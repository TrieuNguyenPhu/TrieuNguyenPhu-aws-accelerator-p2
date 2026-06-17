# Progressive Delivery & Canary Deployment — Triển khai An toàn, Kiểm soát Rủi ro

Bản ghi chép này trình bày về phương pháp Giao hàng Tịnh tiến (Progressive Delivery), so sánh các hình thức triển khai, và cách thiết lập tự động hóa Canary Deployment bằng Argo Rollouts tích hợp Prometheus metric để tự động hủy (abort) khi gặp lỗi.

---

## 1. Khái niệm Progressive Delivery (Giao hàng Tịnh tiến)

**Progressive Delivery** là bước tiến hóa tiếp theo của Continuous Delivery (CD). Thay vì triển khai phiên bản mới trực tiếp cho toàn bộ người dùng và chịu rủi ro lớn, Progressive Delivery thực hiện việc phát hành tính năng/ứng dụng một cách tịnh tiến và có kiểm soát:
*   Giới hạn đối tượng tiếp cận phiên bản mới (Blast Radius - Bán kính ảnh hưởng).
*   Đo lường các chỉ số sức khỏe hệ thống theo thời gian thực (Telemetric feedback).
*   Tự động đưa ra quyết định tiếp tục nâng cấp (Promote) hoặc đảo ngược trạng thái (Rollback/Abort) dựa trên dữ liệu thu được.

---

## 2. So sánh Blue-Green và Canary Deployment

| Đặc tính | Blue-Green Deployment | Canary Deployment |
| :--- | :--- | :--- |
| **Cơ chế** | Duy trì hai môi trường song song độc lập hoàn toàn (Blue - cũ, Green - mới). Chuyển hướng 100% traffic lập tức tại Load Balancer. | Chuyển một phần nhỏ traffic (ví dụ: 5%, 10%) sang phiên bản mới chạy song song trên cùng một cụm. |
| **Bán kính ảnh hưởng** | Lớn (100% người dùng tiếp cận phiên bản mới ngay lập tức, nếu lỗi sẽ ảnh hưởng toàn bộ). | Rất nhỏ (Chỉ có tỷ lệ nhỏ traffic chịu ảnh hưởng nếu phiên bản mới bị lỗi). |
| **Yêu cầu Tài nguyên** | Cao (Cần gấp đôi tài nguyên hệ thống để chạy đồng thời cả 2 phiên bản cũ và mới ở công suất tối đa). | Thấp (Chỉ cần scale lượng Pod tương ứng với phần trăm traffic được chia sẻ). |
| **Cơ chế Rollback** | Cực nhanh và đơn giản (Switch cổng Load Balancer ngược trở lại môi trường Blue). | Tự động hóa thông qua việc chỉnh sửa cấu hình phân luồng mạng và scale down Pod mới về 0. |

---

## 3. Argo Rollouts và Custom Resources (CRDs)

Trong Kubernetes native, tài nguyên **Deployment** chỉ hỗ trợ chiến lược RollingUpdate cơ bản (không thể phân chia traffic theo tỷ lệ lẻ, không thể tạm dừng để quan sát tự động). **Argo Rollouts** được phát triển để giải quyết nhược điểm này bằng cách giới thiệu một Controller và các Custom Resource Definitions (CRDs) mới.

### Các CRD quan trọng của Argo Rollouts:

#### 1. Rollout CRD
Thay thế trực tiếp cho `Deployment` tiêu chuẩn trong K8s. Nó định nghĩa cấu hình Pod template, số lượng replica, và chiến lược deployment nâng cao (`canary` hoặc `blueGreen`).
*Ví dụ khai báo các bước chia traffic:*
```yaml
spec:
  strategy:
    canary:
      steps:
        - setWeight: 10
        - pause: { duration: 5m } # Dừng lại 5 phút để đo lường
        - analysis:
            templates:
              - templateName: success-rate-analysis
        - setWeight: 50
        - pause: { duration: 10m }
```

#### 2. AnalysisTemplate
Định nghĩa **cách thức** và **tiêu chí** để đánh giá phiên bản mới có an toàn hay không. Nó khai báo metric cần lấy (ví dụ: Prometheus query, Datadog, Webhook) và các ngưỡng chấp nhận/thất bại.

#### 3. AnalysisRun
Là một "thể hiện" (Instance) được tạo ra từ `AnalysisTemplate` khi quá trình Rollout bắt đầu. Nó thực thi truy vấn đo lường thực tế và trả kết quả về cho Rollout Controller quyết định.

---

## 4. Tự động Hủy triển khai (Auto-Abort) bằng Metric Prometheus

Để loại bỏ hoàn toàn yếu tố phán đoán cảm tính của con người, ta cấu hình để cụm tự kiểm tra chất lượng bản release mới.

### Kịch bản tự động hóa:
1.  **Deploy bản mới:** Developer update tag image lỗi (`v-bad`) lên Git. ArgoCD sync và báo Argo Rollouts khởi chạy tiến trình Canary.
2.  **Chia luồng traffic:** Argo Rollouts chuyển 10% traffic vào Pod mới.
3.  **Kích hoạt AnalysisRun:** OpendTect / Prometheus bắt đầu cào metric từ Pod mới. AnalysisRun chạy truy vấn PromQL đo tỷ lệ lỗi HTTP 5xx:
    ```promql
    sum(rate(http_requests_total{status=~"5..", kubernetes_pod_name=~"api-.*"}[2m])) 
    / 
    sum(rate(http_requests_total[2m]))
    ```
4.  **Kiểm tra điều kiện lỗi:** Nếu tỷ lệ lỗi vượt ngưỡng cho phép (ví dụ: `> 1%`), AnalysisRun sẽ đánh dấu trạng thái thất bại (`Failed`).
5.  **Auto-Abort (Hủy tự động):** Argo Rollouts lập tức nhận diện tín hiệu thất bại, chuyển hướng 100% traffic quay về phiên bản ổn định cũ (`v-good`) và scale down các Pod lỗi về 0. Hệ thống được bảo vệ an toàn tự động.

---

## 5. Tích hợp với SLO và Burn Rate

Bước tối ưu cao nhất của Progressive Delivery là gắn trực tiếp `AnalysisTemplate` vào ngân sách lỗi (**Error Budget**) hoặc tốc độ tiêu hao ngân sách (**Burn Rate**) của ứng dụng:
*   Nếu quá trình triển khai Canary làm tăng đột biến tốc độ tiêu thụ Error Budget (Burn Rate vượt quá 14.4 trong Fast Window), quá trình release phải bị hủy bỏ ngay tức thì.
*   Điều này giúp tích hợp chặt chẽ việc phát triển phần mềm (Dev) với vận hành tin cậy (Ops/SRE), bảo vệ trải nghiệm của khách hàng ở mức tối đa.

# Báo cáo Thu hoạch & Phản tư - Tuần 9 📝

Báo cáo này tổng hợp quá trình học tập, phản tư và các kỹ năng thu nhận trong Tuần 9 của track Cloud/DevOps thuộc chương trình **AWS Accelerator Program - Phase 2**.

---

## 1. Kiến thức đã tích lũy theo từng ngày

### 🔹 Day A: GitOps & CI/CD
*   **Nguyên lý GitOps:** Hiểu sâu sắc về vai trò của Git làm "Single Source of Truth". Trạng thái mong muốn của hệ thống khai báo bằng YAML được đồng bộ liên tục nhờ GitOps agent, giúp loại bỏ việc SSH gõ lệnh thủ công trên cụm.
*   **ArgoCD vs FluxCD:** Phân biệt được ưu điểm của ArgoCD (giao diện trực quan, thích hợp làm việc nhóm nhiều ứng dụng) và FluxCD (nhẹ, tối giản, CLI-native).
*   **App of Apps Pattern:** Phương pháp dùng một ứng dụng cha (Root App) khai báo cấu hình để quản lý và triển khai tự động nhiều ứng dụng con (Child Apps), giải quyết bài toán scale hạ tầng khi số lượng microservices tăng lên.
*   **Sync Waves:** Cơ chế kiểm soát thứ tự deploy tài nguyên (ví dụ: tạo Namespace, Secrets trước, sau đó mới tạo Deployments và Services) tránh các lỗi crash loop do thiếu dependencies.
*   **Chiến lược Rollback:** So sánh `git revert` (đúng chuẩn GitOps, lưu lịch sử rõ ràng) và `kubectl rollout undo` (nhanh nhưng gây drift cấu hình, chỉ dùng khi khẩn cấp).

### 🔹 Day B: Observability — SLO/SLI/OTel
*   **Trụ cột Observability:** Nắm vững vai trò và sự liên kết giữa Metrics (đo lường tổng quát), Logs (chi tiết sự kiện) và Traces (luồng request trong microservices).
*   **Phương pháp luận SRE:** Hiểu cách tính toán SLI (chất lượng thực tế), xác định SLO (mục tiêu nội bộ) và sự khác biệt với SLA (cam kết thương mại). Quản lý rủi ro qua Khái niệm Ngân sách lỗi (Error Budget).
*   **Bộ công cụ giám sát:** Cách hoạt động của Prometheus (Pull metric), Loki (Log aggregator tối ưu nhãn tương đồng Prometheus) và Grafana (thiết lập Dashboard).
*   **OpenTelemetry (OTel):** Chuẩn hóa việc thu thập telemetry thông qua OTel Collector (Receivers, Processors, Exporters).
*   **Cảnh báo nâng cao (Burn Rate Alerting):** Cách thiết kế cảnh báo theo Google SRE Book dựa trên tốc độ tiêu thụ Error Budget (Multi-window Burn Rate) giúp tránh tình trạng nhiễu cảnh báo (Alert Fatigue) mà vẫn phát hiện lỗi âm ỉ.

### 🔹 Day C: Progressive Delivery (Canary)
*   **Phương pháp Giao hàng Tịnh tiến:** Hạn chế bán kính ảnh hưởng (Blast Radius) khi triển khai phiên bản mới bằng cách tăng tỷ lệ traffic dần dần (5% -> 10% -> 50% -> 100%).
*   **Argo Rollouts:** Sử dụng Rollout CRD thay thế cho Deployment mặc định của Kubernetes để kiểm soát chi tiết các bước chuyển tiếp traffic và phân tích metric.
*   **Phân tích tự động (AnalysisTemplate & AnalysisRun):** Thiết lập AnalysisTemplate liên tục truy vấn Prometheus để đo lường tỷ lệ lỗi HTTP của phiên bản Canary.
*   **Auto-Abort (Hủy tự động):** Nếu tỷ lệ lỗi vượt ngưỡng cấu hình trong quá trình Canary, controller sẽ tự động kích hoạt abort, hướng 100% traffic trở lại phiên bản ổn định cũ và hạ tải pod lỗi về 0 mà không cần can thiệp thủ công.

---

## 2. Điểm tâm đắc & Giá trị cốt lõi
*   **Sự kết hợp hoàn chỉnh của chu trình:** Từ code thay đổi trên Git -> CI chạy kiểm định -> ArgoCD tự động đồng bộ lên Kubernetes -> Prometheus đo lường thực tế -> Argo Rollout điều phối traffic và tự động khôi phục nếu phát hiện lỗi. Chu trình này tạo nên một hệ thống tự vận hành cực kỳ an toàn.
*   **Tư duy SRE thay thế tư duy truyền thống:** Chấp nhận hệ thống sẽ có lỗi và học cách quản lý lỗi qua Error Budget thay vì cố gắng hướng tới 100% uptime một cách vô ích và tốn kém.

---

## 3. Điều cần tìm hiểu thêm & Kế hoạch hành động
*   [ ] **Thực hành viết PromQL nâng cao:** Để thiết lập các truy vấn đo lường SLI/SLO chính xác hơn cho các API phức tạp (ví dụ: latency phân vị P99/P95).
*   [ ] **Tự xây dựng một OTel Collector custom:** Cấu hình routing trace data sang các APM Tool khác như AWS X-Ray hay Grafana Tempo để hiểu sâu hơn về Distributed Tracing.
*   [ ] **Tối ưu hóa Service Mesh:** Tìm hiểu cách Argo Rollouts tích hợp với Istio hoặc Linkerd để phân chia traffic Canary ở tầng ứng dụng (L7) thay vì chỉ chia ở tầng mạng (L4) qua Service.

# Platform Integration & SRE — Tích hợp Hệ thống và Vận hành Tin cậy

Bản ghi chép này trình bày cách tích hợp toàn bộ các cấu phần hạ tầng đã học thành một nền tảng thống nhất (Unified Platform), phương pháp phân hoạch tài nguyên cụm, kỹ thuật Chaos Engineering, quy trình ứng phó sự cố (Incident Response) và quản lý chi phí đám mây (Cost Guard).

---

## 1. Tích hợp Hệ thống Nền tảng Toàn diện

Mục tiêu cốt lõi của **Platform Engineering** là gắn kết các cấu phần riêng lẻ đã học thành một nền tảng tự vận hành thống nhất:
*   **Hạ tầng IaC (Terraform):** Khởi tạo VPC, EKS Cluster, IAM Roles (IRSA), S3 Bucket, DynamoDB cho state lock.
*   **GitOps (ArgoCD):** Quản lý toàn bộ cấu hình cụm và ứng dụng qua mẫu thiết kế App of Apps.
*   **Progressive Delivery (Argo Rollouts):** Nhận manifest từ ArgoCD, điều phối traffic Canary và thu thập metrics từ Prometheus.
*   **Observability (Prometheus + Grafana + Loki):** Theo dõi SLI/SLO, cung cấp dữ liệu cho AnalysisRun của Argo Rollouts để quyết định promote hoặc auto-abort.
*   **Secrets & Security (ESO + Gatekeeper/VAP):** Đồng bộ secret an toàn và kiểm soát bảo mật ở cấp cụm.

---

## 2. Phân hoạch Tài nguyên: ResourceQuota và LimitRange

Để tránh hiện tượng ứng dụng tiêu thụ quá nhiều tài nguyên làm sập các ứng dụng khác trên cùng một Node (lỗi Noisy Neighbor), Kubernetes cung cấp hai công cụ phân hoạch:

### 2.1. ResourceQuota (Giới hạn Namespace)
*   **Vai trò:** Đặt hạn mức tài nguyên tối đa (CPU, Memory, Storage, số lượng Pods, Services) mà một Namespace được phép tiêu thụ.
*   *Ví dụ:* Namespace `testing` chỉ được dùng tối đa 4 Cores CPU và 8Gi RAM. Nếu deploy vượt quá, API Server sẽ từ chối.

### 2.2. LimitRange (Mặc định và Ràng buộc cho Container)
*   **Vai trò:** Thiết lập cấu hình tài nguyên mặc định (`default` requests/limits) và giới hạn tỷ lệ (`min/max`) cho từng container riêng lẻ trong Namespace nếu Developer quên không định nghĩa trong manifest.
*   *Ví dụ:* Bất kỳ container nào tạo ra trong namespace `development` mà không khai báo tài nguyên sẽ tự động được gán `request: 200m CPU, 256Mi RAM` và `limit: 500m CPU, 512Mi RAM`.

---

## 3. Kiểm thử Khả năng chịu lỗi: Chaos Engineering

**Chaos Engineering** là kỷ luật kiểm thử khả năng phục hồi của hệ thống bằng cách chủ động đưa các sự cố giả lập vào môi trường Production/Staging một cách có kiểm soát.

*   **Mục đích:** Xác minh xem hệ thống tự phục hồi (Self-healing), giám sát (Observability) và cảnh báo (Alerting) có hoạt động đúng thiết kế khi xảy ra sự cố hay không.
*   **Các kịch bản thực tế:**
    *   **Pod Chaos:** Ngẫu nhiên terminate các Pod của một Service (kiểm tra tính sẵn sàng của ReplicaSet).
    *   **Network Chaos:** Giả lập độ trễ mạng (Network Latency) hoặc mất gói tin (Packet Loss) giữa các microservices (kiểm tra timeout và retry policy).
    *   **Stress Chaos:** Chiếm dụng 100% CPU/Memory của một Node (kiểm tra cơ chế Autoscaling và Eviction).
*   **Công cụ phổ biến:** Chaos Mesh, LitmusChaos.

---

## 4. Quy trình Ứng phó Sự cố (Incident Response Playbook)

Khi hệ thống xảy ra sự cố nghiêm trọng, đội ngũ SRE tuân thủ quy trình 6 bước chuẩn:

```text
1. Phát hiện (Detect) ➔ 2. Phân loại (Triage) ➔ 3. Khoanh vùng (Contain) ➔ 4. Khắc phục (Eradicate) ➔ 5. Phục hồi (Recover) ➔ 6. Rút kinh nghiệm (Post-mortem)
```

1.  **Phát hiện (Detect):** Qua cảnh báo Burn Rate Alert trên Slack/PagerDuty hoặc người dùng báo lỗi.
2.  **Phân loại (Triage):** Xác định mức độ nghiêm trọng (Severity: P1, P2...) và phạm vi ảnh hưởng (bao nhiêu người dùng bị tác động).
3.  **Khoanh vùng (Contain):** Ngăn chặn sự cố lan rộng (ví dụ: cô lập Pod bị lỗi, tắt tính năng bị lỗi qua Feature Flag, redirect traffic).
4.  **Khắc phục (Eradicate):** Tìm và sửa nguyên nhân gốc rễ (ví dụ: revert commit lỗi, scale up tài nguyên).
5.  **Phục hồi (Recover):** Đưa hệ thống về trạng thái bình thường ổn định và xác nhận qua chỉ số SLI/SLO.
6.  **Rút kinh nghiệm (Post-mortem):** Soạn thảo báo cáo tài liệu hóa sự cố để tránh tái diễn.

### 📜 Runbook Mẫu: Khắc phục lỗi CrashLoopBackOff do Secrets Sync thất bại
*   **Triệu chứng:** Pod crash liên tục với lỗi `CrashLoopBackOff`, log báo thiếu biến môi trường/file config nhạy cảm.
*   **Các bước xử lý:**
    1.  Kiểm tra trạng thái ExternalSecret: `kubectl get externalsecret -n <namespace>`.
    2.  Xem chi tiết lỗi đồng bộ: `kubectl describe externalsecret <name> -n <namespace>`.
    3.  Kiểm tra kết nối AWS Secrets Manager qua log của ESO controller.
    4.  Nếu lỗi quyền (Access Denied): Kiểm tra xem IAM Role / SA ServiceAccount đã gán đúng policy chưa.
    5.  Sau khi fix quyền, trigger sync thủ công: `kubectl annotate externalsecret <name> force-sync="true" --overwrite -n <namespace>`.

---

## 5. Quản lý và Tối ưu Chi phí: Cost Guard

Vận hành hệ thống đám mây hiệu quả không chỉ là đảm bảo độ tin cậy mà còn phải kiểm soát chi phí tối ưu.

*   **AWS Cost Anomaly Detection:** Dịch vụ sử dụng Machine Learning để liên tục giám sát lịch sử chi tiêu của tài khoản AWS, phát hiện các bất thường (ví dụ: đột ngột tăng chi phí EC2 do chạy test quên tắt) và gửi cảnh báo qua Email/Slack.
*   **Terraform Cấu hình Cost Monitor:** Khai báo hạ tầng giám sát chi phí tự động:
    ```hcl
    resource "aws_ce_anomaly_monitor" "cost_monitor" {
      name         = "DailyCostAnomalyMonitor"
      monitor_type = "DIMENSIONAL"
      monitor_dimension = "SERVICE"
    }

    resource "aws_ce_anomaly_subscription" "email_subscription" {
      name             = "DailyCostAnomalySubscription"
      threshold        = 50 # Cảnh báo nếu chi phí bất thường vượt quá $50
      frequency        = "IMMEDIATE"
      monitor_arn_list = [aws_ce_anomaly_monitor.cost_monitor.arn]

      subscriber {
        address = "sre-team@example.com"
        type    = "EMAIL"
      }
    }
    ```

# Báo cáo Thu hoạch & Phản tư - Tuần 10 📝

Báo cáo này tổng hợp quá trình học tập, phản tư và các kỹ năng thu nhận trong Tuần 10 của track Cloud/DevOps thuộc chương trình **AWS Accelerator Program - Phase 2**.

---

## 1. Kiến thức đã tích lũy theo từng ngày

### 🔹 Day A: RBAC & Admission Policy
*   **Kubernetes RBAC Hardening:** Nắm vững cấu trúc phân quyền dựa trên vai trò sử dụng Role, ClusterRole, RoleBinding và ClusterRoleBinding. Rèn luyện nguyên tắc đặc quyền tối thiểu (Least Privilege), kiểm soát chặt chẽ quyền hạn của ServiceAccount, tắt cơ chế tự động mount token (`automountServiceAccountToken: false`) đối với các workload không cần kết nối API Server.
*   **Kiểm tra và kiểm thử quyền:** Sử dụng hiệu quả lệnh `kubectl auth can-i --as` để giả lập quyền của các ServiceAccount khác nhau mà không cần cấu hình file kubeconfig mới.
*   **OPA Gatekeeper:** Tìm hiểu kiến trúc và cơ chế chặn đầu vào thông qua ConstraintTemplate (định nghĩa logic Rego) và Constraint (định nghĩa cấu hình phạm vi và tham số). Phân biệt chế độ Enforce (chặn trực tiếp) và Audit (cho phép chạy và liệt kê vi phạm).
*   **ValidatingAdmissionPolicy (VAP):** Tiếp cận giải pháp native từ K8s 1.30+ sử dụng Common Expression Language (CEL). Thấy rõ ưu điểm vượt trội về hiệu năng và độ tối giản so với việc dựng webhook server bên ngoài của OPA Gatekeeper.

### 🔹 Day B: Secrets Rotation & Supply Chain Security
*   **External Secrets Operator (ESO):** Đồng bộ hóa secrets động từ AWS Secrets Manager về Kubernetes Secrets native một cách an toàn thông qua IAM Roles for Service Accounts (IRSA).
*   **Xoay vòng Secrets dưới 60 giây:** Cấu hình thành công cơ chế xoay vòng bí mật tự động sử dụng Volume Mounts thay vì Environment Variables. Nhờ đó, ứng dụng tự động nhận diện giá trị secrets mới cập nhật từ AWS mà không cần khởi động lại (restart) Pod/Container.
*   **Trivy Container Scanning:** Tích hợp bộ quét bảo mật Trivy vào GitHub Actions CI pipeline để phát hiện và tự động chặn (fail pipeline) khi phát hiện lỗ hổng HIGH/CRITICAL trong image.
*   **Image Signing & Verification:** Thực hành ký số container image bằng Cosign (sử dụng cả khóa private key và cơ chế keyless OIDC). Thiết lập webhook Kyverno để tự động từ chối triển khai các container image không có chữ ký hợp lệ.
*   **Quản lý Ngoại lệ CVE:** Quy trình xử lý ngoại lệ an toàn thông qua ADR có thời hạn và file cấu hình `.trivyignore`.

### 🔹 Day C: Platform Integration & SRE
*   **Tích hợp nền tảng toàn diện:** Kết hợp tất cả các thành phần riêng lẻ của W8, W9, W10 (Terraform, GitOps, Prometheus/Grafana, Argo Rollouts, ESO, Gatekeeper/VAP) thành một hệ thống hoạt động đồng bộ, tự phục hồi và bảo mật tối đa.
*   **Resource Partitioning:** Thiết lập ResourceQuota để kiểm soát hạn mức tiêu thụ tài nguyên của từng Namespace và LimitRange để cấu hình giá trị mặc định cho container, tránh lỗi Noisy Neighbor.
*   **Chaos Engineering:** Giả lập lỗi hệ thống (tắt Pod đột ngột, làm trễ mạng) bằng các công cụ như Chaos Mesh để kiểm thử khả năng chịu lỗi và phản ứng tự phục hồi của cụm.
*   **Incident Response & Runbooks:** Xây dựng quy trình ứng phó sự cố 6 bước và thiết lập Runbook mẫu khắc phục lỗi CrashLoopBackOff do mất đồng bộ secrets, giúp đội ngũ vận hành phản ứng nhanh và chính xác.
*   **AWS Cost Guard:** Thiết lập hệ thống phát hiện chi phí bất thường AWS Cost Anomaly Detection bằng Terraform để tự động gửi cảnh báo qua Slack/Email khi chi tiêu vượt ngưỡng ranh giới cho phép.

---

## 2. Điểm tâm đắc & Đánh giá cá nhân
*   **Chuyển đổi từ Developer sang Platform Engineer:** Tuần này đã nâng tầm tư duy quản trị hệ thống của tôi. Không chỉ đơn thuần là triển khai ứng dụng chạy được mà là xây dựng một nền tảng cụm cứng cáp (Hardened Platform) bảo mật ở mọi cấp độ: từ chuỗi cung ứng code (Trivy, Cosign), cấp độ truy cập API (RBAC, VAP), đến an toàn bảo mật dữ liệu (ESO Secrets Rotation).
*   **Sức mạnh của Automation:** Việc kết hợp AWS Secrets Manager và ESO giúp việc quản lý credentials trở nên vô cùng nhàn nhã và an toàn, xóa bỏ hoàn toàn nỗi lo lộ secrets trên mã nguồn mở.

---

## 3. Định hướng hành động tiếp theo
*   [ ] **Chuẩn bị Capstone Project (W11-W12):** Thiết kế sẵn template bootstrap hạ tầng EKS bảo mật tích hợp đầy đủ stack GitOps, Observability, Secrets Rotation và Security Policies để triển khai nhanh chóng cho cross-team pod.
*   [ ] **Nâng cấp chính sách bảo mật lên CEL:** Di chuyển dần các chính sách Gatekeeper Rego cũ sang ValidatingAdmissionPolicy (VAP) dạng CEL native để tối ưu hóa hiệu năng cụm.

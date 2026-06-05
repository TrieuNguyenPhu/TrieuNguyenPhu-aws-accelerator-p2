# Báo cáo Thu hoạch & Phản tư - Tuần 8 📝

Báo cáo này tổng kết lại hành trình học tập, các kỹ năng đã tích lũy và quá trình thực hiện bài lab thực tế trong Tuần 8 của chương trình **AWS Accelerator Program - Phase 2**.

---

## 1. Kiến thức và Kỹ năng đã học

### 🔹 Day A: Terraform Cơ bản & Quy trình IaC
- **Khái niệm Infrastructure as Code (IaC)**: Sự khác biệt giữa phương pháp Khai báo (Declarative) của Terraform và Mệnh lệnh (Imperative) của scripts truyền thống. Hiểu cách IaC giúp ngăn chặn *Configuration Drift* (sự sai lệch cấu hình hạ tầng).
- **Cú pháp HCL**: Nắm vững các block cấu hình chính bao gồm `provider`, `resource`, `variable` (đầu vào), `output` (đầu ra), `locals`.
- **Quy trình làm việc (Lifecycle Workflow)**: Quy trình chuẩn `terraform init` ➔ `terraform fmt` ➔ `terraform validate` ➔ `terraform plan` ➔ `terraform apply` ➔ `terraform destroy`.
- **Quản lý State**: Bản chất của `terraform.tfstate` và quy tắc bảo mật quan trọng: *Không bao giờ commit file state lên Git.*

### 🔹 Day B: Kubernetes Cơ bản (K8s Core)
- **Container Orchestration**: Lý do cần K8s để điều phối, scale, tự động restart và rolling update thay vì chỉ chạy Docker độc lập.
- **Các thành phần cốt lõi**:
  - **Pod**: Đơn vị triển khai nhỏ nhất, chia sẻ Network và Storage namespace.
  - **Service**: Abstraction tạo endpoint ổn định (ClusterIP cho nội bộ, NodePort/LoadBalancer cho external access).
  - **Probes**: Cơ chế kiểm tra sức khỏe của container thông qua `LivenessProbe` (quyết định restart container) và `ReadinessProbe` (quyết định route traffic).
  - **ConfigMap & Secret**: Tách cấu hình và thông tin bảo mật khỏi Image mã nguồn của ứng dụng.
  - **NetworkPolicy**: Quản lý và giới hạn luồng traffic giữa các Pod theo nguyên lý Least Privilege.

### 🔹 Day C: Terraform Nâng cao & Thiết kế Kiến trúc
- **Remote State Backend**: Cấu hình lưu trữ file state tập trung trên **Amazon S3** (bật Versioning để rollback và SSE để mã hóa) kết hợp với **Amazon DynamoDB** (với partition key `LockID`) để khóa trạng thái (State Locking), tránh xung đột khi chạy song song trong team.
- **Terraform Modules**: Chia tách mã nguồn hạ tầng thành các Child Modules độc lập (ví dụ: module VPC, module EC2, module S3...) giúp tái sử dụng và quản lý mã nguồn chuyên nghiệp.
- **Quản lý Đa môi trường**: Lựa chọn giải pháp *Directory-based Separation* để tách biệt hoàn toàn state giữa Dev, Staging và Production, giảm thiểu rủi ro thao tác nhầm trên Production.
- **ADR (Architecture Decision Record)**: Cách soạn thảo tài liệu ghi chép lại các quyết định thiết kế kiến trúc quan trọng cùng hệ quả kéo theo của chúng.

---

## 2. Thành tựu từ Bài Lab Thực hành (Minesweeper Gin K8s on AWS)

Tôi đã hoàn thành xuất sắc bài Lab triển khai game **Minesweeper (Go + Gin)** chạy trên cụm **Kubernetes (Minikube)** của một **EC2 Instance**, expose ra ngoài Internet thông qua **AWS Application Load Balancer (ALB)** bằng giải pháp tự động hóa hoàn toàn **1-Click Deploy**.

### 🏆 Các điểm sáng kỹ thuật đạt được:
1. **Liên kết Providers (Wire Providers)**: Sử dụng kết hợp `hashicorp/tls` và `hashicorp/aws`. TLS provider tự động sinh RSA-4096 SSH key pair trong state, sau đó truyền public key sang AWS provider để tạo `aws_key_pair` và gán vào EC2, đồng thời xuất private key qua output nhạy cảm (sensitive output) để SSH debug.
2. **Thiết lập Pipeline User Data tự động**: Viết script bootstrapping hoàn chỉnh trên EC2 (Amazon Linux 2023) thực hiện:
   - Cài đặt Docker, Git, Kubectl, Minikube.
   - Khởi động minikube sử dụng docker driver kèm port forwarding.
   - Clone mã nguồn, thực hiện build Docker image cục bộ và nạp trực tiếp vào registry của minikube.
   - Triển khai các K8s manifests (Deployment & Service).
3. **Cấu hình Mạng & Load Balancer**: Thiết kế VPC tùy chỉnh với 2 Public Subnet ở 2 Availability Zones khác nhau phục vụ cho ALB. Định tuyến chính xác: `Internet ➔ ALB (:80) ➔ Target Group ➔ EC2 (:30080) ➔ Minikube (:30080) ➔ Service NodePort ➔ Pod (:8080)`.
4. **Lưu trữ bằng chứng hoàn thành**:
   - [Bằng chứng 1 - Khởi tạo hạ tầng thành công (16 resources)](lab/evidence/01-terraform-apply.jpg)
   - [Bằng chứng 2 - Game Minesweeper truy cập qua ALB URL](lab/evidence/02-app-browser.jpg)
   - [Bằng chứng 3 - Kiểm tra pod, svc running bên trong cluster](lab/evidence/03-kubectl-pods-svc.jpg)
   - [Bằng chứng 4 - Hủy tài nguyên sạch sẽ bảo vệ ngân sách](lab/evidence/04-terraform-destroy.jpg)

---

## 3. Khó khăn gặp phải & Hướng Giải quyết

| Khó khăn | Nguyên nhân | Cách khắc phục / Giải quyết |
| :--- | :--- | :--- |
| **Debug script User Data chạy ngầm quá lâu** | Quá trình cài Docker, Minikube, build image tốn 5-8 phút. Nếu có bước nào lỗi thì `terraform apply` vẫn báo success nhưng app không chạy. | Sử dụng SSH private key kết nối vào EC2 thông qua output IP: `ssh -i .ssh/id_rsa_minesweeper ec2-user@<IP>`. Chạy lệnh `sudo tail -f /var/log/user-data.log` để xem log cài đặt thời gian thực nhằm phát hiện bước lỗi. |
| **K8s Pod báo lỗi ErrImagePull** | K8s mặc định tìm kiếm image trên registry công khai (Docker Hub) thay vì dùng image local vừa build. | Đặt thuộc tính `imagePullPolicy: Never` trong file `deployment.yaml`. Trước khi apply manifest, sử dụng lệnh `minikube image load --image minesweeper-gin:local` để nạp image vào cluster. |
| **ALB không kết nối được vào Minikube bên trong EC2** | Minikube chạy cô lập bên trong docker driver container của EC2 nên ALB không thể truy cập trực tiếp qua NodePort. | Bổ sung tham số map port khi chạy lệnh start minikube: `minikube start --driver=docker --ports=30080:30080 --force` để chuyển tiếp cổng từ container minikube ra host EC2. |

---

## 4. Định hướng và Kế hoạch Hành động tiếp theo

- [ ] **Áp dụng Remote Backend**: Bắt buộc cấu hình S3 Backend và DynamoDB Lock cho toàn bộ các bài thực hành và dự án Capstone sau này để rèn luyện thói quen làm việc nhóm an toàn.
- [ ] **Nghiên cứu Helm Chart**: Thay thế việc quản lý các file manifest K8s dạng YAML rời rạc bằng Helm để đóng gói ứng dụng chuyên nghiệp hơn.
- [ ] **Tối ưu hóa CI/CD**: Xây dựng luồng GitHub Actions để tự động build docker image và đẩy lên AWS ECR thay vì clone code và build trực tiếp trên máy chủ EC2 như bài lab này, giúp phân tách rõ ràng nhiệm vụ (Build vs Run).
- [ ] **Tuân thủ Style Guide**: Duy trì việc sử dụng `terraform fmt` trước mỗi lần commit và ghi chép đầy đủ các quyết định kiến trúc qua ADR.

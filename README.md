# AWS Accelerator Program - Phase 2 🚀

Chào mừng bạn đến với kho lưu trữ mã nguồn của **AWS Accelerator Program - Phase 2**. Đây là nơi quản lý và lưu trữ toàn bộ nội dung học tập, thực hành lab, demo, cấu hình hạ tầng (Infrastructure as Code) và dự án capstone về Cloud Engineering, DevOps, Terraform và Kubernetes.

---

## 📁 Cấu trúc thư mục (Repository Layout)

Dự án được tổ chức một cách rõ ràng theo tuần học và giai đoạn:

```text
TrieuNguyenPhu-aws-accelerator-p2/
├── cloud/                             # Nội dung học tập và bài tập AWS Cloud & DevOps
│   ├── w8/                            # Tuần 8: Infrastructure as Code & Kubernetes Core
│   │   ├── day-a/                     # Ngày A: Terraform cơ bản (HCL, CLI workflow)
│   │   ├── day-b/                     # Ngày B: Kubernetes cơ bản (Pod, Service, Probes, Secrets...)
│   │   ├── day-c/                     # Ngày C: Terraform nâng cao (State, Modules, Best Practices, ADR)
│   │   ├── Demo/                      # Bài thực hành Demo EC2 và SSH Key pair bằng Terraform
│   │   ├── lab/                       # Dự án Lab: Triển khai game Minesweeper Gin trên K8s qua AWS ALB
│   │   └── reflection.md              # Báo cáo thu hoạch & phản tư Tuần 8
│   ├── w9/                            # Tuần 9: GitOps, Observability & Progressive Delivery
│   │   ├── day-a/                     # Ngày A: GitOps & CI/CD (ArgoCD, App of Apps Pattern, Sync Waves)
│   │   ├── day-b/                     # Ngày B: Observability (SLO/SLI, Prometheus, Loki, Grafana, OTel)
│   │   ├── day-c/                     # Ngày C: Progressive Delivery (Argo Rollouts, Canary, Auto-Abort)
│   │   ├── lab/                       # Dự án Lab: GitOps Progressive Delivery Pipeline (Canary & Auto-Abort)
│   │   └── reflection.md              # Báo cáo thu hoạch & phản tư Tuần 9
│   └── w10/                           # Tuần 10: Kubernetes Security Hardening & Platform Integration
│       ├── day-a/                     # Ngày A: RBAC Hardening & Admission Policies (OPA Gatekeeper, VAP)
│       ├── day-b/                     # Ngày B: Secrets Rotation (ESO) & Supply Chain Security (Trivy, Cosign)
│       ├── day-c/                     # Ngày C: Platform Integration (ResourceQuota, LimitRange, Chaos Mesh)
│       └── reflection.md              # Báo cáo thu hoạch & phản tư Tuần 10
├── capstone/                          # Khu vực dự án tốt nghiệp (Capstone Project)
│   ├── w11/                           # Tuần 11 Capstone (Trống)
│   └── w12/                           # Tuần 12 Capstone (Trống)
└── README.md                          # Tài liệu hướng dẫn chính (File này)
```

---

## 🌟 Dự án nổi bật trong học phần

### [Week 8 Lab: Minesweeper (Go + Gin) on K8s (1-Click Deploy)](file:///d:/source%20code/TrieuNguyenPhu-aws-accelerator-p2/cloud/w8/lab/README.md)
Triển khai trò chơi **Minesweeper** viết bằng Go (Gin Framework) lên cụm **Kubernetes (Minikube)** chạy bên trong một **EC2 Instance (Amazon Linux 2023)**, expose ra Internet thông qua **AWS Application Load Balancer (ALB)**. Tất cả được tự động hóa hoàn toàn chỉ bằng **một lệnh duy nhất** `terraform apply`.

#### 🏗️ Sơ đồ Kiến trúc hạ tầng
```text
                         ┌─────────────────────────────────────────┐
Internet ──── :80 ──────▶│   AWS Application Load Balancer (ALB)   │
                         │   (internet-facing, 2 AZs)              │
                         └──────────────┬──────────────────────────┘
                                         │ HTTP :30080 (Target Group)
                                         ▼
                         ┌─────────────────────────────────────────┐
                         │  EC2  t3.medium  (Amazon Linux 2023)    │
                         │  ┌───────────────────────────────────┐  │
                         │  │  minikube cluster (docker driver)  │  │
                         │  │  ┌─────────────────────────────┐  │  │
                         │  │  │  Pod: minesweeper-gin       │  │  │
                         │  │  │  image: minesweeper-gin:local│  │  │
                         │  │  │  containerPort: 8080        │  │  │
                         │  │  └─────────────────────────────┘  │  │
                         │  │  Service: NodePort 30080 → 8080   │  │
                         │  └───────────────────────────────────┘  │
                         │  Docker  │  Security Group              │
                         └─────────────────────────────────────────┘
```

#### 🚀 Cách triển khai nhanh
1. Cấu hình AWS Credentials trên máy cá nhân (`aws configure`).
2. Di chuyển vào thư mục Terraform của lab:
   ```bash
   cd cloud/w8/lab/terraform
   ```
3. Khởi chạy triển khai:
   ```bash
   terraform init
   terraform apply -auto-approve
   ```
4. Truy cập URL của ALB được in ra ở output của Terraform sau khi hệ thống khởi động xong (~5-8 phút).

### [Week 9 Lab: GitOps Progressive Delivery Pipeline](file:///d:/source%20code/TrieuNguyenPhu-aws-accelerator-p2/cloud/w9/lab/README.md)
Xây dựng pipeline triển khai ứng dụng API tự động hóa qua GitOps (ArgoCD App-of-Apps), đo lường chất lượng dịch vụ theo thời gian thực (SLO/SLI) qua Prometheus, và tự động hóa điều phối traffic bằng **Argo Rollouts (Canary Deployment)** tích hợp cơ chế tự động hủy bỏ (**Auto-Abort & Auto-Rollback**) khi tỷ lệ lỗi vượt ngưỡng cho phép (> 5%).

#### 🏗️ Sơ đồ Quy trình Canary & Auto-Abort
```text
   Developer                 Git Repository                 ArgoCD (GitOps)
  ┌─────────┐                 ┌───────────┐                  ┌──────────┐
  │ Push v2 │───────────────▶ │  GitHub   │◀─────────────────│   Sync   │
  └─────────┘                 └───────────┘                  └────┬─────┘
                                                                  │ Apply
                                                                  ▼
                                                          ┌───────────────┐
                                                          │ Argo Rollouts │
                                                          └───────┬───────┘
                                                       Canary 25% │
                                                                  ▼
                                                          ┌───────────────┐
                                                          │ AnalysisRun   │
                                                          └───────┬───────┘
                                                                  │
                                            ┌─────────────────────┴─────────────────────┐
                                     [Success Rate >= 95%]                       [Success Rate < 95%]
                                            │                                           │
                                            ▼                                           ▼
                                    Promote to 100%                             Auto-Abort & Rollback
                                    (Deploy Success ✅)                         (Back to v1 & Alert ❌)
```

#### 🚀 Các tính năng chính
- **GitOps App-of-Apps**: Đồng bộ toàn bộ tài nguyên từ Git bao gồm Prometheus Stack, Argo Rollouts và ứng dụng API.
- **Auto-Abort**: Tự động rollback phiên bản lỗi dựa trên kết quả đo đạc từ Prometheus Query theo thời gian thực thông qua `AnalysisTemplate`.
- **Email Alerting**: Cấu hình SMTP Gmail thông qua Alertmanager để gửi cảnh báo tức thì khi SLO chất lượng dịch vụ (< 95% thành công trên 5 phút) bị vi phạm.

---

## 📚 Tóm tắt các chủ đề học tập

| Tuần học | Chủ đề chính | Nội dung chi tiết | Tài liệu & Lab |
| :--- | :--- | :--- | :--- |
| **Week 8** | **Infrastructure as Code & Kubernetes Core** | - Terraform basics & CLI workflow<br>- Kubernetes Core Components (Pods, Services, Probes, ConfigMaps, Secrets)<br>- Terraform State, Modules & ADRs<br>- Lab: Deploy Go App on Kubernetes inside EC2 via ALB | - [Day A Notes](file:///d:/source%20code/TrieuNguyenPhu-aws-accelerator-p2/cloud/w8/day-a/terraform-learning-notes.md)<br>- [Day B Notes](file:///d:/source%20code/TrieuNguyenPhu-aws-accelerator-p2/cloud/w8/day-b/k8s-learning-notes.md)<br>- [Day C Notes](file:///d:/source%20code/TrieuNguyenPhu-aws-accelerator-p2/cloud/w8/day-c/terraform-advanced-notes.md)<br>- [Week 8 Reflection](file:///d:/source%20code/TrieuNguyenPhu-aws-accelerator-p2/cloud/w8/reflection.md) |
| **Week 9** | **GitOps, Observability & Progressive Delivery** | - GitOps principles & ArgoCD App-of-Apps Pattern<br>- Observability (Metrics, Logs, Traces), SLO/SLI & Prometheus/Loki/Grafana/OTel<br>- Progressive Delivery with Argo Rollouts (Canary, AnalysisTemplate & Auto-Abort)<br>- Lab: GitOps Progressive Delivery Pipeline | - [Day A Notes](file:///d:/source%20code/TrieuNguyenPhu-aws-accelerator-p2/cloud/w9/day-a/gitops-cicd-notes.md)<br>- [Day B Notes](file:///d:/source%20code/TrieuNguyenPhu-aws-accelerator-p2/cloud/w9/day-b/observability-notes.md)<br>- [Day C Notes](file:///d:/source%20code/TrieuNguyenPhu-aws-accelerator-p2/cloud/w9/day-c/canary-deployment-notes.md)<br>- [Week 9 Lab Guide](file:///d:/source%20code/TrieuNguyenPhu-aws-accelerator-p2/cloud/w9/lab/README.md)<br>- [Week 9 Reflection](file:///d:/source%20code/TrieuNguyenPhu-aws-accelerator-p2/cloud/w9/reflection.md) |
| **Week 10** | **Kubernetes Security Hardening & Platform Integration** | - RBAC Hardening & Admission Controls (OPA Gatekeeper, ValidatingAdmissionPolicy)<br>- External Secrets Operator (ESO) rotation & Supply Chain Security (Trivy, Cosign image signing)<br>- Resource Partitioning, Chaos Engineering (Chaos Mesh) & Incident Runbooks | - [Day A Notes](file:///d:/source%20code/TrieuNguyenPhu-aws-accelerator-p2/cloud/w10/day-a/rbac-admission-policy-notes.md)<br>- [Day B Notes](file:///d:/source%20code/TrieuNguyenPhu-aws-accelerator-p2/cloud/w10/day-b/secrets-supply-chain-notes.md)<br>- [Day C Notes](file:///d:/source%20code/TrieuNguyenPhu-aws-accelerator-p2/cloud/w10/day-c/platform-integration-notes.md)<br>- [Week 10 Reflection](file:///d:/source%20code/TrieuNguyenPhu-aws-accelerator-p2/cloud/w10/reflection.md) |
| **Week 11-12**| **Capstone Project** | Thiết kế và hiện thực hóa hệ thống hoàn chỉnh trên AWS | *Sắp diễn ra* |

---

## ✍️ Thông tin tác giả
- **Học viên**: Triệu Nguyễn Phú (TrieuNguyenPhu)
- **Chương trình**: AWS Accelerator Program - Phase 2
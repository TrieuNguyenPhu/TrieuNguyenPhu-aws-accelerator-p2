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
│   ├── w9/                            # Tuần 9 (Trống)
│   └── w10/                           # Tuần 10 (Trống)
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

---

## 📚 Tóm tắt các chủ đề học tập

| Tuần học | Chủ đề chính | Nội dung chi tiết | Tài liệu & Lab |
| :--- | :--- | :--- | :--- |
| **Week 8** | **Infrastructure as Code & Kubernetes Core** | - Terraform basics & CLI workflow<br>- Kubernetes Core Components (Pods, Services, Probes, ConfigMaps, Secrets)<br>- Terraform State, Modules & ADRs<br>- Lab: Deploy Go App on Kubernetes inside EC2 via ALB | - [Day A Notes](file:///d:/source%20code/TrieuNguyenPhu-aws-accelerator-p2/cloud/w8/day-a/terraform-learning-notes.md)<br>- [Day B Notes](file:///d:/source%20code/TrieuNguyenPhu-aws-accelerator-p2/cloud/w8/day-b/k8s-learning-notes.md)<br>- [Day C Notes](file:///d:/source%20code/TrieuNguyenPhu-aws-accelerator-p2/cloud/w8/day-c/terraform-advanced-notes.md)<br>- [Week 8 Reflection](file:///d:/source%20code/TrieuNguyenPhu-aws-accelerator-p2/cloud/w8/reflection.md) |
| **Week 9** | *Đang cập nhật* | Sắp diễn ra | *Chưa có* |
| **Week 10** | *Đang cập nhật* | Sắp diễn ra | *Chưa có* |
| **Week 11-12**| **Capstone Project** | Thiết kế và hiện thực hóa hệ thống hoàn chỉnh trên AWS | *Chưa có* |

---

## ✍️ Thông tin tác giả
- **Học viên**: Triệu Nguyễn Phú (TrieuNguyenPhu)
- **Chương trình**: AWS Accelerator Program - Phase 2
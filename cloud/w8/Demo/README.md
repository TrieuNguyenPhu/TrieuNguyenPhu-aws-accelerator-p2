# Dự án Triển khai EC2 Instance bằng Terraform

Dự án này hướng dẫn cách tạo cặp khóa SSH bảo mật (Key Pair) trên máy local và sử dụng Terraform để tự động triển khai một máy chủ Amazon EC2 trên AWS.

## Cấu trúc thư mục dự án

```text
.
├── .gitignore          # Chặn các file nhạy cảm đẩy lên GitHub
├── README.md           # Hướng dẫn sử dụng dự án
├── main.tf             # Code cấu hình Terraform (EC2, Key Pair...)
└── keypair/            # Thư mục lưu trữ khóa SSH (Không đẩy lên GitHub)
    ├── demo-key        # Khóa bí mật (Private Key - ĐÃ BỊ CHẶN)
    └── demo-key.pub    # Khóa công khai (Public Key)
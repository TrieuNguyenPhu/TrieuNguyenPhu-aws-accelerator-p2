# Terraform Advanced: State Management, Modules, Best Practices & ADR

## 1. Terraform State Management & Backend (S3 + DynamoDB Lock)

### Khái niệm State trong Terraform
Terraform lưu trữ thông tin về hạ tầng thực tế dưới dạng một file JSON gọi là **State file** (`terraform.tfstate`). State đóng vai trò như một bản đồ ánh xạ (mapping) giữa các file cấu hình `.tf` và tài nguyên thực tế được khởi tạo trên Cloud. 

State giúp Terraform:
- Xác định những thay đổi (thêm, sửa, xóa) cần thực hiện trong lần chạy tiếp theo.
- Theo dõi các thuộc tính metadata của tài nguyên (ví dụ: Resource ID, ARN, Public IP) mà cấu hình chưa khai báo trực tiếp.
- Cải thiện hiệu năng bằng cách lưu trữ cache thông tin hạ tầng thay vì liên tục gọi API của Cloud Provider.

### Hạn chế của Local State
Khi làm việc một mình, việc lưu state ở local (`terraform.tfstate` trên máy cá nhân) có thể chấp nhận được. Tuy nhiên, khi làm việc nhóm (Teamwork), Local State bộc lộ nhiều điểm yếu nghiêm trọng:
- **Không đồng bộ**: Khi thành viên A chạy `apply`, hạ tầng thay đổi nhưng thành viên B không có file state mới nhất của A, dẫn đến việc ghi đè hoặc xung đột hạ tầng.
- **Rò rỉ thông tin nhạy cảm (Security Risk)**: State file lưu trữ toàn bộ thông tin dưới dạng plain text, bao gồm cả mật khẩu, khóa bí mật (Secret keys), private keys. Việc vô tình commit file này lên Git là cực kỳ nguy hiểm.
- **Thiếu cơ chế Lock**: Nếu hai người cùng chạy `terraform apply` đồng thời, họ sẽ ghi đè lên state file của nhau, gây hỏng hóc hoặc mất đồng bộ hạ tầng.

### Giải pháp: Remote Backend (S3 + DynamoDB)
Để giải quyết các vấn đề trên, Terraform cung cấp cơ chế **Remote Backend**. Với AWS, mô hình chuẩn và phổ biến nhất là sử dụng **Amazon S3** để lưu trữ State và **Amazon DynamoDB** để thực hiện State Locking (khóa trạng thái).

- **S3 Bucket (Storage)**:
  - Lưu trữ file state tập trung, bảo mật bằng IAM policy.
  - **Versioning**: Bắt buộc phải bật để giữ lại lịch sử các phiên bản state. Nếu file state hiện tại bị hỏng, ta có thể dễ dàng rollback về phiên bản trước.
  - **Encryption**: Bật mã hóa SSE (Server-Side Encryption) để bảo vệ dữ liệu nhạy cảm trong state file khi lưu trữ trên đĩa (at rest).
- **DynamoDB Table (Locking)**:
  - Khi một người chạy `terraform apply` hoặc `destroy`, Terraform sẽ ghi một record vào DynamoDB để khóa state lại.
  - Bất kỳ ai khác cố gắng chạy lệnh ghi vào thời điểm đó sẽ nhận được thông báo lỗi state đang bị lock và phải đợi cho đến khi tiến trình đầu tiên hoàn tất.
  - Cấu hình DynamoDB yêu cầu Partition Key (Primary Key) phải được đặt tên chính xác là `LockID` với kiểu dữ liệu là `String`.

### Ví dụ cấu hình Remote Backend S3 + DynamoDB

#### Bước 1: Khởi tạo S3 Bucket và DynamoDB Table (Bootstrap)
Trước khi Terraform có thể lưu state lên S3 và lock qua DynamoDB, các tài nguyên này phải tồn tại trước. Bạn có thể tạo thủ công trên console hoặc dùng một cấu hình Terraform "bootstrap" riêng để tạo chúng:

```hcl
# S3 Bucket để lưu State
resource "aws_s3_bucket" "terraform_state" {
  bucket        = "npt-terraform-state-bucket" # Thay đổi tên bucket duy nhất của bạn
  force_destroy = false
}

# Bật Versioning cho S3
resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Bật mã hóa SSE cho S3
resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Chặn quyền truy cập public vào S3
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table để phục vụ State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID" # Bắt buộc phải là LockID

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

#### Bước 2: Cấu hình Backend trong dự án chính
Sau khi đã có S3 Bucket và DynamoDB table, ta khai báo khối `backend` bên trong block `terraform`:

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "npt-terraform-state-bucket" # Tên bucket đã tạo ở Bước 1
    key            = "global/s3/terraform.tfstate" # Đường dẫn file state trong bucket
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-state-locks"       # Tên DynamoDB table dùng để lock
    encrypt        = true                         # Bật mã hóa phía client khi gửi lên S3
  }
}
```

#### Bước 3: Khởi chạy di chuyển State
Khi thêm hoặc thay đổi cấu hình `backend`, bạn cần chạy lệnh:

```powershell
terraform init
```

Terraform sẽ phát hiện cấu hình backend mới và hỏi bạn có muốn copy file local state hiện tại (nếu có) lên Remote Backend hay không. Nhập `yes` để hoàn tất quá trình di chuyển (migration).

---

## 2. Terraform Modules

### Module là gì?
Module là tập hợp các file cấu hình Terraform (`.tf`) nằm chung trong một thư mục. Bản chất mọi thư mục chứa mã nguồn Terraform đều được coi là một module.
- **Root Module**: Thư mục chứa cấu hình chính mà bạn đứng ở đó để chạy các lệnh `terraform init`, `terraform plan`, `terraform apply`.
- **Child Module**: Các module con được đóng gói riêng biệt để thực hiện một chức năng cụ thể (ví dụ: tạo VPC, tạo cụm ECS, tạo RDS database) và được gọi từ Root Module.

### Lợi ích của việc sử dụng Module
- **Tái sử dụng mã nguồn (Reusability)**: Viết cấu hình chuẩn một lần và sử dụng lại nhiều lần cho các môi trường khác nhau (Dev, Staging, Prod).
- **Quản lý độ phức tạp (Abstraction)**: Ẩn đi các chi tiết cấu hình phức tạp. Người dùng chỉ cần truyền các tham số đầu vào (Variables) và nhận kết quả đầu ra (Outputs).
- **Chuẩn hóa hạ tầng (Standardization)**: Đảm bảo toàn bộ hạ tầng trong tổ chức tuân thủ các quy tắc bảo mật và cấu hình chuẩn.

### Cấu trúc tiêu chuẩn của một Module độc lập
Một child module nên được tổ chức tối thiểu với cấu trúc sau:
```text
modules/
└── aws-s3-website/
    ├── README.md        # Tài liệu hướng dẫn sử dụng module
    ├── main.tf          # Định nghĩa các resource chính của module
    ├── variables.tf     # Các tham số đầu vào (Inputs)
    └── outputs.tf       # Các giá trị trả về sau khi tạo xong (Outputs)
```

### Ví dụ định nghĩa và gọi Module

#### 1. Định nghĩa Module (`modules/aws-s3-website/main.tf`...)
```hcl
# modules/aws-s3-website/variables.tf
variable "bucket_name" {
  description = "Tên duy nhất của S3 Bucket"
  type        = string
}

variable "tags" {
  description = "Tags cho S3 Bucket"
  type        = map(string)
  default     = {}
}

# modules/aws-s3-website/main.tf
resource "aws_s3_bucket" "website" {
  bucket = var.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }
}

# modules/aws-s3-website/outputs.tf
output "website_endpoint" {
  value       = aws_s3_bucket_website_configuration.website_config.website_endpoint
  description = "Domain name của trang web tĩnh S3"
}
```

#### 2. Gọi Module từ Root Module (`main.tf` của dự án)
```hcl
module "static_website" {
  source      = "./modules/aws-s3-website" # Đường dẫn local đến child module
  bucket_name = "npt-my-amazing-website-bucket-2026"
  
  tags = {
    Environment = "Dev"
    Project     = "Learning"
  }
}

# Sử dụng Output từ module
output "website_url" {
  value = module.static_website.website_endpoint
}
```

### Các nguồn Module (Module Sources)
Terraform hỗ trợ lấy module từ nhiều nguồn khác nhau thông qua thuộc tính `source`:
- **Local Paths**: Dùng đường dẫn tương đối (như ví dụ trên `./modules/aws-s3-website`). Dễ phát triển và chỉnh sửa nhanh.
- **Terraform Registry**: Sử dụng các module cộng đồng hoặc public của nhà cung cấp (ví dụ: `source = "terraform-aws-modules/vpc/aws"`).
- **Git Repository**: Lấy từ repo riêng. Có thể chỉ định tag/branch cụ thể để kiểm soát versioning:
  ```hcl
  source = "git::https://github.com/example/terraform-aws-vpc.git?ref=v1.2.0"
  ```

---

## 3. Terraform Best Practices

### Cấu trúc thư mục theo môi trường (Multi-Environment)
Có hai cách tiếp cận chính để quản lý nhiều môi trường (Dev, Staging, Production):

1. **Sử dụng Terraform Workspaces (Không khuyến khích cho hạ tầng production phức tạp)**:
   - Dùng chung một tập hợp code `.tf`, thay đổi state bằng lệnh `terraform workspace select <env>`.
   - **Hạn chế**: Dễ nhầm lẫn môi trường nếu quên chuyển workspace; các môi trường dùng chung biến nên khó tùy chỉnh chi tiết cấu hình khác biệt sâu giữa dev và prod.
2. **Sử dụng Directory-based separation (Khuyến khích)**:
   - Tách biệt hoàn toàn các file cấu hình và backend state của từng môi trường thành các thư mục riêng.
   - Ví dụ cấu trúc dự án:
     ```text
     ├── environments/
     │   ├── dev/
     │   │   ├── main.tf        # Gọi các module, khai báo backend s3 với key "dev/terraform.tfstate"
     │   │   ├── variables.tf
     │   │   └── terraform.tfvars
     │   └── prod/
     │       ├── main.tf        # Khai báo backend s3 với key "prod/terraform.tfstate"
     │       ├── variables.tf
     │       └── terraform.tfvars
     └── modules/
         ├── vpc/
         └── ec2/
     ```
   - **Ưu điểm**: Độc lập tuyệt đối về mặt state, giảm thiểu rủi ro khi thay đổi cấu hình môi trường Dev làm ảnh hưởng tới Production. Dễ dàng phân quyền IAM cho từng thư mục state.

### Quản lý Secrets an toàn
- **Không bao giờ** commit file chứa thông tin nhạy cảm (như `terraform.tfvars`, `*.pem`, credential keys) lên Git.
- Sử dụng file `.gitignore` để chặn các file nhạy cảm (xem lại note của Day A).
- Sử dụng biến môi trường có tiền tố `TF_VAR_` để truyền secret (ví dụ: `export TF_VAR_db_password="SuperSecretPassword"`).
- Khai báo thuộc tính `sensitive = true` trong variables để tránh ghi đè plaintext giá trị đó ra màn hình console khi chạy plan/apply:
  ```hcl
  variable "db_password" {
    type      = string
    sensitive = true
  }
  ```
- Sử dụng các Data Source để đọc secret trực tiếp từ AWS Secrets Manager hoặc HashiCorp Vault thay vì truyền cứng qua code.

### Lock file (`.terraform.lock.hcl`)
- File này chứa mã hash của các phiên bản Provider đã tải xuống trong quá trình chạy `terraform init`.
- **Nên commit** file `.terraform.lock.hcl` vào Git repo. Nó đảm bảo mọi thành viên trong team và hệ thống CI/CD sử dụng chính xác cùng một phiên bản provider nhị phân, tránh lỗi phát sinh do cập nhật tự động của provider.

### Quy tắc đặt tên và Coding Style (Style Guide)
- Luôn chạy `terraform fmt` trước khi commit để chuẩn hóa format code (thụt lề, căn lề tự động).
- Đặt tên tài nguyên rõ ràng và nhất quán:
  - Tên resource Terraform nên ở dạng số ít, viết thường, ngăn cách bằng dấu gạch dưới (snake_case), ví dụ: `aws_security_group.web_server_sg`.
  - Tên biến đầu vào (variables) nên mang tính mô tả rõ mục đích, ví dụ: `instance_count` thay vì `num`.
- Sử dụng Tags đầy đủ: Luôn gắn tags cho các tài nguyên cloud (ví dụ: `Environment`, `Owner`, `Project`) để dễ quản lý chi phí và phân loại tài nguyên.

---

## 4. Architecture Decision Record (ADR)

### ADR là gì?
**Architecture Decision Record (ADR)** là một tài liệu ngắn gọn, ghi lại một quyết định thiết kế kiến trúc quan trọng được đưa ra đối với hệ thống, cùng với bối cảnh lịch sử và hậu quả (hệ quả kéo theo) của quyết định đó.

### Tại sao cần ADR trong dự án Infrastructure as Code?
Hạ tầng thay đổi theo thời gian. Sau vài tháng hoặc vài năm, các câu hỏi thường gặp sẽ xuất hiện:
- *Tại sao chúng ta lại tách dự án thành nhiều thư mục môi trường thay vì dùng Workspace?*
- *Tại sao chúng ta lại tự viết module S3 mà không dùng module chính thức từ Registry?*
- *Tại sao chúng ta chọn sử dụng AWS DynamoDB làm lock table thay vì các giải pháp khác?*

ADR lưu lại lịch sử suy nghĩ của đội ngũ kỹ sư tại thời điểm đó, giúp người mới gia nhập dự án nhanh chóng nắm bắt lý do cấu trúc hệ thống được thiết kế như vậy.

### Cấu trúc tiêu chuẩn của một tài liệu ADR
Một tài liệu ADR thường bao gồm các phần chính sau:
1. **Title**: Tiêu đề quyết định (ví dụ: `ADR-001: Sử dụng cấu trúc thư mục Directory-based separation`).
2. **Status**: Trạng thái hiện tại của quyết định (Proposed - Đang đề xuất, Accepted - Đã chấp nhận, Superseded - Được thay thế bởi ADR khác, Deprecated - Đã lỗi thời).
3. **Context**: Bối cảnh, vấn đề gặp phải và các phương án giải quyết đã được xem xét.
4. **Decision**: Quyết định được lựa chọn và giải thích lý do tại sao phương án đó là tối ưu nhất.
5. **Consequences**: Hệ quả (mặt tích cực mang lại và những điểm hạn chế, đánh đổi kỹ thuật phải chấp nhận).

---

### Ví dụ ADR mẫu thực tế: Thiết lập cấu trúc môi trường Terraform

Dưới đây là một mẫu ADR chi tiết ghi lại quyết định tổ chức môi trường Terraform trong dự án:

```markdown
# ADR-001: Lựa chọn Directory-based Separation để quản lý Đa môi trường

## Status
Accepted

## Context
Dự án của chúng tôi cần triển khai hạ tầng trên ba môi trường độc lập: Dev, Staging và Production. Chúng tôi cần lựa chọn phương án tổ chức mã nguồn Terraform để quản lý và cô lập các môi trường này. Hai phương án chính đã được đưa ra cân nhắc:
1. **Phương án 1: Sử dụng Terraform Workspaces**
   - *Mô tả*: Dùng chung một bộ code Terraform, sử dụng state cô lập ảo qua câu lệnh workspace (`terraform workspace select <env>`).
2. **Phương án 2: Sử dụng Directory-based Separation (Cấu trúc thư mục độc lập)**
   - *Mô tả*: Tạo các thư mục riêng cho từng môi trường (environments/dev, environments/prod), mỗi thư mục khai báo một backend state riêng biệt và gọi chung các module chia sẻ tại thư mục `modules/`.

## Decision
Chúng tôi quyết định chọn **Phương án 2: Directory-based Separation**.

**Lý do lựa chọn:**
- **Cô lập an toàn tuyệt đối**: Việc tách biệt thư mục giúp tránh lỗi cấu hình chéo giữa các môi trường. Không sợ vô tình chạy `terraform destroy` nhầm trên môi trường Production khi đang làm việc trên Dev (vì file state của Production nằm ở một thư mục backend hoàn toàn khác).
- **Khác biệt hóa cấu hình dễ dàng**: Môi trường Production thường yêu cầu cấu hình phức tạp hơn (ví dụ: số lượng EC2 lớn hơn, kích thước RDS lớn hơn, bật Multi-AZ). Tách biệt thư mục giúp chúng tôi dễ dàng tùy biến mã nguồn cụ thể cho từng môi trường mà không phải viết các logic điều kiện phức tạp (`count = var.env == "prod" ? 3 : 1`) trong code.
- **Phân quyền IAM tốt hơn**: Chúng tôi có thể phân quyền IAM chặt chẽ cho các kỹ sư: kỹ sư junior chỉ có quyền ghi vào S3 bucket state của Dev, trong khi chỉ có hệ thống CI/CD hoặc tech lead mới có quyền ghi vào S3 bucket state của Production.

## Consequences
### Điểm tốt (Consequences - Positive):
- Tăng tính an toàn và giảm thiểu rủi ro lỗi do con người gây ra trên Production.
- Cấu hình từng môi trường trực quan, rõ ràng và dễ bảo trì.
- Dễ dàng tích hợp vào luồng CI/CD (mỗi nhánh Git hoặc thư mục thay đổi sẽ trigger pipeline tương ứng).

### Điểm hạn chế (Consequences - Negative):
- Xuất hiện hiện tượng lặp lại code cấu hình ở mức độ khai báo Root Module (như khai báo block provider, backend config, input values).
- Khi có thay đổi cấu hình hạ tầng chung, kỹ sư phải cập nhật thủ công các file gọi module ở cả ba thư mục môi trường.
```

---

## 5. Tài liệu tham khảo

- [Terraform Remote State with AWS S3 & DynamoDB](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [How to structure Terraform Projects](https://developer.hashicorp.com/terraform/tutorials/modules/pattern-module-creation)
- [Terraform Module Best Practices](https://developer.hashicorp.com/terraform/language/modules)
- [Documenting Architecture Decisions (ADR)](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [Terraform Style Guide and Naming Conventions](https://developer.hashicorp.com/terraform/language/syntax/style)

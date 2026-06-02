# Terraform Learning Notes

## 1. Infrastructure as Code (IaC)

Việc tạo hạ tầng thủ công, chẳng hạn thao tác trực tiếp trên giao diện AWS, có một số hạn chế:

- Khó tái tạo chính xác cùng một môi trường.
- Dễ xảy ra sai lệch cấu hình (configuration drift) khi có thay đổi thủ công.
- Khó review thay đổi trước khi triển khai.

Infrastructure as Code (IaC) giải quyết vấn đề này bằng cách mô tả hạ tầng dưới dạng mã nguồn. Các file cấu hình có thể lưu trữ và theo dõi lịch sử thay đổi bằng Git.

Terraform là một công cụ IaC theo hướng khai báo (declarative). Thay vì viết từng bước thao tác, người dùng mô tả trạng thái hạ tầng mong muốn. Terraform xác định những thay đổi cần thực hiện để đưa hạ tầng thực tế về trạng thái đó.

## 2. Các thành phần cơ bản của Terraform

### Template files (`.tf`)

Các file cấu hình được viết bằng HashiCorp Configuration Language (HCL), dùng để mô tả hạ tầng mong muốn.

### Providers

Provider là plugin giúp Terraform tương tác với API của nền tảng hoặc dịch vụ bên ngoài, chẳng hạn AWS, Azure hoặc Google Cloud.

### Resources

Resource là thành phần hạ tầng được Terraform quản lý, ví dụ máy ảo, mạng, storage hoặc dịch vụ cloud.

### Terraform CLI

Terraform CLI cung cấp các lệnh để khởi tạo môi trường làm việc, kiểm tra cấu hình, xem trước thay đổi, triển khai và xóa hạ tầng.

### State files

Terraform lưu trạng thái để ánh xạ resource trong cấu hình với tài nguyên thực tế. State giúp Terraform xác định thay đổi cần thực hiện trong các lần chạy tiếp theo.

Không commit file state lên Git vì state có thể chứa dữ liệu nhạy cảm. Khi làm việc theo nhóm, cần lưu state trong remote backend có cơ chế kiểm soát truy cập và locking.

### Variables and outputs

- Variable giúp tùy chỉnh cấu hình mà không phải sửa trực tiếp logic chính.
- Output giúp lấy các giá trị cần sử dụng sau khi hạ tầng được tạo, chẳng hạn ID hoặc địa chỉ IP.

## 3. Quy trình triển khai cơ bản

### Bước 1: Khởi tạo

```powershell
terraform init
```

Khởi tạo working directory, tải provider plugin và module cần thiết. Đây là lệnh đầu tiên cần chạy sau khi tạo hoặc clone một Terraform configuration.

### Bước 2: Kiểm tra định dạng và cấu hình

```powershell
terraform fmt
terraform validate
```

- `terraform fmt` chuẩn hóa định dạng file cấu hình.
- `terraform validate` kiểm tra cấu hình có hợp lệ hay không.

### Bước 3: Lập kế hoạch

```powershell
terraform plan
```

Xem trước resource nào sẽ được thêm, chỉnh sửa hoặc xóa. Lệnh này không thay đổi hạ tầng thực tế.

### Bước 4: Áp dụng thay đổi

```powershell
terraform apply
```

Terraform hiển thị plan và yêu cầu xác nhận trước khi tạo, chỉnh sửa hoặc xóa resource.

### Bước 5: Xóa hạ tầng khi không còn sử dụng

```powershell
terraform destroy
```

Lệnh này xóa toàn bộ resource đang được Terraform quản lý trong working directory và workspace hiện tại. Cần kiểm tra kỹ trước khi xác nhận.

## 4. Cài đặt Terraform trên Windows

### Cách cài đặt bằng file binary

1. Truy cập trang cài đặt chính thức: <https://developer.hashicorp.com/terraform/install>
2. Trong mục **Windows**, tải file ZIP phù hợp với kiến trúc máy, thường là `AMD64`.
3. Giải nén file ZIP. Bên trong có file `terraform.exe`.
4. Tạo thư mục để lưu chương trình, ví dụ:

   ```text
   C:\tools\terraform
   ```

5. Di chuyển `terraform.exe` vào thư mục vừa tạo.
6. Thêm `C:\tools\terraform` vào biến môi trường `Path`:
   - Mở Start Menu và tìm `Environment Variables`.
   - Chọn **Edit the system environment variables**.
   - Chọn **Environment Variables**.
   - Trong `User variables`, chọn `Path` rồi chọn **Edit**.
   - Chọn **New**, thêm `C:\tools\terraform`, sau đó lưu thay đổi.
7. Mở cửa sổ PowerShell mới và kiểm tra:

   ```powershell
   terraform -version
   ```

Nếu lệnh hiển thị phiên bản Terraform, quá trình cài đặt đã hoàn tất.

## 5. Các file không nên commit

Khi thực hành Terraform, cần thêm các nội dung sau vào `.gitignore`:

```gitignore
.terraform/
*.tfstate
*.tfstate.*
crash.log
crash.*.log
*.tfplan
```

File `.terraform.lock.hcl` nên được commit để các lần chạy sau sử dụng nhất quán phiên bản provider đã chọn.

## 6. Tài liệu tham khảo

- [Install Terraform](https://developer.hashicorp.com/terraform/install)
- [Terraform CLI overview](https://developer.hashicorp.com/terraform/cli/commands)
- [Initialize the working directory](https://developer.hashicorp.com/terraform/cli/init)
- [Terraform workflow](https://developer.hashicorp.com/terraform/cli/run)
- [Terraform state](https://developer.hashicorp.com/terraform/language/state)

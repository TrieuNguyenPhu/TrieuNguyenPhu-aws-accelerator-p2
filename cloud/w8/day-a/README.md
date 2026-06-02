**. Tổng quan về Cơ sở hạ tầng dưới dạng Mã (Infrastructure as Code - IaC)**

Việc tạo hạ tầng thủ công (như click trên giao diện web của AWS) thường gặp ba rắc rối lớn: **không thể tái tạo** chính xác một hệ thống y hệt, **sai lệch cấu hình (configuration drift)** khi ai đó tự ý chỉnh sửa bằng tay, và **không thể kiểm duyệt (review)** trước khi thay đổi. 

IaC giải quyết vấn đề này bằng cách mô tả hạ tầng thông qua các tệp cấu hình có thể lưu trữ trên Git, giống hệt như mã nguồn phần mềm. Từ các tệp này, một công cụ sẽ biến đổi chúng thành hạ tầng thực tế, cho phép bạn dễ dàng chạy lại, phát hiện sai lệch và đánh giá rủi ro (đọc diff) trước khi thực thi.

Terraform là một công cụ IaC hoạt động theo cơ chế **khai báo (declarative)**. Điều này có nghĩa là bạn chỉ cần viết ra trạng thái hạ tầng mà bạn *mong muốn* (ví dụ: "Tôi muốn một máy chủ EC2 kèm theo IP tĩnh"), Terraform sẽ tự tính toán các lệnh API cần gọi và thứ tự thực hiện để biến điều đó thành hiện thực, thay vì bạn phải viết các bước chạy tuần tự.


**. Vòng đời cơ bản (Init / Plan / Apply / Destroy)**

Cách làm việc với Terraform gói gọn trong một quy trình lõi gồm các lệnh CLI nối tiếp nhau:

*   **`terraform init` (Khởi tạo):** Chuẩn bị thư mục làm việc của bạn. Lệnh này tải xuống các plugin của nhà cung cấp (Provider, như AWS, Azure) và các module cần thiết để Terraform có thể giao tiếp với các hệ thống đó.
*   **`terraform plan` (Lên kế hoạch):** Xem trước những gì sẽ xảy ra. Lệnh này so sánh trạng thái mong muốn (code bạn viết) với trạng thái hiện tại của hạ tầng, từ đó đưa ra một "kế hoạch thực thi" mô tả chi tiết những tài nguyên nào sẽ được tạo mới, sửa đổi, hay xóa đi. Bước này hoàn toàn an toàn và chưa tạo ra bất kỳ thay đổi nào trên thực tế.
*   **`terraform apply` (Áp dụng):** Thực thi bản kế hoạch. Nếu bạn đồng ý với kế hoạch từ bước trước, lệnh này sẽ chính thức gọi các API để tạo hoặc cập nhật hạ tầng thực tế theo đúng trình tự phụ thuộc hợp lý nhất.
*   **`terraform destroy` (Tiêu hủy):** Khi không còn cần dùng hệ thống nữa, lệnh này sẽ tháo dỡ và xóa bỏ toàn bộ các tài nguyên hạ tầng đã được cấu hình và tạo ra trước đó.
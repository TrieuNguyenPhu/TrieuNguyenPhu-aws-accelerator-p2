# Secrets Rotation & Supply Chain Security — Quản lý Bí mật và An toàn Chuỗi cung ứng

Bản ghi chép này tổng hợp các kiến thức nâng cao về quản lý Secrets động bằng External Secrets Operator (ESO), quy trình xoay vòng bí mật, và các giải pháp bảo mật chuỗi cung ứng phần mềm (Container Scanning, Image Signing & Verification).

---

## 1. Quản lý Secrets Động & External Secrets Operator (ESO)

Quản lý thông tin nhạy cảm (secrets) trong môi trường Cloud Native đòi hỏi một vòng đời khép kín bao gồm: Khởi tạo, Lưu trữ, Truy xuất, Xoay vòng (Rotation) và Thu hồi.

### 1.1. Cơ chế hoạt động của ESO:
**External Secrets Operator (ESO)** hoạt động theo mô hình **Pull-based**. Nó kết nối và kéo secret trực tiếp từ các Cloud Provider API (như AWS Secrets Manager) về cụm Kubernetes dưới dạng tài nguyên `Secret` native.

*   **SecretStore:** Tài nguyên phạm vi Namespace khai báo cách kết nối và phương thức xác thực (ví dụ: sử dụng IRSA - IAM Roles for Service Accounts) tới AWS Secrets Manager.
*   **ClusterSecretStore:** Tương tự `SecretStore` nhưng có phạm vi toàn cụm, dùng chung cho nhiều Namespace.
*   **ExternalSecret:** Khai báo cụ thể khóa (key) nào cần lấy từ Secret Store ngoài và ánh xạ thành tên Kubernetes Secret nào.

### 1.2. So sánh ESO vs Sealed Secrets

| Tiêu chí | External Secrets Operator (ESO) | Bitnami Sealed Secrets |
| :--- | :--- | :--- |
| **Cơ chế** | **Pull-based:** Kéo secret từ AWS Secrets Manager/Vault về cụm. | **Push-based:** Mã hóa secret ở máy client và commit lên Git. |
| **Xoay vòng (Rotation)** | **Tự động:** Hỗ trợ tự động cập nhật khi secret nguồn thay đổi. | **Thủ công:** Phải mã hóa lại thủ công và push commit mới lên Git. |
| **Bảo mật gốc** | Lưu trữ tập trung trên Cloud HSM chuyên dụng. | Khóa Private Key giải mã nằm duy nhất trong cụm K8s. |
| **Khuyến nghị** | Phù hợp dự án chạy trên Cloud (AWS/GCP/Azure) cần tuân thủ bảo mật cao. | Phù hợp dự án chạy On-Premise hoặc mô hình GitOps thuần túy. |

### 1.3. Xoay vòng Secrets (Rotation) không cần Restart Pod
*   **Vấn đề:** Khi cập nhật secret trong K8s, nếu Pod nhận secret qua **Environment Variables (Biến môi trường)**, ứng dụng sẽ không nhận được giá trị mới trừ khi ta restart lại Pod.
*   **Giải pháp:** Mount secret dưới dạng **Volume Mounts**. Kubernetes sẽ tự động cập nhật nội dung file secret trong container sau một khoảng thời gian (kubelet sync). Kết hợp với thuộc tính `refreshInterval: 1m` trong `ExternalSecret`, ta có thể xoay vòng secret trong vòng dưới 60 giây mà không cần restart Pod. Ứng dụng chỉ cần đọc lại file cấu hình định kỳ.

---

## 2. Bảo mật Chuỗi cung ứng (Supply Chain Security)

Bảo mật không chỉ giới hạn trong runtime mà phải bắt đầu ngay từ khâu viết code và đóng gói image (Shift Left Security).

### 2.1. Quét lỗ hổng Image bằng Trivy trong CI Pipeline
*   **Trivy:** Công cụ quét bảo mật mạnh mẽ và nhanh chóng cho Container Images, File system, Git Repositories.
*   **Tích hợp CI:** Chèn bước quét Trivy vào GitHub Actions trước khi push image lên registry:
    ```yaml
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: 'my-app:${{ github.sha }}'
        format: 'table'
        exit-code: '1' # Làm lỗi pipeline nếu phát hiện lỗi bảo mật nghiêm trọng
        severity: 'CRITICAL,HIGH'
    ```

### 2.2. Ký ảnh Container (Image Signing) bằng Cosign
*   **Cosign (Sigstore):** Công cụ dùng để ký và xác thực chữ ký của container image nhằm chứng minh nguồn gốc hình ảnh tin cậy, ngăn chặn tấn công giả mạo hình ảnh (Image Spoofing/Tampering).
*   **Key-based Signing:** Tạo cặp khóa public/private key để ký.
*   **Keyless Signing (OIDC):** Ký không cần quản lý khóa riêng, sử dụng định danh OIDC của GitHub Actions runner để chứng thực và lưu trữ log công khai trên Recor (sigstore transparency log).

### 2.3. Xác thực chữ ký ở Admission Controller (Verify Signature)
*   Sử dụng admission webhooks như **Kyverno** để áp dụng chính sách kiểm soát:
    *   API Server nhận yêu cầu tạo Pod.
    *   Kyverno đánh chặn yêu cầu và liên lạc với registry để kiểm tra xem image của Pod đó có chữ ký hợp lệ từ khóa Public Key đã đăng ký hay không.
    *   Nếu image không được ký hoặc chữ ký giả mạo, Kyverno sẽ từ chối tạo Pod ngay lập tức.

### 2.4. Xử lý ngoại lệ CVE qua ADR và `.trivyignore`
Trong thực tế, có những lỗ hổng bảo mật cấp HIGH/CRITICAL xuất hiện trong các thư viện base image mà ta chưa thể fix ngay được (chờ nhà phát hành vá). Để tránh làm tắc nghẽn CI/CD pipeline, ta xử lý qua:
1.  **ADR (Architecture Decision Record):** Ghi chép lại lý do tại sao chấp nhận rủi ro này, các biện pháp giảm thiểu thay thế, và thời hạn khắc phục.
2.  `.trivyignore`:** Liệt kê ID của CVE cần bỏ qua (ví dụ: `CVE-2026-XXXX`) kèm ghi chú thời gian hết hạn của ngoại lệ đó.

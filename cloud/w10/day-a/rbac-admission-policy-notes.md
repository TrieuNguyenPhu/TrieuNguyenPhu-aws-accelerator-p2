# RBAC & Admission Policy — Kiểm soát Quyền truy cập và Chính sách Cụm

Bản ghi chép này tổng hợp các kiến thức quan trọng về phân quyền dựa trên vai trò (RBAC), cách kiểm tra quyền hạn, và cơ chế thực thi chính sách cụm thông qua OPA Gatekeeper và ValidatingAdmissionPolicy (VAP).

---

## 1. Kubernetes RBAC (Role-Based Access Control)

Kubernetes kiểm soát quyền truy cập API của người dùng (User) và ứng dụng (ServiceAccount) bằng cơ chế RBAC.

### 1.1. Các thành phần chính:
*   **Role (Quyền trong Namespace):** Định nghĩa các hành động (`verbs`) được phép thực hiện trên các tài nguyên (`resources`) cụ thể trong một Namespace duy nhất.
*   **ClusterRole (Quyền cấp Cụm):** Giống như Role nhưng có phạm vi toàn cụm. Nó được dùng cho các tài nguyên không thuộc Namespace (như Nodes, PersistentVolumes) hoặc để cấp quyền trên tất cả các Namespace.
*   **RoleBinding:** Liên kết một Role (hoặc ClusterRole) với các đối tượng (`Subjects` bao gồm User, Group, ServiceAccount) trong phạm vi Namespace đó.
*   **ClusterRoleBinding:** Liên kết một ClusterRole với các đối tượng trên phạm vi toàn cụm (tất cả Namespaces).

### 1.2. ServiceAccount Security
*   **ServiceAccount (SA):** Định danh dành riêng cho các tiến trình chạy bên trong Pod để giao tiếp với API Server.
*   **Best Practices:**
    *   **Nguyên tắc Least Privilege:** Tránh gán quyền admin cho SA mặc định (`default`). Tạo SA riêng cho từng workload.
    *   **automountServiceAccountToken: false:** Nếu Pod không cần tương tác với Kubernetes API, hãy tắt tính năng tự động gắn token của SA để giảm thiểu rủi ro bị hacker đánh cắp token khi Pod bị compromise.

### 1.3. Xác thực quyền bằng `kubectl auth can-i`
Để kiểm tra xem một tài khoản hoặc SA có quyền thực hiện hành động nào đó hay không mà không cần đổi file cấu hình kubeconfig:
```powershell
# Kiểm tra tài khoản hiện tại có được tạo pod không
kubectl auth can-i create pods

# Giả lập quyền của một ServiceAccount cụ thể
kubectl auth can-i list secrets --as=system:serviceaccount:production:app-sa -n production
```

---

## 2. OPA Gatekeeper (Admission Controller)

**OPA Gatekeeper** hoạt động như một Validation Webhook chặn hoặc cho phép các yêu cầu gửi đến API Server trước khi tài nguyên được ghi vào etcd.

### 2.1. Kiến trúc ConstraintTemplate và Constraint:
*   **ConstraintTemplate (Mẫu chính sách):** Định nghĩa **logic kiểm tra** viết bằng ngôn ngữ Rego và schema khai báo các tham số đầu vào.
*   **Constraint (Áp dụng chính sách):** Khai báo các tham số cụ thể và chỉ định phạm vi áp dụng (ví dụ: áp dụng cho tất cả namespaces ngoại trừ `kube-system`).

### 2.2. Chế độ thực thi (Enforcement Action):
*   **Enforce (Deny):** Chặn trực tiếp và trả về lỗi forbidden ngay trên terminal của người dùng nếu vi phạm chính sách.
*   **Audit (dryrun):** Cho phép triển khai tài nguyên vi phạm nhưng ghi nhận lại lỗi trong trạng thái (`status`) của Constraint để quản trị viên theo dõi và lên kế hoạch xử lý sau.

---

## 3. Kubernetes Native ValidatingAdmissionPolicy (VAP)

Bắt đầu từ Kubernetes **1.30+**, tính năng **ValidatingAdmissionPolicy** đã được kích hoạt chính thức (GA/Beta). Đây là giải pháp thay thế cực kỳ mạnh mẽ cho Gatekeeper.

### 3.1. Điểm nổi bật của VAP:
*   **Native & Lightweight:** Tích hợp trực tiếp vào K8s API Server, không cần cài đặt thêm webhook server bên ngoài, giảm thiểu tối đa độ trễ (latency) của request.
*   **Sử dụng CEL (Common Expression Language):** Thay vì dùng ngôn ngữ Rego phức tạp, VAP sử dụng CEL - một ngôn ngữ lập trình biểu thức đơn giản, dễ đọc và tối ưu hiệu năng.

### 3.2. So sánh Gatekeeper và ValidatingAdmissionPolicy (VAP)

| Tiêu chí | OPA Gatekeeper | ValidatingAdmissionPolicy (VAP) |
| :--- | :--- | :--- |
| **Giao thức** | Webhook HTTPS ngoại vi. | Tích hợp sẵn (K8s Native). |
| **Ngôn ngữ viết luật** | Rego (Phức tạp, khai báo logic mạnh). | CEL (Common Expression Language - Đơn giản, nhẹ). |
| **Độ trễ (Latency)** | Cao hơn do phải truyền data ra webhook pod bên ngoài. | Cực thấp (Xử lý trực tiếp trong tiến trình API Server). |
| **Độ tin cậy** | Có thể bị sập cụm nếu Webhook Pod bị treo hoặc quá tải. | Cực kỳ ổn định do chạy song song với API Server. |
| **Khả năng mutate** | Hỗ trợ thay đổi manifest khi tạo (Mutating). | Chỉ hỗ trợ kiểm tra tính hợp lệ (Validating). |

*Ví dụ biểu thức CEL đơn giản trong VAP để kiểm tra container bắt buộc chạy non-root:*
```yaml
spec:
  validation:
    - expression: "object.spec.containers.all(c, has(c.securityContext) && has(c.securityContext.runAsNonRoot) && c.securityContext.runAsNonRoot == true)"
      message: "Tat ca container trong pod bat buoc phai dat runAsNonRoot la true"
```

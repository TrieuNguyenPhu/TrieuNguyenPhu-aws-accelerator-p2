# GitOps & CI/CD — Giao hàng Thông minh và Tự động hóa

Bản ghi chép này tóm tắt các kiến thức cốt lõi về mô hình GitOps, so sánh các công cụ phổ biến, cách thiết kế CI/CD pipeline và chiến lược khôi phục hệ thống (Rollback) trong Kubernetes.

---

## 1. Nguyên lý GitOps

**GitOps** là một mô hình vận hành và triển khai phần mềm, trong đó Git đóng vai trò là **nguồn sự thật duy nhất (Single Source of Truth)** cho toàn bộ trạng thái mong muốn của hệ thống (hạ tầng lẫn ứng dụng).

### 4 Nguyên lý cốt lõi (theo OpenGitOps):
1. **Khai báo (Declarative):** Toàn bộ trạng thái hệ thống phải được mô tả bằng manifest file khai báo (ví dụ: K8s YAML, Terraform).
2. **Phiên bản & Bất biến (Versioned and Immutable):** Trạng thái mong muốn được lưu trữ trong Git, kế thừa mọi thuộc tính về lịch sử commit, phân quyền, review (PR) và không thể bị sửa đổi tùy tiện.
3. **Kéo tự động (Pulled Automatically):** Tác nhân phần mềm (Agent) tự động phát hiện sự thay đổi giữa Git và thực tế.
4. **Liên tục đối soát & Tự phục hồi (Continuous Reconciliation & Self-healing):** Hệ thống liên tục so sánh trạng thái thực tế với Git. Nếu phát hiện sai lệch (Drift), agent sẽ tự động đồng bộ (Sync) hoặc phục hồi trạng thái cũ nếu có ai đó sửa đổi thủ công trên cụm.

---

## 2. GitHub Actions trong GitOps Pipeline

CI/CD trong GitOps thường chia làm hai phần: **CI (Continuous Integration)** kiểm tra và build image, và **CD (Continuous Delivery)** đồng bộ manifest lên cụm thông qua GitOps controller.

*   **Workflow: Plan on Pull Request (PR-driven Validation):**
    *   Kích hoạt khi có PR mở vào nhánh chính (`main`/`master`).
    *   Nhiệm vụ: Chạy linter (`yamllint`), kiểm tra cấu hình K8s (`kubeconform` hoặc `pluto`), hoặc chạy dry-run để kiểm tra tính hợp lệ của manifest trước khi merge.
*   **Workflow: Apply on Merge (Tag & Sync):**
    *   Kích hoạt sau khi PR được phê duyệt và merge vào nhánh chính.
    *   Nhiệm vụ: Cập nhật tag image mới vào repository cấu hình manifest (thường là một Git repo riêng biệt với mã nguồn ứng dụng) để kích hoạt quá trình tự động đồng bộ của GitOps controller.

---

## 3. So sánh ArgoCD và FluxCD

| Tiêu chí | ArgoCD | Flux (FluxCD) |
| :--- | :--- | :--- |
| **Kiến trúc** | Sử dụng Webhook/Poller tập trung, chạy dưới dạng một bộ controller quản lý Application CRD. | Kiến trúc Microservices phân tán (Source controller, Kustomize controller, Helm controller). |
| **Giao diện người dùng (UI)** | Cung cấp giao diện Web UI trực quan, mạnh mẽ để xem cấu trúc và trạng thái tài nguyên. | Không có giao diện UI chính thức (dựa vào CLI hoặc các extension bên thứ ba). |
| **Khả năng quản lý** | Phù hợp quản lý nhiều ứng dụng, nhiều cụm tập trung (Multi-tenant, Multi-cluster). | Thiết kế tối giản, bảo mật cao, tích hợp sâu với cấu trúc Kustomize và Helm native. |
| **Độ dốc học tập** | Thân thiện, dễ học nhờ giao diện trực quan trực tiếp. | Yêu cầu hiểu sâu về Kustomize, Helm và vận hành qua CLI. |

---

## 4. Mô hình App of Apps Pattern trong ArgoCD

Khi số lượng ứng dụng tăng lên, việc khai báo thủ công từng ứng dụng trên giao diện ArgoCD sẽ trở nên bất khả thi. **App of Apps** là mẫu thiết kế giải quyết vấn đề này.

*   **Nguyên lý:** Định nghĩa một Application cha (Root Application) trong ArgoCD. 
*   **Hoạt động:** Thay vì trỏ đến source code của app, Root Application trỏ đến một thư mục chứa các manifest khai báo các Application con (Child Applications). Khi áp dụng Root Application, ArgoCD sẽ tự động quét và tạo toàn bộ các Application con, từ đó triển khai toàn bộ tài nguyên (Web, API, DB, Monitoring...) lên cụm chỉ với 1 click duy nhất.

```text
Root Application (App-of-Apps)
 ├── Application Con 1 (kube-prometheus-stack)
 ├── Application Con 2 (argo-rollouts)
 ├── Application Con 3 (database-mysql)
 └── Application Con 4 (frontend-web)
```

---

## 5. Đồng bộ hóa có thứ tự: Sync Waves

Mặc định, Kubernetes API sẽ cố gắng áp dụng tất cả các manifests đồng thời. Điều này dẫn đến việc Pod khởi động lỗi do Database chưa sẵn sàng, hoặc CRD chưa được đăng ký trước khi tạo Custom Resource.

**Sync Waves** trong ArgoCD giải quyết việc này thông qua annotation:
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "5"
```
*   **Thứ tự thực thi:** Sóng (Wave) có giá trị thấp nhất sẽ được triển khai trước (ví dụ: `-5`, `0`). Các sóng có giá trị lớn hơn sẽ chỉ được áp dụng khi các tài nguyên thuộc sóng trước đó đã ở trạng thái **Healthy**.
*   **Ví dụ phân phối sóng chuẩn:**
    1.  Wave `-10`: Namespace, Custom Resource Definitions (CRDs).
    2.  Wave `-5`: Secrets, ConfigMaps, Storage Classes.
    3.  Wave `0`: Deployments, StatefulSets (Workloads).
    4.  Wave `5`: Services, Ingress, NetworkPolicies.

---

## 6. Chiến lược Khôi phục (Rollback)

Khi phiên bản mới deploy lên gặp lỗi, ta có hai phương án xử lý:

### Phương án 1: Git Revert (Khuyến nghị cho GitOps)
*   **Cách làm:** Sử dụng lệnh `git revert <commit_hash>` trên nhánh `main` để đảo ngược thay đổi và đẩy commit mới lên Git. ArgoCD sẽ phát hiện thay đổi và đồng bộ hạ tầng quay về trạng thái trước đó.
*   **Ưu điểm:** Đảm bảo tính nhất quán tối đa. Git vẫn giữ vai trò là "nguồn sự thật duy nhất". Lịch sử thay đổi được ghi nhận đầy đủ phục vụ audit.
*   **Nhược điểm:** Tốc độ phản ứng có thể bị trễ một chút do phụ thuộc vào thời gian chạy CI pipeline và thời gian poll/sync của ArgoCD.

### Phương án 2: `kubectl rollout undo` (Khôi phục khẩn cấp)
*   **Cách làm:** Chạy lệnh trực tiếp trên cluster để rollback Deployment: `kubectl rollout undo deployment/web -n demo`.
*   **Ưu điểm:** Khôi phục ngay tức thì trong vài giây, giảm thiểu downtime tối đa khi gặp sự cố nghiêm trọng.
*   **Nhược điểm:** Gây ra hiện tượng **Out of Sync** (sai lệch cấu hình) giữa Git và cluster. ArgoCD sẽ báo lỗi và nếu bật tính năng `Self-Heal`, ArgoCD sẽ lập tức ghi đè và mang phiên bản lỗi trên Git quay lại cụm. Do đó, phương pháp này chỉ dùng khi đã tạm thời tắt auto-sync hoặc phải nhanh chóng thực hiện Git Revert song song.

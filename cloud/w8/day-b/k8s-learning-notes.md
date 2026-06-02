# Kubernetes Learning Notes

## 1. Vì sao cần Container và Orchestration

Trước khi học Kubernetes, cần nắm hai khái niệm nền:

- **Container** là cách đóng gói ứng dụng cùng runtime, thư viện và cấu hình cần thiết để chạy nhất quán giữa máy local, test và production.
- **Container orchestration** là lớp điều phối giúp triển khai, scale, tự phục hồi và quản lý mạng cho nhiều container trên nhiều node.

Nếu chỉ chạy container đơn lẻ bằng Docker, việc quản lý còn đơn giản. Nhưng khi hệ thống có nhiều service, cần rolling update, service discovery, health check và tự động restart, cần một platform orchestration như Kubernetes.

## 2. Kubernetes là gì

Kubernetes (K8s) là nền tảng orchestration mã nguồn mở để quản lý workload dạng container theo mô hình khai báo.

Thay vì thao tác thủ công từng container, người dùng mô tả trạng thái mong muốn, ví dụ:

- Ứng dụng cần chạy bao nhiêu bản sao.
- Ứng dụng lắng nghe qua cổng nào.
- Cấu hình nào được inject vào runtime.
- Pod nào được phép giao tiếp với Pod nào.

Kubernetes sẽ cố gắng đưa trạng thái thực tế của cluster về đúng trạng thái mong muốn đó.

## 3. Pod

Pod là đơn vị triển khai nhỏ nhất trong Kubernetes. Một Pod có thể chứa một hoặc nhiều container chia sẻ:

- Network namespace, bao gồm IP và port space.
- Storage volume nếu được mount chung.
- Vòng đời triển khai và restart.

Thông thường, một Pod chỉ nên chứa một container chính. Mô hình nhiều container trong cùng Pod thường dành cho sidecar, ví dụ log shipper hoặc proxy.

Một số điểm cần nhớ:

- Pod có IP riêng, nhưng IP này không ổn định lâu dài.
- Khi Pod bị recreate, IP có thể thay đổi.
- Không nên để ứng dụng phụ thuộc trực tiếp vào IP của Pod.

## 4. Service

Service là abstraction cung cấp địa chỉ truy cập ổn định cho một nhóm Pod.

Service giải quyết các vấn đề:

- Pod có thể chết và được tạo lại với IP mới.
- Ứng dụng khác cần một endpoint cố định để gọi tới.
- Cần load balancing traffic giữa nhiều Pod giống nhau.

Các loại Service cơ bản:

### ClusterIP

Loại mặc định, chỉ truy cập được bên trong cluster. Phù hợp cho giao tiếp nội bộ giữa các service.

### NodePort

Expose service qua một port trên node. Có thể truy cập từ bên ngoài bằng `NodeIP:NodePort`, nhưng ít phù hợp cho production nếu dùng trực tiếp.

### LoadBalancer

Tích hợp với cloud provider để tạo external load balancer phía trước service. Phù hợp khi cần public ứng dụng ra ngoài.

## 5. Probes

Probe là cơ chế để Kubernetes kiểm tra trạng thái container và quyết định có nên restart hay route traffic tới container đó hay không.

Ba loại probe quan trọng:

### Liveness probe

Kiểm tra container còn sống đúng nghĩa hay không. Nếu liveness probe fail liên tục, Kubernetes sẽ restart container.

Dùng khi:

- Ứng dụng bị deadlock.
- Process còn chạy nhưng không còn xử lý request đúng cách.

### Readiness probe

Kiểm tra container đã sẵn sàng nhận traffic chưa. Nếu readiness probe fail, Pod vẫn tồn tại nhưng sẽ bị loại khỏi danh sách endpoint của Service.

Dùng khi:

- Ứng dụng cần thời gian warm up.
- Ứng dụng phụ thuộc database hoặc service khác trước khi sẵn sàng.

### Startup probe

Dùng cho ứng dụng khởi động chậm. Trong giai đoạn startup probe chưa pass, Kubernetes chưa áp dụng liveness probe bình thường.

Điểm thực tế:

- Thiếu readiness probe dễ làm traffic bị route vào Pod chưa sẵn sàng.
- Cấu hình liveness probe quá gắt dễ gây restart vòng lặp.
- Startup probe hữu ích cho Java app, app init dữ liệu lớn hoặc workload khởi động lâu.

## 6. ConfigMap và Secret

Kubernetes tách cấu hình khỏi image để tránh hard-code giá trị môi trường trong container image.

### ConfigMap

ConfigMap dùng để lưu dữ liệu cấu hình không nhạy cảm, ví dụ:

- Tên environment.
- URL nội bộ.
- Feature flags.
- File cấu hình ứng dụng.

ConfigMap có thể được inject vào Pod qua:

- Environment variables.
- File mount vào volume.

### Secret

Secret dùng cho dữ liệu nhạy cảm như:

- Mật khẩu database.
- API token.
- SSH key.
- TLS certificate.

Cần nhớ:

- Secret trong K8s chỉ là base64-encoded, không tự động mã hóa mạnh nếu không cấu hình thêm.
- Trong production nên kết hợp encryption at rest và kiểm soát RBAC chặt chẽ.
- Không commit secret thật vào Git.

## 7. NetworkPolicy

Mặc định, nhiều cluster cho phép Pod giao tiếp khá rộng nếu chưa có policy chặn lại. NetworkPolicy giúp kiểm soát luồng traffic giữa Pod với Pod hoặc từ bên ngoài vào Pod.

NetworkPolicy thường dùng để áp dụng nguyên tắc **least privilege** trong mạng nội bộ cluster:

- Chỉ cho frontend gọi backend.
- Chỉ cho backend gọi database.
- Chặn các Pod không liên quan truy cập service nội bộ.

Hai hướng policy chính:

- **Ingress**: kiểm soát traffic đi vào Pod.
- **Egress**: kiểm soát traffic đi ra từ Pod.

Lưu ý:

- NetworkPolicy chỉ hoạt động nếu CNI plugin của cluster hỗ trợ.
- Nếu không thiết kế policy, cluster dễ bị giao tiếp quá rộng giữa các workload.

## 8. Quan hệ giữa các thành phần

Luồng tư duy cơ bản khi đọc một ứng dụng trên Kubernetes:

1. Ứng dụng chạy trong **Pod**.
2. Nhiều Pod cùng loại được expose qua **Service**.
3. **Probes** quyết định Pod có khỏe và sẵn sàng nhận traffic hay không.
4. **ConfigMap/Secret** cung cấp cấu hình và thông tin nhạy cảm cho Pod.
5. **NetworkPolicy** giới hạn Pod nào được phép giao tiếp.

Đây là bộ kiến thức nền quan trọng trước khi học sâu hơn về Deployment, Ingress, StatefulSet, volume, autoscaling và observability.

## 9. Tài liệu tham khảo

- [Kubernetes Concepts Overview](https://kubernetes.io/docs/concepts/overview/)
- [Pods](https://kubernetes.io/docs/concepts/workloads/pods/)
- [Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Liveness, Readiness, and Startup Probes](https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/)
- [ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secret](https://kubernetes.io/docs/concepts/configuration/secret/)
- [NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

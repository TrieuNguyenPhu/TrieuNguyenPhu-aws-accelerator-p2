# Observability & SRE — Giám sát và Đo lường Hệ thống tin cậy

Bản ghi chép này tổng hợp các kiến thức nền tảng về Giám sát (Monitoring) và Quan sát (Observability), phương pháp luận SRE (SLI/SLO/SLA), bộ công cụ Prometheus-Grafana-Loki-OTel, và kỹ thuật cảnh báo tiên tiến dựa trên tốc độ tiêu thụ Error Budget (Burn Rate Alert).

---

## 1. Ba trụ cột của Observability

Giám sát truyền thống (Monitoring) chỉ trả lời câu hỏi *"Hệ thống có chạy hay không?"*, trong khi **Khả năng quan sát (Observability)** giúp ta hiểu *"Tại sao hệ thống chạy sai hoặc chậm?"* dựa trên dữ liệu telemetry thu thập được.

Observability được xây dựng trên **3 trụ cột dữ liệu (M.E.L.T / M.L.T)**:
1. **Metrics (Số liệu đo lường):** Các giá trị số có thể tổng hợp theo thời gian (CPU, Memory, Request Count, Latency). Metrics nhẹ, có thể lưu trữ lâu và phù hợp nhất để xây dựng dashboard cảnh báo tổng quan.
2. **Logs (Nhật ký hệ thống):** Các dòng text có timestamp mô tả chi tiết một sự kiện cụ thể xảy ra trong code. Logs rất hữu ích để debug và tìm nguyên nhân gốc rễ (Root Cause Analysis), nhưng tốn dung lượng lưu trữ lớn.
3. **Traces (Dấu vết phân tán):** Theo dõi hành trình của một request đi qua nhiều microservices khác nhau trong một hệ thống phân tán. Trace giúp chỉ ra chính xác service nào hoặc truy vấn database nào đang làm nghẽn cổ chai (bottleneck).

---

## 2. Thiết lập mục tiêu độ tin cậy: SLI, SLO và SLA

Trong triết lý SRE (Site Reliability Engineering), ta chấp nhận rằng không có hệ thống nào đạt độ tin cậy tuyệt đối 100% (bởi vì chi phí quá đắt và cản trở tốc độ phát triển tính năng). Do đó, ta quản lý sự tin cậy qua 3 khái niệm:

### 2.1. SLI (Service Level Indicator - Chỉ số chất lượng dịch vụ)
*   Là chỉ số đo lường hiệu năng thực tế tại một thời điểm cụ thể.
*   **Công thức tính phổ biến:** 
    $$\text{SLI} = \frac{\text{Số lượng sự kiện hợp lệ (Good Events)}}{\text{Tổng số lượng sự kiện nhận vào (Total Events)}} \times 100\%$$
*   *Ví dụ:* Số request HTTP có status code `< 500` chia cho tổng số request HTTP nhận được trong 5 phút qua.

### 2.2. SLO (Service Level Objective - Mục tiêu chất lượng dịch vụ)
*   Là mục tiêu mong muốn về hiệu năng mà team kỹ thuật đặt ra và cam kết nội bộ.
*   *Ví dụ:* Uptime Availability của API phải $\ge 99.9\%$ trong chu kỳ 30 ngày.

### 2.3. SLA (Service Level Agreement - Cam kết chất lượng dịch vụ)
*   Là cam kết pháp lý hoặc thương mại giữa doanh nghiệp và khách hàng sử dụng dịch vụ. Nếu vi phạm SLA, doanh nghiệp phải đền bù tài chính hoặc tặng coupon.
*   **Quy tắc thiết kế:** SLA luôn lỏng lẻo hơn SLO để tạo khoảng đệm an toàn cho kỹ sư (ví dụ: SLO = 99.9% nhưng SLA = 99.5%).

### 2.4. Ngân sách lỗi (Error Budget)
*   Là khoảng lỗi tối đa được phép xảy ra mà không làm ảnh hưởng đến trải nghiệm chung của khách hàng.
*   **Công thức:** 
    $$\text{Error Budget} = 100\% - \text{SLO}$$
*   Nếu SLO là 99.9%, Error Budget là 0.1%. Error Budget có thể dùng làm "hạn mức" để các dev tự tin deploy code mới. Nếu cạn kiệt Error Budget, toàn team phải dừng việc deploy tính năng mới để tập trung fix bug.

---

## 3. Hệ sinh thái Prometheus, Grafana và Loki

*   **Prometheus:** Hệ thống giám sát theo cơ chế **Pull-based** (chủ động cào metric định kỳ từ target export). Prometheus lưu trữ dữ liệu dạng Time-Series và cung cấp ngôn ngữ truy vấn **PromQL**.
*   **Grafana:** Công cụ trực quan hóa dữ liệu (Visualization) hàng đầu, kết nối với nhiều nguồn dữ liệu (Prometheus, Loki, Elasticsearch, CloudWatch) để dựng dashboard biểu đồ động.
*   **Loki:** Hệ thống gom log lấy cảm hứng từ Prometheus. Loki không đánh chỉ mục (index) toàn bộ nội dung log mà chỉ đánh chỉ mục cho các label (metadata) giống hệt nhãn của Prometheus. Nhờ đó, Loki cực kỳ nhẹ, tối ưu bộ nhớ và cho phép dễ dàng chuyển đổi qua lại giữa Dashboard Metric của Prometheus sang Log của Loki bằng **LogQL**.

---

## 4. OpenTelemetry (OTel) — Chuẩn hóa Telemetry toàn cầu

Trước đây, mỗi công cụ giám sát sử dụng một thư viện SDK riêng (vendor lock-in). **OpenTelemetry** ra đời như một chuẩn chung (open standard) do CNCF quản lý để thu thập mọi dữ liệu Telemetry.

### Kiến trúc OpenTelemetry Collector:
OTel Collector gồm 3 thành phần nối tiếp tạo thành một pipeline:
```text
Receivers (Thu nhận) ➔ Processors (Xử lý/Lọc) ➔ Exporters (Đẩy đi)
```
*   **Receivers:** Nhận dữ liệu dưới nhiều giao thức (OTLP, Jaeger, Prometheus, Zipkin).
*   **Processors:** Xử lý dữ liệu (batching, lọc bỏ log rác, che giấu thông tin nhạy cảm, thêm metadata).
*   **Exporters:** Đẩy dữ liệu đã xử lý về các backend đích (Prometheus cho metrics, Jaeger cho traces, Loki cho logs).

---

## 5. Cảnh báo nâng cao: Multi-Window Burn Rate Alert

Cảnh báo truyền thống dựa trên ngưỡng (ví dụ: *Alert nếu Error Rate > 2% trong 5 phút*) thường gặp hai nhược điểm lớn:
*   **Báo động giả (Alert Fatigue):** Lỗi tăng đột biến trong 1 phút rồi tự hết, gây nhiễu và làm loãng sự chú ý của SRE.
*   **Bỏ sót lỗi âm ỉ:** Lỗi chỉ tăng nhẹ 0.2% (vượt quá Error Budget cho phép) nhưng kéo dài nhiều ngày, làm cạn kiệt ngân sách lỗi mà không hề kích hoạt alert 5 phút.

**Burn Rate** là tốc độ tiêu thụ Error Budget. Tốc độ tiêu chuẩn (Burn Rate = 1) nghĩa là bạn sẽ tiêu hết 100% Error Budget chính xác trong chu kỳ tính toán (thường là 30 ngày).
*   Burn Rate = 14.4 nghĩa là tiêu hết Error Budget trong 50 giờ (2% budget tiêu hao trong 1 giờ).
*   Burn Rate = 6 nghĩa là tiêu hết trong 120 giờ (5% budget tiêu hao trong 6 giờ).

### Công thức cảnh báo đa cửa sổ (Multi-Window Multi-Burn-Rate Alert) của Google:
Ta kết hợp một cửa sổ ngắn (để phản ứng nhanh) và một cửa sổ dài (để kiểm tra tính ổn định):

*   **Cảnh báo Đột biến (Critical Alert - Page khẩn cấp):**
    *   *Điều kiện:* Burn Rate > 14.4 trong cả cửa sổ 1 giờ (Fast Window) và cửa sổ 5 phút (Slow Window).
    *   *Ý nghĩa:* Hệ thống đang mất 2% Error Budget chỉ trong 1 giờ. Cần đánh thức kỹ sư trực ca ngay lập tức.
*   **Cảnh báo Âm ỉ (Warning Alert - Ticket/Slack):**
    *   *Điều kiện:* Burn Rate > 6 trong cả cửa sổ 6 giờ và cửa sổ 30 phút.
    *   *Ý nghĩa:* Hệ thống đang rò rỉ lỗi chậm nhưng liên tục. Cần xử lý trong giờ làm việc trước khi cạn kiệt ngân sách.

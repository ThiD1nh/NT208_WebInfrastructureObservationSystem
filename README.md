# Web Infrastructure Observation System (NT208 - Đề tài 18)

Dự án này là giả lập 1 hệ thống giám sát **Observation System** đơn giản: một ứng dụng web cơ bản (FastAPI + Nginx + MySQL) được giám sát bởi bộ công cụ của Grafana (Loki, Tempo, Alloy, Prometheus) và hệ thống cảnh báo (Alertmanager + Telegram Webhook) được triển khai giám sát ở localhost

---

## 👨‍💻 Thành viên nhóm 
| MSSV | Họ và tên | Chức vụ |
|---|---|---|
| 24521656 | Trần Đình Thi | Nhóm trưởng |
| 24521773 | Nguyễn Hữu Tiến | Thành viên |
| 24521593 | Vũ Cao Thạch | Thành viên |
| 24521676 | Đỗ Toàn Thịnh | Thành viên | 

## 🏗️ Các thành phần trong Repo

Dự án được chia thành các khối chính:

1. **Ứng dụng web cơ bản (`/target-app`)**
   - Một backend viết bằng **FastAPI Python** .
   - Đã được tích hợp sẵn **OpenTelemetry** để tự động thu thập Logs, Metrics, và Traces.

2. **Cơ sở dữ liệu (`/database`)**
   - **MySQL** Database.
   - Chứa script `init.sql` để khởi tạo bảng và chèn dữ liệu mẫu ngay khi khởi động.

3. **Reverse Proxy (`/nginx`)**
   - Reverse Proxy đóng vai trò làm cổng giao tiếp chính để hứng request và chuyển tiếp cho backend. Cung cấp metrics truy cập (throughput, status codes).

4. **Hệ thống giám sát (`/observability`)**
   - **Grafana Alloy**: Collector, nhận dữ liệu OTLP từ backend và scrape metrics từ Nginx, MySQL.
   - **Prometheus**: Cơ sở dữ liệu lưu trữ Metrics và lưu trữ các Alert Rules.
   - **Loki**: Cơ sở dữ liệu lưu trữ Logs.
   - **Tempo**: Cơ sở dữ liệu lưu trữ phân tán Distributed Traces.
   - **Grafana**: Giao diện trực quan hóa dữ liệu kết nối sẵn với các nguồn dữ liệu trên.
   - **Alertmanager**: Trình quản lý cảnh báo, chịu trách nhiệm nhận cảnh báo từ Prometheus và chuyển tiếp.

5. **Plugin Tùy chỉnh (`/custom-plugins`)**
   - **Telegram Webhook**: Một microservice viết bằng FastAPI, nhận Webhook từ Alertmanager và gửi tin nhắn cảnh báo trực tiếp về ứng dụng Telegram với chat ID được cung cấp, bot đã được tạo sẵn và cung cấp sẵn ID.

6. **Kiểm thử (`/load-test`)**
   - Kịch bản Load Testing bằng **K6** (`k6-stress.js`).
   - Các script Fault Injection bằng **PowerShell/Bash** để giả lập các sự cố hệ thống (App Crash, DB Slow Query, CPU Throttle).

---

## 🛠️ Prerequisites

Để chạy được dự án này, máy tính của bạn cần cài đặt sẵn:

1. **[Docker Desktop](https://www.docker.com/products/docker-desktop/)**: (Bao gồm Docker Engine và Docker Compose) Dùng để chạy toàn bộ hệ thống.
2. **[K6](https://k6.io/docs/get-started/installation/)**: Công cụ tạo tải cho bước kiểm thử.
3. **PowerShell 5.1+ / 7+** (có sẵn trên Windows) để chạy kịch bản tiêm lỗi.
4. Một tài khoản **Telegram** để cấu hình nhận cảnh báo (Chat ID từ `@userinfobot`).

---

## 🚀 Hướng dẫn chạy hệ thống

### Bước 1: Cấu hình Telegram Webhook
Mở file `custom-plugins/telegram-webhook/.env` và điền thông tin vào:
```ini
TELEGRAM_CHAT_ID=thay_bang_chat_id_cua_ban
```

### Bước 2: Khởi động toàn bộ hệ thống
Mở terminal tại thư mục gốc của dự án và chạy lệnh:
```bash
docker compose up -d --build
```

### Bước 3: Truy cập giao diện
Sau khi các container báo `Started`, bạn có thể truy cập:
- **App Backend API**: `http://localhost:8081`
- **Grafana Dashboard**: `http://localhost:3000` (Đăng nhập với `admin` / `admin`). Tìm đến thư mục Dashboards để xem các biểu đồ.

---

## 🧪 Testing

Để xem dữ liệu nhảy trên biểu đồ và nhận được cảnh báo, bạn làm như sau:

**1. Load Test:**
Mở một terminal mới và chạy:
```bash
k6 run load-test/k6-stress.js
```

**2. Fault Injection:**
Mở **PowerShell**, chuyển tới thư mục dự án và chạy kịch bản:
```powershell
.\load-test\fault-inject.ps1
```
*Gõ số tương ứng với các kịch bản để tạo ra sự cố (Ví dụ: Giới hạn CPU, tắt Backend). Sau đó mở Grafana và Telegram để quan sát biểu đồ biến động và thông báo lỗi.*

---

## 🛑 Dừng hệ thống
Khi không sử dụng nữa, bạn có thể tắt toàn bộ hệ thống và dọn dẹp volumes bằng lệnh:
```bash
docker compose down -v
```

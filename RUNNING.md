# Hướng dẫn chạy — NT208 Web Infrastructure Observation System

## 1. Yêu cầu

| Công cụ | Phiên bản tối thiểu | Kiểm tra |
|---|---|---|
| Docker Engine | 24.x | `docker --version` |
| Docker Compose | 2.x (plugin) | `docker compose version` |
| curl | bất kỳ | `curl --version` |

---

## 2. Kiến trúc tổng quan

```
Người dùng
    │
    ▼ :80
┌─────────┐      proxy_pass      ┌──────────────┐
│  Nginx  │ ──────────────────▶  │  Backend App │ :8000
│(alpine) │                      │   (FastAPI)  │
└─────────┘                      └──────┬───────┘
    │ :8080/stub_status                 │ OTLP gRPC
    │                                   ▼ :4317
    │                           ┌──────────────┐
    │                           │  Grafana     │
    └──────────────────────────▶│  Alloy       │
     scrape nginx metrics       └──────┬───────┘
                                       │ (forward đến Loki / Tempo / Prometheus)
                                       ▼
                              [chưa triển khai]

┌──────────┐
│  MySQL   │ ◀── Backend App (qua biến môi trường DB_HOST=database)
│  8.0     │
└──────────┘
```

### Trạng thái triển khai

| Thành phần | File | Trạng thái |
|---|---|---|
| Backend App (FastAPI) | `target-app/` | ✅ Hoàn thành |
| Nginx reverse proxy | `nginx/nginx.conf` | ✅ Hoàn thành |
| MySQL + schema | `database/init.sql` | ✅ Hoàn thành |
| Grafana Alloy | `observability/alloy/config.alloy` | ⚠️ Có 2 lỗi cú pháp (xem mục 6) |
| Prometheus | `observability/prometheus/` | ❌ Chưa có config + chưa có service trong compose |
| Loki | `observability/loki/` | ❌ Chưa có config + chưa có service trong compose |
| Tempo | `observability/tempo/` | ❌ Chưa có config + chưa có service trong compose |
| Grafana | `observability/grafana/` | ❌ Chưa có config + chưa có service trong compose |
| AlertManager | `observability/alertmanager/` | ❌ Chưa có config + chưa có service trong compose |
| Load test | `load-test/` | ❌ Chưa viết |
| Frontend | `frontend/` | ❌ Chưa viết |

---

## 3. Khởi động stack (các service đã hoàn thành)

### Bước 1 — Tạo thư mục log

Alloy và Nginx cần thư mục log tồn tại trước khi mount:

```bash
mkdir -p target-app/logs nginx/logs
```

### Bước 2 — Build và khởi động

```bash
docker compose up -d --build
```

Lần đầu chạy sẽ mất vài phút để:
- Pull image `mysql:8.0`, `nginx:alpine`, `grafana/alloy:latest`
- Build image `backend-app` từ `target-app/Dockerfile`
- MySQL chạy `init.sql` (tạo schema + insert 50.000 đơn hàng mẫu)

### Bước 3 — Kiểm tra container

```bash
docker compose ps
```

Kết quả mong đợi (4 service `Up`):

```
NAME            IMAGE                    STATUS
demo_mysql      mysql:8.0                Up (healthy)
demo_backend    target-app               Up
demo_nginx      nginx:alpine             Up
demo_alloy      grafana/alloy:latest     Up
```

> **Lưu ý:** `demo_alloy` sẽ in lỗi kết nối đến Prometheus/Loki/Tempo vì các service này chưa được thêm vào `docker-compose.yml`. Container vẫn chạy, chỉ bỏ qua được việc forward dữ liệu.

### Bước 4 — Kiểm tra Backend App sẵn sàng

```bash
curl http://localhost/health
# {"status":"ok"}
```

---

## 4. Kiểm tra 3 API

Tất cả request đi qua Nginx (port 80). Cũng có thể gọi thẳng backend (port 8000).

### `/api/fast` — Trả về ngay

```bash
curl http://localhost/api/fast
```

```json
{"message": "fast response", "status": "ok"}
```

Thời gian phản hồi: < 50ms.

### `/api/slow` — Sleep 2 giây

```bash
curl http://localhost/api/slow
# Chờ 2 giây...
```

```json
{"message": "slow response after 2s", "status": "ok"}
```

Dùng để quan sát latency tăng cao trong Grafana (khi observability stack hoàn chỉnh).

### `/api/error` — Trả lỗi HTTP 500

```bash
curl -v http://localhost/api/error
```

```
< HTTP/1.1 500 Internal Server Error
{"detail": "Internal Server Error", "error": "Intentional server error for observability testing"}
```

---

## 5. Xem logs

### Log của từng container

```bash
# Backend App
docker compose logs -f backend-app

# Nginx access log
docker compose logs -f nginx

# Alloy (xem lỗi kết nối đến backends chưa có)
docker compose logs -f alloy
```

### Log JSON của Backend App (file)

Backend ghi log JSON vào `target-app/logs/app.log` (bind mount với `/app/logs` trong container):

```bash
tail -f target-app/logs/app.log
```

Mỗi dòng là một JSON object:

```json
{"timestamp": "2026-05-05T10:00:00+00:00", "level": "INFO", "message": "fast endpoint called", "service": "backend-app", "trace_id": "abc123...", "span_id": "def456..."}
```

### Nginx access log (JSON)

```bash
tail -f nginx/logs/access.log
```

```json
{"time":"2026-05-05T10:00:00+07:00","method":"GET","uri":"/api/fast","status":200,"body_bytes":39,"request_time":0.002,"upstream_response_time":"0.001","remote_addr":"172.18.0.1","http_user_agent":"curl/8.7.1"}
```

---

## 6. Lỗi đã biết trong `config.alloy`

File `observability/alloy/config.alloy` có 2 lỗi cú pháp — **chưa sửa vì thuộc phần việc của thành viên khác**:

| Dòng | Nội dung sai | Đúng phải là |
|---|---|---|
| 5 | `"http://promethus:9090/..."` | `"http://prometheus:9090/..."` |
| 63 | `prometheus.scape "..."` | `prometheus.scrape "..."` |

Khi các service Prometheus/Loki/Tempo được thêm vào, cần sửa 2 lỗi này trước khi Alloy có thể forward dữ liệu.

---

## 7. Dừng và dọn dẹp

```bash
# Dừng tất cả container (giữ data)
docker compose down

# Dừng và xóa volume MySQL (reset toàn bộ database)
docker compose down -v

# Xóa image đã build (build lại từ đầu lần sau)
docker compose down --rmi local
```

---

## 8. Các lệnh debug thường dùng

```bash
# Xem toàn bộ log từ lúc khởi động
docker compose logs --since 5m

# Vào shell của backend container
docker exec -it demo_backend bash

# Kết nối MySQL trực tiếp
docker exec -it demo_mysql mysql -u app_user -papp_password shop_db

# Xem bảng products (dùng để test lỗi UNSIGNED)
docker exec -it demo_mysql mysql -u app_user -papp_password shop_db \
  -e "SELECT * FROM products;"

# Đếm đơn hàng pending (dùng để test bottleneck)
docker exec -it demo_mysql mysql -u app_user -papp_password shop_db \
  -e "SELECT COUNT(*) FROM orders WHERE status='pending';"

# Kiểm tra Alloy thu thập được metrics nginx chưa
curl http://localhost:8080/stub_status

# Rebuild chỉ backend (sau khi sửa code)
docker compose up -d --build backend-app
```

---

## 9. Kịch bản test lỗi cố ý trong database

Schema `init.sql` được thiết kế có 2 lỗi cố ý để demo observability:

### Kịch bản 1 — HTTP 500 do UNSIGNED constraint

Bảng `products` dùng `INT UNSIGNED` cho `stock_quantity`. Laptop chỉ có 3 cái trong kho. Khi API đặt hàng trừ quá số lượng, MySQL báo lỗi → App trả 500.

*(Cần implement API `/api/order` — phần việc sau)*

### Kịch bản 2 — Bottleneck do thiếu index

Bảng `orders` không có index trên cột `status`. Database đã có sẵn 50.000 đơn hàng (`SeedDummyOrders`). Query `WHERE status='pending'` sẽ full-scan toàn bảng → response chậm.

*(Cần implement API `/api/orders/pending` — phần việc sau)*

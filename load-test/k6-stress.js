import http from "k6/http";
import { sleep, check } from "k6";

export const options = {
  // Ramping VUs: tang dan tai roi giam — thay ro latency thay doi tren Grafana
  stages: [
    // { duration: "1m", target: 50 }, // Ramp up  : 0 → 50 VUs
    // { duration: "3m", target: 50 }, // Sustained: giu 50 VUs
    // { duration: "1m", target: 0  }, // Ramp down: 50 → 0 VUs
    { duration: "30s", target: 20 }, // Ramp up nhanh để thấy màu vàng sớm
    { duration: "3m", target: 20 },  // Giữ tải ổn định để Prometheus đếm đủ thời gian 'for'
    { duration: "30s", target: 0  }, 
  ],
  thresholds: {
    // // 95% request phai hoan thanh trong 3s
    // http_req_duration: ["p(95)<3000"],
    // // Ti le that bai (non-2xx) phai duoi 15%
    // // /api/error tra 500 la co chu y (10% traffic) nen dat nguong 15%
    // http_req_failed: ["rate<0.15"],
    // Khớp với rule Latency > 0.5s
    http_req_duration: ["p(95)>500"], 
    // Khớp với rule Error > 0.1 req/s
    http_req_failed: ["rate>0.1"],
  },
};

const BASE_URL = "http://localhost";

export default function () {
  const rand = Math.random();

  // if (rand < 0.60) {
  //   // 60% — /api/fast: baseline request nhanh
  //   const res = http.get(`${BASE_URL}/api/fast`);
  //   check(res, { "fast 200": (r) => r.status === 200 });

  // } else if (rand < 0.90) {
  //   // 30% — /api/slow: sleep 2s, tao latency spike de trigger alert
  //   const res = http.get(`${BASE_URL}/api/slow`, { timeout: "10s" });
  //   check(res, { "slow 200": (r) => r.status === 200 });

  // } else {
  //   // 10% — /api/error: tao error rate quan sat tren dashboard
  //   const res = http.get(`${BASE_URL}/api/error`);
  //   check(res, { "error 500": (r) => r.status === 500 });
  // }
   if (rand < 0.50) {
    // 50% — Request bình thường
    const res = http.get(`${BASE_URL}/api/fast`);
    check(res, { "status 200": (r) => r.status === 200 });

  } else if (rand < 0.80) {
    // 30% — Gây lỗi Latency (Slow là 2s, kéo trung bình lên > 0.5s chắc chắn)
    const res = http.get(`${BASE_URL}/api/slow`);
    check(res, { "status 200": (r) => r.status === 200 });

  } else {
    // 20% — Gây lỗi 500 (Với 20 VU, rate sẽ tầm 4-8 req/s, dư sức vượt ngưỡng 0.1)
    const res = http.get(`${BASE_URL}/api/error`);
    check(res, { "system error 5xx": (r) => r.status === 500 });
  }

  sleep(0.5);
}

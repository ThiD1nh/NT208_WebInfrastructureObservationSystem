#!/usr/bin/env bash
# fault-inject.sh — Inject loi vao he thong de quan sat tren Grafana

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn()    { echo -e "${YELLOW}[WAIT]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }

mysql_exec() {
    docker exec demo_mysql mysql -u app_user -papp_password shop_db -e "$1" 2>/dev/null
}

# ===========================================================================
# Kich ban 1: Crash App — simulate outage
# Quan sat: Nginx tra 502, traces dung, Prometheus alert firing
# ===========================================================================
scenario_crash_app() {
    log_info "Kich ban 1: Dung container backend → Nginx se tra 502"
    docker stop demo_backend
    log_warn "Backend da dung. Doi 30 giay..."
    log_warn "→ Mo Grafana va quan sat: http_req_failed tang vot, traces bien mat"
    sleep 30
    log_info "Khoi dong lai backend..."
    docker start demo_backend
    sleep 3
    log_success "Backend da phuc hoi."
}

# ===========================================================================
# Kich ban 2: UNSIGNED MySQL constraint — trigger HTTP 500
# Quan sat: MySQL error trong log, trace span bi danh dau error
# ===========================================================================
scenario_unsigned_overflow() {
    log_info "Kich ban 2: Tru stock Laptop qua so luong ton kho (UNSIGNED overflow)"

    log_info "Kiem tra stock hien tai..."
    mysql_exec "SELECT product_name, stock_quantity FROM products WHERE product_name = 'Laptop A';"

    log_info "Thu tru 5 cai (trong khi kho chi con 3)..."
    if mysql_exec "UPDATE products SET stock_quantity = stock_quantity - 5 WHERE product_name = 'Laptop A';"; then
        log_warn "Lenh chay duoc (MySQL mode co the khong strict). Kiem tra lai gia tri:"
        mysql_exec "SELECT product_name, stock_quantity FROM products WHERE product_name = 'Laptop A';"
    else
        log_success "MySQL bao loi UNSIGNED overflow — dung nhu thiet ke!"
    fi

    log_info "Phuc hoi: reset stock ve 3..."
    mysql_exec "UPDATE products SET stock_quantity = 3 WHERE product_name = 'Laptop A';"
    log_success "Stock da reset ve 3."
}

# ===========================================================================
# Kich ban 3: Bottleneck query — thieu index tren cot status
# Quan sat: Slow query time, MySQL exporter metrics tang, latency cao
# ===========================================================================
scenario_slow_query() {
    log_info "Kich ban 3: Chay query tren bang orders khong co index (50,000 rows)"
    log_info "Chay 10 lan lien tiep de tao load..."

    total=0
    for i in $(seq 1 10); do
        start=$(date +%s%3N)
        mysql_exec "SELECT COUNT(*) FROM orders WHERE status='pending';" > /dev/null
        end=$(date +%s%3N)
        elapsed=$((end - start))
        total=$((total + elapsed))
        log_warn "  Lan $i: ${elapsed}ms"
    done

    avg=$((total / 10))
    log_success "Trung binh: ${avg}ms — full table scan tren 50K rows."
    log_warn "→ So sanh voi query co index (sau khi them ALTER TABLE orders ADD INDEX idx_status (status))"
}

# ===========================================================================
# Kich ban 4: CPU throttle — simulate resource exhaustion
# Quan sat: Latency tang cao, Prometheus alert HostHighCpuLoad
# ===========================================================================
scenario_cpu_throttle() {
    log_info "Kich ban 4: Gioi han CPU container backend xuong 0.1 core"
    docker update --cpus="0.1" demo_backend
    log_success "CPU da gioi han. Backend se chay rat cham."
    log_warn "→ Goi nhieu request de thay latency tang: curl http://localhost/api/fast"
    log_warn "→ Doi 60 giay roi tu dong phuc hoi..."
    sleep 60
    log_info "Phuc hoi CPU..."
    docker update --cpus="0" demo_backend
    log_success "CPU da phuc hoi (khong gioi han)."
}

# ===========================================================================
# Menu chinh
# ===========================================================================
print_menu() {
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Fault Injection — NT208 Demo  ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo "  1) Crash App         (simulate outage, Nginx 502)"
    echo "  2) UNSIGNED Overflow (MySQL constraint, HTTP 500)"
    echo "  3) Slow Query        (thieu index, bottleneck)"
    echo "  4) CPU Throttle      (resource exhaustion)"
    echo "  5) Chay tat ca theo thu tu"
    echo "  0) Thoat"
    echo ""
}

main() {
    while true; do
        print_menu
        read -rp "Chon kich ban [0-5]: " choice
        echo ""
        case $choice in
            1) scenario_crash_app ;;
            2) scenario_unsigned_overflow ;;
            3) scenario_slow_query ;;
            4) scenario_cpu_throttle ;;
            5)
                scenario_crash_app
                scenario_unsigned_overflow
                scenario_slow_query
                scenario_cpu_throttle
                log_success "Da chay xong tat ca kich ban."
                ;;
            0) log_info "Thoat."; exit 0 ;;
            *) log_error "Lua chon khong hop le." ;;
        esac
        echo ""
        read -rp "Nhan Enter de tiep tuc..." _
    done
}

main

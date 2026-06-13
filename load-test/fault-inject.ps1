# fault-inject.ps1 — Inject loi vao he thong de quan sat tren Grafana
# Chay tren Windows voi PowerShell 5.1+ hoac PowerShell 7+
# Yeu cau: Docker Desktop dang chay

function Write-Info    { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok      { param($msg) Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Wait    { param($msg) Write-Host "[WAIT] $msg" -ForegroundColor Yellow }
function Write-Err     { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

function Invoke-MySQL {
    param([string]$sql)
    docker exec demo_mysql mysql -u app_user -papp_password shop_db -e $sql 2>$null
}

# ===========================================================================
# Kich ban 1: Crash App — simulate outage
# Quan sat: Nginx tra 502, traces dung, Prometheus alert firing
# ===========================================================================
function Invoke-CrashApp {
    Write-Info "Kich ban 1: Dung container backend → Nginx se tra 502"
    docker stop demo_backend
    Write-Wait "Backend da dung. Doi 30 giay..."
    Write-Wait "→ Mo Grafana va quan sat: http_req_failed tang vot, traces bien mat"
    Start-Sleep -Seconds 30
    Write-Info "Khoi dong lai backend..."
    docker start demo_backend
    Start-Sleep -Seconds 3
    Write-Ok "Backend da phuc hoi."
}

# ===========================================================================
# Kich ban 2: UNSIGNED MySQL constraint — trigger HTTP 500
# Quan sat: MySQL error trong log, trace span bi danh dau error
# ===========================================================================
function Invoke-UnsignedOverflow {
    Write-Info "Kich ban 2: Tru stock Laptop qua so luong ton kho (UNSIGNED overflow)"

    Write-Info "Kiem tra stock hien tai..."
    Invoke-MySQL "SELECT product_name, stock_quantity FROM products WHERE product_name = 'Laptop A';"

    Write-Info "Thu tru 5 cai (trong khi kho chi con 3)..."
    try {
        Invoke-MySQL "UPDATE products SET stock_quantity = stock_quantity - 5 WHERE product_name = 'Laptop A';"
        Write-Wait "Lenh chay duoc (MySQL mode co the khong strict). Kiem tra lai gia tri:"
        Invoke-MySQL "SELECT product_name, stock_quantity FROM products WHERE product_name = 'Laptop A';"
    } catch {
        Write-Ok "MySQL bao loi UNSIGNED overflow — dung nhu thiet ke!"
    }

    Write-Info "Phuc hoi: reset stock ve 3..."
    Invoke-MySQL "UPDATE products SET stock_quantity = 3 WHERE product_name = 'Laptop A';"
    Write-Ok "Stock da reset ve 3."
}

# ===========================================================================
# Kich ban 3: Bottleneck query — thieu index tren cot status
# Quan sat: Slow query time, MySQL exporter metrics tang, latency cao
# ===========================================================================
function Invoke-SlowQuery {
    Write-Info "Kich ban 3: Chay query tren bang orders khong co index (50,000 rows)"
    Write-Info "Chay 10 lan lien tiep de tao load..."

    $total = 0
    for ($i = 1; $i -le 10; $i++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Invoke-MySQL "SELECT COUNT(*) FROM orders WHERE status='pending';" | Out-Null
        $sw.Stop()
        $elapsed = $sw.ElapsedMilliseconds
        $total += $elapsed
        Write-Wait "  Lan $i`: ${elapsed}ms"
    }

    $avg = [math]::Round($total / 10)
    Write-Ok "Trung binh: ${avg}ms — full table scan tren 50K rows."
    Write-Wait "→ So sanh voi query co index (sau khi them ALTER TABLE orders ADD INDEX idx_status (status))"
}

# ===========================================================================
# Kich ban 4: CPU throttle — simulate resource exhaustion
# Quan sat: Latency tang cao, Prometheus alert HostHighCpuLoad
# ===========================================================================
function Invoke-CpuThrottle {
    Write-Info "Kich ban 4: Gioi han CPU container backend xuong 0.1 core"
    docker update --cpus="0.1" demo_backend
    Write-Ok "CPU da gioi han. Backend se chay rat cham."
    Write-Wait "→ Goi nhieu request de thay latency tang: curl http://localhost:8081/api/fast"
    Write-Wait "→ Doi 60 giay roi tu dong phuc hoi..."
    Start-Sleep -Seconds 60
    Write-Info "Phuc hoi CPU..."
    docker update --cpus="0" demo_backend
    Write-Ok "CPU da phuc hoi (khong gioi han)."
}

# ===========================================================================
# Menu chinh
# ===========================================================================
function Show-Menu {
    Write-Host ""
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "  Fault Injection — NT208 Demo  " -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "  1) Crash App         (simulate outage, Nginx 502)"
    Write-Host "  2) UNSIGNED Overflow (MySQL constraint, HTTP 500)"
    Write-Host "  3) Slow Query        (thieu index, bottleneck)"
    Write-Host "  4) CPU Throttle      (resource exhaustion)"
    Write-Host "  5) Chay tat ca theo thu tu"
    Write-Host "  0) Thoat"
    Write-Host ""
}

# Kiem tra Docker dang chay
if (-not (docker info 2>$null)) {
    Write-Err "Docker khong chay hoac chua cai dat. Vui long khoi dong Docker Desktop."
    exit 1
}

while ($true) {
    Show-Menu
    $choice = Read-Host "Chon kich ban [0-5]"
    Write-Host ""

    switch ($choice) {
        "1" { Invoke-CrashApp }
        "2" { Invoke-UnsignedOverflow }
        "3" { Invoke-SlowQuery }
        "4" { Invoke-CpuThrottle }
        "5" {
            Invoke-CrashApp
            Invoke-UnsignedOverflow
            Invoke-SlowQuery
            Invoke-CpuThrottle
            Write-Ok "Da chay xong tat ca kich ban."
        }
        "0" { Write-Info "Thoat."; exit 0 }
        default { Write-Err "Lua chon khong hop le." }
    }

    Write-Host ""
    Read-Host "Nhan Enter de tiep tuc"
}

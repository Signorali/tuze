#requires -Version 5.1
<#
.SYNOPSIS
  Tüze CRM — Tek-tık Kurulum (Windows).

.DESCRIPTION
  Bu script Docker Hub'dan Tüze CRM imajlarını çekip ayağa kaldırır.
  Her zaman güvenli, idempotent: yeniden çalıştırıldığında mevcut .env'i korur,
  yalnızca eksikleri doldurur veya güncelleme yapar.

.PARAMETER InstallDir
  Kurulum dizini. Varsayılan: $HOME\Tuze (örn. C:\Users\Ali\Tuze)

.PARAMETER Port
  HTTP port. Varsayılan: 9090

.PARAMETER Version
  Çekilecek sürüm. Varsayılan: latest

.PARAMETER NoStart
  Servisleri başlatma — sadece dosyaları indir ve secret üret.

.EXAMPLE
  # En basit kurulum (her şey varsayılan):
  ./install.ps1

.EXAMPLE
  # Özel dizin ve port:
  ./install.ps1 -InstallDir D:\Tuze -Port 8080

.EXAMPLE
  # Tek-satır kurulum (gelecekte GitHub barındırılırsa):
  iwr https://raw.githubusercontent.com/signorali/tuze/main/install.ps1 | iex

.NOTES
  Gereksinimler:
    - Docker Desktop 4.30+ (Windows) — https://docs.docker.com/desktop/install/windows-install/
    - PowerShell 5.1+ (Windows 10/11'de zaten kurulu)
#>
[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $HOME "Tuze"),
    [int]$Port = 9090,
    [string]$Version = "latest",
    [switch]$NoStart
)

$ErrorActionPreference = "Stop"
$ScriptVersion = "1.0.0"
$HUB_USER = "signorali"

# Bu script'in barındırılacağı URL (raw GitHub veya kendi sunucunuz).
# Boş bırakılırsa script kendisinin yanındaki install/ klasörüne bakar.
$BASE_URL = $env:TUZE_BASE_URL
if (-not $BASE_URL) {
    $BASE_URL = "https://raw.githubusercontent.com/signorali/tuze/main/install"
}

# ── Renkler ──────────────────────────────────────────────────────────────────
function Write-Step($n, $msg) {
    Write-Host ""
    Write-Host "==> [${n}] $msg" -ForegroundColor Magenta
}
function Write-Ok($msg)   { Write-Host "  [✓] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  [!] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "  [✗] $msg" -ForegroundColor Red }
function Die($msg) { Write-Err $msg; exit 1 }

# ── Banner ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host @"
   ╔══════════════════════════════════════════════════════╗
   ║                                                      ║
   ║       Tüze CRM — Tek-Tık Kurulum (Windows)           ║
   ║                                                      ║
   ║       v$ScriptVersion                                          ║
   ║                                                      ║
   ╚══════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

# ── 1. Önkoşullar ────────────────────────────────────────────────────────────
Write-Step "1/7" "Sistem Kontrolleri"

# Docker
$dockerVer = (docker --version 2>$null)
if (-not $dockerVer) {
    Die "Docker kurulu değil. Önce Docker Desktop'ı kurun: https://docs.docker.com/desktop/install/windows-install/"
}
Write-Ok "Docker: $dockerVer"

# Docker compose v2
$composeVer = (docker compose version --short 2>$null)
if (-not $composeVer) {
    Die "Docker Compose v2 bulunamadı. Docker Desktop güncel mi?"
}
Write-Ok "Docker Compose: v$composeVer"

# Daemon ayakta mı?
try {
    docker info --format '{{.ServerVersion}}' 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "info failed" }
    Write-Ok "Docker daemon çalışıyor"
} catch {
    Die "Docker daemon erişilemedi. Docker Desktop açık mı?"
}

# Boş port kontrolü
$portInUse = (Test-NetConnection -ComputerName localhost -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue 2>$null)
if ($portInUse) {
    Write-Warn "Port $Port kullanımda — kuruluyu sürdürürüz, başlatma sırasında çakışma olursa farklı port seçin"
} else {
    Write-Ok "Port $Port boş"
}

# ── 2. Kurulum dizini ────────────────────────────────────────────────────────
Write-Step "2/7" "Kurulum Dizini: $InstallDir"

$upgrade = Test-Path (Join-Path $InstallDir "docker-compose.yml")
if ($upgrade) {
    Write-Warn "Mevcut kurulum tespit edildi → güncelleme moduna geçiliyor (.env korunur)"
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $InstallDir "nginx") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $InstallDir "uploads") | Out-Null
Write-Ok "Dizin hazır"

# ── 3. Yapılandırma dosyalarını indir ────────────────────────────────────────
Write-Step "3/7" "Yapılandırma Dosyaları"

# Script'in çalıştığı dizinde install/ klasörü varsa oradan kopyala (local install)
$localInstall = Join-Path $PSScriptRoot "install"
$useLocal = (Test-Path $localInstall) -and (Test-Path (Join-Path $localInstall "docker-compose.yml"))

function Get-ConfigFile($relPath) {
    $dest = Join-Path $InstallDir $relPath
    $destDir = Split-Path $dest -Parent
    if ($destDir -and -not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }

    if ($useLocal) {
        $src = Join-Path $localInstall $relPath
        Copy-Item -Force -Path $src -Destination $dest
        Write-Ok "$relPath  (lokal)"
    } else {
        $url = "$BASE_URL/$($relPath -replace '\\','/')"
        try {
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
            Write-Ok "$relPath  ($url)"
        } catch {
            Die "İndirilemedi: $url — $($_.Exception.Message)"
        }
    }
}

Get-ConfigFile "docker-compose.yml"
Get-ConfigFile "nginx/nginx.conf"

# ── 4. Secret + .env oluştur ─────────────────────────────────────────────────
Write-Step "4/7" "Yapılandırma (.env)"

$envFile = Join-Path $InstallDir ".env"
if (Test-Path $envFile) {
    Write-Ok ".env mevcut — korunuyor (mevcut şifreler değişmedi)"
} else {
    function New-RandomKey($len) {
        $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
        -join ((1..$len) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    }

    $dbPwd       = New-RandomKey 32
    $secretKey   = New-RandomKey 64
    $adminPwd    = New-RandomKey 16

    # LAN IP tespiti (HOST_IP için)
    $lanIp = $null
    try {
        $route = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction Stop | Sort-Object -Property RouteMetric | Select-Object -First 1
        $ifaceIdx = $route.InterfaceIndex
        $lanIp = (Get-NetIPAddress -InterfaceIndex $ifaceIdx -AddressFamily IPv4 -ErrorAction Stop | Where-Object { $_.PrefixOrigin -eq "Dhcp" -or $_.PrefixOrigin -eq "Manual" } | Select-Object -First 1).IPAddress
    } catch { $lanIp = $null }
    if ($lanIp) { Write-Ok "LAN IP tespit edildi: $lanIp" } else { Write-Warn "LAN IP otomatik tespit edilemedi (boş bırakılıyor)" }

    @"
# =============================================================================
#  Tüze CRM — Otomatik üretilmiş .env
#  Üretildi: $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
#  ⚠ Bu dosyayı YEDEKLEYIN — şifreler kaybolursa veriye erişim de kaybedilir
# =============================================================================

# Sürüm (Docker Hub tag)
APP_VERSION=$Version

# Image isimleri (update sistemi bunlardan kontrol eder)
DOCKER_IMAGE_BACKEND=$HUB_USER/tuze-backend
DOCKER_IMAGE_FRONTEND=$HUB_USER/tuze-frontend
DOCKER_IMAGE_REPORT=$HUB_USER/tuze-report

# Veritabanı
POSTGRES_DB=tuze
POSTGRES_USER=tuze
POSTGRES_PASSWORD=$dbPwd
DATABASE_URL=postgresql+asyncpg://tuze:$dbPwd@postgres:5432/tuze

# Redis
REDIS_URL=redis://redis:6379/0

# Güvenlik
SECRET_KEY=$secretKey
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=30

# Uygulama
APP_ENV=production
APP_HOST=0.0.0.0
APP_PORT=8000
ALLOWED_ORIGINS=http://localhost,http://localhost:$Port,http://127.0.0.1:$Port

# Dosya yükleme
UPLOAD_DIR=/app/uploads
MAX_FILE_SIZE_MB=20

# Döviz kuru
TCMB_FETCH_CRON=0 16 * * 1-5
GOOGLE_FINANCE_FETCH_INTERVAL_MINUTES=30

# Sunucunun LAN IP adresi (diğer kullanıcıların bağlanacağı adres)
# Boş bırakılırsa backend otomatik algılar.
HOST_IP=$lanIp

# Nginx port
HTTP_PORT=$Port
HTTPS_PORT=$($Port + 1)

# İlk admin kullanıcı (kurulum sihirbazında değiştirilebilir)
ADMIN_EMAIL=admin@tuze.local
ADMIN_PASSWORD=$adminPwd
ADMIN_FULL_NAME=Sistem Yöneticisi
"@ | Set-Content -Path $envFile -Encoding UTF8 -NoNewline

    Write-Ok ".env oluşturuldu (rastgele şifrelerle)"
    Write-Host "      İlk giriş şifresi: $adminPwd" -ForegroundColor Yellow
    Write-Host "      (Bu şifre sadece şimdi gösteriliyor — kaybetmeden bir yere kaydedin)" -ForegroundColor Yellow
}

# ── 5. Image pull ────────────────────────────────────────────────────────────
Write-Step "5/7" "Docker Hub'dan İmajlar İndiriliyor"

Push-Location $InstallDir
try {
    if ($NoStart) {
        Write-Warn "-NoStart belirtildi → image indirme atlanıyor"
    } else {
        $env:APP_VERSION = $Version
        docker compose pull
        if ($LASTEXITCODE -ne 0) { Die "İmaj indirme başarısız" }
        Write-Ok "Tüm imajlar indirildi"
    }

    # ── 6. Servisleri başlat ─────────────────────────────────────────────────
    Write-Step "6/7" "Servisler Başlatılıyor"
    if ($NoStart) {
        Write-Warn "-NoStart → 'docker compose up -d' atlandı"
    } else {
        docker compose up -d
        if ($LASTEXITCODE -ne 0) { Die "Servisler başlatılamadı" }

        # Sağlık kontrolü
        Write-Host "  Servislerin hazır olması bekleniyor..." -NoNewline
        $ready = $false
        for ($i = 0; $i -lt 18; $i++) {
            Start-Sleep -Seconds 3
            try {
                $r = Invoke-WebRequest -Uri "http://localhost:$Port/api/health" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
                if ($r.StatusCode -eq 200) { $ready = $true; break }
            } catch { }
            Write-Host "." -NoNewline
        }
        Write-Host ""
        if ($ready) { Write-Ok "Servisler ayakta" } else { Write-Warn "Servisler hâlâ başlatılıyor — birkaç dakika içinde hazır olur" }
    }

    # ── 7. Sonuç ─────────────────────────────────────────────────────────────
    Write-Step "7/7" "Tamamlandı"

    $adminPwdShown = if (-not $upgrade) { (Select-String -Path $envFile -Pattern '^ADMIN_PASSWORD=(.+)$').Matches.Groups[1].Value } else { "(mevcut .env'de — değişmedi)" }

    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                                                      ║" -ForegroundColor Green
    Write-Host "║   ✅  Kurulum Tamamlandı!                            ║" -ForegroundColor Green
    Write-Host "║                                                      ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "🌐 Erişim adresleri:" -ForegroundColor White
    Write-Host "   → http://localhost:$Port" -ForegroundColor Cyan
    if ($lanIp) {
        Write-Host "   → http://${lanIp}:$Port    # ağdaki diğer kullanıcılar için" -ForegroundColor Cyan
    }
    Write-Host ""
    if (-not $upgrade) {
        Write-Host "🔐 İlk giriş:" -ForegroundColor White
        Write-Host "   E-posta: admin@tuze.local" -ForegroundColor Cyan
        Write-Host "   Şifre:   $adminPwdShown" -ForegroundColor Yellow
        Write-Host "   (Giriş yaptıktan sonra hemen şifrenizi değiştirin)" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "📁 Kurulum dizini: $InstallDir" -ForegroundColor White
    Write-Host "🛠 Komutlar:" -ForegroundColor White
    Write-Host "   cd $InstallDir" -ForegroundColor DarkGray
    Write-Host "   docker compose ps               # durum" -ForegroundColor DarkGray
    Write-Host "   docker compose logs -f backend  # canlı log" -ForegroundColor DarkGray
    Write-Host "   docker compose restart          # yeniden başlat" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "🔄 Güncelleme:" -ForegroundColor White
    Write-Host "   Uygulama içinden: Ayarlar > Güncelleme > 'Şimdi Güncelle'" -ForegroundColor DarkGray
    Write-Host "   Veya manuel: docker compose pull; docker compose up -d" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "⚠ .env dosyasını yedekleyin: $envFile" -ForegroundColor Yellow
    Write-Host "   İçinde DB şifresi ve JWT secret var." -ForegroundColor Yellow
    Write-Host ""

    # Tarayıcıyı aç — ilk kurulumda /setup wizard'ına otomatik yönlenir
    if (-not $NoStart -and $ready) {
        Write-Host "Tarayıcı 3 saniye içinde otomatik açılacak..." -ForegroundColor White
        Start-Sleep -Seconds 3
        Start-Process "http://localhost:$Port"
    }

} finally {
    Pop-Location
}

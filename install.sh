#!/usr/bin/env bash
# =============================================================================
#  Tüze CRM — Tek Satır Kurulum (Linux / macOS)
#
#  Kurulum:
#    curl -fsSL https://raw.githubusercontent.com/signorali/tuze/main/install.sh | bash
#    # veya indirip:
#    ./install.sh
#
#  Çevre değişkenleri (override):
#    INSTALL_DIR=/opt/tuze    # Kurulum dizini (varsayılan: $HOME/tuze)
#    PORT=9090                # HTTP port
#    APP_VERSION=latest       # Docker Hub tag
#    BASE_URL=https://...     # Config dosyalarının URL'si
#    SKIP_PULL=1              # Image pull'u atla
#    NO_START=1               # Servisleri başlatma
# =============================================================================

set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/tuze}"
PORT="${PORT:-9090}"
APP_VERSION="${APP_VERSION:-latest}"
HUB_USER="${HUB_USER:-signorali}"
BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/signorali/tuze/main/install}"

# ── Renkler ──────────────────────────────────────────────────────────────────
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  BOLD=$(tput bold); DIM=$(tput dim); RESET=$(tput sgr0)
  RED=$(tput setaf 1); GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3)
  BLUE=$(tput setaf 4); CYAN=$(tput setaf 6); MAGENTA=$(tput setaf 5)
else
  BOLD=""; DIM=""; RESET=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""; MAGENTA=""
fi

log()  { printf "  ${BLUE}[*]${RESET} %s\n" "$*"; }
ok()   { printf "  ${GREEN}[✓]${RESET} %s\n" "$*"; }
warn() { printf "  ${YELLOW}[!]${RESET} %s\n" "$*"; }
err()  { printf "  ${RED}[✗]${RESET} %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }
step() { printf "\n${BOLD}${MAGENTA}==>${RESET} ${BOLD}[%s] %s${RESET}\n" "$1" "$2"; }

# ── Banner ───────────────────────────────────────────────────────────────────
cat <<EOF
${BOLD}${CYAN}
   ╔══════════════════════════════════════════════════════╗
   ║                                                      ║
   ║       Tüze CRM — Tek-Satır Kurulum (Linux/Mac)       ║
   ║                                                      ║
   ╚══════════════════════════════════════════════════════╝
${RESET}
EOF

# ── 1. Önkoşullar ────────────────────────────────────────────────────────────
step "1/7" "Sistem Kontrolleri"

# Docker
if ! command -v docker >/dev/null 2>&1; then
  die "Docker kurulu değil. Önce kurun: https://docs.docker.com/engine/install/"
fi
ok "Docker: $(docker --version)"

# Docker Compose v2
if ! docker compose version >/dev/null 2>&1; then
  die "Docker Compose v2 yok. Kurun: https://docs.docker.com/compose/install/"
fi
ok "Docker Compose: $(docker compose version --short)"

# Daemon ayakta mı?
if ! docker info >/dev/null 2>&1; then
  die "Docker daemon çalışmıyor. 'sudo systemctl start docker' veya Docker Desktop'ı açın."
fi
ok "Docker daemon erişilebilir"

# Disk
free_gb=$(df -BG "$HOME" 2>/dev/null | awk 'NR==2 {gsub("G",""); print $4}' || echo "?")
if [ -n "$free_gb" ] && [ "$free_gb" != "?" ] && [ "$free_gb" -lt 5 ]; then
  warn "Disk alanı düşük: ${free_gb} GB (en az 5 GB önerilir)"
else
  ok "Disk: ${free_gb} GB"
fi

# ── 2. Kurulum dizini ────────────────────────────────────────────────────────
step "2/7" "Kurulum Dizini: $INSTALL_DIR"

UPGRADE=0
if [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
  warn "Mevcut kurulum bulundu → güncelleme modu (.env korunur)"
  UPGRADE=1
fi

mkdir -p "$INSTALL_DIR/nginx" "$INSTALL_DIR/uploads"
ok "Dizin hazır"

cd "$INSTALL_DIR"

# ── 3. Yapılandırma dosyaları ────────────────────────────────────────────────
step "3/7" "Yapılandırma Dosyaları"

# Script ./install/ ile aynı dizinde mi? (lokal kullanım)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
USE_LOCAL=0
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/install/docker-compose.yml" ]; then
  USE_LOCAL=1
fi

fetch_file() {
  local rel="$1"
  local dest="$INSTALL_DIR/$rel"
  mkdir -p "$(dirname "$dest")"

  if [ "$USE_LOCAL" = "1" ]; then
    cp -f "$SCRIPT_DIR/install/$rel" "$dest"
    ok "$rel  (lokal)"
  else
    if curl -fsSL "$BASE_URL/$rel" -o "$dest"; then
      ok "$rel  ($BASE_URL/$rel)"
    else
      die "İndirilemedi: $BASE_URL/$rel"
    fi
  fi
}

fetch_file "docker-compose.yml"
fetch_file "nginx/nginx.conf"

# ── 4. .env oluştur ──────────────────────────────────────────────────────────
step "4/7" "Yapılandırma (.env)"

ENV_FILE="$INSTALL_DIR/.env"
if [ -f "$ENV_FILE" ]; then
  ok ".env mevcut — korunuyor"
else
  rand() { LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$1"; }

  DB_PWD="$(rand 32)"
  SECRET_KEY="$(rand 64)"
  ADMIN_PWD="$(rand 16)"

  # LAN IP tespiti
  LAN_IP=""
  if command -v ip >/dev/null 2>&1; then
    LAN_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -1)"
  fi
  if [ -z "$LAN_IP" ] && command -v hostname >/dev/null 2>&1; then
    LAN_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi

  if [ -n "$LAN_IP" ]; then
    ok "LAN IP tespit edildi: $LAN_IP"
  else
    warn "LAN IP otomatik tespit edilemedi (boş bırakılıyor)"
  fi

  HTTPS_PORT=$((PORT + 1))

  cat > "$ENV_FILE" <<EOF
# =============================================================================
#  Tüze CRM — Otomatik üretilmiş .env
#  Üretildi: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
#  ⚠ Bu dosyayı YEDEKLEYİN — şifreler kaybolursa veriye erişim de kaybedilir
# =============================================================================

# Sürüm (Docker Hub tag)
APP_VERSION=$APP_VERSION

# Image isimleri (update sistemi kontrol eder)
DOCKER_IMAGE_BACKEND=$HUB_USER/tuze-backend
DOCKER_IMAGE_FRONTEND=$HUB_USER/tuze-frontend
DOCKER_IMAGE_REPORT=$HUB_USER/tuze-report

# Veritabanı
POSTGRES_DB=tuze
POSTGRES_USER=tuze
POSTGRES_PASSWORD=$DB_PWD
DATABASE_URL=postgresql+asyncpg://tuze:$DB_PWD@postgres:5432/tuze

# Redis
REDIS_URL=redis://redis:6379/0

# Güvenlik
SECRET_KEY=$SECRET_KEY
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=30

# Uygulama
APP_ENV=production
APP_HOST=0.0.0.0
APP_PORT=8000
ALLOWED_ORIGINS=http://localhost,http://localhost:$PORT,http://127.0.0.1:$PORT

# Dosya yükleme
UPLOAD_DIR=/app/uploads
MAX_FILE_SIZE_MB=20

# Döviz kuru
TCMB_FETCH_CRON=0 16 * * 1-5
GOOGLE_FINANCE_FETCH_INTERVAL_MINUTES=30

# Sunucunun LAN IP adresi (boş bırakılırsa backend algılar)
HOST_IP=$LAN_IP

# Nginx port
HTTP_PORT=$PORT
HTTPS_PORT=$HTTPS_PORT

# İlk admin
ADMIN_EMAIL=admin@tuze.local
ADMIN_PASSWORD=$ADMIN_PWD
ADMIN_FULL_NAME=Sistem Yöneticisi
EOF
  chmod 600 "$ENV_FILE"
  ok ".env oluşturuldu (rastgele şifrelerle, chmod 600)"
  printf "      ${YELLOW}İlk giriş şifresi: ${BOLD}%s${RESET}\n" "$ADMIN_PWD"
  printf "      ${DIM}(Bu şifre sadece şimdi gösteriliyor — bir yere kaydedin)${RESET}\n"
fi

# ── 5. Image pull ────────────────────────────────────────────────────────────
step "5/7" "Docker Hub'dan İmajlar İndiriliyor"
if [ "${SKIP_PULL:-0}" = "1" ]; then
  warn "SKIP_PULL=1 — atlanıyor"
else
  export APP_VERSION
  if docker compose pull; then
    ok "Tüm imajlar indirildi"
  else
    die "İmaj indirme başarısız — internet bağlantısını kontrol edin"
  fi
fi

# ── 6. Servisler ─────────────────────────────────────────────────────────────
step "6/7" "Servisler Başlatılıyor"
if [ "${NO_START:-0}" = "1" ]; then
  warn "NO_START=1 — başlatılmıyor"
else
  docker compose up -d || die "Başlatma hatası"

  printf "  ${DIM}Sağlık kontrolü"
  ready=0
  for _ in $(seq 1 18); do
    sleep 3
    if curl -fsS "http://localhost:$PORT/api/health" >/dev/null 2>&1; then
      ready=1; break
    fi
    printf "."
  done
  printf "${RESET}\n"
  if [ "$ready" = "1" ]; then
    ok "Servisler ayakta"
  else
    warn "Servisler hâlâ başlatılıyor — birkaç dakikada hazır olur"
  fi
fi

# ── 7. Sonuç ─────────────────────────────────────────────────────────────────
step "7/7" "Tamamlandı"

ADMIN_PWD_SHOWN="$(grep '^ADMIN_PASSWORD=' "$ENV_FILE" | cut -d= -f2)"
LAN_IP_SHOWN="$(grep '^HOST_IP=' "$ENV_FILE" | cut -d= -f2)"

cat <<EOF

${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗
║                                                      ║
║   ✅  Kurulum Tamamlandı!                            ║
║                                                      ║
╚══════════════════════════════════════════════════════╝${RESET}

${BOLD}🌐 Erişim adresleri:${RESET}
   → http://localhost:${PORT}
EOF
if [ -n "$LAN_IP_SHOWN" ]; then
  echo "   → http://${LAN_IP_SHOWN}:${PORT}    ${DIM}# ağdaki diğer kullanıcılar için${RESET}"
fi

if [ "$UPGRADE" = "0" ]; then
cat <<EOF

${BOLD}🔐 İlk giriş:${RESET}
   E-posta: admin@tuze.local
   Şifre:   ${YELLOW}${BOLD}${ADMIN_PWD_SHOWN}${RESET}
   ${DIM}(Giriş yaptıktan sonra hemen şifrenizi değiştirin)${RESET}
EOF
fi

cat <<EOF

${BOLD}📁 Kurulum dizini:${RESET} $INSTALL_DIR
${BOLD}🛠 Komutlar:${RESET}
   cd $INSTALL_DIR
   docker compose ps               ${DIM}# durum${RESET}
   docker compose logs -f backend  ${DIM}# canlı log${RESET}
   docker compose restart          ${DIM}# yeniden başlat${RESET}

${BOLD}🔄 Güncelleme:${RESET}
   Uygulama içinden: Ayarlar > Güncelleme > "Şimdi Güncelle"
   Manuel: cd $INSTALL_DIR && docker compose pull && docker compose up -d

${YELLOW}⚠ .env dosyasını yedekleyin: $ENV_FILE
   İçinde DB şifresi ve JWT secret var.${RESET}
EOF

# Tarayıcıyı aç — ilk kurulumda /setup wizard'ına otomatik yönlenir
if [ "${NO_START:-0}" != "1" ] && [ "${ready:-0}" = "1" ]; then
  URL="http://localhost:${PORT}"
  echo ""
  echo "Tarayıcı 3 saniye içinde otomatik açılacak..."
  sleep 3
  if command -v xdg-open >/dev/null 2>&1; then xdg-open "$URL" >/dev/null 2>&1 &
  elif command -v open >/dev/null 2>&1; then open "$URL" >/dev/null 2>&1 &  # macOS
  else echo "Tarayıcıyı elle açın: $URL"
  fi
fi

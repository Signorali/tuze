# Tüze CRM

Modern alüminyum sanayi için ERP-entegre müşteri ilişkileri yönetimi sistemi.

## 🚀 Tek Satır Kurulum

### Windows (PowerShell)

```powershell
iwr -UseBasicParsing https://raw.githubusercontent.com/Signorali/tuze/main/install.ps1 -OutFile "$env:TEMP\tuze-install.ps1"; & "$env:TEMP\tuze-install.ps1"
```

### Linux / macOS

```bash
curl -fsSL https://raw.githubusercontent.com/Signorali/tuze/main/install.sh | bash
```

Bu komut çalıştırıldığında:
1. Docker Hub'dan tüm imajlar indirilir
2. Rastgele şifrelerle `.env` oluşturulur
3. Servisler başlatılır
4. **Tarayıcı otomatik açılır** → ilk kurulum sihirbazına yönlenir

**Gereksinimler:** Docker Desktop 4.30+, 2 GB RAM, 5 GB disk, 1 boş port (varsayılan: 9090).

Detaylı kılavuz: [install/README.md](install/README.md)

## 📦 Yapısı

- **Backend:** FastAPI + SQLAlchemy async + PostgreSQL
- **Frontend:** React 18 + Vite + Ant Design + TypeScript
- **Worker:** Celery + Redis
- **Gateway:** nginx
- **Report:** Carbone (PDF render)

## 🐳 Docker Hub

Tüm imajlar [hub.docker.com/u/signorali](https://hub.docker.com/u/signorali) üzerinde:

- [signorali/tuze-backend](https://hub.docker.com/r/signorali/tuze-backend)
- [signorali/tuze-frontend](https://hub.docker.com/r/signorali/tuze-frontend)
- [signorali/tuze-report](https://hub.docker.com/r/signorali/tuze-report)

## 🔄 Güncelleme

İki yol:

1. **Uygulama içinden:** Ayarlar > Güncelleme > "Şimdi Güncelle" (önerilen — sayfa otomatik yenilenir)
2. **Manuel:**
   ```bash
   cd ~/Tuze && docker compose pull && docker compose up -d
   ```

## 📋 Sürüm Geçmişi

Bkz. [CHANGELOG.md](CHANGELOG.md)

## 🛠 Geliştirici Notları

### Dev mode

```bash
git clone https://github.com/Signorali/tuze.git
cd tuze
docker compose up -d
# Backend Python kod değişikliği → uvicorn --reload (otomatik)
# Frontend TSX değişikliği → Vite HMR (otomatik)
```

### Yeni sürüm yayınlama

```powershell
./publish-dockerhub.ps1 -Version 1.0.1
```

Bu script:
- `.env` ve `backend/VERSION` dosyalarını günceller
- Tüm imajları yeni APP_VERSION ile build eder
- Sanity check yapar (`alembic heads`, import testi)
- `signorali/tuze-*:1.0.1` + `:latest` tag'ler
- Docker Hub'a push eder

Müşterinin sisteminde **Ayarlar > Güncelleme > Yeniden Kontrol Et** → kırmızı badge görünür → "Şimdi Güncelle" tıklanır → bitti.

## 📄 Lisans

Bu yazılım [Şartlara] tabidir. Lütfen lisans dosyasına bakın.

## 📞 İletişim

- GitHub Issues: [signorali/tuze/issues](https://github.com/Signorali/tuze/issues)
- E-posta: alikoken@outlook.com

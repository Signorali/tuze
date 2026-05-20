# Tüze CRM — Kurulum

Tek-tık kurulum paketi. Docker Hub'dan tüm imajları çeker, secret üretir, servisleri ayağa kaldırır.

## ⚡ Hızlı Kurulum

### Windows — PowerShell (tek satır)

```powershell
iwr -UseBasicParsing https://raw.githubusercontent.com/Signorali/tuze/main/install.ps1 -OutFile "$env:TEMP\tuze-install.ps1"; & "$env:TEMP\tuze-install.ps1"
```

Bu komut yapıştırıldığında:
1. `install.ps1` GitHub'dan indirilir
2. Kurulum başlar (Docker kontrolü, .env oluştur, image pull, container başlat)
3. Tamamlanınca **tarayıcı otomatik açılır** → ilk kurulum sihirbazına yönlenir

> **Not:** Yönetici hakkı gerekmez, kullanıcının kendi `%USERPROFILE%\Tuze` dizinine kurulur.

### Linux / macOS — Bash (tek satır)

```bash
curl -fsSL https://raw.githubusercontent.com/Signorali/tuze/main/install.sh | bash
```

## 🛠 Gereksinimler

| Bileşen | Minimum sürüm | Nasıl kurulur |
|---------|---------------|---------------|
| Docker | 24.0+ | [docs.docker.com/get-docker](https://docs.docker.com/get-docker/) |
| Docker Compose | v2.20+ | Docker Desktop ile birlikte gelir |
| RAM | 2 GB | — |
| Disk | 5 GB boş | — |
| Port | 9090 (HTTP) | İhtiyaç halinde `-Port 8080` ile değiştirilebilir |

## 📋 Parametreler

### Windows

```powershell
./install.ps1 [-InstallDir <path>] [-Port <num>] [-Version <semver>] [-NoStart]
```

| Parametre | Varsayılan | Açıklama |
|-----------|-----------|----------|
| `-InstallDir` | `$HOME\Tuze` | Kurulum dizini |
| `-Port` | `9090` | HTTP port (HTTPS otomatik +1) |
| `-Version` | `latest` | Docker Hub tag (ör. `1.0.1`) |
| `-NoStart` | — | Sadece kur, servisleri başlatma |

### Linux/Mac

Çevre değişkenleri ile:

```bash
INSTALL_DIR=/opt/tuze PORT=8080 ./install.sh
```

## 🔄 Güncelleme

İki yol:

1. **Uygulama içinden (önerilen):** Ayarlar > Güncelleme > "Yeniden Kontrol Et" → "Şimdi Güncelle"
2. **Manuel:**
   ```bash
   cd ~/tuze  # veya kurulum dizininiz
   docker compose pull
   docker compose up -d
   ```

## 🔐 İlk Giriş

Kurulum tamamlandığında ekrana yazılan **rastgele şifre** ile giriş yapın:
- E-posta: `admin@tuze.local`
- Şifre: (kurulum çıktısında gösterilen)

Bu şifreyi `.env` dosyasında da bulabilirsiniz:
```
ADMIN_PASSWORD=...
```

Giriş yaptıktan sonra **hemen değiştirin** (Profil > Şifre Değiştir).

## 📁 Dosya Yapısı (kurulumdan sonra)

```
<INSTALL_DIR>/
├── .env                    # Şifreler ve config (YEDEKLEYIN!)
├── docker-compose.yml      # Servis tanımları
├── nginx/
│   └── nginx.conf          # Reverse proxy config
├── uploads/                # Yüklenen dosyalar (logolar, ekler)
└── (postgres_data — Docker volume, ayrı tutulur)
```

## 🛡 Yedekleme

**Kritik dosyalar:**
- `.env` — şifreler (kopyalayın)
- `uploads/` — yüklenen dosyalar (kopyalayın)
- PostgreSQL volume:
  ```bash
  docker exec tuze_postgres pg_dump -U tuze tuze > yedek-$(date +%Y%m%d).sql
  ```

## 🐛 Sorun Giderme

### Port çakışması
```powershell
./install.ps1 -Port 8080   # 9090 yerine 8080
```

### Servis başlamadı
```bash
cd ~/tuze
docker compose ps                  # durum
docker compose logs backend        # backend log'u
docker compose restart backend     # tek servis yeniden başlat
```

### Sıfırdan başla (DİKKAT: tüm verileri siler)
```bash
cd ~/tuze
docker compose down -v   # -v = volume'leri de sil
rm -rf .env uploads/
./install.ps1   # yeniden çalıştır
```

## 🔗 Bağlantılar

- **Docker Hub:** https://hub.docker.com/u/signorali
- **Sürüm geçmişi:** [CHANGELOG.md](../CHANGELOG.md)

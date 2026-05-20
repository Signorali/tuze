# Tüze CRM — Değişiklik Geçmişi

Bu dosya semantic versioning (SemVer) standardına göre tutulur:

- **MAJOR** (X.0.0) — Geriye uyumsuz kırılma (DB şema değişikliği vb.)
- **MINOR** (1.X.0) — Geriye uyumlu yeni özellik
- **PATCH** (1.0.X) — Hata düzeltme, küçük iyileştirme

Yayın akışı:
```powershell
./publish-dockerhub.ps1 -Version 1.0.1
```

---

## [1.0.0] — 2026-05-20 — İlk yayın

### Eklenen
- **Update sistemi** — Docker Hub üzerinden tek-tık yazılım güncelleme
  - Ayarlar > Güncelleme sekmesinde mevcut + en yüksek sürüm karşılaştırması
  - Yeni sürüm varsa header'da kırmızı badge
  - Anlık ilerleme bar'ı (Redis-backed phases: PULLING → RECREATING → COMPLETED)
  - Backend self-recreate sidecar pattern'i (docker:27-cli)
  - Update geçmişi tablosu
- **Fatura modülü** kapsamlı geliştirmeler
  - 155 XML kolonunun tamamı işleniyor (40 yeni alan + JSONB `extra_data`)
  - FASON İŞÇİLİK otomatik tespiti — magenta badge ana listede
  - Kar Merkezi, Gelir-Gider, Parti kalem detayında varsayılan görünür
  - "Tam Yenile" butonu — hash'leri sıfırlayıp tüm kayıtları yeniden çeker
- **İzin sistemi** tutarlılık düzeltmeleri
  - Admin rolü `/auth/me`'de tüm izinleri alır (require_permission ile aynı)
  - `PriceMatrixPage` `price_matrix.manage` izninini doğru kontrol ediyor
  - `tevkifat.py` ve `exchange_rates.py` artık geçerli izin kodları kullanıyor
- **Development modu** — `docker-compose.override.yml`
  - Backend Python kod değişiklikleri → uvicorn auto-reload
  - Frontend TSX/CSS değişiklikleri → Vite HMR (F5 yok)
  - Volume mount + watcher polling Windows host için ayarlı
- **Para formatı** standardize edildi (10+ sayfada)
- **İrsaliye sayfası** sıralama: tarih + irsaliye_no artan (eski → yeni)
- **Otomatik IP tespiti** — `guncelle-ip.ps1` LAN IP'sini `.env`'e yazar
- **CORS** tüm private LAN aralıkları için regex tabanlı

### Düzeltilen
- Fatura detayında React Rules of Hooks ihlali → beyaz ekran (Ürün Adı sütunu)
- Kullanıcı oluşturma sonrası ilişki lazy-load hatası
- Fiyat matrisi indirim yönü pozitif/negatif mantığı
- Nakliye Dahil bayrağı teklife aktarımı
- Teslim tarihi varsayılan 4 hafta sonrası

---

## Yayınlanmamış sürümler

Yeni özellikleri buraya ekleyin; publish sırasında üst başlık altına taşınır.

### Eklenen
- (henüz yok)

### Düzeltilen
- (henüz yok)

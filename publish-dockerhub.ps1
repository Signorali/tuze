#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Tüze CRM — Docker Hub'a yayın script'i (ergenekon ile birebir akış).

.DESCRIPTION
  1. .env'deki APP_VERSION'u günceller
  2. backend/VERSION dosyasını günceller (image'a bake edilir)
  3. Tüm imajları APP_VERSION ile yeniden build eder
  4. signorali/tuze-{backend,frontend,report}:{X.Y.Z, latest} olarak tag'ler
  5. Docker Hub'a push eder

.EXAMPLE
  ./publish-dockerhub.ps1 -Version 1.0.1
  ./publish-dockerhub.ps1 -Version 1.1.0 -SkipBuild   # build atla (mevcut imajları sadece tag+push)

.NOTES
  Önkoşullar:
    - docker login (signorali kullanıcısıyla)
    - Docker Desktop çalışıyor
    - CHANGELOG.md güncel (manuel)
#>
param(
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$HUB_USER = "signorali"

# Repo adları (docker-compose.yml'deki image: ile birebir eşleşmeli)
$SERVICES = @{
    "tuze-backend"  = "tuze-backend"
    "tuze-frontend" = "tuze-frontend"
    "tuze-report"   = "tuze-report"
}

Write-Host ""
Write-Host "=== Tüze CRM Docker Hub Publisher ===" -ForegroundColor Cyan
Write-Host "    Version: $Version" -ForegroundColor Cyan
Write-Host "    Hub User: $HUB_USER" -ForegroundColor Cyan
Write-Host ""

# Çalışma dizini = script konumu
Push-Location $PSScriptRoot

try {
    # 1. APP_VERSION'u .env'de güncelle
    Write-Host "[1/6] APP_VERSION'u .env'de güncelleniyor..." -ForegroundColor Blue
    if (Test-Path ".env") {
        $content = Get-Content ".env" -Raw
        if ($content -match "APP_VERSION=") {
            $content = $content -replace "APP_VERSION=.*", "APP_VERSION=$Version"
        } else {
            $content = $content.TrimEnd() + "`nAPP_VERSION=$Version`n"
        }
        Set-Content -Path ".env" -Value $content -NoNewline -Encoding UTF8
        Write-Host "  .env → APP_VERSION=$Version" -ForegroundColor Green
    } else {
        Write-Host "  UYARI: .env bulunamadı" -ForegroundColor Yellow
    }

    # 2. backend/VERSION'u güncelle (image'a bake edilen)
    Write-Host ""
    Write-Host "[2/6] backend/VERSION güncelleniyor..." -ForegroundColor Blue
    Set-Content -Path "backend/VERSION" -Value $Version -NoNewline -Encoding UTF8
    Write-Host "  backend/VERSION → $Version" -ForegroundColor Green

    # 3. Build (skip edilebilir)
    if (-not $SkipBuild) {
        Write-Host ""
        Write-Host "[3/6] İmajlar build ediliyor (APP_VERSION=$Version baked-in)..." -ForegroundColor Blue
        $env:APP_VERSION = $Version
        # NOT: override.yml dev mount/comand'i kaplar; production build için sadece base yml kullan
        docker compose -f docker-compose.yml build backend frontend report 2>&1 | Select-String -Pattern "Built|ERROR|error" | Select-Object -Last 14
        if ($LASTEXITCODE -ne 0) {
            throw "Build başarısız"
        }
        Write-Host "  ✓ Build tamamlandı" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "[3/6] Build atlandı (-SkipBuild)" -ForegroundColor Yellow
    }

    # 4. Sanity: backend hızlı boot testi (import hatası olmasın)
    Write-Host ""
    Write-Host "[4/6] Backend sanity check (import test)..." -ForegroundColor Blue
    $importTest = docker run --rm --entrypoint python "signorali/tuze-backend:${Version}" -c "from app.main import app; print('OK')" 2>&1
    if ($importTest -notmatch "OK") {
        Write-Host "  HATA: backend boot başarısız:" -ForegroundColor Red
        Write-Host $importTest -ForegroundColor Red
        throw "Backend image broken"
    }
    Write-Host "  ✓ Backend import OK" -ForegroundColor Green

    # 5. Mevcut imajları kontrol et + Hub tag'lerini ata
    Write-Host ""
    Write-Host "[5/6] Hub tag'leri atanıyor..." -ForegroundColor Blue
    foreach ($repo in $SERVICES.Keys) {
        $localTag = "${HUB_USER}/${repo}:${Version}"
        $latestTag = "${HUB_USER}/${repo}:latest"

        # docker-compose build sonrası image zaten "signorali/tuze-X:VERSION" formatında oluşur
        # Bu sayede ek tag adımı sadece :latest için gerekli
        docker tag $localTag $latestTag 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Tag başarısız: $localTag → $latestTag"
        }
        Write-Host "  ✓ $repo : $Version + latest" -ForegroundColor Green
    }

    # 6. Push
    Write-Host ""
    Write-Host "[6/6] Docker Hub'a push ediliyor..." -ForegroundColor Blue
    foreach ($repo in $SERVICES.Keys) {
        Write-Host ""
        Write-Host "  Push: ${HUB_USER}/${repo}:${Version}" -ForegroundColor Yellow
        docker push "${HUB_USER}/${repo}:${Version}" 2>&1 | Select-String -Pattern "Pushed|already|denied|error" | Select-Object -Last 3
        if ($LASTEXITCODE -ne 0) { throw "Push başarısız: ${repo}:${Version}" }

        Write-Host "  Push: ${HUB_USER}/${repo}:latest" -ForegroundColor Yellow
        docker push "${HUB_USER}/${repo}:latest" 2>&1 | Select-String -Pattern "Pushed|already|denied|error" | Select-Object -Last 3
        if ($LASTEXITCODE -ne 0) { throw "Push başarısız: ${repo}:latest" }

        Write-Host "  ✓ $repo yayınlandı" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "=== TÜM İMAJLAR BAŞARIYLA YAYINLANDI ===" -ForegroundColor Green
    Write-Host "Hub: https://hub.docker.com/u/$HUB_USER" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Yayınlandı:" -ForegroundColor White
    foreach ($repo in $SERVICES.Keys) {
        Write-Host "  ${HUB_USER}/${repo}:${Version}" -ForegroundColor Gray
        Write-Host "  ${HUB_USER}/${repo}:latest" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Sonraki adım: Tüze sayfasında Ayarlar > Güncelleme → 'Yeniden Kontrol Et'" -ForegroundColor White
}
finally {
    Pop-Location
}

# Setup Firebase sekali jalan (C1 push notifikasi).
#
# Cara pakai (PowerShell):
#   1) Taruh 2 file di %TEMP%\opencode\firebase\ :
#      - google-services.json          (dari Firebase console -> Add Android app)
#      - firebase-service-account.json (dari Firebase console -> Service accounts -> Generate new private key)
#   2) Jalankan dari root repo:
#      powershell -ExecutionPolicy Bypass -File scripts/setup_firebase.ps1
#
# Script ini akan:
#   - Set secret GOOGLE_SERVICES_JSON  ke GitHub (agar APK dapat token FCM)
#   - Set env   FCM_SERVICE_ACCOUNT_JSON ke Vercel  (agar backend dapat kirim push)
#   - Redeploy backend
#   - Menampilkan langkah verifikasi
param(
    [string]$FirebaseDir = "$env:TEMP\opencode\firebase"
)

$ErrorActionPreference = "Stop"

$gsFile = Join-Path $FirebaseDir "google-services.json"
$saFile = Join-Path $FirebaseDir "firebase-service-account.json"

if (-not (Test-Path -LiteralPath $gsFile) -or -not (Test-Path -LiteralPath $saFile)) {
    Write-Host "ERROR: pastikan kedua file ada di $FirebaseDir"
    Write-Host "  - google-services.json          (ada? $(Test-Path -LiteralPath $gsFile))"
    Write-Host "  - firebase-service-account.json (ada? $(Test-Path -LiteralPath $saFile))"
    exit 1
}

# Validasi JSON
try {
    Get-Content -LiteralPath $gsFile -Raw | ConvertFrom-Json | Out-Null
    Get-Content -LiteralPath $saFile -Raw | ConvertFrom-Json | Out-Null
    Write-Host "OK: kedua file valid JSON."
} catch {
    Write-Host "ERROR: salah satu file bukan JSON valid: $($_.Exception.Message)"
    exit 1
}

# 1) Simpan secret di temporary file (gh secret set butuh stdin/file)
$tmpGithub = Join-Path $env:TEMP "gs_github.txt"
$tmpVercel = Join-Path $env:TEMP "sa_vercel.txt"
Copy-Item -LiteralPath $gsFile -Destination $tmpGithub -Force
Copy-Item -LiteralPath $saFile -Destination $tmpVercel -Force

try {
    Write-Host "1/3 Set GitHub secret GOOGLE_SERVICES_JSON ..."
    gh secret set GOOGLE_SERVICES_JSON --body (Get-Content -LiteralPath $tmpGithub -Raw)
    if ($LASTEXITCODE -ne 0) { throw "gh secret set gagal" }

    Write-Host "2/3 Set Vercel env FCM_SERVICE_ACCOUNT_JSON (production) ..."
    Get-Content -LiteralPath $tmpVercel -Raw | & "C:\Users\HP\AppData\Roaming\npm\vercel.cmd" env add FCM_SERVICE_ACCOUNT_JSON production --scope "team_2X57gh17awzqT1o28gQDYVnn"
    if ($LASTEXITCODE -ne 0) { throw "vercel env add gagal" }

    Write-Host "3/3 Redeploy backend ..."
    & "C:\Users\HP\AppData\Roaming\npm\vercel.cmd" deploy --prod --yes --scope "team_2X57gh17awzqT1o28gQDYVnn" --cwd "ml_backend"
    if ($LASTEXITCODE -ne 0) { throw "vercel deploy gagal" }
} finally {
    Remove-Item -LiteralPath $tmpGithub, $tmpVercel -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "SELESAI. Verifikasi:"
Write-Host "  1) https://cangcilung-trading-api.vercel.app/push/enabled  -> harus { \"enabled\": true }"
Write-Host "  2) Build APK baru di GitHub Actions (memasukkan google-services.json)"
Write-Host "  3) Uji: https://cangcilung-trading-api.vercel.app/push/send?title=Test&body=Halo"
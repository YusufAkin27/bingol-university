# iOS push hazirlik kontrolu (sir degerleri yazdirilmaz). Kullanim:
#   powershell -File scripts/check-ios-push.ps1            (yalniz kontrol)
#   powershell -File scripts/check-ios-push.ps1 -Enable    (BuPush.xcconfig olusturur: push yetkisi acilir)
# -Enable yalniz ODEMELI Apple Developer hesabi ile imzalarken acilmali (ucretsiz Apple ID push yetkisi veremez).
param([switch]$Enable)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$ios = Join-Path $root 'mobile\ios'
$fail = 0; $warn = 0
function Ok($m)   { Write-Host "[OK]   $m" }
function Bad($m)  { Write-Host "[YOK]  $m"; $script:fail++ }
function Warn($m) { Write-Host "[UYARI] $m"; $script:warn++ }
function Raw($p)  { if (Test-Path $p) { [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) } else { '' } }

$pbx  = Raw (Join-Path $ios 'Runner.xcodeproj\project.pbxproj')
$info = Raw (Join-Path $ios 'Runner\Info.plist')
$plistPath = Join-Path $ios 'Runner\GoogleService-Info.plist'
$plist = Raw $plistPath

# 1) Proje bundle id
$m = [regex]::Match($pbx, 'PRODUCT_BUNDLE_IDENTIFIER = ([A-Za-z0-9\.\-]+);(?![\s\S]{0,0})')
$bundles = [regex]::Matches($pbx, 'PRODUCT_BUNDLE_IDENTIFIER = ([A-Za-z0-9\.\-]+);') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -notlike '*.RunnerTests' } | Select-Object -Unique
$bundle = $bundles | Select-Object -First 1
if ($bundle) { Ok "Xcode bundle id: $bundle" } else { Bad 'PRODUCT_BUNDLE_IDENTIFIER okunamadi' }

# 2) GoogleService-Info.plist
if ($plist) {
  Ok 'ios/Runner/GoogleService-Info.plist var'
  $b = [regex]::Match($plist, '<key>BUNDLE_ID</key>\s*<string>([^<]+)</string>')
  if ($b.Success -and $b.Groups[1].Value -eq $bundle) { Ok 'plist BUNDLE_ID Xcode bundle id ile eslesiyor' }
  elseif ($b.Success) { Bad "plist BUNDLE_ID ($($b.Groups[1].Value)) Xcode bundle id ($bundle) ile ESLESMIYOR" }
  else { Bad 'plist icinde BUNDLE_ID yok (gecersiz dosya)' }
  foreach ($k in 'GCM_SENDER_ID','GOOGLE_APP_ID','API_KEY','PROJECT_ID') {
    if ($plist -match "<key>$k</key>") { Ok "plist anahtari $k mevcut (deger gizli)" } else { Bad "plist anahtari $k eksik" }
  }
  if ($plist -match '<key>IS_GCM_ENABLED</key>\s*<false/>') { Warn 'IS_GCM_ENABLED false gorunuyor' }
} else {
  Warn 'GoogleService-Info.plist henuz yok: push sessizce devre disi (beklenen, anahtar gelince eklenir)'
}

# 3) Entitlements
foreach ($pair in @(@('Runner.entitlements','development'), @('RunnerRelease.entitlements','production'))) {
  $t = Raw (Join-Path $ios ('Runner\' + $pair[0]))
  if ($t -match "<key>aps-environment</key>\s*<string>$($pair[1])</string>") { Ok "$($pair[0]): aps-environment=$($pair[1])" } else { Bad "$($pair[0]) eksik/yanlis (beklenen $($pair[1]))" }
}
$n = ([regex]::Matches($pbx, 'CODE_SIGN_ENTITLEMENTS = "\$\(BU_PUSH_ENTITLEMENTS\)"')).Count
if ($n -ge 3) { Ok "pbxproj: CODE_SIGN_ENTITLEMENTS 3 yapilandirmada (Debug/Release/Profile)" } else { Bad "pbxproj CODE_SIGN_ENTITLEMENTS bagi eksik ($n/3)" }
if ($pbx -match 'Bundle GoogleService-Info\.plist \(optional\)') { Ok 'pbxproj: plist paketleme betigi var (dosya yoksa atlar)' } else { Bad 'pbxproj plist paketleme build fazi yok' }

# 4) Info.plist
if ($info -match '<key>UIBackgroundModes</key>\s*<array>[\s\S]*?<string>remote-notification</string>') { Ok 'Info.plist: UIBackgroundModes remote-notification' } else { Bad 'Info.plist: UIBackgroundModes remote-notification yok' }
if ($info -match 'FirebaseAppDelegateProxyEnabled') { Warn 'FirebaseAppDelegateProxyEnabled tanimli: proxy kapaliysa APNs belirteci elle aktarilmali; silmeniz onerilir' } else { Ok 'FirebaseAppDelegateProxyEnabled tanimsiz (proxy acik, onerilen)' }

# 5) Push yetkisi anahtari
$sw = Join-Path $ios 'Flutter\BuPush.xcconfig'
if (Test-Path $sw) { Ok 'ios/Flutter/BuPush.xcconfig var: push yetkisi (aps-environment) imzaya EKLENIR' }
elseif ($Enable) { Copy-Item (Join-Path $ios 'Flutter\BuPush.xcconfig.example') $sw; Ok 'BuPush.xcconfig olusturuldu: push yetkisi acildi (odemeli hesap gerekir)' }
else { Warn 'BuPush.xcconfig yok: imzaya push yetkisi eklenmez (ucretsiz Apple ID ile derleme icin dogru). Odemeli hesapta: -Enable' }

# 6) Swift
$sd = Raw (Join-Path $ios 'Runner\AppDelegate.swift')
if ($sd -match 'UNUserNotificationCenter\.current\(\)\.delegate') { Ok 'AppDelegate: UNUserNotificationCenter delegesi' } else { Bad 'AppDelegate: UNUserNotificationCenter delegesi yok' }

Write-Host ''
Write-Host "Sonuc: $fail hata, $warn uyari"
Write-Host 'Elle dogrulanacaklar: Firebase konsoluna APNs .p8 (Key ID + Team ID) yuklendi mi; Apple Developer App ID Push yetenegi; gercek cihazda on plan/arka plan/kapali testi.'
if ($fail -gt 0) { exit 1 } else { exit 0 }

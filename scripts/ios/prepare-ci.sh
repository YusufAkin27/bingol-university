#!/usr/bin/env bash
# iOS yayin hazirligi (macOS CI). DOGRULANAMADI: Windows'ta calistirilamaz (PlistBuddy/macOS gerekir).
# Yaptiklari (idempotent, sir YAZDIRMAZ):
#   1) GoogleService-Info.plist'i gizli degiskenden yazar (yoksa REQUIRE_PUSH=1 iken hata, aksi halde uyari)
#   2) BuPush.xcconfig olusturur -> push yetkisi (aps-environment) imzaya baglanir (Release = production)
#   3) Release icin Info.plist'ten gelistirme amacli NSLocalNetworkUsageDescription'i siler (yalniz CI calisma kopyasinda)
#   4) plist BUNDLE_ID ile Xcode bundle id'sinin eslestigini dogrular (install-firebase-plist.sh)
# Ortam:
#   IOS_GOOGLE_SERVICE_INFO_PLIST_BASE64  GoogleService-Info.plist'in base64'u (GitHub Secret / Codemagic degiskeni)
#   REQUIRE_PUSH=1                        plist yoksa durdur (TestFlight/uretim icin ONERILIR)
#   KEEP_LOCAL_NETWORK_KEY=1              NSLocalNetworkUsageDescription'i silme
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IOS="$ROOT/mobile/ios"
PLIST="$IOS/Runner/GoogleService-Info.plist"
INFO="$IOS/Runner/Info.plist"

# 1) GoogleService-Info.plist (install-firebase-plist.sh: ayrisir, BUNDLE_ID/PROJECT_ID/gitignore dogrulanir; uyusmazsa DURUR)
if [ -n "${IOS_GOOGLE_SERVICE_INFO_PLIST_BASE64:-}" ]; then
  bash "$ROOT/scripts/ios/install-firebase-plist.sh" --base64-env IOS_GOOGLE_SERVICE_INFO_PLIST_BASE64
elif [ -f "$PLIST" ]; then
  bash "$ROOT/scripts/ios/install-firebase-plist.sh" --check
elif [ "${REQUIRE_PUSH:-0}" = "1" ]; then
  echo "HATA: GoogleService-Info.plist yok ve IOS_GOOGLE_SERVICE_INFO_PLIST_BASE64 tanimsiz (REQUIRE_PUSH=1)" >&2
  exit 1
else
  echo "UYARI: GoogleService-Info.plist yok: push devre disi derlenir (TestFlight'ta bildirim gelmez)" >&2
fi

# 2) Push yetkisi anahtari
cp -f "$IOS/Flutter/BuPush.xcconfig.example" "$IOS/Flutter/BuPush.xcconfig"
echo "BuPush.xcconfig olusturuldu (Release -> RunnerRelease.entitlements, aps-environment=production)"

# 3) Release'te yerel ag izin metni gereksiz
if [ "${KEEP_LOCAL_NETWORK_KEY:-0}" != "1" ] && command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Delete :NSLocalNetworkUsageDescription" "$INFO" 2>/dev/null \
    && echo "Info.plist: NSLocalNetworkUsageDescription silindi (yalniz CI kopyasi)" || true
fi

# 4) Bundle id (plist eslesmesi 1. adimda dogrulandi)
BUNDLE="$(grep -o 'PRODUCT_BUNDLE_IDENTIFIER = [A-Za-z0-9.-]*;' "$IOS/Runner.xcodeproj/project.pbxproj" | grep -v RunnerTests | head -1 | sed 's/.*= \(.*\);/\1/')"
echo "Xcode bundle id: $BUNDLE"
echo "prepare-ci tamam"

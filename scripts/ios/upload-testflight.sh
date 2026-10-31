#!/usr/bin/env bash
# IPA'yi TestFlight'a (App Store Connect) yukler. DOGRULANAMADI: Windows'ta calistirilamaz.
# Kullanim: scripts/ios/upload-testflight.sh [ipa-yolu]   (varsayilan: mobile/build/ios-release/ipa/*.ipa)
# Ortam: IOS_API_KEY_ID, IOS_API_ISSUER_ID, IOS_API_KEY_P8_BASE64 (build-ipa.sh ile ayni)
# Yontem: xcrun altool --upload-app (API anahtari ~/.appstoreconnect/private_keys altindan okunur).
# Alternatif (ayni sonuc): Transporter uygulamasi / fastlane pilot (mobile/ios/fastlane/Fastfile "beta" hatti).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IPA="${1:-$(ls "$ROOT"/mobile/build/ios-release/ipa/*.ipa 2>/dev/null | head -1)}"
: "${IPA:?IPA bulunamadi}"
: "${IOS_API_KEY_ID:?IOS_API_KEY_ID gerekli}"
: "${IOS_API_ISSUER_ID:?IOS_API_ISSUER_ID gerekli}"
: "${IOS_API_KEY_P8_BASE64:?IOS_API_KEY_P8_BASE64 gerekli}"

KEY_DIR="$HOME/.appstoreconnect/private_keys"
mkdir -p "$KEY_DIR"
KEY_PATH="$KEY_DIR/AuthKey_${IOS_API_KEY_ID}.p8"
printf '%s' "$IOS_API_KEY_P8_BASE64" | base64 --decode > "$KEY_PATH"
chmod 600 "$KEY_PATH"
trap 'rm -f "$KEY_PATH"' EXIT

echo "Yukleniyor: $IPA"
xcrun altool --upload-app --type ios --file "$IPA" \
  --apiKey "$IOS_API_KEY_ID" --apiIssuer "$IOS_API_ISSUER_ID"
echo "Yukleme istegi tamam. App Store Connect > TestFlight'ta isleme (10-30 dk) sonrasi gorunur."

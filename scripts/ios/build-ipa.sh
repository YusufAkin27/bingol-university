#!/usr/bin/env bash
# App Store / TestFlight IPA uretimi (macOS CI). DOGRULANAMADI: Windows'ta calistirilamaz; ilk macOS kosusunda izleyin.
# Akis: flutter build ios --config-only (obfuscate + dart-define) -> xcodebuild archive -> xcodebuild -exportArchive.
# Imzalama: App Store Connect API anahtari ile "cloud signing" (-allowProvisioningUpdates + -authenticationKey*):
# dagitim sertifikasi ve profil Apple tarafinda otomatik yonetilir; depoda/CI'da .p12 veya profil GEREKMEZ.
# Gerekenler (ortam; sirlar yazdirilmaz):
#   IOS_TEAM_ID              Apple Developer Team ID (10 karakter)
#   IOS_API_KEY_ID           App Store Connect API Key ID
#   IOS_API_ISSUER_ID        Issuer ID (UUID)
#   IOS_API_KEY_P8_BASE64    AuthKey_<KEYID>.p8 dosyasinin base64'u
# Istege bagli:
#   IOS_BUILD_NUMBER (CFBundleVersion; varsayilan pubspec +N), API_BASE (varsayilan https://bukampus.com.tr), APP_VERSION (varsayilan pubspec surum adi),
#   OUT_DIR (varsayilan mobile/build/ios-release, gitignored), SKIP_FLUTTER_TEST yok (testler ayri is akisinda kosar)
# Cikti: $OUT_DIR/ipa/*.ipa, $OUT_DIR/symbols (--split-debug-info; SAKLAYIN: cokme izleri icin), $OUT_DIR/Runner.xcarchive
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MOBILE="$ROOT/mobile"
OUT_DIR="${OUT_DIR:-$MOBILE/build/ios-release}"
API_BASE="${API_BASE:-https://bukampus.com.tr}"

: "${IOS_TEAM_ID:?IOS_TEAM_ID gerekli}"
: "${IOS_API_KEY_ID:?IOS_API_KEY_ID gerekli}"
: "${IOS_API_ISSUER_ID:?IOS_API_ISSUER_ID gerekli}"
: "${IOS_API_KEY_P8_BASE64:?IOS_API_KEY_P8_BASE64 gerekli}"

case "$API_BASE" in https://*) ;; *) echo "HATA: API_BASE https olmali: $API_BASE" >&2; exit 1 ;; esac

# Surum: pubspec "version: 2.0.3+20003" -> CFBundleShortVersionString=2.0.3, CFBundleVersion=20003
VERSION_LINE="$(grep -E '^version:' "$MOBILE/pubspec.yaml" | head -1 | sed 's/version:[[:space:]]*//')"
BUILD_NAME="${VERSION_LINE%%+*}"
BUILD_NUMBER="${VERSION_LINE##*+}"
# TestFlight ayni surum icin ayni CFBundleVersion'i iki kez KABUL ETMEZ. CI, "next-build-number" adimiyla
# IOS_BUILD_NUMBER verir (TestFlight'taki son numara + 1); verilmezse pubspec numarasi kullanilir.
if [ -n "${IOS_BUILD_NUMBER:-}" ]; then
  case "$IOS_BUILD_NUMBER" in *[!0-9]*|"") echo "HATA: IOS_BUILD_NUMBER sayi olmali: $IOS_BUILD_NUMBER" >&2; exit 1 ;; esac
  BUILD_NUMBER="$IOS_BUILD_NUMBER"
fi
APP_VERSION="${APP_VERSION:-$BUILD_NAME}"
echo "Surum: $BUILD_NAME ($BUILD_NUMBER)"

# Xcode surumu: Apple, yuklemelerin guncel Xcode/SDK ile derlenmesini ister (2026-04'ten beri Xcode 26 / iOS 26 SDK)
XC_MAJOR="$(xcodebuild -version | head -1 | sed 's/Xcode \([0-9]*\).*/\1/')"
echo "Xcode $(xcodebuild -version | head -1)"
if [ "${XC_MAJOR:-0}" -lt 26 ] && [ "${ALLOW_OLD_XCODE:-0}" != "1" ]; then
  echo "HATA: Xcode 26+ gerekli (App Store yukleme sarti). Eski Xcode ile denemek icin ALLOW_OLD_XCODE=1" >&2
  exit 1
fi

# API anahtari: xcodebuild -authenticationKeyPath icin gecici dosya (is bitince silinir)
KEY_DIR="$(mktemp -d)"
trap 'rm -rf "$KEY_DIR"' EXIT
KEY_PATH="$KEY_DIR/AuthKey_${IOS_API_KEY_ID}.p8"
printf '%s' "$IOS_API_KEY_P8_BASE64" | base64 --decode > "$KEY_PATH"
chmod 600 "$KEY_PATH"
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$KEY_PATH" -authenticationKeyID "$IOS_API_KEY_ID" -authenticationKeyIssuerID "$IOS_API_ISSUER_ID")

mkdir -p "$OUT_DIR" "$OUT_DIR/symbols" "$OUT_DIR/ipa"
cd "$MOBILE"
flutter pub get

# Flutter yapilandirmasi (Generated.xcconfig, eklenti Swift paketi) - derleme xcodebuild'e birakilir
flutter build ios --config-only --release --no-codesign \
  --obfuscate --split-debug-info="$OUT_DIR/symbols" \
  --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER" \
  --dart-define=API_BASE="$API_BASE" --dart-define=APP_VERSION="$APP_VERSION"

cd "$MOBILE/ios"
xcodebuild archive \
  -workspace Runner.xcworkspace -scheme Runner -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$OUT_DIR/Runner.xcarchive" \
  DEVELOPMENT_TEAM="$IOS_TEAM_ID" CODE_SIGN_STYLE=Automatic \
  "${AUTH[@]}"

# Dogrulama: push yetkisi arsive girdi mi? (BuPush.xcconfig yoksa sessizce eksik kalir)
APP="$OUT_DIR/Runner.xcarchive/Products/Applications/Runner.app"
ENT="$(codesign -d --entitlements :- "$APP" 2>/dev/null || true)"
if ! printf '%s' "$ENT" | grep -q "aps-environment"; then
  echo "HATA: arsivde aps-environment yok (prepare-ci.sh calistirildi mi? BuPush.xcconfig var mi?)" >&2
  exit 1
fi
echo "Arsivde aps-environment var"

sed "s/__TEAM_ID__/$IOS_TEAM_ID/" "$MOBILE/ios/ExportOptions.plist" > "$OUT_DIR/ExportOptions.plist"
xcodebuild -exportArchive \
  -archivePath "$OUT_DIR/Runner.xcarchive" \
  -exportOptionsPlist "$OUT_DIR/ExportOptions.plist" \
  -exportPath "$OUT_DIR/ipa" \
  "${AUTH[@]}"

ls -la "$OUT_DIR/ipa"
echo "build-ipa tamam: $(ls "$OUT_DIR"/ipa/*.ipa)"

#!/usr/bin/env bash
# iOS bundle id'sini TEK komutla degistirir (KULLANICI KARARI sonrasi; docs/IOS_RELEASE.md bolum 1).
# Kullanim: scripts/ios/set-bundle-id.sh tr.com.bukampus.app
# Degisen yerler: Runner.xcodeproj/project.pbxproj (Runner + RunnerTests), codemagic.yaml (BUNDLE_ID),
# mobile/ios/fastlane/Appfile. GoogleService-Info.plist YENIDEN indirilmelidir (Firebase'de iOS uygulamasi yeni id ile
# eklenir) ve APNs/App ID yeni id ile olusturulmalidir. Bu betik Firebase/Apple tarafina dokunmaz.
set -euo pipefail

NEW="${1:?kullanim: $0 <yeni.bundle.id>}"
case "$NEW" in
  *[!A-Za-z0-9.-]*|.*|*.|"") echo "gecersiz bundle id: $NEW" >&2; exit 2 ;;
esac

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PBX="$ROOT/mobile/ios/Runner.xcodeproj/project.pbxproj"
OLD="$(grep -o 'PRODUCT_BUNDLE_IDENTIFIER = [A-Za-z0-9.-]*;' "$PBX" | grep -v RunnerTests | head -1 | sed 's/.*= \(.*\);/\1/')"
echo "Eski: $OLD  Yeni: $NEW"
[ "$OLD" != "$NEW" ] || { echo "zaten ayni"; exit 0; }

sed -i.bak "s/PRODUCT_BUNDLE_IDENTIFIER = $OLD;/PRODUCT_BUNDLE_IDENTIFIER = $NEW;/g; s/PRODUCT_BUNDLE_IDENTIFIER = $OLD\.RunnerTests;/PRODUCT_BUNDLE_IDENTIFIER = $NEW.RunnerTests;/g" "$PBX"
rm -f "$PBX.bak"
for f in "$ROOT/codemagic.yaml" "$ROOT/mobile/ios/fastlane/Appfile"; do
  if [ -f "$f" ]; then
    sed -i.bak "s/$OLD/$NEW/g" "$f"
    rm -f "$f.bak"
  fi
done
grep -c "PRODUCT_BUNDLE_IDENTIFIER = $NEW" "$PBX" | sed 's/^/pbxproj degisen satir: /'
echo "Tamam. Sonraki adimlar: Firebase iOS uygulamasi + GoogleService-Info.plist, Apple App ID (Push), docs/IOS_RELEASE.md bolum 1."

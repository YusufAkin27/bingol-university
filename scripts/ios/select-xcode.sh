#!/usr/bin/env bash
# macOS CI: Xcode 26+ (App Store yukleme sarti) aktif degilse en yuksek /Applications/Xcode*.app'i secer.
# Bulamazsa uyarir (build-ipa.sh zaten Xcode < 26'da durur). DOGRULANAMADI: Windows'ta calistirilamaz.
set -uo pipefail
major() { xcodebuild -version 2>/dev/null | head -1 | sed 's/Xcode \([0-9]*\).*/\1/'; }
cur="$(major)"
echo "Etkin Xcode: $(xcodebuild -version 2>/dev/null | head -1) (major=${cur:-?})"
if [ "${cur:-0}" -ge 26 ] 2>/dev/null; then exit 0; fi
best=""
for app in /Applications/Xcode*.app; do
  [ -d "$app" ] || continue
  v="$("$app/Contents/Developer/usr/bin/xcodebuild" -version 2>/dev/null | head -1 | sed 's/Xcode \([0-9]*\).*/\1/')"
  if [ "${v:-0}" -ge 26 ] 2>/dev/null; then best="$app"; fi
done
if [ -n "$best" ]; then
  sudo xcode-select -s "$best/Contents/Developer" && echo "Xcode secildi: $best"
else
  echo "UYARI: Xcode 26+ bulunamadi; build-ipa.sh durabilir (macos-latest gorselini kontrol edin)" >&2
fi

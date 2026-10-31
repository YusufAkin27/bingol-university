#!/usr/bin/env bash
# TestFlight yapi numarasi cakismasini onler: App Store Connect'teki son numara + 1 (en az pubspec "+N") hesaplar.
# Cikti: stdout'a SAYI, $GITHUB_ENV varsa IOS_BUILD_NUMBER=<sayi> ekler (sonraki adimlar build-ipa.sh'e aktarir).
# Gerekenler: IOS_API_KEY_ID, IOS_API_ISSUER_ID, IOS_API_KEY_P8_BASE64 (fastlane lane "next_build", mobile/ios/fastlane/Fastfile).
# Hata/uygulama henuz Connect'te yok/fastlane yok: pubspec numarasi + CI kosu numarasi (monoton artan) kullanilir.
# DOGRULANAMADI: Windows'ta calistirilamaz (fastlane/macOS). Sir yazdirmaz.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION_LINE="$(grep -E '^version:' "$ROOT/mobile/pubspec.yaml" | head -1 | sed 's/version:[[:space:]]*//')"
NAME="${VERSION_LINE%%+*}"
BASE="${VERSION_LINE##*+}"
RUN="${GITHUB_RUN_NUMBER:-${PROJECT_BUILD_NUMBER:-0}}"
FALLBACK=$((BASE + RUN))
OUT="$ROOT/mobile/build/ios-release/next_build_number.txt"
rm -f "$OUT"

N=""
if [ -n "${IOS_API_KEY_ID:-}" ] && [ -n "${IOS_API_ISSUER_ID:-}" ] && [ -n "${IOS_API_KEY_P8_BASE64:-}" ]; then
  FL="$(command -v fastlane || true)"
  if [ -n "$FL" ]; then
    ( cd "$ROOT/mobile/ios" && "$FL" next_build base:"$BASE" version:"$NAME" >&2 ) || true
    [ -f "$OUT" ] && N="$(tr -dc '0-9' < "$OUT")"
  else
    echo "UYARI: fastlane yok, yedek numara kullanilacak" >&2
  fi
fi
if [ -z "$N" ]; then
  N="$FALLBACK"
  echo "UYARI: TestFlight sorgulanamadi; yedek numara = pubspec ($BASE) + kosu ($RUN) = $N" >&2
fi
echo "Yapi numarasi: $N (surum $NAME)" >&2
[ -z "${GITHUB_ENV:-}" ] || echo "IOS_BUILD_NUMBER=$N" >> "$GITHUB_ENV"
echo "$N"

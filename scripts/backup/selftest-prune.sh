#!/usr/bin/env bash
# Saklama (prune) mantiginin KENDI KENDINE testi: gecici dizinde sahte tarihli yedeklerle; docker/DB/gercek yedek dizini GEREKMEZ.
# Kullanim: bash scripts/backup/selftest-prune.sh      (sunucuda: BACKUP_DIR'e dokunmaz, mktemp kullanir)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export BACKUP_DIR="$T/root"; mkdir -p "$BACKUP_DIR"
# shellcheck source=lib.sh
. "$HERE/lib.sh" 2>/dev/null
fail=0
ok()  { printf 'OK    %s\n' "$*"; }
bad() { printf 'FAIL  %s\n' "$*"; fail=1; }
mk() { # mk <dizin> <ad> [gecersiz]
  mkdir -p "$1/$2"; if [ "${3:-}" != bad ]; then echo x > "$1/$2/db.dump.age"; echo x > "$1/$2/SHA256SUMS"; fi
}
names() { ls -1 "$1" | tr '\n' ' '; }

D="$T/d1"; mkdir -p "$D"; for h in 08 09 10 11 12 13; do mk "$D" "20261029T${h}0500"; done
prune "$D" 3 2>/dev/null
[ "$(names "$D")" = "20261029T110500 20261029T120500 20261029T130500 " ] && ok "6 yedek, tut=3 -> en yeni 3 kaldi" || bad "tut=3: $(names "$D")"

D="$T/d2"; mkdir -p "$D"; mk "$D" 20261029T120500; mk "$D" 20261029T130500
prune "$D" 3 2>/dev/null
[ "$(ls "$D" | wc -l)" = 2 ] && ok "2 yedek, tut=3 -> hicbiri silinmedi" || bad "az yedek silindi"

D="$T/d3"; mkdir -p "$D"; for h in 09 10 11 12; do mk "$D" "20261029T${h}0500"; done; mk "$D" 20261029T130500 bad
prune "$D" 3 2>/dev/null
[ "$(names "$D")" = "20261029T100500 20261029T110500 20261029T120500 20261029T130500 " ] && ok "en yeni yedek bozuk -> 3 GECERLI korundu (09:05 silindi)" || bad "bozuk yedek: $(names "$D")"

D="$T/d4"; mkdir -p "$D"; mk "$D" 20261029T120500 bad; mk "$D" 20261029T130500 bad; mk "$D" 20261029T110500
prune "$D" 3 2>/dev/null
[ "$(ls "$D" | wc -l)" = 3 ] && ok "gecerli < tut -> silme yok" || bad "gecerli az iken silindi"

D="$T/d5"; mkdir -p "$D"; mk "$D" 20261029T120500; mkdir -p "$D/baska-dizin" "$D/.partial-20261029T130000"
prune "$D" 1 2>/dev/null
[ -d "$D/baska-dizin" ] && [ -d "$D/.partial-20261029T130000" ] && ok "yedek adli olmayan dizinlere dokunulmadi" || bad "yabanci dizin silindi"

D="$T/d6"; mkdir -p "$D"
out="$(prune "$D" 0 2>&1)"; [ -z "$out" ] && ok "kapali saklama + bos dizin -> sessiz (yanlis alarm yok)" || bad "gurultu: $out"
mk "$D" 20261029T120500; out="$(prune "$D" 0 2>&1)"
{ [ -d "$D/20261029T120500" ] && printf '%s' "$out" | grep -q uyari; } && ok "kapali saklama + yedek var -> uyarir, silmez" || bad "tut=0 davranisi: $out"
out="$(prune "$D" abc 2>&1)"; [ -d "$D/20261029T120500" ] && ok "gecersiz sayi -> silmez" || bad "gecersiz sayi sildi"
exit "$fail"

#!/usr/bin/env bash
# Ortak kaynaklar icin basit kilit (mkdir atomiktir). Paralel ajanlar ARB/gen-l10n ve ag test kosularini siraya sokar.
# Kullanim: scripts/dev/with-lock.sh <ad> <komut> [arg ...]
#   ornek: scripts/dev/with-lock.sh l10n bash -c 'cd /c/bu_mobile && flutter gen-l10n'
# Kilit /tmp/bu-lock-<ad>.d; 20 dk'dan eski kilit bayat sayilip kirilir; en cok 30 dk bekler.
set -uo pipefail
if [ "$#" -lt 2 ]; then
  echo "kullanim: $0 <ad> <komut> [arg ...]" >&2
  exit 2
fi
NAME="$1"
shift
LOCK="/tmp/bu-lock-${NAME}.d"
tries=0
until mkdir "$LOCK" 2>/dev/null; do
  if [ -d "$LOCK" ] && [ -n "$(find "$LOCK" -maxdepth 0 -mmin +20 2>/dev/null)" ]; then
    rmdir "$LOCK" 2>/dev/null || true
    continue
  fi
  tries=$((tries + 1))
  if [ "$tries" -gt 360 ]; then
    echo "kilit alinamadi (30 dk): $NAME" >&2
    exit 3
  fi
  sleep 5
done
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT
"$@"

#!/usr/bin/env bash
# Sunucudaki YEREL yedekleri guvenle azaltir: bir yerel yedek ancak uzakta DOGRULANMIS (rclone check + boyut + SHA256SUMS) bir kopyasi
# varsa silinir; her katmanda (daily/weekly/monthly) en yeni N yedek her durumda yerelde kalir.
# Kullanim: prune-local-after-remote.sh [--apply] [--keep N]
#   (varsayilan KURU CALISMA: yalniz ne yapilacagini listeler; silmek icin --apply)
#   N: --keep, yoksa BACKUP_LOCAL_KEEP_WHEN_REMOTE_OK, yoksa 2 (en az 1)
# Yalnizca $BACKUP_DIR/{daily,weekly,monthly}/<YYYYmmddTHHMMSS> dizinlerine dokunur; sembolik baglari ve disariya cikan yollari atlar.
# Uzakta kopyasi OLMAYAN (ornegin saatlik, gunluk yuklemeye girmeyen) yedekler silinmez: yerel saklama icin BACKUP_KEEP_* kullanilir.
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"
drop_root "$HERE/prune-local-after-remote.sh" "$@"
# shellcheck source=remote.sh
. "$HERE/remote.sh"

APPLY=0; KEEP="${BACKUP_LOCAL_KEEP_WHEN_REMOTE_OK:-2}"
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1;;
    --keep) KEEP="${2:-}"; shift;;
    *) die "bilinmeyen arguman: $1";;
  esac
  shift
done
[ "$KEEP" -ge 1 ] 2>/dev/null || KEEP=2   # 0/gecersiz: guvenli taraf, en az 1 (varsayilan 2)

[ -n "${BACKUP_REMOTE:-}" ] || { log "BACKUP_REMOTE bos: uzak kopya olmadan yerel yedek silinmez"; exit 2; }
command -v rclone >/dev/null && command -v jq >/dev/null || die "rclone/jq yok"

if [ "$APPLY" = 1 ]; then
  # hourly backup.sh ile ayni anda silme/yazma olmasin
  exec 8>"${BACKUP_LOCK:-/tmp/backup.lock}"
  flock -n 8 || { log "yedek calisiyor (backup.lock); sonra tekrar deneyin"; exit 0; }
fi

BASE_REAL="$(cd "$BACKUP_DIR" && pwd -P)"
REMOTE_LIST="$(remote_stamps)" || die "uzak dizin listelenemedi: $(classify_error)"
MODE="KURU CALISMA (silmek icin --apply)"; [ "$APPLY" = 0 ] || MODE="UYGULANIYOR"
log "$MODE; her katmanda en yeni $KEEP yedek yerelde kalir; uzak kopya dogrulanmadan hicbir sey silinmez"

DEL=0; KEPT=0; SKIP=0; FREED=0
for tier in daily weekly monthly; do
  tdir="$BACKUP_DIR/$tier"; [ -d "$tdir" ] || continue
  i=0
  for stamp in $(ls -1 "$tdir" | grep -E "$STAMP_RE" | sort -r); do
    i=$((i + 1))
    path="$tdir/$stamp"
    if [ "$i" -le "$KEEP" ]; then log "tutuldu (en yeni $KEEP): $tier/$stamp"; KEPT=$((KEPT + 1)); continue; fi
    if [ -L "$path" ] || [ ! -d "$path" ]; then log "atlandi (dizin degil/sembolik bag): $tier/$stamp"; SKIP=$((SKIP + 1)); continue; fi
    real="$(cd "$path" && pwd -P)" || { SKIP=$((SKIP + 1)); continue; }
    case "$real" in "$BASE_REAL/$tier/"*) ;; *) log "atlandi (yedek dizini disina cikiyor): $tier/$stamp"; SKIP=$((SKIP + 1)); continue;; esac
    if ! printf '%s\n' "$REMOTE_LIST" | grep -qx "$stamp"; then
      log "KORUNDU (uzakta kopyasi yok): $tier/$stamp"; SKIP=$((SKIP + 1)); continue
    fi
    if ! verify_remote_copy "$path" "$REMOTE_BASE/$stamp"; then
      log "KORUNDU (uzak kopya DOGRULANAMADI: $VERIFY_MSG): $tier/$stamp"; SKIP=$((SKIP + 1)); continue
    fi
    sz="$(du -sk "$path" | awk '{print $1*1024}')"
    if [ "$APPLY" = 1 ]; then
      rm -rf -- "${path:?}" && { log "SILINDI (uzakta dogrulandi): $tier/$stamp ($(human "$sz"))"; DEL=$((DEL + 1)); FREED=$((FREED + sz)); } \
        || log "uyari: $tier/$stamp silinemedi"
    else
      log "SILINIRDI (uzakta dogrulandi): $tier/$stamp ($(human "$sz"))"; DEL=$((DEL + 1)); FREED=$((FREED + sz))
    fi
  done
done
log "ozet: silinen/silinecek $DEL, tutulan $KEPT, korunan/atlanan $SKIP, bosalan ~$(human "$FREED")"
if [ "$APPLY" = 1 ]; then status_enrich || true; metric_remote_write || true; fi
rm -f "$RC_ERR" 2>/dev/null || true

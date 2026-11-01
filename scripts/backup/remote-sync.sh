#!/usr/bin/env bash
# En yeni GECERLI yerel yedegi uzak hedefe (Google Drive/S3/SFTP; rclone) yukler, indirmeden DOGRULAR, ancak ondan sonra
# uzak saklamayi (GFS: gunluk/haftalik/aylik) uygular. Uzak dizin yalniz dogrulama gectikten sonra yayinlanir
# (`.partial-<damga>` -> `<damga>` yeniden adlandirma): uzakta damga adli bir dizin varsa eksiksizdir.
# Kullanim: remote-sync.sh [--dry-run] [--force] [--if-stale] [--stamp <damga>] [--no-retention]
#   --dry-run  : hicbir sey yuklemez/silmez; plani, uzak bos alani ve silinecekleri yazar
#   --if-stale : son basarili yukleme BACKUP_REMOTE_STALE_HOURS (20) saatten yeniyse hicbir sey yapmaz (yeniden deneme zamanlayicisi)
#   --force    : bugun zaten yuklenmis olsa da yeniden yukler/dogrular
# Cikis: 0 basarili/yapilacak is yok, 1 hata. Hata durum dosyasina KISA ve sirsiz yazilir (remote.lastError).
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"
drop_root "$HERE/remote-sync.sh" "$@"
# shellcheck source=remote.sh
. "$HERE/remote.sh"

DRY=0; FORCE=0; STALE=0; STAMP_ARG=""; RETENTION=1
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1;; --force) FORCE=1;; --if-stale) STALE=1;; --no-retention) RETENTION=0;;
    --stamp) STAMP_ARG="${2:-}"; shift;;
    *) die "bilinmeyen arguman: $1";;
  esac
  shift
done

[ -n "${BACKUP_REMOTE:-}" ] || { log "uzak kopya kapali (BACKUP_REMOTE bos); yapilacak is yok"; exit 0; }
case "$BACKUP_REMOTE" in *:*) ;; *) die "BACKUP_REMOTE 'uzakadi:yol' bicimde olmali (rclone)";; esac
command -v rclone >/dev/null || die "rclone yok"
command -v jq >/dev/null || die "jq yok"

# tek uzak esitleme: yukleme saatler surebilir, saatlik yerel yedegi (backup.lock) ENGELLEMESIN diye ayri kilit
exec 9>"${BACKUP_REMOTE_LOCK:-/tmp/backup-remote.lock}"
flock -n 9 || { log "baska bir uzak esitleme calisiyor; atlandi"; exit 0; }

START=$(date +%s)
ERRMSG=""; STAGE=""; STAMP=""
fail() { ERRMSG="$*"; log "HATA: $*"; exit 1; }

on_exit() {
  local code=$?
  [ -z "$STAGE" ] || rm -rf "$STAGE" 2>/dev/null || true
  [ "$code" -ne 0 ] || { rm -f "$RC_ERR" 2>/dev/null || true; return 0; }
  [ "$DRY" = 0 ] || return 0
  [ -n "$ERRMSG" ] || ERRMSG="$(classify_error)"
  ERRMSG="$(printf '%s' "$ERRMSG" | tr -d '\n\r' | cut -c1-200)"
  log "UZAK KOPYA BASARISIZ: $ERRMSG"
  state_merge "$(jq -nc --arg e "$ERRMSG" --arg t "$(now_iso)" '{lastError:$e, lastAttemptAt:$t}')" || true
  metric_remote_write || true
  status_enrich || true
  notify "UZAK YEDEK BASARISIZ ($(hostname), $(remote_name)): $ERRMSG"
  rm -f "$RC_ERR" 2>/dev/null || true
}
trap on_exit EXIT

# --- yakinlik: son basari yeterince yeniyse (yeniden deneme zamanlayicisi) hicbir sey yapma ---
if [ "$STALE" = 1 ] && [ "$FORCE" = 0 ] && [ -s "$REMOTE_STATE_FILE" ]; then
  LS="$(jq -r '.lastSuccessAt // empty' "$REMOTE_STATE_FILE" 2>/dev/null || true)"
  LE="$(jq -r '.lastError // empty' "$REMOTE_STATE_FILE" 2>/dev/null || true)"
  if [ -n "$LS" ] && [ -z "$LE" ]; then
    LSS="$(iso_to_epoch "$LS")"
    if [ $(( $(date +%s) - LSS )) -lt $(( ${BACKUP_REMOTE_STALE_HOURS:-20} * 3600 )) ]; then
      log "son uzak yukleme yeni ($LS); yeniden deneme gerekmiyor"; exit 0
    fi
  fi
fi

# --- on kontroller ---
rc lsd "${BACKUP_REMOTE%%:*}:" >/dev/null || rc about "${BACKUP_REMOTE%%:*}:" >/dev/null || fail "$(classify_error)"
: > "$RC_ERR"   # basarili on kontrolun gecici (yeniden denenen) hata satirlari sonraki hata siniflandirmasini yaniltmasin
[ "$DRY" = 1 ] || rc mkdir "$REMOTE_BASE" || fail "$(classify_error)"
[ "$DRY" = 1 ] || state_merge "$(jq -nc --arg t "$(now_iso)" '{lastAttemptAt:$t}')"

if [ -n "$STAMP_ARG" ]; then
  printf '%s' "$STAMP_ARG" | grep -qE "$STAMP_RE" || die "gecersiz damga: $STAMP_ARG"
  [ -s "$BACKUP_DIR/daily/$STAMP_ARG/SHA256SUMS" ] || die "yerel yedek yok: $STAMP_ARG"
  (cd "$BACKUP_DIR/daily/$STAMP_ARG" && sha256sum -c SHA256SUMS >/dev/null 2>&1) || fail "yerel yedek sha256 dogrulamasini gecemedi"
  STAMP="$STAMP_ARG"
else
  STAMP="$(newest_valid_local)" || fail "yuklenecek gecerli yerel yedek yok"
fi
SRC="$BACKUP_DIR/daily/$STAMP"
SRC_JSON="$(dir_size_json "$SRC")" || fail "yerel boyut okunamadi"
SRC_BYTES="$(printf '%s' "$SRC_JSON" | jq -r .bytes)"
log "yuklenecek yedek: $STAMP ($(human "$SRC_BYTES"))"

REMOTE_LIST="$(remote_stamps)" || fail "uzak dizin listelenemedi: $(classify_error)"

# Uzak bos alan (Drive/S3 bildirirse): bilinmiyorsa atlanir. Yetersizse YUKLEME BASLAMAZ, hicbir sey silinmez.
FREE="$(rc about --json "${BACKUP_REMOTE%%:*}:" 2>/dev/null | jq -r '.free // empty' 2>/dev/null || true)"
if [ -n "${FREE:-}" ] && [ "$FREE" -lt "$SRC_BYTES" ] 2>/dev/null; then
  fail "Drive/uzak depoda bos alan yetersiz ($(human "$FREE") < $(human "$SRC_BYTES")); uzak saklamayi azaltin veya kotayi artirin"
fi
[ -z "${FREE:-}" ] || log "uzak bos alan: $(human "$FREE")"

# --- plan: yuklemeden sonraki saklama ---
PLAN_ALL="$(printf '%s\n%s\n' "$REMOTE_LIST" "$STAMP" | grep -E "$STAMP_RE" | sort -u)"
TO_DELETE="$(printf '%s\n' "$PLAN_ALL" | gfs_delete_list "$RK_DAILY" "$RK_WEEKLY" "$RK_MONTHLY")"
MAXDEL="${BACKUP_REMOTE_MAX_DELETE:-20}"
if [ "$DRY" = 1 ]; then
  log "KURU CALISMA: $STAMP uzakta ${BACKUP_REMOTE%%:*}:... altina yuklenir (once .partial-$STAMP, dogrulanir, sonra yeniden adlandirilir)"
  log "KURU CALISMA: uzakta simdi $(printf '%s\n' "$REMOTE_LIST" | grep -c . || true) yedek; saklama gunluk $RK_DAILY / haftalik $RK_WEEKLY / aylik $RK_MONTHLY"
  if [ -n "$TO_DELETE" ]; then printf '%s\n' "$TO_DELETE" | head -n "$MAXDEL" | while read -r d; do log "KURU CALISMA: yuklemeden sonra SILINIR: $d"; done
  else log "KURU CALISMA: silinecek uzak yedek yok"; fi
  log "KURU CALISMA tamam: hicbir sey yuklenmedi/silinmedi"
  exit 0
fi

# --- onceki kesintiye ugramis yuklemelerin / hazirliklarin temizligi (yalniz BU damgadan farkli olanlar; ayni damga devam eder) ---
for p in $(rc lsf --dirs-only "$REMOTE_BASE" | sed 's#/$##' | grep -E '^\.partial-[0-9]{8}T[0-9]{6}$' || true); do
  [ "$p" = ".partial-$STAMP" ] && continue
  log "eski kismi yukleme siliniyor: $p"
  rc purge "$REMOTE_BASE/$p" --drive-use-trash=false || log "uyari: $p silinemedi"
done
for s in "$BACKUP_DIR"/.remote-stage-*; do [ -d "$s" ] && rm -rf "$s"; done

ALREADY=0
printf '%s\n' "$REMOTE_LIST" | grep -qx "$STAMP" && ALREADY=1
if [ "$ALREADY" = 1 ] && [ "$FORCE" = 0 ]; then
  log "$STAMP uzakta zaten var; yalniz dogrulaniyor"
  if verify_remote_copy "$SRC" "$REMOTE_BASE/$STAMP"; then :; else
    log "uzak kopya dogrulanamadi ($VERIFY_MSG); yeniden yuklenecek"
    rc purge "$REMOTE_BASE/$STAMP" --drive-use-trash=false || fail "bozuk uzak kopya silinemedi"
    ALREADY=0
  fi
fi

if [ "$ALREADY" = 0 ] || [ "$FORCE" = 1 ]; then
  # prune, yukleme sirasinda kaynagi silmesin: sabit bagli (hardlink) kopya, ek disk kullanmaz
  STAGE="$BACKUP_DIR/.remote-stage-$STAMP"
  rm -rf "$STAGE"; cp -al "$SRC" "$STAGE"
  if [ "$ALREADY" = 1 ]; then rc purge "$REMOTE_BASE/$STAMP" --drive-use-trash=false || fail "$(classify_error)"; fi
  TMPD="$REMOTE_BASE/.partial-$STAMP"
  log "rclone yukleme basliyor -> .partial-$STAMP (tek aktarim, parca ${BACKUP_RCLONE_DRIVE_CHUNK:-64M})"
  : > "$RC_ERR"
  timeout "${BACKUP_REMOTE_MAX_SECONDS:-14400}" rclone "${RC_OPTS[@]}" copy "$STAGE" "$TMPD" --checksum --transfers 1 --checkers 2 \
    2>>"$RC_ERR" || { UC=$?
      case "$UC" in 124|137|143) fail "yukleme sure sinirini asti (BACKUP_REMOTE_MAX_SECONDS=${BACKUP_REMOTE_MAX_SECONDS:-14400} sn); sonraki denemede tamamlanmamis dosyalar bastan yuklenir";; esac
      fail "yukleme basarisiz: $(classify_error)"; }
  log "yukleme bitti; indirmeden dogrulaniyor"
  verify_remote_copy "$STAGE" "$TMPD" || fail "yukleme dogrulamasi basarisiz: $VERIFY_MSG"
  rc moveto "$TMPD" "$REMOTE_BASE/$STAMP" || fail "$(classify_error)"
  verify_remote_copy "$STAGE" "$REMOTE_BASE/$STAMP" || fail "yayin sonrasi dogrulama basarisiz: $VERIFY_MSG"
fi

NOWISO="$(now_iso)"
state_merge "$(jq -nc --arg t "$NOWISO" --arg s "$STAMP" '{lastSuccessAt:$t, lastVerifiedAt:$t, lastError:null, lastStamp:$s}')"
log "UZAK KOPYA TAMAM ve dogrulandi: $STAMP"

# --- uzak saklama: yalniz yukarida dogrulanmis yedek varken ---
if [ "$RETENTION" = 1 ]; then
  LIST_NOW="$(remote_stamps)" || LIST_NOW=""
  if ! printf '%s\n' "$LIST_NOW" | grep -qx "$STAMP"; then
    log "uyari: uzak liste yeni yedegi icermiyor; saklama silmesi ATLANDI"
  else
    DEL="$(printf '%s\n' "$LIST_NOW" | gfs_delete_list "$RK_DAILY" "$RK_WEEKLY" "$RK_MONTHLY")"
    N=0
    for d in $DEL; do
      [ "$d" != "$STAMP" ] || continue
      if [ "$N" -ge "$MAXDEL" ]; then log "uzak silme sinirina ulasildi ($MAXDEL); kalanlar sonraki calismada"; break; fi
      log "uzak saklama: siliniyor $d"
      rc purge "$REMOTE_BASE/$d" --drive-use-trash=false || log "uyari: uzak $d silinemedi (sonraki calismada yeniden denenir)"
      N=$((N + 1))
    done
  fi
fi

# --- uzak toplamlar (durum/metrik) ---
FINAL_LIST="$(remote_stamps || true)"
TOT="$(rc size --json "$REMOTE_BASE" 2>/dev/null | jq -c '{bytes:.bytes}' 2>/dev/null || echo '{"bytes":null}')"
state_merge "$(jq -nc --argjson t "$TOT" --argjson c "$(printf '%s\n' "$FINAL_LIST" | grep -c . || true)" '$t + {count:$c}')"

# --- istege bagli: dogrulanmis uzak kopyasi olan eski yerel yedekleri azalt ---
if [ -n "${BACKUP_LOCAL_KEEP_WHEN_REMOTE_OK:-}" ]; then
  "$HERE/prune-local-after-remote.sh" --apply --keep "$BACKUP_LOCAL_KEEP_WHEN_REMOTE_OK" || log "uyari: yerel azaltma tamamlanamadi"
fi

metric_remote_write || true
status_enrich || true
log "bitti: sure $(( $(date +%s) - START )) sn"

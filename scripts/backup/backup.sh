#!/usr/bin/env bash
# PostgreSQL (pg_dump -Fc) + uploads tar -> age ile sifreli, SHA-256 ozetli yedek.
# Kullanim: backup.sh [--dry-run]
# Env: PGHOST PGUSER PGDATABASE PGPASSWORD, BACKUP_AGE_RECIPIENT (age GENEL anahtari), BACKUP_DIR, UPLOADS_DIR,
#      BACKUP_REMOTE (rclone hedefi, ops.), BACKUP_KEEP_DAILY/WEEKLY/MONTHLY (14/8/12), BACKUP_WEBHOOK_URL
# --dry-run: hicbir yedek yazmaz; baglanti, izin, anahtar, disk ve uzak hedefi dener, plani yazdirir.
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

UPLOADS_DIR="${UPLOADS_DIR:-/data/uploads}"
KEEP_D="${BACKUP_KEEP_DAILY:-14}"; KEEP_W="${BACKUP_KEEP_WEEKLY:-8}"; KEEP_M="${BACKUP_KEEP_MONTHLY:-12}"
RECIPIENT="${BACKUP_AGE_RECIPIENT:-}"
# Ek alici (ops.): sunucuda ozel anahtari duran DOGRULAMA anahtari (haftalik otomatik geri yukleme denemesi icin)
EXTRA_RECIPIENT="${BACKUP_VERIFY_AGE_RECIPIENT:-}"
START=$(date +%s)
STAMP="$(date +%Y%m%dT%H%M%S)"
DEST="$BACKUP_DIR/daily/$STAMP"
PART="$BACKUP_DIR/.partial-$STAMP"

[ -n "$RECIPIENT" ] || die "BACKUP_AGE_RECIPIENT bos (age genel anahtari gerekli)"
case "$RECIPIENT" in AGE-SECRET-KEY-*) die "BACKUP_AGE_RECIPIENT bir OZEL anahtar gibi gorunuyor; yalnizca genel anahtar (age1...) verin";; esac

fail() {
  local rc=$?
  log "BASARISIZ (cikis $rc, satir ${BASH_LINENO[0]})"
  rm -rf "$PART" 2>/dev/null || true
  if [ "$DRY" = 0 ]; then
    metric_write "" "$(date +%s)" 0 "$(( $(date +%s) - START ))" "" "" "" ""
    notify "YEDEK BASARISIZ ($(hostname)) satir ${BASH_LINENO[0]}, cikis $rc"
  fi
  exit "${rc:-1}"
}
trap fail ERR

# --- on kontroller (dry-run'da da calisir) ---
command -v pg_dump >/dev/null || die "pg_dump yok"
command -v age >/dev/null || die "age yok"
pg_isready -q -t 10 || die "PostgreSQL yanit vermiyor ($PGHOST)"
psql -Atqc 'select 1' >/dev/null || die "PostgreSQL kimlik dogrulamasi/sorgu basarisiz"
[ -d "$UPLOADS_DIR" ] || die "uploads dizini yok: $UPLOADS_DIR"
AGE_ARGS=(-r "$RECIPIENT")
[ -z "$EXTRA_RECIPIENT" ] || AGE_ARGS+=(-r "$EXTRA_RECIPIENT")
printf 'age-denemesi' | age "${AGE_ARGS[@]}" >/dev/null || die "age alicisi gecersiz"
if [ -n "${BACKUP_REMOTE:-}" ]; then
  rclone lsd "${BACKUP_REMOTE%%:*}:" >/dev/null 2>&1 || rclone about "${BACKUP_REMOTE%%:*}:" >/dev/null 2>&1 \
    || die "rclone hedefi erisilemez: ${BACKUP_REMOTE%%:*}"
fi

if [ "$DRY" = 1 ]; then
  DBSZ="$(psql -Atqc "select pg_database_size(current_database())")"
  UPN="$(find "$UPLOADS_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')"
  UPSZ="$(du -sk "$UPLOADS_DIR" 2>/dev/null | awk '{print $1*1024}')"
  FREE="$(df -Pk "$BACKUP_DIR" | awk 'NR==2{print $4*1024}')"
  log "KURU CALISMA: DB boyutu $(human "$DBSZ"), uploads $UPN dosya / $(human "$UPSZ"), hedefte bos alan $(human "$FREE")"
  log "KURU CALISMA: yazilacak: $DEST/{db.dump.age,uploads.tar.zst.age,manifest.json,SHA256SUMS}; saklama $KEEP_D gunluk/$KEEP_W haftalik/$KEEP_M aylik; uzak: ${BACKUP_REMOTE:-yok}"
  log "KURU CALISMA tamam: hicbir dosya yazilmadi, metrik degismedi"
  exit 0
fi

mkdir -p "$PART" "$BACKUP_DIR/daily" "$BACKUP_DIR/weekly" "$BACKUP_DIR/monthly"
chmod 700 "$PART"
log "yedek basliyor: $STAMP"

# --- manifest icin satir sayilari (dogrulama karsilastirmasi) ---
COUNTS="$(psql -Atq -F '|' -c "
  select quote_ident(table_name) from information_schema.tables
  where table_schema='public' and table_type='BASE TABLE' order by 1" | while read -r t; do
    n="$(psql -Atqc "select count(*) from public.$t")"; printf '%s=%s\n' "$t" "$n"; done)"
FLYWAY="$(psql -Atqc "select coalesce(max(version::int),0) from flyway_schema_history where success and version ~ '^[0-9]+\$'" 2>/dev/null || echo 0)"
UPFILES="$(find "$UPLOADS_DIR" -type f | wc -l | tr -d ' ')"

# --- veritabani: dogrudan sifreli akis (diske acik metin yazilmaz) ---
log "pg_dump -Fc -> age"
pg_dump -Fc -Z 6 --no-owner --no-privileges | age "${AGE_ARGS[@]}" > "$PART/db.dump.age"

# --- yuklenen dosyalar ---
log "uploads tar+zstd -> age"
# --warning=no-file-changed: yazma sirasinda degisen dosya hatasi olmasin (yeni dosyalar bir sonraki yedege girer)
tar -C "$UPLOADS_DIR" --warning=no-file-changed -cf - . | zstd -T2 -q | age "${AGE_ARGS[@]}" > "$PART/uploads.tar.zst.age"

DBB="$(stat -c %s "$PART/db.dump.age")"; UPB="$(stat -c %s "$PART/uploads.tar.zst.age")"
[ "$DBB" -gt 200 ] || die "db yedegi supheli derecede kucuk ($DBB bayt)"

{
  printf '{\n  "stamp": "%s",\n  "created_at": "%s",\n  "host": "%s",\n  "flyway_version": %s,\n  "upload_files": %s,\n  "db_bytes": %s,\n  "uploads_bytes": %s,\n  "tables": {' \
    "$STAMP" "$(date -u +%FT%TZ)" "$(hostname)" "${FLYWAY:-0}" "${UPFILES:-0}" "$DBB" "$UPB"
  first=1
  while IFS== read -r t n; do
    [ -n "$t" ] || continue
    [ "$first" = 1 ] || printf ','
    printf '\n    "%s": %s' "$t" "$n"; first=0
  done <<< "$COUNTS"
  printf '\n  }\n}\n'
} > "$PART/manifest.json"
(cd "$PART" && sha256sum db.dump.age uploads.tar.zst.age manifest.json > SHA256SUMS)

# butunluk: sifreli dosyalar sha256 ile dogrulanir; sifre cozme dogrulamasi verify-restore.sh'in isidir
(cd "$PART" && sha256sum -c SHA256SUMS >/dev/null) || die "sha256 dogrulamasi basarisiz"

mv "$PART" "$DEST"

# --- kademeli saklama: pazar -> haftalik, ayin 1'i -> aylik (hardlink, ek yer yemez) ---
if [ "$(date +%u)" = 7 ]; then mkdir -p "$BACKUP_DIR/weekly"; cp -al "$DEST" "$BACKUP_DIR/weekly/$STAMP"; fi
if [ "$(date +%d)" = 01 ]; then mkdir -p "$BACKUP_DIR/monthly"; cp -al "$DEST" "$BACKUP_DIR/monthly/$STAMP"; fi
prune() { # prune <dizin> <tut>
  local n=0
  for d in $(ls -1 "$1" 2>/dev/null | sort -r); do
    n=$((n+1)); [ "$n" -le "$2" ] || { log "siliniyor: $1/$d"; rm -rf "${1:?}/$d"; }
  done
}
prune "$BACKUP_DIR/daily" "$KEEP_D"; prune "$BACKUP_DIR/weekly" "$KEEP_W"; prune "$BACKUP_DIR/monthly" "$KEEP_M"

# --- uzak kopya (istege bagli) ---
if [ -n "${BACKUP_REMOTE:-}" ]; then
  log "rclone -> $BACKUP_REMOTE"
  rclone copy "$DEST" "${BACKUP_REMOTE%/}/$STAMP" --checksum --transfers 2 || die "rclone yuklemesi basarisiz"
fi

NOW=$(date +%s)
echo "$NOW" > "$BACKUP_DIR/last_success"
metric_write "$NOW" "$NOW" 1 "$((NOW-START))" "$DBB" "$UPB" "" ""
log "TAMAM: $STAMP db=$(human "$DBB") uploads=$(human "$UPB") sure=$((NOW-START))sn"

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
# Elle/guncelleme betigi root olarak cagirsa bile tek kullanici (postgres) ile calis: root sahipli dizin prune'u cokertirdi (H2)
drop_root "$HERE/backup.sh" "$@"

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

UPLOADS_DIR="${UPLOADS_DIR:-/data/uploads}"
# Varsayilan: saatlik yedek, EN YENI 3 tutulur; haftalik/aylik kapali (0). daily = "saatlik" yedeklerin dizini.
KEEP_D="${BACKUP_KEEP_DAILY:-3}"; KEEP_W="${BACKUP_KEEP_WEEKLY:-0}"; KEEP_M="${BACKUP_KEEP_MONTHLY:-0}"
DB_OK=false; FILES_OK=false
RECIPIENT="${BACKUP_AGE_RECIPIENT:-}"
# Ek alici (ops.): sunucuda ozel anahtari duran DOGRULAMA anahtari (haftalik otomatik geri yukleme denemesi icin)
EXTRA_RECIPIENT="${BACKUP_VERIFY_AGE_RECIPIENT:-}"
START=$(date +%s)
STAMP="$(date +%Y%m%dT%H%M%S)"
DEST="$BACKUP_DIR/daily/$STAMP"
PART="$BACKUP_DIR/.partial-$STAMP"

[ -n "$RECIPIENT" ] || die "BACKUP_AGE_RECIPIENT bos (age genel anahtari gerekli)"
case "$RECIPIENT" in AGE-SECRET-KEY-*) die "BACKUP_AGE_RECIPIENT bir OZEL anahtar gibi gorunuyor; yalnizca genel anahtar (age1...) verin";; esac

DIE_MSG=""
die() { DIE_MSG="$*"; log "HATA: $*"; exit 1; }

# EXIT tuzagi: die/set -e/sinyal fark etmez, sifir disi cikista durum JSON + metrik + bildirim yazilir.
on_exit() {
  local rc=$?
  [ "$rc" -ne 0 ] || return 0
  log "BASARISIZ (cikis $rc${DIE_MSG:+: $DIE_MSG})"
  rm -rf "$PART" 2>/dev/null || true
  if [ "$DRY" = 0 ]; then
    metric_write "" "$(date +%s)" 0 "$(( $(date +%s) - START ))" "" "" "" "" || true
    # Rotasyon burada ASLA calismaz: basarisiz yedek mevcut iyi yedekleri silmez
    status_failure "${DIE_MSG:-beklenmeyen hata (cikis $rc)}" "$(( $(date +%s) - START ))" "$DB_OK" "$FILES_OK" || true
    notify "YEDEK BASARISIZ ($(hostname)): ${DIE_MSG:-cikis $rc}"
  fi
}
trap on_exit EXIT

# --- on kontroller (dry-run'da da calisir) ---
command -v pg_dump >/dev/null || die "pg_dump yok"
command -v age >/dev/null || die "age yok"
pg_isready -q -t 10 || die "PostgreSQL yanit vermiyor ($PGHOST)"
psql -Atqc 'select 1' >/dev/null || die "PostgreSQL kimlik dogrulamasi/sorgu basarisiz"
[ -d "$UPLOADS_DIR" ] || die "uploads dizini yok: $UPLOADS_DIR"
AGE_ARGS=(-r "$RECIPIENT")
[ -z "$EXTRA_RECIPIENT" ] || [ "$EXTRA_RECIPIENT" = "$RECIPIENT" ] || AGE_ARGS+=(-r "$EXTRA_RECIPIENT")
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

# --- disk: yeni yedek yazilirken eskiler (KEEP_D) hala durur; basari sonrasi rotasyon yapilir ---
NEED="$(( $(psql -Atqc "select pg_database_size(current_database())") + $(du -sk "$UPLOADS_DIR" | awk '{print $1*1024}') ))"
FREE_B="$(df -Pk "$BACKUP_DIR" | awk 'NR==2{print $4*1024}')"
if [ "$FREE_B" -lt "$NEED" ]; then
  die "disk yetersiz: bos $(human "$FREE_B") < gereken (en kotu durum) $(human "$NEED"); yedek alinmadi, mevcut yedekler korundu"
elif [ "$FREE_B" -lt "$((NEED * 2))" ]; then
  log "UYARI: bos alan $(human "$FREE_B"), veri boyutunun 2 kati altinda; diski buyutun"
  notify "UYARI disk azaliyor ($(hostname)): bos $(human "$FREE_B")"
fi

mkdir -p "$PART" "$BACKUP_DIR/daily" "$BACKUP_DIR/weekly" "$BACKUP_DIR/monthly"
chmod 750 "$PART"   # tek kullanici (postgres); node-exporter/backend bu dizine girmez
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
DB_OK=true

# --- yuklenen dosyalar ---
log "uploads tar+zstd -> age"
# --warning=no-file-changed: yazma sirasinda degisen dosya hatasi olmasin (yeni dosyalar bir sonraki yedege girer)
tar -C "$UPLOADS_DIR" --warning=no-file-changed -cf - . | zstd -T2 -q | age "${AGE_ARGS[@]}" > "$PART/uploads.tar.zst.age"
FILES_OK=true

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

# --- uzak kopya (istege bagli): rotasyondan ONCE; hata burada beklenir ama rotasyonu engellemez (disk dolmasin) ---
REMOTE_ERR=""
if [ -n "${BACKUP_REMOTE:-}" ]; then
  log "rclone -> $BACKUP_REMOTE"
  rclone copy "$DEST" "${BACKUP_REMOTE%/}/$STAMP" --checksum --transfers 2 || REMOTE_ERR="rclone yuklemesi basarisiz"
fi

# --- saklama: YALNIZ basarili yerel yedekten sonra, en yeni KEEP_D tane kalir (varsayilan 3 = 3 saatlik pencere) ---
# Haftalik/aylik kopya (hardlink) yalniz KEEP_W/KEEP_M > 0 ise uretilir. prune hatasi yedegi basarisiz saymaz.
if [ "$KEEP_W" -gt 0 ] && [ "$(date +%u)" = 7 ]; then cp -al "$DEST" "$BACKUP_DIR/weekly/$STAMP"; fi
if [ "$KEEP_M" -gt 0 ] && [ "$(date +%d)" = 01 ]; then cp -al "$DEST" "$BACKUP_DIR/monthly/$STAMP"; fi
prune "$BACKUP_DIR/daily" "$KEEP_D"; prune "$BACKUP_DIR/weekly" "$KEEP_W"; prune "$BACKUP_DIR/monthly" "$KEEP_M"
[ -z "$REMOTE_ERR" ] || die "$REMOTE_ERR"

NOW=$(date +%s)
echo "$NOW" > "$BACKUP_DIR/last_success"
metric_write "$NOW" "$NOW" 1 "$((NOW-START))" "$DBB" "$UPB" "" ""
status_success "$STAMP" "$((DBB+UPB))" "$((NOW-START))" "$DB_OK" "$FILES_OK"
log "TAMAM: $STAMP db=$(human "$DBB") uploads=$(human "$UPB") sure=$((NOW-START))sn"

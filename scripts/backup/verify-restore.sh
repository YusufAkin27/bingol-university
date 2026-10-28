#!/usr/bin/env bash
# "Geri yukleme denenmis yedek" kaniti: yedegi GECICI bir PostgreSQL sunucusuna yukler; canli veritabanina
# ve volume'lara DOKUNMAZ. Flyway surumu, tablo/satir sayilari ve dosya sayisi manifest ile karsilastirilir.
# Kullanim: verify-restore.sh <yedek-dizini> | --latest  [--identity <anahtar>] [--tolerance 5]
# Cikis: 0 basarili, 1 basarisiz, 3 anahtar yok (yalniz sha256 denetlendi).
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib.sh"
drop_root "$HERE/verify-restore.sh" "$@"

SRC="${1:-}"; shift || true
IDENT="${BACKUP_AGE_IDENTITY_FILE:-/run/age-key/age.key}"; TOL=5
while [ $# -gt 0 ]; do
  case "$1" in
    --identity) IDENT="$2"; shift 2;;
    --tolerance) TOL="$2"; shift 2;;
    *) die "bilinmeyen arguman: $1";;
  esac
done
if [ "$SRC" = "--latest" ] || [ -z "$SRC" ]; then
  L="$(ls -1 "$BACKUP_DIR/daily" 2>/dev/null | sort | tail -1)"
  [ -n "$L" ] || die "daily altinda yedek yok"
  SRC="$BACKUP_DIR/daily/$L"
fi
[ -d "$SRC" ] || die "yedek dizini yok: $SRC"

# Anahtar: entrypoint'in postgres icin hazirladigi kopya (BACKUP_AGE_IDENTITY_FILE), yoksa dogrudan kaynak dosya.
# "Var ama OKUNAMIYOR" (host'ta 0600 + baska sahip) eskiden sessizce basarisiz sayiliyordu; simdi acik hata + uyari uretilir (M26).
if [ ! -r "$IDENT" ] && [ -r "${BACKUP_AGE_IDENTITY_SRC:-/run/backup/verify.key}" ]; then
  IDENT="${BACKUP_AGE_IDENTITY_SRC:-/run/backup/verify.key}"
fi
if [ ! -r "$IDENT" ]; then
  KSRC="${BACKUP_AGE_IDENTITY_SRC:-/run/backup/verify.key}"
  if [ -e "$KSRC" ]; then WHY="age kimlik dosyasi var ama OKUNAMIYOR ($KSRC; sahip/izin: host'ta chown 70:70 + chmod 0400, ya da konteyneri yeniden baslatin)"
  elif [ -e "$IDENT" ]; then WHY="age kimlik dosyasi var ama OKUNAMIYOR ($IDENT)"
  else WHY="age kimlik dosyasi yok ($IDENT)"; fi
  log "$WHY: sifre cozulemez, yalniz butunluk (sha256) denetleniyor"
  SHA_OK=1; (cd "$SRC" && sha256sum -c SHA256SUMS) >&2 || SHA_OK=0
  # Dogrulama YAPILANDIRILMISSA (verify alicisi dolu) anahtarin okunamamasi bir hatadir: metrik 0 + bildirim.
  if [ -n "${BACKUP_VERIFY_AGE_RECIPIENT:-}" ] && [ "${VERIFY_NO_METRICS:-0}" != 1 ]; then
    metric_write "" "" "" "" "" "" "" 0
    notify "GERI YUKLEME DOGRULAMASI YAPILAMADI ($(basename "$SRC")): $WHY"
  fi
  [ "$SHA_OK" = 1 ] || exit 1
  exit 3
fi

WORK="$(mktemp -d /tmp/verify.XXXXXX)"
PGD="$WORK/pgdata"; SOCK="$WORK/sock"; UPX="$WORK/uploads"
mkdir -p "$SOCK" "$UPX"
# Canli sunucuya baglanmamak icin ortam degiskenleri gecici sunucuya cevrilir
export PGHOST="$SOCK" PGPORT=54329 PGUSER=verify PGDATABASE=postgres
unset PGPASSWORD || true
STARTED=0; FAILED=""

cleanup() {
  if [ "$STARTED" = 1 ]; then pg_ctl -D "$PGD" -m immediate stop >/dev/null 2>&1 || true; fi
  rm -rf "$WORK"
}
finish_fail() {
  FAILED="${FAILED:-beklenmeyen hata, satir ${BASH_LINENO[0]}}"
  log "DOGRULAMA BASARISIZ: $FAILED"
  if [ "${VERIFY_NO_METRICS:-0}" != 1 ]; then
    metric_write "" "" "" "" "" "" "" 0
    notify "GERI YUKLEME DOGRULAMASI BASARISIZ ($(basename "$SRC")): $FAILED"
  fi
  trap - EXIT
  cleanup
  exit 1
}
trap finish_fail ERR
trap cleanup EXIT

fail() { FAILED="$*"; false; }

log "yedek: $SRC"
(cd "$SRC" && sha256sum -c SHA256SUMS >/dev/null) || fail "sha256 uyusmuyor"

log "gecici PostgreSQL baslatiliyor"
initdb -D "$PGD" -U verify -A trust --no-locale -E UTF8 >/dev/null
pg_ctl -D "$PGD" -w -t 60 -o "-c listen_addresses='' -c unix_socket_directories='$SOCK' -c port=54329 -c fsync=off" -l "$WORK/pg.log" start >/dev/null
STARTED=1
createdb verify_target

log "veritabani geri yukleniyor (sifre cozme + pg_restore)"
age -d -i "$IDENT" "$SRC/db.dump.age" | pg_restore --no-owner --no-privileges --exit-on-error -d verify_target \
  || fail "pg_restore basarisiz"
export PGDATABASE=verify_target

jget() { grep -E "\"$1\":" "$SRC/manifest.json" | head -1 | sed -E 's/.*: *([0-9]+).*/\1/'; }
M_FLY="$(jget flyway_version)"; M_FILES="$(jget upload_files)"
R_FLY="$(psql -Atqc "select coalesce(max(version::int),0) from flyway_schema_history where success and version ~ '^[0-9]+\$'")"
[ "$R_FLY" = "$M_FLY" ] || fail "Flyway surumu uyusmuyor (yedek $M_FLY, geri yuklenen $R_FLY)"
log "Flyway surumu: V$R_FLY (uyumlu)"

TABLES=0; BAD=0; ROWS=0
while IFS=: read -r t n; do
  t="$(printf '%s' "$t" | tr -d ' "')"
  n="$(printf '%s' "$n" | tr -d ' ,')"
  if ! [[ "$t" =~ ^[a-z0-9_]+$ ]] || ! [[ "$n" =~ ^[0-9]+$ ]]; then continue; fi
  TABLES=$((TABLES+1))
  if ! r="$(psql -Atqc "select count(*) from public.$t" 2>/dev/null)"; then
    log "tablo YOK: $t"; BAD=$((BAD+1)); continue
  fi
  ROWS=$((ROWS+r))
  min=$(( n * (100 - TOL) / 100 ))
  if [ "$r" -lt "$min" ]; then log "satir sayisi dusuk: $t yedek=$n geri=$r"; BAD=$((BAD+1)); fi
done < <(sed -n '/"tables": {/,/^  }/p' "$SRC/manifest.json" | grep -E '^ +"')
[ "$TABLES" -gt 0 ] || fail "manifest'te tablo yok"
[ "$BAD" = 0 ] || fail "$BAD tablo uyusmuyor"
log "tablolar: $TABLES tablo, toplam $ROWS satir (tolerans %$TOL)"

log "uploads arsivi cikariliyor"
age -d -i "$IDENT" "$SRC/uploads.tar.zst.age" | zstd -dq | tar -C "$UPX" -xf - || fail "uploads arsivi cozulemedi"
GOT="$(find "$UPX" -type f | wc -l | tr -d ' ')"
LOW=$(( M_FILES * (100 - TOL) / 100 ))
[ "$GOT" -ge "$LOW" ] || fail "dosya sayisi dusuk (yedek $M_FILES, cikan $GOT)"
log "uploads: $GOT dosya (manifest $M_FILES)"

NOW=$(date +%s)
if [ "${VERIFY_NO_METRICS:-0}" != 1 ]; then metric_write "" "" "" "" "" "" "$NOW" 1; fi
log "DOGRULAMA BASARILI: $(basename "$SRC") geri yuklenebilir (Flyway V$R_FLY, $TABLES tablo, $ROWS satir, $GOT dosya)"

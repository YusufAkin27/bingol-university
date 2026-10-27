#!/usr/bin/env bash
# Sifreli yedegi YENI bir veritabanina geri yukler (canli veritabanini ezmez; --overwrite-live ile bilincli ezilir).
# Kullanim:
#   restore.sh <yedek-dizini> --identity <age-ozel-anahtar-dosyasi> [--target-db bingol_restore]
#              [--uploads-to <bos-dizin>] [--overwrite-live]
# Adimlar: sha256 dogrula -> sifre coz -> pg_restore -> (ops.) uploads cikar -> ozet.
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib.sh"

SRC="${1:-}"; shift || true
IDENT="${BACKUP_AGE_IDENTITY_FILE:-}"; TARGET="bingol_restore"; UPTO=""; LIVE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --identity) IDENT="$2"; shift 2;;
    --target-db) TARGET="$2"; shift 2;;
    --uploads-to) UPTO="$2"; shift 2;;
    --overwrite-live) LIVE=1; shift;;
    *) die "bilinmeyen arguman: $1";;
  esac
done
[ -d "$SRC" ] || die "yedek dizini yok: '$SRC'"
[ -f "$IDENT" ] || die "age ozel anahtar dosyasi yok (--identity)"
[[ "$TARGET" =~ ^[a-zA-Z0-9_]+$ ]] || die "gecersiz veritabani adi"
if [ "$TARGET" = "${PGDATABASE:-bingol}" ] && [ "$LIVE" = 0 ]; then
  die "hedef canli veritabani ($TARGET). Yeni bir ad verin ya da bilincli olarak --overwrite-live kullanin"
fi

log "1/4 sha256 dogrulaniyor"
(cd "$SRC" && sha256sum -c SHA256SUMS) || die "sha256 uyusmuyor: yedek bozuk/degismis"

log "2/4 veritabani olusturuluyor: $TARGET"
if [ "$LIVE" = 1 ]; then
  dropdb --if-exists "$TARGET"
fi
createdb "$TARGET"

log "3/4 sifre cozulup geri yukleniyor"
age -d -i "$IDENT" "$SRC/db.dump.age" | pg_restore --no-owner --no-privileges --exit-on-error -d "$TARGET"

if [ -n "$UPTO" ]; then
  log "4/4 uploads cikariliyor: $UPTO"
  mkdir -p "$UPTO"
  [ -z "$(ls -A "$UPTO" 2>/dev/null)" ] || die "uploads hedefi bos degil: $UPTO"
  age -d -i "$IDENT" "$SRC/uploads.tar.zst.age" | zstd -dq | tar -C "$UPTO" -xf -
else
  log "4/4 uploads atlandi (--uploads-to verilmedi)"
fi

log "TAMAM. Kontrol: psql -d $TARGET -c 'select max(version::int) from flyway_schema_history'"
log "Sonraki adim: docs/BACKUP_RESTORE.md 'Geri yukleme sonrasi' (silinen hesaplari yeniden anonimlestir, uygulamayi bu DB'ye yonlendir)"

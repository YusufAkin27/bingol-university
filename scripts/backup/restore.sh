#!/usr/bin/env bash
# Sifreli yedegi YENI bir veritabanina geri yukler (canli veritabanini ezmez; --overwrite-live ile bilincli degistirilir).
# Kullanim:
#   restore.sh <yedek-dizini> [--identity <age-ozel-anahtar-dosyasi>] [--target-db bingol_restore]
#              [--uploads-to <bos-dizin>] [--overwrite-live] [--check-only]
# Adimlar: (0) KURU DOGRULAMA: sha256 + anahtar okunabilir/gecerli + dump sifresi cozulur ve pg_restore --list calisir
#          (+ uploads arsivi cozulur/zstd/tar) -> hicbir sey degismeden once; (1) gecici veritabanina geri yukle;
#          (2) --overwrite-live ise MEVCUT canli veritabani SILINMEZ: yeniden adlandirilir (<ad>_prev_<damga>) ve yenisi yerine konur;
#          (3) (ops.) uploads cikar. --check-only yalniz (0)'i yapar (restore-live.sh yigini durdurmadan once cagirir).
# Anahtar: --identity, yoksa BACKUP_AGE_IDENTITY_FILE (entrypoint'in postgres icin hazirladigi kopya).
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib.sh"
drop_root "$HERE/restore.sh" "$@"

SRC="${1:-}"; shift || true
IDENT="${BACKUP_AGE_IDENTITY_FILE:-}"; TARGET="bingol_restore"; UPTO=""; LIVE=0; CHECK=0
while [ $# -gt 0 ]; do
  case "$1" in
    --identity) IDENT="$2"; shift 2;;
    --target-db) TARGET="$2"; shift 2;;
    --uploads-to) UPTO="$2"; shift 2;;
    --overwrite-live) LIVE=1; shift;;
    --check-only) CHECK=1; shift;;
    *) die "bilinmeyen arguman: $1";;
  esac
done
[ -d "$SRC" ] || die "yedek dizini yok: '$SRC'"
[ -n "$IDENT" ] && [ -e "$IDENT" ] || die "age ozel anahtar dosyasi yok (--identity / BACKUP_AGE_IDENTITY_FILE)"
[ -r "$IDENT" ] || die "age ozel anahtar dosyasi OKUNAMIYOR: $IDENT (sahip/izin: postgres/uid 70 okuyabilmeli; entrypoint kopyasi icin BACKUP_AGE_IDENTITY_SRC verin)"
grep -q '^AGE-SECRET-KEY-' "$IDENT" || die "anahtar dosyasi bir age ozel anahtari icermiyor: $IDENT"
[[ "$TARGET" =~ ^[a-zA-Z0-9_]+$ ]] || die "gecersiz veritabani adi"
if [ "$TARGET" = "${PGDATABASE:-bingol}" ] && [ "$LIVE" = 0 ] && [ "$CHECK" = 0 ]; then
  die "hedef canli veritabani ($TARGET). Yeni bir ad verin ya da bilincli olarak --overwrite-live kullanin"
fi
STAMP="$(date +%Y%m%dT%H%M%S)"

# ---- (0) kuru dogrulama: canli veriye dokunmadan once her seyi dene ----
log "0/4 kuru dogrulama: sha256, anahtar, dump (pg_restore --list), tam sifre cozme$([ -n "$UPTO" ] || [ "$CHECK" = 1 ] && echo ', uploads arsivi')"
(cd "$SRC" && sha256sum -c SHA256SUMS >/dev/null) || die "sha256 uyusmuyor: yedek bozuk/degismis"
# pg_restore --list icerik tablosunu okuyup cikar; age'e SIGPIPE gidebilir -> yalniz pg_restore'un durumuna bakilir
set +o pipefail
age -d -i "$IDENT" "$SRC/db.dump.age" | pg_restore --list >/dev/null
RC=("${PIPESTATUS[@]}")
set -o pipefail
[ "${RC[1]}" = 0 ] || die "dump icerik tablosu okunamadi (anahtar yanlis olabilir ya da dump bozuk; age=${RC[0]} pg_restore=${RC[1]})"
# tam akis: age her blogu dogrular (bozulma/yanlis anahtar burada yakalanir)
age -d -i "$IDENT" "$SRC/db.dump.age" >/dev/null || die "dump sifresi cozulemedi (yanlis anahtar ya da bozuk dosya)"
if [ -n "$UPTO" ] || [ "$CHECK" = 1 ]; then
  age -d -i "$IDENT" "$SRC/uploads.tar.zst.age" | zstd -dq | tar -tf - >/dev/null || die "uploads arsivi cozulemedi/bozuk"
fi
log "kuru dogrulama TAMAM: yedek okunabilir ve geri yuklenebilir gorunuyor"
if [ "$CHECK" = 1 ]; then exit 0; fi

# ---- (1) gecici veritabanina geri yukle ----
if [ "$LIVE" = 1 ]; then BUILD="${TARGET}_new_${STAMP}"; else BUILD="$TARGET"; fi
cleanup_build() { dropdb --if-exists "$BUILD" >/dev/null 2>&1 || true; }
log "1/4 veritabani olusturuluyor: $BUILD"
createdb "$BUILD"
trap 'rc=$?; [ "$rc" = 0 ] || { log "HATA: geri yukleme basarisiz (cikis $rc); mevcut veritabani DEGISMEDI"; cleanup_build; }' EXIT

log "2/4 sifre cozulup geri yukleniyor"
age -d -i "$IDENT" "$SRC/db.dump.age" | pg_restore --no-owner --no-privileges --exit-on-error -d "$BUILD"
trap - EXIT   # geri yukleme bitti; bundan sonrasinda yarim kalan degisimi elle kurtarmak icin $BUILD silinmez

# ---- (2) canli degisimi: eski veritabani silinmez, adi degisir ----
if [ "$LIVE" = 1 ]; then
  PREV="${TARGET}_prev_${STAMP}"
  ADM=(psql -X -Atq -v ON_ERROR_STOP=1 -d postgres)
  if [ "$("${ADM[@]}" -c "select 1 from pg_database where datname='$TARGET'")" = 1 ]; then
    log "3/4 canli veritabani yeniden adlandiriliyor: $TARGET -> $PREV (SILINMEZ)"
    "${ADM[@]}" -c "alter database \"$TARGET\" with allow_connections false" >/dev/null
    "${ADM[@]}" -c "select pg_terminate_backend(pid) from pg_stat_activity where datname='$TARGET'" >/dev/null
    "${ADM[@]}" -c "alter database \"$TARGET\" rename to \"$PREV\"" >/dev/null || { "${ADM[@]}" -c "alter database \"$TARGET\" with allow_connections true" >/dev/null || true; { cleanup_build; die "canli veritabani yeniden adlandirilamadi (acik baglanti?); canli veritabani DEGISMEDI"; }; }
    if ! "${ADM[@]}" -c "alter database \"$BUILD\" rename to \"$TARGET\"" >/dev/null; then
      "${ADM[@]}" -c "alter database \"$PREV\" rename to \"$TARGET\"" >/dev/null || true
      "${ADM[@]}" -c "alter database \"$TARGET\" with allow_connections true" >/dev/null || true
      die "yeni veritabani yerine konamadi; eski veritabani geri alindi, yeni veritabani $BUILD olarak duruyor"
    fi
    "${ADM[@]}" -c "alter database \"$PREV\" with allow_connections false" >/dev/null || true
    log "eski veritabani $PREV olarak SAKLANDI (geri donus: bu ada yeniden adlandirin). Sorun yoksa disk icin: dropdb $PREV"
  else
    log "3/4 canli veritabani yoktu; yeni veritabani $TARGET adini aldi"
    "${ADM[@]}" -c "alter database \"$BUILD\" rename to \"$TARGET\"" >/dev/null
  fi
fi

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

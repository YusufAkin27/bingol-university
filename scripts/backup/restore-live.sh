#!/usr/bin/env bash
# CANLI yigina geri yukleme (sunucuda, repo kokunden). Uygulamayi durdurur, veritabanini ve yuklenen dosyalari
# secilen yedekten geri koyar, yigini yeniden baslatir. Yikicidir: onay ister.
# Kullanim: bash scripts/backup/restore-live.sh <yedek-dizini> <age-ozel-anahtar-dosyasi> [--yes]
#   yedek-dizini: sunucudaki yedek (volume icinden: docker compose ... cp ile ya da uzak kopyadan indirilmis dizin)
#   Ortam: ENV_FILE (.env.prod), PROJECT (bu), COMPOSE_FILES ("-f docker-compose.prod.yml")
#
# Guvenlik (A4):
#  1) Yigin DURDURULMADAN ONCE yedek kuru dogrulanir (anahtar okunabilir mi, dump cozulur mu, pg_restore --list, uploads arsivi).
#     Herhangi biri basarisizsa HICBIR SEY degismez.
#  2) Canli veritabani SILINMEZ: yeni veritabani once gecici adla kurulur, sonra canli ad <ad>_prev_<damga> olarak SAKLANIR ve
#     yenisi yerine konur (geri donus: veritabanlarini yeniden adlandirin).
#  3) Adim hatasinda yigin (eski veritabaniyla) yeniden baslatilmaya calisilir.
# Anahtar dosyasi konteynere /run/restore-key altinda baglanir (servisin :ro /run/backup baglamasinin ALTINA degil) ve
# entrypoint tarafindan postgres'in okuyabilecegi 0400 kopyaya cevrilir; host'taki izin (0600, baska sahip) sorun degildir.
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

SRC="${1:-}"; KEY="${2:-}"; YES="${3:-}"
ENV_FILE="${ENV_FILE:-.env.prod}"; PROJECT="${PROJECT:-bu}"
COMPOSE_FILES="${COMPOSE_FILES:--f docker-compose.prod.yml}"
[ -d "$SRC" ] || { echo "kullanim: $0 <yedek-dizini> <anahtar> [--yes]" >&2; exit 2; }
[ -f "$KEY" ] || { echo "age ozel anahtar dosyasi yok: $KEY" >&2; exit 2; }
[ -r "$KEY" ] || { echo "age ozel anahtar dosyasi okunamiyor (bu kullanici icin): $KEY" >&2; exit 2; }
grep -q '^AGE-SECRET-KEY-' "$KEY" || { echo "bu dosya bir age OZEL anahtari icermiyor: $KEY" >&2; exit 2; }
[ -f "$SRC/SHA256SUMS" ] && [ -f "$SRC/db.dump.age" ] && [ -f "$SRC/uploads.tar.zst.age" ] \
  || { echo "yedek dizini eksik (SHA256SUMS, db.dump.age, uploads.tar.zst.age)" >&2; exit 2; }
SRC="$(cd "$SRC" && pwd)"; KEY="$(cd "$(dirname "$KEY")" && pwd)/$(basename "$KEY")"
# shellcheck disable=SC2206
DC=(docker compose -p "$PROJECT" $COMPOSE_FILES --env-file "$ENV_FILE")
KEYMOUNT=(-e BACKUP_AGE_IDENTITY_SRC=/run/restore-key/restore.key -v "$KEY:/run/restore-key/restore.key:ro")

echo "Geri yuklenecek yedek: $SRC"
head -8 "$SRC/manifest.json" 2>/dev/null || true
echo "UYARI: canli veritabani ve TUM yuklenen dosyalar bu yedekle DEGISTIRILECEK (eski veritabani <ad>_prev_<damga> olarak saklanir)."
if [ "$YES" != "--yes" ]; then
  printf 'Devam icin GERI YUKLE yazin: '
  read -r ans
  [ "$ans" = "GERI YUKLE" ] || { echo "iptal"; exit 1; }
fi

echo "[0/5] kuru dogrulama (yigin henuz DURDURULMADI)"
(cd "$SRC" && sha256sum -c SHA256SUMS)
# Konteyner icinde restore.sh postgres (uid 70) olarak calisir: indirilmis yedek dizini 0700/baska sahipli ise "Permission denied"
# olurdu. Dizin yalniz SIFRELI dosyalar icerir; baskasinin okuyabilmesi guvenli. Gerekirse okunur yapilir.
if [ -n "$(find "$SRC" \( -type d ! -perm -o+rx \) -o \( -type f ! -perm -o+r \) 2>/dev/null | head -n 1)" ]; then
  echo "yedek dizini baska kullanicilar icin okunamiyor; chmod -R a+rX uygulaniyor (icerik age ile sifreli)"
  chmod -R a+rX "$SRC" || { echo "izin verilemedi: $SRC (elle: chmod -R a+rX)" >&2; exit 1; }
fi
"${DC[@]}" run --rm --no-deps "${KEYMOUNT[@]}" -v "$SRC:/restore:ro" backup \
  restore.sh /restore --check-only \
  || { echo "KURU DOGRULAMA BASARISIZ: anahtar/yedek gecersiz; hicbir sey degistirilmedi" >&2; exit 1; }

STOPPED=0
restart_on_error() {
  rc=$?
  if [ "$rc" != 0 ] && [ "$STOPPED" = 1 ]; then
    echo "HATA (cikis $rc): geri yukleme tamamlanmadi. Yigin yeniden baslatiliyor (canli veritabani ya degismedi ya <ad>_prev_* olarak duruyor)." >&2
    "${DC[@]}" up -d || true
  fi
}
trap restart_on_error EXIT

echo "[1/5] uygulama durduruluyor (caddy, web, backend)"
STOPPED=1
"${DC[@]}" stop caddy web backend
"${DC[@]}" up -d postgres redis

echo "[2/5] veritabani geri yukleniyor (gecici adla kurulur, sonra canli adla degistirilir)"
"${DC[@]}" run --rm --no-deps "${KEYMOUNT[@]}" -v "$SRC:/restore:ro" backup \
  restore.sh /restore --target-db bingol --overwrite-live

echo "[3/5] yuklenen dosyalar geri yukleniyor"
# Once gecici dizine cikar, basariliysa mevcut icerigi sil ve tasi (cikarma hatasinda canli dosyalar kalir)
"${DC[@]}" run --rm --no-deps --user root --entrypoint bash "${KEYMOUNT[@]}" \
  -v "${PROJECT}_uploads:/live" -v "$SRC:/restore:ro" backup \
  -c 'set -euo pipefail; shopt -s dotglob nullglob
      rm -rf /live/.restore-incoming; mkdir /live/.restore-incoming
      age -d -i /run/restore-key/restore.key /restore/uploads.tar.zst.age | zstd -dq | tar -C /live/.restore-incoming -xf -
      find /live -mindepth 1 -maxdepth 1 ! -name .restore-incoming -exec rm -rf {} +
      mv /live/.restore-incoming/* /live/ 2>/dev/null || true
      rmdir /live/.restore-incoming
      chown -R 1001:1001 /live'

echo "[4/5] Redis oturumlari temizleniyor (kullanicilar yeniden giris yapar)"
"${DC[@]}" exec -T redis redis-cli flushall >/dev/null

echo "[5/5] yigin baslatiliyor"
"${DC[@]}" up -d
STOPPED=0

echo "TAMAM. Kontrol: ${DC[*]} ps ; sonra docs/BACKUP_RESTORE.md bolum 5 adim 7-8 (silinen hesaplari yeniden anonimlestir, dogrula)."
echo "Eski veritabani saklandi: ${DC[*]} exec -T postgres psql -U bingol -d postgres -Atc '\\l' | grep bingol_prev ; sorun yoksa dropdb ile silin."

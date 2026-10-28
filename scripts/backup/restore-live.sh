#!/usr/bin/env bash
# CANLI yigina geri yukleme (sunucuda, repo kokunden). Uygulamayi durdurur, veritabanini ve yuklenen dosyalari
# secilen yedekten geri koyar, yigini yeniden baslatir. Yikicidir: onay ister.
# Kullanim: bash scripts/backup/restore-live.sh <yedek-dizini> <age-ozel-anahtar-dosyasi> [--yes]
#   yedek-dizini: sunucudaki yedek (volume icinden: docker compose ... cp ile ya da uzak kopyadan indirilmis dizin)
#   Ortam: ENV_FILE (.env.prod), PROJECT (bu), COMPOSE_FILES ("-f docker-compose.prod.yml")
# Canli veri, geri yukleme oncesi (varsa) son durum olarak ayrica dokulmez; once elle bir yedek alin: backup.sh.
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

SRC="${1:-}"; KEY="${2:-}"; YES="${3:-}"
ENV_FILE="${ENV_FILE:-.env.prod}"; PROJECT="${PROJECT:-bu}"
COMPOSE_FILES="${COMPOSE_FILES:--f docker-compose.prod.yml}"
[ -d "$SRC" ] || { echo "kullanim: $0 <yedek-dizini> <anahtar> [--yes]" >&2; exit 2; }
[ -f "$KEY" ] || { echo "age ozel anahtar dosyasi yok: $KEY" >&2; exit 2; }
[ -f "$SRC/SHA256SUMS" ] && [ -f "$SRC/db.dump.age" ] && [ -f "$SRC/uploads.tar.zst.age" ] \
  || { echo "yedek dizini eksik (SHA256SUMS, db.dump.age, uploads.tar.zst.age)" >&2; exit 2; }
SRC="$(cd "$SRC" && pwd)"; KEY="$(cd "$(dirname "$KEY")" && pwd)/$(basename "$KEY")"
# shellcheck disable=SC2206
DC=(docker compose -p "$PROJECT" $COMPOSE_FILES --env-file "$ENV_FILE")

echo "Geri yuklenecek yedek: $SRC"
cat "$SRC/manifest.json" 2>/dev/null | head -8 || true
echo "UYARI: canli veritabani ve TUM yuklenen dosyalar bu yedekle DEGISTIRILECEK."
if [ "$YES" != "--yes" ]; then
  printf 'Devam icin GERI YUKLE yazin: '
  read -r ans
  [ "$ans" = "GERI YUKLE" ] || { echo "iptal"; exit 1; }
fi

(cd "$SRC" && sha256sum -c SHA256SUMS)

echo "[1/5] uygulama durduruluyor (caddy, web, backend)"
"${DC[@]}" stop caddy web backend
"${DC[@]}" up -d postgres redis

echo "[2/5] veritabani geri yukleniyor"
"${DC[@]}" run --rm --no-deps -v "$SRC:/restore:ro" -v "$KEY:/run/backup/restore.key:ro" backup \
  restore.sh /restore --identity /run/backup/restore.key --target-db bingol --overwrite-live

echo "[3/5] yuklenen dosyalar geri yukleniyor"
"${DC[@]}" run --rm --no-deps --user root --entrypoint bash \
  -v "${PROJECT}_uploads:/live" -v "$SRC:/restore:ro" -v "$KEY:/run/backup/restore.key:ro" backup \
  -c 'set -euo pipefail; find /live -mindepth 1 -delete; age -d -i /run/backup/restore.key /restore/uploads.tar.zst.age | zstd -dq | tar -C /live -xf -; chown -R 1001:1001 /live'

echo "[4/5] Redis oturumlari temizleniyor (kullanicilar yeniden giris yapar)"
"${DC[@]}" exec -T redis redis-cli flushall >/dev/null

echo "[5/5] yigin baslatiliyor"
"${DC[@]}" up -d

echo "TAMAM. Kontrol: ${DC[*]} ps ; sonra docs/BACKUP_RESTORE.md bolum 5 adim 7-8 (silinen hesaplari yeniden anonimlestir, dogrula)."

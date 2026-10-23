#!/usr/bin/env bash
# Gelistirme: yonetim paneli grafikleri icin demo veri ekler / siler.
# Kullanim: ./scripts/seed-demo.sh           (ekler; tekrar calistirilabilir)
#           ./scripts/seed-demo.sh --clean   (yalnizca demo.%@bingol.edu.tr kayitlarini siler)
# Calisan compose yigininin postgres servisine baglanir (docker compose exec -T postgres psql -U bingol -d bingol).
set -eu
cd "$(dirname "$0")/.."

# Proje adi: worktree/klasor adi farkli olsa da calisan yigina baglanmak icin (COMPOSE_PROJECT_NAME ile ezilebilir).
# DB_PASSWORD yalnizca compose dosyasinin ayristirilmasi icin gerekir (exec parola kullanmaz).
export DB_PASSWORD="${DB_PASSWORD:-unused}"
PSQL="docker compose -p ${COMPOSE_PROJECT_NAME:-bingol-university} exec -T postgres psql -U bingol -d bingol -v ON_ERROR_STOP=1"

if [ "${1:-}" = "--clean" ]; then
  echo "DELETE FROM app_user WHERE email LIKE 'demo.%@bingol.edu.tr'; SELECT count(*) AS kalan_demo FROM app_user WHERE email LIKE 'demo.%@bingol.edu.tr';" | $PSQL
  echo "demo kayitlari silindi"
else
  $PSQL < scripts/seed-demo.sql
  echo "demo verisi hazir"
fi

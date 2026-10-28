#!/usr/bin/env bash
# Gelistirme: veritabanini SIFIRLAR (volume'lar silinir!) ve tohum verisiyle temiz baslatir.
# Kullanim: ./scripts/reset-dev-db.sh [compose-proje-adi]      (varsayilan: bu_fresh)
#   BACKEND_PORT (varsayilan 18080), INITIAL_FILL (varsayilan false), ASSUME_YES=1 (onay sorma)
# Yalnizca YEREL: SPRING_PROFILES_ACTIVE'de "prod" varsa reddeder. Belge: docs/DEV_SEED.md
set -eu
cd "$(dirname "$0")/.."

PROJECT="${1:-bu_fresh}"
case "${SPRING_PROFILES_ACTIVE:-}" in *prod*) echo "HATA: prod profilinde calistirilmaz." >&2; exit 1 ;; esac
if [ ! -f .env ]; then echo "HATA: .env yok (cp .env.example .env)." >&2; exit 1; fi
if [ "${ASSUME_YES:-0}" != "1" ]; then
  printf "'%s' projesinin TUM verisi (postgres, redis, yuklemeler) silinecek. Devam? [e/H] " "$PROJECT"
  read -r ans
  [ "$ans" = "e" ] || { echo "iptal"; exit 1; }
fi

export BACKEND_PORT="${BACKEND_PORT:-18080}"
export INITIAL_FILL="${INITIAL_FILL:-false}"
export SPRING_PROFILES_ACTIVE="dev,seed"
export MAIL_ENABLED=false
DC="docker compose -p $PROJECT"

echo "1/4 durduruluyor, volume'lar siliniyor"
$DC down -v --remove-orphans
echo "2/4 postgres + redis + backend (seed profili) kaldiriliyor"
$DC up -d --build postgres redis backend

echo "3/4 saglik bekleniyor (en cok 240 sn; tohum acilista calisir)"
ok=0
for _ in $(seq 1 80); do
  if curl -fsS "http://localhost:${BACKEND_PORT}/actuator/health" >/dev/null 2>&1; then ok=1; break; fi
  sleep 3
done
if [ "$ok" != "1" ]; then echo "HATA: backend saglikli degil: $DC logs backend" >&2; exit 1; fi

echo "4/4 tohum dogrulaniyor"
$DC exec -T postgres psql -U bingol -d bingol -tA -c \
  "SELECT 'kullanici='||count(*) FROM app_user WHERE email LIKE '%@bingol.edu.tr'" 
$DC exec -T postgres psql -U bingol -d bingol -tA -c \
  "SELECT 'kulup='||(SELECT count(*) FROM community)||' etkinlik='||(SELECT count(*) FROM user_event)||' gonderi='||(SELECT count(*) FROM post)"
echo "Hazir: http://localhost:${BACKEND_PORT}  giris: mobil.test@bingol.edu.tr / admin: seed.admin@bingol.edu.tr (sifre docs/DEV_SEED.md)"
echo "Not: tohumu kapatmak icin stack'i SPRING_PROFILES_ACTIVE=dev ile yeniden baslatin (veri kalir)."

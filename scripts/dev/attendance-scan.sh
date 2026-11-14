#!/usr/bin/env bash
# Yerel gelistirme: ogrencinin TELEFONUNU oynar. Giris yapar ve doner QR kodunu yoklamaya okutur, sunucunun yanitini yazar.
# Kullanim:
#   ./scripts/dev/attendance-scan.sh <eposta-veya-okul-numarasi> '<bingol-lesson:...kod>'
#   echo 'bingol-lesson:12.345678.AbCd...' | ./scripts/dev/attendance-scan.sh seed.ayse@bingol.edu.tr
# Ortam:
#   BASE            backend adresi (varsayilan http://localhost:18080 = scripts/reset-dev-db.sh varsayilani)
#   SEED_PASSWORD   hesabin sifresi (varsayilan: docs/DEV_SEED.md'deki DEV tohum sifresi; yalniz yerel tohum hesaplari)
# Not: kod her 5 sn'de degisir ve yalniz ~10 sn gecerlidir; web ekranindaki kodu hemen yapistirin.
# Cikis kodu: 0 = 200 (MARKED/ALREADY/PENDING), 1 = sunucu reddetti (kod yanitta), 2 = kullanim/baglanti hatasi.
set -u
BASE=${BASE:-http://localhost:18080}
SEED_PASSWORD=${SEED_PASSWORD:-DevSeed-2026!}

LOGIN=${1:-}
if [ -z "$LOGIN" ]; then echo "Kullanim: $0 <eposta-veya-numara> [kod]   (kod yoksa stdin'den okunur)" >&2; exit 2; fi
CODE=${2:-}
if [ -z "$CODE" ]; then
  if [ -t 0 ]; then printf 'QR kodu: ' >&2; fi
  IFS= read -r CODE || true
fi
CODE=$(printf '%s' "$CODE" | tr -d '[:space:]')
if [ -z "$CODE" ]; then echo "HATA: kod bos" >&2; exit 2; fi

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

printf '{"email":"%s","password":"%s","client":"web"}' "$LOGIN" "$SEED_PASSWORD" > "$TMP/login.json"
LR=$(curl -s -m 20 -w '\n%{http_code}' -X POST -H 'Content-Type: application/json' --data-binary @"$TMP/login.json" "$BASE/api/auth/login") || { echo "HATA: $BASE erisilemiyor" >&2; exit 2; }
LST=$(printf '%s' "$LR" | tail -n 1)
TOK=$(printf '%s' "$LR" | grep -o '"accessToken":"[^"]*' | head -1 | cut -d'"' -f4)
if [ "$LST" != "200" ] || [ -z "$TOK" ]; then echo "Giris basarisiz ($LOGIN): HTTP $LST $(printf '%s' "$LR" | head -n -1 | head -c 200)" >&2; exit 2; fi

printf '{"code":"%s"}' "$CODE" > "$TMP/scan.json"
SR=$(curl -s -m 20 -w '\n%{http_code}' -X POST -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' --data-binary @"$TMP/scan.json" "$BASE/api/attendance/scan") || { echo "HATA: tarama istegi gitmedi" >&2; exit 2; }
SST=$(printf '%s' "$SR" | tail -n 1)
echo "HTTP $SST $(printf '%s' "$SR" | head -n -1)"
[ "$SST" = "200" ]

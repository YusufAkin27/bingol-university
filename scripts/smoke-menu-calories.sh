#!/usr/bin/env bash
# Yemek kalorisi duman testi (V870): yetki, tek/toplu kalori yazimi, dogrulama, herkese acik menu yanitinda
# dishes/totalKcal/kcalComplete, ETag degisimi ve "senkron/gun satiri yeniden yazimi kaloriyi EZMEZ" (postgres uzerinde, gercek Flyway).
# Calisan compose yigina karsi, ASCII, tekrar calistirilabilir.
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ./scripts/smoke-menu-calories.sh
# Onkosul: MAIL_ENABLED=false (kod log'dan okunur), ADMIN_EMAILS=$ADMIN_EMAIL (FULL), V870 uygulanmis.
# Veri: 2099-01 ayinda iki sahte menu_day satiri eklenir ve sonunda silinir (kaynak siteye istek ATILMAZ).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
DB_USER=${DB_USER:-bingol}
DB_NAME=${DB_NAME:-bingol}
H='Content-Type: application/json'
FAIL=0

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 300)"; FAIL=1; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
sql() { docker compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -At -c "$1" 2>&1; }

register() {
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true,\"language\":\"tr\"}"
  sleep 1
  local c t
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  t=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Sifre1234\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  if [ -z "$t" ]; then
    t=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" |
      grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  fi
  echo "$t"
}

D1=2099-01-05
D2=2099-01-06
cleanup() {
  sql "DELETE FROM menu_item_calorie WHERE menu_date IN ('$D1','$D2')" >/dev/null
  sql "DELETE FROM menu_day WHERE menu_date IN ('$D1','$D2')" >/dev/null
}
trap cleanup EXIT

echo "== hazirlik"
TA=$(register "$ADMIN_EMAIL" "Yonetici")
TU=$(register "smkkcal$RANDOM@bingol.edu.tr" "Smoke Kcal")
[ -n "$TA" ] && [ -n "$TU" ] || { echo "token alinamadi (ADMIN_EMAILS ayarli mi?)"; exit 1; }
AD="Authorization: Bearer $TA"; US="Authorization: Bearer $TU"
cleanup
check "tablo var (V870)" 0 "$(sql 'SELECT count(*) FROM menu_item_calorie' | tr -d '[:space:]')"
sql "INSERT INTO menu_day (menu_date, items) VALUES ('$D1', 'MERCIMEK CORBASI
PATLICAN MUSAKKA
CACIK'), ('$D2', 'ORMAN KEBABI')" >/dev/null

echo "== yetki"
BODY='{"items":[{"name":"CACIK","kcal":80}]}'
check "anonim tek" 401 "$(code -X PUT -H "$H" $A/admin/menu/$D1/calories -d "$BODY")"
check "kullanici tek" 403 "$(code -X PUT -H "$H" -H "$US" $A/admin/menu/$D1/calories -d "$BODY")"
check "kullanici toplu" 403 "$(code -X PUT -H "$H" -H "$US" $A/admin/menu/calories -d '{"days":[]}')"

echo "== dogrulama"
check "kalori > 5000" 400 "$(code -X PUT -H "$H" -H "$AD" $A/admin/menu/$D1/calories -d '{"items":[{"name":"CACIK","kcal":5001}]}')"
check "kalori < 0" 400 "$(code -X PUT -H "$H" -H "$AD" $A/admin/menu/$D1/calories -d '{"items":[{"name":"CACIK","kcal":-1}]}')"
R=$(curl -s -H "$H" -H "$AD" -X PUT $A/admin/menu/$D1/calories -d '{"items":[{"name":"YOK","kcal":5}]}')
has "olmayan yemek" MENU_ITEM_NOT_FOUND "$R"
check "olmayan gun" 404 "$(code -X PUT -H "$H" -H "$AD" $A/admin/menu/2099-01-20/calories -d "$BODY")"
check "bozuk tarih" 400 "$(code -X PUT -H "$H" -H "$AD" $A/admin/menu/bozuk/calories -d "$BODY")"
R=$(curl -s -H "$H" -H "$AD" -H 'Accept-Language: en' -X PUT $A/admin/menu/$D1/calories -d '{"items":[{"name":"CACIK","kcal":9000}]}')
has "ingilizce hata metni" "whole number between 0 and 5000" "$R"

echo "== tek gun yazimi"
R=$(curl -s -H "$H" -H "$AD" -X PUT $A/admin/menu/$D1/calories -d '{"items":[{"name":"mercimek corbasi","kcal":180},{"name":"CACIK","kcal":80}]}')
has "dishes alani" '"dishes"' "$R"
has "kismi toplam" '"totalKcal":260' "$R"
has "tamam degil" '"kcalComplete":false' "$R"

echo "== herkese acik menu"
E1=$(curl -s -D - -o /dev/null "$A/menu?month=2099-01" | grep -i '^etag' | tr -d '\r')
M=$(curl -s "$A/menu?month=2099-01")
has "items hala metin dizisi" '"items":["MERCIMEK CORBASI","PATLICAN MUSAKKA","CACIK"]' "$M"
has "kcal gorunur" '"kcal":180' "$M"
R=$(curl -s -H "$H" -H "$AD" -X PUT $A/admin/menu/$D1/calories -d '{"items":[{"name":"PATLICAN MUSAKKA","kcal":320}]}')
has "tamamlandi" '"kcalComplete":true' "$R"
has "toplam 580" '"totalKcal":580' "$R"
E2=$(curl -s -D - -o /dev/null "$A/menu?month=2099-01" | grep -i '^etag' | tr -d '\r')
if [ -n "$E1" ] && [ "$E1" != "$E2" ]; then echo "  ok   ETag degisti"; else echo "  FAIL ETag degismedi ($E1 / $E2)"; FAIL=1; fi
check "ayni ETag ile 304" 304 "$(code -H "If-None-Match: ${E2#*: }" "$A/menu?month=2099-01")"

echo "== toplu uc (kismi)"
R=$(curl -s -H "$H" -H "$AD" -X PUT $A/admin/menu/calories -d "{\"days\":[{\"date\":\"$D2\",\"items\":[{\"name\":\"ORMAN KEBABI\",\"kcal\":550},{\"name\":\"YANLIS\",\"kcal\":1}]},{\"date\":\"2099-01-25\",\"items\":[{\"name\":\"X\",\"kcal\":1}]}]}")
has "1 guncellendi" '"updated":1' "$R"
has "yemek atlandi" ITEM_NOT_FOUND "$R"
has "gun atlandi" DAY_NOT_FOUND "$R"
check "gecersiz kalori tum istegi reddeder" 400 "$(code -X PUT -H "$H" -H "$AD" $A/admin/menu/calories -d "{\"days\":[{\"date\":\"$D2\",\"items\":[{\"name\":\"ORMAN KEBABI\",\"kcal\":99999}]}]}")"

echo "== senkron kaloriyi ezmez"
# Kaynak sitenin yaptigini taklit et: ayni gunun satiri yeniden yazilir (yeni yemek eklendi), sonra tamamen silinip tekrar eklenir
sql "UPDATE menu_day SET items = 'MERCIMEK CORBASI
PATLICAN MUSAKKA
CACIK
AYRAN' WHERE menu_date = '$D1'" >/dev/null
M=$(curl -s "$A/menu?month=2099-01")
has "yeni yemek kalorisiz" '"name":"AYRAN","kcal":null' "$M"
has "eski kalori korundu" '"name":"PATLICAN MUSAKKA","kcal":320' "$M"
sql "DELETE FROM menu_day WHERE menu_date = '$D1'" >/dev/null
sql "INSERT INTO menu_day (menu_date, items) VALUES ('$D1', 'PATLICAN MUSAKKA')" >/dev/null
M=$(curl -s "$A/menu?month=2099-01")
has "silinip yeniden yazilinca kalori geri geldi" '"name":"PATLICAN MUSAKKA","kcal":320' "$M"

echo "== kalori silme"
R=$(curl -s -H "$H" -H "$AD" -X PUT $A/admin/menu/$D1/calories -d '{"items":[{"name":"PATLICAN MUSAKKA","kcal":null}]}')
has "kalori silindi" '"kcal":null' "$R"
check "silinen yemegin satiri yok" 0 "$(sql "SELECT count(*) FROM menu_item_calorie WHERE menu_date='$D1' AND item_key='patlican musakka'" | tr -d '[:space:]')"
check "digerleri duruyor" 2 "$(sql "SELECT count(*) FROM menu_item_calorie WHERE menu_date='$D1'" | tr -d '[:space:]')"

echo "== denetim"
check "denetim kaydi var" "1" "$(sql "SELECT CASE WHEN count(*) > 0 THEN 1 ELSE 0 END FROM admin_audit WHERE path LIKE '%/admin/menu/%calories%'" | tr -d '[:space:]')"

if [ "$FAIL" = 0 ]; then echo "TUMU GECTI"; exit 0; else echo "BASARISIZ"; exit 1; fi

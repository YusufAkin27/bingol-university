#!/usr/bin/env bash
# CR1 duman testi (anonim cokme raporlari): anonim gonderim -> imzaya gore gruplama -> sunucu maskeleme -> govde siniri
# -> yonetici liste/ayrinti/ozet -> durum degisikligi (sebep zorunlu) -> yeniden acma -> silme -> hiz siniri (429).
# Calisan compose yigina karsi, ASCII, tekrar calistirilabilir.
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ./scripts/smoke-crash-reports.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur), ADMIN_EMAILS=$ADMIN_EMAIL, V860 migration uygulanmis.
# Not: COMPOSE_PROJECT_NAME ile ayri proje kullaniliyorsa ayni degisken bu betikte de verilmelidir (docker compose logs).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 300)"; FAIL=1; fi; }
hasnt() { if echo "$3" | grep -qF -- "$2"; then echo "  FAIL $1 (bulunmamali: $2)"; FAIL=1; else echo "  ok   $1"; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

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

# report <cihaz-kimligi> <hata-turu> <surum> <yigin-json-kacisli> [ek-alanlar]
report() {
  curl -s -o /dev/null -w '%{http_code}' -X POST -H "$H" -H "X-Device-Id: $1" $A/app/crash-reports \
    -d "{\"appVersion\":\"$3\",\"platform\":\"android\",\"osVersion\":\"Android 14\",\"errorType\":\"$2\",\"stackTrace\":\"$4\",\"screen\":\"/news\",\"fatal\":true${5:-}}"
}
# list_id <q>: q ile suzulen ilk grubun kimligi
group_id() { curl -s -H "$AD" "$A/admin/crashes?q=$1&size=5" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

SFX=$RANDOM$RANDOM
T1="SmokeErrorA$SFX"
T2="SmokeErrorB$SFX"
ST1='#0      Foo.bar (package:bu_kampus/features/smoke/a_page.dart:10:5)\n#1      baz (package:bu_kampus/core/api.dart:77:3)\n<asynchronous suspension>'
ST1B='#0      Foo.bar (package:bu_kampus/features/smoke/a_page.dart:99:2)\n#1      baz (package:bu_kampus/core/api.dart:70:9)\n<asynchronous suspension>'
ST2='#0      Other.thing (package:bu_kampus/features/smoke/b_page.dart:5:5)\n#1      baz (package:bu_kampus/core/api.dart:77:3)'

echo "== hazirlik"
TA=$(register "$ADMIN_EMAIL" "Yonetici")
TU=$(register "smkcrash$SFX@bingol.edu.tr" "Smoke Crash")
[ -n "$TA" ] && [ -n "$TU" ] || { echo "token alinamadi (ADMIN_EMAILS ayarli mi?)"; exit 1; }
AD="Authorization: Bearer $TA"; US="Authorization: Bearer $TU"

echo "== yetki (admin uclari)"
check "anonim liste" 401 "$(code $A/admin/crashes)"
check "kullanici liste" 403 "$(code -H "$US" $A/admin/crashes)"
check "kullanici durum" 403 "$(code -X PATCH -H "$H" -H "$US" $A/admin/crashes/1/status -d '{"status":"ACK","reason":"deneme yetkisiz"}')"
check "kullanici sil" 403 "$(code -X DELETE -H "$US" $A/admin/crashes/1)"

echo "== anonim gonderim ve gruplama"
DEV1="smoke-dev-$SFX-0001"
check "anonim rapor kabul" 202 "$(report $DEV1 $T1 1.0.0 "$ST1")"
check "ayni hata, farkli satir no" 202 "$(report $DEV1 $T1 1.0.0 "$ST1B")"
check "farkli hata" 202 "$(report $DEV1 $T2 1.0.0 "$ST2")"
G1=$(group_id "$T1"); G2=$(group_id "$T2")
[ -n "$G1" ] && [ -n "$G2" ] && echo "  ok   iki grup olustu ($G1, $G2)" || { echo "  FAIL gruplar olusmadi"; FAIL=1; exit 1; }
[ "$G1" != "$G2" ] && echo "  ok   farkli imza farkli grup" || { echo "  FAIL imzalar birlesti"; FAIL=1; }
L=$(curl -s -H "$AD" "$A/admin/crashes?q=$T1")
has "ayni imza tek grup" '"totalItems":1' "$L"
has "sayac 2" '"eventCount":2' "$L"
has "ilk durum NEW" '"status":"NEW"' "$L"
has "surum dagilimi" '"version":"1.0.0"' "$L"
D=$(curl -s -H "$AD" $A/admin/crashes/$G1)
has "ayrinti olaylari" '"events":[' "$D"
has "yigin izi" 'package:bu_kampus/features/smoke/a_page.dart' "$D"
SUM=$(curl -s -H "$AD" $A/admin/crashes/summary)
has "ozet newGroups" '"newGroups"' "$SUM"
has "ozet events24h" '"events24h"' "$SUM"

echo "== kisisel veri sunucuda maskelenir; kimlik saklanmaz"
T3="SmokeErrorC$SFX"
ST3='#0 f (package:bu_kampus/a.dart:1:1)\nHata ali.veli@bingol.edu.tr https://x.com/a?token=SIRRIM123\nAuthorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NSJ9.imzaimza\nogrenci 226051015 C:\\Users\\Toprak\\dev\\app.dart'
check "kisisel veri iceren rapor" 202 "$(report smoke-dev-$SFX-0002 $T3 1.0.0 "$ST3" ',"message":"mail ayse@bingol.edu.tr 5321234567"')"
G3=$(group_id "$T3")
D3=$(curl -s -H "$AD" $A/admin/crashes/$G3)
hasnt "e-posta yok" 'ali.veli' "$D3"
hasnt "e-posta (ileti) yok" 'ayse@bingol' "$D3"
hasnt "sorgu dizesi yok" 'SIRRIM123' "$D3"
hasnt "jwt yok" 'eyJhbGciOi' "$D3"
hasnt "ogrenci no yok" '226051015' "$D3"
hasnt "telefon yok" '5321234567' "$D3"
hasnt "ev dizini kullanicisi yok" 'Toprak' "$D3"
has "dosya yolu korunur" 'package:bu_kampus/a.dart' "$D3"
hasnt "kullanici kimligi alani yok" '"userId"' "$D3"
# girisli kullanici da gonderebilir; kimlik yine saklanmaz
check "girisli rapor" 202 "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "$H" -H "$US" -H "X-Device-Id: smoke-dev-$SFX-0003" $A/app/crash-reports -d "{\"appVersion\":\"1.0.0\",\"platform\":\"ios\",\"errorType\":\"$T3\",\"stackTrace\":\"$ST3\"}")"
D3=$(curl -s -H "$AD" $A/admin/crashes/$G3)
hasnt "girisli: kullanici kimligi yok" '"userId"' "$D3"
has "iOS platformu" '"platform":"IOS"' "$D3"

echo "== dogrulama ve govde siniri"
check "errorType eksik 400" 400 "$(code -X POST -H "$H" $A/app/crash-reports -d '{"appVersion":"1.0.0","platform":"android","stackTrace":"x"}')"
check "gecersiz surum 400" 400 "$(code -X POST -H "$H" $A/app/crash-reports -d '{"appVersion":"1 0 0!","platform":"android","errorType":"E","stackTrace":"x"}')"
BIG=$(head -c 20000 /dev/zero | tr '\0' 'a')
check "16 KB ustu govde 413" 413 "$(code -X POST -H "$H" $A/app/crash-reports -d "{\"appVersion\":\"1.0.0\",\"platform\":\"android\",\"errorType\":\"E\",\"stackTrace\":\"$BIG\"}")"

echo "== yonetici: durum degisikligi (sebep zorunlu) ve yeniden acma"
check "sebepsiz durum 400" 400 "$(code -X PATCH -H "$H" -H "$AD" $A/admin/crashes/$G1/status -d '{"status":"ACK"}')"
check "gecersiz durum 400" 400 "$(code -X PATCH -H "$H" -H "$AD" $A/admin/crashes/$G1/status -d '{"status":"WAT","reason":"gecersiz durum"}')"
R=$(curl -s -X PATCH -H "$H" -H "$AD" $A/admin/crashes/$G1/status -d '{"status":"ACK","reason":"inceleniyor duman"}')
has "ACK" '"status":"ACK"' "$R"
has "gerekce kaydedildi" 'inceleniyor duman' "$R"
R=$(curl -s -X PATCH -H "$H" -H "$AD" $A/admin/crashes/$G1/status -d '{"status":"RESOLVED","reason":"duzeltme yayinda","fixedInVersion":"1.1.0"}')
has "RESOLVED" '"status":"RESOLVED"' "$R"
has "duzeltme surumu" '"fixedInVersion":"1.1.0"' "$R"
check "eski surumden tekrar" 202 "$(report $DEV1 $T1 1.0.0 "$ST1")"
has "eski surum grubu acmaz" '"status":"RESOLVED"' "$(curl -s -H "$AD" $A/admin/crashes/$G1)"
check "duzeltme surumunden tekrar" 202 "$(report smoke-dev-$SFX-0004 $T1 1.1.0 "$ST1")"
R=$(curl -s -H "$AD" $A/admin/crashes/$G1)
has "yeni surumde yeniden acildi" '"status":"NEW"' "$R"
has "yeniden acilma sayaci" '"reopenCount":1' "$R"
has "yeni surum dagilimda" '"version":"1.1.0"' "$R"
L=$(curl -s -H "$AD" "$A/admin/crashes?status=NEW&platform=ANDROID&version=1.1.0&q=$T1")
has "durum+platform+surum suzgeci" '"totalItems":1' "$L"
L=$(curl -s -H "$AD" "$A/admin/crashes?status=RESOLVED&q=$T1")
has "RESOLVED suzgeci bos" '"totalItems":0' "$L"
check "gecersiz platform suzgeci 400" 400 "$(code -H "$AD" "$A/admin/crashes?platform=WAT")"

echo "== grup basina en cok 50 olay"
T4="SmokeErrorD$SFX"
n=0
for d in 1 2 3 4 5 6 7 8 9 10; do
  for i in 1 2 3 4 5 6; do
    s=$(report smoke-bulk-$SFX-$d $T4 1.0.0 "$ST1")
    [ "$s" = "202" ] && n=$((n + 1))
  done
done
echo "  kabul edilen: $n / 60"
G4=$(group_id "$T4")
D4=$(curl -s -H "$AD" $A/admin/crashes/$G4)
EV=$(echo "$D4" | grep -o '"stack":' | wc -l | tr -d ' ')
if [ "$EV" -le 50 ] && [ "$EV" -ge 40 ]; then echo "  ok   saklanan olay <= 50 ($EV)"; else echo "  FAIL saklanan olay sayisi ($EV)"; FAIL=1; fi
has "kumulatif sayac" "\"eventCount\":$n" "$(curl -s -H "$AD" "$A/admin/crashes?q=$T4")"

echo "== hiz siniri (cihaz basina dakikada 6 / gunde 20)"
RL=""
for i in $(seq 1 30); do
  RL="$RL $(report smoke-rl-$SFX $T2 1.0.0 "$ST2")"
done
OK=$(echo "$RL" | tr ' ' '\n' | grep -c '^202$')
TOO=$(echo "$RL" | tr ' ' '\n' | grep -c '^429$')
if [ "$TOO" -ge 1 ] && [ "$OK" -ge 5 ] && [ "$OK" -le 20 ]; then echo "  ok   429 goruldu (202: $OK, 429: $TOO)"; else echo "  FAIL hiz siniri (202: $OK, 429: $TOO)"; FAIL=1; fi
H429=$(curl -s -i -X POST -H "$H" -H "X-Device-Id: smoke-rl-$SFX" $A/app/crash-reports -d "{\"appVersion\":\"1.0.0\",\"platform\":\"android\",\"errorType\":\"$T2\",\"stackTrace\":\"x\"}")
has "429 Retry-After" 'Retry-After' "$H429"

echo "== silme (sebep zorunlu)"
check "sebepsiz silme 400" 400 "$(code -X DELETE -H "$AD" $A/admin/crashes/$G2)"
check "sebepli silme 204" 204 "$(code -X DELETE -H "$AD" -H 'X-Admin-Reason: duman temizligi' $A/admin/crashes/$G2)"
check "silinen grup 404" 404 "$(code -H "$AD" $A/admin/crashes/$G2)"
code -X DELETE -H "$AD" -H 'X-Admin-Reason: duman temizligi' $A/admin/crashes/$G1 >/dev/null
code -X DELETE -H "$AD" -H 'X-Admin-Reason: duman temizligi' $A/admin/crashes/$G3 >/dev/null
code -X DELETE -H "$AD" -H 'X-Admin-Reason: duman temizligi' $A/admin/crashes/$G4 >/dev/null

echo "== denetim kaydi"
AU=$(curl -s -H "$AD" "$A/admin/audit?size=30")
has "denetimde crashes yazma kaydi" '/api/admin/crashes' "$AU"

if [ "$FAIL" = "0" ]; then echo "TAMAM: smoke-crash-reports"; else echo "BASARISIZ: smoke-crash-reports"; exit 1; fi

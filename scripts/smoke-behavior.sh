#!/usr/bin/env bash
# BK6 duman testi (kullanici davranis analizi): olay sozlesmesi dogrulamasi (sid/sure/eylem beyaz listesi, bozuk olay tek tek
# elenir) -> oturumlastirma (sid'li + sid'siz eski olaylar) -> /api/admin/analytics/behavior/{overview,screens,flows,actions,
# users,users/{id}} -> yetki (anonim 401, kullanici 403) -> sayfalama/siralama/aralik hatalari -> denetim kaydi -> V1240 tablolari.
# Calisan compose yigina karsi, ASCII, tekrar calistirilabilir (her kosuda yeni kullanici + yeni sid'ler).
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ./scripts/smoke-behavior.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur), ADMIN_EMAILS=$ADMIN_EMAIL, V1240 migration uygulanmis.
# Not: COMPOSE_PROJECT_NAME ile ayri proje kullaniliyorsa ayni degisken bu betikte de verilmelidir (docker compose logs).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
DB_USER=${DB_USER:-bingol}
DB_NAME=${DB_NAME:-bingol}
H='Content-Type: application/json'
FAIL=0

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 400)"; FAIL=1; fi; }
hasnt() { if echo "$3" | grep -qF -- "$2"; then echo "  FAIL $1 (bulunmamali: $2)"; FAIL=1; else echo "  ok   $1"; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
# ts <kac-saniye-once>: ISO an (UTC)
ts() { date -u -d "-$1 seconds" +%Y-%m-%dT%H:%M:%SZ; }

register() {
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Zk7-Qmv-Lpx92w\",\"displayName\":\"$2\",\"acceptTerms\":true,\"language\":\"tr\"}"
  sleep 1
  local c t
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  t=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Zk7-Qmv-Lpx92w\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  if [ -z "$t" ]; then
    t=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Zk7-Qmv-Lpx92w\"}" |
      grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  fi
  echo "$t"
}
post() { curl -s -o /dev/null -w '%{http_code}' -X POST -H "$H" -H "$US" $A/analytics/events -d "$1"; }

SFX=$RANDOM$RANDOM
SA="smka$SFX"   # sid'ler [a-z0-9]{8,32}
SB="smkb$SFX"
UMAIL="smkbeh$SFX@bingol.edu.tr"

echo "== hazirlik"
TA=$(register "$ADMIN_EMAIL" "Yonetici")
TU=$(register "$UMAIL" "Smoke Davranis")
[ -n "$TA" ] && [ -n "$TU" ] || { echo "token alinamadi (ADMIN_EMAILS ayarli mi?)"; exit 1; }
AD="Authorization: Bearer $TA"; US="Authorization: Bearer $TU"
UID1=$(curl -s -H "$US" $A/users/me | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
[ -n "$UID1" ] && echo "  ok   kullanici kimligi $UID1" || { echo "  FAIL kullanici kimligi alinamadi"; exit 1; }

echo "== yetki"
for p in overview screens flows actions users "users/$UID1"; do
  check "anonim $p 401" 401 "$(code $A/admin/analytics/behavior/$p)"
  check "kullanici $p 403" 403 "$(code -H "$US" $A/admin/analytics/behavior/$p)"
done

echo "== olay sozlesmesi: gecerli olaylar"
# Oturum A (sid'li): home 20 sn, news 40 sn, bir begeni, arka plana atildi (60 sn, 2 ekran)
EV_A="{\"events\":[
 {\"name\":\"session_start\",\"props\":{\"sid\":\"$SA\"},\"at\":\"$(ts 600)\"},
 {\"name\":\"screen_view\",\"screen\":\"home\",\"props\":{\"sid\":\"$SA\"},\"at\":\"$(ts 600)\"},
 {\"name\":\"screen_exit\",\"screen\":\"home\",\"props\":{\"sid\":\"$SA\",\"dwellMs\":20000},\"at\":\"$(ts 580)\"},
 {\"name\":\"screen_view\",\"screen\":\"news\",\"props\":{\"sid\":\"$SA\"},\"at\":\"$(ts 580)\"},
 {\"name\":\"action\",\"screen\":\"news\",\"props\":{\"sid\":\"$SA\",\"kind\":\"like\",\"target\":\"news\"},\"at\":\"$(ts 575)\"},
 {\"name\":\"screen_exit\",\"screen\":\"news\",\"props\":{\"sid\":\"$SA\",\"dwellMs\":40000},\"at\":\"$(ts 540)\"},
 {\"name\":\"session_end\",\"props\":{\"sid\":\"$SA\",\"durationMs\":60000,\"screens\":2,\"reason\":\"background\"},\"at\":\"$(ts 540)\"}]}"
check "oturum A kabul (204)" 204 "$(post "$EV_A")"
# Oturum B: hemen kapatma (2 sn, tek ekran) -> bounce + quickClose
EV_B="{\"events\":[
 {\"name\":\"session_start\",\"props\":{\"sid\":\"$SB\"},\"at\":\"$(ts 400)\"},
 {\"name\":\"screen_view\",\"screen\":\"home\",\"props\":{\"sid\":\"$SB\"},\"at\":\"$(ts 400)\"},
 {\"name\":\"screen_exit\",\"screen\":\"home\",\"props\":{\"sid\":\"$SB\",\"dwellMs\":2000},\"at\":\"$(ts 398)\"},
 {\"name\":\"session_end\",\"props\":{\"sid\":\"$SB\",\"durationMs\":2000,\"screens\":1,\"reason\":\"background\"},\"at\":\"$(ts 398)\"}]}"
check "oturum B kabul (204)" 204 "$(post "$EV_B")"
# Eski surum (sid'siz): iki oturum, aralarinda 40 dk bosluk -> sunucu turetir
EV_C="{\"events\":[
 {\"name\":\"app_open\",\"at\":\"$(ts 7200)\"},
 {\"name\":\"screen_view\",\"screen\":\"search\",\"at\":\"$(ts 7190)\"},
 {\"name\":\"screen_view\",\"screen\":\"home\",\"at\":\"$(ts 7100)\"},
 {\"name\":\"app_open\",\"at\":\"$(ts 4000)\"},
 {\"name\":\"screen_view\",\"screen\":\"home\",\"at\":\"$(ts 3996)\"}]}"
check "eski surum olaylari kabul (204)" 204 "$(post "$EV_C")"

echo "== olay sozlesmesi: bozuk olaylar tek tek elenir (istek dusmez)"
BAD="{\"events\":[
 {\"name\":\"action\",\"screen\":\"home\",\"props\":{\"sid\":\"$SA\",\"kind\":\"hack_it\"}},
 {\"name\":\"action\",\"screen\":\"home\",\"props\":{\"sid\":\"$SA\",\"kind\":\"LIKE\"}},
 {\"name\":\"screen_exit\",\"screen\":\"home\",\"props\":{\"sid\":\"$SA\",\"dwellMs\":86400001}},
 {\"name\":\"screen_exit\",\"screen\":\"home\",\"props\":{\"sid\":\"$SA\",\"dwellMs\":-5}},
 {\"name\":\"screen_view\",\"screen\":\"home\",\"props\":{\"sid\":\"KISA\"}},
 {\"name\":\"session_end\",\"props\":{\"sid\":\"$SA\"}}]}"
check "tum bozuklar elenir, istek 204" 204 "$(post "$BAD")"
check "yapisal bozuk (buyuk harf ad) 400" 400 "$(post '{"events":[{"name":"Bad-Name"}]}')"
check "9 props 400" 400 "$(post '{"events":[{"name":"x","props":{"a":"1","b":"2","c":"3","d":"4","e":"5","f":"6","g":"7","h":"8","i":"9"}}]}')"
check "8 props kabul" 204 "$(post '{"events":[{"name":"x","props":{"a":"1","b":"2","c":"3","d":"4","e":"5","f":"6","g":"7","h":"8"}}]}')"

echo "== kullanici zaman cizelgesi (users/{id})"
D=$(curl -s -H "$AD" "$A/admin/analytics/behavior/users/$UID1?days=7")
has "kullanici ad" '"displayName":"Smoke Davranis"' "$D"
has "e-posta (FULL yonetici maskesiz)" "\"email\":\"$UMAIL\"" "$D"
has "4 oturum (A, B, iki turetilmis)" '"sessions":4' "$D"
has "toplam sure 166 sn" '"totalMs":166000' "$D"
has "hemen kapatma 2" '"quickCloseCount":2' "$D"
has "bounce orani 0.5" '"bounceRate":0.5' "$D"
has "A oturumu sid" "\"sid\":\"$SA\"" "$D"
has "A oturumu neden" '"reason":"background"' "$D"
has "turetilmis oturum" '"reason":"derived"' "$D"
has "ekran adimi home 20 sn" '"dwellMs":20000' "$D"
has "ekran adimi news 40 sn" '"dwellMs":40000' "$D"
has "eylem adimi like" '"kind":"like"' "$D"
has "bounce rozeti" '"bounce":true' "$D"
has "quickClose rozeti" '"quickClose":true' "$D"
hasnt "gecersiz eylem kaydedilmedi" 'hack_it' "$D"
# en yeni once: B (ts 400) A'dan (ts 600) sonra basladi
POS_B=$(echo "$D" | grep -bo "\"sid\":\"$SB\"" | head -1 | cut -d: -f1)
POS_A=$(echo "$D" | grep -bo "\"sid\":\"$SA\"" | head -1 | cut -d: -f1)
[ -n "$POS_A" ] && [ -n "$POS_B" ] && [ "$POS_B" -lt "$POS_A" ] && echo "  ok   en yeni oturum once" || { echo "  FAIL oturum sirasi"; FAIL=1; }
check "gecersiz gun sayisi 400" 400 "$(code -H "$AD" "$A/admin/analytics/behavior/users/$UID1?days=46")"
check "olmayan kullanici 404" 404 "$(code -H "$AD" "$A/admin/analytics/behavior/users/999999999")"

echo "== ozet"
O=$(curl -s -H "$AD" "$A/admin/analytics/behavior/overview")
for k in sessions users avgSessionMs medianSessionMs avgScreensPerSession sessionsPerUser bounceRate quickCloseRate byDay durationBuckets; do
  has "overview.$k" "\"$k\"" "$O"
done
N=$(echo "$O" | grep -o '"sessions":[0-9]*' | head -1 | cut -d: -f2)
[ -n "$N" ] && [ "$N" -ge 4 ] && echo "  ok   en az 4 oturum ($N)" || { echo "  FAIL oturum sayisi: $N"; FAIL=1; }
has "sure kovasi etiketi" '"label":"<5sn"' "$O"
has "sure kovasi 10dk+" '"label":"10dk+"' "$O"
OD=$(curl -s -H "$AD" "$A/admin/analytics/behavior/overview?from=$(date -u -d '-3 days' +%F)&to=$(date -u +%F)")
has "4 gunluk aralik byDay" '"day":"' "$OD"

echo "== ekranlar (sayfali, siralanabilir)"
S=$(curl -s -H "$AD" "$A/admin/analytics/behavior/screens?sort=views&dir=desc&page=0&size=100")
has "ekran home" '"screen":"home"' "$S"
has "ekran news" '"screen":"news"' "$S"
for k in views users avgDwellMs medianDwellMs p90DwellMs exitRate bounceRate sharePct total page size; do
  has "screens.$k" "\"$k\"" "$S"
done
S1=$(curl -s -H "$AD" "$A/admin/analytics/behavior/screens?size=1&page=0")
has "size=1 sayfalama" '"size":1' "$S1"
for srt in views users avgDwellMs exitRate bounceRate; do
  check "screens sort=$srt" 200 "$(code -H "$AD" "$A/admin/analytics/behavior/screens?sort=$srt&dir=asc")"
done
check "gecersiz sort 400" 400 "$(code -H "$AD" "$A/admin/analytics/behavior/screens?sort=drop_table")"

echo "== akislar ve eylemler"
F=$(curl -s -H "$AD" "$A/admin/analytics/behavior/flows")
for k in topTransitions entryScreens exitScreens dropOff; do has "flows.$k" "\"$k\"" "$F"; done
has "gecis home -> news" '"from":"home","to":"news"' "$F"
AC=$(curl -s -H "$AD" "$A/admin/analytics/behavior/actions")
has "eylem like" '"kind":"like"' "$AC"
has "eylem ekran kirilimi" '"perScreen":[' "$AC"

echo "== kullanici listesi (arama, siralama, sayfalama)"
U=$(curl -s -H "$AD" "$A/admin/analytics/behavior/users?q=smkbeh$SFX&sort=sessions&dir=desc&page=0&size=20")
has "q ile tek kullanici" '"total":1' "$U"
has "oturum sayisi 4" '"sessions":4' "$U"
has "toplam sure" '"totalMs":166000' "$U"
has "en cok vakit gecirilen ekran" '"screen":"news","ms":40000' "$U"
has "e-posta" "\"email\":\"$UMAIL\"" "$U"
UW=$(curl -s -H "$AD" "$A/admin/analytics/behavior/users?q=%25")
has "joker q kacirilir (eslesme yok)" '"total":0' "$UW"
for srt in sessions totalMs avgSessionMs bounceRate quickCloseCount lastSeenAt; do
  check "users sort=$srt" 200 "$(code -H "$AD" "$A/admin/analytics/behavior/users?sort=$srt&dir=asc&size=5")"
done
check "users gecersiz sort 400" 400 "$(code -H "$AD" "$A/admin/analytics/behavior/users?sort=password")"
check "users size > 100 kenetlenir" 200 "$(code -H "$AD" "$A/admin/analytics/behavior/users?size=1000")"

echo "== aralik hatalari"
R=$(curl -s -H "$AD" "$A/admin/analytics/behavior/overview?from=2020-01-01&to=2026-11-02")
has "45 gunden uzun: RANGE_TOO_LARGE" 'RANGE_TOO_LARGE' "$R"
check "RANGE_TOO_LARGE 400" 400 "$(code -H "$AD" "$A/admin/analytics/behavior/overview?from=2020-01-01&to=2026-11-02")"
check "bozuk tarih 400" 400 "$(code -H "$AD" "$A/admin/analytics/behavior/overview?from=abc")"
check "ters aralik 400" 400 "$(code -H "$AD" "$A/admin/analytics/behavior/overview?from=2026-11-02&to=2026-11-01")"
RE=$(curl -s -H "$AD" -H 'Accept-Language: en' "$A/admin/analytics/behavior/overview?from=2020-01-01&to=2026-11-02")
has "RANGE_TOO_LARGE ingilizce" 'Date range too large' "$RE"

echo "== denetim kaydi (kullanici bazli uclar)"
AU=$(curl -s -H "$AD" "$A/admin/audit?size=60")
has "denetimde behavior/users okumasi" '/api/admin/analytics/behavior/users' "$AU"

echo "== V1240 tablolari"
if docker compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -At -c "SELECT count(*) FROM analytics_session_daily" >/dev/null 2>&1; then
  echo "  ok   analytics_session_daily var"
  docker compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -At -c "SELECT count(*) FROM analytics_screen_daily" >/dev/null 2>&1 \
    && echo "  ok   analytics_screen_daily var" || { echo "  FAIL analytics_screen_daily yok"; FAIL=1; }
else
  echo "  ATLA  postgres'e erisilemedi (tablo denetimi yapilmadi)"
fi

if [ "$FAIL" = "0" ]; then echo "TAMAM: smoke-behavior"; else echo "BASARISIZ: smoke-behavior"; exit 1; fi

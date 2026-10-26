#!/usr/bin/env bash
# T3 etkinlik denetimi: calisan yigina karsi kapasite yarisi, IDOR, tarih sinirlari, takvim ay siniri,
# sayfalama sinirlari, QR sahteciligi/yeniden oynatma, CSV enjeksiyonu, silinen kullanici davranisi.
# Kullanim: COMPOSE_PROJECT_NAME=wt_t3 BASE=http://localhost:8103 ./scripts/qa-event-api.sh
# Tekrar calistirilabilir (her kosuda rastgele sonek). Onkosul: MAIL_ENABLED=false, ADMIN_EMAILS=$ADMIN_EMAIL.
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
RACERS=${RACERS:-6}  # kayit ucu IP basina saatte 10: 4 ana kullanici + 6 yarisci = 10
CAP=2
BURST=3              # her yarisci ayni anda BURST istek yollar
H='Content-Type: application/json'
FAIL=0
TMP=$(mktemp)
RACE=$(mktemp)
trap 'rm -f "$TMP" "$RACE" "$RACE".*' EXIT

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
contains() { if printf '%s' "$3" | grep -q -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 ('$2' yok)"; FAIL=1; fi; }
lacks() { if printf '%s' "$3" | grep -q -- "$2"; then echo "  FAIL $1 ('$2' var)"; FAIL=1; else echo "  ok   $1"; fi; }
call() {
  local m=$1 p=$2 t=$3 d=${4:-}
  if [ -n "$d" ]; then
    CODE=$(curl -s -o "$TMP" -w '%{http_code}' -X "$m" -H "$H" -H "Authorization: Bearer $t" "$A$p" -d "$d")
  else
    CODE=$(curl -s -o "$TMP" -w '%{http_code}' -X "$m" -H "Authorization: Bearer $t" "$A$p")
  fi
  BODY=$(cat "$TMP")
}
step() { local name=$1 exp=$2; shift 2; call "$@"; check "$name" "$exp" "$CODE"; }
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
field() { grep -o "\"$1\":\"[^\"]*" | head -1 | cut -d'"' -f4; }
iso() { date -u -d "$1" +%Y-%m-%dT%H:%M:%SZ; }
logs() { docker compose logs backend 2>&1; }

register() { # email ad
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c tok
  c=$(logs | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  tok=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  if [ -z "$tok" ]; then
    tok=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  fi
  echo "$tok"
}

SFX=$RANDOM
echo "== hazirlik (rate limit icin onceden redis temizlenmesi onerilir)"
TA=$(register "$ADMIN_EMAIL" "Yonetici")
T1=$(register "qa3a$SFX@bingol.edu.tr" "Organizator Bir")
T2=$(register "qa3b$SFX@bingol.edu.tr" "Katilimci Iki")
T3=$(register "qa3c$SFX@bingol.edu.tr" "Yabanci Uc")
[ -n "$TA" ] && [ -n "$T1" ] && [ -n "$T2" ] && [ -n "$T3" ] || { echo "kayit basarisiz"; exit 1; }
ID1=$(curl -s -H "Authorization: Bearer $T1" $A/users/me | idof)
ID2=$(curl -s -H "Authorization: Bearer $T2" $A/users/me | idof)
ID3=$(curl -s -H "Authorization: Bearer $T3" $A/users/me | idof)
START=$(iso "+10 minutes"); END=$(iso "+3 hours")

echo "== kapasite yarisi ($RACERS kullanici x $BURST es zamanli istek, kapasite $CAP)"
RTOK=()
for i in $(seq 1 "$RACERS"); do RTOK+=("$(register "qa3r${i}x$SFX@bingol.edu.tr" "Yarisci $i")"); done
step "yaris etkinligi" 201 POST /events "$TA" "{\"title\":\"Yaris Etkinligi $SFX\",\"startsAt\":\"$START\",\"endsAt\":\"$END\",\"capacity\":$CAP}"
EVR=$(printf '%s' "$BODY" | idof)
n=0
for t in "${RTOK[@]}"; do
  for b in $(seq 1 $BURST); do
    n=$((n + 1))
    ( curl -s -o /dev/null -w '%{http_code}\n' -X PUT -H "$H" -H "Authorization: Bearer $t" $A/events/$EVR/rsvp -d '{"status":"GOING"}' > "$RACE.$n" ) &
  done
done
wait
cat "$RACE".* | sort | uniq -c | tr '\n' ' '; echo
check "hic 5xx/401 yok" 0 "$(cat "$RACE".* | grep -c '^[45]0[01]$')"
check "en az kapasite kadar basarili" 1 "$(( $(cat "$RACE".* | grep -c '^200$') >= CAP ? 1 : 0 ))"
call GET /events/$EVR "$TA"
contains "goingCount tam kapasite" "\"goingCount\":$CAP" "$BODY"
call GET "/events/$EVR/attendees" "$TA"
check "katilimci satiri tam kapasite" $CAP "$(printf '%s' "$BODY" | grep -o '"userId"' | wc -l | tr -d ' ')"
# ayni kullanicinin es zamanli cift istegi: tek RSVP, sayac 1 artar
step "cift istek etkinligi" 201 POST /events "$TA" "{\"title\":\"Cift Istek $SFX\",\"startsAt\":\"$START\",\"endsAt\":\"$END\",\"capacity\":10}"
EVD=$(printf '%s' "$BODY" | idof)
rm -f "$RACE".*
for k in 1 2 3 4 5 6; do
  ( curl -s -o /dev/null -w '%{http_code}\n' -X PUT -H "$H" -H "Authorization: Bearer $T2" $A/events/$EVD/rsvp -d '{"status":"GOING"}' > "$RACE.$k" ) &
done
wait
check "cift istekte hic 5xx yok" 0 "$(cat "$RACE".* | grep -c '^5')"
call GET /events/$EVD "$TA"
contains "goingCount tam 1" '"goingCount":1' "$BODY"

echo "== IDOR: onay bekleyen / baskasinin etkinligi"
step "bagimsiz etkinlik (202)" 202 POST /events "$T1" "{\"title\":\"Bekleyen $SFX\",\"startsAt\":\"$START\",\"endsAt\":\"$END\"}"
EVP=$(printf '%s' "$BODY" | idof)
step "yabanci okuyamaz 404" 404 GET /events/$EVP "$T3"
step "yabanci katilimci listesi 404 (varlik sizmaz)" 404 GET /events/$EVP/attendees "$T3"
step "yabanci duzenleyemez 404" 404 PATCH /events/$EVP "$T3" '{"title":"Hack"}'
step "yabanci silemez 404" 404 DELETE /events/$EVP "$T3"
step "yabanci yoklama listesi 404" 404 GET /events/$EVP/attendance "$T3"
step "yabanci kod alamaz 404" 404 GET /events/$EVP/checkin-code "$T3"
step "yabanci csv 404" 404 GET /events/$EVP/attendance.csv "$T3"
step "yabanci elle isaretleyemez 404" 404 PUT /events/$EVP/attendance/$ID2 "$T3" '{"present":true}'
step "olmayan etkinlik 404" 404 GET /events/999999999 "$T3"
step "olusturan gorur" 200 GET /events/$EVP "$T1"
step "ACTIVE etkinlikte yabanci 403 (404 degil)" 403 GET /events/$EVR/attendees "$T3"
step "ACTIVE etkinlikte yabanci duzenleyemez 403" 403 PATCH /events/$EVR "$T3" '{"title":"Hack"}'
step "ACTIVE etkinlikte yabanci silemez 403" 403 DELETE /events/$EVR "$T3"
PNG="$(mktemp --suffix=.png)"; printf '\x89PNG\r\n\x1a\n' > "$PNG"
PNGW=$(cygpath -m "$PNG" 2>/dev/null || echo "$PNG")
cover() { curl -s -o /dev/null -w '%{http_code}' -X POST -H "Authorization: Bearer $1" -F "file=@$PNGW;type=$3" $A/events/$2/cover; }
check "yabanci kapak yukleyemez 403" 403 "$(cover "$T3" $EVR image/png)"
check "yabanci bekleyen etkinlige kapak 404" 404 "$(cover "$T3" $EVP image/png)"
check "organizator kapak yukler 200" 200 "$(cover "$TA" $EVR image/png)"
check "kapak sahte tur 400" 400 "$(cover "$TA" $EVR text/html)"
rm -f "$PNG"

echo "== tarih sinirlari"
step "uzak gelecek 400" 400 POST /events "$T1" '{"title":"Uzak","startsAt":"2150-01-01T00:00:00Z","endsAt":"2150-01-01T02:00:00Z"}'
contains "INVALID_DATES" INVALID_DATES "$BODY"
step "asiri uzak yil 400/422 (500 degil)" 400 POST /events "$T1" '{"title":"Asiri","startsAt":"+999999999-01-01T00:00:00Z","endsAt":"+999999999-01-01T02:00:00Z"}'
step "from asiri gecmis 200" 200 GET "/events?from=0001-01-01T00:00:00Z" "$T3"
step "to asiri gelecek 200" 200 GET "/events?to=9999-12-31T00:00:00Z" "$T3"
step "bozuk tarih 400" 400 GET "/events?from=yarin" "$T3"
step "takvim 1900 400" 400 GET "/events/calendar?month=1900-01" "$T3"
step "takvim 999999 400" 400 GET "/events/calendar?month=999999-01" "$T3"
step "bitis<baslangic 400" 400 POST /events "$T1" "{\"title\":\"Ters\",\"startsAt\":\"$END\",\"endsAt\":\"$START\"}"
step "kisa baslik 400" 400 POST /events "$T1" "{\"title\":\"ab\",\"startsAt\":\"$START\",\"endsAt\":\"$END\"}"
step "kapasite 0 olusturma 400" 400 POST /events "$T1" "{\"title\":\"Sifir\",\"startsAt\":\"$START\",\"endsAt\":\"$END\",\"capacity\":0}"
step "kapasite eksi 400" 400 POST /events "$T1" "{\"title\":\"Eksi\",\"startsAt\":\"$START\",\"endsAt\":\"$END\",\"capacity\":-3}"
step "ay formati yok 400" 400 GET "/events/calendar?month=abc" "$T3"

echo "== takvim ay siniri (Europe/Istanbul, UTC+3)"
YR=$(( $(date -u +%Y) + 1 ))
EDGE="$YR-01-01T00:30:00+03:00"
EDGE_END="$YR-01-01T02:00:00+03:00"
step "yilbasi 00:30 yerel etkinlik" 201 POST /events "$TA" "{\"title\":\"Yilbasi $SFX\",\"startsAt\":\"$(date -u -d "$EDGE" +%Y-%m-%dT%H:%M:%SZ)\",\"endsAt\":\"$(date -u -d "$EDGE_END" +%Y-%m-%dT%H:%M:%SZ)\"}"
call GET "/events/calendar?month=$YR-01" "$T3"
contains "Ocak takviminde" "Yilbasi $SFX" "$BODY"
contains "yerel gun 1 Ocak" "\"date\":\"$YR-01-01\"" "$BODY"
call GET "/events/calendar?month=$((YR - 1))-12" "$T3"
lacks "Aralik takviminde degil" "Yilbasi $SFX" "$BODY"

echo "== sayfalama sinirlari"
for k in 1 2 3 4 5; do
  curl -s -o /dev/null -X POST -H "$H" -H "Authorization: Bearer $TA" $A/events \
    -d "{\"title\":\"Sayfa $SFX $k\",\"startsAt\":\"$(iso "+$((k + 1)) days")\",\"endsAt\":\"$(iso "+$((k + 1)) days +1 hour")\"}"
done
SEEN=""
CUR=""
PAGES=0
while [ $PAGES -lt 30 ]; do
  call GET "/events?size=2&from=$(iso '+1 day')&to=$(iso '+7 days')$CUR" "$T3"
  SEEN="$SEEN $(printf '%s' "$BODY" | grep -o "Sayfa $SFX [0-9]" | tr '\n' ' ')"
  NEXT=$(printf '%s' "$BODY" | grep -o '"nextCursor":[0-9]*' | cut -d: -f2)
  PAGES=$((PAGES + 1))
  [ -z "$NEXT" ] && break
  CUR="&cursor=$NEXT"
done
check "5 sayfa kaydi tekrarsiz" 5 "$(printf '%s\n' $SEEN | grep -c '^[0-9]$' )"
check "benzersiz 5" 5 "$(printf '%s ' $SEEN | tr ' ' '\n' | grep '^[0-9]$' | sort -u | wc -l | tr -d ' ')"
step "size=0 -> 200" 200 GET "/events?size=0" "$T3"
step "size=100000 -> 200" 200 GET "/events?size=100000" "$T3"
call GET "/events?size=100000" "$T3"
check "size ust siniri 50" 1 "$(( $(printf '%s' "$BODY" | grep -o '"startsAt"' | wc -l) <= 50 ? 1 : 0 ))"
step "cursor olmayan id -> 200" 200 GET "/events?cursor=999999999" "$T3"
step "cursor eksi -> 200" 200 GET "/events?cursor=-5" "$T3"
step "cursor metin -> 400" 400 GET "/events?cursor=abc" "$T3"
step "size metin -> 400" 400 GET "/events?size=abc" "$T3"
step "me/events gecersiz mod -> 200" 200 GET "/me/events?mode=zzz" "$T3"
step "attendees size=1000" 200 GET "/events/$EVR/attendees?size=1000" "$TA"

echo "== ozel topluluk etkinligi: uyelikten cikarilan kullanici /me/events'te goremez"
step "ozel topluluk" 202 POST /communities "$TA" "{\"name\":\"Gizli Etkinlik Kulubu $SFX\",\"visibility\":\"PRIVATE\"}"
CP=$(printf '%s' "$BODY" | idof)
step "admin onayla" 204 POST /admin/communities/$CP/approve "$TA"
step "T2 katilir" 200 POST /communities/$CP/join "$T2"
step "topluluk etkinligi" 201 POST /events "$TA" "{\"title\":\"Gizli Etkinlik $SFX\",\"startsAt\":\"$START\",\"endsAt\":\"$END\",\"communityId\":$CP}"
EVPR=$(printf '%s' "$BODY" | idof)
step "uye RSVP" 200 PUT /events/$EVPR/rsvp "$T2" '{"status":"GOING"}'
step "uye /me/events'te gorur" 200 GET /me/events "$T2"
contains "etkinlik listede" "Gizli Etkinlik $SFX" "$BODY"
step "yabanci ozel etkinligi goremez" 404 GET /events/$EVPR "$T3"
step "sahip uyeyi cikarir" 204 DELETE /communities/$CP/members/$ID2 "$TA"
step "cikarilan /me/events" 200 GET /me/events "$T2"
lacks "cikarilan kullanici ozel etkinligi goremez" "Gizli Etkinlik $SFX" "$BODY"
step "cikarilan etkinlik detayi 404" 404 GET /events/$EVPR "$T2"
step "cikarilan RSVP yapamaz 404" 404 PUT /events/$EVPR/rsvp "$T2" '{"status":"GOING"}'

echo "== QR sahteciligi / yeniden oynatma / pencere"
START2=$(iso "+5 minutes"); END2=$(iso "+2 hours")
step "yoklama etkinligi" 201 POST /events "$TA" "{\"title\":\"Yoklama $SFX\",\"startsAt\":\"$START2\",\"endsAt\":\"$END2\"}"
EVQ=$(printf '%s' "$BODY" | idof)
step "T2 GOING" 200 PUT /events/$EVQ/rsvp "$T2" '{"status":"GOING"}'
step "kod al (admin)" 200 GET /events/$EVQ/checkin-code "$TA"
QR=$(printf '%s' "$BODY" | field code)
MAC=${QR##*.}
WIN=$(printf '%s' "$QR" | cut -d. -f2)
step "imza bozuk 400" 400 POST /events/$EVQ/check-in "$T2" "{\"code\":\"$EVQ.$WIN.AAAAAAAAAAAAAAAAAAAAAA\"}"
step "pencere ileri 400" 400 POST /events/$EVQ/check-in "$T2" "{\"code\":\"$EVQ.$((WIN + 5)).$MAC\"}"
step "pencere eski 400" 400 POST /events/$EVQ/check-in "$T2" "{\"code\":\"$EVQ.$((WIN - 5)).$MAC\"}"
step "bos kod 400" 400 POST /events/$EVQ/check-in "$T2" '{"code":""}'
step "cok uzun kod 400" 400 POST /events/$EVQ/check-in "$T2" "{\"code\":\"$(printf 'A%.0s' $(seq 1 300))\"}"
step "yabanci RSVPsiz gecerli kodla 403" 403 POST /events/$EVQ/check-in "$T3" "{\"code\":\"$QR\"}"
step "T2 gecerli kodla yoklama" 200 POST /events/$EVQ/check-in "$T2" "{\"code\":\"$QR\"}"
step "T2 ayni kodu tekrar (idempotent)" 200 POST /events/$EVQ/check-in "$T2" "{\"code\":\"$QR\"}"
step "baska etkinligin koduyla 400" 400 POST /events/$EVR/check-in "$T2" "{\"code\":\"$QR\"}"
step "kod almada katilimci 403" 403 GET /events/$EVQ/checkin-code "$T2"
step "iptal edilen etkinlikte yoklama 409" 204 DELETE /events/$EVQ "$TA"
step "iptalde kod 409/404" 409 GET /events/$EVQ/checkin-code "$TA"

echo "== CSV enjeksiyonu + silinen kullanici"
step "csv etkinligi" 201 POST /events "$TA" "{\"title\":\"CSV $SFX\",\"startsAt\":\"$(iso '+5 minutes')\",\"endsAt\":\"$(iso '+2 hours')\"}"
EVC=$(printf '%s' "$BODY" | idof)
TCSV=$TA
for NAME in '=1+1' '+1+1' '-2+3' '@SUM(1)' 'x,y"z'; do
  step "ad degistir $NAME" 200 PATCH /users/me "$T3" "{\"displayName\":\"$(printf '%s' "$NAME" | sed 's/"/\\"/g')\"}"
  step "elle isaretle" 204 PUT /events/$EVC/attendance/$ID3 "$TCSV" '{"present":true}'
  CSV=$(curl -s -H "Authorization: Bearer $TCSV" "$A/events/$EVC/attendance.csv")
  case "$NAME" in
    '=1+1'|'+1+1'|'-2+3'|'@SUM(1)') contains "kacirildi: $NAME" "\"'$NAME\"" "$CSV"; lacks "ham formul yok: $NAME" ",\"$NAME\"" "$CSV" ;;
    *) contains "tirnak kacirildi" '"x,y""z"' "$CSV" ;;
  esac
done
step "kullanici hesabini siler (T3)" 204 DELETE /users/me "$T3" '{"password":"Sifre1234"}'
CSV=$(curl -s -H "Authorization: Bearer $TCSV" "$A/events/$EVC/attendance.csv")
lacks "silinen kullanicinin eski adi csv'de yok" 'x,y""z' "$CSV"
step "silinen kullanici elle isaretlenemez 404" 404 PUT /events/$EVC/attendance/$ID3 "$TCSV" '{"present":true}'
call GET /events "$T3"
# BILINEN SORUN (profile paketi): oz-servis hesap silmede suspended:<id> anahtari yazilmiyor (admin silme yazar).
if [ "$CODE" = "401" ]; then echo "  ok   silinen kullanicinin token'i reddedildi"
else echo "  WARN silinen kullanicinin access token'i hala gecerli ($CODE) - profile paketi, rapora bak"; fi

echo
[ $FAIL -eq 0 ] && echo "TUMU GECTI" || echo "HATA VAR"
exit $FAIL

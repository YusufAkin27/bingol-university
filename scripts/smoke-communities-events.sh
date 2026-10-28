#!/usr/bin/env bash
# Calisan yigina (docker compose) karsi topluluk + etkinlik + yoklama uctan uca duman testi.
# Kullanim: BASE=http://localhost:8081 ./scripts/smoke-communities-events.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur) ve ADMIN_EMAILS=$ADMIN_EMAIL
# Not: hatirlatma testi ~3 dk surer; atlamak icin SKIP_REMINDER=1.
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0
TMP=$(mktemp)
trap 'rm -f "$TMP" "${RACE:-}" "${PNG:-}"' EXIT

check() { # ad beklenen gercek
  if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi
}
contains() { # ad metin kaynak
  if printf '%s' "$3" | grep -q -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 ('$2' bulunamadi)"; FAIL=1; fi
}
lacks() { # ad metin kaynak
  if printf '%s' "$3" | grep -q -- "$2"; then echo "  FAIL $1 ('$2' beklenmedik sekilde var)"; FAIL=1; else echo "  ok   $1"; fi
}
# call METHOD YOL TOKEN [JSON] -> CODE ve BODY
call() {
  local m=$1 p=$2 t=$3 d=${4:-}
  if [ -n "$d" ]; then
    CODE=$(curl -s -o "$TMP" -w '%{http_code}' -X "$m" -H "$H" -H "Authorization: Bearer $t" "$A$p" -d "$d")
  else
    CODE=$(curl -s -o "$TMP" -w '%{http_code}' -X "$m" -H "Authorization: Bearer $t" "$A$p")
  fi
  BODY=$(cat "$TMP")
}
step() { # ad beklenen METHOD YOL TOKEN [JSON]
  local name=$1 exp=$2; shift 2
  call "$@"
  check "$name" "$exp" "$CODE"
}
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
field() { grep -o "\"$1\":\"[^\"]*" | head -1 | cut -d'"' -f4; }

register() { # email ad
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c tok
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  tok=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Sifre1234\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  if [ -z "$tok" ]; then # hesap onceden varsa giris yap
    tok=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" |
      grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  fi
  echo "$tok"
}
iso() { date -u -d "$1" +%Y-%m-%dT%H:%M:%SZ; }

SFX=$RANDOM
echo "== kullanicilar"
T1=$(register "sahip$SFX@bingol.edu.tr" "Sahip Kisi")
T2=$(register "uye$SFX@bingol.edu.tr" "Uye Kisi")
T3=$(register "yabanci$SFX@bingol.edu.tr" "Yabanci Kisi")
T4=$(register "dorduncu$SFX@bingol.edu.tr" "Dorduncu Kisi")
TA=$(register "$ADMIN_EMAIL" "Yonetici")
[ -n "$T1" ] && [ -n "$T2" ] && [ -n "$T3" ] && [ -n "$T4" ] || { echo "kayit basarisiz"; exit 1; }
[ -n "$TA" ] || { echo "admin token yok (ADMIN_EMAILS ayarli mi?)"; exit 1; }
ID1=$(curl -s -H "Authorization: Bearer $T1" $A/users/me | idof)
ID2=$(curl -s -H "Authorization: Bearer $T2" $A/users/me | idof)
ID3=$(curl -s -H "Authorization: Bearer $T3" $A/users/me | idof)
ID4=$(curl -s -H "Authorization: Bearer $T4" $A/users/me | idof)

echo "== topluluk olusturma ve admin onayi"
NAME="Yazilim Kulubu $SFX"
step "olustur (202)" 202 POST /communities "$T1" "{\"name\":\"$NAME\",\"description\":\"Kod yazanlar\",\"category\":\"teknoloji\"}"
C1=$(printf '%s' "$BODY" | idof)
contains "durum PENDING_REVIEW" '"status":"PENDING_REVIEW"' "$BODY"
contains "slug uretildi" "\"slug\":\"yazilim-kulubu-$SFX\"" "$BODY"
step "gecersiz ad 400" 400 POST /communities "$T1" '{"name":"ab"}'
call GET "/communities?q=$SFX" "$T2"
lacks "onaysiz kesfette gorunmez" "yazilim-kulubu-$SFX" "$BODY"
step "onaysiz detay baskasina 404" 404 GET /communities/$C1 "$T2"
step "onaysiz topluluga katilamaz" 404 POST /communities/$C1/join "$T2"
step "normal kullanici admin ucu 403" 403 GET /admin/communities "$T1"
step "admin bekleyenler" 200 GET /admin/communities "$TA"
contains "bekleyen listede" "yazilim-kulubu-$SFX" "$BODY"
step "admin onayla" 204 POST /admin/communities/$C1/approve "$TA"
step "ikinci onay 409" 409 POST /admin/communities/$C1/approve "$TA"
step "kesfet" 200 GET "/communities?q=$SFX&category=teknoloji" "$T2"
contains "onayli kesfette gorunur" "yazilim-kulubu-$SFX" "$BODY"
step "baslik slug cakisma -> yeni slug" 202 POST /communities "$T1" "{\"name\":\"$NAME\",\"joinPolicy\":\"APPROVAL\"}"
C2=$(printf '%s' "$BODY" | idof)
contains "slug -2" "yazilim-kulubu-$SFX-2" "$BODY"
step "ozel topluluk" 202 POST /communities "$T1" "{\"name\":\"Gizli Kulup $SFX\",\"visibility\":\"PRIVATE\"}"
C3=$(printf '%s' "$BODY" | idof)
step "4. topluluk limiti 409" 409 POST /communities "$T1" '{"name":"Dorduncu Kulup"}'
contains "limit kodu" "COMMUNITY_LIMIT" "$BODY"
step "onay C2" 204 POST /admin/communities/$C2/approve "$TA"
step "onay C3" 204 POST /admin/communities/$C3/approve "$TA"
call GET "/communities?q=Gizli" "$T2"
lacks "PRIVATE kesfette yok" "Gizli Kulup $SFX" "$BODY"

echo "== katilma, roller, istekler"
step "detay (uye degil)" 200 GET /communities/$C1 "$T2"
contains "myStatus NONE" '"myStatus":"NONE"' "$BODY"
step "OPEN katil -> ACTIVE" 200 POST /communities/$C1/join "$T2"
contains "ACTIVE" '"status":"ACTIVE"' "$BODY"
step "tekrar katil 409" 409 POST /communities/$C1/join "$T2"
step "detay uye sayisi" 200 GET /communities/$C1 "$T1"
contains "uye sayisi 2" '"memberCount":2' "$BODY"
step "sahip ayrilamaz 409" 409 DELETE /communities/$C1/membership "$T1"
step "APPROVAL katil -> PENDING" 200 POST /communities/$C2/join "$T3"
contains "PENDING" '"status":"PENDING"' "$BODY"
step "istekler (uye degil) 403" 403 GET /communities/$C2/requests "$T3"
step "istekler (sahip)" 200 GET /communities/$C2/requests "$T1"
contains "istek veli" "\"userId\":$ID3" "$BODY"
step "istegi onayla" 204 POST /communities/$C2/requests/$ID3/approve "$T1"
step "onayli uye detay" 200 GET /communities/$C2 "$T3"
contains "artik ACTIVE" '"myStatus":"ACTIVE"' "$BODY"
step "var olmayan istek 404" 404 POST /communities/$C2/requests/$ID4/reject "$T1"
step "mehmet katil" 200 POST /communities/$C2/join "$T4"
step "istegi reddet" 204 POST /communities/$C2/requests/$ID4/reject "$T1"
step "rol: uye atayamaz 403" 403 PUT /communities/$C1/members/$ID2/role "$T2" '{"role":"MODERATOR"}'
step "rol: OWNER atanamaz 400" 400 PUT /communities/$C1/members/$ID2/role "$T1" '{"role":"OWNER"}'
step "rol: moderator ata" 204 PUT /communities/$C1/members/$ID2/role "$T1" '{"role":"MODERATOR"}'
step "moderator bilgi gunceller" 200 PATCH /communities/$C1 "$T2" '{"description":"Yeni aciklama"}'
step "uye (T3) bilgi guncelleyemez" 403 PATCH /communities/$C1 "$T3" '{"description":"x"}'
PNG="$(mktemp --suffix=.png)"; cp "$(dirname "$0")/fixtures/media/tiny.png" "$PNG"  # gercek (kucuk) PNG: medya hatti sahte dosyayi reddeder
PNGW=$(cygpath -m "$PNG" 2>/dev/null || echo "$PNG")
CODE=$(curl -s -o "$TMP" -w '%{http_code}' -X POST -H "Authorization: Bearer $T1" -F "file=@$PNGW;type=image/png" $A/communities/$C1/cover)
check "kapak yukle" 200 "$CODE"
COVER=$(cat "$TMP" | field coverUrl)
check "kapak dosyasi servis" 200 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE$COVER")"
check "uye (T3) kapak yukleyemez" 403 "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "Authorization: Bearer $T3" -F "file=@$PNGW;type=image/png" $A/communities/$C1/cover)"

echo "== topluluk akisi"
step "uye olmayan paylasamaz" 403 POST /communities/$C1/posts "$T3" '{"text":"selam"}'
step "uye paylasir" 201 POST /communities/$C1/posts "$T2" "{\"text\":\"Ilk gonderi $SFX\"}"
P1=$(printf '%s' "$BODY" | idof)
step "yabanci gorsel adresi 400" 400 POST /communities/$C1/posts "$T2" '{"text":"x","imageUrl":"https://evil.example/a.png"}'
step "bos metin 400" 400 POST /communities/$C1/posts "$T2" '{"text":""}'
step "sahip paylasir" 201 POST /communities/$C1/posts "$T1" '{"text":"Duyuru"}'
P2=$(printf '%s' "$BODY" | idof)
step "akis" 200 GET /communities/$C1/posts "$T1"
contains "akista gonderi" "Ilk gonderi $SFX" "$BODY"
step "sabitle" 204 PUT /communities/$C1/posts/$P2/pin "$T1"
step "uye olmayan sabitleyemez" 403 PUT /communities/$C1/posts/$P1/pin "$T3"
step "baskasinin yazisini silemez" 403 DELETE /communities/$C1/posts/$P2 "$T3"
step "PRIVATE akis uye olmayana 403" 403 GET /communities/$C3/posts "$T3"
step "PRIVATE uyeler uye olmayana 403" 403 GET /communities/$C3/members "$T3"
step "rapor (POST)" 201 POST /reports "$T3" "{\"targetType\":\"POST\",\"targetId\":$P1,\"reason\":\"SPAM\"}"
step "rapor (COMMUNITY)" 201 POST /reports "$T3" "{\"targetType\":\"COMMUNITY\",\"targetId\":$C1,\"reason\":\"SPAM\"}"

echo "== engelleme"
step "sahip uyeyi engeller" 204 POST /users/$ID2/block "$T1"
step "akis" 200 GET /communities/$C1/posts "$T1"
lacks "engelli yazar akista yok" "Ilk gonderi $SFX" "$BODY"
step "uye listesi" 200 GET /communities/$C1/members "$T1"
lacks "engelli uye listede yok" "\"userId\":$ID2," "$BODY"
step "engeli kaldir" 204 DELETE /users/$ID2/block "$T1"
step "akis (engel kalkti)" 200 GET /communities/$C1/posts "$T1"
contains "yazar yine gorunur" "Ilk gonderi $SFX" "$BODY"

echo "== uyeyi cikar / yasakla"
step "moderator sahibi cikaramaz" 403 DELETE /communities/$C1/members/$ID1 "$T2"
step "kendini cikaramaz" 400 DELETE /communities/$C1/members/$ID2 "$T2"
step "yasakla (T3 C2'de)" 204 DELETE "/communities/$C2/members/$ID3?ban=true" "$T1"
step "yasakli tekrar katilamaz" 403 POST /communities/$C2/join "$T3"
contains "BANNED kodu" "BANNED" "$BODY"
step "yasakli ayrilarak kurtulamaz" 403 DELETE /communities/$C2/membership "$T3"
step "ben topluluklarim" 200 GET /me/communities "$T2"
contains "T2 C1'de" "\"id\":$C1" "$BODY"
step "uye ayrilir" 204 DELETE /communities/$C1/membership "$T2"
step "tekrar katil" 200 POST /communities/$C1/join "$T2"
step "yeniden moderator" 204 PUT /communities/$C1/members/$ID2/role "$T1" '{"role":"MODERATOR"}'

echo "== etkinlik dogrulamalari ve onay akisi"
START=$(iso "+10 minutes"); END=$(iso "+2 hours")
PAST=$(iso "-3 hours"); PAST_END=$(iso "-2 hours")
step "gecmis etkinlik 400" 400 POST /events "$T1" "{\"title\":\"Eski\",\"startsAt\":\"$PAST\",\"endsAt\":\"$PAST_END\"}"
contains "PAST_EVENT" "PAST_EVENT" "$BODY"
step "bitis<=baslangic 400" 400 POST /events "$T1" "{\"title\":\"Ters\",\"startsAt\":\"$END\",\"endsAt\":\"$START\"}"
contains "INVALID_DATES" "INVALID_DATES" "$BODY"
step "uye olmayan topluluk etkinligi 403" 403 POST /events "$T3" "{\"title\":\"Izinsiz\",\"startsAt\":\"$START\",\"endsAt\":\"$END\",\"communityId\":$C1}"
step "bagimsiz etkinlik -> 202" 202 POST /events "$T3" "{\"title\":\"Bagimsiz Soylesi $SFX\",\"startsAt\":\"$START\",\"endsAt\":\"$END\",\"capacity\":10}"
EV_IND=$(printf '%s' "$BODY" | idof)
contains "PENDING_REVIEW" '"status":"PENDING_REVIEW"' "$BODY"
step "onaysiz etkinlik baskasina 404" 404 GET /events/$EV_IND "$T4"
step "onaysiz etkinlige RSVP olmaz" 404 PUT /events/$EV_IND/rsvp "$T4" '{"status":"GOING"}'
step "admin bekleyen etkinlikler" 200 GET /admin/events "$TA"
contains "bekleyen etkinlik listede" "Bagimsiz Soylesi $SFX" "$BODY"
step "admin onayla" 204 POST /admin/events/$EV_IND/approve "$TA"
step "etkinlik gorunur" 200 GET /events/$EV_IND "$T4"
contains "ACTIVE" '"status":"ACTIVE"' "$BODY"
step "reddedilecek etkinlik" 202 POST /events "$T3" "{\"title\":\"Reddedilecek $SFX\",\"startsAt\":\"$START\",\"endsAt\":\"$END\"}"
EV_REJ=$(printf '%s' "$BODY" | idof)
step "admin reddet" 204 POST /admin/events/$EV_REJ/reject "$TA" '{"reason":"uygun degil"}'
step "tekrar reddet 409" 409 POST /admin/events/$EV_REJ/reject "$TA"

echo "== topluluk etkinligi, RSVP, kapasite"
step "moderator topluluk etkinligi (201)" 201 POST /events "$T2" "{\"title\":\"Hackathon $SFX\",\"description\":\"24 saat\",\"startsAt\":\"$START\",\"endsAt\":\"$END\",\"location\":\"Salon A\",\"capacity\":2,\"communityId\":$C1}"
EV=$(printf '%s' "$BODY" | idof)
contains "ACTIVE (onaysiz yayinda)" '"status":"ACTIVE"' "$BODY"
step "liste" 200 GET "/events?communityId=$C1" "$T4"
contains "listede etkinlik" "Hackathon $SFX" "$BODY"
step "from/to filtresi" 200 GET "/events?from=$(iso '-1 hour')&to=$(iso '+1 day')" "$T4"
contains "aralikta etkinlik" "Hackathon $SFX" "$BODY"
step "from/to disinda" 200 GET "/events?from=$(iso '+30 days')" "$T4"
lacks "gelecek aralikta yok" "Hackathon $SFX" "$BODY"
step "RSVP sahip GOING" 200 PUT /events/$EV/rsvp "$T1" '{"status":"GOING"}'
step "RSVP uye GOING" 200 PUT /events/$EV/rsvp "$T2" '{"status":"GOING"}'
contains "goingCount 2" '"goingCount":2' "$BODY"
step "kapasite dolu 409" 409 PUT /events/$EV/rsvp "$T4" '{"status":"GOING"}'
contains "EVENT_FULL" "EVENT_FULL" "$BODY"
step "doluyken INTERESTED olur" 200 PUT /events/$EV/rsvp "$T4" '{"status":"INTERESTED"}'
step "INTERESTED -> GOING dolu 409" 409 PUT /events/$EV/rsvp "$T4" '{"status":"GOING"}'
step "gecersiz RSVP 400" 400 PUT /events/$EV/rsvp "$T4" '{"status":"MAYBE"}'
step "detay" 200 GET /events/$EV "$T1"
contains "myRsvp GOING" '"myRsvp":"GOING"' "$BODY"
contains "canManage" '"canManage":true' "$BODY"
contains "katilimci 2 / kapasite 2" '"capacity":2' "$BODY"
step "GOING vazgec" 204 DELETE /events/$EV/rsvp "$T1"
step "bosalan yere T4 GOING" 200 PUT /events/$EV/rsvp "$T4" '{"status":"GOING"}'
step "T1 geri GOING dolu 409" 409 PUT /events/$EV/rsvp "$T1" '{"status":"GOING"}'
step "T1 vazgec (yok) yine 204" 204 DELETE /events/$EV/rsvp "$T1"
step "katilimcilar (organizator)" 200 GET /events/$EV/attendees "$T2"
contains "katilimci T4" "\"userId\":$ID4" "$BODY"
step "katilimcilar (yabanci) 403" 403 GET /events/$EV/attendees "$T3"
step "kapasite altina guncelleme 409" 409 PATCH /events/$EV "$T2" '{"capacity":1}'
step "yabanci guncelleyemez 403" 403 PATCH /events/$EV "$T3" '{"title":"Hack"}'
step "organizator gunceller" 200 PATCH /events/$EV "$T2" '{"description":"36 saat"}'

echo "== kapasite yarisi (4 es zamanli istek, kapasite 1)"
step "dar kapasiteli etkinlik" 201 POST /events "$TA" "{\"title\":\"Yaris $SFX\",\"startsAt\":\"$START\",\"endsAt\":\"$END\",\"capacity\":1}"
EV_RACE=$(printf '%s' "$BODY" | idof)
RACE=$(mktemp)
# Her istek kendi dosyasina yazar (ortak dosyaya es zamanli ekleme Windows'ta satir kaybettirebilir)
n=0
for t in "$T1" "$T2" "$T3" "$T4"; do
  n=$((n + 1))
  ( curl -s -o /dev/null -w '%{http_code}\n' -X PUT -H "$H" -H "Authorization: Bearer $t" $A/events/$EV_RACE/rsvp -d '{"status":"GOING"}' > "$RACE.$n" ) &
done
wait
cat "$RACE".? > "$RACE"
rm -f "$RACE".?
echo "  yanit kodlari: $(sort "$RACE" | tr '\n' ' ')"
check "tam 1 basarili" 1 "$(grep -c '^200$' "$RACE")"
check "3 EVENT_FULL" 3 "$(grep -c '^409$' "$RACE")"
call GET /events/$EV_RACE "$TA"
contains "goingCount 1" '"goingCount":1' "$BODY"

echo "== QR yoklama"
step "kod: katilimci alamaz 403" 403 GET /events/$EV/checkin-code "$T4"
step "kod: organizator alir" 200 GET /events/$EV/checkin-code "$T2"
QR=$(printf '%s' "$BODY" | field code)
contains "qrPayload" "bingol-checkin:" "$BODY"
step "RSVP'siz okutamaz 403" 403 POST /events/$EV/check-in "$T3" "{\"code\":\"$QR\"}"
contains "NOT_RSVPED" "NOT_RSVPED" "$BODY"
step "INTERESTED okutamaz (T1 vazgecti)" 403 POST /events/$EV/check-in "$T1" "{\"code\":\"$QR\"}"
step "sahte kod 400" 400 POST /events/$EV/check-in "$T4" '{"code":"1.2.AAAAAAAAAAAAAAAAAAAAAA"}'
contains "INVALID_CODE" "INVALID_CODE" "$BODY"
step "baska etkinligin kodu 400" 400 POST /events/$EV/check-in "$T4" "{\"code\":\"$(printf '%s' "$QR" | sed "s/^$EV\./$((EV+9999))./")\"}"
step "QR yoklama (T4)" 200 POST /events/$EV/check-in "$T4" "{\"code\":\"$QR\"}"
contains "present true" '"present":true' "$BODY"
contains "yontem QR" '"method":"QR"' "$BODY"
step "tekrar okut idempotent" 200 POST /events/$EV/check-in "$T4" "{\"code\":\"$QR\"}"
contains "hala present" '"present":true' "$BODY"
step "my-attendance (T4)" 200 GET /events/$EV/my-attendance "$T4"
contains "my present" '"present":true' "$BODY"
step "my-attendance (T3 kayitsiz)" 200 GET /events/$EV/my-attendance "$T3"
lacks "T3 present degil" '"present":true' "$BODY"
FUT=$(iso "+7 days"); FUT_END=$(iso "+7 days +2 hours")
step "gelecek etkinlik" 201 POST /events "$TA" "{\"title\":\"Haftaya $SFX\",\"startsAt\":\"$FUT\",\"endsAt\":\"$FUT_END\"}"
EV_FUT=$(printf '%s' "$BODY" | idof)
step "pencere kapali: kod 409" 409 GET /events/$EV_FUT/checkin-code "$TA"
contains "CHECKIN_CLOSED" "CHECKIN_CLOSED" "$BODY"
step "gelecek etkinlige RSVP" 200 PUT /events/$EV_FUT/rsvp "$T4" '{"status":"GOING"}'
step "pencere kapali okutma 409" 409 POST /events/$EV_FUT/check-in "$T4" "{\"code\":\"$QR\"}"

echo "== elle yoklama"
step "liste (yabanci) 403" 403 GET /events/$EV/attendance "$T3"
step "liste (organizator)" 200 GET /events/$EV/attendance "$T2"
contains "T4 QR ile gelmis" '"method":"QR"' "$BODY"
contains "T4 satiri" "\"userId\":$ID4" "$BODY"
step "elle isaretle: yabanci 403" 403 PUT /events/$EV/attendance/$ID4 "$T3" '{"present":true}'
step "elle isaretle: yok yaz" 204 PUT /events/$EV/attendance/$ID4 "$T2" '{"present":false}'
step "listede yok + MANUAL" 200 GET /events/$EV/attendance "$T2"
contains "MANUAL" '"method":"MANUAL"' "$BODY"
step "QR ile gelmemis (T3) elle ekle" 204 PUT /events/$EV/attendance/$ID3 "$T2" '{"present":true}'
step "toplu isaretle" 200 POST /events/$EV/attendance/bulk "$T2" "{\"entries\":[{\"userId\":$ID4,\"present\":true},{\"userId\":$ID3,\"present\":false}]}"
contains "2 guncellendi" '"updated":2' "$BODY"
step "toplu bos liste 400" 400 POST /events/$EV/attendance/bulk "$T2" '{"entries":[]}'
step "toplu bilinmeyen kullanici 404" 404 POST /events/$EV/attendance/bulk "$T2" '{"entries":[{"userId":999999999,"present":true}]}'
step "my-attendance elle yazildi" 200 GET /events/$EV/my-attendance "$T4"
contains "isaretleyen elle present" '"present":true' "$BODY"
CODE=$(curl -s -D "$TMP.h" -o "$TMP" -w '%{http_code}' -H "Authorization: Bearer $T2" "$A/events/$EV/attendance.csv")
check "csv indir" 200 "$CODE"
CSV=$(cat "$TMP")
contains "csv baslik" "userId,name,department" "$CSV"
contains "csv content-type" "text/csv" "$(cat "$TMP.h")"
rm -f "$TMP.h"
check "csv yabanci 403" 403 "$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $T3" "$A/events/$EV/attendance.csv")"
# CSV enjeksiyonu: formul gibi baslayan ad kacirilir
step "ad degistir (formul)" 200 PATCH /users/me "$T3" '{"displayName":"=1+1"}'
step "formul adli kisi elle ekle" 204 PUT /events/$EV/attendance/$ID3 "$T2" '{"present":true}'
CSV=$(curl -s -H "Authorization: Bearer $T2" "$A/events/$EV/attendance.csv")
contains "formul kacirildi" "\"'=1+1\"" "$CSV"
lacks "kacirilmamis formul yok" ",\"=1+1\"" "$CSV"

echo "== takvim, benim etkinliklerim"
MONTH=$(date -u -d "+10 minutes" +%Y-%m)
step "takvim" 200 GET "/events/calendar?month=$MONTH" "$T4"
contains "kullanici etkinligi USER" '"source":"USER"' "$BODY"
contains "takvimde Hackathon" "Hackathon $SFX" "$BODY"
step "takvim gecersiz ay 400" 400 GET "/events/calendar?month=2026-13" "$T4"
step "takvim ay yok 400" 400 GET "/events/calendar" "$T4"
step "benim etkinliklerim (katilacagim)" 200 GET /me/events "$T4"
contains "katilacagim" "Hackathon $SFX" "$BODY"
step "benim etkinliklerim (duzenledigim)" 200 GET "/me/events?mode=organizing" "$T2"
contains "duzenledigim" "Hackathon $SFX" "$BODY"

echo "== iptal / silme"
step "yabanci silemez 403" 403 DELETE /events/$EV "$T3"
step "organizator siler" 204 DELETE /events/$EV "$T2"
step "silinen etkinlik yabancida 404" 404 GET /events/$EV "$T3"
step "silinen listede yok" 200 GET "/events?communityId=$C1" "$T4"
lacks "silinen etkinlik listede yok" "Hackathon $SFX" "$BODY"

if [ "${SKIP_REMINDER:-0}" != "1" ]; then
  echo "== hatirlatma (zamanlayici ~1 dk'da bir calisir)"
  step "yakin etkinlik" 201 POST /events "$TA" "{\"title\":\"Yakin Etkinlik $SFX\",\"startsAt\":\"$(iso '+20 minutes')\",\"endsAt\":\"$(iso '+3 hours')\"}"
  EV_R=$(printf '%s' "$BODY" | idof)
  step "RSVP GOING" 200 PUT /events/$EV_R/rsvp "$T4" '{"status":"GOING"}'
  FOUND=0
  for i in $(seq 1 24); do
    call GET /notifications "$T4"
    if printf '%s' "$BODY" | grep -q 'saat'; then FOUND=1; break; fi
    sleep 5
  done
  check "1 saat kala hatirlatma geldi" 1 "$FOUND"
  sleep 70
  call GET /notifications "$T4"
  check "hatirlatma tekrar gitmedi" 1 "$(printf '%s' "$BODY" | grep -o 'saat' | wc -l | tr -d ' ')"
fi

echo
[ $FAIL -eq 0 ] && echo "TUMU GECTI" || echo "HATA VAR"
exit $FAIL

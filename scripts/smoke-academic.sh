#!/usr/bin/env bash
# Akademik modul (ders programi, sinavlar, akademik takvim, bolum duyurulari) icin uctan uca duman testi.
# Kullanim: ADMIN_PASSWORD=... BASE=http://localhost:8080 ./scripts/smoke-academic.sh
# Onkosul: compose'ta MAIL_ENABLED=false (dogrulama kodu log'dan okunur); ADMIN_PASSWORD .env ile ayni.
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
ADMIN_PASSWORD=${ADMIN_PASSWORD:-}
FAIL=0

check() { # ad beklenen gercek
  if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi
}
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
jid() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
has() { # ad metin gövde
  if echo "$3" | grep -q "$2"; then echo "  ok   $1"; else echo "  FAIL $1 ($3)"; FAIL=1; fi
}

register() { # email ad
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4
}

SFX=$RANDOM
TA=$(register "acda$SFX@bingol.edu.tr" "Akademik Bir")
TB=$(register "acdb$SFX@bingol.edu.tr" "Akademik Iki")
[ -n "$TA" ] && [ -n "$TB" ] || { echo "kayit basarisiz"; exit 1; }
AA="Authorization: Bearer $TA"
AB="Authorization: Bearer $TB"
ADM="admin:$ADMIN_PASSWORD"

echo "== yetki"
check "girissiz timetable 401" 401 "$(code $A/timetable)"
check "girissiz duyuru 401" 401 "$(code $A/announcements)"
check "kullanici admin ucu 403" 403 "$(code -H "$AA" $A/admin/announcements)"

echo "== ders programi"
R=$(curl -s -X POST -H "$AA" -H "$H" $A/timetable/courses -d '{"name":"Veri Yapilari","code":"BIL201","instructor":"Dr. Ayse","color":"blue","sessions":[{"dayOfWeek":1,"start":"09:00","end":"10:50","room":"B-204"},{"dayOfWeek":3,"start":"13:00","end":"14:50","room":"Lab"}]}')
CID=$(echo "$R" | jid)
[ -n "$CID" ] || { echo "  FAIL ders olusmadi: $R"; exit 1; }
has "iki oturum" '"dayOfWeek":3' "$R"
check "kisa biçim 201" 201 "$(code -X POST -H "$AA" -H "$H" $A/timetable/courses -d '{"name":"Kimya","dayOfWeek":2,"startTime":"09:00","endTime":"10:00"}')"
check "cakisma 409" 409 "$(code -X POST -H "$AA" -H "$H" $A/timetable/courses -d '{"name":"Fizik","dayOfWeek":1,"startTime":"10:00","endTime":"11:00"}')"
check "force 201" 201 "$(code -X POST -H "$AA" -H "$H" $A/timetable/courses -d '{"name":"Fizik","dayOfWeek":1,"startTime":"10:00","endTime":"11:00","force":true}')"
check "gun 8 422" 422 "$(code -X POST -H "$AA" -H "$H" $A/timetable/courses -d '{"name":"X","dayOfWeek":8,"startTime":"09:00","endTime":"10:00"}')"
check "saat sirasi 422" 422 "$(code -X POST -H "$AA" -H "$H" $A/timetable/courses -d '{"name":"X","dayOfWeek":4,"startTime":"11:00","endTime":"10:00"}')"
check "baska kullanici ders goremez" 0 "$(curl -s -H "$AB" $A/timetable | grep -c 'Veri Yapilari')"
check "baskasinin dersi 404" 404 "$(code -X PATCH -H "$AB" -H "$H" $A/timetable/courses/$CID -d '{"name":"Z"}')"
check "patch" 200 "$(code -X PATCH -H "$AA" -H "$H" $A/timetable/courses/$CID -d '{"instructor":"Prof. Veli"}')"
check "today" 200 "$(code -H "$AA" $A/timetable/today)"
check "week" 200 "$(code -H "$AA" $A/timetable/week)"
check "reminders" 200 "$(code -H "$AA" "$A/timetable/reminders?days=7")"
ICS=$(curl -s -H "$AA" $A/timetable/export.ics)
has "ics VTIMEZONE" 'VTIMEZONE' "$ICS"
has "ics RRULE" 'RRULE:FREQ=WEEKLY' "$ICS"
IMP=$(curl -s -X POST -H "$AB" -H "$H" $A/timetable/import -d '{"courses":[{"name":"A","sessions":[{"dayOfWeek":1,"start":"08:00","end":"09:00"}]},{"name":"B","sessions":[{"dayOfWeek":2,"start":"08:00","end":"09:00"}]}]}')
has "import created 2" '"created":2' "$IMP"

echo "== donemler"
S=$(curl -s -X POST -H "$AA" -H "$H" $A/timetable/semesters -d '{"name":"Guz","startDate":"2026-09-14","endDate":"2027-01-15","current":true}')
has "donem current" '"current":true' "$S"
check "donem tarih 422" 422 "$(code -X POST -H "$AA" -H "$H" $A/timetable/semesters -d '{"name":"X","startDate":"2027-01-15","endDate":"2026-09-14"}')"
check "resmi donem yok 404 ya da 201" 1 "$( [ "$(code -X POST -H "$AB" $A/timetable/semesters/from-official)" = 404 ] || [ "$(code -X POST -H "$AB" $A/timetable/semesters/from-official)" = 201 ] && echo 1 || echo 0)"

echo "== sinavlar"
E=$(curl -s -X POST -H "$AA" -H "$H" $A/timetable/exams -d "{\"courseId\":$CID,\"title\":\"Vize 1\",\"type\":\"VIZE\",\"startsAt\":\"2099-11-10T10:00\"}")
EID=$(echo "$E" | jid)
[ -n "$EID" ] || { echo "  FAIL sinav olusmadi: $E"; FAIL=1; }
has "sinav offset" '+03:00' "$E"
check "sinav turu 422" 422 "$(code -X POST -H "$AA" -H "$H" $A/timetable/exams -d '{"title":"X","type":"ZZZ","startsAt":"2099-11-10T10:00"}')"
check "upcoming" 200 "$(code -H "$AA" "$A/timetable/exams/upcoming?days=30")"
check "baskasi siler 404" 404 "$(code -X DELETE -H "$AB" $A/timetable/exams/$EID)"
check "resmi sinavlar" 200 "$(code -H "$AA" $A/exams/official)"
check "sinav sil" 204 "$(code -X DELETE -H "$AA" $A/timetable/exams/$EID)"

echo "== akademik takvim"
EV=$(curl -s -u "$ADM" -X POST -H "$H" $A/admin/academic/events -d '{"kind":"VIZE","title":"Vize haftasi","startsAt":"2099-11-09","endsAt":"2099-11-13","allDay":true,"published":true}')
EVID=$(echo "$EV" | jid)
[ -n "$EVID" ] || { echo "  FAIL takvim olusmadi: $EV"; FAIL=1; }
check "takvim kullanici yazamaz 403" 403 "$(code -X POST -H "$AA" -H "$H" $A/admin/academic/events -d '{}')"
has "takvim ay" 'Vize haftasi' "$(curl -s -H "$AA" "$A/academic/calendar?month=2099-11")"
has "takvim sirada" 'Vize haftasi' "$(curl -s -H "$AA" "$A/academic/calendar/next?limit=20")"
check "takvim aralik 422" 422 "$(code -H "$AA" "$A/academic/calendar?from=2020-01-01&to=2030-01-01")"
check "yayindan kaldir" 200 "$(code -u "$ADM" -X POST $A/admin/academic/events/$EVID/unpublish)"
check "kaldirilan gorunmez" 0 "$(curl -s -H "$AA" "$A/academic/calendar?month=2099-11" | grep -c 'Vize haftasi')"
IMPE=$(curl -s -u "$ADM" -X POST -H "$H" $A/admin/academic/events/import -d '{"text":"TATIL;Ara tatil;2099-12-01;2099-12-03\nXXX;Hatali;2099-01-01","publish":true}')
has "takvim import 1 + hata" '"created":1' "$IMPE"
check "takvim sil" 204 "$(code -u "$ADM" -X DELETE $A/admin/academic/events/$EVID)"

echo "== duyurular"
N1=$(curl -s -u "$ADM" -X POST -H "$H" $A/admin/announcements -d '{"title":"Genel duyuru","body":"Herkese","pinned":false}')
NID=$(echo "$N1" | jid)
[ -n "$NID" ] || { echo "  FAIL duyuru olusmadi: $N1"; exit 1; }
N2=$(curl -s -u "$ADM" -X POST -H "$H" $A/admin/announcements -d '{"title":"Baska bolum","body":"Gelmez","department":"Yok Boyle Bir Bolum"}')
NID2=$(echo "$N2" | jid)
N3=$(curl -s -u "$ADM" -X POST -H "$H" $A/admin/announcements -d '{"title":"Sabit duyuru","body":"Ustte","pinned":true}')
check "http ek 422" 422 "$(code -u "$ADM" -X POST -H "$H" $A/admin/announcements -d '{"title":"x","body":"y","attachmentUrl":"http://x.com/a"}')"
check "bos baslik 422" 422 "$(code -u "$ADM" -X POST -H "$H" $A/admin/announcements -d '{"title":" ","body":"y"}')"
F=$(curl -s -H "$AA" "$A/announcements?scope=mine&size=20")
has "mine genel var" 'Genel duyuru' "$F"
check "mine baska bolum yok" 0 "$(echo "$F" | grep -c 'Baska bolum')"
has "all baska bolum var" 'Baska bolum' "$(curl -s -H "$AA" "$A/announcements?scope=all")"
check "sabit ilk" 1 "$(echo "$F" | grep -o '"title":"[^"]*' | head -1 | grep -c 'Sabit duyuru')"
P1=$(curl -s -H "$AA" "$A/announcements?scope=all&size=1")
CUR=$(echo "$P1" | grep -o '"nextCursor":"[^"]*' | cut -d'"' -f4)
[ -n "$CUR" ] && echo "  ok   nextCursor" || { echo "  FAIL nextCursor yok: $P1"; FAIL=1; }
check "bozuk imlec 422" 422 "$(code -H "$AA" "$A/announcements?cursor=bozuk")"
U1=$(curl -s -H "$AB" $A/announcements/unread-count | grep -o '"count":[0-9]*' | cut -d: -f2)
check "okunmamis >= 2" 1 "$([ "${U1:-0}" -ge 2 ] && echo 1 || echo 0)"
check "detay" 200 "$(code -H "$AB" $A/announcements/$NID)"
U2=$(curl -s -H "$AB" $A/announcements/unread-count | grep -o '"count":[0-9]*' | cut -d: -f2)
check "okununca azalir" 1 "$([ "${U2:-0}" -lt "${U1:-0}" ] && echo 1 || echo 0)"
check "read idempotent" 204 "$(code -X POST -H "$AB" $A/announcements/$NID/read)"
check "read-all" 204 "$(code -X POST -H "$AB" $A/announcements/read-all)"
has "okunmamis 0" '"count":0' "$(curl -s -H "$AB" $A/announcements/unread-count)"
check "olmayan duyuru 404" 404 "$(code -H "$AB" $A/announcements/999999999)"
check "hedef kitle sayisi" 200 "$(code -u "$ADM" "$A/admin/announcements/audience-count?department=Yok")"
check "yayindan kaldir -> 404" 404 "$(curl -s -o /dev/null -u "$ADM" -X POST $A/admin/announcements/$NID/unpublish -w '%{http_code}' >/dev/null; code -H "$AB" $A/announcements/$NID)"
check "admin liste" 200 "$(code -u "$ADM" "$A/admin/announcements?status=all")"
check "admin sil" 204 "$(code -u "$ADM" -X DELETE $A/admin/announcements/$NID)"
[ -n "${NID2:-}" ] && code -u "$ADM" -X DELETE $A/admin/announcements/$NID2 >/dev/null

echo "== KVKK export"
has "export timetable" '"timetable"' "$(curl -s -H "$AA" $A/users/me/export)"

echo
[ "$FAIL" = 0 ] && echo "TUM KONTROLLER GECTI" || { echo "BAZI KONTROLLER BASARISIZ"; exit 1; }

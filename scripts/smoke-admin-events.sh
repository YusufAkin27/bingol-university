#!/usr/bin/env bash
# Yonetici etkinlik derin yonetimi (P07) icin uctan uca duman testi: yetki, basvuru listesi + zorla kabul (kapasite asilamaz),
# yoklama listesi/duzeltme, sertifika uclari, anonim geri bildirim, duyuru kaydi, duzenleyen korumasi, CSV (maskeli e-posta,
# formul kacisi), toplu islem (kismi basari) ve denetim kaydi.
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ./scripts/smoke-admin-events.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur), ADMIN_EMAILS=$ADMIN_EMAIL, calisan postgres/redis konteynerleri.
# Idempotent: her calistirmada benzersiz kullanicilar/etkinlikler; sebep zorunlulugu (X-Admin-Reason) aciktir.
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
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

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
iso() { date -u -d "$1" +%Y-%m-%dT%H:%M:%SZ; }

SFX=$RANDOM
EU1="evp1x$SFX@bingol.edu.tr"; EU2="evp2x$SFX@bingol.edu.tr"; EU3="evp3x$SFX@bingol.edu.tr"
R='X-Admin-Reason: duman testi sebebi'

echo "== kullanicilar"
TA=$(register "$ADMIN_EMAIL" "Yonetici")
T1=$(register "$EU1" "Sahip Smoke")
T2=$(register "$EU2" "Basvuran Bir")
T3=$(register "$EU3" "Basvuran Iki")
[ -n "$TA" ] && [ -n "$T1" ] && [ -n "$T2" ] && [ -n "$T3" ] || { echo "token yok"; exit 1; }
AAD="Authorization: Bearer $TA"
U1=$(curl -s -H "Authorization: Bearer $T1" $A/users/me | idof)
U2=$(curl -s -H "Authorization: Bearer $T2" $A/users/me | idof)
U3=$(curl -s -H "Authorization: Bearer $T3" $A/users/me | idof)

echo "== etkinlik (istekle katilim, kapasite 1)"
S1=$(iso "+2 days"); E1=$(iso "+2 days +2 hours")
EV=$(curl -s -X POST -H "$H" -H "Authorization: Bearer $T1" $A/events \
  -d "{\"title\":\"Duman Etkinligi $SFX\",\"description\":\"p07\",\"startsAt\":\"$S1\",\"endsAt\":\"$E1\",\"location\":\"Salon\",\"capacity\":1,\"joinPolicy\":\"APPROVAL\"}")
EID=$(echo "$EV" | idof)
[ -n "$EID" ] || { echo "etkinlik olusmadi: $EV"; exit 1; }
# onay gerekiyorsa yonetici onaylar (gerekmiyorsa 409 NOT_PENDING gelir, sorun degil)
curl -s -o /dev/null -X POST -H "$AAD" -H "$H" -H "$R" $A/admin/events/$EID/approve
curl -s -o /dev/null -X POST -H "$H" -H "Authorization: Bearer $T2" $A/events/$EID/applications -d '{"note":"=1+1"}'
curl -s -o /dev/null -X POST -H "$H" -H "Authorization: Bearer $T3" $A/events/$EID/applications -d '{"note":"merhaba"}'

echo "== yetki: anonim 401, normal kullanici 403"
for p in applications attendance certificates feedback announcements organizers attendance.csv applications.csv; do
  check "anonim $p" 401 "$(code $A/admin/events/$EID/$p)"
  check "kullanici $p" 403 "$(code -H "Authorization: Bearer $T2" $A/admin/events/$EID/$p)"
done
check "anonim export.csv" 401 "$(code $A/admin/events/export.csv)"
check "kullanici bulk" 403 "$(code -X POST -H "$H" -H "Authorization: Bearer $T2" $A/admin/events/bulk -d '{"action":"HIDE","ids":[1],"reason":"x"}')"

echo "== basvurular (maskeli e-posta, kapasite ozeti)"
AP=$(curl -s -H "$AAD" "$A/admin/events/$EID/applications?size=10")
has "iki basvuru" "\"userId\":$U2" "$AP"
has "ozet kapasite" "\"capacity\":1" "$AP"
has "e-posta maskeli" "***@bingol.edu.tr" "$AP"
hasnt "tam e-posta yok" "$EU2" "$AP"
check "gecersiz durum" 400 "$(code -H "$AAD" "$A/admin/events/$EID/applications?status=BOGUS")"
check "sebepsiz kabul" 400 "$(code -X POST -H "$AAD" $A/admin/events/$EID/applications/$U2/accept)"

echo "== zorla kabul: kapasite asilamaz"
check "ilk kabul" 200 "$(code -X POST -H "$AAD" -H "$R" $A/admin/events/$EID/applications/$U2/accept)"
FULL=$(curl -s -X POST -H "$AAD" -H "$R" $A/admin/events/$EID/applications/$U3/accept)
has "ikinci kabul EVENT_FULL" "EVENT_FULL" "$FULL"
check "ikinci kabul 409" 409 "$(code -X POST -H "$AAD" -H "$R" $A/admin/events/$EID/applications/$U3/accept)"
AP2=$(curl -s -H "$AAD" "$A/admin/events/$EID/applications?status=PENDING")
has "ikinci basvuru PENDING kaldi" "\"userId\":$U3" "$AP2"
echo "== zorla ret (kabul edilmis katilimci cikarilir)"
check "kabul edilmisi reddet" 200 "$(code -X POST -H "$AAD" -H "$R" $A/admin/events/$EID/applications/$U2/reject)"
check "yer acildi, simdi kabul" 200 "$(code -X POST -H "$AAD" -H "$R" $A/admin/events/$EID/applications/$U3/accept)"

echo "== yoklama / sertifika / geri bildirim / duyuru"
AT=$(curl -s -H "$AAD" $A/admin/events/$EID/attendance)
has "yoklama ozeti" "\"summary\"" "$AT"
# yoklama penceresi (baslangica 30 dk) kapali: 409 CHECKIN_CLOSED beklenir
check "yoklama duzeltme pencere kapali" 409 "$(code -X PUT -H "$AAD" -H "$H" -H "$R" $A/admin/events/$EID/attendance/$U3 -d '{"present":true}')"
check "sertifika listesi" 200 "$(code -H "$AAD" $A/admin/events/$EID/certificates)"
check "olmayan sertifika iptali" 404 "$(code -X POST -H "$AAD" -H "$R" $A/admin/events/$EID/certificates/$U3/revoke)"
FBK=$(curl -s -H "$AAD" $A/admin/events/$EID/feedback)
has "geri bildirim ozeti" "\"summary\"" "$FBK"
hasnt "geri bildirimde kimlik yok" "userId" "$FBK"
check "olmayan geri bildirim silme" 404 "$(code -X DELETE -H "$AAD" -H "$R" $A/admin/events/$EID/feedback/999999999)"
check "duyuru listesi" 200 "$(code -H "$AAD" $A/admin/events/$EID/announcements)"
check "olmayan duyuru silme" 404 "$(code -X DELETE -H "$AAD" -H "$R" $A/admin/events/$EID/announcements/999999999)"

echo "== duzenleyenler: sahip korunur"
OR=$(curl -s -H "$AAD" $A/admin/events/$EID/organizers)
has "sahip listede" "\"role\":\"OWNER\"" "$OR"
OWN=$(curl -s -X DELETE -H "$AAD" -H "$R" $A/admin/events/$EID/organizers/$U1)
has "sahip cikarilamaz" "EVENT_OWNER_PROTECTED" "$OWN"

echo "== CSV"
curl -s -D /tmp/p07_h1.txt -H "$AAD" $A/admin/events/$EID/applications.csv -o /tmp/p07_apps.csv
has "CSV content-type" "text/csv" "$(cat /tmp/p07_h1.txt)"
has "CSV basligi" "applicationId,userId,name,emailMasked" "$(cat /tmp/p07_apps.csv)"
hasnt "CSV tam e-posta yok" "$EU2" "$(cat /tmp/p07_apps.csv)"
has "CSV formul kacisi" "'=1+1" "$(cat /tmp/p07_apps.csv)"
check "yoklama CSV" 200 "$(code -H "$AAD" $A/admin/events/$EID/attendance.csv)"
check "etkinlik listesi CSV" 200 "$(code -H "$AAD" "$A/admin/events/export.csv?status=ALL")"
check "olmayan etkinlik CSV 404 JSON" 404 "$(code -H "$AAD" $A/admin/events/987654321/attendance.csv)"

echo "== toplu islem (kismi basari)"
BL=$(curl -s -X POST -H "$AAD" -H "$H" -H "$R" $A/admin/events/bulk -d "{\"action\":\"HIDE\",\"ids\":[$EID,987654321],\"reason\":\"duman testi toplu gizleme\"}")
has "toplu: 1 basarili" "\"done\":1" "$BL"
has "toplu: 1 basarisiz" "EVENT_NOT_FOUND" "$BL"
check "toplu: sebepsiz" 400 "$(code -X POST -H "$AAD" -H "$H" $A/admin/events/bulk -d "{\"action\":\"HIDE\",\"ids\":[$EID]}")"
IDS=$(seq -s, 900000001 900000101)
check "toplu: 101 id" 400 "$(code -X POST -H "$AAD" -H "$H" -H "$R" $A/admin/events/bulk -d "{\"action\":\"HIDE\",\"ids\":[$IDS],\"reason\":\"duman testi\"}")"
check "gizlenen etkinlik yonetici detayinda" 200 "$(code -H "$AAD" $A/admin/events/$EID)"
check "toplu iptal (temizlik)" 200 "$(code -X POST -H "$AAD" -H "$H" -H "$R" $A/admin/events/bulk -d "{\"action\":\"CANCEL\",\"ids\":[$EID],\"reason\":\"duman testi temizligi\"}")"

echo "== denetim kaydi"
AU=$(curl -s -H "$AAD" "$A/admin/audit?targetType=EVENT&targetId=$EID&size=50")
has "denetim: EVENT hedefi" "\"targetType\":\"EVENT\"" "$AU"
has "denetim: sebep" "duman testi" "$AU"

if [ "$FAIL" = "0" ]; then echo "TUMU TAMAM"; else echo "BASARISIZ ADIMLAR VAR"; exit 1; fi

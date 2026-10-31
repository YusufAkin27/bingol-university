#!/usr/bin/env bash
# P14 duman testi (yonetici push altyapisi): kuyruk listesi/ayrinti (yuk ve ham token ASLA donmez), retry/cancel durum
# kurallari, toplu kismi basari, cihaz ozeti, kampanya hata gruplari, bildirim kutusu istatistikleri, FCM durumu.
# Calisan compose yigina karsi, ASCII, tekrar calistirilabilir. Hizli yazma sinirina takilmamak icin az istek atar.
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ./scripts/smoke-admin-pushops.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur), ADMIN_EMAILS=$ADMIN_EMAIL, V760 migration uygulanmis.
# Not: kuyruga yazmak icin kullanicinin cihazi olmali; FCM kapaliyken kayit yazilmaz (app.push.outbox.hold-when-disabled=true
# ile calistirin ya da kuyruk bos kalirsa ilgili adimlar atlanir).
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

SFX=$RANDOM
UE="smkpush$SFX@bingol.edu.tr"
DEVTOKEN="smoke-token-$SFX-$(date +%s)"
echo "== hazirlik"
TA=$(register "$ADMIN_EMAIL" "Yonetici")
TU=$(register "$UE" "Smoke Push")
[ -n "$TA" ] && [ -n "$TU" ] || { echo "token alinamadi (ADMIN_EMAILS ayarli mi?)"; exit 1; }
AD="Authorization: Bearer $TA"; US="Authorization: Bearer $TU"
# kullanicinin cihazi (cihaz ozeti ve kuyruk icin)
curl -s -o /dev/null -X POST -H "$H" -H "$US" $A/devices -d "{\"fcmToken\":\"$DEVTOKEN\",\"platform\":\"ANDROID\",\"appVersion\":\"9.9.9\"}"

echo "== yetki"
for u in push/outbox push/outbox/1 push/devices/summary push/campaigns/1/failures notifications/stats; do
  check "anonim GET $u" 401 "$(code $A/admin/$u)"
  check "kullanici GET $u" 403 "$(code -H "$US" $A/admin/$u)"
done
check "kullanici retry" 403 "$(code -X POST -H "$US" $A/admin/push/outbox/1/retry)"
check "kullanici bulk" 403 "$(code -X POST -H "$H" -H "$US" $A/admin/push/outbox/bulk -d '{"action":"RETRY","ids":[1]}')"

echo "== FCM durumu (mevcut uclar degismedi)"
F=$(curl -s -H "$AD" $A/admin/push/fcm/status)
has "fcm status alanlari" '"enabled"' "$F"
has "fcm status projectId alani" '"projectId"' "$F"

echo "== cihaz ozeti: yalniz toplu sayilar"
D=$(curl -s -H "$AD" $A/admin/push/devices/summary)
has "totalTokens" '"totalTokens"' "$D"
has "byPlatform" '"byPlatform"' "$D"
has "android sayaci" '"android"' "$D"
has "activeLast7d" '"activeLast7d"' "$D"
has "staleOver30d" '"staleOver30d"' "$D"
hasnt "ham token yok" "$DEVTOKEN" "$D"
hasnt "fcmToken alani yok" 'fcmToken' "$D"

echo "== bildirim istatistikleri"
S=$(curl -s -H "$AD" $A/admin/notifications/stats)
has "14 gun" '"days":14' "$S"
has "seri" '"series"' "$S"
has "tur dagilimi" '"byType"' "$S"
check "gun 7" 200 "$(code -H "$AD" "$A/admin/notifications/stats?days=7")"

echo "== kuyruk listesi (yuk ve ham token donmez)"
L=$(curl -s -H "$AD" "$A/admin/push/outbox?size=50")
has "liste sayfali" '"totalItems"' "$L"
hasnt "yuk alani yok" 'payload' "$L"
hasnt "ham token yok" "$DEVTOKEN" "$L"
hasnt "ham kullanici kimligi alani yok" '"userId"' "$L"
check "gecersiz durum suzgeci" 400 "$(code -H "$AD" "$A/admin/push/outbox?status=NOPE")"
check "gecersiz tur suzgeci" 400 "$(code -H "$AD" "$A/admin/push/outbox?type=NOPE")"
check "olmayan kayit" 404 "$(code -H "$AD" $A/admin/push/outbox/987654321)"

ID=$(echo "$L" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
if [ -n "$ID" ]; then
  echo "== ayrinti #$ID"
  DT=$(curl -s -H "$AD" $A/admin/push/outbox/$ID)
  has "ayrinti: maxAttempts" '"maxAttempts"' "$DT"
  has "ayrinti: canRetry" '"canRetry"' "$DT"
  hasnt "ayrinti: yuk yok" 'payload' "$DT"
  hasnt "ayrinti: ham token yok" "$DEVTOKEN" "$DT"
else
  echo "  not: kuyrukta kayit yok (FCM kapali olabilir); ayrinti/islem adimlari atlandi"
fi

echo "== durum kurallari"
check "olmayan kaydi yeniden dene" 404 "$(code -X POST -H "$AD" $A/admin/push/outbox/987654321/retry)"
check "olmayan kaydi iptal (sebepli)" 404 "$(code -X POST -H "$H" -H "$AD" -H 'X-Admin-Reason: duman testi sebebi' $A/admin/push/outbox/987654321/cancel -d '{"reason":"duman testi sebebi"}')"
check "iptal sebepsiz" 400 "$(code -X POST -H "$AD" $A/admin/push/outbox/987654321/cancel)"
check "toplu sebepsiz" 400 "$(code -X POST -H "$H" -H "$AD" $A/admin/push/outbox/bulk -d '{"action":"RETRY","ids":[987654321]}')"
BR=$(curl -s -X POST -H "$H" -H "$AD" -H 'X-Admin-Reason: duman testi sebebi' $A/admin/push/outbox/bulk \
  -d '{"action":"CANCEL","reason":"duman testi sebebi","ids":[987654321,987654322]}')
has "toplu: kismi sonuc" '"requested":2' "$BR"
has "toplu: bulunamadi" 'NOT_FOUND' "$BR"
check "toplu 201 kimlik" 400 "$(code -X POST -H "$H" -H "$AD" -H 'X-Admin-Reason: duman testi sebebi' $A/admin/push/outbox/bulk -d "{\"action\":\"RETRY\",\"reason\":\"duman testi sebebi\",\"ids\":[$(seq -s, 1 201)]}")"

echo "== kampanya hatalari"
check "olmayan kampanya" 404 "$(code -H "$AD" $A/admin/push/campaigns/987654321/failures)"
C=$(curl -s -X POST -H "$H" -H "$AD" -H 'X-Admin-Reason: smoke kampanya denemesi' $A/admin/push/campaigns -d '{"audience":{"type":"SELF"},"tr":{"title":"Smoke kampanya","body":"Duman testi"}}')
CID=$(echo "$C" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
if [ -n "$CID" ]; then
  CF=$(curl -s -H "$AD" $A/admin/push/campaigns/$CID/failures)
  has "kampanya hata ozeti" '"totals"' "$CF"
  has "kampanya gruplari" '"groups"' "$CF"
  hasnt "alici kimligi yok" 'userRef' "$CF"
fi

echo
if [ "$FAIL" = "0" ]; then echo "TAMAM: yonetici push altyapisi duman testi gecti"; else echo "BASARISIZ"; exit 1; fi

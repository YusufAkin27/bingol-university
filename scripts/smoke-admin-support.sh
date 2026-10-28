#!/usr/bin/env bash
# P12 duman testi (yonetici destek tamamlama): ic not (musteriye GORUNMEZ), yeniden ac, oncelik/atama, silme,
# geri bildirim silme/birlestirme (oy tasima PostgreSQL'de), SSS siralama, CSV. Calisan compose yigina karsi, ASCII.
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ./scripts/smoke-admin-support.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur), ADMIN_EMAILS=$ADMIN_EMAIL, V740 migration uygulanmis.
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

SFX=$RANDOM
UE="smksup$SFX@bingol.edu.tr"; UE2="smksup2x$SFX@bingol.edu.tr"
SECRET="GIZLI-IC-NOT-$SFX"
echo "== hazirlik"
TA=$(register "$ADMIN_EMAIL" "Yonetici")
TU=$(register "$UE" "Smoke Destek"); TU2=$(register "$UE2" "Smoke Destek Iki")
[ -n "$TA" ] && [ -n "$TU" ] && [ -n "$TU2" ] || { echo "token alinamadi (ADMIN_EMAILS ayarli mi?)"; exit 1; }
AD="Authorization: Bearer $TA"; US="Authorization: Bearer $TU"; US2="Authorization: Bearer $TU2"
ADMIN_ID=$(curl -s -H "$AD" $A/admin/me | idof)
UID1=$(curl -s -H "$US" $A/users/me | idof); UID2=$(curl -s -H "$US2" $A/users/me | idof)

echo "== yetki"
check "anonim reopen" 401 "$(code -X POST $A/admin/support/tickets/1/reopen)"
check "kullanici reopen" 403 "$(code -X POST -H "$US" $A/admin/support/tickets/1/reopen)"
check "kullanici csv" 403 "$(code -H "$US" $A/admin/support/tickets/export.csv)"
check "kullanici faq order" 403 "$(code -X PUT -H "$H" -H "$US" $A/admin/faq/order -d '{"ids":[1]}')"

echo "== ic not: musteriye gorunmez"
T=$(curl -s -X POST -H "$H" -H "$US" $A/support/tickets -d "{\"category\":\"TECHNICAL\",\"subject\":\"Smoke talep $SFX\",\"message\":\"Smoke mesaj\"}")
TID=$(echo "$T" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
[ -n "$TID" ] || { echo "talep olusmadi: $T"; exit 1; }
N=$(curl -s -X POST -H "$H" -H "$AD" $A/admin/support/tickets/$TID/notes -d "{\"text\":\"$SECRET\"}")
has "not olustu (internal)" '"internal":true' "$N"
D=$(curl -s -H "$AD" $A/admin/support/tickets/$TID)
has "yonetici: not gorunur" "$SECRET" "$D"
has "yonetici: oncelik" '"priority":"NORMAL"' "$D"
UD=$(curl -s -H "$US" $A/support/tickets/$TID)
hasnt "musteri ayrintisi: not yok" "$SECRET" "$UD"
hasnt "musteri ayrintisi: internal alani yok" 'internal' "$UD"
hasnt "musteri listesi: not yok" "$SECRET" "$(curl -s -H "$US" $A/support/tickets)"
curl -s -o /dev/null -X POST -H "$H" -H "$AD" $A/admin/support/tickets/$TID/reply -d '{"text":"Personel yaniti"}'
hasnt "personel yaniti sonrasi musteri: not yok" "$SECRET" "$(curl -s -H "$US" $A/support/tickets/$TID)"

echo "== oncelik / atama / yeniden ac"
P=$(curl -s -X PATCH -H "$H" -H "$AD" $A/admin/support/tickets/$TID -d "{\"priority\":\"HIGH\",\"assigneeId\":$ADMIN_ID}")
has "oncelik HIGH" '"priority":"HIGH"' "$P"
has "atanan yonetici" "\"assigneeId\":$ADMIN_ID" "$P"
check "normal kullaniciya atama" 400 "$(code -X PATCH -H "$H" -H "$AD" $A/admin/support/tickets/$TID -d "{\"assigneeId\":$UID1}")"
check "bos patch" 400 "$(code -X PATCH -H "$H" -H "$AD" $A/admin/support/tickets/$TID -d '{}')"
has "atama kaldir" '"assigneeId":null' "$(curl -s -X PATCH -H "$H" -H "$AD" $A/admin/support/tickets/$TID -d '{"unassign":true}')"
check "acik talep yeniden acilamaz" 409 "$(code -X POST -H "$AD" $A/admin/support/tickets/$TID/reopen)"
check "kapat" 204 "$(code -X POST -H "$AD" $A/admin/support/tickets/$TID/close)"
has "yeniden ac" '"status":"OPEN"' "$(curl -s -X POST -H "$AD" $A/admin/support/tickets/$TID/reopen)"

echo "== CSV (ic not disa aktarilmaz)"
TC=$(curl -s -D - -H "$AD" "$A/admin/support/tickets/export.csv?priority=HIGH" | head -c 4000)
has "talep csv baslik" 'id,durum,kategori,oncelik' "$TC"
hasnt "talep csv: ic not yok" "$SECRET" "$TC"

echo "== talep silme"
check "silme: sebepsiz" 400 "$(code -X DELETE -H "$AD" $A/admin/support/tickets/$TID)"
check "silme" 204 "$(code -X DELETE -H "$AD" -H 'X-Admin-Reason: smoke temizligi' $A/admin/support/tickets/$TID)"
check "silinen talep yok (yonetici)" 404 "$(code -H "$AD" $A/admin/support/tickets/$TID)"
check "silinen talep yok (musteri)" 404 "$(code -H "$US" $A/support/tickets/$TID)"

echo "== geri bildirim: birlestirme ve silme"
F1=$(curl -s -X POST -H "$H" -H "$US" $A/feedback -d "{\"category\":\"SUGGESTION\",\"subject\":\"Smoke oneri A $SFX\",\"message\":\"mesaj A\"}" | idof)
F2=$(curl -s -X POST -H "$H" -H "$US2" $A/feedback -d "{\"category\":\"SUGGESTION\",\"subject\":\"Smoke oneri B $SFX\",\"message\":\"mesaj B\"}" | idof)
[ -n "$F1" ] && [ -n "$F2" ] || { echo "geri bildirim olusmadi"; exit 1; }
for f in $F1 $F2; do curl -s -o /dev/null -X PATCH -H "$H" -H "$AD" $A/admin/feedback/$f -d '{"publicVisible":true}'; done
curl -s -o /dev/null -X PUT -H "$US" $A/suggestions/$F1/vote
curl -s -o /dev/null -X PUT -H "$US2" $A/suggestions/$F1/vote
curl -s -o /dev/null -X PUT -H "$US2" $A/suggestions/$F2/vote
check "ayni kayit" 400 "$(code -X POST -H "$H" -H "$AD" $A/admin/support/feedback/merge -d "{\"sourceId\":$F1,\"targetId\":$F1,\"reason\":\"yeterince uzun sebep\"}")"
check "sebepsiz birlestirme" 400 "$(code -X POST -H "$H" -H "$AD" $A/admin/support/feedback/merge -d "{\"sourceId\":$F1,\"targetId\":$F2}")"
M=$(curl -s -X POST -H "$H" -H "$AD" $A/admin/support/feedback/merge -d "{\"sourceId\":$F1,\"targetId\":$F2,\"reason\":\"ayni oneri tekrar edilmis\"}")
has "oylar tasindi (iki farkli kullanici)" '"voteCount":2' "$M"
check "kaynak silindi" 404 "$(code -X DELETE -H "$AD" -H 'X-Admin-Reason: smoke temizligi' $A/admin/support/feedback/$F1)"
check "hedef silinir" 204 "$(code -X DELETE -H "$AD" -H 'X-Admin-Reason: smoke temizligi' $A/admin/support/feedback/$F2)"
has "geri bildirim csv" 'id,kategori,durum,konu' "$(curl -s -H "$AD" $A/admin/support/feedback/export.csv | head -c 300)"

echo "== SSS siralama"
CAT="SmokeSira$SFX"
Q1=$(curl -s -X POST -H "$H" -H "$AD" $A/admin/faq -d "{\"lang\":\"tr\",\"category\":\"$CAT\",\"question\":\"Birinci?\",\"answer\":\"a\"}" | idof)
Q2=$(curl -s -X POST -H "$H" -H "$AD" $A/admin/faq -d "{\"lang\":\"tr\",\"category\":\"$CAT\",\"question\":\"Ikinci?\",\"answer\":\"b\"}" | idof)
O=$(curl -s -X PUT -H "$H" -H "$AD" $A/admin/faq/order -d "{\"ids\":[$Q2,$Q1]}")
has "ilk sirada Q2" "\"id\":$Q2" "$(echo "$O" | head -c 40)"
check "tekrar eden kimlik" 400 "$(code -X PUT -H "$H" -H "$AD" $A/admin/faq/order -d "{\"ids\":[$Q1,$Q1]}")"
check "olmayan kimlik" 404 "$(code -X PUT -H "$H" -H "$AD" $A/admin/faq/order -d "{\"ids\":[$Q1,999999999]}")"
curl -s -o /dev/null -X DELETE -H "$AD" $A/admin/faq/$Q1
curl -s -o /dev/null -X DELETE -H "$AD" $A/admin/faq/$Q2

echo
[ "$FAIL" = 0 ] && echo "TUMU TAMAM" || { echo "HATA VAR"; exit 1; }

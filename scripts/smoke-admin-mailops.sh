#!/usr/bin/env bash
# P13 duman testi (yonetici mail altyapisi): bastirma listesi (maskeleme, elle ekleme, UNSUBSCRIBED/COMPLAINT cift onayli
# kaldirma, CSV), mail kuyrugu (maskeli liste, icerik YOK, iptal/yeniden dene/toplu), gunluk kota (salt okunur).
# Calisan compose yigina karsi, ASCII, tekrar calistirilabilir.
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ./scripts/smoke-admin-mailops.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur), ADMIN_EMAILS=$ADMIN_EMAIL, V750 migration uygulanmis.
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
UE="smkmail$SFX@bingol.edu.tr"
MAN="elle.smoke$SFX@example.com"
echo "== hazirlik"
TA=$(register "$ADMIN_EMAIL" "Yonetici")
TU=$(register "$UE" "Smoke Mail")
[ -n "$TA" ] && [ -n "$TU" ] || { echo "token alinamadi (ADMIN_EMAILS ayarli mi?)"; exit 1; }
AD="Authorization: Bearer $TA"; US="Authorization: Bearer $TU"

echo "== yetki"
check "anonim liste" 401 "$(code $A/admin/mail/suppressions)"
check "kullanici bastirma" 403 "$(code -H "$US" $A/admin/mail/suppressions)"
check "kullanici kuyruk" 403 "$(code -H "$US" $A/admin/mail/outbox)"
check "kullanici kota" 403 "$(code -H "$US" $A/admin/mail/quota)"
check "kullanici csv" 403 "$(code -H "$US" $A/admin/mail/suppressions/export.csv)"

echo "== bastirma: elle ekle (not zorunlu, adres maskeli)"
check "gecersiz e-posta" 400 "$(code -X POST -H "$H" -H "$AD" $A/admin/mail/suppressions -d '{"email":"yok","note":"yeterli not"}')"
check "kisa not" 400 "$(code -X POST -H "$H" -H "$AD" $A/admin/mail/suppressions -d "{\"email\":\"$MAN\",\"note\":\"ab\"}")"
R=$(curl -s -X POST -H "$H" -H "$AD" -H "X-Admin-Reason: smoke deneme" $A/admin/mail/suppressions -d "{\"email\":\"$MAN\",\"reason\":\"MANUAL\",\"note\":\"Smoke elle ekleme\"}")
has "MANUAL" '"reason":"MANUAL"' "$R"
hasnt "yanitta tam adres yok" "$MAN" "$R"
MID=$(echo "$R" | idof)
check "ayni adres" 409 "$(code -X POST -H "$H" -H "$AD" -H "X-Admin-Reason: smoke deneme" $A/admin/mail/suppressions -d "{\"email\":\"$MAN\",\"note\":\"tekrar deneme\"}")"
L=$(curl -s -H "$AD" "$A/admin/mail/suppressions?q=$MAN")
has "tam adresle arama" '"total":1' "$L"
hasnt "listede tam adres yok" "$MAN" "$L"
D=$(curl -s -H "$AD" $A/admin/mail/suppressions/$MID)
has "ayrinti: cozulemeyen adres" '"fullEmail":null' "$D"
CSV=$(curl -s -H "$AD" "$A/admin/mail/suppressions/export.csv?reason=MANUAL")
hasnt "csv: tam adres yok" "$MAN" "$CSV"
check "BOUNCED/MANUAL kisa sebep reddi" 400 "$(code -X DELETE -H "$AD" -H "X-Admin-Reason: ab" $A/admin/mail/suppressions/$MID)"
check "MANUAL kaldir" 204 "$(code -X DELETE -H "$AD" -H "X-Admin-Reason: smoke temizlik" $A/admin/mail/suppressions/$MID)"
check "kaldirilan tekrar" 404 "$(code -X DELETE -H "$AD" -H "X-Admin-Reason: smoke temizlik" $A/admin/mail/suppressions/$MID)"

echo "== bastirma: kullanicinin kendi cikisi cift onayli kaldirilir (UNSUBSCRIBED)"
# Abonelikten cikma jetonu uretmek yerine veritabaninda hazirlanir (compose postgres)
HASH=$(printf '%s' "$UE" | tr 'A-Z' 'a-z' | sha256sum | cut -d' ' -f1)
docker compose exec -T postgres psql -U "${DB_USER:-bu}" -d "${DB_NAME:-bu}" -c \
  "INSERT INTO mail_suppression (email_hash, reason, created_at) VALUES ('$HASH','UNSUBSCRIBED', now()) ON CONFLICT DO NOTHING" >/dev/null 2>&1
UL=$(curl -s -H "$AD" "$A/admin/mail/suppressions?q=$UE")
UID_S=$(echo "$UL" | idof)
if [ -z "$UID_S" ]; then
  echo "  atlandi: UNSUBSCRIBED kaydi hazirlanamadi (psql yok/kimlik farkli) -> DB_USER/DB_NAME verin"
else
  has "UNSUBSCRIBED listelendi" '"reason":"UNSUBSCRIBED"' "$UL"
  hasnt "listede tam adres yok" "$UE" "$UL"
  UD=$(curl -s -H "$AD" $A/admin/mail/suppressions/$UID_S)
  has "ayrinti: kayitli kullanici -> tam adres" "$UE" "$UD"
  has "ayrinti: onay gerekli" '"removeNeedsConfirm":true' "$UD"
  check "onay basligi yok" 409 "$(code -X DELETE -H "$AD" -H 'X-Admin-Reason: Kullanici yazili olarak istedi' $A/admin/mail/suppressions/$UID_S)"
  check "onay var ama sebep kisa" 400 "$(code -X DELETE -H "$AD" -H "X-Admin-Confirm: $UID_S" -H 'X-Admin-Reason: on dokuz karakter!!' $A/admin/mail/suppressions/$UID_S)"
  check "cift onayla kaldir" 204 "$(code -X DELETE -H "$AD" -H "X-Admin-Confirm: $UID_S" -H 'X-Admin-Reason: Kullanici yazili olarak yeniden abone oldu' $A/admin/mail/suppressions/$UID_S)"
fi

echo "== kuyruk: liste maskeli, icerik yok"
O=$(curl -s -H "$AD" "$A/admin/mail/outbox?size=50")
has "kuyruk listesi" '"items"' "$O"
hasnt "listede tam alici yok" "$UE" "$O"
hasnt "listede degisken alani yok" 'varsJson' "$O"
OQ=$(curl -s -H "$AD" "$A/admin/mail/outbox?q=$UE")
has "tam adresle arama" '"items"' "$OQ"
hasnt "arama sonucu tam alici yok" "$UE" "$OQ"
OID=$(echo "$OQ" | idof)
if [ -n "$OID" ]; then
  OD=$(curl -s -H "$AD" $A/admin/mail/outbox/$OID)
  has "ayrinti: icerik yok" '"contentIncluded":false' "$OD"
  hasnt "ayrintida degisken alani yok" 'varsJson' "$OD"
  hasnt "ayrintida kod alani yok" '"code"' "$OD"
  check "SENT/DEAD iptal edilemez ya da bekleyen iptal edilir" 1 "$(code -X POST -H "$AD" -H 'X-Admin-Reason: smoke iptal' $A/admin/mail/outbox/$OID/cancel | grep -cE '^(200|409)$')"
fi
check "olmayan kayit" 404 "$(code -H "$AD" $A/admin/mail/outbox/999999999)"
check "sebepsiz toplu" 400 "$(code -X POST -H "$H" -H "$AD" $A/admin/mail/outbox/bulk -d '{"action":"RETRY","ids":[1]}')"
check "gecersiz eylem" 400 "$(code -X POST -H "$H" -H "$AD" $A/admin/mail/outbox/bulk -d '{"action":"DELETE","ids":[1],"reason":"gecersiz eylem"}')"
B=$(curl -s -X POST -H "$H" -H "$AD" $A/admin/mail/outbox/bulk -d '{"action":"RETRY","ids":[999999998,999999999],"reason":"smoke toplu deneme"}')
has "toplu: kismi sonuc" '"succeeded":0' "$B"
has "toplu: bulunamadi" 'MAILOPS_OUTBOX_NOT_FOUND' "$B"

echo "== kota (salt okunur)"
Q=$(curl -s -H "$AD" $A/admin/mail/quota)
has "kota alanlari" '"percent"' "$Q"
has "kota gecmisi" '"history"' "$Q"
has "kuyruk ozeti" '"queue"' "$Q"
check "kota yazma yok" 405 "$(code -X POST -H "$AD" $A/admin/mail/quota)"

echo "== denetim"
AU=$(curl -s -H "$AD" "$A/admin/audit?targetType=MAIL_SUPPRESSION&size=5")
has "denetimde MAIL_SUPPRESSION" 'MAIL_SUPPRESSION' "$AU"

[ $FAIL -eq 0 ] && echo "TUMU GECTI" || { echo "BAZI KONTROLLER BASARISIZ"; exit 1; }

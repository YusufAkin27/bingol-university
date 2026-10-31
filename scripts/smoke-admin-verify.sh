#!/usr/bin/env bash
# Yonetici dogrulama duman testi: kayit -> yonetici bekleyen kaydi kodsuz dogrular -> kullanici giris yapar.
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ADMIN_PASSWORD=... ./scripts/smoke-admin-verify.sh
# Onkosul: compose'ta MAIL_ENABLED=false, ADMIN_EMAILS=$ADMIN_EMAIL, hesap ADMIN_EMAIL daha once dogrulanmis olmali
# (sifresi ADMIN_ACCOUNT_PASSWORD / ADMIN_PASSWORD / Sifre1234 degerlerinden biri).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-adminpw123}
H='Content-Type: application/json'
FAIL=0
# T-011/T-013: kodsuz dogrulama ve hesap islemleri gerekce ister (>= 5 karakter)
RS='X-Admin-Reason: smoke dogrulama testi'
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
# JSON govdesi dosyadan gonderilir (Windows terminalinde tirnak/karakter sorunlarina karsi)
post() { # yol govde-dosyasi [ek-baslik]
  curl -s -o "$TMP/out" -w '%{http_code}' -X POST -H "$H" -H "$RS" ${3:+-H "$3"} "$A$1" --data-binary @"$2"
}

SFX=$RANDOM
NUM="9$(printf '%05d' $SFX)001"
EMAIL="$NUM@bingol.edu.tr"

echo "== yonetici girisi"
# Yonetici HESABININ sifresi (ADMIN_ACCOUNT_PASSWORD) ile Basic "admin" sifresi (ADMIN_PASSWORD) farkli olabilir; diger
# duman betikleri yonetici hesabini "Sifre1234" ile acar. Sirayla denenir; ilk 200 gecerlidir.
LOGIN_CODE=000
for PW in "${ADMIN_ACCOUNT_PASSWORD:-}" "$ADMIN_PASSWORD" "Sifre1234"; do
  [ -n "$PW" ] || continue
  printf '{"email":"%s","password":"%s"}' "$ADMIN_EMAIL" "$PW" > "$TMP/login.json"
  LOGIN_CODE=$(post /auth/login "$TMP/login.json")
  [ "$LOGIN_CODE" = "200" ] && break
done
check "admin login" 200 "$LOGIN_CODE"
TA=$(grep -o '"accessToken":"[^"]*' "$TMP/out" | cut -d'"' -f4)
[ -n "$TA" ] || { echo "admin token yok"; exit 1; }
AAD="Authorization: Bearer $TA"

echo "== kayit (bekleyen)"
printf '{"email":"%s","password":"Sifre1234","displayName":"Smoke Dogrula","acceptTerms":true,"language":"tr"}' "$NUM" > "$TMP/reg.json"
check "register" 202 "$(post /auth/register "$TMP/reg.json")"
printf '{"email":"%s","password":"Sifre1234"}' "$NUM" > "$TMP/ulogin.json"
check "dogrulanmadan giris 403" 403 "$(post /auth/login "$TMP/ulogin.json")"

echo "== yonetici listesi (q) ve dogrulama"
check "liste q" 200 "$(curl -s -o "$TMP/out" -w '%{http_code}' -H "$AAD" "$A/admin/pending-registrations?q=$NUM")"
grep -qF "$EMAIL" "$TMP/out" && echo "  ok   listede" || { echo "  FAIL listede yok"; FAIL=1; }
echo '{}' > "$TMP/empty.json"
check "anonim istek 401" 401 "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "$H" "$A/admin/pending-registrations/$NUM/verify" --data-binary @"$TMP/empty.json")"
check "verify gerekcesiz 400" 400 "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "$H" -H "$AAD" "$A/admin/pending-registrations/$NUM/verify" --data-binary @"$TMP/empty.json")"
check "verify 201" 201 "$(post "/admin/pending-registrations/$NUM/verify" "$TMP/empty.json" "$AAD")"
grep -qF "$EMAIL" "$TMP/out" && echo "  ok   govde e-posta" || { echo "  FAIL govde"; FAIL=1; }
check "verify tekrar 404" 404 "$(post "/admin/pending-registrations/$NUM/verify" "$TMP/empty.json" "$AAD")"

echo "== kullanici girisi"
check "giris 200" 200 "$(post /auth/login "$TMP/ulogin.json")"
UID_=$(curl -s -H "$AAD" "$A/admin/users?q=$NUM" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
check "send-reset 204" 204 "$(post "/admin/users/$UID_/send-reset" "$TMP/empty.json" "$AAD")"
check "revoke-sessions 204" 204 "$(post "/admin/users/$UID_/revoke-sessions" "$TMP/empty.json" "$AAD")"
check "verify-email gerekcesiz 400" 400 "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "$H" -H "$AAD" "$A/admin/users/$UID_/verify-email" --data-binary @"$TMP/empty.json")"
$1
echo "== temizlik"
curl -s -o /dev/null -X DELETE -H "$AAD" -H "$RS" "$A/admin/users/$UID_"
[ $FAIL -eq 0 ] && echo "TAMAM" || { echo "HATA VAR"; exit 1; }

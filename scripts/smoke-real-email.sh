#!/usr/bin/env bash
# Gercek e-posta (Apple gizli/role adres) dogrulamasi icin duman testi (ASCII). Calisan compose yigina karsi, PostgreSQL 16.
# Gercek Apple token'i yok: role hesap, parola ile kaydolan bir kullanicinin e-postasini ve bayraklarini veritabaninda
# role adresine cevirerek taklit edilir (kapi, kod akisi, e-posta guncelleme, benzersizlik, rehber ozeti PostgreSQL'de
# dogrulanir). OAuth giris yanitindaki emailNeedsReal/realEmailRequired alanlari OAuthMvcTest/RealEmailMvcTest'te
# (yerel RSA anahtarli token) dogrulanir.
# Kullanim: BASE=http://localhost:8080 ./scripts/smoke-real-email.sh
# Onkosul: MAIL_ENABLED=false (kod log'dan okunur), LEGAL_ENFORCE_REACCEPT=false, AUTH_REAL_EMAIL_GATE_ENABLED=true (varsayilan).
# Rate limit: bir kullanici saatte 5 'start' atabilir; betik 5 kullanir. Tekrar kosmadan once: redis flushall (smoke-all.sh yapar).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0
PW='Zk7-Qmv-Lpx92w'

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 240)"; FAIL=1; fi; }
hasnt() { if echo "$3" | grep -qF -- "$2"; then echo "  FAIL $1 (bulunmamali: $2) -> $(echo "$3" | head -c 240)"; FAIL=1; else echo "  ok   $1"; fi; }
field() { grep -o "\"$1\":\"[^\"]*" | head -1 | cut -d'"' -f4; }
sql() { docker compose exec -T postgres psql -U bingol -d bingol -tA -c "$1" 2>/dev/null | tr -d '\r'; }
mailcode() { docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2; }

TAG="$RANDOM$RANDOM"
EMAIL="re$TAG@gmail.com"
RELAY="re$TAG@privaterelay.appleid.com"
REAL="gercek$TAG@gmail.com"
OTHER="baska$TAG@gmail.com"

register() { # $1 e-posta -> access token
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register \
    -d "{\"email\":\"$1\",\"password\":\"$PW\",\"displayName\":\"Gercek Eposta\",\"acceptTerms\":true}"
  sleep 1
  local c; c=$(mailcode "$1")
  local d; d=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"$PW\"}")
  local t; t=$(echo "$d" | field accessToken)
  if [ -z "$t" ]; then
    d=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"$PW\",\"client\":\"web\"}")
    t=$(echo "$d" | field accessToken)
  fi
  echo "$t"
}

echo "== kullanici hazirla (parola ile kayitli, normal)"
AT=$(register "$EMAIL")
[ -n "$AT" ] && echo "  ok   kayit + giris" || { echo "  FAIL kayit/giris"; exit 1; }
AH="Authorization: Bearer $AT"
UID_=$(sql "SELECT id FROM app_user WHERE email='$EMAIL'")
echo "  bilgi: kullanici id=$UID_"

ME=$(curl -s -H "$AH" $A/users/me)
has "normal hesap: emailNeedsReal=false" '"emailNeedsReal":false' "$ME"
has "normal hesap: realEmailRequired=false" '"realEmailRequired":false' "$ME"

echo "== role hesabi taklidi (veritabaninda: e-posta role adresi + bayraklar)"
sql "UPDATE app_user SET email='$RELAY', email_relay=TRUE, real_email_required=TRUE WHERE id=$UID_" >/dev/null
check "role bayragi yazildi" "t|t" "$(sql "SELECT email_relay||'|'||real_email_required FROM app_user WHERE id=$UID_")"
ME=$(curl -s -H "$AH" $A/users/me)
has "users/me emailNeedsReal=true" '"emailNeedsReal":true' "$ME"
has "users/me realEmailRequired=true" '"realEmailRequired":true' "$ME"

echo "== kapi: yazma 403 REAL_EMAIL_REQUIRED, okuma + profil + akis serbest"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$AH" $A/posts -d '{}')
check "gonderi yazma kapali" 403 "$(echo "$R" | tail -1)"
has "gonderi yazma kodu" '"code":"REAL_EMAIL_REQUIRED"' "$R"
R=$(curl -s -w '\n%{http_code}' -H "$AH" -H 'Accept-Language: en' $A/notifications)
check "okuma serbest" 200 "$(echo "$R" | tail -1)"
R=$(curl -s -w '\n%{http_code}' -X PATCH -H "$H" -H "$AH" $A/users/me -d '{"bio":"duman"}')
check "profil guncelleme serbest" 200 "$(echo "$R" | tail -1)"

echo "== start: dogrulamalar (role adresi / +etiket reddedilir, kod gonderilmez)"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$AH" $A/users/me/email/start -d '{"email":"baska'$TAG'@privaterelay.appleid.com"}')
check "role adresi reddi" 400 "$(echo "$R" | tail -1)"
has "role adresi kodu" '"code":"EMAIL_RELAY_NOT_ALLOWED"' "$R"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$AH" $A/users/me/email/start -d '{"email":"ali+1'$TAG'@gmail.com"}')
check "+etiket reddi" 400 "$(echo "$R" | tail -1)"
has "+etiket kodu" '"code":"EMAIL_ALIAS_NOT_ALLOWED"' "$R"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" $A/users/me/email/start -d '{"email":"'$REAL'"}')
check "kimliksiz start" 401 "$(echo "$R" | tail -1)"

echo "== start -> verify (kapi acilir)"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$AH" $A/users/me/email/start -d '{"email":"'$REAL'"}')
check "kod gonderildi" 200 "$(echo "$R" | tail -1)"
has "start sent" '"sent":true' "$R"
has "start emailMasked" '"emailMasked":"g***@gmail.com"' "$R"
sleep 1
CODE=$(mailcode "$REAL")
[ -n "$CODE" ] && echo "  ok   kod gercek adrese gitti" || { echo "  FAIL kod log'da yok"; FAIL=1; }
RELAYCODE=$(mailcode "$RELAY")
[ -z "$RELAYCODE" ] && echo "  ok   role adresine kod GITMEDI" || { echo "  FAIL role adresine kod gitmis"; FAIL=1; }

BAD=$([ "$CODE" = "000000" ] && echo 000001 || echo 000000)
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$AH" $A/users/me/email/verify -d '{"code":"'$BAD'"}')
check "yanlis kod" 400 "$(echo "$R" | tail -1)"
has "yanlis kod kodu" '"code":"INVALID_CODE"' "$R"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$AH" $A/users/me/email/verify -d '{"code":"12ab"}')
check "bicimsiz kod" 400 "$(echo "$R" | tail -1)"

R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$AH" $A/users/me/email/verify -d '{"code":"'$CODE'"}')
check "dogru kod" 200 "$(echo "$R" | tail -1)"
has "dogrulama e-posta" '"email":"'$REAL'"' "$R"
has "dogrulama emailNeedsReal=false" '"emailNeedsReal":false' "$R"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$AH" $A/users/me/email/verify -d '{"code":"'$CODE'"}')
check "kod tek kullanimlik" 400 "$(echo "$R" | tail -1)"

echo "== PostgreSQL durumu"
check "hesap tek e-posta + bayraklar kapali" "$REAL|t|f|f" "$(sql "SELECT email||'|'||email_verified||'|'||email_relay||'|'||real_email_required FROM app_user WHERE id=$UID_")"
check "real_email_verified_at dolu" "t" "$(sql "SELECT (real_email_verified_at IS NOT NULL) FROM app_user WHERE id=$UID_")"
check "rehber ozeti (email_sha256) guncellendi" "t" "$(sql "SELECT (email_sha256 = encode(sha256(convert_to('$REAL','UTF8')),'hex')) FROM app_user WHERE id=$UID_")"
check "role adresi artik hicbir hesapta yok" "0" "$(sql "SELECT count(*) FROM app_user WHERE email='$RELAY'")"

ME=$(curl -s -H "$AH" $A/users/me)
has "users/me yeni e-posta" '"email":"'$REAL'"' "$ME"
has "users/me emailNeedsReal=false" '"emailNeedsReal":false' "$ME"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$AH" $A/posts -d '{}')
hasnt "gonderi yazma artik REAL_EMAIL_REQUIRED degil" 'REAL_EMAIL_REQUIRED' "$R"

D=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$REAL\",\"password\":\"$PW\",\"client\":\"web\"}")
[ -n "$(echo "$D" | field accessToken)" ] && echo "  ok   yeni adresle parola girisi" || { echo "  FAIL yeni adresle giris"; FAIL=1; }

echo "== baska hesapta kayitli adres: kod yine gider, cakisma yalniz dogru kodda 409 (enumerasyon yok); role olmayan hesap yeniden dogrulama ister"
BT=$(register "$OTHER")
[ -n "$BT" ] && echo "  ok   ikinci kullanici" || { echo "  FAIL ikinci kullanici"; FAIL=1; }
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$AH" $A/users/me/email/start -d '{"email":"'$OTHER'"}')
check "role olmayan hesap parolasiz start" 403 "$(echo "$R" | tail -1)"
has "parola kodu" '"code":"WRONG_PASSWORD"' "$R"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$AH" $A/users/me/email/start -d '{"email":"'$OTHER'","password":"'$PW'"}')
check "dolu adres: start yine 200 (sizinti yok)" 200 "$(echo "$R" | tail -1)"
sleep 1
C2=$(mailcode "$OTHER")
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$AH" $A/users/me/email/verify -d '{"code":"'$C2'"}')
check "dolu adres: dogru kodda 409" 409 "$(echo "$R" | tail -1)"
has "dolu adres kodu" '"code":"EMAIL_UNAVAILABLE"' "$R"
check "hesap degismedi" "$REAL" "$(sql "SELECT email FROM app_user WHERE id=$UID_")"

echo "== temizlik"
sql "DELETE FROM app_user WHERE id=$UID_" >/dev/null 2>&1
[ "$FAIL" = "0" ] && echo "TUM ADIMLAR GECTI" || echo "BASARISIZ ADIMLAR VAR"
exit $FAIL

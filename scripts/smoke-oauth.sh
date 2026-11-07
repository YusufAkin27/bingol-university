#!/usr/bin/env bash
# Google/Apple girisi + profil tamamlama icin duman testi (ASCII). GERCEK saglayici token'i gerektiren adimlar
# (yeni kullanici, link, gate) burada YOK: onlar birim/MVC testlerinde yerel RSA anahtariyla dogrulanir
# (OAuthTokenVerifierTest, OAuthServiceTest, OAuthMvcTest). Bu betik: bayrak davranisi, giris dogrulamasi, kullanici
# adi musaitligi, /users/me alanlari, mevcut kullanicinin kilitlenmedigi.
# Kullanim: BASE=http://localhost:8080 ./scripts/smoke-oauth.sh
# Onkosul: MAIL_ENABLED=false (kod log'dan okunur), LEGAL_ENFORCE_REACCEPT=false.
# AUTH_OAUTH_ENABLED=false (varsayilan): uclar 404 OAUTH_DISABLED. =true: gecersiz token 400 OAUTH_TOKEN_INVALID.
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 200)"; FAIL=1; fi; }
field() { grep -o "\"$1\":\"[^\"]*" | head -1 | cut -d'"' -f4; }

echo "== OAuth uclari (bayrak durumuna gore)"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" $A/auth/oauth/google -d '{"idToken":"sahte.token.degeri"}')
ST=$(echo "$R" | tail -1)
if [ "$ST" = "404" ]; then
  echo "  bilgi: AUTH_OAUTH_ENABLED=false (bayrak kapali)"
  has "google kapali" '"code":"OAUTH_DISABLED"' "$R"
  R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" $A/auth/oauth/apple -d '{"identityToken":"x","nonce":"n"}')
  check "apple kapali" 404 "$(echo "$R" | tail -1)"
else
  echo "  bilgi: AUTH_OAUTH_ENABLED=true"
  check "google sahte token" 400 "$ST"
  has "google sahte token kodu" '"code":"OAUTH_TOKEN_INVALID"' "$R"
  R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" $A/auth/oauth/apple -d '{"identityToken":"sahte.token.degeri","nonce":"n"}')
  check "apple sahte token" 400 "$(echo "$R" | tail -1)"
  R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" $A/auth/oauth/apple -d '{"identityToken":"sahte.token.degeri"}')
  check "apple nonce zorunlu" 400 "$(echo "$R" | tail -1)"
fi
R=$(curl -s -w '\n%{http_code}' $A/auth/oauth/identities)
check "kimliksiz identities" 401 "$(echo "$R" | tail -1)"
R=$(curl -s -w '\n%{http_code}' "$A/users/username-available?u=abc")
check "kimliksiz username-available" 401 "$(echo "$R" | tail -1)"

echo "== mevcut (parola) kullanici kilitlenmez; kullanici adi"
EMAIL="oa$RANDOM$RANDOM@gmail.com"
curl -s -o /dev/null -X POST -H "$H" $A/auth/register \
  -d "{\"email\":\"$EMAIL\",\"password\":\"Zk7-Qmv-Lpx92w\",\"displayName\":\"Oauth Duman\",\"acceptTerms\":true}"
sleep 1
CODE=$(docker compose logs backend 2>&1 | grep "$EMAIL icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
D=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$EMAIL\",\"code\":\"$CODE\",\"password\":\"Zk7-Qmv-Lpx92w\"}")
AT=$(echo "$D" | field accessToken)
if [ -z "$AT" ]; then
  D=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$EMAIL\",\"password\":\"Zk7-Qmv-Lpx92w\",\"client\":\"web\"}")
  AT=$(echo "$D" | field accessToken)
fi
[ -n "$AT" ] && echo "  ok   giris" || { echo "  FAIL giris"; FAIL=1; }
AH="Authorization: Bearer $AT"

ME=$(curl -s -H "$AH" $A/users/me)
has "users/me profileCompleted=true (parola kaydi tamamlanmis)" '"profileCompleted":true' "$ME"
has "users/me authProviders" '"authProviders"' "$ME"
R=$(curl -s -w '\n%{http_code}' -X PATCH -H "$H" -H "$AH" $A/users/me -d '{"bio":"duman"}')
check "profil yazma kapisi mevcut kullaniciya KAPALI DEGIL" 200 "$(echo "$R" | tail -1)"

U="duman.$RANDOM$RANDOM"
R=$(curl -s -H "$AH" "$A/users/username-available?u=$U")
has "musait" '"available":true' "$R"
R=$(curl -s -H "$AH" "$A/users/username-available?u=admin")
has "ayrilmis" '"reason":"RESERVED"' "$R"
R=$(curl -s -H "$AH" "$A/users/username-available?u=a!")
has "gecersiz" '"reason":"INVALID"' "$R"

R=$(curl -s -w '\n%{http_code}' -X PUT -H "$H" -H "$AH" $A/users/me/username -d "{\"username\":\"$U\"}")
check "kullanici adi atama (eski hesap, istege bagli)" 200 "$(echo "$R" | tail -1)"
R=$(curl -s -H "$AH" "$A/users/username-available?u=$(echo "$U" | tr a-z A-Z)")
has "kendi adin buyuk harfle: musait" '"available":true' "$R"

# ikinci kullanici ayni adi alamaz
EMAIL2="ob$RANDOM$RANDOM@gmail.com"
curl -s -o /dev/null -X POST -H "$H" $A/auth/register \
  -d "{\"email\":\"$EMAIL2\",\"password\":\"Zk7-Qmv-Lpx92w\",\"displayName\":\"Oauth Iki\",\"acceptTerms\":true}"
sleep 1
CODE2=$(docker compose logs backend 2>&1 | grep "$EMAIL2 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
D2=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$EMAIL2\",\"code\":\"$CODE2\",\"password\":\"Zk7-Qmv-Lpx92w\"}")
AT2=$(echo "$D2" | field accessToken)
R=$(curl -s -H "Authorization: Bearer $AT2" "$A/users/username-available?u=$U")
has "baskasinin adi: TAKEN" '"reason":"TAKEN"' "$R"
R=$(curl -s -w '\n%{http_code}' -X PUT -H "$H" -H "Authorization: Bearer $AT2" $A/users/me/username -d "{\"username\":\"$U\"}")
check "alinmis ad 409" 409 "$(echo "$R" | tail -1)"
has "USERNAME_TAKEN" '"code":"USERNAME_TAKEN"' "$R"

# tamamlanmis hesapta onboarding veriyi EZMEZ (idempotent)
R=$(curl -s -w '\n%{http_code}' -X PUT -H "$H" -H "$AH" $A/users/me/onboarding \
  -d "{\"firstName\":\"Baska\",\"lastName\":\"Kisi\",\"username\":\"$U.x\",\"facultyId\":\"muhendislik\",\"departmentId\":\"bilgisayar-muhendisligi\",\"classYear\":\"Y1\",\"acceptTerms\":true}")
check "onboarding tamamlanmis hesapta 200" 200 "$(echo "$R" | tail -1)"
ME2=$(curl -s -H "$AH" $A/users/me)
has "kullanici adi ezilmedi" "\"username\":\"$U\"" "$ME2"

[ $FAIL -eq 0 ] && echo "TAMAM: smoke-oauth" || echo "BASARISIZ: smoke-oauth"
exit $FAIL

#!/usr/bin/env bash
# T5 guvenlik denetimi: JWT / yetki atlatma saldirilari.
# Kullanim: BASE=http://localhost:8105 ./scripts/security/jwt-auth-attacks.sh
# Tekrar calistirilabilir, yikici degildir (yalniz GET/okuma + kendi test kullanicilariyla POST dener).
set -u
BASE=${BASE:-http://localhost:8105}
A=$BASE/api
PASS=Sifre1234

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
# JWT payload'undan "sub" (kullanici id) okur; base64url -> base64 donusumu + dolgu eklenir.
jwt_sub() {
  local p=$(echo "$1" | cut -d. -f2 | tr '_-' '/+')
  case $(( ${#p} % 4 )) in 2) p="${p}==";; 3) p="${p}=";; esac
  echo "$p" | base64 -d 2>/dev/null | grep -o '"sub":"[0-9]*' | cut -d'"' -f4
}

pass() { echo "[OK]   $1"; }
fail() { echo "[FINDING] $1"; }
info() { echo "[info] $1"; }

echo "=== JWT / yetki atlatma saldirilari ($BASE) ==="

# --- Test kullanicilari hazirla (varsa login, yoksa kayit) -----------------
mk_user() {
  local email=$1 name=$2
  curl -s -o /dev/null -X POST -H 'Content-Type: application/json' "$A/auth/register" \
    -d "{\"email\":\"$email\",\"password\":\"$PASS\",\"displayName\":\"$name\",\"acceptTerms\":true}"
  sleep 1
  local code
  code=$(docker compose logs backend 2>&1 | grep "$email icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  if [ -n "$code" ]; then
    curl -s -o /dev/null -X POST -H 'Content-Type: application/json' "$A/auth/verify-email" \
      -d "{\"email\":\"$email\",\"code\":\"$code\",\"password\":\"$PASS\"}"
  fi
}
login() {
  curl -s -X POST -H 'Content-Type: application/json' "$A/auth/login" \
    -d "{\"email\":\"$1\",\"password\":\"$PASS\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4
}

# Her calistirmada benzersiz e-posta kullanilir (betik tekrar calistirilabilir olsun; 409'dan kacinilir).
RUN=$(date +%s)
VICTIM_EMAIL="sec-t5-victim-$RUN@bingol.edu.tr"
ATTACKER_EMAIL="sec-t5-attacker-$RUN@bingol.edu.tr"
mk_user "$VICTIM_EMAIL" "Sec T5 Victim"
mk_user "$ATTACKER_EMAIL" "Sec T5 Attacker"

VICTIM_TOKEN=$(login "$VICTIM_EMAIL")
ATTACKER_TOKEN=$(login "$ATTACKER_EMAIL")
if [ -z "$VICTIM_TOKEN" ] || [ -z "$ATTACKER_TOKEN" ]; then
  echo "[HATA] test kullanicilari hazirlanamadi (login basarisiz); betik durduruluyor." >&2
  exit 1
fi
VICTIM_ID=$(jwt_sub "$VICTIM_TOKEN")
info "kurban kullanici id=$VICTIM_ID"

# --- 1) alg:none saldirisi ---------------------------------------------------
HEADER_NONE=$(printf '{"alg":"none","typ":"JWT"}' | b64url)
PAYLOAD_ADMIN=$(printf '{"sub":"%s","email":"x@bingol.edu.tr","role":"ADMIN","iat":9999999999,"exp":9999999999}' "$VICTIM_ID" | b64url)
TOKEN_NONE="$HEADER_NONE.$PAYLOAD_ADMIN."
CODE=$(curl -s -o /tmp/t5_none.json -w '%{http_code}' -H "Authorization: Bearer $TOKEN_NONE" "$A/auth/me")
if [ "$CODE" = "200" ]; then
  fail "KRITIK: alg:none JWT kabul edildi (HTTP 200) -> $(cat /tmp/t5_none.json)"
else
  pass "alg:none JWT reddedildi (HTTP $CODE)"
fi

# --- 2) suresi dolmus token ---------------------------------------------------
PAYLOAD_EXPIRED=$(printf '{"sub":"%s","email":"x@bingol.edu.tr","role":"USER","iat":1000000000,"exp":1000000001}' "$VICTIM_ID" | b64url)
TOKEN_EXPIRED="$HEADER_NONE.$PAYLOAD_EXPIRED.FAKESIG"
CODE=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN_EXPIRED" "$A/auth/me")
if [ "$CODE" = "200" ]; then
  fail "KRITIK: suresi dolmus/imzasiz token kabul edildi (HTTP 200)"
else
  pass "suresi dolmus/imzasiz token reddedildi (HTTP $CODE)"
fi

# --- 3) rol claim kurcalama (gecerli imzali token'in payload'u degistirilip imza tutturulmaya calisilir) ---
# Gercek saldirgan gizli anahtari bilmez; burada "ayni anahtari tahmin etme" degil, sunucunun
# imza dogrulamasini atlayip atlamadigini (örn. yalnizca payload'a bakip bakmadigini) test ediyoruz.
HEADER_HS=$(printf '{"alg":"HS256","typ":"JWT"}' | b64url)
PAYLOAD_FORGED=$(printf '{"sub":"%s","email":"attacker@bingol.edu.tr","role":"ADMIN","iat":1700000000,"exp":9999999999}' "$VICTIM_ID" | b64url)
# attacker'in kendi gecerli token'inin imzasini (son parcasini) farkli payload'a yapistirma (klasik "signature stripping/reuse")
ATTACKER_SIG=$(echo "$ATTACKER_TOKEN" | cut -d. -f3)
TOKEN_FORGED="$HEADER_HS.$PAYLOAD_FORGED.$ATTACKER_SIG"
CODE=$(curl -s -o /tmp/t5_forged.json -w '%{http_code}' -H "Authorization: Bearer $TOKEN_FORGED" "$A/auth/me")
if [ "$CODE" = "200" ]; then
  fail "KRITIK: imza baska bir token'dan tasinip rol ADMIN'e yukseltilebildi"
else
  pass "tasinmis imzali/rolu kurcalanmis token reddedildi (HTTP $CODE)"
fi

# --- 4) kendi rolunu /api/admin/users/{id}/role ile yukseltme (yetki yukseltme denemesi) ---
CODE=$(curl -s -o /tmp/t5_selfrole.json -w '%{http_code}' -X PATCH -H "Authorization: Bearer $ATTACKER_TOKEN" \
  -H 'Content-Type: application/json' "$A/admin/users/$VICTIM_ID/role" -d '{"role":"ADMIN"}')
if [ "$CODE" = "200" ] || [ "$CODE" = "204" ]; then
  fail "KRITIK: normal kullanici /api/admin/users/{id}/role ile baskasini ADMIN yapabildi (HTTP $CODE)"
else
  pass "normal kullanici admin rol ucuna erisemedi (HTTP $CODE, beklenen 401/403)"
fi

# --- 5) mass assignment: kayit sirasinda role alani gonderme ---
MA_EMAIL="sec-t5-massassign-$RUN@bingol.edu.tr"
mk_user_resp=$(curl -s -X POST -H 'Content-Type: application/json' "$A/auth/register" \
  -d "{\"email\":\"$MA_EMAIL\",\"password\":\"Sifre1234\",\"displayName\":\"MA\",\"acceptTerms\":true,\"role\":\"ADMIN\"}")
sleep 1
CODE=$(docker compose logs backend 2>&1 | grep "$MA_EMAIL icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
if [ -n "$CODE" ]; then
  MA_TOKEN=$(curl -s -X POST -H 'Content-Type: application/json' "$A/auth/verify-email" \
    -d "{\"email\":\"$MA_EMAIL\",\"code\":\"$CODE\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  ME=$(curl -s -H "Authorization: Bearer $MA_TOKEN" "$A/auth/me")
  if echo "$ME" | grep -q '"role":"ADMIN"'; then
    fail "KRITIK: kayitta 'role':'ADMIN' alani gonderilerek ADMIN rolu alindi (mass assignment) -> $ME"
  else
    pass "kayitta gonderilen 'role' alani yok sayildi -> $ME"
  fi
else
  info "mass-assignment testi icin dogrulama kodu okunamadi (log formati degisti olabilir); manuel kontrol gerekir"
fi

# --- 6) profilde mass assignment: PATCH /api/users/me ile role/id/email degistirme denemesi ---
CODE=$(curl -s -o /tmp/t5_patchself.json -w '%{http_code}' -X PATCH -H "Authorization: Bearer $VICTIM_TOKEN" \
  -H 'Content-Type: application/json' "$A/users/me" -d '{"role":"ADMIN","id":999999,"email":"hacked@bingol.edu.tr"}')
ROLE_AFTER=$(curl -s -H "Authorization: Bearer $VICTIM_TOKEN" "$A/auth/me")
if echo "$ROLE_AFTER" | grep -q '"role":"ADMIN"'; then
  fail "KRITIK: PATCH /api/users/me ile 'role' alani kabul edilip ADMIN'e yukseldi"
else
  pass "PATCH /api/users/me rol/id/email alanlarini yok saydi (HTTP $CODE profil guncelleme), rol: $(echo "$ROLE_AFTER" | grep -o '\"role\":\"[A-Z]*\"')"
fi

# --- 7) Basic auth yonetici ucu: zayif/varsayilan kimlik bilgisi denemesi ---
for cred in "admin:admin" "admin:password" "admin:admin123"; do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' -u "$cred" "$A/admin/users?size=1")
  if [ "$CODE" = "200" ]; then
    fail "KRITIK: Basic auth yonetici ucu zayif kimlik bilgisiyle acildi: $cred"
  fi
done
pass "yaygin zayif Basic-auth kimlik bilgileri denendi (sonuc yukarida FINDING yoksa reddedildi)"

# --- 8) askiya alinan kullanicinin token'i hemen reddedilmeli ---
ADMIN_TOKEN=$(login "boss@bingol.edu.tr")
if [ -n "$ADMIN_TOKEN" ]; then
  ATTACKER_ID=$(jwt_sub "$ATTACKER_TOKEN")
  SUSP_CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H 'Content-Type: application/json' "$A/admin/users/$ATTACKER_ID/suspend" -d '{"reason":"T5 guvenlik testi"}')
  info "suspend cagrisi HTTP $SUSP_CODE (id=$ATTACKER_ID)"
  sleep 1
  CODE=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $ATTACKER_TOKEN" "$A/auth/me")
  if [ "$CODE" = "200" ]; then
    fail "YUKSEK: askiya alinan kullanicinin eski access token'i hala kabul ediliyor (HTTP 200)"
  else
    pass "askiya alinan kullanicinin token'i aninda reddedildi (HTTP $CODE)"
  fi
  curl -s -o /dev/null -X POST -H "Authorization: Bearer $ADMIN_TOKEN" "$A/admin/users/$ATTACKER_ID/unsuspend"
else
  info "admin (boss@bingol.edu.tr) login basarisiz; askiya alma testi atlandi (ADMIN_EMAILS kontrol edin)"
fi

echo "=== bitti ==="

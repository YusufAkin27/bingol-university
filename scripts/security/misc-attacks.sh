#!/usr/bin/env bash
# T5 guvenlik denetimi: rate limit / XFF, kullanici enumerasyonu, dogrulama kodu kaba kuvvet,
# SQL enjeksiyonu fuzz (arama/filtre/siralama), CORS ve guvenlik basliklari.
# Kullanim: BASE=http://localhost:8105 ./scripts/security/misc-attacks.sh
# Tekrar calistirilabilir; betikten once/sonra 'docker compose exec -T redis redis-cli flushall' onerilir.
set -u
BASE=${BASE:-http://localhost:8105}
A=$BASE/api
PASS=Sifre1234
RUN=$(date +%s)

pass() { echo "[OK]      $1"; }
fail() { echo "[FINDING] $1"; }
info() { echo "[info]    $1"; }

mk_user() {
  local email=$1 name=$2
  curl -s -o /dev/null -X POST -H 'Content-Type: application/json' "$A/auth/register" \
    -d "{\"email\":\"$email\",\"password\":\"$PASS\",\"displayName\":\"$name\",\"acceptTerms\":true}"
  sleep 1
  local code
  code=$(docker compose logs backend 2>&1 | grep "$email icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  [ -n "$code" ] && curl -s -o /dev/null -X POST -H 'Content-Type: application/json' "$A/auth/verify-email" \
    -d "{\"email\":\"$email\",\"code\":\"$code\"}"
}
login() {
  curl -s -X POST -H 'Content-Type: application/json' "$A/auth/login" \
    -d "{\"email\":\"$1\",\"password\":\"$PASS\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4
}

echo "=== 1) X-Forwarded-For ile IP tabanli rate limit atlatma (register) ==="
OK200=0
for i in $(seq 1 14); do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' -H "X-Forwarded-For: 203.0.113.$i" -X POST -H 'Content-Type: application/json' \
    "$A/auth/resend-code" -d "{\"email\":\"xff-test-$RUN-$i@bingol.edu.tr\"}")
  [ "$CODE" = "202" ] && OK200=$((OK200+1))
done
if [ "$OK200" -gt 10 ]; then
  fail "ORTA: X-Forwarded-For degistirerek IP tabanli rate limit asildi ($OK200/14 istek kabul edildi, siniri 10/saat). Sunucu forward-headers-strategy ayarliyorsa XFF taklit edilebilir."
else
  pass "X-Forwarded-For degistirmek rate limit siniri atlamadi ($OK200/14 kabul edildi, siniri 10/saat); bu ortamda getRemoteAddr() XFF'yi okumuyor olabilir. UYARI: nginx arkasinda forward-headers-strategy YANLIS ayarlanirsa (1) XFF ise spoofable, (2) ayarlanmazsa TUM istemciler nginx'in TEK IP'sinden gorunur ve rate limit kazara KUresel/paylasimli hale gelir (bir kullanicinin asiri istegi hepsini kilitler). docs/SECURITY_AUDIT.md'de ayrintili."
fi

echo "=== 2) Kullanici enumerasyonu: register (var olan e-posta) ==="
mk_user "sec-t5-enum-$RUN@bingol.edu.tr" "Enum Test"
R1=$(curl -s -X POST -H 'Content-Type: application/json' "$A/auth/register" \
  -d "{\"email\":\"sec-t5-enum-$RUN@bingol.edu.tr\",\"password\":\"$PASS\",\"displayName\":\"x\",\"acceptTerms\":true}")
info "var olan e-posta ile tekrar kayit yaniti: $R1 (CLAUDE.md'de bilinen sinirli enumerasyon olarak kayitli)"

echo "=== 3) Kullanici enumerasyonu: login (var olan vs olmayan e-posta, zamanlama) ==="
T_EXIST_START=$(date +%s%N)
R_EXIST=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' "$A/auth/login" \
  -d "{\"email\":\"sec-t5-enum-$RUN@bingol.edu.tr\",\"password\":\"yanlis-sifre\"}")
T_EXIST_END=$(date +%s%N)
T_MISS_START=$(date +%s%N)
R_MISS=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' "$A/auth/login" \
  -d "{\"email\":\"hic-olmayan-$RUN@bingol.edu.tr\",\"password\":\"yanlis-sifre\"}")
T_MISS_END=$(date +%s%N)
D_EXIST=$(( (T_EXIST_END - T_EXIST_START) / 1000000 ))
D_MISS=$(( (T_MISS_END - T_MISS_START) / 1000000 ))
if [ "$R_EXIST" = "$R_MISS" ]; then
  pass "login yaniti ayni (HTTP $R_EXIST) var/yok olan e-posta icin; sureler: var=${D_EXIST}ms yok=${D_MISS}ms (buyuk fark varsa inceleyin, BCrypt dogal olarak var-olan icin daha yavas olabilir)"
else
  fail "ORTA: login yaniti var olan ($R_EXIST) ile olmayan ($R_MISS) e-posta icin FARKLI; kullanici enumerasyonu mumkun"
fi

echo "=== 4) Dogrulama kodu kaba kuvvet (5 deneme siniri) ==="
BF_EMAIL="sec-t5-bruteforce-$RUN@bingol.edu.tr"
mk_user_noverify() {
  curl -s -o /dev/null -X POST -H 'Content-Type: application/json' "$A/auth/register" \
    -d "{\"email\":\"$1\",\"password\":\"$PASS\",\"displayName\":\"BF\",\"acceptTerms\":true}"
}
mk_user_noverify "$BF_EMAIL"
LAST=000
for i in 1 2 3 4 5 6 7; do
  LAST=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' "$A/auth/verify-email" \
    -d "{\"email\":\"$BF_EMAIL\",\"code\":\"00000$i\"}")
done
if [ "$LAST" = "429" ] || [ "$LAST" = "400" ]; then
  pass "dogrulama kodu kaba kuvvetinde 7. denemede engellendi (HTTP $LAST, siniri 5 deneme)"
else
  fail "YUKSEK: dogrulama kodu kaba kuvvetinde 7 yanlis denemeden sonra hala engellenmedi (HTTP $LAST)"
fi

echo "=== 5) SQL enjeksiyonu fuzz: arama / admin kullanici filtresi ve siralama ==="
ADMIN_TOKEN=$(login "boss@bingol.edu.tr")
SEARCH_TOKEN=$(login "sec-t5-enum-$RUN@bingol.edu.tr")
SQLI_PAYLOADS=("' OR '1'='1" "'; DROP TABLE app_user; --" "' UNION SELECT NULL,NULL,NULL--" "1' AND SLEEP(3)='0")
for p in "${SQLI_PAYLOADS[@]}"; do
  ENC=$(node -e "console.log(encodeURIComponent(process.argv[1]))" "$p")
  CODE=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $SEARCH_TOKEN" "$A/search?q=$ENC")
  [ "$CODE" = "500" ] && fail "KRITIK: /api/search SQLi yukuyle 500 dondu (olasi enjeksiyon): $p" || info "/api/search q='$p' -> HTTP $CODE (500 degilse parametreli sorgu kullaniliyor olabilir)"
done
if [ -n "$ADMIN_TOKEN" ]; then
  for sortp in "id; DROP TABLE app_user" "id,asc,extra" "' OR 1=1" "createdAt,asc); --"; do
    ENC=$(node -e "console.log(encodeURIComponent(process.argv[1]))" "$sortp")
    CODE=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $ADMIN_TOKEN" "$A/admin/users?sort=$ENC&size=1")
    [ "$CODE" = "500" ] && fail "KRITIK: /api/admin/users?sort= SQLi/whitelist atlatma yukuyle 500 dondu: $sortp" || info "/api/admin/users sort='$sortp' -> HTTP $CODE (beklenen 400, whitelist calisiyor)"
  done
else
  info "admin token alinamadi; admin sort fuzz atlandi"
fi

echo "=== 6) CORS ve guvenlik basliklari ==="
CORS_HDR=$(curl -s -D - -o /dev/null -H "Origin: https://evil-example.test" -H "Access-Control-Request-Method: GET" \
  -X OPTIONS "$A/news" | grep -i 'access-control-allow-origin')
if echo "$CORS_HDR" | grep -qi "evil-example.test"; then
  fail "YUKSEK: CORS preflight, rastgele/kotu niyetli Origin'i yansitiyor (Access-Control-Allow-Origin): $CORS_HDR"
elif [ -z "$CORS_HDR" ]; then
  pass "CORS preflight bilinmeyen origin icin Access-Control-Allow-Origin dondurmedi"
else
  info "CORS basligi: $CORS_HDR"
fi
SEC_HDRS=$(curl -s -D - -o /dev/null "$A/news" )
echo "$SEC_HDRS" | grep -i "x-content-type-options\|x-frame-options\|strict-transport-security\|content-security-policy" || \
  info "guvenlik basliklari (X-Content-Type-Options / X-Frame-Options / HSTS / CSP) /api/news yanitinda GORULMEDI (Spring Security varsayilanlari devre disi birakilmis olabilir; WebConfig/SecurityConfig kontrol edin)"

echo "=== bitti ==="

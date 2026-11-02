#!/usr/bin/env bash
# Okul numarasiyla kayit/giris + dogrulanmamis hesap (EMAIL_NOT_VERIFIED) duman testi.
# Kullanim: BASE=http://localhost:8080 ./scripts/smoke-student-number.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur). Kayit ucu IP basina saatte 10 ile sinirli:
# betikler arasinda `docker compose exec -T redis redis-cli flushall`.
# Kod "yeniden iste" beklemesi (varsayilan 180 sn): yigini CODE_RESEND_COOLDOWN_SECONDS=2 ile baslatin (bu betik de ayni
# degiskeni okur); kayit zaten beklemeyi baslatir, bu yuzden resend-code once 429, sure dolunca 202 beklenir.
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0
NUM=9$(printf '%08d' $(( (RANDOM * 32768 + RANDOM) % 100000000 )))
MAIL=$NUM@bingol.edu.tr

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
post()  { # post yol govde -> "kod govde"
  local f; f=$(mktemp)
  printf '%s' "$2" > "$f"
  curl -s -w '\n%{http_code}' -X POST -H "$H" "$A$1" --data-binary @"$f"
  rm -f "$f"
}
status() { echo "$1" | tail -1; }
body()   { echo "$1" | head -n -1; }

echo "== kayit (okul numarasi: $NUM)"
R=$(post /auth/register "{\"email\":\"$MAIL\",\"password\":\"Zk7-Qmv-Lpx92w\",\"displayName\":\"Numara Test\",\"acceptTerms\":true,\"language\":\"tr\"}")
check register 202 "$(status "$R")"
# Kayit yalniz tam e-posta ile (EMAIL_FULL_REQUIRED); numara yalniz giris/dogrulama kimligi olarak kullanilir
R=$(post /auth/register "{\"email\":\"$NUM\",\"password\":\"Zk7-Qmv-Lpx92w\",\"displayName\":\"Numara Test\",\"acceptTerms\":true}")
check register-number-only 400 "$(status "$R")"

echo "== dogrulanmamis: dogru sifre -> EMAIL_NOT_VERIFIED, yanlis sifre -> INVALID_CREDENTIALS"
R=$(post /auth/login "{\"email\":\"$NUM\",\"password\":\"Zk7-Qmv-Lpx92w\",\"client\":\"mobile\"}")
check login-unverified 403 "$(status "$R")"
echo "$(body "$R")" | grep -q EMAIL_NOT_VERIFIED && echo "  ok   kod EMAIL_NOT_VERIFIED" || { echo "  FAIL kod"; FAIL=1; }
R=$(post /auth/login "{\"email\":\"$NUM\",\"password\":\"Yanlis1234x\"}")
check login-wrong-pw 401 "$(status "$R")"
R=$(post /auth/login "{\"email\":\"900000000\",\"password\":\"Zk7-Qmv-Lpx92w\"}")
check login-unknown 401 "$(status "$R")"

echo "== gecersiz kimlik"
R=$(post /auth/login "{\"email\":\"12345\",\"password\":\"Zk7-Qmv-Lpx92w\"}")
check short-number 400 "$(status "$R")"

echo "== resend-code (bekleme dolmadan 429, sonra genel 202)"
CD_SEC=${CODE_RESEND_COOLDOWN_SECONDS:-2}
R=$(post /auth/resend-code "{\"email\":\"$NUM\"}")
check resend-early 429 "$(status "$R")"
sleep $((CD_SEC + 1))
R=$(post /auth/resend-code "{\"email\":\"$NUM\"}")
check resend 202 "$(status "$R")"

echo "== dogrulama (kod log'dan)"
sleep 2
CODE=$(docker compose logs backend 2>&1 | grep "$MAIL icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
R=$(post /auth/verify-email "{\"email\":\"$NUM\",\"code\":\"$CODE\",\"password\":\"Zk7-Qmv-Lpx92w\",\"client\":\"mobile\"}")
check verify-email 200 "$(status "$R")"

echo "== dogrulandiktan sonra numara ve tam e-posta ile giris"
R=$(post /auth/login "{\"email\":\"$NUM\",\"password\":\"Zk7-Qmv-Lpx92w\",\"client\":\"web\"}")
check login-number 200 "$(status "$R")"
R=$(post /auth/login "{\"email\":\"$MAIL\",\"password\":\"Zk7-Qmv-Lpx92w\",\"client\":\"web\"}")
check login-email 200 "$(status "$R")"
R=$(post /auth/register "{\"email\":\"$MAIL\",\"password\":\"Zk7-Qmv-Lpx92w\",\"displayName\":\"Numara Test\",\"acceptTerms\":true}")
check register-again 409 "$(status "$R")"

[ "$FAIL" = 0 ] && echo "TAMAM" || { echo "HATA VAR"; exit 1; }

#!/usr/bin/env bash
# Okul numarasiyla kayit/giris + dogrulanmamis hesap (EMAIL_NOT_VERIFIED) duman testi.
# Kullanim: BASE=http://localhost:8080 ./scripts/smoke-student-number.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur). Kayit ucu IP basina saatte 10 ile sinirli:
# betikler arasinda `docker compose exec -T redis redis-cli flushall`.
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
R=$(post /auth/register "{\"email\":\"$NUM\",\"password\":\"Sifre1234x\",\"displayName\":\"Numara Test\",\"acceptTerms\":true,\"language\":\"tr\"}")
check register 202 "$(status "$R")"

echo "== dogrulanmamis: dogru sifre -> EMAIL_NOT_VERIFIED, yanlis sifre -> INVALID_CREDENTIALS"
R=$(post /auth/login "{\"email\":\"$NUM\",\"password\":\"Sifre1234x\",\"client\":\"mobile\"}")
check login-unverified 403 "$(status "$R")"
echo "$(body "$R")" | grep -q EMAIL_NOT_VERIFIED && echo "  ok   kod EMAIL_NOT_VERIFIED" || { echo "  FAIL kod"; FAIL=1; }
R=$(post /auth/login "{\"email\":\"$NUM\",\"password\":\"Yanlis1234x\"}")
check login-wrong-pw 401 "$(status "$R")"
R=$(post /auth/login "{\"email\":\"900000000\",\"password\":\"Sifre1234x\"}")
check login-unknown 401 "$(status "$R")"

echo "== gecersiz kimlik"
R=$(post /auth/login "{\"email\":\"12345\",\"password\":\"Sifre1234x\"}")
check short-number 400 "$(status "$R")"

echo "== resend-code (genel 202)"
R=$(post /auth/resend-code "{\"email\":\"$NUM\"}")
check resend 202 "$(status "$R")"

echo "== dogrulama (kod log'dan)"
sleep 2
CODE=$(docker compose logs backend 2>&1 | grep "$MAIL icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
R=$(post /auth/verify-email "{\"email\":\"$NUM\",\"code\":\"$CODE\",\"client\":\"mobile\"}")
check verify-email 200 "$(status "$R")"

echo "== dogrulandiktan sonra numara ve tam e-posta ile giris"
R=$(post /auth/login "{\"email\":\"$NUM\",\"password\":\"Sifre1234x\",\"client\":\"web\"}")
check login-number 200 "$(status "$R")"
R=$(post /auth/login "{\"email\":\"$MAIL\",\"password\":\"Sifre1234x\",\"client\":\"web\"}")
check login-email 200 "$(status "$R")"
R=$(post /auth/register "{\"email\":\"$NUM\",\"password\":\"Sifre1234x\",\"displayName\":\"Numara Test\",\"acceptTerms\":true}")
check register-again 409 "$(status "$R")"

[ "$FAIL" = 0 ] && echo "TAMAM" || { echo "HATA VAR"; exit 1; }

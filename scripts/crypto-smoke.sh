#!/usr/bin/env bash
# T21 Asama 1 duman testi: V68 nesneleri, denetim tablosunun degistirilemezligi, yonetici cozme/anahtar uclari.
# Kullanim: BASE=http://localhost:8121 COMPOSE_PROJECT_NAME=wt_t21 ./scripts/crypto-smoke.sh
# Onkosul: calisan compose yigini (postgres, redis, backend), MAIL_ENABLED=false, ADMIN_EMAILS=boss@bingol.edu.tr.
# Tekrar calistirilabilir: her seferinde benzersiz kullanici; yalnizca test denetim satirlari eklenir (silinemez, beklenen).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0
PSQL="docker compose exec -T postgres psql -U bingol -d bingol -tA"

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 300)"; FAIL=1; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

token() { # e-posta -> access token (kayit + dogrulama, varsa giris)
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"Crypto Test\",\"acceptTerms\":true}"
  sleep 1
  CODE=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  T=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$CODE\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  [ -z "$T" ] && T=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  echo "$T"
}

echo "== V68 nesneleri =="
check "conversation_key tablosu" "1" "$($PSQL -c "select count(*) from information_schema.tables where table_name='conversation_key'")"
check "message_access_audit tablosu" "1" "$($PSQL -c "select count(*) from information_schema.tables where table_name='message_access_audit'")"
check "tetikleyiciler" "2" "$($PSQL -c "select count(*) from pg_trigger where tgname like 'trg_message_access_audit_no_%'")"

echo "== Yetki =="
ADMIN=$(token "$ADMIN_EMAIL")
USER=$(token "crypto-user-$RANDOM$RANDOM@bingol.edu.tr")
[ -n "$ADMIN" ] && [ -n "$USER" ] || { echo "  FAIL token alinamadi"; exit 1; }
check "anonim decrypt -> 401/403" "1" "$([ "$(code -X POST -H "$H" $A/admin/messages/decrypt -d '{}')" -ge 401 ] && echo 1 || echo 0)"
check "normal kullanici decrypt -> 403" "403" "$(code -X POST -H "$H" -H "Authorization: Bearer $USER" $A/admin/messages/decrypt -d '{}')"
check "normal kullanici status -> 403" "403" "$(code -H "Authorization: Bearer $USER" $A/admin/crypto/status)"

echo "== Durum ve dogrulamalar =="
ST=$(curl -s -H "Authorization: Bearer $ADMIN" $A/admin/crypto/status)
has "status activeKeyId" '"activeKeyId"' "$ST"
has "status sir icermez" '"dekCountsByMasterKey"' "$ST"
R=$(curl -s -w ' %{http_code}' -X POST -H "$H" -H "Authorization: Bearer $ADMIN" $A/admin/messages/decrypt -d '{"conversationId":1,"fromMessageId":1,"reason":"kisa"}')
has "kisa gerekce reddi" 'DECRYPT_REASON_REQUIRED' "$R"
R=$(curl -s -X POST -H "$H" -H "Authorization: Bearer $ADMIN" $A/admin/messages/decrypt -d '{"fromMessageId":1,"reason":"yeterince uzun gerekce"}')
has "aralik reddi" 'DECRYPT_RANGE_INVALID' "$R"
R=$(curl -s -H "Accept-Language: en" -X POST -H "$H" -H "Authorization: Bearer $ADMIN" $A/admin/messages/decrypt -d '{"conversationId":1,"fromMessageId":1,"reason":"x"}')
has "ingilizce hata metni" 'at least' "$R"
R=$(curl -s -H "Accept-Language: ar" -X POST -H "$H" -H "Authorization: Bearer $ADMIN" $A/admin/messages/decrypt -d '{"conversationId":1,"fromMessageId":1,"reason":"x"}')
has "arapca hata kodu" 'DECRYPT_REASON_REQUIRED' "$R"
# Asama 1'de MessageReader baglanmamistir: gecerli istek 501 doner ve denetim satiri YAZILMAZ.
BEFORE=$($PSQL -c "select count(*) from message_access_audit")
check "okuyucu yok -> 501" "501" "$(code -X POST -H "$H" -H "Authorization: Bearer $ADMIN" $A/admin/messages/decrypt -d '{"conversationId":1,"fromMessageId":1,"reason":"yeterince uzun gerekce"}')"
check "501'de denetim satiri yok" "$BEFORE" "$($PSQL -c "select count(*) from message_access_audit")"

echo "== Rotasyon ucu =="
check "rewrap bilinmeyen anahtar -> 400" "400" "$(code -X POST -H "$H" -H "Authorization: Bearer $ADMIN" $A/admin/crypto/rewrap -d '{"targetKeyId":"yok-boyle-anahtar"}')"
R=$(curl -s -X POST -H "$H" -H "Authorization: Bearer $ADMIN" $A/admin/crypto/rewrap -d '{}')
has "rewrap sonucu" '"rewrapped"' "$R"

echo "== Denetim tablosu degistirilemez =="
UID_=$($PSQL -c "select id from app_user where email='$ADMIN_EMAIL'")
$PSQL -c "insert into message_access_audit (admin_id, conversation_id, message_count, reason) values ($UID_, 0, 0, 'duman testi satiri xxxx')" >/dev/null
check "ekleme calisir" "1" "$($PSQL -c "select count(*)>0 from message_access_audit where reason='duman testi satiri xxxx'" | sed 's/t/1/;s/f/0/')"
OUT=$($PSQL -c "update message_access_audit set reason='degistirildi!!!' where reason='duman testi satiri xxxx'" 2>&1)
has "UPDATE engelli" 'append-only' "$OUT"
OUT=$($PSQL -c "delete from message_access_audit where reason='duman testi satiri xxxx'" 2>&1)
has "DELETE engelli" 'append-only' "$OUT"
OUT=$($PSQL -c "truncate message_access_audit" 2>&1)
has "TRUNCATE engelli" 'append-only' "$OUT"
OUT=$($PSQL -c "insert into message_access_audit (admin_id, conversation_id, message_count, reason) values ($UID_, 0, 0, 'kisa')" 2>&1)
has "kisa gerekce CHECK" 'violates check constraint' "$OUT"

[ $FAIL -eq 0 ] && echo "TAMAM: crypto-smoke" || { echo "BASARISIZ: crypto-smoke"; exit 1; }

#!/usr/bin/env bash
# T21 Asama 2 dogrulamasi: gonderilen mesaj metni veritabaninda, Redis kanalinda, bildirim tablosunda ve gunlukte
# DUZ METIN olarak bulunmaz; alici/yonetici/KVKK disa aktarimi ise duz metni dogru gorur.
# 1) iki kullanici + benzersiz "kanarya" cumleyle mesaj (REST: POST /api/conversations/{id}/messages {text, clientId})
# 2) pg_dump --data-only icinde kanarya YOK (hem duz hem hex); message.body bos, body_ciphertext dolu
# 3) message_access ve notification tablolarinda kanarya YOK; bildirim govdesi sabit "Yeni mesaj"
# 4) Redis chat:events dinlenir (kanal 6 sn): kanarya YOK
# 5) alici gecmisten duz metni okur; yonetici POST /api/admin/messages/decrypt ile okur ve denetim satiri +1 olur;
#    KVKK disa aktarim (GET /api/users/me/export) duz metni icerir; backend gunlugunde kanarya YOK
# Kullanim: BASE=http://localhost:8121 COMPOSE_PROJECT_NAME=wt_t21 ./scripts/crypto-no-plaintext.sh
# Onkosul: yigin calisiyor, MAIL_ENABLED=false, ADMIN_EMAILS=boss@bingol.edu.tr, app.push.message-preview=false (varsayilan).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0
PSQL="docker compose exec -T postgres psql -U bingol -d bingol -tA"
check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

token() { # e-posta, ad -> access token
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  CODE=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  T=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$CODE\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  [ -z "$T" ] && T=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  echo "$T"
}

S=$RANDOM$RANDOM
TA=$(token "enc-a-$S@bingol.edu.tr" "Enc A"); TB=$(token "enc-b-$S@bingol.edu.tr" "Enc B"); TADM=$(token "$ADMIN_EMAIL" "Boss")
[ -n "$TA" ] && [ -n "$TB" ] && [ -n "$TADM" ] || { echo "FAIL token alinamadi"; exit 1; }
IDB=$(curl -s -H "Authorization: Bearer $TB" $A/profile | idof)
CANARY="KANARYA-gizli-cumle-$S-zebra-kuantum"
HEX=$(printf '%s' "KANARYA-gizli-cumle-$S" | od -An -tx1 | tr -d ' \n')

CONV=$(curl -s -X POST -H "$H" -H "Authorization: Bearer $TA" $A/conversations -d "{\"userId\":$IDB}" | idof)
[ -n "$CONV" ] || { echo "FAIL konusma acilamadi"; exit 1; }

# Redis kanalini dinle (arka planda), sonra mesaji gonder
REDISLOG=$(mktemp)
( docker compose exec -T redis timeout 8 redis-cli subscribe chat:events > "$REDISLOG" 2>&1 & )
sleep 2
SEND=$(curl -s -w ' %{http_code}' -X POST -H "$H" -H "Authorization: Bearer $TA" $A/conversations/$CONV/messages \
  -d "{\"text\":\"$CANARY\",\"clientId\":\"enc-$S\"}")
check "mesaj gonderildi" "201" "${SEND##* }"
MID=$(echo "${SEND% *}" | idof)
sleep 7

echo "== Veritabani =="
DUMP=$(docker compose exec -T postgres pg_dump -U bingol -d bingol --data-only 2>/dev/null)
check "pg_dump bos degil" "1" "$([ -n "$DUMP" ] && echo 1 || echo 0)"
check "kanarya dokumde yok" "0" "$(echo "$DUMP" | grep -c "$CANARY")"
check "kanarya hex bicimde de yok" "0" "$(echo "$DUMP" | grep -ci "$HEX")"
check "message.body bos" "" "$($PSQL -c "select coalesce(body,'') from message where id=$MID" 2>/dev/null)"
check "sifreli sutunlar dolu" "t" "$($PSQL -c "select body_ciphertext is not null and length(body_nonce)=12 and key_version>=1 from message where id=$MID")"
check "bildirim govdesi sabit" "Yeni mesaj" "$($PSQL -c "select body from notification where type='MESSAGE' order by id desc limit 1" | head -1)"
check "hicbir mesaj duz metin birakmadi" "0" "$($PSQL -c "select count(*) from message where body is not null")"
check "konusma anahtari var" "1" "$($PSQL -c "select count(*) from conversation_key where conversation_id=$CONV")"

echo "== Redis =="
check "kanalda olay goruldu" "1" "$(grep -c 'v1\.' "$REDISLOG" | sed 's/^0$/0/;s/^[1-9].*/1/')"
check "kanalda kanarya yok" "0" "$(grep -c "$CANARY" "$REDISLOG")"
rm -f "$REDISLOG"

echo "== API gidis-donus =="
GOT=$(curl -s -H "Authorization: Bearer $TB" "$A/conversations/$CONV/messages")
check "alici duz metni gorur" "1" "$(echo "$GOT" | grep -qF "$CANARY" && echo 1 || echo 0)"
EXP=$(curl -s -H "Authorization: Bearer $TA" $A/users/me/export)
check "KVKK disa aktarim cozulmus metni icerir" "1" "$(echo "$EXP" | grep -qF "$CANARY" && echo 1 || echo 0)"

echo "== Yonetici cozme =="
BEFORE=$($PSQL -c "select count(*) from message_access_audit")
R=$(curl -s -w ' %{http_code}' -X POST -H "$H" -H "Authorization: Bearer $TADM" $A/admin/messages/decrypt \
  -d "{\"conversationId\":$CONV,\"fromMessageId\":$MID,\"reason\":\"duman testi gerekcesi $S\"}")
check "yonetici cozme 200" "200" "${R##* }"
check "yanitta duz metin" "1" "$(echo "$R" | grep -qF "$CANARY" && echo 1 || echo 0)"
check "denetim satiri eklendi" "$((BEFORE + 1))" "$($PSQL -c "select count(*) from message_access_audit")"
check "denetim gerekce kaydi" "1" "$($PSQL -c "select count(*) from message_access_audit where reason like '%$S' and conversation_id=$CONV")"
R=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "$H" -H "Authorization: Bearer $TA" $A/admin/messages/decrypt \
  -d "{\"conversationId\":$CONV,\"fromMessageId\":$MID,\"reason\":\"yetkisiz deneme gerekcesi\"}")
check "normal kullanici cozemez" "403" "$R"

echo "== Gunluk =="
check "kanarya backend gunlugunde yok" "0" "$(docker compose logs backend 2>&1 | grep -c "$CANARY")"

[ $FAIL -eq 0 ] && echo "TAMAM: crypto-no-plaintext" || { echo "BASARISIZ: crypto-no-plaintext"; exit 1; }

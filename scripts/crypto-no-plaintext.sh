#!/usr/bin/env bash
# T21 (Asama 2 sonrasi calistirilir): gonderilen mesaj metninin veritabaninda DUZ METIN olarak bulunmadigini psql ile dogrular.
# 1) iki kullanici arasinda benzersiz bir "kanarya" cumleyle mesaj gonderir (REST)
# 2) tum veritabani dokumunde (pg_dump) kanaryayi arar: bulunmamali
# 3) message tablosunda duz metin sutunu kalmamis olmali (body/content/text benzeri); sifreli sutunlar dolu olmali
# 4) kullanici mesaji API'den dogru okunur (gidis-donus)
# Kullanim: BASE=http://localhost:8121 COMPOSE_PROJECT_NAME=wt_t21 ./scripts/crypto-no-plaintext.sh
# Onkosul: mesajlasma entegrasyonu (Asama 2) birlesmis, yigin calisiyor, MAIL_ENABLED=false.
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0
PSQL="docker compose exec -T postgres psql -U bingol -d bingol -tA"
check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }

token() {
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  CODE=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  T=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$CODE\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  [ -z "$T" ] && T=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  echo "$T"
}

S=$RANDOM$RANDOM
EA="enc-a-$S@bingol.edu.tr"; EB="enc-b-$S@bingol.edu.tr"
TA=$(token "$EA" "Enc A"); TB=$(token "$EB" "Enc B")
[ -n "$TA" ] && [ -n "$TB" ] || { echo "FAIL token"; exit 1; }
IDB=$(curl -s -H "Authorization: Bearer $TB" $A/users/me | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)

CANARY="KANARYA-gizli-cumle-$S-zebra-kuantum"
# NOT: uc noktalar Asama 2'de netlesir (mevcut messaging API'sine gore: konusma ac + mesaj gonder)
CONV=$(curl -s -X POST -H "$H" -H "Authorization: Bearer $TA" $A/conversations -d "{\"type\":\"DIRECT\",\"userId\":$IDB}" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
curl -s -o /dev/null -X POST -H "$H" -H "Authorization: Bearer $TA" $A/conversations/$CONV/messages -d "{\"body\":\"$CANARY\"}"

echo "== Veritabani dokumunde duz metin yok =="
DUMP=$(docker compose exec -T postgres pg_dump -U bingol -d bingol --data-only 2>/dev/null)
check "pg_dump bos degil" "1" "$([ -n "$DUMP" ] && echo 1 || echo 0)"
check "kanarya dokumde yok" "0" "$(echo "$DUMP" | grep -c "$CANARY")"
check "kanarya base64/hex bicimde de yok" "0" "$(echo "$DUMP" | grep -c "$(printf '%s' "$CANARY" | od -An -tx1 | tr -d ' \n' | head -c 24)")"

echo "== Sema =="
check "duz metin sutunu yok" "0" "$($PSQL -c "select count(*) from information_schema.columns where table_name='message' and column_name in ('body','content','text','plain_body')")"
check "sifreli sutunlar var" "3" "$($PSQL -c "select count(*) from information_schema.columns where table_name='message' and column_name in ('body_ciphertext','body_nonce','key_version')")"
check "sifreli satir dolu" "1" "$($PSQL -c "select count(*)>0 from message where body_ciphertext is not null and length(body_nonce)=12" | sed 's/t/1/;s/f/0/')"

echo "== API gidis-donus =="
GOT=$(curl -s -H "Authorization: Bearer $TB" "$A/conversations/$CONV/messages")
check "alici duz metni gorur" "1" "$(echo "$GOT" | grep -qF "$CANARY" && echo 1 || echo 0)"

echo "== Gunluk =="
check "kanarya backend gunlugunde yok" "0" "$(docker compose logs backend 2>&1 | grep -c "$CANARY")"

[ $FAIL -eq 0 ] && echo "TAMAM: crypto-no-plaintext" || { echo "BASARISIZ: crypto-no-plaintext"; exit 1; }

#!/usr/bin/env bash
# T24 yonetici sohbet goruntuleyici uctan uca betigi (CALISTIRILMADI - test asamasinda calistirilacak).
# Kapsam: kullanici bazli konusma listesi + mesaj sayfalama (before imleci), silinen mesajin yoneticide cozulu / kullanicida
# gizli / DB'de sifreli kalmasi, duzenleme gecmisi, otomatik degistirilemez denetim kaydi, IDOR (baska kullanicinin konusmasi 404),
# rol kontrolu (ADMIN disi 403), eski decrypt ucunun kaldirilmasi, KVKK disa aktarimda silinen mesajin olmamasi.
# Kullanim (kendi yiginin):
#   export COMPOSE_PROJECT_NAME=wt_t24 BACKEND_PORT=8124
#   docker compose up -d --build postgres redis backend
#   docker compose exec -T redis redis-cli flushall
#   BASE=http://localhost:8124 ./scripts/admin-chat-viewer-e2e.sh
# Onkosul: MAIL_ENABLED=false (dogrulama kodu log'dan okunur), ADMIN_EMAILS icinde boss@bingol.edu.tr.
# Kayit ucu IP basina saatte 10 ile sinirli (bu betik 4 kullanici acar) -> tekrar oncesi redis flushall.
set -u
BASE=${BASE:-http://localhost:8124}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0
PSQL="docker compose exec -T postgres psql -U bingol -d bingol -tA"
check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 300)"; FAIL=1; fi; }
hasnt() { if echo "$3" | grep -qF -- "$2"; then echo "  FAIL $1 (bulunmamali: $2)"; FAIL=1; else echo "  ok   $1"; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

token() { # e-posta, ad -> access token
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c t
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  t=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  [ -z "$t" ] && t=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  echo "$t"
}
uid() { curl -s -H "Authorization: Bearer $1" $A/profile | idof; }
send() { # token conv clientId text -> mesaj kimligi
  curl -s -X POST -H "$H" -H "Authorization: Bearer $1" $A/conversations/$2/messages -d "{\"text\":\"$4\",\"clientId\":\"$3\"}" | idof
}

S=$RANDOM$RANDOM
TA=$(token "chv-a-$S@bingol.edu.tr" "Chv A"); TB=$(token "chv-b-$S@bingol.edu.tr" "Chv B")
TC=$(token "chv-c-$S@bingol.edu.tr" "Chv C"); TADM=$(token "$ADMIN_EMAIL" "Boss")
[ -n "$TA" ] && [ -n "$TB" ] && [ -n "$TC" ] && [ -n "$TADM" ] || { echo "FAIL token alinamadi"; exit 1; }
IDA=$(uid "$TA"); IDB=$(uid "$TB"); IDC=$(uid "$TC")
AUTH_ADM="Authorization: Bearer $TADM"

echo "== Hazirlik: A<->B konusmasi, B<->C konusmasi =="
CONV=$(curl -s -X POST -H "$H" -H "Authorization: Bearer $TA" $A/conversations -d "{\"userId\":$IDB}" | idof)
CONV2=$(curl -s -X POST -H "$H" -H "Authorization: Bearer $TB" $A/conversations -d "{\"userId\":$IDC}" | idof)
[ -n "$CONV" ] && [ -n "$CONV2" ] || { echo "FAIL konusma acilamadi"; exit 1; }
KEEP="gorunen-mesaj-$S"
SECRET="silinen-gizli-cumle-$S-zebra"
OLDV="ilk-surum-$S"
NEWV="ikinci-surum-$S"
M1=$(send "$TA" $CONV "k1-$S" "$KEEP")
M2=$(send "$TB" $CONV "k2-$S" "$SECRET")
M3=$(send "$TA" $CONV "k3-$S" "$OLDV")
OTHER=$(send "$TB" $CONV2 "k4-$S" "baska-konusma-$S")
check "mesajlar gonderildi" "1" "$([ -n "$M1" ] && [ -n "$M2" ] && [ -n "$M3" ] && [ -n "$OTHER" ] && echo 1 || echo 0)"

echo "== B silsin, A duzenlesin =="
check "B kendi mesajini siler" "204" "$(code -X DELETE -H "Authorization: Bearer $TB" $A/messages/$M2)"
check "A mesajini duzenler" "200" "$(code -X PATCH -H "$H" -H "Authorization: Bearer $TA" $A/messages/$M3 -d "{\"text\":\"$NEWV\"}")"

echo "== Kullanici API'si: silinen govde yok =="
HIST=$(curl -s -H "Authorization: Bearer $TA" "$A/conversations/$CONV/messages")
has "kullanici silindi metnini gorur" "Bu mesaj silindi" "$HIST"
hasnt "kullanici silinen metni gormez" "$SECRET" "$HIST"
hasnt "kullanici eski surumu gormez" "$OLDV" "$HIST"

echo "== Veritabani: silinen govde SAKLANIR =="
check "silinen satir: sifreli govde dolu, deleted_at dolu" "t" "$($PSQL -c "select body_ciphertext is not null and deleted_at is not null and deleted_by=$IDB from message where id=$M2")"
check "duzenleme gecmisi satiri" "1" "$($PSQL -c "select count(*) from message_revision where message_id=$M3")"
check "DB'de duz metin yok" "0" "$($PSQL -c "select count(*) from message where convert_from(body_ciphertext,'SQL_ASCII') like '%$SECRET%'")"

echo "== Yonetici: konusma listesi =="
BEFORE=$($PSQL -c "select count(*) from message_access_audit")
L=$(curl -s -w ' %{http_code}' -H "$AUTH_ADM" "$A/admin/users/$IDA/conversations?size=20")
check "liste 200" "200" "${L##* }"
has "listede konusma" "\"id\":$CONV" "$L"
has "son mesaj onizlemesi cozulu" "$NEWV" "$L"
hasnt "baskasinin konusmasi listede yok" "\"id\":$CONV2" "$L"
check "liste denetim satiri (konusma basina)" "$((BEFORE + 1))" "$($PSQL -c "select count(*) from message_access_audit")"

echo "== Yonetici: mesajlar (silinen cozulu) =="
BEFORE=$($PSQL -c "select count(*) from message_access_audit")
R=$(curl -s -w ' %{http_code}' -H "$AUTH_ADM" "$A/admin/users/$IDA/conversations/$CONV/messages?size=50")
check "mesajlar 200" "200" "${R##* }"
has "gorunen mesaj" "$KEEP" "$R"
has "silinen mesaj yoneticide cozulu" "$SECRET" "$R"
has "silindi isareti" "\"deleted\":true" "$R"
has "duzenlenen: yeni surum" "$NEWV" "$R"
has "duzenleme gecmisi: eski surum" "$OLDV" "$R"
has "nextBefore alani" "\"nextBefore\"" "$R"
check "sayfa denetim satiri +1" "$((BEFORE + 1))" "$($PSQL -c "select count(*) from message_access_audit")"
check "denetim: hedef/kind/sabit gerekce" "1" "$($PSQL -c "select count(*) from message_access_audit where target_user_id=$IDA and conversation_id=$CONV and kind='VIEW_MESSAGES' and reason='yonetici sohbet goruntuleme' and admin_id is not null")"

echo "== Sayfalama (before imleci) =="
for i in $(seq 1 60); do send "$TA" $CONV "pg-$S-$i" "sayfa-mesaj-$i" >/dev/null; done
P1=$(curl -s -H "$AUTH_ADM" "$A/admin/users/$IDA/conversations/$CONV/messages?size=20")
NB=$(echo "$P1" | grep -o '"nextBefore":[0-9]*' | cut -d: -f2)
check "ilk sayfa nextBefore dolu" "1" "$([ -n "$NB" ] && echo 1 || echo 0)"
has "ilk sayfa en yeni mesaji icerir" "sayfa-mesaj-60" "$P1"
hasnt "ilk sayfa eski mesaji icermez" "sayfa-mesaj-1\"" "$P1"
P2=$(curl -s -H "$AUTH_ADM" "$A/admin/users/$IDA/conversations/$CONV/messages?before=$NB&size=20")
has "ikinci sayfa daha eski" "sayfa-mesaj-40" "$P2"
hasnt "ikinci sayfada ilk sayfanin mesaji yok" "sayfa-mesaj-60" "$P2"

echo "== Yetki / IDOR =="
check "ADMIN disi (kullanici) konusma listesi 403" "403" "$(code -H "Authorization: Bearer $TC" $A/admin/users/$IDA/conversations)"
check "ADMIN disi mesajlar 403" "403" "$(code -H "Authorization: Bearer $TC" $A/admin/users/$IDA/conversations/$CONV/messages)"
check "anonim 401/403" "1" "$([ "$(code $A/admin/users/$IDA/conversations)" -ge 401 ] && echo 1 || echo 0)"
BEFORE=$($PSQL -c "select count(*) from message_access_audit")
check "A'nin olmadigi konusma -> 404" "404" "$(code -H "$AUTH_ADM" $A/admin/users/$IDA/conversations/$CONV2/messages)"
check "olmayan kullanici -> 404" "404" "$(code -H "$AUTH_ADM" $A/admin/users/999999999/conversations)"
check "reddedilen istek denetim satiri yazmaz" "$BEFORE" "$($PSQL -c "select count(*) from message_access_audit")"
check "eski decrypt ucu kaldirildi" "1" "$([ "$(code -X POST -H "$H" -H "$AUTH_ADM" $A/admin/messages/decrypt -d '{}')" -ge 400 ] && echo 1 || echo 0)"

echo "== Denetim degistirilemez =="
$PSQL -c "update message_access_audit set ip='x' where id=(select max(id) from message_access_audit)" >/dev/null 2>&1
check "UPDATE reddedilir (cikis kodu 0 degil)" "1" "$([ $? -ne 0 ] && echo 1 || echo 0)"

echo "== KVKK disa aktarim: silinen mesaj yok =="
EXP=$(curl -s -H "Authorization: Bearer $TB" $A/users/me/export)
hasnt "B'nin disa aktarimi silinen mesaji icermez" "$SECRET" "$EXP"

[ $FAIL -eq 0 ] && echo "TAMAM: admin-chat-viewer-e2e" || { echo "BASARISIZ: admin-chat-viewer-e2e"; exit 1; }

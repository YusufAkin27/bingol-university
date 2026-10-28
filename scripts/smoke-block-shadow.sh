#!/usr/bin/env bash
# Golge engel (V260) duman betigi: engelliyken gonderim 201 ama karsi tarafa ulasmaz, bos profil, avatar null.
# Kullanim:
#   docker compose exec -T redis redis-cli flushall
#   BASE=http://localhost:8080 ./scripts/smoke-block-shadow.sh
# Onkosul: MAIL_ENABLED=false (kod backend log'undan okunur), node ve curl kurulu. 2 kullanici acar (kayit IP basina saatte 10).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0
RUN=$(date +%s)

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
jget() { node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{const j=JSON.parse(d);const v=process.argv[1].split('.').reduce((o,k)=>o==null?o:o[k],j);console.log(v===undefined||v===null?'':v)}catch(e){console.log('')}})" "$1"; }
# mesaj listesinden metin eslesen mesaj sayisi
count_text() { node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{const j=JSON.parse(d);console.log((j.items||[]).filter(m=>m.text===process.argv[1]).length)})" "$1"; }
status_of() { node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{const j=JSON.parse(d);const m=(j.items||[]).find(m=>m.text===process.argv[1]);console.log(m?(m.status||''):'YOK')})" "$1"; }

register() {
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c t
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  t=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  if [ -z "$t" ]; then
    t=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  fi
  echo "$t"
}

echo "== kullanicilar"
TA=$(register "shda${RUN}@bingol.edu.tr" "Golge A"); TB=$(register "shdb${RUN}@bingol.edu.tr" "Golge B")
[ -n "$TA" ] && [ -n "$TB" ] || { echo "  FAIL kayit"; exit 1; }
AUTH_A="Authorization: Bearer $TA"; AUTH_B="Authorization: Bearer $TB"
IDA=$(curl -s -H "$AUTH_A" $A/users/me | jget id); IDB=$(curl -s -H "$AUTH_B" $A/users/me | jget id)
CONV=$(curl -s -X POST -H "$H" -H "$AUTH_A" $A/conversations -d "{\"userId\":$IDB}" | jget id)
[ -n "$CONV" ] || { echo "  FAIL konusma"; exit 1; }
send() { curl -s -X POST -H "$H" -H "$1" $A/conversations/$CONV/messages -d "{\"text\":\"$2\",\"clientId\":\"$3-$RUN\"}"; }

echo "== engel oncesi normal"
send "$AUTH_A" "gorunur-1" a1 > /dev/null

echo "== B, A'yi engeller"
check "engelle" 204 "$(code -X POST -H "$AUTH_B" $A/users/$IDA/block)"

echo "== A yazar: hata yok, SENT, B'ye ulasmaz"
R=$(send "$AUTH_A" "golge-2" a2)
check "A gonderim 201" 201 "$(code -X POST -H "$H" -H "$AUTH_A" $A/conversations/$CONV/messages -d "{\"text\":\"golge-3\",\"clientId\":\"a3-$RUN\"}")"
check "gonderen durumu SENT" SENT "$(echo "$R" | jget status)"
check "A gecmiste kendi golge mesajini gorur" 1 "$(curl -s -H "$AUTH_A" $A/conversations/$CONV/messages | count_text golge-2)"
check "A'da golge mesaj SENT kalir" SENT "$(curl -s -H "$AUTH_A" $A/conversations/$CONV/messages | status_of golge-2)"
check "B gecmisinde golge mesaj yok" 0 "$(curl -s -H "$AUTH_B" $A/conversations/$CONV/messages | count_text golge-2)"
check "B gecmisinde onceki mesaj var" 1 "$(curl -s -H "$AUTH_B" $A/conversations/$CONV/messages | count_text gorunur-1)"
# engelleyen kullanici icin engellenenin mesajlari (onceki dahil) okunmamis sayacina girmez
check "B okunmamis sayaci 0 (engelli gonderen sayilmaz)" 0 "$(curl -s -H "$AUTH_B" $A/conversations/unread-count | jget total)"
LAST=$(curl -s -H "$AUTH_B" $A/conversations | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{const j=JSON.parse(d);const c=(j.items||[]).find(c=>String(c.id)==process.argv[1]);console.log(c&&c.lastMessage?c.lastMessage.text:'YOK')})" "$CONV")
check "B listesinde son mesaj onceki" gorunur-1 "$LAST"

echo "== B de yazabilir (iki yonlu kural), A'ya ulasmaz"
check "B gonderim 201" 201 "$(code -X POST -H "$H" -H "$AUTH_B" $A/conversations/$CONV/messages -d "{\"text\":\"engelleyen-4\",\"clientId\":\"b4-$RUN\"}")"
check "A gecmisinde engelleyenin mesaji yok" 0 "$(curl -s -H "$AUTH_A" $A/conversations/$CONV/messages | count_text engelleyen-4)"

echo "== profil ve avatar"
PROF=$(curl -s -H "$AUTH_A" $A/users/$IDB)
check "engelli profil 200 (404 degil)" 200 "$(code -H "$AUTH_A" $A/users/$IDB)"
check "profil avatarUrl bos" "" "$(echo "$PROF" | jget avatarUrl)"
check "profil bio bos" "" "$(echo "$PROF" | jget bio)"
check "profil adi kalir" "Golge B" "$(echo "$PROF" | jget displayName)"
check "konusma listesi peer avatar bos" "" "$(curl -s -H "$AUTH_A" $A/conversations | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{const j=JSON.parse(d);const c=(j.items||[]).find(c=>String(c.id)==process.argv[1]);console.log(c&&c.peer&&c.peer.avatarUrl||'')})" "$CONV")"

echo "== engel kalkinca eski golge mesajlar gizli kalir"
check "engel kaldir" 204 "$(code -X DELETE -H "$AUTH_B" $A/users/$IDA/block)"
check "B yine golge mesaji gormez" 0 "$(curl -s -H "$AUTH_B" $A/conversations/$CONV/messages | count_text golge-2)"
send "$AUTH_A" "normal-5" a5 > /dev/null
check "engelsiz yeni mesaj B'ye ulasir" 1 "$(curl -s -H "$AUTH_B" $A/conversations/$CONV/messages | count_text normal-5)"

if [ "$FAIL" = 0 ]; then echo "TUMU GECTI"; else echo "HATA VAR"; exit 1; fi

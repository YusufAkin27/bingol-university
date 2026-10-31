#!/usr/bin/env bash
# QA-ADVERSARIAL regresyon duman betigi: gizli hesap gorunurlugu, mesaj istegi kotu niyet senaryolari, surum kontrolu.
# Kullanim:
#   docker compose exec -T redis redis-cli flushall
#   BASE=http://localhost:8080 ./scripts/smoke-qa-private.sh
# Onkosul: MAIL_ENABLED=false (kod backend log'undan okunur), node ve curl. 5 kullanici acar (kayit IP basina saatte 10).
# Kapsam (QA bulgulari): (1) engelleyenin mesaj istegi kutusunda engellenenin istegi YOK, (2) yanitsiz istek siniri
# eszamanli gonderimde 3'u asmaz, (3) uzun surum numarasi 500 degil 400, (4) gizli hesap gonderisi yabancida
# akis/detay/medya/rapor/arama yollarinda gorunmez.
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0
RUN=$(date +%s)

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
jget() { node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{const j=JSON.parse(d);const v=process.argv[1].split('.').reduce((o,k)=>o==null?o:o[k],j);console.log(v===undefined||v===null?'':v)}catch(e){console.log('')}})" "$1"; }
# items icinde id'si verilen kayit var mi (0/1)
hasid() { node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{console.log((JSON.parse(d).items||[]).some(x=>String(x.id)===process.argv[1])?1:0)}catch(e){console.log('ERR')}})" "$1"; }

register() {
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Zk7-Qmv-Lpx92w\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c t
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  t=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Zk7-Qmv-Lpx92w\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  if [ -z "$t" ]; then
    t=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Zk7-Qmv-Lpx92w\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  fi
  echo "$t"
}

TMPD=$(mktemp -d)
printf 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' | base64 -d > "$TMPD/a.png"
TMPW=$(cygpath -m "$TMPD" 2>/dev/null || echo "$TMPD")

echo "== kullanicilar"
TP=$(register "qap${RUN}@bingol.edu.tr" "Gizli Yazar"); TS=$(register "qas${RUN}@bingol.edu.tr" "Yabanci Bir")
TF=$(register "qaf${RUN}@bingol.edu.tr" "Takipci Bir"); TB=$(register "qab${RUN}@bingol.edu.tr" "Engelli Bir")
TK=$(register "qak${RUN}@bingol.edu.tr" "Engelleyen Bir")
[ -n "$TP" ] && [ -n "$TS" ] && [ -n "$TF" ] && [ -n "$TB" ] && [ -n "$TK" ] || { echo "  FAIL kayit"; exit 1; }
AP="Authorization: Bearer $TP"; AS="Authorization: Bearer $TS"; AF="Authorization: Bearer $TF"; AB="Authorization: Bearer $TB"; AK="Authorization: Bearer $TK"
IDP=$(curl -s -H "$AP" $A/users/me | jget id); IDF=$(curl -s -H "$AF" $A/users/me | jget id)
IDB=$(curl -s -H "$AB" $A/users/me | jget id); IDK=$(curl -s -H "$AK" $A/users/me | jget id)

echo "== (4) gizli hesap gonderisi yabancida gorunmez"
curl -s -o /dev/null -X PUT -H "$H" -H "$AP" $A/users/me/privacy -d '{"privateAccount":true}'
MID=$(curl -s -X POST -H "$AP" -F "file=@$TMPW/a.png;type=image/png" $A/posts/media | jget id)
PID=$(curl -s -X POST -H "$AP" -H "$H" $A/posts -d "{\"text\":\"gizli gonderi\",\"mediaIds\":[$MID]}" | jget id)
[ -n "$PID" ] || { echo "  FAIL gonderi olusmadi"; exit 1; }
curl -s -o /dev/null -X POST -H "$AF" $A/users/$IDP/follow
curl -s -o /dev/null -X POST -H "$AP" $A/users/me/follow-requests/$IDF/accept
for sc in latest popular top following department; do
  check "yabanci $sc akisinda yok" 0 "$(curl -s -H "$AS" "$A/feed?scope=$sc&size=50" | hasid $PID)"
done
check "takipci latest akisinda var" 1 "$(curl -s -H "$AF" "$A/feed?scope=latest&size=50" | hasid $PID)"
check "yabanci GET /posts/{id} 404" 404 "$(code -H "$AS" $A/posts/$PID)"
check "takipci GET /posts/{id} 200" 200 "$(code -H "$AF" $A/posts/$PID)"
check "yabanci medya 404" 404 "$(code -H "$AS" $A/posts/media/$MID)"
check "yabanci medya thumb 404" 404 "$(code -H "$AS" "$A/posts/media/$MID?thumb=true")"
check "takipci medya 200" 200 "$(code -H "$AF" $A/posts/media/$MID)"
check "yabanci begeni 404" 404 "$(code -X PUT -H "$AS" $A/posts/$PID/like)"
RS=$(code -X POST -H "$H" -H "$AS" $A/reports -d "{\"targetType\":\"FEED_POST\",\"targetId\":$PID,\"reason\":\"SPAM\"}")
RN=$(code -X POST -H "$H" -H "$AS" $A/reports -d '{"targetType":"FEED_POST","targetId":999999,"reason":"SPAM"}')
check "gizli gonderi raporu olmayanla ayni kod" "$RN" "$RS"
check "takipci raporu 201" 201 "$(code -X POST -H "$H" -H "$AF" $A/reports -d "{\"targetType\":\"FEED_POST\",\"targetId\":$PID,\"reason\":\"SPAM\"}")"
check "yabanci genel aramada gonderi yok" 0 "$(curl -s -H "$AS" "$A/search?q=gizli+gonderi" | grep -c '"targetId":'"$PID"',')"

echo "== (1) engelleyenin istek kutusunda engellenenin istegi yok"
check "K, B yi engeller" 204 "$(code -X POST -H "$AK" $A/users/$IDB/block)"
R=$(curl -s -w ' %{http_code}' -X POST -H "$H" -H "$AB" $A/conversations -d "{\"userId\":$IDK}")
CID=$(echo "${R% *}" | jget id)
check "engelli B konusma acar (golge, 201)" 201 "${R##* }"
check "engelli B mesaj yazar (golge, 201)" 201 "$(code -X POST -H "$H" -H "$AB" $A/conversations/$CID/messages -d '{"text":"selam","clientId":"qb1"}')"
check "K istek sayaci 0" 0 "$(curl -s -H "$AK" $A/conversations/requests/count | jget count)"
check "K istek listesinde yok" 0 "$(curl -s -H "$AK" $A/conversations/requests | hasid $CID)"
check "K ana listede yok" 0 "$(curl -s -H "$AK" $A/conversations | hasid $CID)"

echo "== (2) eszamanli gonderimde yanitsiz istek siniri 3"
R=$(curl -s -X POST -H "$H" -H "$AS" $A/conversations -d "{\"userId\":$IDF}")
C2=$(echo "$R" | jget id)
# F, P'yi takip ediyor ama S ile baglami yok: S->F istek (F de S'yi takip etmiyor)
for i in 1 2 3 4 5 6 7 8; do
  curl -s -o "$TMPD/r$i" -w '%{http_code}\n' -X POST -H "$H" -H "$AS" $A/conversations/$C2/messages -d "{\"text\":\"yaris $i\",\"clientId\":\"qrace$i-$RUN\"}" > "$TMPD/c$i" &
done
wait
OKN=$(cat "$TMPD"/c? | grep -c '^201$')
if [ "$OKN" -le 3 ]; then echo "  ok   eszamanli 8 istekte en cok 3 mesaj kabul ($OKN)"; else echo "  FAIL eszamanli 8 istekte $OKN mesaj kabul edildi (en cok 3)"; FAIL=1; fi

echo "== (3) surum kontrolu: tasan surum 500 vermez"
check "uzun surum 400" 400 "$(code "$A/app/version?platform=android&version=99999999999999999999999.1")"
check "normal surum 200" 200 "$(code "$A/app/version?platform=android&version=2.0.4")"

rm -f "$TMPD"/* 2>/dev/null; rmdir "$TMPD" 2>/dev/null || true
if [ "$FAIL" = 0 ]; then echo "TAMAM"; else echo "BASARISIZ"; exit 1; fi

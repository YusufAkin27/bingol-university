#!/usr/bin/env bash
# FOLLOWREQ duman betigi: gizli hesap + takip istegi (V1020).
# Kullanim:
#   docker compose exec -T redis redis-cli flushall
#   BASE=http://localhost:8080 ./scripts/smoke-follow-requests.sh
# Onkosul: MAIL_ENABLED=false (kod backend log'undan okunur), node ve curl kurulu. 4 kullanici acar (kayit IP basina saatte 10).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0
RUN=$(date +%s)

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
jget() { node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{const j=JSON.parse(d);const v=process.argv[1].split('.').reduce((o,k)=>o==null?o:o[k],j);console.log(v===undefined||v===null?'':v)}catch(e){console.log('')}})" "$1"; }
# items dizisinin uzunlugu
ilen() { node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{console.log((JSON.parse(d).items||[]).length)}catch(e){console.log('ERR')}})"; }
# items icinde type'i verilen bildirim sayisi
ntype() { node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{console.log((JSON.parse(d).items||[]).filter(n=>n.type===process.argv[1]).length)}catch(e){console.log('ERR')}})" "$1"; }

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
TP=$(register "frqp${RUN}@bingol.edu.tr" "Gizli Hesap"); TR=$(register "frqr${RUN}@bingol.edu.tr" "Istekci Bir")
TS=$(register "frqs${RUN}@bingol.edu.tr" "Yabanci Uc"); TO=$(register "frqo${RUN}@bingol.edu.tr" "Acik Hesap")
[ -n "$TP" ] && [ -n "$TR" ] && [ -n "$TS" ] && [ -n "$TO" ] || { echo "  FAIL kayit"; exit 1; }
AP="Authorization: Bearer $TP"; AR="Authorization: Bearer $TR"; AS="Authorization: Bearer $TS"; AO="Authorization: Bearer $TO"
IDP=$(curl -s -H "$AP" $A/users/me | jget id); IDR=$(curl -s -H "$AR" $A/users/me | jget id)
IDS=$(curl -s -H "$AS" $A/users/me | jget id); IDO=$(curl -s -H "$AO" $A/users/me | jget id)

echo "== varsayilan herkese acik + acik hesap aninda takip"
check "privateAccount varsayilan false" false "$(curl -s -H "$AP" $A/users/me/privacy | jget privateAccount)"
R=$(curl -s -X POST -H "$AR" $A/users/$IDO/follow)
check "acik hesap FOLLOWING" FOLLOWING "$(echo "$R" | jget followState)"
check "acik hesap istek kutusu bos" 0 "$(curl -s -H "$AO" $A/users/me/follow-requests/count | jget count)"

echo "== hesabi gizli yap (PUT)"
check "PUT privacy 200" 200 "$(code -X PUT -H "$H" -H "$AP" $A/users/me/privacy -d '{"privateAccount":true}')"
check "privateAccount true" true "$(curl -s -H "$AP" $A/users/me/privacy | jget privateAccount)"

echo "== gizli hesaba takip = istek"
R=$(curl -s -X POST -H "$AR" $A/users/$IDP/follow)
check "followState REQUESTED" REQUESTED "$(echo "$R" | jget followState)"
check "following false" false "$(echo "$R" | jget following)"
R=$(curl -s -X POST -H "$AR" $A/users/$IDP/follow)
check "tekrar istek idempotent" REQUESTED "$(echo "$R" | jget followState)"
check "istek sayaci 1" 1 "$(curl -s -H "$AP" $A/users/me/follow-requests/count | jget count)"
check "istek listesi 1" 1 "$(curl -s -H "$AP" $A/users/me/follow-requests | ilen)"
check "istek satiri userId" "$IDR" "$(curl -s -H "$AP" $A/users/me/follow-requests | jget items.0.userId)"
check "hedefe FOLLOW_REQUEST bildirimi" 1 "$(curl -s -H "$AP" "$A/notifications?type=FOLLOW_REQUEST" | ntype FOLLOW_REQUEST)"
check "hedefe USER_FOLLOW bildirimi YOK" 0 "$(curl -s -H "$AP" "$A/notifications" | ntype USER_FOLLOW)"

echo "== profil kabugu ve kilit"
PR=$(curl -s -H "$AR" $A/users/$IDP)
check "isPrivate" true "$(echo "$PR" | jget isPrivate)"
check "istekci locked" true "$(echo "$PR" | jget locked)"
check "istekci followState" REQUESTED "$(echo "$PR" | jget followState)"
check "kilitli sayac gizli" "" "$(echo "$PR" | jget followerCount)"
check "yabanci followState NONE" NONE "$(curl -s -H "$AS" $A/users/$IDP | jget followState)"
check "kendi profili SELF" SELF "$(curl -s -H "$AP" $A/users/$IDP | jget followState)"
check "kilitli takipci listesi bos" 0 "$(curl -s -H "$AS" $A/users/$IDP/followers | ilen)"
check "kilitli takipci listesi locked" true "$(curl -s -H "$AS" $A/users/$IDP/followers | jget locked)"
check "kilitli gonderi listesi bos" 0 "$(curl -s -H "$AS" $A/users/$IDP/posts | ilen)"
check "kilitli gonderi listesi locked" true "$(curl -s -H "$AS" $A/users/$IDP/posts | jget locked)"

echo "== geri cek, tekrar iste"
R=$(curl -s -X DELETE -H "$AR" $A/users/$IDP/follow)
check "geri cekme NONE" NONE "$(echo "$R" | jget followState)"
check "istek sayaci 0" 0 "$(curl -s -H "$AP" $A/users/me/follow-requests/count | jget count)"
check "yeniden istek" REQUESTED "$(curl -s -X POST -H "$AR" $A/users/$IDP/follow | jget followState)"

echo "== kabul"
check "kabul 200" 200 "$(code -X POST -H "$AP" $A/users/me/follow-requests/$IDR/accept)"
check "kabul sonrasi sayac 0" 0 "$(curl -s -H "$AP" $A/users/me/follow-requests/count | jget count)"
check "kabul idempotent 200" 200 "$(code -X POST -H "$AP" $A/users/me/follow-requests/$IDR/accept)"
PR=$(curl -s -H "$AR" $A/users/$IDP)
check "takipci locked false" false "$(echo "$PR" | jget locked)"
check "takipci followState FOLLOWING" FOLLOWING "$(echo "$PR" | jget followState)"
check "istek sahibine FOLLOW_ACCEPTED bildirimi" 1 "$(curl -s -H "$AR" "$A/notifications?type=FOLLOW_ACCEPTED" | ntype FOLLOW_ACCEPTED)"
check "takipci listesi artik gorunur" 1 "$(curl -s -H "$AR" $A/users/$IDP/followers | ilen)"

echo "== takipten cikinca yeniden istek gerekir"
check "takibi birak NONE" NONE "$(curl -s -X DELETE -H "$AR" $A/users/$IDP/follow | jget followState)"
check "tekrar takip = REQUESTED" REQUESTED "$(curl -s -X POST -H "$AR" $A/users/$IDP/follow | jget followState)"

echo "== red sessiz"
check "red 200" 200 "$(code -X POST -H "$AP" $A/users/me/follow-requests/$IDR/decline)"
check "red sonrasi sayac 0" 0 "$(curl -s -H "$AP" $A/users/me/follow-requests/count | jget count)"
check "red sonrasi profil NONE" NONE "$(curl -s -H "$AR" $A/users/$IDP | jget followState)"

echo "== mesaj bildirimi kutuda yok (yalniz push)"
check "bildirim listesinde MESSAGE yok" 0 "$(curl -s -H "$AP" "$A/notifications" | ntype MESSAGE)"

echo "== gizli -> acik: bekleyen istekler otomatik kabul"
curl -s -o /dev/null -X POST -H "$AS" $A/users/$IDP/follow
check "yabanci istek" 1 "$(curl -s -H "$AP" $A/users/me/follow-requests/count | jget count)"
check "PUT privacy acik" 200 "$(code -X PUT -H "$H" -H "$AP" $A/users/me/privacy -d '{"privateAccount":false}')"
sleep 1
check "istek kutusu bosaldi" 0 "$(curl -s -H "$AP" $A/users/me/follow-requests/count | jget count)"
check "yabanci artik takipci" FOLLOWING "$(curl -s -H "$AS" $A/users/$IDP | jget followState)"

echo "== kendini takip ve oturumsuz"
check "kendini takip 400" 400 "$(code -X POST -H "$AP" $A/users/$IDP/follow)"
check "oturumsuz istek listesi 401" 401 "$(code $A/users/me/follow-requests)"

if [ "$FAIL" = 0 ]; then echo "TAMAM"; else echo "BASARISIZ"; exit 1; fi

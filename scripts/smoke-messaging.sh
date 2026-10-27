#!/usr/bin/env bash
# Mesajlasma REST akisi icin uctan uca duman testi (WebSocket icin: scripts/ws-test.js).
# Kullanim: BASE=http://localhost:8080 ./scripts/smoke-messaging.sh
# Onkosul: compose'ta MAIL_ENABLED=false (dogrulama kodu log'dan okunur), ADMIN_EMAILS=$ADMIN_EMAIL
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0

check() { # ad beklenen gercek
  if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi
}
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

register() { # email ad -> access token
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  local t
  t=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  # Hesap daha once olusturulmussa (ornegin smoke.sh calistiysa) giris yap
  [ -n "$t" ] || t=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  echo "$t"
}

SFX=$RANDOM
echo "== kullanicilar"
T1=$(register "mali$SFX@bingol.edu.tr" "Mesaj Ali"); T2=$(register "mayse$SFX@bingol.edu.tr" "Mesaj Ayse")
T3=$(register "mcan$SFX@bingol.edu.tr" "Mesaj Can"); TA=$(register "$ADMIN_EMAIL" "Yonetici" || true)
[ -n "$T1" ] && [ -n "$T2" ] && [ -n "$T3" ] || { echo "kayit basarisiz"; exit 1; }
ID1=$(curl -s -H "Authorization: Bearer $T1" $A/users/me | idof)
ID2=$(curl -s -H "Authorization: Bearer $T2" $A/users/me | idof)
ID3=$(curl -s -H "Authorization: Bearer $T3" $A/users/me | idof)
AUTH1="Authorization: Bearer $T1"; AUTH2="Authorization: Bearer $T2"; AUTH3="Authorization: Bearer $T3"

echo "== kimlik ve dogrulama"
check "girissiz liste 401" 401 "$(code $A/conversations)"
check "kendisiyle konusma 400" 400 "$(code -X POST -H "$H" -H "$AUTH1" $A/conversations -d "{\"userId\":$ID1}")"
check "olmayan kullanici 404" 404 "$(code -X POST -H "$H" -H "$AUTH1" $A/conversations -d '{"userId":99999999}')"
check "bos govde 400" 400 "$(code -X POST -H "$H" -H "$AUTH1" $A/conversations -d '{}')"

echo "== birebir konusma"
R=$(curl -s -w ' %{http_code}' -X POST -H "$H" -H "$AUTH1" $A/conversations -d "{\"userId\":$ID2}")
check "olustur 201" 201 "${R##* }"
CID=$(echo "$R" | idof)
R=$(curl -s -w ' %{http_code}' -X POST -H "$H" -H "$AUTH2" $A/conversations -d "{\"userId\":$ID1}")
check "karsi taraf ayni konusma 200" 200 "${R##* }"
check "ayni id" "$CID" "$(echo "$R" | idof)"
# yaris kosulu: es zamanli 8 istek tek konusma uretmeli
ID4=$(curl -s -H "$AUTH3" $A/users/me | idof)
for i in 1 2 3 4 5 6 7 8; do curl -s -o /dev/null -X POST -H "$H" -H "$AUTH3" $A/conversations -d "{\"userId\":$ID1}" & done; wait
N=$(curl -s -H "$AUTH3" $A/conversations | grep -o '"type":"DIRECT"' | wc -l)
check "yaris: mesajsiz konusma listede yok" 0 "$N"
C13A=$(curl -s -X POST -H "$H" -H "$AUTH3" $A/conversations -d "{\"userId\":$ID1}" | idof)
C13B=$(curl -s -X POST -H "$H" -H "$AUTH1" $A/conversations -d "{\"userId\":$ID3}" | idof)
check "yaris: tek konusma" "$C13A" "$C13B"

echo "== mesaj gonderme (REST)"
M=$(curl -s -w ' %{http_code}' -X POST -H "$H" -H "$AUTH1" $A/conversations/$CID/messages -d '{"text":"Merhaba <b>Ayse</b> & co","clientId":"c-1"}')
check "gonder 201" 201 "${M##* }"
MID=$(echo "$M" | idof)
M2=$(curl -s -w ' %{http_code}' -X POST -H "$H" -H "$AUTH1" $A/conversations/$CID/messages -d '{"text":"Merhaba <b>Ayse</b> & co","clientId":"c-1"}')
check "ayni clientId 200 (idempotent)" 200 "${M2##* }"
check "ayni mesaj id" "$MID" "$(echo "$M2" | idof)"
check "duz metin saklanir" 1 "$(echo "$M" | grep -c 'Merhaba <b>Ayse</b> & co')"
check "bos metin 400" 400 "$(code -X POST -H "$H" -H "$AUTH1" $A/conversations/$CID/messages -d '{"text":"   ","clientId":"c-2"}')"
LONG=$(head -c 2001 /dev/zero | tr '\0' 'a')
check "2001 karakter 400" 400 "$(code -X POST -H "$H" -H "$AUTH1" $A/conversations/$CID/messages -d "{\"text\":\"$LONG\",\"clientId\":\"c-3\"}")"
check "clientId yok 400" 400 "$(code -X POST -H "$H" -H "$AUTH1" $A/conversations/$CID/messages -d '{"text":"x"}')"
check "katilimci olmayan gonderemez 404" 404 "$(code -X POST -H "$H" -H "$AUTH3" $A/conversations/$CID/messages -d '{"text":"x","clientId":"c-4"}')"
check "katilimci olmayan gecmis goremez 404" 404 "$(code -H "$AUTH3" $A/conversations/$CID/messages)"
curl -s -o /dev/null -X POST -H "$H" -H "$AUTH2" $A/conversations/$CID/messages -d '{"text":"Selam Ali","clientId":"b-1"}'
# Kendi mesajini gondermek imleci ilerletir; Ayse icin 1 okunmamis mesaj kalmasi icin Ali bir daha yazar
check "ikinci mesaj" 201 "$(code -X POST -H "$H" -H "$AUTH1" $A/conversations/$CID/messages -d '{"text":"Ikinci mesaj","clientId":"c-7"}')"

echo "== gecmis ve liste"
H1=$(curl -s -H "$AUTH2" "$A/conversations/$CID/messages?size=1")
check "sayfa 1 oge" 1 "$(echo "$H1" | grep -o '"clientId"' | wc -l)"
NEXT=$(echo "$H1" | grep -o '"nextCursor":[0-9]*' | cut -d: -f2)
H2=$(curl -s -H "$AUTH2" "$A/conversations/$CID/messages?before=$NEXT&size=5")
check "onceki sayfa" 1 "$(echo "$H2" | grep -c 'c-1')"
check "before+after 400" 400 "$(code -H "$AUTH2" "$A/conversations/$CID/messages?before=5&after=1")"
check "after ile devam" 200 "$(code -H "$AUTH2" "$A/conversations/$CID/messages?after=$MID")"
L=$(curl -s -H "$AUTH2" $A/conversations)
check "liste okunmamis 1" 1 "$(echo "$L" | grep -c '"unreadCount":1')"
check "liste karsi taraf profili" 1 "$(echo "$L" | grep -c '"displayName":"Mesaj Ali"')"

echo "== okundu imleci"
LAST=$(curl -s -H "$AUTH2" "$A/conversations/$CID/messages?size=1" | idof)
check "okundu 204" 204 "$(code -X POST -H "$H" -H "$AUTH2" $A/conversations/$CID/read -d "{\"lastMessageId\":$LAST}")"
check "okunmamis 0" 1 "$(curl -s -H "$AUTH2" $A/conversations | grep -c '"unreadCount":0')"
check "geri gitmez (204)" 204 "$(code -X POST -H "$H" -H "$AUTH2" $A/conversations/$CID/read -d "{\"lastMessageId\":$MID}")"
check "imlec hala 0" 1 "$(curl -s -H "$AUTH2" $A/conversations | grep -c '"unreadCount":0')"
check "son mesaji asamaz 400" 400 "$(code -X POST -H "$H" -H "$AUTH2" $A/conversations/$CID/read -d "{\"lastMessageId\":$((LAST + 100000))}")"

echo "== presence"
check "ortak konusma: 200" 200 "$(code -H "$AUTH2" $A/users/$ID1/presence)"
check "ortak konusma yok: 404" 404 "$(code -H "$AUTH2" $A/users/$ID3/presence)"

echo "== engelleme"
check "engelle" 204 "$(code -X POST -H "$AUTH2" $A/users/$ID1/block)"
check "engelli gonderim 201 (golge engel, hata yok)" 201 "$(code -X POST -H "$H" -H "$AUTH1" $A/conversations/$CID/messages -d '{"text":"x","clientId":"c-5"}')"
check "engelleyen gonderim 201 (golge engel)" 201 "$(code -X POST -H "$H" -H "$AUTH2" $A/conversations/$CID/messages -d '{"text":"x","clientId":"b-5"}')"
check "engelli konusma yeniden acilir 200 (golge engel)" 200 "$(code -X POST -H "$H" -H "$AUTH1" $A/conversations -d "{\"userId\":$ID2}")"
check "engelli konusma listede blocked" 1 "$(curl -s -H "$AUTH2" $A/conversations | grep -c '"blocked":true')"
check "engelli presence 404" 404 "$(code -H "$AUTH2" $A/users/$ID1/presence)"
check "gecmis hala okunur" 200 "$(code -H "$AUTH2" $A/conversations/$CID/messages)"
check "engel kaldir" 204 "$(code -X DELETE -H "$AUTH2" $A/users/$ID1/block)"
check "tekrar gonderim" 201 "$(code -X POST -H "$H" -H "$AUTH1" $A/conversations/$CID/messages -d '{"text":"yine ben","clientId":"c-6"}')"

echo "== hiz limiti (dakikada 30)"
CODES=""
for i in $(seq 1 35); do
  CODES="$CODES $(code -X POST -H "$H" -H "$AUTH3" $A/conversations/$C13A/messages -d "{\"text\":\"m$i\",\"clientId\":\"rl-$i\"}")"
done
check "ilk 30 basarili" 30 "$(echo $CODES | tr ' ' '\n' | grep -c 201)"
check "sonrasi 429" 5 "$(echo $CODES | tr ' ' '\n' | grep -c 429)"
check "limitte tekrar gonderim yine idempotent" 200 "$(code -X POST -H "$H" -H "$AUTH3" $A/conversations/$C13A/messages -d '{"text":"m1","clientId":"rl-1"}')"

echo "== grup"
GR=$(curl -s -w ' %{http_code}' -X POST -H "$H" -H "$AUTH1" $A/conversations -d "{\"title\":\"Proje Grubu\",\"memberIds\":[$ID2,$ID3]}")
check "grup 201" 201 "${GR##* }"
GID=$(echo "$GR" | idof)
check "grup basligi bos 400" 400 "$(code -X POST -H "$H" -H "$AUTH1" $A/conversations -d "{\"title\":\"  \",\"memberIds\":[$ID2]}")"
check "uye olmayan baslik degistiremez 403" 403 "$(code -X PATCH -H "$H" -H "$AUTH2" $A/conversations/$GID -d '{"title":"Yeni"}')"
check "yonetici baslik degistirir" 200 "$(code -X PATCH -H "$H" -H "$AUTH1" $A/conversations/$GID -d '{"title":"Yeni Baslik"}')"
check "grupta mesaj" 201 "$(code -X POST -H "$H" -H "$AUTH2" $A/conversations/$GID/messages -d '{"text":"grup mesaji","clientId":"g-1"}')"
check "detay uyeler" 3 "$(curl -s -H "$AUTH1" $A/conversations/$GID | grep -o '"userId"' | wc -l)"
check "uye cikarma yalniz yonetici 403" 403 "$(code -X DELETE -H "$AUTH2" $A/conversations/$GID/members/$ID3)"
check "yonetici uye cikarir 204" 204 "$(code -X DELETE -H "$AUTH1" $A/conversations/$GID/members/$ID3)"
check "cikarilan gecmisi goremez 404" 404 "$(code -H "$AUTH3" $A/conversations/$GID/messages)"
check "uye ekle" 200 "$(code -X POST -H "$H" -H "$AUTH1" $A/conversations/$GID/members -d "{\"userIds\":[$ID3]}")"
check "yeni uye eski mesaji gormez" 0 "$(curl -s -H "$AUTH3" $A/conversations/$GID/messages | grep -c 'grup mesaji')"
check "ayril 204" 204 "$(code -X POST -H "$AUTH1" $A/conversations/$GID/leave)"
check "ayrilan erisemez 404" 404 "$(code -H "$AUTH1" $A/conversations/$GID/messages)"
check "yonetici devri: Ayse artik yonetici" 204 "$(code -X DELETE -H "$AUTH2" $A/conversations/$GID/members/$ID3)"
check "birebirde ayrilma 400" 400 "$(code -X POST -H "$AUTH2" $A/conversations/$CID/leave)"

echo "== rapor ve moderasyon"
check "mesaj raporla 201" 201 "$(code -X POST -H "$H" -H "$AUTH2" $A/messages/$MID/report -d '{"reason":"SPAM","note":"deneme"}')"
check "tekrar raporla 409" 409 "$(code -X POST -H "$H" -H "$AUTH2" $A/messages/$MID/report -d '{"reason":"SPAM"}')"
check "kendi mesajini raporlama 400" 400 "$(code -X POST -H "$H" -H "$AUTH1" $A/messages/$MID/report -d '{"reason":"SPAM"}')"
check "uye olmayan raporlayamaz 404" 404 "$(code -X POST -H "$H" -H "$AUTH3" $A/messages/$MID/report -d '{"reason":"SPAM"}')"
check "olmayan mesaj 404" 404 "$(code -X POST -H "$H" -H "$AUTH2" $A/messages/99999999/report -d '{"reason":"SPAM"}')"
if [ -n "${TA:-}" ]; then
  AUTHA="Authorization: Bearer $TA"
  RID=$(curl -s -H "$AUTHA" "$A/admin/reports?size=50" | grep -o "\"id\":[0-9]*,\"reporterId\":[0-9]*,\"targetType\":\"MESSAGE\",\"targetId\":$MID," | head -1 | grep -o '^"id":[0-9]*' | cut -d: -f2)
  check "admin kuyrukta mesaj raporu var" 1 "$([ -n "$RID" ] && echo 1 || echo 0)"
  check "raporu coz (gizle)" 204 "$(code -X POST -H "$H" -H "$AUTHA" $A/admin/reports/$RID/resolve -d '{"action":"HIDE"}')"
  HIDDEN=$(curl -s -H "$AUTH2" "$A/conversations/$CID/messages?size=10")
  check "gizlenen mesaj kaldirildi metni" 1 "$(echo "$HIDDEN" | grep -c 'Bu mesaj kaldırıldı')"
  check "gizlenen icerik sizmaz" 0 "$(echo "$HIDDEN" | grep -c 'Merhaba <b>Ayse')"
else
  echo "  atlandi: admin token yok (ADMIN_EMAILS ayarli mi?)"
fi

echo
if [ $FAIL = 0 ]; then echo "TUM KONTROLLER GECTI"; else echo "BAZI KONTROLLER BASARISIZ"; exit 1; fi

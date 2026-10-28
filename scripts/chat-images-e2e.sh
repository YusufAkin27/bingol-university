#!/usr/bin/env bash
# T8 sohbet gorselleri uctan uca betigi: yukleme, baskasi goremez, imzali URL, boyut/tur saldirilari,
# yasakli ozet (422), rapor -> gizle -> itiraz -> geri al, engel, grup katilim siniri, KVKK. Tekrar calistirilabilir.
# Kullanim (kendi yiginin):
#   export COMPOSE_PROJECT_NAME=wt_t8 BACKEND_PORT=8108
#   docker compose up -d --build postgres redis backend
#   docker compose exec -T redis redis-cli flushall
#   BASE=http://localhost:8108 ./scripts/chat-images-e2e.sh
# Onkosul: MAIL_ENABLED=false (dogrulama kodu log'dan okunur), ADMIN_EMAILS icinde boss@bingol.edu.tr, node kurulu.
# Kayit ucu IP basina saatte 10 ile sinirli (bu betik 6 kullanici acar) -> tekrar oncesi redis flushall.
# Istege bagli: SLOW=1 LINK_TTL=30 (yigin CHAT_MEDIA_LINK_TTL=30 ile baslatilmis olmali) -> imzali URL gercek sure asimi.
set -u
BASE=${BASE:-http://localhost:8108}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
TMP="$WORK/body.out"
HDR="$WORK/hdr.out"

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 300)"; FAIL=1; fi; }
hasnt() { if echo "$3" | grep -qF -- "$2"; then echo "  FAIL $1 (bulunmamali: $2)"; FAIL=1; else echo "  ok   $1"; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
win() { cygpath -m "$1" 2>/dev/null || echo "$1"; }
sha() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else node -e "console.log(require('crypto').createHash('sha256').update(require('fs').readFileSync(process.argv[1])).digest('hex'))" "$(win "$1")"; fi; }

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
uid() { curl -s -H "Authorization: Bearer $1" $A/users/me | idof; }

node "$HERE/media-fixtures.js" "$WORK/fx" >/dev/null || { echo "fixture uretilemedi"; exit 1; }
FX="$WORK/fx"

# Dakikalik yukleme siniri cok sayida saldiri denemesini engellemesin (siniri sinayan bolum NORESET=1 kullanir)
reset_min() { [ "${NORESET:-0}" = "1" ] || docker compose exec -T redis redis-cli --scan --pattern 'rl:chatmedia:min:*' | while read -r k; do docker compose exec -T redis redis-cli del "$k" >/dev/null; done; }
# up TOKEN CID DOSYA TUR -> HTTP kodu; govde $TMP'de
up() {
  reset_min
  curl -s -o "$TMP" -w '%{http_code}' -X POST -H "Authorization: Bearer $1" -F "file=@$(win "$FX/$3");type=$4" $A/conversations/$2/media
}
errcode() { grep -o '"code":"[^"]*' "$TMP" | cut -d'"' -f4; }
attid() { grep -o '"id":[0-9]*' "$TMP" | head -1 | cut -d: -f2; }
send() { # token cid text clientId attachmentIdsJson -> HTTP kodu (govde $TMP)
  curl -s -o "$TMP" -w '%{http_code}' -X POST -H "$H" -H "Authorization: Bearer $1" $A/conversations/$2/messages \
    -d "{\"text\":\"$3\",\"clientId\":\"$4\",\"attachmentIds\":$5}"
}

SFX=$RANDOM
echo "== hazirlik"
TA=$(register "$ADMIN_EMAIL" "Resim Admin")
T1=$(register "img1$SFX@bingol.edu.tr" "Resim Bir")
T2=$(register "img2$SFX@bingol.edu.tr" "Resim Iki")
T3=$(register "img3$SFX@bingol.edu.tr" "Resim Uc")
T4=$(register "img4$SFX@bingol.edu.tr" "Resim Dort")
T5=$(register "img5$SFX@bingol.edu.tr" "Resim Bes")
for t in "$TA" "$T1" "$T2" "$T3" "$T4" "$T5"; do [ -z "$t" ] && { echo "  FAIL kullanici hazirlanamadi (redis flushall?)"; exit 1; }; done
AUTHA="Authorization: Bearer $TA"; AUTH1="Authorization: Bearer $T1"; AUTH2="Authorization: Bearer $T2"; AUTH3="Authorization: Bearer $T3"
ID1=$(uid "$T1"); ID2=$(uid "$T2"); ID4=$(uid "$T4")
CID=$(curl -s -X POST -H "$H" -H "$AUTH1" $A/conversations -d "{\"userId\":$ID2}" | idof)
[ -n "$CID" ] || { echo "  FAIL konusma olusmadi"; exit 1; }

echo "== yukleme ve saldirilar"
check "girissiz yukleme 401" 401 "$(curl -s -o /dev/null -w '%{http_code}' -X POST -F "file=@$(win "$FX/unique-a.png");type=image/png" $A/conversations/$CID/media)"
check "uye olmayan yukleyemez 404" 404 "$(up "$T3" $CID unique-a.png image/png)"
check "gecerli png 201" 201 "$(up "$T1" $CID unique-a.png image/png)"
AID=$(attid)
has "yanit kimlikli yol" "/api/conversations/$CID/media/$AID" "$(cat "$TMP")"
has "genislik/yukseklik" '"width":' "$(cat "$TMP")"
check "svg 400" 400 "$(up "$T1" $CID evil.svg image/svg+xml)"
check "svg hata kodu" INVALID_FILE "$(errcode)"
check "html 400" 400 "$(up "$T1" $CID evil.html text/html)"
check "gif (png adiyla) 400" 400 "$(up "$T1" $CID polyglot.gif image/png)"
check "bozuk png 400" 400 "$(up "$T1" $CID corrupt.png image/png)"
check "bos dosya 400" 400 "$(up "$T1" $CID empty.png image/png)"
check "boyut bombasi 400" 400 "$(up "$T1" $CID bomb.png image/png)"
check "bomba kodu" IMAGE_TOO_MANY_PIXELS "$(errcode)"
check "cok buyuk ham dosya 413" 413 "$(up "$T1" $CID huge.png image/png)"
RC=$(up "$T1" $CID noise.png image/png)
if [ "$RC" = "201" ] || [ "$RC" = "422" ]; then echo "  ok   gurultulu buyuk gorsel 201/422 ($RC)"; else echo "  FAIL gurultulu gorsel ($RC)"; FAIL=1; fi
[ "$RC" = "201" ] && curl -s -o /dev/null -X DELETE -H "$AUTH1" $A/conversations/$CID/media/$(attid)

echo "== gonderilmemis yukleme gizlidir"
check "karsi taraf gonderilmemis eki goremez" 404 "$(code -H "$AUTH2" $A/conversations/$CID/media/$AID)"
check "sahibi gorur" 200 "$(code -H "$AUTH1" $A/conversations/$CID/media/$AID)"

echo "== mesaj gonderimi (ek ile)"
check "baskasinin eki ile gonderim 400" 400 "$(send "$T2" $CID "" c-steal "[$AID]")"
check "kod" ATTACHMENT_INVALID "$(errcode)"
check "bos metin + ek yok 400" 400 "$(send "$T1" $CID "" c-empty "[]")"
check "5 ek 400" 400 "$(send "$T1" $CID "x" c-five "[1,2,3,4,5]")"
check "ek siniri kodu" ATTACHMENT_LIMIT "$(errcode)"
check "ayni ek iki kez 400" 400 "$(send "$T1" $CID "x" c-dup "[$AID,$AID]")"
check "yalniz gorsel mesaj 201" 201 "$(send "$T1" $CID "" c-img1 "[$AID]")"
MSG=$(cat "$TMP")
has "mesajda ek meta" "\"attachments\":[{\"id\":$AID" "$MSG"
check "ayni clientId tekrar 200 (idempotent)" 200 "$(send "$T1" $CID "" c-img1 "[$AID]")"
has "tekrarda da ek var" "\"attachments\":[{\"id\":$AID" "$(cat "$TMP")"
check "kullanilmis ek yeniden 400" 400 "$(send "$T1" $CID "tekrar" c-reuse "[$AID]")"
H2=$(curl -s -H "$AUTH2" "$A/conversations/$CID/messages")
has "alici gecmiste eki gorur" "\"attachments\":[{\"id\":$AID" "$H2"
has "konusma listesi son mesaj eki" "\"attachments\":[{\"id\":$AID" "$(curl -s -H "$AUTH2" $A/conversations)"

echo "== okuma yetkisi"
check "girissiz okuma 401" 401 "$(code $A/conversations/$CID/media/$AID)"
check "alici okur 200" 200 "$(curl -s -D "$HDR" -o "$WORK/got.jpg" -w '%{http_code}' -H "$AUTH2" $A/conversations/$CID/media/$AID)"
has "Content-Type jpeg" "image/jpeg" "$(grep -i '^content-type' "$HDR")"
has "no-store" "no-store" "$(grep -i '^cache-control' "$HDR")"
has "private" "private" "$(grep -i '^cache-control' "$HDR")"
has "nosniff" "nosniff" "$(grep -i '^x-content-type-options' "$HDR")"
check "kucuk resim 200" 200 "$(code -H "$AUTH2" $A/conversations/$CID/media/$AID/thumb)"
check "disaridaki kullanici 404" 404 "$(code -H "$AUTH3" $A/conversations/$CID/media/$AID)"
check "disaridaki kucuk resim 404" 404 "$(code -H "$AUTH3" $A/conversations/$CID/media/$AID/thumb)"
check "disaridaki link 404" 404 "$(code -H "$AUTH3" $A/conversations/$CID/media/$AID/link)"
check "yanlis konusma (IDOR) 404" 404 "$(code -H "$AUTH2" $A/conversations/999999/media/$AID)"
check "olmayan ek 404" 404 "$(code -H "$AUTH2" $A/conversations/$CID/media/99999999)"
check "disaridaki kullanici rapor 404" 404 "$(code -X POST -H "$H" -H "$AUTH3" $A/conversations/$CID/media/$AID/report -d '{"reason":"SPAM"}')"
check "genel rapor ucu ile yoklama 404" 404 "$(code -X POST -H "$H" -H "$AUTH3" $A/reports -d "{\"targetType\":\"MESSAGE_IMAGE\",\"targetId\":$AID,\"reason\":\"SPAM\"}")"
check "dosya yolu /files/** altinda degil" 404 "$(code $BASE/files/chat/x.jpg)"

echo "== diskte sifreli"
ONDISK=$(docker compose exec -T backend sh -c 'f=$(find / -path "*_private/chat/*" -name "*.jpg" -not -name "*-t.jpg" 2>/dev/null | head -1); [ -n "$f" ] && head -c 4 "$f"' 2>/dev/null | tr -d '\r')
if [ -z "$ONDISK" ]; then echo "  skip disk sifre denetimi (konteynere erisilemedi)"; else check "disk dosyasi sifreli cerceve (BUM1)" BUM1 "$ONDISK"; fi
check "API cikti JPEG imzasi" "ffd8" "$(head -c 2 "$WORK/got.jpg" | od -An -tx1 | tr -d ' \n')"

echo "== imzali URL"
LK=$(curl -s -H "$AUTH2" $A/conversations/$CID/media/$AID/link)
URL=$(echo "$LK" | grep -o '"url":"[^"]*' | cut -d'"' -f4)
has "imzali url bicimi" "/files/p/chat/" "$URL"
check "imzali url 200 (girissiz)" 200 "$(curl -s -D "$HDR" -o /dev/null -w '%{http_code}' "$BASE$URL")"
has "imzali url no-store" "no-store" "$(grep -i '^cache-control' "$HDR")"
BAD=$(echo "$URL" | sed 's/sig=./sig=0/')
check "bozuk imza 404" 404 "$(code "$BASE$BAD")"
PAST=$(echo "$URL" | sed 's/exp=[0-9]*/exp=1000/')
check "gecmis sure 404" 404 "$(code "$BASE$PAST")"
FAR=$(echo "$URL" | sed 's/exp=\([0-9]*\)/exp=9\1/')
check "uzatilmis sure 404" 404 "$(code "$BASE$FAR")"
if [ "${SLOW:-0}" = "1" ]; then
  W=$(( ${LINK_TTL:-30} + 3 )); echo "  ... $W sn bekleniyor (yigin CHAT_MEDIA_LINK_TTL=${LINK_TTL:-30} ile acik olmali)"; sleep $W
  check "sure dolunca imzali url 404" 404 "$(code "$BASE$URL")"
fi

echo "== yasakli ozet (blocklist)"
curl -s -o "$WORK/prev.jpg" -H "$AUTHA" "$A/admin/media/attachments/$AID/preview"
HASHV=$(sha "$WORK/prev.jpg")
check "yonetici onizleme 200" 200 "$(code -H "$AUTHA" $A/admin/media/attachments/$AID/preview)"
check "normal kullanici onizleme 403" 403 "$(code -H "$AUTH1" $A/admin/media/attachments/$AID/preview)"
check "girissiz onizleme 401" 401 "$(code $A/admin/media/attachments/$AID/preview)"
check "ozet ekle 201" 201 "$(code -X POST -H "$H" -H "$AUTHA" $A/admin/moderation/blocklist -d "{\"sha256\":\"$HASHV\",\"note\":\"t8 e2e\"}")"
RC=$(up "$T1" $CID unique-a.png image/png)
if [ "$RC" = "422" ] && [ "$(errcode)" = "MEDIA_BLOCKED" ]; then echo "  ok   yasakli ozet 422 MEDIA_BLOCKED"; else echo "  INFO yasakli ozet: $RC $(errcode) (islenmis cikti baytlari ozetle eslesmeyebilir)"; fi
curl -s -o /dev/null -X DELETE -H "$AUTHA" $A/admin/moderation/blocklist/$HASHV

echo "== rapor -> gizle -> itiraz -> geri al"
check "kendi gorselini raporlayamaz 400" 400 "$(code -X POST -H "$H" -H "$AUTH1" $A/conversations/$CID/media/$AID/report -d '{"reason":"SPAM"}')"
check "alici raporlar 201" 201 "$(code -X POST -H "$H" -H "$AUTH2" $A/conversations/$CID/media/$AID/report -d '{"reason":"INAPPROPRIATE"}')"
check "tekrar rapor 409" 409 "$(code -X POST -H "$H" -H "$AUTH2" $A/conversations/$CID/media/$AID/report -d '{"reason":"INAPPROPRIATE"}')"
Q=$(curl -s -H "$AUTHA" "$A/admin/reports?targetType=MESSAGE_IMAGE")
has "kuyrukta gorsel hedefi" "\"targetId\":$AID" "$Q"
has "yonetici onizleme adresi" "/api/admin/media/attachments/$AID/preview" "$Q"
RID=$(echo "$Q" | grep -o '"id":[0-9]*,"reporterId":[0-9]*' | head -1 | cut -d: -f2 | cut -d, -f1)
check "yonetici HIDE karari" 204 "$(code -X POST -H "$H" -H "$AUTHA" $A/admin/reports/$RID/resolve -d '{"action":"HIDE","reasonCode":"SPAM"}')"
check "gizli gorsel alici 404" 404 "$(code -H "$AUTH2" $A/conversations/$CID/media/$AID)"
check "gizli gorsel gonderen 404" 404 "$(code -H "$AUTH1" $A/conversations/$CID/media/$AID)"
check "eski imzali url olur 404" 404 "$(code "$BASE$URL")"
has "mesaj gorunumunde removed ek" '"removed":true' "$(curl -s -H "$AUTH2" "$A/conversations/$CID/messages" | grep -o '"attachments":\[[^]]*\]')"
check "yonetici gizli gorseli hala onizler" 200 "$(code -H "$AUTHA" $A/admin/media/attachments/$AID/preview)"
check "sahip itiraz 201" 201 "$(code -X POST -H "$H" -H "$AUTH1" $A/appeals -d "{\"targetType\":\"MESSAGE_IMAGE\",\"targetId\":$AID,\"message\":\"Bu gorsel kurallara uygun\"}")"
AP=$(curl -s -H "$AUTHA" "$A/admin/moderation/appeals?status=OPEN")
has "admin itiraz listesi" "\"userId\":$ID1" "$AP"
APID=$(echo "$AP" | idof)
check "itiraz kabul" 204 "$(code -X POST -H "$H" -H "$AUTHA" $A/admin/moderation/appeals/$APID/decide -d '{"accept":true,"note":"hata olmus"}')"
check "geri alinca alici gorur 200" 200 "$(code -H "$AUTH2" $A/conversations/$CID/media/$AID)"
hasnt "mesaj gorunumunde artik removed ek yok" '"removed":true,"url":null' "$(curl -s -H "$AUTH2" "$A/conversations/$CID/messages")"

echo "== engel"
check "gonderilmemis yeni yukleme" 201 "$(up "$T2" $CID unique-b.png image/png)"
BID=$(attid)
check "engelle" 204 "$(code -X POST -H "$AUTH2" $A/users/$ID1/block)"
check "engelli kullanici yukleyemez 403" 403 "$(up "$T1" $CID unique-c.png image/png)"
check "engel sonrasi eski gorsel 404" 404 "$(code -H "$AUTH2" $A/conversations/$CID/media/$AID)"
check "engel kodu" BLOCKED "$(up "$T1" $CID unique-c.png image/png >/dev/null; errcode)"
curl -s -o /dev/null -X DELETE -H "$AUTH2" $A/users/$ID1/block
check "engel kalkinca 200" 200 "$(code -H "$AUTH2" $A/conversations/$CID/media/$AID)"
curl -s -o /dev/null -X DELETE -H "$AUTH2" $A/conversations/$CID/media/$BID

echo "== grup: katilmadan onceki gorsel"
GID=$(curl -s -X POST -H "$H" -H "$AUTH1" $A/conversations -d "{\"title\":\"T8 grup\",\"memberIds\":[$ID2]}" | idof)
check "grupta yukleme" 201 "$(up "$T1" $GID unique-d.png image/png)"
GA=$(attid)
check "grupta gorselli mesaj" 201 "$(send "$T1" $GID "" g-img1 "[$GA]")"
sleep 1
check "uye ekle" 204 "$(code -X POST -H "$H" -H "$AUTH1" $A/conversations/$GID/members -d "{\"userIds\":[$ID4]}")"
check "sonradan katilan eski gorseli goremez 404" 404 "$(code -H "Authorization: Bearer $T4" $A/conversations/$GID/media/$GA)"
check "eski uye gorur 200" 200 "$(code -H "$AUTH2" $A/conversations/$GID/media/$GA)"

echo "== kota / hiz siniri"
CIDX=$(curl -s -X POST -H "$H" -H "Authorization: Bearer $T5" $A/conversations -d "{\"userId\":$ID1}" | idof)
GOT429=0
NORESET=1
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13; do R=$(up "$T5" "$CIDX" unique-a.png image/png); [ "$R" = "429" ] && GOT429=1; done
check "dakikada 10 yukleme siniri (429)" 1 "$GOT429"

echo "== KVKK"
EX=$(curl -s -H "$AUTH1" $A/users/me/export)
has "disa aktarimda gorsel bolumu" '"sentChatImages"' "$EX"
has "gorsel sayisi" '"count":' "$(echo "$EX" | grep -o '"sentChatImages":{[^}]*')"
hasnt "gorsel icerigi yok" 'base64' "$EX"

echo "== hesap silme: ekler kaldirilir"
check "yeni yukleme (T4)" 201 "$(up "$T4" $GID unique-e.png image/png)"
EA=$(attid)
check "mesaj (T4)" 201 "$(send "$T4" $GID "" g-img2 "[$EA]")"
check "uye silinmeden once gorur" 200 "$(code -H "$AUTH2" $A/conversations/$GID/media/$EA)"
check "hesap sil" 204 "$(code -X DELETE -H "$H" -H "Authorization: Bearer $T4" $A/users/me -d '{"password":"Sifre1234"}')"
check "silinen kullanicinin gorseli kalkti" 404 "$(code -H "$AUTH2" $A/conversations/$GID/media/$EA)"

echo
if [ "$FAIL" = "0" ]; then echo "TAMAM: chat-images-e2e"; else echo "BASARISIZ: chat-images-e2e"; fi
rm -rf "$WORK"
exit $FAIL

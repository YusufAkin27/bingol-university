#!/usr/bin/env bash
# Yonetici sohbet izleme (V270) duman betigi: kullanici sohbet goruntuleyici kisitsiz gorunurluk, tek gosterimlik
# gorsel saklama, toplu ek/mesaj akisi, istatistik, sikayet baglami, yetki ve denetim.
# Kullanim:
#   docker compose exec -T redis redis-cli flushall
#   BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ./scripts/smoke-admin-chat.sh
# Onkosul: MAIL_ENABLED=false (kod backend log'undan okunur), ADMIN_EMAILS=$ADMIN_EMAIL, node ve curl kurulu.
# 3 kullanici acar (kayit IP basina saatte 10).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0
RUN=$(date +%s)
WORK=$(mktemp -d)

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has() { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 300)"; FAIL=1; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
jget() { node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{const j=JSON.parse(d);const v=process.argv[1].split('.').reduce((o,k)=>o==null?o:o[k],j);console.log(v===undefined||v===null?'':v)}catch(e){console.log('')}})" "$1"; }
win() { cygpath -m "$1" 2>/dev/null || echo "$1"; }

register() {
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c t
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  t=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  if [ -z "$t" ]; then
    t=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  fi
  echo "$t"
}

# gecerli 64x64 PNG uret (zlib + crc; dis bagimlilik yok)
node -e "
const z=require('zlib'),fs=require('fs');
const crcT=[];for(let n=0;n<256;n++){let c=n;for(let k=0;k<8;k++)c=c&1?0xedb88320^(c>>>1):c>>>1;crcT[n]=c>>>0}
const crc=b=>{let c=0xffffffff;for(const x of b)c=crcT[(c^x)&255]^(c>>>8);return (c^0xffffffff)>>>0};
const ch=(t,d)=>{const l=Buffer.alloc(4);l.writeUInt32BE(d.length);const td=Buffer.concat([Buffer.from(t),d]);const c=Buffer.alloc(4);c.writeUInt32BE(crc(td));return Buffer.concat([l,td,c])};
const w=64,h=64,raw=Buffer.alloc((w*3+1)*h);for(let y=0;y<h;y++){raw[y*(w*3+1)]=0;for(let x=0;x<w*3;x++)raw[y*(w*3+1)+1+x]=(x*7+y*13+${RUN})&255}
const ihdr=Buffer.alloc(13);ihdr.writeUInt32BE(w,0);ihdr.writeUInt32BE(h,4);ihdr[8]=8;ihdr[9]=2;
fs.writeFileSync(process.argv[1],Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),ch('IHDR',ihdr),ch('IDAT',z.deflateSync(raw)),ch('IEND',Buffer.alloc(0))]))
" "$WORK/a.png"

echo "== kullanicilar ve yonetici"
TA=$(register "adca${RUN}@bingol.edu.tr" "Chat A"); TB=$(register "adcb${RUN}@bingol.edu.tr" "Chat B")
TADM=$(register "$ADMIN_EMAIL" "Yonetici")
[ -n "$TA" ] && [ -n "$TB" ] && [ -n "$TADM" ] || { echo "  FAIL kayit/yonetici (ADMIN_EMAILS?)"; exit 1; }
AUTH_A="Authorization: Bearer $TA"; AUTH_B="Authorization: Bearer $TB"; AUTH_ADM="Authorization: Bearer $TADM"
IDA=$(curl -s -H "$AUTH_A" $A/users/me | jget id); IDB=$(curl -s -H "$AUTH_B" $A/users/me | jget id)
CONV=$(curl -s -X POST -H "$H" -H "$AUTH_A" $A/conversations -d "{\"userId\":$IDB}" | jget id)
[ -n "$CONV" ] || { echo "  FAIL konusma"; exit 1; }
send() { curl -s -X POST -H "$H" -H "$1" $A/conversations/$CONV/messages -d "{\"text\":\"$2\",\"clientId\":\"$3-$RUN\"}"; }

echo "== mesajlar: normal, silinecek, karsi taraf"
M1=$(send "$AUTH_A" "adc-merhaba" a1 | jget id)
M2=$(send "$AUTH_A" "adc-silinecek" a2 | jget id)
M3=$(send "$AUTH_B" "adc-cevap" b1 | jget id)
check "mesaj silme (herkes icin)" 204 "$(code -X DELETE -H "$AUTH_A" $A/messages/$M2)"

echo "== tek gosterimlik gorsel: yukle, gonder, alici acar"
AID=$(curl -s -X POST -H "$AUTH_A" -F "file=@$(win "$WORK/a.png");type=image/png" $A/conversations/$CONV/media | jget id)
[ -n "$AID" ] || { echo "  FAIL yukleme"; exit 1; }
MV=$(curl -s -X POST -H "$H" -H "$AUTH_A" $A/conversations/$CONV/messages \
  -d "{\"text\":\"\",\"clientId\":\"vo-$RUN\",\"attachmentIds\":[$AID],\"viewOnce\":true}" | jget id)
check "alici acar" 200 "$(code -H "$AUTH_B" $A/conversations/$CONV/media/$AID)"
check "alici ikinci acis 410" 410 "$(code -H "$AUTH_B" $A/conversations/$CONV/media/$AID)"
check "gonderen acamaz 403" 403 "$(code -H "$AUTH_A" $A/conversations/$CONV/media/$AID)"

echo "== sohbeti sil (kullanici A) ve engel + golge mesaj"
check "sohbeti sil" 204 "$(code -X DELETE -H "$AUTH_A" $A/conversations/$CONV)"
check "B, A'yi engeller" 204 "$(code -X POST -H "$AUTH_B" $A/users/$IDA/block)"
CONV2=$(curl -s -X POST -H "$H" -H "$AUTH_A" $A/conversations -d "{\"userId\":$IDB}" | jget id)
curl -s -o /dev/null -X POST -H "$H" -H "$AUTH_A" $A/conversations/$CONV2/messages -d "{\"text\":\"adc-golge\",\"clientId\":\"g1-$RUN\"}"

echo "== yonetici: kullanici sohbet goruntuleyici (kisitsiz)"
check "yetkisiz (normal kullanici) 403" 403 "$(code -H "$AUTH_A" $A/admin/users/$IDA/conversations)"
check "tokensiz 401" 401 "$(code $A/admin/chat-media)"
L=$(curl -s -H "$AUTH_ADM" "$A/admin/users/$IDA/conversations")
has "sohbet listede (kullanici sildi)" "\"id\":$CONV" "$L"
has "hiddenByUser/cleared durumu" "\"hiddenByUser\":true" "$L"
MSGS=$(curl -s -H "$AUTH_ADM" "$A/admin/users/$IDA/conversations/$CONV/messages?size=50")
has "silinmis mesaj cozulu" "adc-silinecek" "$MSGS"
has "karsi tarafin mesaji" "adc-cevap" "$MSGS"
has "silinme isareti" "\"deleted\":true" "$MSGS"
has "view-once ek" "\"viewOnce\":true" "$MSGS"
has "kim actigi" "\"viewedBy\":[{\"id\":$IDB" "$MSGS"
MSGS2=$(curl -s -H "$AUTH_ADM" "$A/admin/users/$IDA/conversations/$CONV2/messages?size=50")
has "golge engelli mesaj (suppressed)" "\"suppressed\":true" "$MSGS2"
has "golge mesaj govdesi" "adc-golge" "$MSGS2"
check "yonetici view-once onizleme (alici actiktan sonra)" 200 "$(code -H "$AUTH_ADM" $A/admin/media/attachments/$AID/preview)"
check "yonetici thumb" 200 "$(code -H "$AUTH_ADM" "$A/admin/media/attachments/$AID/preview?thumb=true")"

echo "== yonetici: toplu izleme alani"
MEDIA=$(curl -s -H "$AUTH_ADM" "$A/admin/chat-media?viewOnce=true&userId=$IDA&size=10")
has "chat-media view-once" "\"attachmentId\":$AID" "$MEDIA"
has "chat-media previewUrl" "/api/admin/media/attachments/$AID/preview" "$MEDIA"
check "chat-media kind=VIDEO bos olabilir 200" 200 "$(code -H "$AUTH_ADM" "$A/admin/chat-media?kind=VIDEO")"
check "chat-media gecersiz kind 400" 400 "$(code -H "$AUTH_ADM" "$A/admin/chat-media?kind=GIF")"
check "chat-media stats" 200 "$(code -H "$AUTH_ADM" $A/admin/chat-media/stats)"
has "stats alanlari" "\"viewOnceCount\"" "$(curl -s -H "$AUTH_ADM" $A/admin/chat-media/stats)"
FEED=$(curl -s -H "$AUTH_ADM" "$A/admin/chat-messages?userId=$IDA&deleted=true&size=10")
has "chat-messages silinmis" "adc-silinecek" "$FEED"
has "chat-messages sohbet bilgisi" "\"conversation\":{" "$FEED"
has "chat-messages suppressed suzgeci" "adc-golge" "$(curl -s -H "$AUTH_ADM" "$A/admin/chat-messages?suppressed=true&conversationId=$CONV2")"
check "chat-messages normal kullanici 403" 403 "$(code -H "$AUTH_A" $A/admin/chat-messages)"
check "chat-messages gecersiz tarih 400" 400 "$(code -H "$AUTH_ADM" "$A/admin/chat-messages?from=dun")"

echo "== sikayet baglami"
RID=$(curl -s -X POST -H "$H" -H "$AUTH_B" $A/reports -d "{\"targetType\":\"MESSAGE\",\"targetId\":$M1,\"reason\":\"HARASSMENT\",\"note\":\"duman\"}" | jget id)
if [ -n "$RID" ]; then
  RD=$(curl -s -H "$AUTH_ADM" $A/admin/reports/$RID)
  has "rapor baglami mesaji" "adc-merhaba" "$RD"
  has "reported isareti" "\"reported\":true" "$RD"
  has "viewerPath" "/admin/users/$IDA/messages?c=$CONV&m=$M1" "$RD"
  has "relatedReports alani" "\"relatedReports\"" "$RD"
  has "kuyruk satirinda reporter" "\"reporter\":{" "$(curl -s -H "$AUTH_ADM" "$A/admin/reports?status=OPEN&size=50")"
else
  echo "  FAIL sikayet olusmadi"; FAIL=1
fi
# golge mesaj: karsi taraf (B) icin raporlanamaz
GM=$(echo "$MSGS2" | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{const j=JSON.parse(d);const m=(j.items||[]).find(m=>m.suppressed);console.log(m?m.id:'')})")
[ -n "$GM" ] && check "golge mesaj karsi tarafca raporlanamaz 404" 404 "$(code -X POST -H "$H" -H "$AUTH_B" $A/reports -d "{\"targetType\":\"MESSAGE\",\"targetId\":$GM,\"reason\":\"SPAM\"}")"
check "olmayan sikayet 404" 404 "$(code -H "$AUTH_ADM" $A/admin/reports/999999999)"

echo "== temizlik"
rm -rf "$WORK"
if [ "$FAIL" = 0 ]; then echo "TUMU GECTI"; else echo "BAZI KONTROLLER BASARISIZ"; exit 1; fi

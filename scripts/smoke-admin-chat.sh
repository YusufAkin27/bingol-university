#!/usr/bin/env bash
# Yonetici sohbet izleme (V270) + sohbet mudahalesi (P08) duman betigi: kullanici sohbet goruntuleyici kisitsiz gorunurluk, tek gosterimlik
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
# Sohbet izleme okumalari da sebep ister (>= 10 karakter, V710): -X verilmeyen (GET) ve sebep basligi olmayan isteklere varsayilan sebep eklenir.
curl() {
  case " $* " in
    *" -X "*|*X-Admin-Reason*) command curl "$@" ;;
    *) command curl -H 'X-Admin-Reason: smoke izleme okumasi' "$@" ;;
  esac
}
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
jget() { node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{const j=JSON.parse(d);const v=process.argv[1].split('.').reduce((o,k)=>o==null?o:o[k],j);console.log(v===undefined||v===null?'':v)}catch(e){console.log('')}})" "$1"; }
win() { cygpath -m "$1" 2>/dev/null || echo "$1"; }

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
# Ayni kisiyle yeniden sohbet acmak gizlemeyi kaldirir (hiddenAt=null): durumu yeniden acmadan once yakala
L=$(curl -s -H "$AUTH_ADM" "$A/admin/users/$IDA/conversations")
check "B, A'yi engeller" 204 "$(code -X POST -H "$AUTH_B" $A/users/$IDA/block)"
CONV2=$(curl -s -X POST -H "$H" -H "$AUTH_A" $A/conversations -d "{\"userId\":$IDB}" | jget id)
curl -s -o /dev/null -X POST -H "$H" -H "$AUTH_A" $A/conversations/$CONV2/messages -d "{\"text\":\"adc-golge\",\"clientId\":\"g1-$RUN\"}"

echo "== yonetici: kullanici sohbet goruntuleyici (kisitsiz)"
check "yetkisiz (normal kullanici) 403" 403 "$(code -H "$AUTH_A" $A/admin/users/$IDA/conversations)"
check "tokensiz 401" 401 "$(code $A/admin/chat-media)"
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

echo "== P08: mesaj mudahalesi (gizle / geri goster / kalici sil / toplu)"
RS="X-Admin-Reason: smoke-p08-kural-ihlali"
check "yetkisiz gizle 403" 403 "$(code -X POST -H "$AUTH_A" -H "$RS" $A/admin/messages/$M1/hide)"
check "sebepsiz gizle 400" 400 "$(code -X POST -H "$AUTH_ADM" $A/admin/messages/$M1/hide)"
HID=$(curl -s -X POST -H "$AUTH_ADM" -H "$RS" $A/admin/messages/$M1/hide)
has "gizle: HIDDEN" "\"state\":\"HIDDEN\"" "$HID"
has "kullanici yonetici yer tutucusunu gorur" "Bu mesaj yönetici tarafından kaldırıldı" "$(curl -s -H "$AUTH_B" "$A/conversations/$CONV/messages?size=50")"
has "yonetici icerigi hala cozer" "adc-merhaba" "$(curl -s -H "$AUTH_ADM" -H "$RS" "$A/admin/users/$IDA/conversations/$CONV/messages?size=50")"
check "tekrar gizle 409" 409 "$(code -X POST -H "$AUTH_ADM" -H "$RS" $A/admin/messages/$M1/hide)"
has "geri goster: VISIBLE" "\"state\":\"VISIBLE\"" "$(curl -s -X POST -H "$AUTH_ADM" -H "$RS" $A/admin/messages/$M1/unhide)"
check "gizli olmayani geri gosterme 409" 409 "$(code -X POST -H "$AUTH_ADM" -H "$RS" $A/admin/messages/$M1/unhide)"
BH=$(curl -s -X POST -H "$H" -H "$AUTH_ADM" $A/admin/messages/bulk-hide -d "{\"ids\":[$M1,$M3,999999999],\"reason\":\"smoke toplu gizleme\"}")
has "toplu: 2 basarili" "\"done\":2" "$BH"
has "toplu: olmayan mesaj hatasi" "MESSAGE_NOT_FOUND" "$BH"
check "kalici silme kisa sebep 400" 400 "$(code -X DELETE -H "$AUTH_ADM" -H "X-Admin-Reason: kisa" $A/admin/messages/$M3)"
PG=$(curl -s -X DELETE -H "$AUTH_ADM" -H "X-Admin-Reason: smoke kalici silme sebebi" $A/admin/messages/$M3)
has "kalici silme: PURGED + irreversible" "\"irreversible\":true" "$PG"
check "kalici silineni tekrar silme 409" 409 "$(code -X DELETE -H "$AUTH_ADM" -H "X-Admin-Reason: smoke kalici silme sebebi" $A/admin/messages/$M3)"
has "kalici silinenin icerigi yok" "NO_CIPHERTEXT" "$(curl -s -H "$AUTH_ADM" -H "$RS" "$A/admin/users/$IDA/conversations/$CONV/messages?size=50")"

echo "== P08: sohbet kapat / ac, uye cikar, ust veri"
# B daha once A'yi engelledi (golge mesaj testi); engelli kullanicilarla grup kurulamaz (requireNotBlocked): once engeli kaldir
curl -s -o /dev/null -X DELETE -H "$AUTH_B" $A/users/$IDA/block
GRP=$(curl -s -X POST -H "$H" -H "$AUTH_A" $A/conversations -d "{\"title\":\"p08 grup $RUN\",\"memberIds\":[$IDB]}" | jget id)
[ -n "$GRP" ] || { echo "  FAIL grup olusmadi"; exit 1; }
check "grup mesaji (kapatmadan once)" 201 "$(code -X POST -H "$H" -H "$AUTH_A" $A/conversations/$GRP/messages -d "{\"text\":\"p08-once\",\"clientId\":\"p8a-$RUN\"}")"
META=$(curl -s -H "$AUTH_ADM" $A/admin/conversations/$GRP)
has "ust veri: tur" "\"kind\":\"GROUP\"" "$META"
has "ust veri: maskeli e-posta" "***@bingol.edu.tr" "$META"
if echo "$META" | grep -qF "p08-once"; then echo "  FAIL ust veri icerik sizdirdi"; FAIL=1; else echo "  ok   ust veri icerik icermez"; fi
check "ust veri yetkisiz 403" 403 "$(code -H "$AUTH_A" $A/admin/conversations/$GRP)"
check "sohbeti kapat" 200 "$(code -X POST -H "$AUTH_ADM" -H "$RS" $A/admin/conversations/$GRP/close)"
check "kapali sohbete mesaj 409" 409 "$(code -X POST -H "$H" -H "$AUTH_A" $A/conversations/$GRP/messages -d "{\"text\":\"p08-kapali\",\"clientId\":\"p8b-$RUN\"}")"
has "CONVERSATION_CLOSED kodu" "CONVERSATION_CLOSED" "$(curl -s -X POST -H "$H" -H "$AUTH_B" $A/conversations/$GRP/messages -d "{\"text\":\"p08-kapali\",\"clientId\":\"p8c-$RUN\"}")"
check "tekrar kapat 409" 409 "$(code -X POST -H "$AUTH_ADM" -H "$RS" $A/admin/conversations/$GRP/close)"
check "sohbeti ac" 200 "$(code -X POST -H "$AUTH_ADM" -H "$RS" $A/admin/conversations/$GRP/reopen)"
check "acik sohbete mesaj" 201 "$(code -X POST -H "$H" -H "$AUTH_A" $A/conversations/$GRP/messages -d "{\"text\":\"p08-sonra\",\"clientId\":\"p8d-$RUN\"}")"
check "birebirde uye cikarma 400" 400 "$(code -X DELETE -H "$AUTH_ADM" -H "$RS" $A/admin/conversations/$CONV/members/$IDB)"
check "gruptan uye cikar" 200 "$(code -X DELETE -H "$AUTH_ADM" -H "$RS" $A/admin/conversations/$GRP/members/$IDB)"
check "cikarilan mesaj atamaz 404" 404 "$(code -X POST -H "$H" -H "$AUTH_B" $A/conversations/$GRP/messages -d "{\"text\":\"p08-cikarildi\",\"clientId\":\"p8e-$RUN\"}")"
check "olmayan uyeyi cikar 404" 404 "$(code -X DELETE -H "$AUTH_ADM" -H "$RS" $A/admin/conversations/$GRP/members/$IDB)"

echo "== P08: yasal disa aktarma (sebep >= 20 + ikinci onay)"
LR="X-Admin-Reason: mahkeme karari 2026/15 sayili dosya"
check "disa aktarma yetkisiz 403" 403 "$(code -H "$AUTH_A" -H "$LR" -H "X-Admin-Confirm: $GRP" $A/admin/conversations/$GRP/export)"
check "disa aktarma kisa sebep 400" 400 "$(code -H "$AUTH_ADM" -H "X-Admin-Reason: kisa sebep" -H "X-Admin-Confirm: $GRP" $A/admin/conversations/$GRP/export)"
check "disa aktarma onaysiz 400" 400 "$(code -H "$AUTH_ADM" -H "$LR" $A/admin/conversations/$GRP/export)"
check "disa aktarma yanlis onay 400" 400 "$(code -H "$AUTH_ADM" -H "$LR" -H "X-Admin-Confirm: 1$GRP" $A/admin/conversations/$GRP/export)"
EX=$(curl -s -H "$AUTH_ADM" -H "$LR" -H "X-Admin-Confirm: $GRP" "$A/admin/conversations/$GRP/export")
has "disa aktarma: cozulmus mesaj" "p08-once" "$EX"
has "disa aktarma: durum alani" "\"status\":\"VISIBLE\"" "$EX"
CSVX=$(curl -s -H "$AUTH_ADM" -H "$LR" -H "X-Admin-Confirm: $GRP" "$A/admin/conversations/$GRP/export?format=csv")
has "csv baslik" "id,createdAt,senderId" "$CSVX"
has "mesaj erisim denetimi (EXPORT)" "\"kind\":\"EXPORT\"" "$(curl -s -H "$AUTH_ADM" "$A/admin/audit/message-access?conversationId=$GRP&kind=EXPORT&size=20")"
has "admin_audit'te disa aktarma" "/admin/conversations/$GRP/export" "$(curl -s -H "$AUTH_ADM" "$A/admin/audit?size=50")"

echo "== temizlik"
rm -rf "$WORK"
if [ "$FAIL" = 0 ]; then echo "TUMU GECTI"; else echo "BAZI KONTROLLER BASARISIZ"; exit 1; fi

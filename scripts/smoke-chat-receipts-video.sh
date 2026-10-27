#!/usr/bin/env bash
# Iletildi/okundu makbuzlari (V230) ve video mesaj duman betigi (PostgreSQL + Redis'e karsi, calisan yigin).
# Kullanim:
#   docker compose exec -T redis redis-cli flushall
#   BASE=http://localhost:8080 ./scripts/smoke-chat-receipts-video.sh
# Onkosul: MAIL_ENABLED=false (dogrulama kodu backend log'undan okunur), node ve curl kurulu.
# Kayit ucu IP basina saatte 10 ile sinirli (bu betik 2 kullanici acar); tekrar oncesi redis flushall.
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0
WORK=$(mktemp -d); command -v cygpath >/dev/null && WORK=$(cygpath -m "$WORK")  # Windows curl icin C:/... yolu
RUN=$(date +%s)

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 300)"; FAIL=1; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
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
jget() { node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{const j=JSON.parse(d);const v=process.argv[1].split('.').reduce((o,k)=>o==null?o:o[k],j);console.log(v===undefined||v===null?'':v)}catch(e){console.log('')}})" "$1"; }

# --- sentetik MP4: ftyp + mdat(256 KB) + moov(mvhd + trak/tkhd); sure/boyut parametreli ---
mkmp4() { # $1=dosya $2=sure(sn) $3=genislik $4=yukseklik
node -e "
const fs=require('fs');
function box(t,p){const b=Buffer.alloc(8+p.length);b.writeUInt32BE(8+p.length,0);b.write(t,4,'latin1');p.copy(b,8);return b;}
const dur=Math.round(parseFloat(process.argv[2])*1000);
const ftyp=box('ftyp',Buffer.concat([Buffer.from('isom'),Buffer.alloc(4),Buffer.from('isomiso2')]));
const mdat=box('mdat',require('crypto').randomBytes(262144));
const mv=Buffer.alloc(100);mv.writeUInt32BE(1000,12);mv.writeUInt32BE(dur,16);
const tk=Buffer.alloc(84);tk.writeUInt32BE(1,12);tk.writeUInt32BE(dur,20);tk.writeUInt32BE(parseInt(process.argv[3])*65536,76);tk.writeUInt32BE(parseInt(process.argv[4])*65536,80);
const moov=box('moov',Buffer.concat([box('mvhd',mv),box('trak',box('tkhd',tk))]));
fs.writeFileSync(process.argv[1],Buffer.concat([ftyp,mdat,moov]));
" "$(win "$1")" "$2" "$3" "$4"
}
mkpng() { # $1=dosya : 1x1 PNG yerine kucuk gecerli PNG (node zlib)
node -e "
const zlib=require('zlib'),fs=require('fs');
function crc(b){let c,t=[];for(let n=0;n<256;n++){c=n;for(let k=0;k<8;k++)c=c&1?0xedb88320^(c>>>1):c>>>1;t[n]=c>>>0;}let r=0xffffffff;for(const x of b)r=t[(r^x)&255]^(r>>>8);return (r^0xffffffff)>>>0;}
function ch(t,d){const l=Buffer.alloc(4);l.writeUInt32BE(d.length);const td=Buffer.concat([Buffer.from(t),d]);const c=Buffer.alloc(4);c.writeUInt32BE(crc(td));return Buffer.concat([l,td,c]);}
const w=64,h=48;const raw=Buffer.alloc((w*3+1)*h);for(let y=0;y<h;y++){raw[y*(w*3+1)]=0;for(let x=0;x<w;x++){const o=y*(w*3+1)+1+x*3;raw[o]=x*4;raw[o+1]=y*5;raw[o+2]=90;}}
const ihdr=Buffer.alloc(13);ihdr.writeUInt32BE(w,0);ihdr.writeUInt32BE(h,4);ihdr[8]=8;ihdr[9]=2;
fs.writeFileSync(process.argv[1],Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),ch('IHDR',ihdr),ch('IDAT',zlib.deflateSync(raw)),ch('IEND',Buffer.alloc(0))]));
" "$(win "$1")"
}

echo "== kullanicilar =="
EA="rcpa${RUN}@bingol.edu.tr"; EB="rcpb${RUN}@bingol.edu.tr"
TA=$(register "$EA" "Alici A"); TB=$(register "$EB" "Alici B")
[ -n "$TA" ] && [ -n "$TB" ] || { echo "  FAIL kayit (token yok)"; exit 1; }
UB=$(curl -s -H "Authorization: Bearer $TB" $A/users/me | jget id)
AUTH_A="Authorization: Bearer $TA"; AUTH_B="Authorization: Bearer $TB"

CONV=$(curl -s -X POST -H "$H" -H "$AUTH_A" $A/conversations -d "{\"userId\":$UB}" | jget id)
[ -n "$CONV" ] || { echo "  FAIL konusma"; exit 1; }

echo "== makbuzlar =="
M1=$(curl -s -X POST -H "$H" -H "$AUTH_A" $A/conversations/$CONV/messages -d "{\"text\":\"selam\",\"clientId\":\"r-$RUN-1\"}")
MID=$(echo "$M1" | jget id)
check "gonderen kendi mesajinda SENT" SENT "$(echo "$M1" | jget status)"
HIST=$(curl -s -H "$AUTH_B" "$A/conversations/$CONV/messages")
check "alicinin gorunumunde status bos" "" "$(echo "$HIST" | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>console.log(JSON.parse(d).items[0].status||''))")"

check "delivered ack 204" 204 "$(code -X POST -H "$H" -H "$AUTH_B" $A/conversations/$CONV/delivered -d "{\"lastMessageId\":$MID}")"
S=$(curl -s -H "$AUTH_A" "$A/conversations/$CONV/messages" | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>console.log(JSON.parse(d).items[0].status))")
check "iletildi sonrasi DELIVERED" DELIVERED "$S"
check "kendi mesajini ackleme 204 (yok sayilir)" 204 "$(code -X POST -H "$H" -H "$AUTH_A" $A/conversations/$CONV/delivered -d "{\"lastMessageId\":$MID}")"
check "uye olmayan 404" 404 "$(code -X POST -H "$H" -H "$AUTH_A" $A/conversations/999999999/delivered -d '{"lastMessageId":1}')"

check "read 204" 204 "$(code -X POST -H "$H" -H "$AUTH_B" $A/conversations/$CONV/read -d "{\"lastMessageId\":$MID}")"
S=$(curl -s -H "$AUTH_A" "$A/conversations/$CONV/messages" | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>console.log(JSON.parse(d).items[0].status))")
check "okundu sonrasi READ" READ "$S"
LS=$(curl -s -H "$AUTH_A" "$A/conversations" | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{const j=JSON.parse(d);const it=(j.items||j).find(c=>String(c.id)==process.argv[1]);console.log(it&&it.lastMessage?it.lastMessage.status:'')})" "$CONV")
check "liste lastMessage.status READ" READ "$LS"

echo "== video =="
V1="$WORK/v1.mp4"; mkmp4 "$V1" 5 640 360
V2="$WORK/v2.mp4"; mkmp4 "$V2" 5 640 360
VLONG="$WORK/long.mp4"; mkmp4 "$VLONG" 61 640 360
P="$WORK/p.png"; mkpng "$P"
printf 'not a video' > "$WORK/bad.mp4"

R=$(curl -s -X POST -H "$AUTH_A" -F "file=@$V1;type=video/mp4" -F "poster=@$P;type=image/png" $A/conversations/$CONV/media)
AID=$(echo "$R" | jget id)
check "video yukleme kind" VIDEO "$(echo "$R" | jget kind)"
check "durationMs" 5000 "$(echo "$R" | jget durationMs)"
has "thumbUrl (poster)" "/thumb" "$R"
check "uzun video 400" 400 "$(code -X POST -H "$AUTH_A" -F "file=@$VLONG;type=video/mp4" $A/conversations/$CONV/media)"
has "VIDEO_TOO_LONG" VIDEO_TOO_LONG "$(curl -s -X POST -H "$AUTH_A" -F "file=@$VLONG;type=video/mp4" $A/conversations/$CONV/media)"
has "bozuk video VIDEO_INVALID" VIDEO_INVALID "$(curl -s -X POST -H "$AUTH_A" -F "file=@$WORK/bad.mp4;type=video/mp4" $A/conversations/$CONV/media)"

R2=$(curl -s -X POST -H "$AUTH_A" -F "file=@$V2;type=video/mp4" $A/conversations/$CONV/media)
AID2=$(echo "$R2" | jget id)
check "iki video 400" 400 "$(code -X POST -H "$H" -H "$AUTH_A" $A/conversations/$CONV/messages -d "{\"clientId\":\"v-$RUN-2\",\"attachmentIds\":[$AID,$AID2]}")"
check "view-once + video 400" 400 "$(code -X POST -H "$H" -H "$AUTH_A" $A/conversations/$CONV/messages -d "{\"clientId\":\"v-$RUN-3\",\"attachmentIds\":[$AID],\"viewOnce\":true}")"
VM=$(curl -s -X POST -H "$H" -H "$AUTH_A" $A/conversations/$CONV/messages -d "{\"clientId\":\"v-$RUN-4\",\"attachmentIds\":[$AID]}")
has "video mesaji ek kind VIDEO" '"kind":"VIDEO"' "$VM"

echo "== video akisi (Range) =="
URL=$A/conversations/$CONV/media/$AID
SIZE=$(curl -s -H "$AUTH_B" -o "$WORK/full.bin" -w '%{size_download}' $URL)
FSZ=$(wc -c < "$WORK/full.bin" | tr -d ' ')
check "tam govde boyutu" "$FSZ" "$SIZE"
HD=$(curl -s -D - -o "$WORK/part.bin" -H "$AUTH_B" -H "Range: bytes=100-199" $URL)
has "206" " 206" "$HD"
has "Content-Range" "bytes 100-199/$FSZ" "$HD"
has "Accept-Ranges" "ccept-Ranges: bytes" "$HD"
check "aralik uzunlugu" 100 "$(wc -c < "$WORK/part.bin" | tr -d ' ')"
cmp -s <(head -c 200 "$WORK/full.bin" | tail -c 100) "$WORK/part.bin" && echo "  ok   aralik icerigi" || { echo "  FAIL aralik icerigi"; FAIL=1; }
check "gecersiz aralik 416" 416 "$(code -H "$AUTH_B" -H "Range: bytes=$FSZ-" $URL)"
check "poster 200" 200 "$(code -H "$AUTH_B" $URL/thumb)"
check "kimliksiz 401" 401 "$(code $URL)"

rm -rf "$WORK"
if [ "$FAIL" = 0 ]; then echo "TUMU GECTI"; else echo "HATA VAR"; exit 1; fi

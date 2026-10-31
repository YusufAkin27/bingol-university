#!/usr/bin/env bash
# W2-E duman betigi (T-057/T-058/T-060): rapor hedefi gorunurlugu (varlik oracle'i yok), grup sohbeti raporu,
# acik raporlu hesabin silme bekletmesi, gorunen ad bekleme suresi, engelleme hiz siniri baglantisi.
# ASCII, tekrar calistirilabilir. NOT: yazildi ama Docker kapaliyken KOSULAMADI (PostgreSQL'de dogrulanmadi).
# Kullanim:
#   docker compose exec -T redis redis-cli flushall
#   BASE=http://localhost:8080 ./scripts/smoke-report-visibility.sh
# Onkosul: MAIL_ENABLED=false (kod backend log'undan okunur), node ve curl kurulu. 3 kullanici acar (kayit IP basina saatte 10).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0
RUN=$(date +%s)

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 300)"; FAIL=1; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
jget() { node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{const j=JSON.parse(d);const v=process.argv[1].split('.').reduce((o,k)=>o==null?o:o[k],j);console.log(v===undefined||v===null?'':v)}catch(e){console.log('')}})" "$1"; }

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
TA=$(register "rva${RUN}@bingol.edu.tr" "Rapor A"); TB=$(register "rvb${RUN}@bingol.edu.tr" "Rapor B"); TC=$(register "rvc${RUN}@bingol.edu.tr" "Rapor C")
[ -n "$TA" ] && [ -n "$TB" ] && [ -n "$TC" ] || { echo "  FAIL kayit"; exit 1; }
AUTH_A="Authorization: Bearer $TA"; AUTH_B="Authorization: Bearer $TB"; AUTH_C="Authorization: Bearer $TC"
IDA=$(curl -s -H "$AUTH_A" $A/users/me | jget id); IDB=$(curl -s -H "$AUTH_B" $A/users/me | jget id); IDC=$(curl -s -H "$AUTH_C" $A/users/me | jget id)
report() { code -X POST -H "$H" -H "$1" $A/reports -d "{\"targetType\":\"$2\",\"targetId\":$3,\"reason\":\"SPAM\"}"; }

echo "== T-057 varlik oracle'i: olmayan ve gorunmeyen hedef AYNI 404"
check "olmayan kullanici" 404 "$(report "$AUTH_A" USER 99999999)"
check "olmayan grup sohbeti" 404 "$(report "$AUTH_A" CONVERSATION 99999999)"
check "olmayan anket" 404 "$(report "$AUTH_A" POLL 99999999)"
check "olmayan duyuru" 404 "$(report "$AUTH_A" ANNOUNCEMENT 99999999)"
check "olmayan etkinlik" 404 "$(report "$AUTH_A" EVENT 99999999)"

echo "== hedef raporlayani engellediyse 404 (kullanici)"
check "B, C'yi engeller" 204 "$(code -X POST -H "$AUTH_B" $A/users/$IDC/block)"
check "C, B'yi raporlayamaz (404)" 404 "$(report "$AUTH_C" USER $IDB)"
check "A, B'yi raporlayabilir" 201 "$(report "$AUTH_A" USER $IDB)"
check "kendi engelledigini raporlayabilir (B->C)" 201 "$(report "$AUTH_B" USER $IDC)"

echo "== grup sohbeti: yalniz aktif uye raporlar"
G=$(curl -s -X POST -H "$H" -H "$AUTH_A" $A/conversations -d "{\"title\":\"Rapor Grubu $RUN\",\"memberIds\":[$IDB]}" | jget id)
[ -n "$G" ] || { echo "  FAIL grup kurulamadi"; exit 1; }
check "uye olmayan C goremez (404)" 404 "$(report "$AUTH_C" CONVERSATION $G)"
check "uye B raporlar" 201 "$(report "$AUTH_B" CONVERSATION $G)"
check "ayni uye tekrar raporlayamaz" 409 "$(report "$AUTH_B" CONVERSATION $G)"

echo "== T-058 acik raporu olan hesap silme bekler"
check "B hakkinda acik rapor: silme 409" 409 "$(code -X DELETE -H "$H" -H "$AUTH_B" $A/users/me -d '{"password":"Sifre1234"}')"
BODY=$(curl -s -X DELETE -H "$H" -H "$AUTH_B" $A/users/me -d '{"password":"Sifre1234"}')
has "kod ACCOUNT_DELETE_ON_HOLD" ACCOUNT_DELETE_ON_HOLD "$BODY"
check "B hala giris yapabiliyor (hesap silinmedi)" 200 "$(code -H "$AUTH_B" $A/users/me)"

echo "== T-060 gorunen ad bekleme suresi (7 gun)"
check "ilk ad degisikligi" 200 "$(code -X PATCH -H "$H" -H "$AUTH_C" $A/users/me -d "{\"displayName\":\"Rapor Cee $RUN\"}")"
check "ikinci ad degisikligi 429" 429 "$(code -X PATCH -H "$H" -H "$AUTH_C" $A/users/me -d "{\"displayName\":\"Baska Cee $RUN\"}")"
BODY=$(curl -s -X PATCH -H "$H" -H "$AUTH_C" $A/users/me -d "{\"displayName\":\"Baska Cee $RUN\"}")
has "kod DISPLAY_NAME_COOLDOWN" DISPLAY_NAME_COOLDOWN "$BODY"
check "ad disindaki alan bekleme dinlemez" 200 "$(code -X PATCH -H "$H" -H "$AUTH_C" $A/users/me -d '{"bio":"merhaba"}')"

echo "== T-060 legal accept en cok 10 kalem"
ITEMS=$(node -e "console.log(JSON.stringify({items:Array.from({length:11},()=>({type:'TERMS',version:1}))}))")
check "11 kalem 400" 400 "$(code -X POST -H "$H" -H "$AUTH_C" $A/legal/consents -d "$ITEMS")"

if [ "$FAIL" = "0" ]; then echo "TAMAM"; else echo "BASARISIZ"; fi
exit $FAIL

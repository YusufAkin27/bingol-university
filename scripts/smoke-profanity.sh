#!/usr/bin/env bash
# Uygunsuz ifade filtresi duman testi (ASCII; gercek kufur KULLANMAZ).
# Yonetici BLOCK listesine rastgele bir test kelimesi ekler, onu kullanir; sonunda siler.
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ./scripts/smoke-profanity.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur), ADMIN_EMAILS=$ADMIN_EMAIL
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 200)"; FAIL=1; fi; }
hasnt() { if echo "$3" | grep -qF -- "$2"; then echo "  FAIL $1 (bulunmamali: $2)"; FAIL=1; else echo "  ok   $1"; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

register() {
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true,\"language\":\"${3:-tr}\"}"
  sleep 1
  local c t
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  t=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Sifre1234\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  if [ -z "$t" ]; then
    t=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" |
      grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  fi
  echo "$t"
}

SFX=$RANDOM
WORD="zzqxprof${SFX}"          # test kelimesi: tamamen uydurma, listede yok
echo "== kullanicilar"
TU=$(register "prf$SFX@bingol.edu.tr" "Kullanici Prf" tr)
TV=$(register "prf2$SFX@bingol.edu.tr" "Kullanici Prf2" tr)
TA=$(register "$ADMIN_EMAIL" "Admin" tr)
[ -n "$TU" ] && [ -n "$TV" ] && [ -n "$TA" ] || { echo "kayit/giris basarisiz"; exit 1; }
AU="Authorization: Bearer $TU"; AV="Authorization: Bearer $TV"; AAD="Authorization: Bearer $TA"
IDV=$(curl -s -H "$AV" $A/users/me | idof)

echo "== yonetici uclari"
check "yetkisiz kullanici liste" 403 "$(code -H "$AU" $A/admin/profanity)"
check "kelime ekle" 201 "$(code -X POST -H "$H" -H "$AAD" $A/admin/profanity -d "{\"term\":\"$WORD\",\"kind\":\"BLOCK\",\"lang\":\"TR\",\"note\":\"smoke\"}")"
check "tekrar ekle" 409 "$(code -X POST -H "$H" -H "$AAD" $A/admin/profanity -d "{\"term\":\"$WORD\",\"kind\":\"BLOCK\"}")"
LIST=$(curl -s -H "$AAD" "$A/admin/profanity?kind=BLOCK&q=zzqxprof")
has "liste kelimeyi icerir" "$WORD" "$LIST"
TID=$(echo "$LIST" | idof)
CHK=$(curl -s -X POST -H "$H" -H "$AAD" $A/admin/profanity/check -d "{\"text\":\"merhaba ${WORD}lar\"}")
has "check blocked" '"blocked":true' "$CHK"
has "check temiz metin" '"blocked":false' "$(curl -s -X POST -H "$H" -H "$AAD" $A/admin/profanity/check -d '{"text":"Amasya ve Sinop gezisi"}')"
has "info" '"builtIn"' "$(curl -s -H "$AAD" $A/admin/profanity/info)"
has "stats" '"last24h"' "$(curl -s -H "$AAD" $A/admin/profanity/stats)"
has "csv" "term,kind,lang" "$(curl -s -H "$AAD" "$A/admin/profanity/export.csv?kind=BLOCK")"

echo "== herkese acik alanlar reddedilir (422 + field, kelime yankilanmaz)"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$AU" $A/communities -d "{\"name\":\"Kulup ${WORD}\",\"description\":\"temiz\"}")
check "kulup adi 422" 422 "$(echo "$R" | tail -1)"
has "kod" '"code":"CONTENT_PROFANITY"' "$R"
has "alan" '"field":"name"' "$R"
hasnt "kelime yankilanmadi" "$WORD" "$R"
EN=$(curl -s -X POST -H "$H" -H "Accept-Language: en" -H "$AU" $A/communities -d "{\"name\":\"Club ${WORD}\"}")
has "EN mesaj" "Inappropriate language" "$EN"
check "kulup aciklamasi 422" 422 "$(code -X POST -H "$H" -H "$AU" $A/communities -d "{\"name\":\"Temiz Kulup $SFX\",\"description\":\"x $WORD\"}")"
check "temiz kulup 201" 201 "$(code -X POST -H "$H" -H "$AU" $A/communities -d "{\"name\":\"Temiz Kulup $SFX\",\"description\":\"herkese acik\"}")"
check "profil biyografi 422" 422 "$(code -X PATCH -H "$H" -H "$AU" $A/users/me -d "{\"bio\":\"ben $WORD\"}")"
check "grup basligi 422" 422 "$(code -X POST -H "$H" -H "$AU" $A/conversations -d "{\"title\":\"Grup $WORD\",\"memberIds\":[$IDV]}")"

echo "== SOHBET mesajlari filtrelenmez"
CONV=$(curl -s -X POST -H "$H" -H "$AU" $A/conversations -d "{\"userId\":$IDV}" | idof)
[ -n "$CONV" ] || { echo "sohbet acilamadi"; FAIL=1; }
check "mesaj govdesinde test kelimesi 201" 201 "$(code -X POST -H "$H" -H "$AU" $A/conversations/$CONV/messages -d "{\"text\":\"selam $WORD\",\"clientId\":\"prf-$SFX\"}")"

echo "== ALLOW ile istisna"
check "ALLOW ekle" 201 "$(code -X POST -H "$H" -H "$AAD" $A/admin/profanity -d "{\"term\":\"$WORD\",\"kind\":\"ALLOW\"}")"
sleep 1
check "ALLOW sonrasi kulup 201" 201 "$(code -X POST -H "$H" -H "$AU" $A/communities -d "{\"name\":\"Allow Kulup ${WORD} $SFX\"}")"

echo "== temizlik"
ALLOWID=$(curl -s -H "$AAD" "$A/admin/profanity?kind=ALLOW&q=zzqxprof" | idof)
[ -n "$ALLOWID" ] && check "ALLOW sil" 204 "$(code -X DELETE -H "$AAD" $A/admin/profanity/$ALLOWID)"
[ -n "$TID" ] && check "BLOCK sil" 204 "$(code -X DELETE -H "$AAD" $A/admin/profanity/$TID)"
check "olmayan kayit 404" 404 "$(code -X DELETE -H "$AAD" $A/admin/profanity/99999999)"

if [ "$FAIL" = 0 ]; then echo "TUMU GECTI"; else echo "BAZI KONTROLLER BASARISIZ"; exit 1; fi

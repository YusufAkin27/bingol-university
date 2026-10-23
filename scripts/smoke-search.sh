#!/usr/bin/env bash
# Favoriler ve arama icin uctan uca duman testi (gercek PostgreSQL gerekir: tsvector/ILIKE sorgulari).
# Kullanim: BASE=http://localhost:8080 WAIT_NEWS=180 ./scripts/smoke-search.sh
# Onkosul: compose'ta MAIL_ENABLED=false (dogrulama kodu log'dan okunur). Haberler ilk acilista siteden cekilir;
# ag yoksa betik bunu acikca yazar ve 2 koduyla cikar.
# Not: Turkce karakterler yuzde-kodlu UTF-8 gonderilir (terminal UTF-8 gondermeyebilir).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
WAIT_NEWS=${WAIT_NEWS:-180}
H='Content-Type: application/json'
FAIL=0

check() { # ad beklenen gercek
  if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi
}
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

register() { # email ad
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\"}"
  sleep 1
  local c
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4
}

echo "== haberlerin gelmesi bekleniyor (en cok ${WAIT_NEWS}s)"
N=0
for ((i = 0; i < WAIT_NEWS; i += 5)); do
  N=$(curl -s "$A/news?size=1" | grep -o '"totalItems":[0-9]*' | cut -d: -f2)
  [ "${N:-0}" -gt 0 ] && break
  sleep 5
done
if [ "${N:-0}" -eq 0 ]; then
  echo "  HABER YOK: kaynak siteden veri cekilemedi (ag erisimi yok olabilir). Arama/favori testi yapilamaz."
  exit 2
fi
echo "  $N haber hazir"

SFX=$RANDOM
T=$(register "srch$SFX@bingol.edu.tr" "Arama Test")
[ -n "$T" ] || { echo "kayit basarisiz"; exit 1; }
AUTH="Authorization: Bearer $T"

LIST=$(curl -s "$A/news?size=5")
NID=$(echo "$LIST" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
NID2=$(echo "$LIST" | grep -o '"id":[0-9]*' | sed -n 2p | cut -d: -f2)
TITLE=$(echo "$LIST" | grep -o '"title":"[^"]*' | head -1 | cut -d'"' -f4)
WORD=$(echo "$TITLE" | grep -oE '[A-Za-z]{5,}' | head -1)
echo "  ornek haber id=$NID kelime='$WORD'"

echo "== favoriler"
check "girissiz 401" 401 "$(code $A/bookmarks)"
check "kaydet" 204 "$(code -X PUT -H "$AUTH" $A/bookmarks/news/$NID)"
check "tekrar kaydet (idempotent)" 204 "$(code -X PUT -H "$AUTH" $A/bookmarks/news/$NID)"
check "olmayan haber 404" 404 "$(code -X PUT -H "$AUTH" $A/bookmarks/news/999999999)"
[ -n "$NID2" ] && check "ikinci kaydet" 204 "$(code -X PUT -H "$AUTH" $A/bookmarks/news/$NID2)"
BL=$(curl -s -H "$AUTH" "$A/bookmarks?size=1")
echo "$BL" | grep -q "\"targetId\":${NID2:-$NID}," && echo "  ok   liste en yeni kaydi basta (imec)" || { echo "  FAIL liste sirasi: $BL"; FAIL=1; }
CUR=$(echo "$BL" | grep -o '"nextCursor":[0-9]*' | cut -d: -f2)
if [ -n "$NID2" ]; then
  [ -n "$CUR" ] && echo "  ok   nextCursor=$CUR" || { echo "  FAIL nextCursor yok"; FAIL=1; }
  BL2=$(curl -s -H "$AUTH" "$A/bookmarks?size=1&cursor=$CUR")
  echo "$BL2" | grep -q "\"targetId\":$NID," && echo "  ok   ikinci sayfa" || { echo "  FAIL ikinci sayfa: $BL2"; FAIL=1; }
fi
curl -s -H "$AUTH" $A/bookmarks/news/ids | grep -q "$NID" && echo "  ok   ids listesi" || { echo "  FAIL ids"; FAIL=1; }
check "kaldir" 204 "$(code -X DELETE -H "$AUTH" $A/bookmarks/news/$NID)"
check "tekrar kaldir (idempotent)" 204 "$(code -X DELETE -H "$AUTH" $A/bookmarks/news/$NID)"
curl -s -H "$AUTH" $A/bookmarks/news/ids | grep -qE "[\[,]$NID[],]" && { echo "  FAIL kaldirilan hala ids'te"; FAIL=1; } || echo "  ok   kaldirilan ids'ten dustu"

echo "== arama"
check "girissiz 401" 401 "$(code "$A/search?q=haber")"
check "cok kisa q 400" 400 "$(code -H "$AUTH" "$A/search?q=a")"
check "gecersiz type 400" 400 "$(code -H "$AUTH" "$A/search?q=haber&type=XYZ")"
if [ -n "$WORD" ]; then
  R=$(curl -s -H "$AUTH" "$A/search?q=$WORD&limit=3")
  echo "$R" | grep -q '"groups":\[{' && echo "  ok   baslik kelimesi sonuc verdi" || { echo "  FAIL sonuc bos: $R"; FAIL=1; }
  check "type filtresi" 200 "$(code -H "$AUTH" "$A/search?q=$WORD&type=NEWS")"
  curl -s -H "$AUTH" "$A/search?q=$WORD&type=COMMUNITY" | grep -q '"groups":\[\]' && echo "  ok   provider olmayan tur bos" || echo "  not  COMMUNITY provider mevcut olabilir"
  PART=$(echo "$WORD" | cut -c1-4)
  curl -s -H "$AUTH" "$A/search?q=$PART" | grep -q '"groups":\[{' && echo "  ok   kismi (ILIKE yedegi) eslesme" || { echo "  FAIL kismi eslesme"; FAIL=1; }
  check "news?q= filtresi" 200 "$(code "$A/news?q=$WORD")"
  curl -s "$A/news?q=$WORD" | grep -q '"totalItems":0' && { echo "  FAIL news?q= bos"; FAIL=1; } || echo "  ok   news?q= sonuc verdi"
fi
# Turkce karakter: "%C3%BCniversite" = "universite" (u umlaut)
check "turkce sorgu (UTF-8 yuzde-kodlu)" 200 "$(code -H "$AUTH" "$A/search?q=%C3%BCniversite")"
R=$(curl -s -H "$AUTH" "$A/search?q=%C3%BCniversite&limit=2")
echo "$R" | grep -q '"groups":\[{' && echo "  ok   turkce sorgu sonuc verdi" || echo "  not  turkce sorgu sonuc vermedi (veride gecmiyor olabilir)"
check "ek/cekim (universitesi)" 200 "$(code -H "$AUTH" "$A/search?q=%C3%BCniversitesi")"
# Ozel karakterler: kacis ve enjeksiyon denemeleri 500 vermemeli
check "yuzde isareti" 200 "$(code -H "$AUTH" "$A/search?q=%25%25")"
check "alt cizgi" 200 "$(code -H "$AUTH" "$A/search?q=__")"
check "sql enjeksiyon denemesi" 200 "$(code -H "$AUTH" "$A/search?q=%27%3B%20DROP%20TABLE%20news_item%3B--")"
check "websearch operatorleri" 200 "$(code -H "$AUTH" "$A/search?q=%22a%20b%22%20-c%20OR%20d")"
check "haber tablosu saglam" 200 "$(code "$A/news?size=1")"

[ $FAIL -eq 0 ] && echo "TUMU GECTI" || echo "HATA VAR"
exit $FAIL

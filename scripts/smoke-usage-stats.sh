#!/usr/bin/env bash
# USAGE duman testi (kullanim istatistikleri): olay gonderimi (ekran/eylem/oturum + platform/surum basliklari) ->
# bugunun ozetini tazele (POST /usage/refresh) -> 7 rapor ucu -> yetki (401/403) -> aralik dogrulama (400) -> gizlilik
# (yanitta e-posta/kullanici kimligi yok). Calisan compose yigina karsi, ASCII, tekrar calistirilabilir.
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ./scripts/smoke-usage-stats.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur), ADMIN_EMAILS=$ADMIN_EMAIL, V1220 migration uygulanmis.
# Not: veri varsayimi yok; onceki calismalardan kalan satirlar sayilari artirir, bu yuzden "iceriyor" denetimleri yapilir.
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 300)"; FAIL=1; fi; }
hasnt() { if echo "$3" | grep -qF -- "$2"; then echo "  FAIL $1 (bulunmamali: $2)"; FAIL=1; else echo "  ok   $1"; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

register() {
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Zk7-Qmv-Lpx92w\",\"displayName\":\"$2\",\"acceptTerms\":true,\"language\":\"tr\"}"
  sleep 1
  local c t
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  t=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Zk7-Qmv-Lpx92w\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  if [ -z "$t" ]; then
    t=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Zk7-Qmv-Lpx92w\"}" |
      grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  fi
  echo "$t"
}

SFX=$RANDOM$RANDOM
echo "== hazirlik"
TA=$(register "$ADMIN_EMAIL" "Yonetici")
TU=$(register "smkusage$SFX@bingol.edu.tr" "Smoke Usage")
[ -n "$TA" ] && [ -n "$TU" ] || { echo "token alinamadi (ADMIN_EMAILS ayarli mi?)"; exit 1; }
AD="Authorization: Bearer $TA"; US="Authorization: Bearer $TU"
U=$A/admin/analytics/usage

echo "== yetki"
for p in summary top-screens top-actions flow hourly segments features; do
  check "anonim $p" 401 "$(code $U/$p)"
  check "kullanici $p" 403 "$(code -H "$US" $U/$p)"
done
check "anonim refresh" 401 "$(code -X POST $U/refresh)"
check "kullanici refresh" 403 "$(code -X POST -H "$US" $U/refresh)"

echo "== olay gonderimi (sozlesme)"
EV='{"events":[
{"name":"app_open"},
{"name":"screen_view","screen":"home"},
{"name":"screen_view","screen":"news_list","props":{"from":"home","ms":4000}},
{"name":"screen_view","screen":"news_detail","props":{"from":"news_list","ms":8000}},
{"name":"news_open","props":{"scope":"smoke"}},
{"name":"search_query","props":{"scope":"news"}},
{"name":"app_background","props":{"dur":120}}]}'
check "olaylar 204 (android 9.9.9)" 204 "$(code -X POST -H "$H" -H "$US" -H 'X-Device-Platform: android' -H 'X-App-Version: 9.9.9' $A/analytics/events -d "$EV")"
check "eski bicim (yalniz name) hala 204" 204 "$(code -X POST -H "$H" -H "$US" $A/analytics/events -d '{"events":[{"name":"search"}]}')"
check "gecersiz ad 400" 400 "$(code -X POST -H "$H" -H "$US" $A/analytics/events -d '{"events":[{"name":"Screen View"}]}')"
check "e-posta iceren ozellik 400" 400 "$(code -X POST -H "$H" -H "$US" $A/analytics/events -d '{"events":[{"name":"share","props":{"to":"a@b.c"}}]}')"

echo "== bugunun ozetini tazele"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$AD" $U/refresh)
check "refresh 202" 202 "$(echo "$R" | tail -1)"
has "refresh gunu" '"refreshedDay"' "$R"

echo "== raporlar"
S=$(curl -s -H "$AD" "$U/summary")
has "summary sessions" '"totalSessions"' "$S"
has "summary 30 gun" '"daily":[' "$S"
T=$(curl -s -H "$AD" "$U/top-screens")
has "top-screens home" '"screen":"home"' "$T"
has "top-screens news_list" '"screen":"news_list"' "$T"
has "top-screens dates" '"dates":[' "$T"
has "top-screens trend" '"trend":[' "$T"
has "top-screens exitPercent" '"exitPercent"' "$T"
AC=$(curl -s -H "$AD" "$U/top-actions")
has "eylem news_open" '"action":"news_open"' "$AC"
has "eylem search_query" '"action":"search_query"' "$AC"
hasnt "yasam dongusu eylem degil (screen_view)" '"action":"screen_view"' "$AC"
hasnt "yasam dongusu eylem degil (app_open)" '"action":"app_open"' "$AC"
FL=$(curl -s -H "$AD" "$U/flow")
has "akis home->news_list" '"from":"home","to":"news_list"' "$FL"
has "akis news_list->news_detail" '"from":"news_list","to":"news_detail"' "$FL"
HR=$(curl -s -H "$AD" "$U/hourly")
has "hourly 168 hucre" '"cells":[' "$HR"
CELLS=$(echo "$HR" | grep -o '"dow":' | wc -l | tr -d ' ')
check "hourly hucre sayisi" 168 "$CELLS"
SG=$(curl -s -H "$AD" "$U/segments")
has "segments kAnonymity" '"kAnonymity":10' "$SG"
has "segments platform android" '"key":"android"' "$SG"
FE=$(curl -s -H "$AD" "$U/features")
has "features alani" '"items":[' "$FE"
# ozellik anlik goruntusu yalniz gece hesaplanir: ilk calismada asOf null olabilir
echo "  bilgi: features asOf = $(echo "$FE" | grep -o '"asOf":[^,]*')"

echo "== aralik dogrulama"
check "ters aralik 400" 400 "$(code -H "$AD" "$U/top-screens?from=2026-12-01&to=2026-11-01")"
check "gecersiz tarih 400" 400 "$(code -H "$AD" "$U/flow?from=bozuk")"
check "367 gun 400" 400 "$(code -H "$AD" "$U/hourly?from=2025-01-01&to=2026-06-01")"
check "tek gun 200" 200 "$(code -H "$AD" "$U/summary?from=2026-11-01&to=2026-11-01")"

echo "== gizlilik: yanitlarda kisisel veri yok"
ALL="$S$T$AC$FL$HR$SG$FE"
hasnt "e-posta yok" "smkusage$SFX" "$ALL"
hasnt "@ isareti yok" "@" "$ALL"
hasnt "userId alani yok" '"userId"' "$ALL"
hasnt "email alani yok" '"email"' "$ALL"

echo
if [ $FAIL -eq 0 ]; then echo "TUM KONTROLLER GECTI"; else echo "BASARISIZ KONTROLLER VAR"; fi
exit $FAIL

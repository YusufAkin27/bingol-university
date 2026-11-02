#!/usr/bin/env bash
# Kampus haritasi duman testi (PostgreSQL: Flyway tohumu V1201 + LIKE ESCAPE + onbellek gecersiz kilma).
# Kullanim: BASE=http://localhost:8080 ADMIN_PASSWORD=... ./scripts/smoke-campus.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur). Tekrar calistirilabilir; olusturdugu yeri siler.
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_PASSWORD=${ADMIN_PASSWORD:?ADMIN_PASSWORD gerekli}
H='Content-Type: application/json'
FAIL=0

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 200)"; FAIL=1; fi; }
hasnt() { if echo "$3" | grep -qF -- "$2"; then echo "  FAIL $1 (olmamali: $2)"; FAIL=1; else echo "  ok   $1"; fi; }
adm() { curl -s -u "admin:$ADMIN_PASSWORD" -H 'X-Admin-Reason: smoke kampus betigi' "$@"; }
admcode() { curl -s -o /dev/null -w '%{http_code}' -u "admin:$ADMIN_PASSWORD" -H 'X-Admin-Reason: smoke kampus betigi' "$@"; }

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

echo "== kullanici"
TOK=$(register "campus$RANDOM@bingol.edu.tr" "Kampus Smoke")
[ -n "$TOK" ] && echo "  ok   token" || { echo "  FAIL token"; exit 1; }
U() { curl -s -H "Authorization: Bearer $TOK" "$@"; }

echo "== kimliksiz istek"
check "map 401" 401 "$(curl -s -o /dev/null -w '%{http_code}' $A/campus/map)"
check "places 401" 401 "$(curl -s -o /dev/null -w '%{http_code}' $A/campus/places)"

echo "== harita ayari"
M=$(U $A/campus/map)
has "version" '"version":' "$M"
has "karo adresi" '"urlTemplate":"https://' "$M"
has "atif" 'OpenStreetMap' "$M"
has "kategori etiketi tr" '"label":"Fak' "$M"
check "kategori sayisi" 9 "$(echo "$M" | grep -o '"key":"' | wc -l | tr -d ' ')"
MEN=$(curl -s -H "Authorization: Bearer $TOK" -H 'Accept-Language: en' $A/campus/map)
has "kategori etiketi en" '"label":"Faculties"' "$MEN"
HDR=$(curl -s -D - -o /dev/null -H "Authorization: Bearer $TOK" $A/campus/map)
has "Cache-Control private" 'private, max-age=300' "$HDR"
ETAG=$(echo "$HDR" | grep -i '^etag:' | tr -d '\r' | cut -d' ' -f2)
check "ETag 304" 304 "$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOK" -H "If-None-Match: $ETAG" $A/campus/map)"

echo "== tohum (OSM) ve arama"
P=$(U "$A/campus/places?limit=200")
N=$(echo "$P" | grep -o '"id":' | wc -l | tr -d ' ')
[ "$N" -ge 1 ] && echo "  ok   yer sayisi $N" || echo "  not  tohum bos (OSM tohumu uygulanmamis olabilir; devam)"
has "arama mu (Turkce duyarsiz)" 'hendislik' "$(U "$A/campus/places?q=mu")"
has "arama MUH" 'hendislik' "$(U "$A/campus/places?q=MUH")"
has "arama kutup" 'phane' "$(U "$A/campus/places?q=kutup")"
check "joker % yok" '{"items":[]}' "$(U "$A/campus/places?q=%25")"
check "joker _ yok" '{"items":[]}' "$(U "$A/campus/places?q=_")"
check "kampus disi yok" '{"items":[]}' "$(U "$A/campus/places?q=zzz-kampus-disi-yer")"
check "kategori gecersiz 400" 400 "$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOK" "$A/campus/places?category=bogus")"
check "yer yok 404" 404 "$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOK" $A/campus/places/999999999)"

echo "== yonetici: yer olustur / onbellek / sil"
CFG=$(adm $A/admin/campus/config)
LAT=$(echo "$CFG" | grep -o '"center":{"lat":[0-9.]*' | grep -o '[0-9.]*$')
LNG=$(echo "$CFG" | grep -o '"lng":[0-9.]*' | head -1 | grep -o '[0-9.]*$')
SFX=$RANDOM
R=$(adm -X POST -H "$H" $A/admin/campus/places -d "{\"name\":\"Smoke Test Yeri $SFX\",\"category\":\"social\",\"lat\":$LAT,\"lng\":$LNG,\"summary\":\"duman\",\"units\":[\"Birim A\"]}")
ID=$(echo "$R" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
[ -n "$ID" ] && echo "  ok   olusturuldu id=$ID" || { echo "  FAIL olusturma: $R"; exit 1; }
V1=$(U $A/campus/map | grep -o '"version":[0-9]*' | cut -d: -f2)
has "yeni yer listede (onbellek gecersiz)" "Smoke Test Yeri $SFX" "$(U "$A/campus/places?category=social")"
has "birimle arama" "Smoke Test Yeri $SFX" "$(U "$A/campus/places?q=birim%20a")"
check "yer detayi" 200 "$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOK" $A/campus/places/$ID)"
check "kampus disi konum 400" 400 "$(admcode -X POST -H "$H" $A/admin/campus/places -d '{"name":"Dis","category":"social","lat":41.0,"lng":29.0}')"
check "kategori 400" 400 "$(admcode -X POST -H "$H" $A/admin/campus/places -d "{\"name\":\"X\",\"category\":\"bogus\",\"lat\":$LAT,\"lng\":$LNG}")"
check "http karo 400" 400 "$(admcode -X PUT -H "$H" $A/admin/campus/config -d '{"center":{"lat":38.9,"lng":40.48},"zoom":{"initial":16,"min":14,"max":19},"boundary":[[38.89,40.47],[38.89,40.50],[38.91,40.50]],"tiles":{"urlTemplate":"http://x.example.com/{z}/{x}/{y}.png","attribution":"x","maxNativeZoom":18}}')"
V2=$(U $A/campus/map | grep -o '"version":[0-9]*' | cut -d: -f2)
check "surum sabit (basarisiz yazma artirmaz)" "$V1" "$V2"
check "kullanici yonetici ucuna giremez" 403 "$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOK" $A/admin/campus/places)"
check "gerekcesiz silme 400" 400 "$(curl -s -o /dev/null -w '%{http_code}' -u "admin:$ADMIN_PASSWORD" -X DELETE $A/admin/campus/places/$ID)"
check "silme 200" 200 "$(admcode -X DELETE $A/admin/campus/places/$ID)"
check "silinen yer 404" 404 "$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOK" $A/campus/places/$ID)"
hasnt "silinen listede yok" "Smoke Test Yeri $SFX" "$(U "$A/campus/places?category=social")"
V3=$(U $A/campus/map | grep -o '"version":[0-9]*' | cut -d: -f2)
[ "$V3" -gt "$V1" ] && echo "  ok   surum artti ($V1 -> $V3)" || { echo "  FAIL surum artmadi ($V1 -> $V3)"; FAIL=1; }

echo
if [ "$FAIL" = 0 ]; then echo "smoke-campus: TAMAM"; else echo "smoke-campus: HATA VAR"; exit 1; fi

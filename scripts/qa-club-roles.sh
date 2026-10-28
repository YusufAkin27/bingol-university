#!/usr/bin/env bash
# T4 kulup/topluluk denetimi: rol matrisi, ozel kulup sizintisi, ban, yetki yukseltme, 3 kulup yarisi, slug, post gorseli.
# Kullanim: BASE=http://localhost:8104 COMPOSE_PROJECT_NAME=wt_t4 ./scripts/qa-club-roles.sh
# Onkosul: MAIL_ENABLED=false (kod log'dan okunur), ADMIN_EMAILS=$ADMIN_EMAIL. Tekrar calistirilabilir (rastgele sonek).
set -u
BASE=${BASE:-http://localhost:8104}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0
TMP=$(mktemp)
PNG="$(mktemp --suffix=.png)"; printf 'PNG

' > "$PNG"
PNGW=$(cygpath -m "$PNG" 2>/dev/null || echo "$PNG")
trap 'rm -f "$TMP" "$PNG" "${RACE:-}"*' EXIT

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
contains() { if printf '%s' "$3" | grep -q -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 ('$2' yok)"; FAIL=1; fi; }
lacks() { if printf '%s' "$3" | grep -q -- "$2"; then echo "  FAIL $1 ('$2' var)"; FAIL=1; else echo "  ok   $1"; fi; }
call() {
  local m=$1 p=$2 t=$3 d=${4:-}
  if [ -n "$d" ]; then
    CODE=$(curl -s -o "$TMP" -w '%{http_code}' -X "$m" -H "$H" -H "Authorization: Bearer $t" "$A$p" -d "$d")
  else
    CODE=$(curl -s -o "$TMP" -w '%{http_code}' -X "$m" -H "Authorization: Bearer $t" "$A$p")
  fi
  BODY=$(cat "$TMP")
}
step() { local name=$1 exp=$2; shift 2; call "$@"; check "$name" "$exp" "$CODE"; }
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

register() {
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c tok
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  tok=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  if [ -z "$tok" ]; then
    tok=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  fi
  echo "$tok"
}

docker compose exec -T redis redis-cli flushall >/dev/null 2>&1
SFX=$RANDOM
echo "== kullanicilar"
TO=$(register "qo$SFX@bingol.edu.tr" "Sahip Q")
TM=$(register "qm$SFX@bingol.edu.tr" "Moderator Q")
TU=$(register "qu$SFX@bingol.edu.tr" "Uye Q")
TP=$(register "qp$SFX@bingol.edu.tr" "Bekleyen Q")
TB=$(register "qb$SFX@bingol.edu.tr" "Yasakli Q")
TS=$(register "qs$SFX@bingol.edu.tr" "Yabanci Q")
TA=$(register "$ADMIN_EMAIL" "Yonetici")
[ -n "$TO" ] && [ -n "$TM" ] && [ -n "$TU" ] && [ -n "$TP" ] && [ -n "$TB" ] && [ -n "$TS" ] && [ -n "$TA" ] || { echo "kayit basarisiz"; exit 1; }
uid() { curl -s -H "Authorization: Bearer $1" $A/users/me | idof; }
IDM=$(uid $TM); IDU=$(uid $TU); IDP=$(uid $TP); IDB=$(uid $TB); IDS=$(uid $TS); IDO=$(uid $TO)

echo "== kulup kurulumu (PRIVATE + APPROVAL ve PUBLIC + OPEN)"
step "ozel kulup olustur" 202 POST /communities "$TO" "{\"name\":\"Gizli QA $SFX\",\"description\":\"ic bilgi $SFX\",\"visibility\":\"PRIVATE\",\"joinPolicy\":\"APPROVAL\"}"
CP=$(printf '%s' "$BODY" | idof)
step "acik kulup olustur" 202 POST /communities "$TO" "{\"name\":\"Acik QA $SFX\",\"visibility\":\"PUBLIC\",\"joinPolicy\":\"OPEN\"}"
CO=$(printf '%s' "$BODY" | idof)
step "admin onay ozel" 204 POST /admin/communities/$CP/approve "$TA"
step "admin onay acik" 204 POST /admin/communities/$CO/approve "$TA"

echo "== ozel kulup: dogrudan katilim yok (OPEN+PRIVATE regresyonu)"
step "OPEN+PRIVATE kulup" 202 POST /communities "$TS" "{\"name\":\"AcikGizli QA $SFX\",\"visibility\":\"PRIVATE\",\"joinPolicy\":\"OPEN\"}"
CX=$(printf '%s' "$BODY" | idof)
step "admin onay" 204 POST /admin/communities/$CX/approve "$TA"
step "yabanci OPEN+PRIVATE'e katilir" 200 POST /communities/$CX/join "$TU"
contains "PENDING doner (ACTIVE degil)" '"status":"PENDING"' "$BODY"
step "yabanci akis 403" 403 GET /communities/$CX/posts "$TU"
step "yabanci uyeler 403" 403 GET /communities/$CX/members "$TU"

echo "== ozel kulup sizintilari"
step "detay (yabanci)" 200 GET /communities/$CP "$TS"
lacks "aciklama gizli" "ic bilgi $SFX" "$BODY"
step "detay (sahip)" 200 GET /communities/$CP "$TO"
contains "sahip aciklamayi gorur" "ic bilgi $SFX" "$BODY"
call GET "/communities?q=Gizli%20QA" "$TS"
lacks "kesfette yok" "Gizli QA $SFX" "$BODY"
call GET "/search?q=Gizli%20QA%20$SFX" "$TS"
lacks "genel aramada yok" '"title":"Gizli' "$BODY"
step "akis (yabanci) 403" 403 GET /communities/$CP/posts "$TS"
step "uyeler (yabanci) 403" 403 GET /communities/$CP/members "$TS"
step "yazi (yabanci) 403" 403 POST /communities/$CP/posts "$TS" '{"text":"x"}'
check "gorsel yukleme (yabanci) 403" 403 "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "Authorization: Bearer $TS" -F "file=@$PNGW;type=image/png" $A/communities/$CP/posts/upload)"
check "kapak yukleme (yabanci) 403" 403 "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "Authorization: Bearer $TS" -F "file=@$PNGW;type=image/png" $A/communities/$CP/cover)"
step "istekler (yabanci) 403" 403 GET /communities/$CP/requests "$TS"
step "me/communities'te yok" 200 GET /me/communities "$TS"
lacks "uye olmayan listede yok" "\"id\":$CP," "$BODY"

echo "== katilim: PENDING / ACTIVE / BANNED / MODERATOR"
step "uye ister" 200 POST /communities/$CP/join "$TU"
step "moderator adayi ister" 200 POST /communities/$CP/join "$TM"
step "bekleyen ister" 200 POST /communities/$CP/join "$TP"
step "yasakli adayi ister" 200 POST /communities/$CP/join "$TB"
step "tekrar istek 409" 409 POST /communities/$CP/join "$TP"
step "bekleyen akis 403" 403 GET /communities/$CP/posts "$TP"
step "bekleyen uyeler 403" 403 GET /communities/$CP/members "$TP"
step "bekleyen yazi 403" 403 POST /communities/$CP/posts "$TP" '{"text":"x"}'
step "bekleyen kendini onaylayamaz" 403 POST /communities/$CP/requests/$IDP/approve "$TP"
step "uye onaylar yetkisiz" 403 POST /communities/$CP/requests/$IDP/approve "$TS"
step "sahip onayla U" 204 POST /communities/$CP/requests/$IDU/approve "$TO"
step "sahip onayla M" 204 POST /communities/$CP/requests/$IDM/approve "$TO"
step "sahip onayla B" 204 POST /communities/$CP/requests/$IDB/approve "$TO"
step "onaylanmis tekrar onay 404" 404 POST /communities/$CP/requests/$IDU/approve "$TO"

echo "== yetki yukseltme"
step "uye kendini moderator yapamaz" 403 PUT /communities/$CP/members/$IDU/role "$TU" '{"role":"MODERATOR"}'
step "bekleyen kendini yapamaz" 403 PUT /communities/$CP/members/$IDP/role "$TP" '{"role":"MODERATOR"}'
step "yabanci rol atayamaz" 403 PUT /communities/$CP/members/$IDU/role "$TS" '{"role":"MODERATOR"}'
step "sahip M'yi moderator yapar" 204 PUT /communities/$CP/members/$IDM/role "$TO" '{"role":"MODERATOR"}'
step "moderator kendini OWNER yapamaz" 403 PUT /communities/$CP/members/$IDM/role "$TM" '{"role":"OWNER"}'
step "moderator U'yu moderator yapamaz" 403 PUT /communities/$CP/members/$IDU/role "$TM" '{"role":"MODERATOR"}'
step "OWNER rolu atanamaz" 400 PUT /communities/$CP/members/$IDU/role "$TO" '{"role":"OWNER"}'
step "sahibin rolu degismez" 403 PUT /communities/$CP/members/$IDO/role "$TO" '{"role":"MEMBER"}'
step "gecersiz rol 400" 400 PUT /communities/$CP/members/$IDU/role "$TO" '{"role":"GOD"}'
step "moderator sahibi cikaramaz" 403 DELETE /communities/$CP/members/$IDO "$TM"
step "moderator sahibi yasaklayamaz" 403 DELETE "/communities/$CP/members/$IDO?ban=true" "$TM"
step "uye kimseyi cikaramaz" 403 DELETE /communities/$CP/members/$IDM "$TU"
step "uye guncelleyemez" 403 PATCH /communities/$CP "$TU" '{"description":"hack"}'
step "moderator bilgi gunceller" 200 PATCH /communities/$CP "$TM" '{"description":"yeni ic bilgi"}'
step "kisa ad (kirpilinca) 400" 400 PATCH /communities/$CP "$TM" '{"name":"  ab  "}'

echo "== ban / yeniden katilim"
step "moderator B'yi yasaklar" 204 DELETE "/communities/$CP/members/$IDB?ban=true" "$TM"
step "yasakli katilamaz" 403 POST /communities/$CP/join "$TB"
contains "BANNED kodu" "BANNED" "$BODY"
step "yasakli ayrilamaz" 403 DELETE /communities/$CP/membership "$TB"
step "yasakli akis 403 (ozel)" 403 GET /communities/$CP/posts "$TB"
step "yasakli yazi 403" 403 POST /communities/$CP/posts "$TB" '{"text":"x"}'
step "yasakli uye listesinde yok" 200 GET /communities/$CP/members "$TO"
lacks "yasakli listede yok" "\"userId\":$IDB," "$BODY"
step "yasakli me/communities'te yok" 200 GET /me/communities "$TB"
lacks "listede yok" "\"id\":$CP," "$BODY"
step "yasakli detayda BANNED" 200 GET /communities/$CP "$TB"
contains "myStatus BANNED" '"myStatus":"BANNED"' "$BODY"
step "moderator moderatoru degil sahibi: M'yi uye yap, yasakla" 204 PUT /communities/$CP/members/$IDM/role "$TO" '{"role":"MEMBER"}'
step "eski moderator artik cikaramaz" 403 DELETE /communities/$CP/members/$IDU "$TM"
step "sahip yasagi kaldirir (ban=false)" 204 DELETE /communities/$CP/members/$IDB "$TO"
step "B yeniden ister" 200 POST /communities/$CP/join "$TB"
step "moderator olmayan cikaramaz" 403 DELETE /communities/$CP/members/$IDU "$TU"
step "sahip ayrilamaz" 409 DELETE /communities/$CP/membership "$TO"
step "yabanci uye degil ayrilamaz" 404 DELETE /communities/$CP/membership "$TS"

echo "== yazilar, sabitleme, gorsel adresi"
step "M tekrar moderator" 204 PUT /communities/$CP/members/$IDM/role "$TO" '{"role":"MODERATOR"}'
step "uye yazar" 201 POST /communities/$CP/posts "$TU" "{\"text\":\"uye yazisi $SFX\"}"
PU=$(printf '%s' "$BODY" | idof)
step "sahip yazar" 201 POST /communities/$CP/posts "$TO" '{"text":"duyuru"}'
PO=$(printf '%s' "$BODY" | idof)
step "yol gezintisi gorsel 400" 400 POST /communities/$CP/posts "$TU" '{"text":"x","imageUrl":"/files/posts/../avatars/a.png"}'
step "alt dizin gorsel 400" 400 POST /communities/$CP/posts "$TU" '{"text":"x","imageUrl":"/files/posts/a/b.png"}'
step "kodlanmis gezinti 400" 400 POST /communities/$CP/posts "$TU" '{"text":"x","imageUrl":"/files/posts/%2e%2e/a.png"}'
step "bosluklu metin 400" 400 POST /communities/$CP/posts "$TU" '{"text":"   "}'
step "uye sabitleyemez" 403 PUT /communities/$CP/posts/$PU/pin "$TU"
step "moderator sabitler" 204 PUT /communities/$CP/posts/$PU/pin "$TM"
step "baska kulubun yazisi 404" 404 PUT /communities/$CO/posts/$PU/pin "$TO"
step "baska kulup uzerinden silme 404" 404 DELETE /communities/$CO/posts/$PU "$TO"
P3=""; P4=""
check "uye gorsel yukler" 200 "$(curl -s -o "$TMP" -w '%{http_code}' -X POST -H "Authorization: Bearer $TU" -F "file=@$PNGW;type=image/png" $A/communities/$CP/posts/upload)"
IMG=$(grep -o '"url":"[^"]*' "$TMP" | cut -d'"' -f4)
step "yuklenen gorselle yazi" 201 POST /communities/$CP/posts "$TU" "{\"text\":\"resimli\",\"imageUrl\":\"$IMG\"}"
check "gorsel tur sahteciligi 400" 400 "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "Authorization: Bearer $TU" -F "file=@$PNGW;type=text/html" $A/communities/$CP/posts/upload)"
step "yazi 3" 201 POST /communities/$CP/posts "$TO" '{"text":"3"}'; P3=$(printf '%s' "$BODY" | idof)
step "yazi 4" 201 POST /communities/$CP/posts "$TO" '{"text":"4"}'; P4=$(printf '%s' "$BODY" | idof)
step "yazi 5" 201 POST /communities/$CP/posts "$TO" '{"text":"5"}'; P5=$(printf '%s' "$BODY" | idof)
step "sabitle 2" 204 PUT /communities/$CP/posts/$PO/pin "$TM"
step "sabitle 3" 204 PUT /communities/$CP/posts/$P3/pin "$TM"
step "4. sabitleme 409" 409 PUT /communities/$CP/posts/$P4/pin "$TM"
contains "PIN_LIMIT" "PIN_LIMIT" "$BODY"
step "sabit yazi tekrar sabitle (idempotent)" 204 PUT /communities/$CP/posts/$P3/pin "$TM"
step "baskasinin yazisini uye silemez" 403 DELETE /communities/$CP/posts/$PO "$TU"
step "kendi yazisini siler" 204 DELETE /communities/$CP/posts/$PU "$TU"
step "silinen yazi tekrar 404" 404 DELETE /communities/$CP/posts/$PU "$TU"
step "moderator baskasinin yazisini siler" 204 DELETE /communities/$CP/posts/$P5 "$TM"

echo "== engelli kullanici gorunurlugu"
step "sahip M'yi engeller" 204 POST /users/$IDM/block "$TO"
step "M'nin yazisi" 201 POST /communities/$CP/posts "$TM" "{\"text\":\"moderator yazisi $SFX\"}"
step "akis (sahip)" 200 GET /communities/$CP/posts "$TO"
lacks "engelli yazar akista yok" "moderator yazisi $SFX" "$BODY"
step "uyeler (sahip)" 200 GET /communities/$CP/members "$TO"
lacks "engelli uye listede yok" "\"userId\":$IDM," "$BODY"
step "engeli kaldir" 204 DELETE /users/$IDM/block "$TO"

echo "== 3 kulup siniri yarisi (5 paralel istek)"
TR=$(register "qr$SFX@bingol.edu.tr" "Yaris Q")
RACE=$(mktemp)
for i in 1 2 3 4 5; do
  curl -s -o /dev/null -w '%{http_code}\n' -X POST -H "$H" -H "Authorization: Bearer $TR" $A/communities \
    -d "{\"name\":\"Yaris Kulup $SFX $i\"}" >> "$RACE".r$i &
done
wait
cat "$RACE".r* > "$RACE"
OKN=$(grep -c 202 "$RACE"); LIMN=$(grep -c 409 "$RACE")
check "tam 3 basarili" 3 "$OKN"
check "2 tanesi limit 409" 2 "$LIMN"
call GET /me/communities "$TR"
check "sahip olunan kulup sayisi 3" 3 "$(printf '%s' "$BODY" | grep -o '"ownerId"' | wc -l)"

echo "== slug cakismasi (3 farkli kullanici, ayni ad, paralel)"
rm -f "$RACE" "$RACE".r*; RACE=$(mktemp)
SLT=("$TU" "$TP" "$TB")
for i in 0 1 2; do
  TK=${SLT[$i]}
  curl -s -X POST -H "$H" -H "Authorization: Bearer $TK" $A/communities -d "{\"name\":\"Ayni Ad $SFX\"}" \
    -o "$RACE.b$i" -w '%{http_code}\n' > "$RACE.c$i" &
done
wait
cat "$RACE".c* > "$RACE"
check "slug yarisinda 5xx yok" 0 "$(grep -c '^5[0-9][0-9]' "$RACE")"
SL=$(cat "$RACE".b* | grep -o '"slug":"[^"]*' | sort | uniq -d | wc -l)
check "ayni slug iki kez verilmedi" 0 "$SL"
rm -f "$RACE".b* "$RACE".c*

echo "== yonetici onay akisi"
step "admin olmayan 403" 403 GET /admin/communities "$TO"
step "ikinci onay 409" 409 POST /admin/communities/$CP/approve "$TA"
step "gecersiz durum 400" 400 GET "/admin/communities?status=XYZ" "$TA"
step "reddedilecek kulup" 202 POST /communities "$TS" "{\"name\":\"Reddedilecek $SFX\"}"
CR=$(printf '%s' "$BODY" | idof)
step "admin reddet" 204 POST /admin/communities/$CR/reject "$TA" '{"reason":"uygunsuz"}'
step "reddedilen yabanciya 404" 404 GET /communities/$CR "$TU"
step "reddedilene katilma 404" 404 POST /communities/$CR/join "$TU"
step "reddedilene yazi yazilamaz" 409 POST /communities/$CR/posts "$TS" '{"text":"x"}'

echo "== rapor / gizleme"
step "kulup raporu" 201 POST /reports "$TS" "{\"targetType\":\"COMMUNITY\",\"targetId\":$CO,\"reason\":\"SPAM\"}"

echo
[ $FAIL -eq 0 ] && echo "TUMU GECTI" || { echo "BAZI KONTROLLER BASARISIZ"; exit 1; }

#!/usr/bin/env bash
# CANLI / STAGING guvenli duman kontrolu: salt-okur + (istege bagli) TEK test hesabi. Gercek veri DEGISTIRMEZ.
# Diger smoke*.sh betiklerinden farki: onlar yerel yigina yazar (kullanici/kulup/gonderi olusturur), bu betik yazmaz.
#
# Kullanim:
#   BASE=https://staging.ornek.net bash scripts/staging-smoke.sh                      # yalniz herkese acik kontroller
#   BASE=... TEST_EMAIL=test@bingol.edu.tr TEST_PASSWORD='...' bash scripts/staging-smoke.sh   # + giris ve oturumlu okuma
#
# Kayit + e-posta kodu (ELLE, istege bagli; gercek e-posta gonderir, tek test hesabi olusur):
#   1) REGISTER=1 BASE=... TEST_EMAIL=... TEST_PASSWORD=... bash scripts/staging-smoke.sh     -> kayit baslar, kod e-postaya gider
#   2) Kodu gelen kutusundan okuyun, sonra:  CODE=123456 BASE=... TEST_EMAIL=... TEST_PASSWORD=... bash scripts/staging-smoke.sh
#      (verify-email tamamlar ve giris yapar). Kod ASLA betiğe/log'a otomatik yazilmaz; elle verilir.
# Ortam: BASE (zorunlu; https onerilir), TEST_EMAIL, TEST_PASSWORD, REGISTER, CODE, EXPECT_VERSION (Flyway son surum, orn 830),
#        INSECURE=1 (yalniz yerel/ozel sertifika icin curl -k), NO_LOGOUT=1 (oturumu kapatma).
# Sirlar: parola ortam degiskeniyle gelir, komut satirinda/log'da gosterilmez. Cikis kodu 1 = en az bir FAIL.
set -u
BASE="${BASE:-}"; BASE="${BASE%/}"
[ -n "$BASE" ] || { echo "BASE gerekli (orn. BASE=https://bukampus.com.tr)" >&2; exit 2; }
case "$BASE" in https://*) ;; http://localhost*|http://127.*) ;; *) echo "UYARI: BASE https degil; canli sistemde https kullanin" >&2;; esac
command -v curl >/dev/null || { echo "curl gerekli" >&2; exit 2; }
command -v node >/dev/null || { echo "node gerekli (JSON ayristirma)" >&2; exit 2; }
CURL=(curl -sS -m 20 -H 'Accept-Language: tr'); [ "${INSECURE:-0}" = 1 ] && CURL+=(-k)
FAIL=0; PASS=0; SKIP=0
ok()   { PASS=$((PASS+1)); echo "  ok    $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL  $1"; }
skip() { SKIP=$((SKIP+1)); echo "  atla  $1"; }
code() { "${CURL[@]}" -o /dev/null -w '%{http_code}' "$@" 2>/dev/null || echo 000; }
jget() { node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{let v=JSON.parse(d);for(const k of process.argv[1].split(".")){v=v==null?undefined:v[k]}console.log(v===undefined||v===null?"":(typeof v==="object"?JSON.stringify(v):v))}catch(e){console.log("")}})' "$1"; }
expect() { # ad beklenen-kod yol [ek curl argumanlari]
  local name="$1" want="$2" path="$3"; shift 3
  local got; got="$(code "$@" "$BASE$path")"
  if [ "$got" = "$want" ]; then ok "$name ($got)"; else bad "$name (beklenen $want, gelen $got) $path"; fi
}

echo "== herkese acik kontroller: $BASE"
H="$("${CURL[@]}" "$BASE/actuator/health" 2>/dev/null || true)"
HC="$(code "$BASE/actuator/health")"
# Uretimde Caddy /actuator/health'i dis dunyaya KAPATIR (404 beklenir); acik ise UP olmali
case "$HC" in
  200) echo "$H" | grep -q '"UP"' && ok "actuator/health UP (yerel/staging; uretimde dis erisim kapali olmali)" || bad "actuator/health 200 ama UP degil" ;;
  404|403|401) ok "actuator/health disariya kapali ($HC) - uretim icin beklenen" ;;
  *) bad "actuator/health beklenmeyen kod $HC" ;;
esac
ST="$("${CURL[@]}" "$BASE/api/status" 2>/dev/null || true)"
[ "$(code "$BASE/api/status")" = 200 ] && ok "GET /api/status 200" || bad "GET /api/status"
case "$ST" in "{"*"}") ok "status gecerli JSON nesnesi";; *) bad "status gecerli JSON degil: ${ST:0:80}";; esac
# Bos veritabaninda ({}), ilk senkrondan once NEWS/MENU anahtarlari olmayabilir: uyari, hata degil
if echo "$ST" | grep -q '"NEWS"' && echo "$ST" | grep -q '"MENU"'; then ok "status: NEWS ve MENU kaynaklari var"; else echo "  not   status NEWS/MENU yok (henuz ilk senkron yapilmadi: INITIAL_FILL/gece 00:00 zamanlayicisi)"; fi
if echo "$ST" | grep -q '"maintenance":true'; then echo "  not   kaynak sitelerden en az biri BAKIMDA gorunuyor (eski veri sunulur; sorun degil ama bakin)"; fi

INFO="$("${CURL[@]}" "$BASE/api/app/info" 2>/dev/null || true)"
[ "$(code "$BASE/api/app/info")" = 200 ] && ok "GET /api/app/info 200" || bad "GET /api/app/info"
MM="$(echo "$INFO" | jget maintenanceMode)"; [ -z "$MM" ] && MM="$(echo "$INFO" | jget maintenance.enabled)"
[ "$MM" = "true" ] && echo "  not   uygulama GENEL BAKIM modunda (maintenance_mode acik)"
expect "GET /api/app/version" 200 "/api/app/version?platform=ANDROID&version=1.0.0"
expect "haber listesi" 200 "/api/news?size=5"
MC="$(code "$BASE/api/menu/today")"; case "$MC" in 200) ok "menu (bugun) 200";; 404) ok "menu (bugun) 404: bugun icin liste yok (beklenen olabilir, ay sonu senkronu)";; *) bad "menu (bugun) beklenmeyen kod $MC";; esac
expect "SSS" 200 /api/faq
expect "sozlesme listesi" 200 /api/legal
expect "gizlilik metni" 200 /api/legal/PRIVACY
expect "akademik katalog" 200 /api/catalog/academic
# Yetkisiz uclar kapali olmali (401/403): yanlislikla acik kalmadigini dogrular
expect "oturumsuz /api/users/me reddi" 401 /api/users/me
expect "oturumsuz /api/admin reddi" 401 /api/admin/users
# Sahte/yanlis kimlik bilgisiyle giris genel hata verir (varlik sizdirmaz), 5xx vermez
GOT="$(code -X POST -H 'Content-Type: application/json' -d '{"email":"yok.boyle.biri@bingol.edu.tr","password":"yanlis-parola-1"}' "$BASE/api/auth/login")"
case "$GOT" in 400|401|429) ok "gecersiz giris reddedildi ($GOT)";; *) bad "gecersiz giris beklenmeyen kod $GOT";; esac
# Web arayuzu: https BASE'de ZORUNLU (Play gizlilik/hesap silme URL'leri); http/yerel API-only ortamda yalniz ana sayfa 200 ise denenir (WEB=1/0 ile zorla)
WEB="${WEB:-auto}"
if [ "$WEB" = auto ]; then
  case "$BASE" in https://*) WEB=1;; *) [ "$(code -L "$BASE/")" = 200 ] && WEB=1 || WEB=0;; esac
fi
if [ "$WEB" = 1 ]; then
  for p in / /tr /tr/privacy /tr/delete-account /tr/data-request /en/privacy /ar/privacy; do
    c="$(code -L "$BASE$p")"; [ "$c" = 200 ] && ok "web $p ($c)" || bad "web $p ($c)"
  done
else
  skip "web arayuzu yok (API-only ortam); canli https BASE'de otomatik denetlenir"
fi
# Guvenlik basliklari (Caddy/uygulama)
HDR="$("${CURL[@]}" -I "$BASE/" 2>/dev/null | tr -d '\r' || true)"
case "$BASE" in https://*) echo "$HDR" | grep -qi '^strict-transport-security:' && ok "HSTS basligi var" || bad "HSTS basligi yok";; esac
echo "$HDR" | grep -qi '^x-content-type-options:' && ok "X-Content-Type-Options var" || bad "X-Content-Type-Options yok"

echo "== kimlik kontrolleri (tek test hesabi)"
TEST_EMAIL="${TEST_EMAIL:-}"; TEST_PASSWORD="${TEST_PASSWORD:-}"
TOKEN=""; REFRESH=""
if [ -z "$TEST_EMAIL" ] || [ -z "$TEST_PASSWORD" ]; then
  skip "TEST_EMAIL/TEST_PASSWORD verilmedi: giris ve oturumlu kontroller atlandi"
else
  if [ "${REGISTER:-0}" = 1 ]; then
    GOT="$(code -X POST -H 'Content-Type: application/json' -d "$(node -e 'console.log(JSON.stringify({email:process.argv[1],password:process.argv[2],displayName:"Duman Test",acceptTerms:true}))' "$TEST_EMAIL" "$TEST_PASSWORD")" "$BASE/api/auth/register")"
    case "$GOT" in 200|201|202|204) ok "kayit baslatildi ($GOT): kodu e-postadan okuyup CODE=... ile yeniden calistirin";; 409) ok "hesap zaten dogrulanmis (409): normal";; *) bad "kayit beklenmeyen kod $GOT";; esac
  fi
  if [ -n "${CODE:-}" ]; then
    R="$("${CURL[@]}" -X POST -H 'Content-Type: application/json' -d "$(node -e 'console.log(JSON.stringify({email:process.argv[1],code:process.argv[2],password:process.argv[3]}))' "$TEST_EMAIL" "$CODE" "$TEST_PASSWORD")" "$BASE/api/auth/verify-email" 2>/dev/null || true)"
    TOKEN="$(echo "$R" | jget accessToken)"; REFRESH="$(echo "$R" | jget refreshToken)"
    [ -n "$TOKEN" ] && ok "verify-email (elle verilen kod) basarili" || bad "verify-email basarisiz (kod yanlis/suresi dolmus?)"
  fi
  if [ -z "$TOKEN" ]; then
    R="$("${CURL[@]}" -X POST -H 'Content-Type: application/json' -d "$(node -e 'console.log(JSON.stringify({email:process.argv[1],password:process.argv[2]}))' "$TEST_EMAIL" "$TEST_PASSWORD")" "$BASE/api/auth/login" 2>/dev/null || true)"
    TOKEN="$(echo "$R" | jget accessToken)"; REFRESH="$(echo "$R" | jget refreshToken)"
    [ -n "$TOKEN" ] && ok "giris basarili (access JWT alindi)" || bad "giris basarisiz (hesap dogrulanmis mi? parola dogru mu?)"
  fi
fi
if [ -n "$TOKEN" ]; then
  A=(-H "Authorization: Bearer $TOKEN")
  expect "GET /api/auth/me" 200 /api/auth/me "${A[@]}"
  expect "GET /api/users/me" 200 /api/users/me "${A[@]}"
  expect "kesfet akisi" 200 "/api/feed?size=5" "${A[@]}"
  expect "sohbet listesi" 200 /api/conversations "${A[@]}"
  expect "bildirim sayaci" 200 /api/notifications/unread-count "${A[@]}"
  expect "bildirim listesi" 200 "/api/notifications?size=5" "${A[@]}"
  expect "sozlesme onay durumu" 200 /api/legal/acceptance-status "${A[@]}"
  expect "kulup listesi" 200 "/api/communities?size=5" "${A[@]}"
  expect "etkinlik listesi" 200 "/api/events?size=5" "${A[@]}"
  # Test hesabi ADMIN degilse admin ucu 403 olmali (yetki sizintisi kontrolu); ADMIN ise 200
  AC="$(code "${A[@]}" "$BASE/api/admin/users")"
  case "$AC" in 403) ok "test hesabi admin ucuna erisemiyor (403)";; 200) echo "  not   test hesabi ADMIN (200): ayri bir sade hesap kullanmaniz onerilir";; *) bad "admin ucu beklenmeyen kod $AC";; esac
  if [ "${NO_LOGOUT:-0}" != 1 ] && [ -n "$REFRESH" ]; then
    LC="$(code -X POST -H 'Content-Type: application/json' -d "$(node -e 'console.log(JSON.stringify({refreshToken:process.argv[1]}))' "$REFRESH")" "$BASE/api/auth/logout")"
    [ "$LC" = 204 ] && ok "oturum kapatildi (yalniz bu test oturumu)" || bad "logout kod $LC"
  fi
fi

echo
echo "SONUC: $PASS gecti, $FAIL basarisiz, $SKIP atlandi"
[ "$FAIL" = 0 ]

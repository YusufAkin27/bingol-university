#!/usr/bin/env bash
# UPDATEGATE duman testi (yonetim panelinden zorunlu uygulama guncelleme): herkese acik surum kontrolu yeni alanlari
# (storeUrl turetme, marketUrl, message) -> yetki -> gerekcesiz zorlama 400 -> FORCE/SOFT/OFF -> surum<latest reddi
# -> zorlama sonrasi ANINDA etki -> denetim kaydi -> ayarlari geri yukleme.
# Calisan compose yigina karsi, ASCII, tekrar calistirilabilir. Duman verisi icin ios ayarlari DEGISTIRILMEZ.
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ./scripts/smoke-app-version.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur), ADMIN_EMAILS=$ADMIN_EMAIL, V1030 migration uygulanmis.
# Not: COMPOSE_PROJECT_NAME ile ayri proje kullaniliyorsa ayni degisken bu betikte de verilmelidir (docker compose logs).
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
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true,\"language\":\"tr\"}"
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

# setting <anahtar> <deger>: gerekceli ayar yazimi (kodu doner)
setting() { code -X PUT -H "$H" -H "$AD" -H 'X-Admin-Reason: duman testi' "$A/admin/settings/$1" -d "{\"value\":\"$2\"}"; }
# jval <json> <alan>: duz alan degeri (dize ya da sayi/bool)
jval() { echo "$1" | grep -o "\"$2\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }

SFX=$RANDOM$RANDOM

echo "== hazirlik"
TA=$(register "$ADMIN_EMAIL" "Yonetici")
TU=$(register "smkupd$SFX@bingol.edu.tr" "Smoke Update")
[ -n "$TA" ] && [ -n "$TU" ] || { echo "token alinamadi (ADMIN_EMAILS ayarli mi?)"; exit 1; }
AD="Authorization: Bearer $TA"; US="Authorization: Bearer $TU"

SET=$(curl -s -H "$AD" $A/admin/settings)
O_MIN=$(jval "$SET" min_version_android)
O_LATEST=$(jval "$SET" latest_version_android)
O_MSG_EN=$(jval "$SET" update_message_en)
O_STORE=$(jval "$SET" store_url_android)
[ -n "$O_MIN" ] && [ -n "$O_LATEST" ] || { echo "ayarlar okunamadi"; exit 1; }
echo "  eski ayarlar: min=$O_MIN latest=$O_LATEST"

echo "== herkese acik surum kontrolu: yeni alanlar"
V=$(curl -s "$A/app/version?platform=android&version=0.0.1")
has "marketUrl var" '"marketUrl":"market://details?id=' "$V"
has "storeUrl dolu (turetilmis ya da yonetici)" '"storeUrl":"https://' "$V"
has "message alani" '"message"' "$V"
check "gecersiz platform 400" 400 "$(code "$A/app/version?platform=web&version=1.0.0")"

echo "== yetki"
check "anonim dagilim" 401 "$(code $A/admin/app-versions)"
check "kullanici dagilim" 403 "$(code -H "$US" $A/admin/app-versions)"
check "kullanici zorlama" 403 "$(code -X POST -H "$H" -H "$US" -H 'X-Admin-Reason: yetkisiz deneme' $A/admin/app-versions/enforce -d '{"platform":"android","mode":"OFF"}')"

echo "== dagilim"
D=$(curl -s -H "$AD" $A/admin/app-versions)
has "kaynak etiketi" '"source":"USER_DEVICE_LOG"' "$D"
has "pencere" '"windowDays":30' "$D"
has "android ozeti" '"platform":"android"' "$D"
has "ios ozeti" '"platform":"ios"' "$D"

echo "== ayar dogrulama (yeni anahtarlar)"
check "metin html reddi 400" 400 "$(setting update_message_tr '<b>x</b>')"
check "metin baglanti reddi 400" 400 "$(setting update_message_tr 'bak https://x.example')"
check "paket gecersiz 400" 400 "$(setting store_package_android 'tek')"
check "apple kimligi harf 400" 400 "$(setting apple_app_id_ios 'abc123')"
check "ingilizce metin 204" 204 "$(setting update_message_en 'Please update to continue.')"

echo "== zorlama: gerekce ve sinirlar"
BODY="{\"platform\":\"android\",\"mode\":\"FORCE\",\"version\":\"99.0.0\"}"
check "gerekcesiz FORCE 400" 400 "$(code -X POST -H "$H" -H "$AD" $A/admin/app-versions/enforce -d "$BODY")"
check "gecersiz kip 400" 400 "$(code -X POST -H "$H" -H "$AD" -H 'X-Admin-Reason: duman testi' $A/admin/app-versions/enforce -d '{"platform":"android","mode":"NUKE","version":"99.0.0"}')"
check "gecersiz platform 400" 400 "$(code -X POST -H "$H" -H "$AD" -H 'X-Admin-Reason: duman testi' $A/admin/app-versions/enforce -d '{"platform":"web","mode":"FORCE","version":"99.0.0"}')"
check "gecersiz surum 400" 400 "$(code -X POST -H "$H" -H "$AD" -H 'X-Admin-Reason: duman testi' $A/admin/app-versions/enforce -d '{"platform":"android","mode":"FORCE","version":"x.y"}')"
LOW=$(curl -s -X POST -H "$H" -H "$AD" -H 'X-Admin-Reason: duman testi' $A/admin/app-versions/enforce -d '{"platform":"android","mode":"FORCE","version":"0.0.1"}')
has "latest altina FORCE reddi" '"code":"VERSION_BELOW_LATEST"' "$LOW"

echo "== FORCE: aninda etki"
check "once 99.0.0 zorunlu degil" "false" "$(curl -s "$A/app/version?platform=android&version=99.0.0" | grep -o '"updateRequired":[a-z]*' | cut -d: -f2)"
R=$(curl -s -X POST -H "$H" -H "$AD" -H 'X-Admin-Reason: duman testi FORCE' $A/admin/app-versions/enforce -d "$BODY")
has "FORCE durumu" '"state":"FORCE"' "$R"
has "yeni min" '"minVersion":"99.0.0"' "$R"
has "kaynak etiketi" '"source":"USER_DEVICE_LOG"' "$R"
V=$(curl -s -H 'Accept-Language: en' "$A/app/version?platform=android&version=98.9.9")
has "eski surum zorunlu (aninda)" '"updateRequired":true' "$V"
has "yayindaki surum" '"latestVersion":"99.0.0"' "$V"
has "ingilizce mesaj" '"message":"Please update to continue."' "$V"
check "yeni surum zorunlu degil" "false" "$(curl -s "$A/app/version?platform=android&version=99.0.0" | grep -o '"updateRequired":[a-z]*' | cut -d: -f2)"
check "ios etkilenmedi" "false" "$(curl -s "$A/app/version?platform=ios&version=1.0.0" | grep -o '"updateRequired":[a-z]*' | cut -d: -f2)"

echo "== SOFT ve OFF"
S=$(curl -s -X POST -H "$H" -H "$AD" -H 'X-Admin-Reason: duman testi SOFT' $A/admin/app-versions/enforce -d '{"platform":"android","mode":"SOFT","version":"99.1.0"}')
has "SOFT latest 99.1.0" '"latestVersion":"99.1.0"' "$S"
has "SOFT min degismedi" '"minVersion":"99.0.0"' "$S"
LOWS=$(curl -s -X POST -H "$H" -H "$AD" -H 'X-Admin-Reason: duman testi' $A/admin/app-versions/enforce -d '{"platform":"android","mode":"SOFT","version":"98.0.0"}')
has "min altina SOFT reddi" '"code":"VERSION_BELOW_MIN"' "$LOWS"
O=$(curl -s -X POST -H "$H" -H "$AD" -H 'X-Admin-Reason: duman testi OFF' $A/admin/app-versions/enforce -d '{"platform":"android","mode":"OFF"}')
has "OFF min varsayilan" '"minVersion":"1.0.0"' "$O"
check "OFF sonrasi zorunlu degil (aninda)" "false" "$(curl -s "$A/app/version?platform=android&version=98.9.9" | grep -o '"updateRequired":[a-z]*' | cut -d: -f2)"

echo "== denetim kaydi"
AU=$(curl -s -H "$AD" "$A/admin/audit?size=40")
has "denetimde zorlama kaydi" '/api/admin/app-versions/enforce' "$AU"

echo "== geri yukleme"
check "latest geri" 204 "$(setting latest_version_android "$O_LATEST")"
check "min geri" 204 "$(setting min_version_android "$O_MIN")"
check "metin geri" 204 "$(setting update_message_en "$O_MSG_EN")"
[ -n "$O_STORE" ] && setting store_url_android "$O_STORE" >/dev/null
V=$(curl -s "$A/app/version?platform=android&version=0.0.1")
has "ayarlar geri yuklendi" "\"latestVersion\":\"$O_LATEST\"" "$V"

if [ "$FAIL" = "0" ]; then echo "TAMAM: smoke-app-version"; else echo "BASARISIZ: smoke-app-version"; exit 1; fi

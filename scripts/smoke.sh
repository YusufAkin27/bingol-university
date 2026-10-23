#!/usr/bin/env bash
# Calisan yigina (docker compose) karsi uctan uca duman testi.
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ./scripts/smoke.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur) ve ADMIN_EMAILS=$ADMIN_EMAIL
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0

check() { # ad beklenen-kod gercek-kod
  if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi
}
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

# kayit + dogrulama -> access token
register() {
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true,\"language\":\"${3:-tr}\"}"
  sleep 1
  local c t
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  t=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  # Hesap onceden kayitliysa (ornek: onceki betik) giris yap
  if [ -z "$t" ]; then
    t=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" |
      grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  fi
  echo "$t"
}
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

SFX=$RANDOM
echo "== kullanicilar"
T1=$(register "ali$SFX@bingol.edu.tr" "Ali Veli");  T2=$(register "ayse$SFX@bingol.edu.tr" "Ayse Yilmaz")
TA=$(register "$ADMIN_EMAIL" "Yonetici" || true)
[ -n "$T1" ] && [ -n "$T2" ] || { echo "kayit basarisiz"; exit 1; }
ID1=$(curl -s -H "Authorization: Bearer $T1" $A/users/me | idof)
ID2=$(curl -s -H "Authorization: Bearer $T2" $A/users/me | idof)
AUTH1="Authorization: Bearer $T1"; AUTH2="Authorization: Bearer $T2"

echo "== profil"
check "guncelle" 200 "$(code -X PATCH -H "$H" -H "$AUTH1" $A/users/me -d '{"department":"Bilgisayar Muhendisligi","classYear":3,"bio":"Merhaba"}')"
check "gecersiz classYear" 400 "$(code -X PATCH -H "$H" -H "$AUTH1" $A/users/me -d '{"classYear":99}')"
check "bozuk json 400" 400 "$(code -X POST -H "$H" -H "$AUTH1" $A/devices -d '{bozuk')"
check "arama" 200 "$(code -H "$AUTH2" "$A/users/search?q=ali")"
check "arama cok kisa" 400 "$(code -H "$AUTH2" "$A/users/search?q=a")"
check "profil baskasi" 200 "$(code -H "$AUTH2" $A/users/$ID1)"
check "bolumler" 200 "$(code -H "$AUTH2" $A/departments)"
PNG="$(mktemp --suffix=.png)"; printf '\x89PNG\r\n\x1a\n' > "$PNG"
PNGW=$(cygpath -m "$PNG" 2>/dev/null || echo "$PNG")
check "avatar yukle" 200 "$(code -X POST -H "$AUTH1" -F "file=@$PNGW;type=image/png" $A/users/me/avatar)"
check "avatar yanlis tur" 400 "$(code -X POST -H "$AUTH1" -F "file=@$PNGW;type=text/html" $A/users/me/avatar)"
URL=$(curl -s -H "$AUTH1" $A/users/me | grep -o '"avatarUrl":"[^"]*' | cut -d'"' -f4)
check "avatar dosyasi servis" 200 "$(code "$BASE$URL")"

echo "== engelleme"
check "engelle" 204 "$(code -X POST -H "$AUTH2" $A/users/$ID1/block)"
check "kendini engelleme" 400 "$(code -X POST -H "$AUTH2" $A/users/$ID2/block)"
check "engelli profil 404" 404 "$(code -H "$AUTH2" $A/users/$ID1)"
check "engel kaldir" 204 "$(code -X DELETE -H "$AUTH2" $A/users/$ID1/block)"

echo "== rapor ve yonetim"
RPT=$(curl -s -w " [%{http_code}]" -X POST -H "$H" -H "$AUTH1" $A/reports -d "{\"targetType\":\"USER\",\"targetId\":$ID2,\"reason\":\"SPAM\"}")
check "rapor" "201" "$(echo "$RPT" | grep -o "[0-9]*]$" | tr -d "]")"
RID=$(echo "$RPT" | grep -o "\"id\":[0-9]*" | head -1 | cut -d: -f2)
check "ayni rapor 409" 409 "$(code -X POST -H "$H" -H "$AUTH1" $A/reports -d "{\"targetType\":\"USER\",\"targetId\":$ID2,\"reason\":\"SPAM\"}")"
check "kendini raporlama" 400 "$(code -X POST -H "$H" -H "$AUTH1" $A/reports -d "{\"targetType\":\"USER\",\"targetId\":$ID1,\"reason\":\"SPAM\"}")"
check "normal kullanici admin 403" 403 "$(code -H "$AUTH1" $A/admin/stats)"
if [ -n "$TA" ]; then
  AUTHA="Authorization: Bearer $TA"
  check "admin stats" 200 "$(code -H "$AUTHA" $A/admin/stats)"
  # (RID: yukarida olusturulan raporun id si)
  check "rapor coz (askiya al)" 204 "$(code -X POST -H "$H" -H "$AUTHA" $A/admin/reports/$RID/resolve -d '{"action":"SUSPEND_USER","message":"test"}')"
  check "askidaki kullanici token'i gecersiz" 401 "$(code -H "$AUTH2" $A/users/me)"
  check "askidaki giris 403" 403 "$(code -X POST -H "$H" $A/auth/login -d "{\"email\":\"ayse$SFX@bingol.edu.tr\",\"password\":\"Sifre1234\"}")"
  check "geri ac" 204 "$(code -X POST -H "$AUTHA" $A/admin/users/$ID2/unsuspend)"
else
  echo "  atlandi: admin token yok (ADMIN_EMAILS ayarli mi?)"
fi

echo "== bildirim"
check "tercih" 200 "$(code -X PUT -H "$H" -H "$AUTH1" $A/notifications/preferences -d '{"news":false,"announcements":true,"events":true,"messages":true,"communities":true}')"
check "cihaz kaydi" 204 "$(code -X POST -H "$H" -H "$AUTH1" $A/devices -d '{"fcmToken":"tok-smoke","platform":"ANDROID"}')"
check "liste" 200 "$(code -H "$AUTH1" $A/notifications)"
check "tumunu okundu" 204 "$(code -X POST -H "$H" -H "$AUTH1" $A/notifications/read -d '{"all":true}')"

echo "== hesap silme"
check "yanlis sifre" 403 "$(code -X DELETE -H "$H" -H "$AUTH1" $A/users/me -d '{"password":"yanlis"}')"
check "hesap sil" 204 "$(code -X DELETE -H "$H" -H "$AUTH1" $A/users/me -d '{"password":"Sifre1234"}')"
check "silinmis giris 401" 401 "$(code -X POST -H "$H" $A/auth/login -d "{\"email\":\"ali$SFX@bingol.edu.tr\",\"password\":\"Sifre1234\"}")"

[ $FAIL -eq 0 ] && echo "TUMU GECTI" || echo "HATA VAR"
exit $FAIL

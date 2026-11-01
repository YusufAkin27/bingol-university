#!/usr/bin/env bash
# E-posta kodlu iki faktorlu dogrulama (2FA) icin uctan uca duman testi (docs/TWO_FACTOR_API.md):
# acma (istek + onay), tanimsiz cihazdan 202 + kod, yanlis kod, yeniden gonderme, guvenilen cihaz (kodsuz giris),
# baslik yoksa her giriste kod, cihaz listesi/silme, sifreyle kapatma, yonetici ozeti/listesi/suzgeci/kurtarma kapatmasi.
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ./scripts/smoke-two-factor.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod `docker compose logs backend` ciktisindan okunur), ADMIN_EMAILS=$ADMIN_EMAIL.
# Idempotent: her calistirmada benzersiz kullanici/cihaz kimlikleri uretilir. Betikler arasi redis flushall onerilir
# (kayit ucu IP basina saatte 10 ile sinirlidir).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
PW='Zk7-Qmv-Lpx92w'
FAIL=0

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 300)"; FAIL=1; fi; }
hasnt() { if echo "$3" | grep -qF -- "$2"; then echo "  FAIL $1 (bulunmamali: $2)"; FAIL=1; else echo "  ok   $1"; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
field() { grep -o "\"$1\":\"[^\"]*" | head -1 | cut -d'"' -f4; }
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

# Verilen adrese giden SON iki faktorlu kodu log'dan okur (yeni satir gelene kadar kisa bekler).
last_code() {
  local c i
  for i in 1 2 3 4 5 6 7 8; do
    c=$(docker compose logs backend 2>&1 | grep "$1 icin iki faktorlu giris kodu" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
    if [ -n "$c" ] && [ "$c" != "${2:-}" ]; then echo "$c"; return; fi
    sleep 1
  done
  echo "$c"
}

register() { # $1 e-posta, $2 ad -> access token
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"$PW\",\"displayName\":\"$2\",\"acceptTerms\":true,\"language\":\"tr\"}"
  sleep 1
  local c t
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  t=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"$PW\"}" | field accessToken)
  if [ -z "$t" ]; then
    t=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"$PW\"}" | field accessToken)
  fi
  echo "$t"
}

SFX=$RANDOM$RANDOM
EMAIL="ikifaktor$SFX@bingol.edu.tr"
DEVA="smoke-2fa-device-A-$SFX"
DEVB="smoke-2fa-device-B-$SFX"
DEVC="smoke-2fa-device-C-$SFX"
dev() { echo "X-Device-Id: $1"; }

echo "== kullanici"
T0=$(register "$EMAIL" "Iki Faktor")
[ -n "$T0" ] && echo "  ok   kayit" || { echo "  FAIL kayit"; exit 1; }
AUTHA="Authorization: Bearer $T0"
UID_=$(curl -s -H "$AUTHA" $A/users/me | idof)

echo "== 2FA kapaliyken giris duz 200 (kodsuz)"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$(dev $DEVA)" $A/auth/login -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\"}")
check "kapali 2FA login" 200 "$(echo "$R" | tail -1)"
has "TokenResponse biciminde" '"accessToken"' "$R"
hasnt "twoFactorRequired yok" 'twoFactorRequired' "$R"

echo "== anonim ve durum uclari"
check "anonim GET /auth/2fa" 401 "$(code $A/auth/2fa)"
check "anonim enable/request" 401 "$(code -X POST $A/auth/2fa/enable/request)"
S=$(curl -s -H "$AUTHA" -H "$(dev $DEVA)" $A/auth/2fa)
has "durum: kapali" '"enabled":false' "$S"
check "kapaliyken disable" 409 "$(code -X POST -H "$H" -H "$AUTHA" $A/auth/2fa/disable -d "{\"password\":\"$PW\"}")"

echo "== acma: istek + onay"
check "enable/request" 202 "$(code -X POST -H "$AUTHA" -H "$(dev $DEVA)" $A/auth/2fa/enable/request)"
C1=$(last_code "$EMAIL")
[ -n "$C1" ] && echo "  ok   acma kodu log'da" || { echo "  FAIL acma kodu yok"; exit 1; }
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$AUTHA" -H "$(dev $DEVA)" $A/auth/2fa/enable/confirm -d '{"code":"000000"}')
check "yanlis onay kodu" 400 "$(echo "$R" | tail -1)"
has "TWO_FACTOR_CODE_INVALID" '"code":"TWO_FACTOR_CODE_INVALID"' "$R"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$AUTHA" -H "$(dev $DEVA)" $A/auth/2fa/enable/confirm -d "{\"code\":\"$C1\"}")
check "onay" 200 "$(echo "$R" | tail -1)"
has "enabled true" '"enabled":true' "$R"
check "zaten acik: enable/request" 409 "$(code -X POST -H "$AUTHA" $A/auth/2fa/enable/request)"
S=$(curl -s -H "$AUTHA" -H "$(dev $DEVA)" $A/auth/2fa)
has "durum: acik" '"enabled":true' "$S"
has "bu cihaz guvenilir" '"currentDeviceTrusted":true' "$S"
has "1 guvenilen cihaz" '"trustedDeviceCount":1' "$S"

echo "== guvenilen cihazdan giris kodsuz"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$(dev $DEVA)" $A/auth/login -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\"}")
check "cihaz A login" 200 "$(echo "$R" | tail -1)"
has "token geldi" '"accessToken"' "$R"

echo "== tanimsiz cihaz: 202 + kod, token yok"
PREV=$C1
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$(dev $DEVB)" $A/auth/login -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\"}")
check "cihaz B login" 202 "$(echo "$R" | tail -1)"
has "twoFactorRequired" '"twoFactorRequired":true' "$R"
has "emailHint maskeli" '***@bingol.edu.tr' "$R"
has "expiresInSeconds" '"expiresInSeconds":600' "$R"
hasnt "token yok" '"accessToken"' "$R"
CH=$(echo "$R" | head -1 | field challengeToken)
[ -n "$CH" ] && echo "  ok   challengeToken" || { echo "  FAIL challengeToken yok"; exit 1; }
C2=$(last_code "$EMAIL" "$PREV")
[ -n "$C2" ] && echo "  ok   giris kodu log'da" || { echo "  FAIL giris kodu yok"; exit 1; }
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$(dev $DEVB)" $A/auth/login/2fa -d "{\"challengeToken\":\"$CH\",\"code\":\"000000\"}")
check "yanlis kod" 400 "$(echo "$R" | tail -1)"
has "TWO_FACTOR_CODE_INVALID" '"code":"TWO_FACTOR_CODE_INVALID"' "$R"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" $A/auth/login/2fa -d '{"challengeToken":"uydurma-jeton","code":"123456"}')
check "bilinmeyen challenge" 400 "$(echo "$R" | tail -1)"
has "TWO_FACTOR_CHALLENGE_EXPIRED" '"code":"TWO_FACTOR_CHALLENGE_EXPIRED"' "$R"
echo "== yeniden gonderme"
check "resend" 202 "$(code -X POST -H "$H" $A/auth/login/2fa/resend -d "{\"challengeToken\":\"$CH\"}")"
C3=$(last_code "$EMAIL" "$C2")
[ -n "$C3" ] && echo "  ok   yeni kod geldi" || { echo "  FAIL yeni kod yok"; exit 1; }
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$(dev $DEVB)" $A/auth/login/2fa -d "{\"challengeToken\":\"$CH\",\"code\":\"$C3\",\"trustDevice\":true}")
check "dogru kod" 200 "$(echo "$R" | tail -1)"
has "token geldi" '"accessToken"' "$R"
BT=$(echo "$R" | head -1 | field accessToken)
check "challenge tek kullanimlik" 400 "$(code -X POST -H "$H" $A/auth/login/2fa -d "{\"challengeToken\":\"$CH\",\"code\":\"$C3\"}")"
check "yeni token gecerli (/auth/me)" 200 "$(code -H "Authorization: Bearer $BT" $A/auth/me)"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$(dev $DEVB)" $A/auth/login -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\"}")
check "cihaz B artik guvenilir: kodsuz" 200 "$(echo "$R" | tail -1)"

echo "== cihaz basligi yoksa her giriste kod"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" $A/auth/login -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\"}")
check "basliksiz login" 202 "$(echo "$R" | tail -1)"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$(dev $DEVC)" $A/auth/login -d "{\"email\":\"$EMAIL\",\"password\":\"wrong-password-1\"}")
check "yanlis sifre 2FA'ya girmez" 401 "$(echo "$R" | tail -1)"
has "genel hata" '"code":"INVALID_CREDENTIALS"' "$R"

echo "== guvenilen cihaz listesi / silme"
L=$(curl -s -H "$AUTHA" -H "$(dev $DEVA)" $A/auth/2fa/devices)
check "2 cihaz" 2 "$(echo "$L" | grep -o '"id":' | wc -l)"
has "current isareti" '"current":true' "$L"
has "etiket" '"label"' "$L"
hasnt "ham/ozet kimlik yok" 'deviceHash' "$L"
OTHER=$(echo "$L" | grep -o '{[^}]*"current":false[^}]*}' | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
[ -n "$OTHER" ] && check "cihaz sil" 204 "$(code -X DELETE -H "$AUTHA" $A/auth/2fa/devices/$OTHER)" || { echo "  FAIL silinecek cihaz bulunamadi"; FAIL=1; }
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$(dev $DEVB)" $A/auth/login -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\"}")
check "silinen cihaz tekrar kod ister" 202 "$(echo "$R" | tail -1)"
check "mevcut cihaz etkilenmedi" 200 "$(code -X POST -H "$H" -H "$(dev $DEVA)" $A/auth/login -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\"}")"

echo "== yonetici: ozet / liste / suzgec"
TA=$(register "$ADMIN_EMAIL" "Yonetici")
[ -n "$TA" ] || { echo "  FAIL yonetici tokeni yok"; exit 1; }
AAD="Authorization: Bearer $TA"
SUM=$(curl -s -H "$AAD" $A/admin/two-factor/summary)
has "ozet alanlari" '"enabledCount"' "$SUM"
has "ozet yuzde" '"enabledPercent"' "$SUM"
has "ozet cihaz toplami" '"trustedDeviceTotal"' "$SUM"
check "kullanici ozeti goremez" 403 "$(code -H "Authorization: Bearer $T0" $A/admin/two-factor/summary)"
check "anonim ozet" 401 "$(code $A/admin/two-factor/summary)"
LST=$(curl -s -H "$AAD" "$A/admin/two-factor/users?q=ikifaktor$SFX")
has "liste: kullanici" "\"userId\":$UID_" "$LST"
has "liste: cihaz sayisi" '"trustedDeviceCount"' "$LST"
has "liste: sayfa alanlari" '"totalElements":1' "$LST"
UL=$(curl -s -H "$AAD" "$A/admin/users?q=ikifaktor$SFX&twoFactor=true")
has "kullanici listesi twoFactor=true" '"twoFactorEnabled":true' "$UL"
UL=$(curl -s -H "$AAD" "$A/admin/users?q=ikifaktor$SFX&twoFactor=false")
has "twoFactor=false listede degil" '"totalItems":0' "$UL"
DT=$(curl -s -H "$AAD" $A/admin/users/$UID_)
has "ayrinti: twoFactorEnabled" '"twoFactorEnabled":true' "$DT"
has "ayrinti: cihaz sayisi" '"twoFactorTrustedDeviceCount":1' "$DT"
has "ayrinti: enabledAt" '"twoFactorEnabledAt":"' "$DT"

echo "== yonetici kurtarma kapatmasi (gerekce zorunlu)"
check "gerekcesiz" 400 "$(code -X POST -H "$H" -H "$AAD" $A/admin/users/$UID_/two-factor/disable -d '{}')"
check "kullanici yapamaz" 403 "$(code -X POST -H "$H" -H "Authorization: Bearer $T0" $A/admin/users/$UID_/two-factor/disable -d '{"reason":"duman testi kurtarma"}')"
check "kapat" 204 "$(code -X POST -H "$H" -H "$AAD" $A/admin/users/$UID_/two-factor/disable -d '{"reason":"duman testi: hesap kurtarma"}')"
check "tekrar kapat 409" 409 "$(code -X POST -H "$H" -H "$AAD" $A/admin/users/$UID_/two-factor/disable -d '{"reason":"duman testi: hesap kurtarma"}')"
S=$(curl -s -H "$AUTHA" -H "$(dev $DEVA)" $A/auth/2fa)
has "durum: kapali" '"enabled":false' "$S"
has "cihazlar silindi" '"trustedDeviceCount":0' "$S"
check "cihaz C kodsuz giris" 200 "$(code -X POST -H "$H" -H "$(dev $DEVC)" $A/auth/login -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\"}")"
NT=$(curl -s -H "$AUTHA" "$A/notifications?size=10")
has "kullaniciya bildirim (kapatildi)" 'kapat' "$NT"

echo "== yeniden ac + sifreyle kapat"
check "enable/request" 202 "$(code -X POST -H "$AUTHA" -H "$(dev $DEVA)" $A/auth/2fa/enable/request)"
C4=$(last_code "$EMAIL" "$C3")
check "onay" 200 "$(code -X POST -H "$H" -H "$AUTHA" -H "$(dev $DEVA)" $A/auth/2fa/enable/confirm -d "{\"code\":\"$C4\"}")"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$AUTHA" $A/auth/2fa/disable -d '{"password":"yanlis-parola-99"}')
check "yanlis sifre" 400 "$(echo "$R" | tail -1)"
has "INVALID_PASSWORD" '"code":"INVALID_PASSWORD"' "$R"
S=$(curl -s -H "$AUTHA" -H "$(dev $DEVA)" $A/auth/2fa)
has "hala acik" '"enabled":true' "$S"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$AUTHA" $A/auth/2fa/disable -d "{\"password\":\"$PW\"}")
check "sifreyle kapat" 200 "$(echo "$R" | tail -1)"
has "enabled false" '"enabled":false' "$R"

echo "== dil: hata metni istek dilinde"
R=$(curl -s -X POST -H "$H" -H 'Accept-Language: en' $A/auth/login/2fa -d '{"challengeToken":"uydurma-jeton","code":"123456"}')
has "en mesaj" 'expired' "$R"
R=$(curl -s -X POST -H "$H" -H 'Accept-Language: ar' $A/auth/login/2fa -d '{"challengeToken":"uydurma-jeton","code":"123456"}')
has "ar kodu" '"code":"TWO_FACTOR_CHALLENGE_EXPIRED"' "$R"

echo
[ "$FAIL" = 0 ] && echo "IKI FAKTOR: TAMAM" || { echo "IKI FAKTOR: HATA VAR"; exit 1; }

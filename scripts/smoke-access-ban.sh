#!/usr/bin/env bash
# Erisim engelleri (IP / CIDR / cihaz / kullanici) icin uctan uca duman testi.
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ./scripts/smoke-access-ban.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur), ADMIN_EMAILS=$ADMIN_EMAIL, calisan postgres/redis.
# IP simulasyonu: backend dogrudan (docker port yonlendirme / loopback) erisildiginde ozel ag eslerinden gelen
# X-Forwarded-For dikkate alinir (ClientIp). Ozel ag/loopback adresleri engellenemez; testte 203.0.113.0/24
# (TEST-NET-3) ve 198.51.100.0/24 (TEST-NET-2) belge adresleri kullanilir.
# Idempotent: benzersiz kullanici/cihaz adlari kullanilir, sonunda olusturulan engeller kaldirilir.
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0
SFX=$RANDOM$RANDOM

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()   { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 300)"; FAIL=1; fi; }
code()  { curl -s -o /dev/null -w '%{http_code}' "$@"; }
idof()  { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

# kayit + dogrulama -> access token (hesap varsa giris). Ek basliklar: $3...
register() {
  local email=$1 name=$2
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$email\",\"password\":\"Sifre1234\",\"displayName\":\"$name\",\"acceptTerms\":true,\"language\":\"tr\"}"
  sleep 1
  local c t
  c=$(docker compose logs backend 2>&1 | grep "$email icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  t=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$email\",\"code\":\"$c\",\"password\":\"Sifre1234\",\"client\":\"mobile\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  if [ -z "$t" ]; then
    t=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$email\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  fi
  echo "$t"
}

echo "== yonetici"
TA=$(register "$ADMIN_EMAIL" "Yonetici")
[ -n "$TA" ] || { echo "admin token yok (ADMIN_EMAILS ayarli mi?)"; exit 1; }
AAD="Authorization: Bearer $TA"
ADMIN_IP="198.51.100.5"          # yoneticinin simule edilen IP'si
XA="X-Forwarded-For: $ADMIN_IP"
adm() { curl -s -H "$AAD" -H "$XA" -H "$H" "$@"; }
admcode() { curl -s -o /dev/null -w '%{http_code}' -H "$AAD" -H "$XA" -H "$H" "$@"; }

echo "== yetki: ADMIN olmayan erisemez"
check "anonim liste" 401 "$(code $A/admin/access-bans)"

echo "== IP engeli"
BANIP="203.0.113.$((RANDOM % 200 + 20))"
R=$(adm -X POST $A/admin/access-bans -d "{\"kind\":\"IP\",\"value\":\"$BANIP\",\"reasonCode\":\"ABUSE\",\"note\":\"smoke $SFX\"}")
has "IP engeli olustu" '"kind":"IP"' "$R"
BID=$(echo "$R" | idof)
check "engelli IP: herkese acik uc 403" 403 "$(code -H "X-Forwarded-For: $BANIP" $A/news)"
has "govde ACCESS_BLOCKED" '"code":"ACCESS_BLOCKED"' "$(curl -s -H "X-Forwarded-For: $BANIP" $A/news)"
check "engelli IP: giris ucu 403" 403 "$(code -X POST -H "$H" -H "X-Forwarded-For: $BANIP" $A/auth/login -d '{"email":"yok@bingol.edu.tr","password":"x"}')"
check "baska IP serbest" 200 "$(code -H "X-Forwarded-For: 203.0.113.250" $A/news)"
check "engelli IP: /api/admin muaf (yetkisiz 401, 403 degil)" 401 "$(code -H "X-Forwarded-For: $BANIP" $A/admin/access-bans)"
has "deneme gunlugu" '"kind":"IP"' "$(adm $A/admin/access-bans/$BID/attempts)"
has "liste q ile bulunur" "$BANIP" "$(adm "$A/admin/access-bans?q=$BANIP&active=true")"

echo "== kendi kendini kilitleme ve ozel ag"
check "kendi IP araligi 400" 400 "$(admcode -X POST $A/admin/access-bans -d '{"kind":"CIDR","value":"198.51.100.0/24"}')"
has "kod BAN_SELF_LOCKOUT" 'BAN_SELF_LOCKOUT' "$(adm -X POST $A/admin/access-bans -d '{"kind":"CIDR","value":"198.51.100.0/24"}')"
check "ozel ag 400" 400 "$(admcode -X POST $A/admin/access-bans -d '{"kind":"CIDR","value":"10.0.0.0/8"}')"
check "gecersiz deger 400" 400 "$(admcode -X POST $A/admin/access-bans -d '{"kind":"IP","value":"abc"}')"

echo "== toplu (CIDR) yukleme"
BULK="# smoke\n192.0.2.0/24 smoke-$SFX\nbozuk-satir\n10.0.0.0/8"
R=$(adm -H "X-Admin-Reason: smoke toplu yukleme" -X POST $A/admin/access-bans/bulk -d "{\"text\":\"$BULK\",\"reasonCode\":\"SPAM\"}")
has "toplu: 1 olustu" '"created":1' "$R"
has "toplu: gecersiz satir raporlandi" 'BAN_INVALID_VALUE' "$R"
check "CIDR icindeki IP 403" 403 "$(code -H "X-Forwarded-For: 192.0.2.77" $A/news)"
check "CIDR disi IP 200" 200 "$(code -H "X-Forwarded-For: 192.0.3.77" $A/news)"

echo "== cihaz engeli (VPN'den bagimsiz)"
DEV1="smoke-dev-$SFX-aaaa"; DEV2="smoke-dev-$SFX-bbbb"
U="smkban$SFX@bingol.edu.tr"
TU=$(register "$U" "Smoke Ban")
check "kullanici giris (cihaz 1)" 200 "$(code -X POST -H "$H" -H "X-Device-Id: $DEV1" -H "X-Device-Platform: ANDROID" -H "X-App-Version: 1.0.0" -H "X-Forwarded-For: 203.0.113.201" $A/auth/login -d "{\"email\":\"$U\",\"password\":\"Sifre1234\",\"client\":\"mobile\"}")"
UID1=$(adm "$A/admin/users?q=$U" | idof)
has "kullanici cihaz listesi" '"deviceShort"' "$(adm $A/admin/users/$UID1/devices)"
R=$(adm -X POST $A/admin/access-bans -d "{\"kind\":\"DEVICE\",\"value\":\"$DEV1\",\"reasonCode\":\"FRAUD\"}")
has "cihaz engeli (ham deger saklanmaz)" '"kind":"DEVICE"' "$R"
case "$R" in *"$DEV1"*) echo "  FAIL ham cihaz kimligi yanitta"; FAIL=1;; *) echo "  ok   ham cihaz kimligi yanitta yok";; esac
DBID=$(echo "$R" | idof)
check "engelli cihaz: baska IP'den (VPN) giris 403" 403 "$(code -X POST -H "$H" -H "X-Device-Id: $DEV1" -H "X-Forwarded-For: 203.0.113.202" $A/auth/login -d "{\"email\":\"$U\",\"password\":\"Sifre1234\",\"client\":\"mobile\"}")"
check "engelli cihaz: anonim kayit ucu 403" 403 "$(code -X POST -H "$H" -H "X-Device-Id: $DEV1" $A/auth/register -d '{"email":"x@bingol.edu.tr","password":"Sifre1234","displayName":"X","acceptTerms":true}')"
check "baska cihazla giris 200" 200 "$(code -X POST -H "$H" -H "X-Device-Id: $DEV2" -H "X-Forwarded-For: 203.0.113.203" $A/auth/login -d "{\"email\":\"$U\",\"password\":\"Sifre1234\",\"client\":\"mobile\"}")"
check "cihaz basligi yok: engel uygulanamaz (200)" 200 "$(code $A/news)"

echo "== kullanici + cihaz tek tikla engel, mevcut oturumlar kapanir"
TU2=$(curl -s -X POST -H "$H" -H "X-Device-Id: $DEV2" $A/auth/login -d "{\"email\":\"$U\",\"password\":\"Sifre1234\",\"client\":\"mobile\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
check "oturum acik" 200 "$(code -H "Authorization: Bearer $TU2" $A/auth/me)"
R=$(adm -X POST $A/admin/users/$UID1/block-access -d '{"devices":true,"ips":false,"userBan":true,"reasonCode":"ABUSE","note":"smoke"}')
has "block-access: kullanici engeli" '"kind":"USER"' "$R"
check "oturum kapandi (401)" 401 "$(code -H "Authorization: Bearer $TU2" $A/auth/me)"
check "engelli kullanici giris 403" 403 "$(code -X POST -H "$H" -H "X-Device-Id: smoke-fresh-$SFX-cccc" $A/auth/login -d "{\"email\":\"$U\",\"password\":\"Sifre1234\",\"client\":\"mobile\"}")"
check "yanlis sifre ban durumunu sizdirmaz (401)" 401 "$(code -X POST -H "$H" -H "X-Device-Id: smoke-fresh-$SFX-cccc" $A/auth/login -d "{\"email\":\"$U\",\"password\":\"yanlis\",\"client\":\"mobile\"}")"

echo "== istatistik"
S=$(adm $A/admin/access-bans/stats)
has "stats activeBans" '"activeBans"' "$S"
has "stats son 24 saat" '"blockedAttemptsLast24h"' "$S"

echo "== anonimlestirici listesi"
has "yukleme" '"added":1' "$(adm -X POST $A/admin/access-bans/anonymizers -d "{\"text\":\"185.220.$((RANDOM % 200)).0/24\",\"source\":\"smoke-$SFX\"}")"
has "liste" "smoke-$SFX" "$(adm $A/admin/access-bans/anonymizers)"
has "kaynaga gore silme" '"deleted":1' "$(adm -X DELETE "$A/admin/access-bans/anonymizers?source=smoke-$SFX")"

echo "== kaldirma"
for id in $BID $DBID; do check "engel $id kaldir" 204 "$(admcode -X DELETE $A/admin/access-bans/$id)"; done
for id in $(adm "$A/admin/access-bans?active=true&q=smoke&size=100" | grep -o '"id":[0-9]*' | cut -d: -f2); do admcode -X DELETE $A/admin/access-bans/$id >/dev/null; done
check "kaldirilan IP serbest" 200 "$(code -H "X-Forwarded-For: $BANIP" $A/news)"
check "kaldirilan CIDR serbest" 200 "$(code -H "X-Forwarded-For: 192.0.2.77" $A/news)"
check "olmayan engel 404" 404 "$(admcode -X DELETE $A/admin/access-bans/99999999)"

if [ "$FAIL" = "0" ]; then echo "TUMU GECTI"; else echo "BAZI KONTROLLER BASARISIZ"; exit 1; fi

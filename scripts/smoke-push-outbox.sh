#!/usr/bin/env bash
# Kalici push kuyrugu (push_outbox) duman testi: gercek PostgreSQL gerekir (FOR UPDATE SKIP LOCKED, kismi indeksler).
# Kullanim: ADMIN_EMAIL=boss@bingol.edu.tr BASE=http://localhost:8080 ./scripts/smoke-push-outbox.sh
# Onkosul: compose'ta MAIL_ENABLED=false ve ADMIN_EMAILS=$ADMIN_EMAIL. FCM kimligi gerekmez:
#  - PUSH_OUTBOX_HOLD_WHEN_DISABLED=true ise kayitlar PENDING'de bekler (bu betik o modu dogrular),
#  - varsayilan (false) modda kayit yazilmaz; betik bunu da dogrular (stats.pending degismez).
# Yeniden baslatma kurtarma testi: betik sonunda isaretli komutlari elle calistirin (compose restart ana oturumun isidir).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0

check() { # ad beklenen gercek
  if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi
}
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
num() { echo "$1" | grep -o "\"$2\":[0-9]*" | head -1 | cut -d: -f2; }

register() { # email ad
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Sifre1234\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4
}

SFX=$RANDOM
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
TAD=$(register "$ADMIN_EMAIL" "Yonetici")
if [ -z "$TAD" ]; then
  TAD=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
fi
[ -n "$TAD" ] || { echo "yonetici token yok (ADMIN_EMAILS ayarli mi?)"; exit 1; }
TU=$(register "outbox$SFX@bingol.edu.tr" "Push Alici")
[ -n "$TU" ] || { echo "kayit basarisiz"; exit 1; }
AD="Authorization: Bearer $TAD"
AU="Authorization: Bearer $TU"

echo "== yetki"
check "girissiz 401" 401 "$(code $A/admin/push/outbox/stats)"
check "kullanici 403" 403 "$(code -H "$AU" $A/admin/push/outbox/stats)"
check "stats 200" 200 "$(code -H "$AD" $A/admin/push/outbox/stats)"
check "retry-dead kullanici 403" 403 "$(code -X POST -H "$AU" $A/admin/push/outbox/retry-dead)"

echo "== saglik gostergesi"
curl -s $BASE/actuator/health | grep -q 'pushQueue' && echo "  ok   pushQueue gostergesi" || echo "  not  pushQueue ayrinti actuator'da kapali olabilir (prod: yalniz health,info)"

echo "== cihaz kaydi + bildirim -> kuyruk"
S0=$(curl -s -H "$AD" $A/admin/push/outbox/stats)
P0=$(num "$S0" pending)
S0S=$(num "$S0" sentLast24h)
echo "  baslangic: pending=$P0 sentLast24h=$S0S $(echo "$S0" | grep -o '"enabled":[a-z]*' | head -1) $(echo "$S0" | grep -o '"holdWhenDisabled":[a-z]*')"
check "cihaz kaydi (yonetici)" 204 "$(code -X POST -H "$AD" -H "$H" $A/devices -d "{\"fcmToken\":\"smoke-token-$SFX-$SFX-$SFX\",\"platform\":\"android\"}")"
# Bildirim uretmek icin yonetici push kampanyasi (hedef: yalniz yonetici = SELF)
CAMP=$(curl -s -X POST -H "$AD" -H "$H" -H 'X-Admin-Reason: smoke kuyruk testi' $A/admin/push/campaigns -d "{\"type\":\"SYSTEM\",\"audience\":{\"type\":\"SELF\"},\"tr\":{\"title\":\"Kuyruk testi $SFX\",\"body\":\"deneme\"}}")
echo "  kampanya: $(echo "$CAMP" | head -c 120)"
sleep 12
S1=$(curl -s -H "$AD" $A/admin/push/outbox/stats)
P1=$(num "$S1" pending)
HOLD=$(echo "$S1" | grep -o '"holdWhenDisabled":[a-z]*' | cut -d: -f2)
ENABLED=$(echo "$S1" | grep -o '"enabled":[a-z]*' | head -1 | cut -d: -f2)
if [ "$ENABLED" = "true" ]; then
  echo "  FCM acik: kayitlar gonderilip SENT olmali"
  # Sahte cihaz tokeni gercek FCM'de reddedilir: SENT yerine failed/dead de "deneme yapildi" kanitidir
  if [ "$(num "$S1" sentLast24h)" -gt "${S0S:-0}" ]; then
    echo "  ok   sentLast24h artti"
  elif [ "$(num "$S1" failed)" -gt 0 ] || [ "$(num "$S1" dead)" -gt 0 ]; then
    echo "  ok   gonderim denendi (sahte token FCM'de reddedildi: failed/dead > 0)"
  else
    echo "  FAIL gonderim izi yok: $S1"; FAIL=1
  fi
elif [ "$HOLD" = "true" ]; then
  [ "$P1" -gt "${P0:-0}" ] && echo "  ok   FCM yok + hold: kayit PENDING'de bekliyor ($P0 -> $P1)" || { echo "  FAIL hold modunda kayit birikmedi: $S1"; FAIL=1; }
else
  check "FCM yok + hold kapali: kayit birikmez" "${P0:-0}" "${P1:-0}"
fi

echo "== olu kayitlari yeniden dene"
RD=$(curl -s -X POST -H "$AD" $A/admin/push/outbox/retry-dead)
echo "$RD" | grep -q '"requeued":' && echo "  ok   retry-dead: $RD" || { echo "  FAIL retry-dead: $RD"; FAIL=1; }

echo "== elle dogrulama (otomatiklestirilmedi)"
cat <<'EOF'
  1) Yeniden baslatma kurtarma: hold modunda kayit varken `docker compose restart backend`; acilis logunda
     "yarim kalan push kaydi kuyruga geri alindi" gorulmeli, stats.pending ayni kalmali (kayip yok).
  2) Cok sunucu: iki backend ornegiyle ayni kayit iki kez gonderilmemeli (FOR UPDATE SKIP LOCKED).
  3) psql: SELECT status, count(*) FROM push_outbox GROUP BY 1; token sutunu yoktur (yalniz fcm_token_hash).
EOF

[ $FAIL -eq 0 ] && echo "TUMU GECTI" || echo "HATA VAR"
exit $FAIL

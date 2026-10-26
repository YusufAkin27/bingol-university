#!/usr/bin/env bash
# T16 duman betigi: iki kullanici arasi mesaj bildirimlerinin gruplanmasi (collapse key + sayac) ve kutu uclari.
# Kullanim: BASE=http://localhost:8116 ./scripts/notification-collapse.sh
# Not: alici cevrimdisi olmali (WebSocket baglantisi yok) ki mesaj bildirimi olussun. Mesaj uclari icin
# docs/API_PLAN.md ve smoke-messaging.sh'a bakin; ucu farkliysa MSG_PATH ile degistirin.
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  ok   $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL $1"; }
DIR=$(dirname "$0")
S=$(date +%s)
U1=colla$S@bingol.edu.tr
U2=collb$S@bingol.edu.tr
for u in $U1 $U2; do BASE=$BASE "$DIR/make-user.sh" "$u" "Kolaps $u" >/dev/null; done
tok() { curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4; }
T1=$(tok $U1); T2=$(tok $U2)
ID2=$(curl -s -H "Authorization: Bearer $T2" $A/profile | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)

CONV=$(curl -s -X POST -H "Authorization: Bearer $T1" -H "$H" $A/conversations -d "{\"userId\":$ID2}" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
[ -n "$CONV" ] && ok "konusma $CONV" || { bad "konusma acilamadi"; exit 1; }

for i in 1 2 3; do
  curl -s -o /dev/null -X POST -H "Authorization: Bearer $T1" -H "$H" $A/conversations/$CONV/messages -d "{\"text\":\"mesaj $i\",\"clientId\":\"col-$i-$RANDOM\"}"
done

L=$(curl -s -H "Authorization: Bearer $T2" "$A/notifications?type=MESSAGE")
N=$(echo "$L" | grep -o '"type":"MESSAGE"' | wc -l | tr -d ' ')
[ "$N" = "1" ] && ok "3 mesaj tek bildirimde birlesti" || bad "bildirim sayisi $N (beklenen 1) -> $L"
case "$L" in *'"count":3'*) ok "sayac 3";; *) bad "sayac 3 degil";; esac

C=$(curl -s -H "Authorization: Bearer $T2" $A/notifications/unread-count)
[ "$C" = '{"unreadCount":1}' ] && ok "okunmamis sayaci 1" || bad "sayac $C"

NID=$(echo "$L" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
R=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "Authorization: Bearer $T2" $A/notifications/$NID/read)
[ "$R" = 204 ] && ok "tekil okundu" || bad "okundu $R"
# okunduktan sonra yeni mesaj yeni bildirim olusturur
curl -s -o /dev/null -X POST -H "Authorization: Bearer $T1" -H "$H" $A/conversations/$CONV/messages -d "{\"text\":\"yeni\",\"clientId\":\"col-new-$RANDOM\"}"
C=$(curl -s -H "Authorization: Bearer $T2" $A/notifications/unread-count)
[ "$C" = '{"unreadCount":1}' ] && ok "okunduktan sonra yeni bildirim" || bad "sayac $C"
# baska kullanici baskasinin bildirimini goremez/silemez
R=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE -H "Authorization: Bearer $T1" $A/notifications/$NID)
[ "$R" = 404 ] && ok "IDOR: baskasinin bildirimi 404" || bad "IDOR $R"
R=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE -H "Authorization: Bearer $T2" $A/notifications/$NID)
[ "$R" = 204 ] && ok "kendi bildirimini silme" || bad "silme $R"

echo "toplam: $PASS gecti, $FAIL kaldi"
[ "$FAIL" -eq 0 ]

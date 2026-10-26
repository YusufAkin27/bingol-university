#!/usr/bin/env bash
# T16 duman betigi: bildirim tercihleri (alt tur, sessiz saat), kutu uclari, cihaz yonetimi, KVKK disa aktarim.
# Kullanim: BASE=http://localhost:8116 ./scripts/notification-polish.sh   (calisan yigina karsi, tekrar calistirilabilir)
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  ok   $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL $1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (beklenen $3, gelen $2)"; fi; }
has() { case "$2" in *"$3"*) ok "$1";; *) bad "$1 (yok: $3) -> $2";; esac; }

U=ntf$(date +%s)@bingol.edu.tr
DIR=$(dirname "$0")
BASE=$BASE "$DIR/make-user.sh" "$U" "Bildirim Test" >/dev/null || { echo "kullanici olusturulamadi"; exit 1; }
TOKEN=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$U\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
AUTH="Authorization: Bearer $TOKEN"
code() { curl -s -o /dev/null -w '%{http_code}' -H "$AUTH" -H "$H" "$@"; }
body() { curl -s -H "$AUTH" -H "$H" "$@"; }

echo "== tercihler"
P=$(body $A/notifications/preferences)
has "varsayilan 5 bayrak" "$P" '"news":true'
has "alt turler listelenir" "$P" '"EVENT_REMINDER":true'
has "sessiz saat varsayilan kapali" "$P" '"enabled":false'
# eski istemci: yalniz 5 bayrak
check "eski PUT 200" "$(code -X PUT $A/notifications/preferences -d '{"news":false,"announcements":true,"events":true,"messages":true,"communities":true}')" 200
has "news kapandi" "$(body $A/notifications/preferences)" '"news":false'
check "kismi PUT 200" "$(code -X PUT $A/notifications/preferences -d '{"quietHours":{"enabled":true,"start":"23:00","end":"06:30","timezone":"Europe/Istanbul"},"subtypes":{"EVENT_REMINDER":false}}')" 200
P=$(body $A/notifications/preferences)
has "sessiz saat kayitli" "$P" '"start":"23:00"'
has "alt tur kapali" "$P" '"EVENT_REMINDER":false'
has "ana bayrak korunur" "$P" '"news":false'
check "gecersiz saat dilimi 400" "$(code -X PUT $A/notifications/preferences -d '{"quietHours":{"enabled":true,"start":"23:00","end":"06:30","timezone":"Mars/Olympus"}}')" 400
check "start==end 400" "$(code -X PUT $A/notifications/preferences -d '{"quietHours":{"enabled":true,"start":"10:00","end":"10:00","timezone":"UTC"}}')" 400
check "bilinmeyen alt tur 400" "$(code -X PUT $A/notifications/preferences -d '{"subtypes":{"NOPE":true}}')" 400
check "gecersiz HH:mm 400" "$(code -X PUT $A/notifications/preferences -d '{"quietHours":{"enabled":true,"start":"25:99","end":"06:30","timezone":"UTC"}}')" 400
body -X PUT $A/notifications/preferences -d '{"news":true,"quietHours":{"enabled":false,"start":"22:00","end":"07:00","timezone":"Europe/Istanbul"},"subtypes":{"EVENT_REMINDER":true}}' >/dev/null

echo "== cihazlar"
T1=tokenaaaaaaaaaaaaaaaa$(date +%s)
check "cihaz kaydi 204" "$(code -X POST $A/devices -d "{\"fcmToken\":\"$T1\",\"platform\":\"ANDROID\"}")" 204
check "kisa token 400" "$(code -X POST $A/devices -d '{"fcmToken":"abc","platform":"ANDROID"}')" 400
check "tekrar kayit 204" "$(code -X POST $A/devices -d "{\"fcmToken\":\"$T1\",\"platform\":\"ANDROID\"}")" 204
D=$(body $A/devices)
has "cihaz listede" "$D" '"platform":"ANDROID"'
case "$D" in *"$T1"*) bad "token tam donmemeli";; *) ok "token maskeli";; esac
for i in $(seq 1 12); do code -X POST $A/devices -d "{\"fcmToken\":\"limittoken${i}xxxxxxxxxx$(date +%s)\",\"platform\":\"WEB\"}" >/dev/null; done
N=$(body $A/devices | grep -o '"platform"' | wc -l | tr -d ' ')
[ "$N" -le 10 ] && ok "cihaz siniri (<=10): $N" || bad "cihaz siniri asildi: $N"
check "cihaz silme 204" "$(code -X DELETE $A/devices/$T1)" 204

echo "== kutu"
check "bos sayac" "$(body $A/notifications/unread-count)" '{"unreadCount":0}'
check "gecersiz tur 400" "$(code "$A/notifications?type=NOPE")" 400
check "olmayan bildirim okundu 404" "$(code -X POST $A/notifications/999999999/read)" 404
check "olmayan bildirim sil 404" "$(code -X DELETE $A/notifications/999999999)" 404
check "hepsini sil 200" "$(code -X DELETE $A/notifications)" 200
has "hepsini sil sayi" "$(body -X DELETE "$A/notifications?type=EVENT&readOnly=true")" '"deleted":'

echo "== KVKK disa aktarim"
X=$(body $A/users/me/export)
has "notificationSettings" "$X" '"notificationSettings"'
has "notifications" "$X" '"notifications"'
has "devices" "$X" '"devices"'

echo "toplam: $PASS gecti, $FAIL kaldi"
[ "$FAIL" -eq 0 ]

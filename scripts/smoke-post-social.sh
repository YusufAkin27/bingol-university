#!/usr/bin/env bash
# Gonderi sosyal ozellikleri icin duman testi: takip (followedByMe/followsMe), akis kapsamlari (following/department),
# kaldirilan ozelliklerin uclarinin artik olmadigi (404).
# Kullanim: BASE=http://localhost:8080 ./scripts/smoke-post-social.sh   (gercek PostgreSQL gerekir)
# Onkosul: compose'ta MAIL_ENABLED=false (dogrulama kodu log'dan okunur); kayit ucu IP basina saatte 10 sinirli:
# gerekirse once `docker compose exec -T redis redis-cli flushall`.
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0

check() { # ad beklenen gercek
  if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi
}
has() { # ad desen metin
  if echo "$3" | grep -q "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (desen $2): $3"; FAIL=1; fi
}
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
jid() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

register() { # email ad
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Sifre1234\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4
}
uid_of() { curl -s -H "$1" $A/users/me | jid; }

SFX=$RANDOM
TA=$(register "socia$SFX@bingol.edu.tr" "Sosyal Ayse")
TB=$(register "socib$SFX@bingol.edu.tr" "Sosyal Bora")
TC=$(register "socic$SFX@bingol.edu.tr" "Sosyal Can")
[ -n "$TA" ] && [ -n "$TB" ] && [ -n "$TC" ] || { echo "kayit basarisiz"; exit 1; }
AA="Authorization: Bearer $TA"
AB="Authorization: Bearer $TB"
AC="Authorization: Bearer $TC"
IDA=$(uid_of "$AA"); IDB=$(uid_of "$AB"); IDC=$(uid_of "$AC")
[ -n "$IDA" ] && [ -n "$IDB" ] && [ -n "$IDC" ] || { echo "profil okunamadi"; exit 1; }

TMPD=$(mktemp -d)
printf 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' | base64 -d > "$TMPD/a.png"
TMPW=$(cygpath -m "$TMPD" 2>/dev/null || echo "$TMPD")

echo "== takip"
check "girissiz 401" 401 "$(code -X POST $A/users/$IDB/follow)"
check "kendini takip 400" 400 "$(code -X POST -H "$AA" $A/users/$IDA/follow)"
check "olmayan kullanici 404" 404 "$(code -X POST -H "$AA" $A/users/999999999/follow)"
R=$(curl -s -X POST -H "$AA" $A/users/$IDB/follow)
has "takip: following true" '"following":true' "$R"
has "takipci sayaci 1" '"followerCount":1' "$R"
R=$(curl -s -X POST -H "$AA" $A/users/$IDB/follow)
has "ikinci takip idempotent (sayac 1)" '"followerCount":1' "$R"
P=$(curl -s -H "$AA" $A/users/$IDB)
has "profil followedByMe true" '"followedByMe":true' "$P"
has "profil followsMe false (B beni takip etmiyor)" '"followsMe":false' "$P"
has "profil followerCount" '"followerCount":1' "$P"
PB=$(curl -s -H "$AB" $A/users/$IDA)
has "B'nin gozunden A: followsMe true" '"followsMe":true' "$PB"
has "B'nin gozunden A: followedByMe false" '"followedByMe":false' "$PB"
LF=$(curl -s -H "$AB" "$A/users/$IDB/followers")
has "takipci listesi" "\"id\":$IDA" "$LF"
has "liste ogesi followsMe alani" '"followsMe":' "$LF"
has "liste ogesi followedByMe alani" '"followedByMe":' "$LF"
has "takip edilenler listesi" "\"id\":$IDB" "$(curl -s -H "$AA" "$A/users/$IDA/following")"
# karsilikli: B de A'yi takip eder -> A'nin listesinde B icin followedByMe + followsMe true
curl -s -o /dev/null -X POST -H "$AB" $A/users/$IDA/follow
LM=$(curl -s -H "$AA" "$A/users/$IDA/following")
has "karsilikli: followsMe true" '"followsMe":true' "$LM"
has "karsilikli: followedByMe true" '"followedByMe":true' "$LM"
check "oneriler 200" 200 "$(code -H "$AA" $A/users/me/follow-suggestions)"

echo "== gonderi (tek foto + kisa metin) ve akis kapsamlari"
MID=$(curl -s -X POST -H "$AB" -F "file=@$TMPW/a.png;type=image/png" $A/posts/media | jid)
R=$(curl -s -X POST -H "$AB" -H "$H" $A/posts -d "{\"text\":\"Gunaydin kampus\",\"mediaIds\":[$MID]}")
PID=$(echo "$R" | jid)
[ -n "$PID" ] || { echo "  FAIL gonderi olusmadi: $R"; exit 1; }
has "following kapsami" "\"id\":$PID" "$(curl -s -H "$AA" "$A/feed?scope=following")"
F=$(curl -s -H "$AC" "$A/feed?scope=following")
if echo "$F" | grep -q "\"id\":$PID,"; then echo "  FAIL takip etmeyen following'te gordu"; FAIL=1; else echo "  ok   takip etmeyen gormez"; fi
has "department bos+ipucu" 'NO_DEPARTMENT' "$(curl -s -H "$AC" "$A/feed?scope=department")"
check "top 200" 200 "$(code -H "$AA" "$A/feed?scope=top")"
check "gecersiz kapsam 400" 400 "$(code -H "$AA" "$A/feed?scope=bogus")"
check "latest hala 200" 200 "$(code -H "$AA" "$A/feed?scope=latest")"

echo "== kaldirilan uclar: artik yok (404)"
check "etiket 404" 404 "$(code -H "$AA" "$A/hashtags/trending")"
check "mention onerisi 404" 404 "$(code -H "$AA" "$A/users/mention-suggest?q=Sosyal")"
check "kaydet 404" 404 "$(code -X PUT -H "$AA" $A/posts/$PID/save)"
check "begenenler 404" 404 "$(code -H "$AA" "$A/posts/$PID/likes")"
check "yorumlar 404" 404 "$(code -H "$AA" "$A/posts/$PID/comments")"
check "hikaye olustur 404" 404 "$(code -X POST -H "$AB" -H "$H" $A/stories -d '{"text":"x"}')"
check "hikaye tepsisi 404" 404 "$(code -H "$AA" $A/stories/tray)"

echo "== takibi birak"
R=$(curl -s -X DELETE -H "$AA" $A/users/$IDB/follow)
has "birak: following false" '"following":false' "$R"
has "sayac 0" '"followerCount":0' "$R"
has "birakinca followedByMe false" '"followedByMe":false' "$(curl -s -H "$AA" $A/users/$IDB)"
has "B hala A'yi takip ediyor: followsMe true" '"followsMe":true' "$(curl -s -H "$AA" $A/users/$IDB)" || true

rm -rf "$TMPD"
echo
[ "$FAIL" = 0 ] && echo "TUM KONTROLLER GECTI" || echo "BAZI KONTROLLER BASARISIZ"
exit $FAIL

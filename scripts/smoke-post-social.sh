#!/usr/bin/env bash
# Gonderi sosyal ozellikleri (kaydet, @etiket, #etiket, takip, akis kapsamlari, hikayeler) icin duman testi.
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
  curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\"}" |
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
has "profil followedByMe" '"followedByMe":true' "$P"
has "profil followerCount" '"followerCount":1' "$P"
has "takipci listesi" "\"id\":$IDA" "$(curl -s -H "$AB" "$A/users/$IDB/followers")"
has "takip edilenler listesi" "\"id\":$IDB" "$(curl -s -H "$AA" "$A/users/$IDA/following")"
check "oneriler 200" 200 "$(code -H "$AA" $A/users/me/follow-suggestions)"

echo "== gonderi: #etiket, @etiket, kaydet"
TAG="smk$SFX"
R=$(curl -s -X POST -H "$AB" -H "$H" $A/posts -d "{\"text\":\"Merhaba #$TAG @[Sosyal Ayse](uid:$IDA)\"}")
PID=$(echo "$R" | jid)
[ -n "$PID" ] || { echo "  FAIL gonderi olusmadi: $R"; exit 1; }
has "hashtags alani" "\"hashtags\":\[\"$TAG\"\]" "$R"
has "mentions alani" "\"mentions\":\[{\"id\":$IDA" "$R"
check "11 mention 400" 400 "$(code -X POST -H "$AB" -H "$H" $A/posts -d '{"text":"@[a](uid:1) @[a](uid:2) @[a](uid:3) @[a](uid:4) @[a](uid:5) @[a](uid:6) @[a](uid:7) @[a](uid:8) @[a](uid:9) @[a](uid:10) @[a](uid:11)"}')"
has "etiket akisi" "\"id\":$PID" "$(curl -s -H "$AA" "$A/hashtags/$TAG/posts")"
has "etiket onerisi" "$TAG" "$(curl -s -H "$AA" "$A/hashtags/suggest?q=smk")"
check "gundem 200" 200 "$(code -H "$AA" "$A/hashtags/trending")"
check "gecersiz etiket 400" 400 "$(code -H "$AA" "$A/hashtags/a/posts")"
has "mention onerisi" "displayName" "$(curl -s -H "$AA" "$A/users/mention-suggest?q=Sosyal")"
N=$(curl -s -H "$AA" "$A/notifications?size=20")
has "etiket bildirimi" 'POST_MENTION' "$N"

check "kaydet" 200 "$(code -X PUT -H "$AA" $A/posts/$PID/save)"
check "kaydet idempotent" 200 "$(code -X PUT -H "$AA" $A/posts/$PID/save)"
has "savedByMe true" '"savedByMe":true' "$(curl -s -H "$AA" $A/posts/$PID)"
has "baskasi savedByMe false" '"savedByMe":false' "$(curl -s -H "$AC" $A/posts/$PID)"
has "kaydedilenler listesi" "\"id\":$PID" "$(curl -s -H "$AA" "$A/posts/saved")"
check "kaydi kaldir" 200 "$(code -X DELETE -H "$AA" $A/posts/$PID/save)"

echo "== akis kapsamlari"
has "following kapsami" "\"id\":$PID" "$(curl -s -H "$AA" "$A/feed?scope=following")"
F=$(curl -s -H "$AC" "$A/feed?scope=following")
if echo "$F" | grep -q "\"id\":$PID,"; then echo "  FAIL takip etmeyen following'te gordu"; FAIL=1; else echo "  ok   takip etmeyen gormez"; fi
has "department bos+ipucu" 'NO_DEPARTMENT' "$(curl -s -H "$AC" "$A/feed?scope=department")"
check "gecersiz kapsam 400" 400 "$(code -H "$AA" "$A/feed?scope=bogus")"
check "latest hala 200" 200 "$(code -H "$AA" "$A/feed?scope=latest")"

echo "== hikayeler"
check "bos hikaye 400" 400 "$(code -X POST -H "$AB" -H "$H" $A/stories -d '{}')"
check "gecersiz renk 400" 400 "$(code -X POST -H "$AB" -H "$H" $A/stories -d '{"text":"selam","background":"mavi"}')"
R=$(curl -s -X POST -H "$AB" -H "$H" $A/stories -d '{"text":"Gunaydin","background":"#336699"}')
SID=$(echo "$R" | jid)
[ -n "$SID" ] || { echo "  FAIL hikaye olusmadi: $R"; exit 1; }
has "hikaye TEXT" '"kind":"TEXT"' "$R"
T=$(curl -s -H "$AA" $A/stories/tray)
has "tepsi: takip edilen hikayesi" "\"id\":$IDB" "$T"
has "tepsi: gorulmemis" '"hasUnseen":true' "$T"
check "goruntule 204" 204 "$(code -X POST -H "$AA" $A/stories/$SID/view)"
check "goruntule idempotent 204" 204 "$(code -X POST -H "$AA" $A/stories/$SID/view)"
T=$(curl -s -H "$AA" $A/stories/tray)
has "tepsi: goruldu" '"hasUnseen":false' "$T"
has "kullanici hikayeleri" "\"id\":$SID" "$(curl -s -H "$AA" $A/users/$IDB/stories)"
has "goruntuleyenler (sahip)" "\"id\":$IDA" "$(curl -s -H "$AB" $A/stories/$SID/viewers)"
check "goruntuleyenler baskasi 403" 403 "$(code -H "$AA" $A/stories/$SID/viewers)"
has "viewCount sahibe" '"viewCount":1' "$(curl -s -H "$AB" $A/users/$IDB/stories)"
check "baskasi silemez 403" 403 "$(code -X DELETE -H "$AA" $A/stories/$SID)"
check "sahip siler" 204 "$(code -X DELETE -H "$AB" $A/stories/$SID)"
check "silinen goruntulenemez 404" 404 "$(code -X POST -H "$AA" $A/stories/$SID/view)"

echo "== takibi birak"
R=$(curl -s -X DELETE -H "$AA" $A/users/$IDB/follow)
has "birak: following false" '"following":false' "$R"
has "sayac 0" '"followerCount":0' "$R"

echo
[ "$FAIL" = 0 ] && echo "TUM KONTROLLER GECTI" || echo "BAZI KONTROLLER BASARISIZ"
exit $FAIL

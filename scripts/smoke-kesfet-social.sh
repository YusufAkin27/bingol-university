#!/usr/bin/env bash
# Kesfet sosyal ozellikleri (KS-BE2, V1230) icin uctan uca duman testi (gercek PostgreSQL gerekir):
# yorum + yanit + yorum begenisi + silme, gonderi kaydetme, kullanici arama (Turkce harf duyarsiz, kismi, takip bayraklari),
# GET /api/search?type=REELS, profil sayaclari (postCount/reelCount), GET /api/users/{id}/reels, yonetici yorum moderasyonu.
# Kullanim: BASE=http://localhost:8080 ADMIN_PASSWORD=... ./scripts/smoke-kesfet-social.sh
# Onkosul: compose'ta MAIL_ENABLED=false (dogrulama kodu log'dan okunur); gerekirse once redis flushall.
# Not: video yukleme hatti KS-BE ile gelir; bu betik video gonderi OLUSTURMAZ, REELS uclari bos liste ile 200 doner.
set -u
BASE=${BASE:-http://localhost:8080}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0

check() { # ad beklenen gercek
  if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi
}
has() { # ad desen metin
  if echo "$3" | grep -q "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (desen $2): $3"; FAIL=1; fi
}
hasnt() { # ad desen metin
  if echo "$3" | grep -q "$2"; then echo "  FAIL $1 (istenmeyen desen $2): $3"; FAIL=1; else echo "  ok   $1"; fi
}
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
jid() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

register() { # email ad -> access token ; id /users/me'den okunur
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Zk7-Qmv-Lpx92w\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Zk7-Qmv-Lpx92w\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4
}
setname() { # token-basligi ad (kayitta ASCII; Turkce karakterli ad PATCH ile)
  curl -s -o /dev/null -X PATCH -H "$1" -H "$H" $A/users/me -d "{\"displayName\":\"$2\"}"
}

SFX=$RANDOM
TA=$(register "ksa$SFX@bingol.edu.tr" "Kesfet Yazar")
TB=$(register "ksb$SFX@bingol.edu.tr" "Kesfet Okur")
TC=$(register "ksc$SFX@bingol.edu.tr" "Kesfet Ucuncu")
[ -n "$TA" ] && [ -n "$TB" ] && [ -n "$TC" ] || { echo "kayit basarisiz"; exit 1; }
AA="Authorization: Bearer $TA"
AB="Authorization: Bearer $TB"
AC="Authorization: Bearer $TC"
IDA=$(curl -s -H "$AA" $A/users/me | jid)
IDB=$(curl -s -H "$AB" $A/users/me | jid)
IDC=$(curl -s -H "$AC" $A/users/me | jid)

TMPD=$(mktemp -d)
printf 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' | base64 -d > "$TMPD/a.png"
TMPW=$(cygpath -m "$TMPD" 2>/dev/null || echo "$TMPD")
newpost() { # token-basligi metin -> gonderi yaniti
  local m
  m=$(curl -s -X POST -H "$1" -F "file=@$TMPW/a.png;type=image/png" $A/posts/media | jid)
  curl -s -X POST -H "$1" -H "$H" $A/posts -d "{\"text\":\"$2\",\"mediaIds\":[$m]}"
}

R=$(newpost "$AA" "kampuste aksam")
PID=$(echo "$R" | jid)
[ -n "$PID" ] || { echo "  FAIL gonderi olusmadi: $R"; exit 1; }
has "PostView commentCount=0" '"commentCount":0' "$R"
has "PostView savedByMe=false" '"savedByMe":false' "$R"

echo "== yorumlar: yazma / kurallar"
check "girissiz yorum listesi 401" 401 "$(code $A/posts/$PID/comments)"
check "bos yorum 400" 400 "$(code -X POST -H "$AB" -H "$H" $A/posts/$PID/comments -d '{"text":"   "}')"
LONG=$(printf 'x%.0s' $(seq 1 301))
check "301 karakter 422" 422 "$(code -X POST -H "$AB" -H "$H" $A/posts/$PID/comments -d "{\"text\":\"$LONG\"}")"
check "olmayan gonderi 404" 404 "$(code -X POST -H "$AB" -H "$H" $A/posts/99999999/comments -d '{"text":"merhaba"}')"
C1=$(curl -s -X POST -H "$AB" -H "$H" $A/posts/$PID/comments -d '{"text":"harika kare"}')
CID1=$(echo "$C1" | jid)
[ -n "$CID1" ] || { echo "  FAIL yorum olusmadi: $C1"; exit 1; }
has "yorum mine=true" '"mine":true' "$C1"
has "yorum parentId null" '"parentId":null' "$C1"
check "yorum 201" 201 "$(code -X POST -H "$AC" -H "$H" $A/posts/$PID/comments -d '{"text":"ben de katiliyorum"}')"

echo "== yanitlar (iki seviye, yassilama)"
R1=$(curl -s -X POST -H "$AC" -H "$H" $A/posts/$PID/comments -d "{\"text\":\"yanit 1\",\"parentId\":$CID1}")
RID1=$(echo "$R1" | jid)
has "yanit parentId=ust yorum" "\"parentId\":$CID1" "$R1"
R2=$(curl -s -X POST -H "$AB" -H "$H" $A/posts/$PID/comments -d "{\"text\":\"yanita yanit\",\"parentId\":$RID1}")
has "yanita yanit ust yoruma yassilanir" "\"parentId\":$CID1" "$R2"
has "yanita yanit replyTo" "\"replyTo\":{\"commentId\":$RID1" "$R2"
check "baska gonderinin yorumuna yanit 404" 404 "$(code -X POST -H "$AB" -H "$H" $A/posts/$(echo "$(newpost "$AB" "ikinci" )" | jid)/comments -d "{\"text\":\"x\",\"parentId\":$CID1}")"
L=$(curl -s -H "$AA" "$A/posts/$PID/comments?sort=new&size=10")
has "liste total = yorum + yanit (4)" '"total":4' "$L"
RP=$(curl -s -H "$AA" "$A/post-comments/$CID1/replies?size=10")
has "yanitlar total=2" '"total":2' "$RP"
check "yanitin yaniti listelenmez 404" 404 "$(code -H "$AA" $A/post-comments/$RID1/replies)"
PV=$(curl -s -H "$AA" $A/posts/$PID)
has "PostView commentCount=4" '"commentCount":4' "$PV"

echo "== yorum begenisi"
LK=$(curl -s -X PUT -H "$AA" $A/post-comments/$CID1/like)
has "begeni liked=true" '"liked":true' "$LK"
has "begeni sayaci 1" '"likeCount":1' "$LK"
LK=$(curl -s -X PUT -H "$AA" $A/post-comments/$CID1/like)
has "cift PUT idempotent (1)" '"likeCount":1' "$LK"
LK=$(curl -s -X DELETE -H "$AA" $A/post-comments/$CID1/like)
has "begeni geri alindi (0)" '"likeCount":0' "$LK"
curl -s -o /dev/null -X PUT -H "$AA" $A/post-comments/$CID1/like
TOP=$(curl -s -H "$AA" "$A/posts/$PID/comments?sort=top&size=10")
has "top: begenen yorumun likedByMe=true" '"likedByMe":true' "$TOP"
check "gecersiz sort 400" 400 "$(code -H "$AA" "$A/posts/$PID/comments?sort=zzz")"
check "bozuk imlec 400" 400 "$(code -H "$AA" "$A/posts/$PID/comments?cursor=zzz")"

echo "== silme yetkisi"
check "baskasinin yorumunu silme 403" 403 "$(code -X DELETE -H "$AC" $A/post-comments/$CID1)"
check "gonderi sahibi baskasinin yorumunu siler 204" 204 "$(code -X DELETE -H "$AA" $A/post-comments/$RID1)"
PV=$(curl -s -H "$AA" $A/posts/$PID)
has "silinen yanit sayaci dusurur (3)" '"commentCount":3' "$PV"
check "silinmis yorum 404" 404 "$(code -H "$AA" $A/post-comments/$RID1)"

echo "== sikayet (COMMENT hedefi)"
check "yorum sikayeti 201" 201 "$(code -X POST -H "$AC" -H "$H" $A/reports -d "{\"targetType\":\"COMMENT\",\"targetId\":$CID1,\"reason\":\"SPAM\"}")"
check "olmayan yorum sikayeti 404" 404 "$(code -X POST -H "$AC" -H "$H" $A/reports -d '{"targetType":"COMMENT","targetId":99999999,"reason":"SPAM"}')"

echo "== kaydetme"
check "girissiz kaydet 401" 401 "$(code -X PUT $A/posts/$PID/save)"
SV=$(curl -s -X PUT -H "$AB" $A/posts/$PID/save)
has "kaydet saved=true" '"saved":true' "$SV"
SV=$(curl -s -X PUT -H "$AB" $A/posts/$PID/save)
has "cift kaydet idempotent (saveCount 1)" '"saveCount":1' "$SV"
SL=$(curl -s -H "$AB" "$A/posts/saved?size=10")
has "kaydedilenler listesinde" "\"id\":$PID" "$SL"
has "savedByMe=true" '"savedByMe":true' "$SL"
SL=$(curl -s -H "$AC" "$A/posts/saved?size=10")
hasnt "baska kullanicinin listesinde yok" "\"id\":$PID," "$SL"
check "olmayan gonderi kaydet 404" 404 "$(code -X PUT -H "$AB" $A/posts/99999999/save)"
SV=$(curl -s -X DELETE -H "$AB" $A/posts/$PID/save)
has "kaydi kaldir saved=false" '"saved":false' "$SV"
SL=$(curl -s -H "$AB" "$A/posts/saved?size=10")
hasnt "kaldirilinca listede yok" "\"id\":$PID," "$SL"

echo "== kullanici arama (Turkce harf duyarsiz, kismi, takip bayraklari)"
setname "$AA" "Şirin Yıldız$SFX"
setname "$AC" "Çağla Öztürk$SFX"
check "girissiz arama 401" 401 "$(code "$A/users/search?q=sirin")"
check "kisa sorgu 400" 400 "$(code -H "$AB" "$A/users/search?q=s")"
S=$(curl -s -H "$AB" "$A/users/search?q=SIRIN%20YILDIZ$SFX")
has "ASCII BUYUK sorgu Turkce adi bulur" "\"id\":$IDA" "$S"
S=$(curl -s -H "$AB" "$A/users/search?q=%C5%9Firin")
has "Turkce karakterli kucuk harf (şirin)" "\"id\":$IDA" "$S"
S=$(curl -s -H "$AB" "$A/users/search?q=ld%C4%B1z$SFX")
has "kismi eslesme (ldız...)" "\"id\":$IDA" "$S"
S=$(curl -s -H "$AB" "$A/users/search?q=ozturk$SFX")
has "ozturk -> Öztürk" "\"id\":$IDC" "$S"
hasnt "kendisi sonuclarda yok" "\"id\":$IDB," "$(curl -s -H "$AB" "$A/users/search?q=Kesfet%20Okur")"
S=$(curl -s -H "$AB" "$A/users/search?q=sirin")
has "satirda followedByMe alani (false)" '"followedByMe":false' "$S"
check "takip et 200" 200 "$(code -X POST -H "$AB" $A/users/$IDA/follow)"
check "karsi takip 200" 200 "$(code -X POST -H "$AA" $A/users/$IDB/follow)"
S=$(curl -s -H "$AB" "$A/users/search?q=SIRIN%20YILDIZ$SFX")
has "followedByMe=true" '"followedByMe":true' "$S"
has "followsMe=true" '"followsMe":true' "$S"
has "followerCount=1" '"followerCount":1' "$S"
check "engel sonrasi arama" 200 "$(code -X POST -H "$AC" -H "$H" $A/users/$IDA/block)"
S=$(curl -s -H "$AA" "$A/users/search?q=ozturk$SFX")
hasnt "engelleyen engelleneni goremez" "\"id\":$IDC," "$S"
curl -s -o /dev/null -X DELETE -H "$AC" $A/users/$IDA/block

echo "== Reels arama + profil sayaclari"
RS=$(curl -s -H "$AB" "$A/search?q=kampuste&type=REELS")
has "REELS arama 200 (groups dizisi)" '"groups"' "$RS"
check "REELS arama HTTP 200" 200 "$(code -H "$AB" "$A/search?q=kampuste&type=REELS")"
PS=$(curl -s -H "$AB" "$A/search?q=kampuste&type=POSTS")
has "POSTS aramasi gonderiyi bulur" "\"targetId\":$PID" "$PS"
UP=$(curl -s -H "$AB" $A/users/$IDA)
has "profil postCount >= 1" '"postCount":[1-9]' "$UP"
has "profil reelCount=0" '"reelCount":0' "$UP"
ME=$(curl -s -H "$AA" $A/users/me)
has "/users/me postCount" '"postCount":[1-9]' "$ME"
RL=$(curl -s -H "$AB" "$A/users/$IDA/reels?size=5")
has "reels listesi items dizisi" '"items":\[' "$RL"
check "reels girissiz 401" 401 "$(code $A/users/$IDA/reels)"

echo "== yonetici yorum moderasyonu"
if [ -n "$ADMIN_PASSWORD" ]; then
  AD="Authorization: Basic $(printf 'admin:%s' "$ADMIN_PASSWORD" | base64)"
  AL=$(curl -s -H "$AD" "$A/admin/posts/$PID/comments?size=20")
  has "admin yorum listesi" "\"id\":$CID1" "$AL"
  check "admin gizle 200" 200 "$(code -X POST -H "$AD" -H "$H" $A/admin/post-comments/$CID1/hide -d '{"reason":"duman testi"}')"
  PV=$(curl -s -H "$AA" $A/posts/$PID)
  has "gizleme sayaci dusurur (1)" '"commentCount":1' "$PV"
  check "gizli yorum 404" 404 "$(code -H "$AA" $A/post-comments/$CID1)"
  check "admin geri al 200" 200 "$(code -X POST -H "$AD" $A/admin/post-comments/$CID1/unhide)"
  PV=$(curl -s -H "$AA" $A/posts/$PID)
  has "geri alma sayaci geri getirir (2)" '"commentCount":2' "$PV"
  check "admin sil 204" 204 "$(code -X DELETE -H "$AD" -H "$H" $A/admin/post-comments/$CID1 -d '{"reason":"duman testi"}')"
  check "admin olmayan yorum 404" 404 "$(code -X DELETE -H "$AD" $A/admin/post-comments/$CID1)"
  check "kullanici admin ucuna 403" 403 "$(code -H "$AB" "$A/admin/posts/$PID/comments")"
else
  echo "  ATLA ADMIN_PASSWORD yok (admin adimlari)"
fi

rm -rf "$TMPD"
if [ "$FAIL" = 0 ]; then echo "TAMAM"; else echo "BASARISIZ"; exit 1; fi

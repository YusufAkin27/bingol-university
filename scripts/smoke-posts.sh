#!/usr/bin/env bash
# Genel gonderiler (Kesfet akisi) icin uctan uca duman testi (gercek PostgreSQL gerekir).
# Kullanim: BASE=http://localhost:8080 ./scripts/smoke-posts.sh
# Onkosul: compose'ta MAIL_ENABLED=false (dogrulama kodu log'dan okunur). Diger ajanlar (medya, begeni, yorum,
# moderasyon) kendi bolumlerini "== BOLUM" basliklariyla bu dosyanin SONUNA (exit'ten once) ekler.
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0

check() { # ad beklenen gercek
  if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi
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

SFX=$RANDOM
TA=$(register "posta$SFX@bingol.edu.tr" "Gonderi Yazar")
TB=$(register "postb$SFX@bingol.edu.tr" "Gonderi Okur")
[ -n "$TA" ] && [ -n "$TB" ] || { echo "kayit basarisiz"; exit 1; }
AA="Authorization: Bearer $TA"
AB="Authorization: Bearer $TB"

echo "== gonderi: olustur / oku"
check "girissiz 401" 401 "$(code $A/feed)"
check "bos gonderi 400" 400 "$(code -X POST -H "$AA" -H "$H" $A/posts -d '{"text":"  "}')"
R=$(curl -s -X POST -H "$AA" -H "$H" $A/posts -d '{"text":"Merhaba kampus"}')
PID=$(echo "$R" | jid)
[ -n "$PID" ] || { echo "  FAIL gonderi olusmadi: $R"; exit 1; }
echo "$R" | grep -q '"mine":true' && echo "  ok   mine=true" || { echo "  FAIL mine: $R"; FAIL=1; }
check "baskasi okur" 200 "$(code -H "$AB" $A/posts/$PID)"
check "olmayan 404" 404 "$(code -H "$AB" $A/posts/999999999)"
curl -s -H "$AB" "$A/posts/$PID" | grep -q '"canEdit":false' && echo "  ok   baskasi canEdit=false" || { echo "  FAIL canEdit"; FAIL=1; }

echo "== akis (latest / popular / imec)"
R2=$(curl -s -X POST -H "$AA" -H "$H" $A/posts -d '{"text":"Ikinci gonderi"}')
PID2=$(echo "$R2" | jid)
F=$(curl -s -H "$AB" "$A/feed?scope=latest&size=1")
echo "$F" | grep -q "\"id\":$PID2," && echo "  ok   en yeni basta" || { echo "  FAIL latest sirasi: $F"; FAIL=1; }
CUR=$(echo "$F" | grep -o '"nextCursor":"[^"]*' | cut -d'"' -f4)
[ -n "$CUR" ] && echo "  ok   nextCursor var" || { echo "  FAIL nextCursor yok"; FAIL=1; }
F2=$(curl -s -H "$AB" "$A/feed?scope=latest&size=1&cursor=$CUR")
echo "$F2" | grep -q '"items":\[{' && echo "  ok   ikinci sayfa" || { echo "  FAIL ikinci sayfa: $F2"; FAIL=1; }
check "popular 200" 200 "$(code -H "$AB" "$A/feed?scope=popular")"
check "bozuk imlec 400" 400 "$(code -H "$AB" "$A/feed?cursor=bozuk")"
check "kullanici gonderileri" 200 "$(code -H "$AB" "$A/users/1/posts")"
check "benim gonderilerim" 200 "$(code -H "$AA" "$A/posts/mine")"

echo "== duzenle / sil"
check "baskasi duzenleyemez 403" 403 "$(code -X PATCH -H "$AB" -H "$H" $A/posts/$PID -d '{"text":"hack"}')"
check "yazar duzenler" 200 "$(code -X PATCH -H "$AA" -H "$H" $A/posts/$PID -d '{"text":"Duzenlendi"}')"
curl -s -H "$AB" "$A/posts/$PID" | grep -q '"editedAt":"' && echo "  ok   editedAt dolu" || { echo "  FAIL editedAt"; FAIL=1; }
check "baskasi silemez 403" 403 "$(code -X DELETE -H "$AB" $A/posts/$PID)"
check "yazar siler" 204 "$(code -X DELETE -H "$AA" $A/posts/$PID)"
check "silinen 404" 404 "$(code -H "$AB" $A/posts/$PID)"

# == BOLUM: medya (B) ==
echo "== medya: yukleme / sunum / range / baglama"
TMPD=$(mktemp -d)
# 1x1 PNG ve en kucuk sentetik mp4 (ftyp + moov/mvhd, 5 sn); oynatilabilir degil, yalniz kap yapisi
printf 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' | base64 -d > "$TMPD/a.png"
printf '\x00\x00\x00\x14ftypisom\x00\x00\x02\x00isom\x00\x00\x00\x24moov\x00\x00\x00\x1cmvhd\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x03\xe8\x00\x00\x13\x88' > "$TMPD/v.mp4"
printf 'bu bir gorsel degil' > "$TMPD/bad.png"
# Windows'ta curl -F icin yol Windows bicimi olmali (cygpath yoksa oldugu gibi kalir)
TMPW=$(cygpath -m "$TMPD" 2>/dev/null || echo "$TMPD")
check "medya girissiz 401" 401 "$(code -X POST -F "file=@$TMPW/a.png;type=image/png" $A/posts/media)"
check "gecersiz gorsel 400" 400 "$(code -X POST -H "$AA" -F "file=@$TMPW/bad.png;type=image/png" $A/posts/media)"
MI=$(curl -s -X POST -H "$AA" -F "file=@$TMPW/a.png;type=image/png" $A/posts/media)
MID=$(echo "$MI" | jid)
[ -n "$MID" ] || { echo "  FAIL gorsel yuklenmedi: $MI"; FAIL=1; }
echo "$MI" | grep -q '"kind":"IMAGE"' && echo "  ok   kind=IMAGE" || { echo "  FAIL kind: $MI"; FAIL=1; }
MV=$(curl -s -X POST -H "$AA" -F "file=@$TMPW/v.mp4;type=video/mp4" $A/posts/media)
MVID=$(echo "$MV" | jid)
[ -n "$MVID" ] || { echo "  FAIL video yuklenmedi: $MV"; FAIL=1; }
echo "$MV" | grep -q '"durationMs":5000' && echo "  ok   durationMs=5000" || { echo "  FAIL sure: $MV"; FAIL=1; }
check "baglanmamis: sahibi gorur" 200 "$(code -H "$AA" $A/posts/media/$MID)"
check "baglanmamis: baskasi 404" 404 "$(code -H "$AB" $A/posts/media/$MID)"
check "medya girissiz 401 (GET)" 401 "$(code $A/posts/media/$MID)"
check "baskasinin medyasi baglanamaz 400" 400 "$(code -X POST -H "$AB" -H "$H" $A/posts -d "{\"mediaIds\":[$MID]}")"
R3=$(curl -s -X POST -H "$AA" -H "$H" $A/posts -d "{\"text\":\"Medyali\",\"mediaIds\":[$MVID,$MID]}")
PID3=$(echo "$R3" | jid)
[ -n "$PID3" ] || { echo "  FAIL medyali gonderi: $R3"; FAIL=1; }
echo "$R3" | grep -q "\"url\":\"/api/posts/media/$MVID\"" && echo "  ok   PostView.media url" || { echo "  FAIL media url: $R3"; FAIL=1; }
check "ayni medya ikinci kez 400" 400 "$(code -X POST -H "$AA" -H "$H" $A/posts -d "{\"mediaIds\":[$MID]}")"
check "baglanan medya: baskasi gorur" 200 "$(code -H "$AB" $A/posts/media/$MID)"
check "thumb 200" 200 "$(code -H "$AB" "$A/posts/media/$MID?thumb=true")"
check "posterisiz video thumb 404" 404 "$(code -H "$AB" "$A/posts/media/$MVID?thumb=true")"
check "video 200" 200 "$(code -H "$AB" $A/posts/media/$MVID)"
check "video Range 206" 206 "$(code -H "$AB" -H 'Range: bytes=0-9' $A/posts/media/$MVID)"
curl -s -D - -o /dev/null -H "$AB" -H 'Range: bytes=0-9' $A/posts/media/$MVID | tr -d '\r' | grep -qi '^content-range: bytes 0-9/' && echo "  ok   Content-Range" || { echo "  FAIL Content-Range"; FAIL=1; }
check "video Range 416" 416 "$(code -H "$AB" -H 'Range: bytes=99999-' $A/posts/media/$MVID)"
curl -s -D - -o /dev/null -H "$AB" $A/posts/media/$MID | tr -d '\r' | grep -qi '^cache-control: .*max-age=86400' && echo "  ok   Cache-Control" || { echo "  FAIL Cache-Control"; FAIL=1; }
ET=$(curl -s -D - -o /dev/null -H "$AB" $A/posts/media/$MID | tr -d '\r' | grep -i '^etag:' | cut -d' ' -f2)
check "ETag 304" 304 "$(code -H "$AB" -H "If-None-Match: $ET" $A/posts/media/$MID)"
check "admin olmayan 403" 403 "$(code -H "$AB" $A/admin/posts/media/$MID)"
check "bagli medya silinemez 409" 409 "$(code -X DELETE -H "$AA" $A/posts/media/$MID)"
check "gonderiyi sil" 204 "$(code -X DELETE -H "$AA" $A/posts/$PID3)"
check "silinen gonderinin medyasi 404" 404 "$(code -H "$AB" $A/posts/media/$MID)"
rm -rf "$TMPD"

# "duzenle / sil" bolumu $PID'i sildi: begeni ve yorum bolumleri icin yeni gonderi
PID=$(curl -s -X POST -H "$AA" -H "$H" $A/posts -d '{"text":"Begeni ve yorum gonderisi"}' | jid)
echo "== BOLUM begeni"
check "begeni girissiz 401" 401 "$(code -X PUT $A/posts/$PID/like)"
check "olmayan gonderi begeni 404" 404 "$(code -X PUT -H "$AB" $A/posts/999999999/like)"
L1=$(curl -s -X PUT -H "$AB" $A/posts/$PID/like)
echo "$L1" | grep -q '"liked":true' && echo "$L1" | grep -q '"likeCount":1' && echo "  ok   PUT like -> 1" || { echo "  FAIL like: $L1"; FAIL=1; }
L2=$(curl -s -X PUT -H "$AB" $A/posts/$PID/like)
echo "$L2" | grep -q '"likeCount":1' && echo "  ok   PUT idempotent" || { echo "  FAIL idempotent: $L2"; FAIL=1; }
# es zamanli cift PUT (yazar): sayac yalniz bir kez artar
curl -s -o /dev/null -X PUT -H "$AA" $A/posts/$PID/like &
curl -s -o /dev/null -X PUT -H "$AA" $A/posts/$PID/like &
wait
curl -s -H "$AB" $A/posts/$PID | grep -q '"likeCount":2' && echo "  ok   yaris: sayac 2" || { echo "  FAIL yaris sayaci"; FAIL=1; }
curl -s -H "$AB" $A/posts/$PID | grep -q '"likedByMe":true' && echo "  ok   likedByMe=true" || { echo "  FAIL likedByMe"; FAIL=1; }
LK=$(curl -s -H "$AA" "$A/posts/$PID/likes?size=1")
echo "$LK" | grep -q '"total":2' && echo "  ok   likes total=2" || { echo "  FAIL likes total: $LK"; FAIL=1; }
echo "$LK" | grep -q '"nextCursor":"' && echo "  ok   likes nextCursor" || { echo "  FAIL likes cursor: $LK"; FAIL=1; }
LCUR=$(echo "$LK" | grep -o '"nextCursor":"[^"]*' | cut -d'"' -f4)
check "likes 2. sayfa" 200 "$(code -H "$AA" "$A/posts/$PID/likes?size=1&cursor=$LCUR")"
check "likes bozuk imlec 400" 400 "$(code -H "$AA" "$A/posts/$PID/likes?cursor=bozuk")"
D1=$(curl -s -X DELETE -H "$AB" $A/posts/$PID/like)
echo "$D1" | grep -q '"liked":false' && echo "$D1" | grep -q '"likeCount":1' && echo "  ok   DELETE like -> 1" || { echo "  FAIL unlike: $D1"; FAIL=1; }
D2=$(curl -s -X DELETE -H "$AB" $A/posts/$PID/like)
echo "$D2" | grep -q '"likeCount":1' && echo "  ok   DELETE idempotent" || { echo "  FAIL unlike idempotent: $D2"; FAIL=1; }
# bildirim: B yazarin gonderisini begenir -> A'da POST_LIKE bildirimi
curl -s -o /dev/null -X PUT -H "$AB" $A/posts/$PID/like
curl -s -H "$AA" "$A/notifications?type=POST_LIKE" | grep -q '"POST_LIKE"'  && echo "  ok   POST_LIKE bildirimi" || { echo "  FAIL POST_LIKE bildirimi"; FAIL=1; }
check "ikinci gonderiyi begen" 200 "$(code -X PUT -H "$AB" $A/posts/$PID2/like)"

echo "== yorum: ekle / yanit / derinlik / sayac / siralama"
check "girissiz yorum 401" 401 "$(code $A/posts/$PID/comments)"
check "bos yorum 400" 400 "$(code -X POST -H "$AB" -H "$H" $A/posts/$PID/comments -d '{"text":"   "}')"
CR=$(curl -s -X POST -H "$AB" -H "$H" $A/posts/$PID/comments -d '{"text":"ilk yorum"}')
C0=$(echo "$CR" | jid)
[ -n "$C0" ] || { echo "  FAIL yorum olusmadi: $CR"; exit 1; }
echo "$CR" | grep -q '"depth":0' && echo "  ok   kok depth=0" || { echo "  FAIL depth: $CR"; FAIL=1; }
check "baska gonderide ebeveyn 400" 400 "$(code -X POST -H "$AB" -H "$H" $A/posts/$PID2/comments -d "{\"text\":\"x\",\"parentId\":$C0}")"
C1=$(curl -s -X POST -H "$AA" -H "$H" $A/posts/$PID/comments -d "{\"text\":\"yanit1\",\"parentId\":$C0}" | jid)
C2=$(curl -s -X POST -H "$AB" -H "$H" $A/posts/$PID/comments -d "{\"text\":\"yanit2\",\"parentId\":$C1}" | jid)
C3=$(curl -s -X POST -H "$AA" -H "$H" $A/posts/$PID/comments -d "{\"text\":\"yanit3\",\"parentId\":$C2}" | jid)
C4R=$(curl -s -X POST -H "$AB" -H "$H" $A/posts/$PID/comments -d "{\"text\":\"derin\",\"parentId\":$C3}")
C4R_ID=$(echo "$C4R" | jid)
echo "$C4R" | grep -q '"depth":3' && echo "$C4R" | grep -q "\"parentId\":$C2" && echo "  ok   4. seviye kardese dustu" || { echo "  FAIL derinlik: $C4R"; FAIL=1; }
curl -s -H "$AA" $A/posts/$PID | grep -q '"commentCount":5' && echo "  ok   commentCount=5" || { echo "  FAIL commentCount"; FAIL=1; }
CL=$(curl -s -H "$AA" "$A/posts/$PID/comments?sort=top&size=5")
echo "$CL" | grep -q '"previewReplies":\[' && echo "  ok   previewReplies" || { echo "  FAIL previewReplies: $CL"; FAIL=1; }
echo "$CL" | grep -q '"total":5' && echo "  ok   total=5" || { echo "  FAIL total: $CL"; FAIL=1; }
check "yanitlar" 200 "$(code -H "$AA" "$A/comments/$C0/replies?size=1")"
check "bozuk imlec 400" 400 "$(code -H "$AA" "$A/posts/$PID/comments?cursor=bozuk")"
check "baskasinin yorumunu duzenleme 403" 403 "$(code -X PATCH -H "$AA" -H "$H" $A/comments/$C0 -d '{"text":"x"}')"
check "yorum duzenle" 200 "$(code -X PATCH -H "$AB" -H "$H" $A/comments/$C0 -d '{"text":"duzenlendi"}')"
curl -s -H "$AA" "$A/notifications?type=POST_COMMENT" | grep -q '"POST_COMMENT"' && echo "  ok   POST_COMMENT bildirimi" || { echo "  FAIL POST_COMMENT bildirimi"; FAIL=1; }
check "yanitli yorumu gonderi sahibi siler" 204 "$(code -X DELETE -H "$AA" $A/comments/$C0)"
curl -s -H "$AA" "$A/posts/$PID/comments" | grep -q '"deleted":true' && echo "  ok   silindi kaydi" || { echo "  FAIL silindi kaydi"; FAIL=1; }
curl -s -H "$AA" $A/posts/$PID | grep -q '"commentCount":4' && echo "  ok   commentCount=4" || { echo "  FAIL commentCount silme sonrasi"; FAIL=1; }
check "silinmis yorum tekrar silme 404" 404 "$(code -X DELETE -H "$AA" $A/comments/$C0)"

echo "== BOLUM moderasyon / yonetici / arama (E)"
# Yonetici hesabi: ADMIN_EMAILS=$ADMIN_EMAIL ile compose acilmis olmali (smoke-admin.sh ile ayni)
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
TAD=$(register "$ADMIN_EMAIL" "Yonetici")
if [ -z "$TAD" ]; then
  echo "  SKIP yonetici token yok (ADMIN_EMAILS ayarli mi?)"
else
  AD="Authorization: Bearer $TAD"
  MR=$(curl -s -X POST -H "$AA" -H "$H" $A/posts -d '{"text":"moderasyon deneme metni ozgunkelime"}')
  MPID=$(echo "$MR" | jid)
  check "admin olmayan liste 403" 403 "$(code -H "$AB" $A/admin/posts)"
  check "girissiz liste 401" 401 "$(code $A/admin/posts)"
  check "admin liste 200" 200 "$(code -H "$AD" "$A/admin/posts?size=5")"
  curl -s -H "$AD" "$A/admin/posts?q=Gonderi%20Yazar&size=5" | grep -q "\"id\":$MPID," && echo "  ok   yazar adiyla arama" || { echo "  FAIL admin q suzgeci"; FAIL=1; }
  curl -s -H "$AD" $A/admin/posts/stats | grep -q '"postCount"' && echo "  ok   stats" || { echo "  FAIL stats"; FAIL=1; }
  check "admin detay 200" 200 "$(code -H "$AD" $A/admin/posts/$MPID)"
  check "olmayan gonderi 404" 404 "$(code -H "$AD" $A/admin/posts/99999999)"
  # arama: PostgreSQL tam metin (type=POSTS)
  curl -s -H "$AB" "$A/search?q=ozgunkelime&type=POSTS" | grep -q "\"targetId\":$MPID" && echo "  ok   arama POSTS" || { echo "  FAIL arama POSTS"; FAIL=1; }
  # sikayet -> rapor kuyrugu (FEED_POST) -> gizle
  check "FEED_POST sikayeti" 201 "$(code -X POST -H "$AB" -H "$H" $A/reports -d "{\"targetType\":\"FEED_POST\",\"targetId\":$MPID,\"reason\":\"SPAM\"}")"
  RID=$(curl -s -H "$AD" "$A/admin/reports?size=50" | grep -o "\"id\":[0-9]*,\"reporterId\":[0-9]*,\"targetType\":\"FEED_POST\",\"targetId\":$MPID," | head -1 | grep -o '^"id":[0-9]*' | cut -d: -f2)
  [ -n "$RID" ] && echo "  ok   rapor kuyrukta" || { echo "  FAIL rapor kuyrukta yok"; FAIL=1; }
  curl -s -H "$AD" $A/admin/reports/$RID | grep -q '"kind":"FEED_POST"' && echo "  ok   rapor baglami FEED_POST" || { echo "  FAIL rapor baglami"; FAIL=1; }
  check "yorumu sikayet" 201 "$(code -X POST -H "$AB" -H "$H" $A/reports -d "{\"targetType\":\"FEED_COMMENT\",\"targetId\":$C1,\"reason\":\"HARASSMENT\"}")"
  # gizle -> akistan ve aramadan kalkar, geri ac -> doner
  check "gizle" 200 "$(code -X POST -H "$AD" -H "$H" $A/admin/posts/$MPID/hide -d '{"reason":"deneme"}')"
  curl -s -H "$AB" "$A/feed?scope=latest&size=20" | grep -q "\"id\":$MPID," && { echo "  FAIL gizli gonderi akista"; FAIL=1; } || echo "  ok   gizli gonderi akista yok"
  check "gizli gonderi 404" 404 "$(code -H "$AB" $A/posts/$MPID)"
  curl -s -H "$AB" "$A/search?q=ozgunkelime&type=POSTS" | grep -q "\"targetId\":$MPID" && { echo "  FAIL gizli gonderi aramada"; FAIL=1; } || echo "  ok   gizli gonderi aramada yok"
  curl -s -H "$AD" "$A/admin/posts?hidden=true&size=50" | grep -q "\"id\":$MPID," && echo "  ok   hidden=true suzgeci" || { echo "  FAIL hidden suzgeci"; FAIL=1; }
  check "geri ac" 200 "$(code -X POST -H "$AD" -H "$H" $A/admin/posts/$MPID/unhide -d '{}')"
  check "geri acilan gonderi 200" 200 "$(code -H "$AB" $A/posts/$MPID)"
  # yorum yonetimi
  check "yorumlar 200" 200 "$(code -H "$AD" $A/admin/posts/$PID/comments)"
  check "yorum gizle" 200 "$(code -X POST -H "$AD" -H "$H" $A/admin/comments/$C1/hide -d '{}')"
  check "yorum geri ac" 200 "$(code -X POST -H "$AD" -H "$H" $A/admin/comments/$C1/unhide -d '{}')"
  check "yorum sil" 204 "$(code -X DELETE -H "$AD" $A/admin/comments/$C4R_ID)"
  # denetim kaydi
  curl -s -H "$AD" "$A/admin/audit?size=20" | grep -q "/api/admin/posts/$MPID/hide" && echo "  ok   denetim kaydi" || { echo "  FAIL denetim kaydi"; FAIL=1; }
  # KVKK dis aktarim
  EX=$(curl -s -H "$AA" $A/users/me/export)
  echo "$EX" | grep -q '"posts"' && echo "$EX" | grep -q '"postComments"' && echo "$EX" | grep -q '"postLikes"' && echo "  ok   export bolumleri" || { echo "  FAIL export bolumleri"; FAIL=1; }
  check "admin gonderi sil" 204 "$(code -X DELETE -H "$AD" $A/admin/posts/$MPID)"
  curl -s -H "$AD" "$A/admin/posts?deleted=true&size=50" | grep -q "\"id\":$MPID," && echo "  ok   deleted=true suzgeci" || { echo "  FAIL deleted suzgeci"; FAIL=1; }
fi

# --- DIGER AJANLAR BOLUMLERINI BURAYA EKLER (moderasyon) ---

[ $FAIL -eq 0 ] && echo "TUMU GECTI" || echo "HATA VAR"
exit $FAIL

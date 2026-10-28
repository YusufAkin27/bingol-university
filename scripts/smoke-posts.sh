#!/usr/bin/env bash
# Sade Kesfet gonderileri icin uctan uca duman testi (gercek PostgreSQL gerekir).
# Sozlesme: gonderi = TAM 1 fotograf (zorunlu) + en cok 7 kelime/60 karakter tek satir metin (istege bagli).
# Kaldirilan ozellikler (yorum, hikaye, etiket, kaydet, begenenler listesi) icin uc YOKTUR: 404 doner (V470 ile tablolar da dusuruldu).
# Kullanim: BASE=http://localhost:8080 ./scripts/smoke-posts.sh
# Onkosul: compose'ta MAIL_ENABLED=false (dogrulama kodu log'dan okunur); gerekirse once redis flushall.
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

SFX=$RANDOM
TA=$(register "posta$SFX@bingol.edu.tr" "Gonderi Yazar")
TB=$(register "postb$SFX@bingol.edu.tr" "Gonderi Okur")
[ -n "$TA" ] && [ -n "$TB" ] || { echo "kayit basarisiz"; exit 1; }
AA="Authorization: Bearer $TA"
AB="Authorization: Bearer $TB"

TMPD=$(mktemp -d)
# 1x1 PNG ve en kucuk sentetik mp4 (yalniz kap yapisi; video gonderi olarak reddedilmeli)
printf 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' | base64 -d > "$TMPD/a.png"
printf '\x00\x00\x00\x14ftypisom\x00\x00\x02\x00isom\x00\x00\x00\x24moov\x00\x00\x00\x1cmvhd\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x03\xe8\x00\x00\x13\x88' > "$TMPD/v.mp4"
printf 'bu bir gorsel degil' > "$TMPD/bad.png"
# Windows'ta curl -F icin yol Windows bicimi olmali (cygpath yoksa oldugu gibi kalir)
TMPW=$(cygpath -m "$TMPD" 2>/dev/null || echo "$TMPD")

upload() { # token-basligi -> medya id
  curl -s -X POST -H "$1" -F "file=@$TMPW/a.png;type=image/png" $A/posts/media | jid
}
newpost() { # token-basligi metin -> gonderi yaniti
  local m
  m=$(upload "$1")
  curl -s -X POST -H "$1" -H "$H" $A/posts -d "{\"text\":\"$2\",\"mediaIds\":[$m]}"
}

echo "== medya: yukleme / sunum"
check "medya girissiz 401" 401 "$(code -X POST -F "file=@$TMPW/a.png;type=image/png" $A/posts/media)"
check "gecersiz gorsel 400" 400 "$(code -X POST -H "$AA" -F "file=@$TMPW/bad.png;type=image/png" $A/posts/media)"
MI=$(curl -s -X POST -H "$AA" -F "file=@$TMPW/a.png;type=image/png" $A/posts/media)
MID=$(echo "$MI" | jid)
[ -n "$MID" ] || { echo "  FAIL gorsel yuklenmedi: $MI"; exit 1; }
has "kind=IMAGE" '"kind":"IMAGE"' "$MI"
check "baglanmamis: sahibi gorur" 200 "$(code -H "$AA" $A/posts/media/$MID)"
check "baglanmamis: baskasi 404" 404 "$(code -H "$AB" $A/posts/media/$MID)"
check "medya girissiz 401 (GET)" 401 "$(code $A/posts/media/$MID)"

echo "== gonderi: kurallar (tek foto + en cok 7 kelime)"
check "girissiz akis 401" 401 "$(code $A/feed)"
check "fotografsiz 400" 400 "$(code -X POST -H "$AA" -H "$H" $A/posts -d '{"text":"yalniz metin"}')"
check "baskasinin medyasi 400" 400 "$(code -X POST -H "$AB" -H "$H" $A/posts -d "{\"mediaIds\":[$MID]}")"
MV=$(curl -s -X POST -H "$AA" -F "file=@$TMPW/v.mp4;type=video/mp4" $A/posts/media | jid)
if [ -n "$MV" ]; then
  check "video gonderi 400" 400 "$(code -X POST -H "$AA" -H "$H" $A/posts -d "{\"mediaIds\":[$MV]}")"
fi
M2=$(upload "$AA")
check "iki foto 400" 400 "$(code -X POST -H "$AA" -H "$H" $A/posts -d "{\"mediaIds\":[$MID,$M2]}")"
check "8 kelime 422" 422 "$(code -X POST -H "$AA" -H "$H" $A/posts -d "{\"text\":\"bir iki uc dort bes alti yedi sekiz\",\"mediaIds\":[$MID]}")"
check "cok satir 422" 422 "$(code -X POST -H "$AA" -H "$H" $A/posts -d "{\"text\":\"bir\\niki\",\"mediaIds\":[$MID]}")"
R=$(curl -s -X POST -H "$AA" -H "$H" $A/posts -d "{\"text\":\"Merhaba kampus\",\"mediaIds\":[$MID]}")
PID=$(echo "$R" | jid)
[ -n "$PID" ] || { echo "  FAIL gonderi olusmadi: $R"; exit 1; }
has "mine=true" '"mine":true' "$R"
has "PostView.media url" "\"url\":\"/api/posts/media/$MID\"" "$R"
check "baglanan medya tekrar 400" 400 "$(code -X POST -H "$AA" -H "$H" $A/posts -d "{\"mediaIds\":[$MID]}")"
check "baskasi okur" 200 "$(code -H "$AB" $A/posts/$PID)"
check "baglanan medya: baskasi gorur" 200 "$(code -H "$AB" $A/posts/media/$MID)"
check "thumb 200" 200 "$(code -H "$AB" "$A/posts/media/$MID?thumb=true")"
check "olmayan 404" 404 "$(code -H "$AB" $A/posts/999999999)"
has "baskasi canEdit=false" '"canEdit":false' "$(curl -s -H "$AB" $A/posts/$PID)"

echo "== akis (latest / popular / top, imec)"
R2=$(newpost "$AA" "Ikinci gonderi")
PID2=$(echo "$R2" | jid)
[ -n "$PID2" ] || { echo "  FAIL ikinci gonderi: $R2"; exit 1; }
F=$(curl -s -H "$AB" "$A/feed?scope=latest&size=1")
has "latest: en yeni basta" "\"id\":$PID2," "$F"
CUR=$(echo "$F" | grep -o '"nextCursor":"[^"]*' | cut -d'"' -f4)
[ -n "$CUR" ] && echo "  ok   nextCursor var" || { echo "  FAIL nextCursor yok"; FAIL=1; }
has "latest 2. sayfa" '"items":\[{' "$(curl -s -H "$AB" "$A/feed?scope=latest&size=1&cursor=$CUR")"
check "popular 200" 200 "$(code -H "$AB" "$A/feed?scope=popular")"
check "top 200" 200 "$(code -H "$AB" "$A/feed?scope=top")"
FT=$(curl -s -H "$AB" "$A/feed?scope=top&size=1")
has "top: items alani" '"items":\[' "$FT"
TCUR=$(echo "$FT" | grep -o '"nextCursor":"[^"]*' | cut -d'"' -f4)
if [ -n "$TCUR" ]; then
  check "top 2. sayfa (imlec)" 200 "$(code -H "$AB" "$A/feed?scope=top&size=1&cursor=$TCUR")"
else
  echo "  --   top nextCursor yok (tek sayfalik veri)"
fi
check "top bozuk imlec 400" 400 "$(code -H "$AB" "$A/feed?scope=top&cursor=bozuk")"
check "bozuk imlec 400" 400 "$(code -H "$AB" "$A/feed?cursor=bozuk")"
check "gecersiz kapsam 400" 400 "$(code -H "$AB" "$A/feed?scope=bogus")"
check "benim gonderilerim" 200 "$(code -H "$AA" "$A/posts/mine")"
check "kullanici gonderileri" 200 "$(code -H "$AB" "$A/users/1/posts")"

echo "== duzenle / sil"
check "baskasi duzenleyemez 403" 403 "$(code -X PATCH -H "$AB" -H "$H" $A/posts/$PID -d '{"text":"hack"}')"
check "yazar duzenler" 200 "$(code -X PATCH -H "$AA" -H "$H" $A/posts/$PID -d '{"text":"Duzenlendi"}')"
has "editedAt dolu" '"editedAt":"' "$(curl -s -H "$AB" $A/posts/$PID)"
check "duzenle 8 kelime 422" 422 "$(code -X PATCH -H "$AA" -H "$H" $A/posts/$PID -d '{"text":"bir iki uc dort bes alti yedi sekiz"}')"
check "baskasi silemez 403" 403 "$(code -X DELETE -H "$AB" $A/posts/$PID)"
check "yazar siler" 204 "$(code -X DELETE -H "$AA" $A/posts/$PID)"
check "silinen 404" 404 "$(code -H "$AB" $A/posts/$PID)"
check "silinen gonderinin medyasi 404" 404 "$(code -H "$AB" $A/posts/media/$MID)"

echo "== begeni"
PID=$(newpost "$AA" "Begeni gonderisi" | jid)
check "begeni girissiz 401" 401 "$(code -X PUT $A/posts/$PID/like)"
check "olmayan gonderi begeni 404" 404 "$(code -X PUT -H "$AB" $A/posts/999999999/like)"
L1=$(curl -s -X PUT -H "$AB" $A/posts/$PID/like)
has "PUT like -> 1" '"likeCount":1' "$L1"
has "PUT like liked" '"liked":true' "$L1"
has "PUT idempotent" '"likeCount":1' "$(curl -s -X PUT -H "$AB" $A/posts/$PID/like)"
# es zamanli cift PUT (yazar): sayac yalniz bir kez artar
curl -s -o /dev/null -X PUT -H "$AA" $A/posts/$PID/like &
curl -s -o /dev/null -X PUT -H "$AA" $A/posts/$PID/like &
wait
has "yaris: sayac 2" '"likeCount":2' "$(curl -s -H "$AB" $A/posts/$PID)"
has "likedByMe=true" '"likedByMe":true' "$(curl -s -H "$AB" $A/posts/$PID)"
has "DELETE like -> 1" '"likeCount":1' "$(curl -s -X DELETE -H "$AB" $A/posts/$PID/like)"
has "DELETE idempotent" '"likeCount":1' "$(curl -s -X DELETE -H "$AB" $A/posts/$PID/like)"
curl -s -o /dev/null -X PUT -H "$AB" $A/posts/$PID/like
has "POST_LIKE bildirimi" '"POST_LIKE"' "$(curl -s -H "$AA" "$A/notifications?type=POST_LIKE")"

echo "== kaldirilan uclar: artik yok (404)"
for ep in "GET posts/$PID/comments" "POST posts/$PID/comments" "GET stories/tray" "POST stories" \
          "GET hashtags/trending" "GET hashtags/abc/posts" "GET users/mention-suggest" \
          "PUT posts/$PID/save" "DELETE posts/$PID/save" "GET posts/$PID/likes"; do
  M=${ep%% *}; P=${ep#* }
  check "404 $M /$P" 404 "$(code -X $M -H "$AB" -H "$H" -d '{}' "$A/$P")"
done

echo "== BOLUM moderasyon / yonetici / arama"
# Yonetici hesabi: ADMIN_EMAILS=$ADMIN_EMAIL ile compose acilmis olmali (smoke-admin.sh ile ayni)
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
TAD=$(register "$ADMIN_EMAIL" "Yonetici")
if [ -z "$TAD" ]; then
  echo "  SKIP yonetici token yok (ADMIN_EMAILS ayarli mi?)"
else
  AD="Authorization: Bearer $TAD"
  MR=$(newpost "$AA" "ozgunkelime")
  MPID=$(echo "$MR" | jid)
  check "admin olmayan liste 403" 403 "$(code -H "$AB" $A/admin/posts)"
  check "girissiz liste 401" 401 "$(code $A/admin/posts)"
  check "admin liste 200" 200 "$(code -H "$AD" "$A/admin/posts?size=5")"
  has "yazar adiyla arama" "\"id\":$MPID," "$(curl -s -H "$AD" "$A/admin/posts?q=Gonderi%20Yazar&size=5")"
  has "stats" '"postCount"' "$(curl -s -H "$AD" $A/admin/posts/stats)"
  check "admin detay 200" 200 "$(code -H "$AD" $A/admin/posts/$MPID)"
  check "olmayan gonderi 404" 404 "$(code -H "$AD" $A/admin/posts/99999999)"
  # arama: PostgreSQL tam metin (type=POSTS); yalniz gorunur + fotografli gonderi
  has "arama POSTS" "\"targetId\":$MPID" "$(curl -s -H "$AB" "$A/search?q=ozgunkelime&type=POSTS")"
  check "FEED_POST sikayeti" 201 "$(code -X POST -H "$AB" -H "$H" $A/reports -d "{\"targetType\":\"FEED_POST\",\"targetId\":$MPID,\"reason\":\"SPAM\"}")"
  RID=$(curl -s -H "$AD" "$A/admin/reports?size=50" | grep -o "\"id\":[0-9]*,\"reporterId\":[0-9]*,\"targetType\":\"FEED_POST\",\"targetId\":$MPID," | head -1 | grep -o '^"id":[0-9]*' | cut -d: -f2)
  [ -n "$RID" ] && echo "  ok   rapor kuyrukta" || { echo "  FAIL rapor kuyrukta yok"; FAIL=1; }
  has "rapor baglami FEED_POST" '"kind":"FEED_POST"' "$(curl -s -H "$AD" $A/admin/reports/$RID)"
  # gizle -> akistan ve aramadan kalkar, geri ac -> doner
  check "gizle" 200 "$(code -X POST -H "$AD" -H "$H" $A/admin/posts/$MPID/hide -d '{"reason":"deneme"}')"
  curl -s -H "$AB" "$A/feed?scope=latest&size=20" | grep -q "\"id\":$MPID," && { echo "  FAIL gizli gonderi akista"; FAIL=1; } || echo "  ok   gizli gonderi akista yok"
  check "gizli gonderi 404" 404 "$(code -H "$AB" $A/posts/$MPID)"
  curl -s -H "$AB" "$A/search?q=ozgunkelime&type=POSTS" | grep -q "\"targetId\":$MPID" && { echo "  FAIL gizli gonderi aramada"; FAIL=1; } || echo "  ok   gizli gonderi aramada yok"
  has "hidden=true suzgeci" "\"id\":$MPID," "$(curl -s -H "$AD" "$A/admin/posts?hidden=true&size=50")"
  check "geri ac" 200 "$(code -X POST -H "$AD" -H "$H" $A/admin/posts/$MPID/unhide -d '{}')"
  check "geri acilan gonderi 200" 200 "$(code -H "$AB" $A/posts/$MPID)"
  has "denetim kaydi" "/api/admin/posts/$MPID/hide" "$(curl -s -H "$AD" "$A/admin/audit?size=20")"
  # V470 sonrasi yonetici yetenekleri: durum/yazar/rapor suzgeci, metin duzenleme (PATCH), gerekceli silme
  has "status=VISIBLE suzgeci" "\"id\":$MPID," "$(curl -s -H "$AD" "$A/admin/posts?status=VISIBLE&size=50")"
  has "minReports=1 suzgeci" "\"id\":$MPID," "$(curl -s -H "$AD" "$A/admin/posts?minReports=1&size=50")"
  check "gecersiz status 400" 400 "$(code -H "$AD" "$A/admin/posts?status=BOGUS")"
  check "admin metin duzenle" 200 "$(code -X PATCH -H "$AD" -H "$H" $A/admin/posts/$MPID -d '{"text":"duzenlendi"}')"
  has "duzenlenen metin" 'duzenlendi' "$(curl -s -H "$AD" $A/admin/posts/$MPID)"
  check "admin metin cok uzun 422" 422 "$(code -X PATCH -H "$AD" -H "$H" $A/admin/posts/$MPID -d '{"text":"bir iki uc dort bes alti yedi sekiz"}')"
  check "admin olmayan duzenleyemez 403" 403 "$(code -X PATCH -H "$AB" -H "$H" $A/admin/posts/$MPID -d '{"text":"x"}')"
  # KVKK dis aktarim: gonderi bolumu
  has "export posts bolumu" '"posts"' "$(curl -s -H "$AA" $A/users/me/export)"
  check "admin gonderi sil (gerekceli)" 204 "$(code -X DELETE -H "$AD" -H "$H" $A/admin/posts/$MPID -d '{"reason":"deneme silme"}')"
  has "silmeyle rapor sonuclandi" '"RESOLVED"' "$(curl -s -H "$AD" $A/admin/posts/$MPID)"
  has "deleted=true suzgeci" "\"id\":$MPID," "$(curl -s -H "$AD" "$A/admin/posts?deleted=true&size=50")"
fi

rm -rf "$TMPD"
[ $FAIL -eq 0 ] && echo "TUMU GECTI" || echo "HATA VAR"
exit $FAIL

#!/usr/bin/env bash
# Kesfet v2 duman testi (gercek PostgreSQL + Redis gerekir): tek siralama, video gonderi, Reels, gorulmus kumesi
# (tekrar gostermeme), izlenme olayi, populerlik puani. Sozlesme: docs/changes/post.md "KS-BE (V1220)".
# Kullanim: BASE=http://localhost:8080 [ADMIN_PASSWORD=...] ./scripts/smoke-kesfet-video.sh
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
hasnt() { # ad desen metin
  if echo "$3" | grep -q "$2"; then echo "  FAIL $1 (istenmeyen desen $2): $3"; FAIL=1; else echo "  ok   $1"; fi
}
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
jid() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
ids() { grep -o '"id":[0-9]*' | cut -d: -f2 | sort -u | tr '\n' ' '; }
PY=$(command -v python3 || command -v python)
postids() { # akis yanitindan (stdin) gonderi kimlikleri
  "$PY" -c 'import json,sys; d=json.load(sys.stdin); print(" ".join(str(i["id"]) for i in d.get("items",[])))'
}

register() { # email ad
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Zk7-Qmv-Lpx92w\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Zk7-Qmv-Lpx92w\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4
}

SFX=$RANDOM
TA=$(register "kva$SFX@bingol.edu.tr" "Video Yazar")
TB=$(register "kvb$SFX@bingol.edu.tr" "Video Okur")
[ -n "$TA" ] && [ -n "$TB" ] || { echo "kayit basarisiz"; exit 1; }
AA="Authorization: Bearer $TA"
AB="Authorization: Bearer $TB"

TMPD=$(mktemp -d)
# 1x1 PNG (poster/foto) ve 5 sn'lik sentetik MP4 kap yapisi (ftyp+mdat+moov/mvhd+tkhd; oynatilabilir degil, yalniz kap)
printf 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' | base64 -d > "$TMPD/a.png"
printf '%s' 'AAAAGGZ0eXBpc29tAAAAAGlzb21pc28yAAAASG1kYXSjHAa9Rj45I7warb3kixaXbAgHFzc7gZoGjzK3prOLazhylkfP3gHCziiybFdHJzf1w1YaF2EYW9hYmkPOC7p1AAAA2G1vb3YAAABsbXZoZAAAAAAAAAAAAAAAAAAAA+gAABOIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABkdHJhawAAAFx0a2hkAAAAAAAAAAAAAAAAAAAAAAAAAAAAABOIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAQAAA' | base64 -d > "$TMPD/v.mp4"
printf 'bu bir video degil, sadece metin ....................' > "$TMPD/junk.mp4"
TMPW=$(cygpath -m "$TMPD" 2>/dev/null || echo "$TMPD")

echo "== video yukleme (gercek icerik dogrulamasi)"
check "bozuk video 400" 400 "$(code -X POST -H "$AA" -F "file=@$TMPW/junk.mp4;type=video/mp4" $A/posts/media)"
check "video girissiz 401" 401 "$(code -X POST -F "file=@$TMPW/v.mp4;type=video/mp4" $A/posts/media)"
VM=$(curl -s -X POST -H "$AA" -F "file=@$TMPW/v.mp4;type=video/mp4" -F "poster=@$TMPW/a.png;type=image/png" $A/posts/media)
VID=$(echo "$VM" | jid)
[ -n "$VID" ] || { echo "  FAIL video yuklenmedi: $VM"; exit 1; }
has "kind=VIDEO" '"kind":"VIDEO"' "$VM"
has "durationMs=5000" '"durationMs":5000' "$VM"
check "baglanmamis video: baskasi 404" 404 "$(code -H "$AB" $A/posts/media/$VID)"
check "video Range 206" 206 "$(code -H "$AA" -H 'Range: bytes=0-15' $A/posts/media/$VID)"
check "poster 200" 200 "$(code -H "$AA" "$A/posts/media/$VID?thumb=true")"

echo "== video gonderi"
MP=$(curl -s -X POST -H "$AA" -F "file=@$TMPW/a.png;type=image/png" $A/posts/media | jid)
check "foto+video birlikte 400" 400 "$(code -X POST -H "$AA" -H "$H" $A/posts -d "{\"mediaIds\":[$MP,$VID]}")"
R=$(curl -s -X POST -H "$AA" -H "$H" $A/posts -d "{\"text\":\"kampus klip\",\"mediaIds\":[$VID]}")
PV=$(echo "$R" | jid)
[ -n "$PV" ] || { echo "  FAIL video gonderi olusmadi: $R"; exit 1; }
has "type=VIDEO" '"type":"VIDEO"' "$R"
has "video nesnesi" '"video":{' "$R"
has "viewCount=0" '"viewCount":0' "$R"
has "yazar popularityScore" '"popularityScore":' "$R"
R2=$(curl -s -X POST -H "$AA" -H "$H" $A/posts -d "{\"text\":\"kampus foto\",\"mediaIds\":[$MP]}")
PP=$(echo "$R2" | jid)
has "foto type=PHOTO" '"type":"PHOTO"' "$R2"
hasnt "fotoda video alani yok" '"video":{' "$R2"

echo "== kapsamlar: foryou | popular (top) | latest | following"
for sc in foryou popular top latest following; do
  check "feed scope=$sc 200" 200 "$(code -H "$AB" "$A/feed?scope=$sc&size=1")"
done
has "latest exhausted alani yok" '"items":' "$(curl -s -H "$AB" "$A/feed?scope=latest&size=2")"
hasnt "latest exhausted yok" '"exhausted"' "$(curl -s -H "$AB" "$A/feed?scope=latest&size=2")"
check "gecersiz kapsam 400" 400 "$(code -H "$AB" "$A/feed?scope=bogus")"
check "following hala 200" 200 "$(code -H "$AB" "$A/feed?scope=following")"

echo "== tekrar gostermeme (gorulmus kumesi)"
F1=$(curl -s -H "$AB" "$A/feed?size=3")
has "exhausted alani" '"exhausted":' "$F1"
IDS1=$(echo "$F1" | postids)
F2=$(curl -s -H "$AB" "$A/feed?size=3")
IDS2=$(echo "$F2" | postids)
if echo "$F2" | grep -q '"exhausted":true'; then
  echo "  ok   havuz tukendi -> tekrar modu (exhausted=true)"
else
  OVER=""
  for i in $IDS2; do case " $IDS1 " in *" $i "*) OVER="$OVER $i";; esac; done
  check "yenilemede ayni gonderi yok" "" "$OVER"
fi
check "seen 204" 204 "$(code -X POST -H "$AB" -H "$H" $A/feed/seen -d "{\"ids\":[$PP]}")"
check "seen girissiz 401" 401 "$(code -X POST -H "$H" $A/feed/seen -d '{"ids":[1]}')"
BIG=$("$PY" -c "print(','.join(str(i) for i in range(1,102)))")
check "seen 101 kimlik 400" 400 "$(code -X POST -H "$AB" -H "$H" $A/feed/seen -d "{\"ids\":[$BIG]}")"
FS=$(curl -s -H "$AB" "$A/feed?size=30")
if echo "$FS" | grep -q '"exhausted":false'; then
  hasnt "seen ile isaretlenen foto akista yok" "\"id\":$PP,\"author\"" "$FS"
fi

echo "== reels"
check "reels girissiz 401" 401 "$(code $A/feed/reels)"
FR=$(curl -s -H "$AA" "$A/feed/reels?size=20")
hasnt "reels yalniz video (PHOTO yok)" '"type":"PHOTO"' "$FR"
has "reels exhausted alani" '"exhausted":' "$FR"
FR2=$(curl -s -H "$AB" "$A/feed/reels?size=20")
has "reels video gonderiyi listeler" "\"id\":$PV," "$FR2"
check "reels bozuk imlec 400" 400 "$(code -H "$AB" "$A/feed/reels?cursor=bozuk")"
check "seen (reels gosterimi) 204" 204 "$(code -X POST -H "$AB" -H "$H" $A/feed/seen -d "{\"ids\":[$PV]}")"
# gosterim kaydindan sonra normal modda video tekrar gelmez (izlenmemisler oncelikli); replay=true ile gelir
FR4=$(curl -s -H "$AB" "$A/feed/reels?size=20")
hasnt "gorulen video yenilemede yok" "\"id\":$PV," "$FR4"
FR5=$(curl -s -H "$AB" "$A/feed/reels?size=20&replay=true")
has "replay: video tekrar gelir" "\"id\":$PV," "$FR5"
has "replay exhausted alani" '"exhausted":' "$FR5"
echo "== ilgilenmiyorum"
check "not-interested girissiz 401" 401 "$(code -X POST $A/posts/$PV/not-interested)"
check "not-interested 404" 404 "$(code -X POST -H "$AB" $A/posts/99999999/not-interested)"
check "not-interested 204" 204 "$(code -X POST -H "$AB" $A/posts/$PV/not-interested)"
hasnt "ilgilenmiyorum: reels'te yok" "\"id\":$PV," "$(curl -s -H "$AB" "$A/feed/reels?size=20&replay=true")"
check "not-interested geri al 204" 204 "$(code -X DELETE -H "$AB" $A/posts/$PV/not-interested)"
has "geri alinca replay'de var" "\"id\":$PV," "$(curl -s -H "$AB" "$A/feed/reels?size=20&replay=true")"
echo "== KVKK: izleme gecmisi disa aktarimda"
has "export reelWatchHistory" 'reelWatchHistory' "$(curl -s -H "$AB" $A/users/me/export)"

echo "== izlenme olayi"
check "view girissiz 401" 401 "$(code -X POST -H "$H" $A/posts/$PV/view -d '{"watchedMs":2000,"durationMs":5000}')"
check "view 204" 204 "$(code -X POST -H "$AB" -H "$H" $A/posts/$PV/view -d '{"watchedMs":2500,"durationMs":5000}')"
check "ayni kullanici tekrar 204 (sayilmaz)" 204 "$(code -X POST -H "$AB" -H "$H" $A/posts/$PV/view -d '{"watchedMs":5000,"durationMs":5000}')"
check "yazarin kendi izlenmesi 204 (sayilmaz)" 204 "$(code -X POST -H "$AA" -H "$H" $A/posts/$PV/view -d '{"watchedMs":5000,"durationMs":5000}')"
check "foto view 204 (sayilmaz)" 204 "$(code -X POST -H "$AB" -H "$H" $A/posts/$PP/view -d '{"watchedMs":5000,"durationMs":5000}')"
check "olmayan gonderi 404" 404 "$(code -X POST -H "$AB" -H "$H" $A/posts/99999999/view -d '{"watchedMs":2000,"durationMs":5000}')"
check "negatif sure 400" 400 "$(code -X POST -H "$AB" -H "$H" $A/posts/$PV/view -d '{"watchedMs":-1,"durationMs":5000}')"
has "viewCount=1" '"viewCount":1' "$(curl -s -H "$AB" $A/posts/$PV)"

echo "== populerlik puani (profil)"
ME=$(curl -s -H "$AA" $A/users/me)
has "ben: popularityScore" '"popularityScore":' "$ME"
has "ben: likesReceived" '"likesReceived":' "$ME"
has "ben: postCount" '"postCount":' "$ME"
UID_A=$(echo "$ME" | jid)
has "baskasinin profili: popularityScore" '"popularityScore":' "$(curl -s -H "$AB" $A/users/$UID_A)"

echo "== yonetici (istege bagli)"
if [ -n "${ADMIN_PASSWORD:-}" ]; then
  AD=$(curl -s -u "admin:$ADMIN_PASSWORD" "$A/admin/posts?type=VIDEO&size=5")
  has "admin type=VIDEO listesi" '"type":"VIDEO"' "$AD"
  has "admin viewCount" '"viewCount":' "$AD"
  check "admin gecersiz type 400" 400 "$(code -u "admin:$ADMIN_PASSWORD" "$A/admin/posts?type=GIF")"
  check "admin video onizleme Range 206" 206 "$(code -u "admin:$ADMIN_PASSWORD" -H 'Range: bytes=0-15' $A/admin/posts/media/$VID)"
else
  echo "  ATLA ADMIN_PASSWORD yok"
fi

echo "== temizlik"
check "video gonderi sil 204" 204 "$(code -X DELETE -H "$AA" $A/posts/$PV)"
check "foto gonderi sil 204" 204 "$(code -X DELETE -H "$AA" $A/posts/$PP)"
rm -rf "$TMPD"
[ "$FAIL" = 0 ] && echo "TAMAM" || { echo "BASARISIZ"; exit 1; }

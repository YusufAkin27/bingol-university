#!/usr/bin/env bash
# Kampus Forum A+B+C+D+E butunlesik duman testi (GERCEK PostgreSQL; H2'de calismaz).
# Akis: kayit (gmail: e-posta alan adi kisiti kalkti) -> konu -> yorum -> yanit -> begeni -> anket oyu -> arama ->
# tekrar-icerik engeli -> sikayet -> moderator (kaldir/geri al) -> anonimlik (mute anonimde uygulanmaz, engel uygulanir) ->
# profil/kaydedilenler (yorum ogesi) -> paylasim (sohbette FORUM_TOPIC karti) -> yonetim listeleri.
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=fsmadmin@gmail.com ./scripts/smoke-forum.sh
# Onkosul: compose'ta MAIL_ENABLED=false, ADMIN_EMAILS=$ADMIN_EMAIL (moderator icin), LEGAL_ENFORCE_REACCEPT=false.
# Tekrar calistirilabilir. Betikler arasinda: docker compose exec -T redis redis-cli flushall (kayit ucu IP basina saatte 10).
set -u
BASE=${BASE:-http://localhost:8080}
ADMIN_EMAIL=${ADMIN_EMAIL:-fsmadmin@gmail.com}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0

check() { # ad beklenen gercek
  if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi
}
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
jid() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
has() { grep -q -- "$1"; }
expect_has() { # ad metin govde
  if printf '%s' "$3" | grep -q -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(printf '%s' "$3" | cut -c1-300)"; FAIL=1; fi
}
expect_not() { # ad metin govde
  if printf '%s' "$3" | grep -q -- "$2"; then echo "  FAIL $1 (olmamaliydi: $2)"; FAIL=1; else echo "  ok   $1"; fi
}

register() { # email ad -> accessToken
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Zk7-Qmv-Lpx92w\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Zk7-Qmv-Lpx92w\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4
}
login() { # email -> accessToken (kayitli kullanici; yonetici tekrar calismada zaten kayitlidir)
  curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Zk7-Qmv-Lpx92w\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4
}
uid_of() { curl -s -H "Authorization: Bearer $1" $A/profile | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

SFX=$RANDOM$RANDOM
echo "== kayit (gmail adresleriyle: alan adi kisiti yok)"
TA=$(register "fsm$SFX.a@gmail.com" "Forum Yazar")
TB=$(register "fsm$SFX.b@gmail.com" "Forum Okur")
TC=$(register "fsm$SFX.c@gmail.com" "Forum Gizli")
[ -n "$TA" ] && [ -n "$TB" ] && [ -n "$TC" ] || { echo "kayit basarisiz (gmail kaydi kabul edilmedi mi?)"; exit 1; }
TM=$(register "$ADMIN_EMAIL" "Forum Moderator")
[ -n "$TM" ] || TM=$(login "$ADMIN_EMAIL")
[ -n "$TM" ] || { echo "moderator girisi basarisiz (ADMIN_EMAILS=$ADMIN_EMAIL ayarli mi?)"; exit 1; }
AA="Authorization: Bearer $TA"; AB="Authorization: Bearer $TB"; AC="Authorization: Bearer $TC"; AM="Authorization: Bearer $TM"
UA=$(uid_of "$TA"); UB=$(uid_of "$TB"); UC=$(uid_of "$TC")
[ -n "$UA" ] && [ -n "$UB" ] && [ -n "$UC" ] || { echo "kullanici kimligi okunamadi"; exit 1; }

CAT=$(curl -s -H "$AA" $A/forum/categories | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
[ -n "$CAT" ] || { echo "kategori yok (V1400 tohumu uygulandi mi?)"; exit 1; }
check "girissiz konu listesi 401" 401 "$(code $A/forum/topics)"

W1="kampusforum$SFX"
echo "== konu (anketli) + idempotency"
R1=$(curl -s -X POST -H "$AA" -H "$H" -H "Idempotency-Key: fsm-$SFX-1" $A/forum/topics \
  -d "{\"title\":\"Yurt $W1 sorusu\",\"body\":\"Yurtta ders calismak icin sessiz alan var mi $W1\",\"categoryId\":$CAT,\"anonymous\":false,\"imageIds\":[],\"poll\":{\"question\":\"Hangisi?\",\"options\":[\"Kutuphane\",\"Yurt\",\"Kafe\"],\"allowChangeVote\":true}}")
T1=$(echo "$R1" | jid)
[ -n "$T1" ] || { echo "  FAIL konu olusmadi: $R1"; exit 1; }
expect_has "konuda anket var" '"hasPoll":true' "$R1"
R1b=$(curl -s -X POST -H "$AA" -H "$H" -H "Idempotency-Key: fsm-$SFX-1" $A/forum/topics \
  -d "{\"title\":\"Yurt $W1 sorusu\",\"body\":\"Yurtta ders calismak icin sessiz alan var mi $W1\",\"categoryId\":$CAT,\"anonymous\":false,\"imageIds\":[],\"poll\":{\"question\":\"Hangisi?\",\"options\":[\"Kutuphane\",\"Yurt\",\"Kafe\"],\"allowChangeVote\":true}}")
check "ayni Idempotency-Key ayni konu" "$T1" "$(echo "$R1b" | jid)"
echo "== tekrar-icerik engeli (D ForumSpamGuard bagli)"
DUP=$(curl -s -w ' %{http_code}' -X POST -H "$AA" -H "$H" $A/forum/topics \
  -d "{\"title\":\"Yurt $W1 sorusu\",\"body\":\"Yurtta ders calismak icin sessiz alan var mi $W1\",\"categoryId\":$CAT,\"anonymous\":false,\"imageIds\":[]}")
check "ayni konu metni 429" 429 "${DUP##* }"
expect_has "hata kodu FORUM_DUPLICATE_CONTENT" 'FORUM_DUPLICATE_CONTENT' "$DUP"

echo "== yorum, yanit, begeni"
RC=$(curl -s -w ' %{http_code}' -X POST -H "$AB" -H "$H" $A/forum/topics/$T1/comments -d "{\"body\":\"Bence kutuphane $W1 en sakin yer\"}")
check "yorum 201" 201 "${RC##* }"
C1=$(echo "$RC" | jid)
RD=$(curl -s -w ' %{http_code}' -X POST -H "$AB" -H "$H" $A/forum/topics/$T1/comments -d "{\"body\":\"Bence kutuphane $W1 en sakin yer\"}")
check "ayni yorum metni 429 (D->B kancasi)" 429 "${RD##* }"
RR=$(curl -s -w ' %{http_code}' -X POST -H "$AA" -H "$H" $A/forum/topics/$T1/comments -d "{\"body\":\"Tesekkurler, deneyecegim\",\"parentCommentId\":$C1}")
check "yanit 201" 201 "${RR##* }"
C2=$(echo "$RR" | jid)
L=$(curl -s -X PUT -H "$AB" $A/forum/topics/$T1/like)
expect_has "konu begeni" '"liked":true' "$L"
L=$(curl -s -X PUT -H "$AA" $A/forum/comments/$C1/like)
expect_has "yorum begeni" '"liked":true' "$L"
CL=$(curl -s -H "$AB" "$A/forum/topics/$T1/comments")
expect_has "yorum listesinde yanit onizlemesi" "\"id\":$C2" "$CL"
curl -s -o /dev/null -X PUT -H "$AB" $A/forum/comments/$C1/bookmark
curl -s -o /dev/null -X PUT -H "$AB" $A/forum/topics/$T1/bookmark

echo "== anket"
TV=$(curl -s -H "$AB" $A/forum/topics/$T1)
OPT=$(echo "$TV" | grep -o '"options":\[{"id":[0-9]*' | grep -o '[0-9]*$')
[ -n "$OPT" ] || { echo "  FAIL anket secenegi okunamadi: $(echo "$TV" | cut -c1-300)"; OPT=0; FAIL=1; }
PV=$(curl -s -X PUT -H "$AB" -H "$H" $A/forum/topics/$T1/poll/vote -d "{\"optionId\":$OPT}")
expect_has "oy sayildi (totalVotes 1)" '"totalVotes":1' "$PV"
expect_has "myOptionId dolu" "\"myOptionId\":$OPT" "$PV"

echo "== arama (E; tsvector)"
sleep 1
S=$(curl -s -H "$AB" "$A/forum/search?q=$W1&sort=NEWEST")
expect_has "arama konuyu buldu" "\"id\":$T1" "$S"
SG=$(curl -s -H "$AB" "$A/forum/search?q=sakin&sort=NEWEST")
expect_has "yorum eslesmesi" '"matchedIn":"COMMENT"' "$SG"

echo "== profil: yorum ve kaydedilenler (E <- B adaptoru)"
P=$(curl -s -H "$AB" $A/forum/me/comments)
expect_has "me/comments yorum ogesi" "\"id\":$C1" "$P"
expect_has "me/comments topicTitle" '"topicTitle"' "$P"
P=$(curl -s -H "$AB" $A/forum/me/saved)
expect_has "me/saved yorum ogesi" '"type":"COMMENT"' "$P"
expect_has "me/saved konu ogesi" '"type":"TOPIC"' "$P"
expect_has "me/saved comment govdesi" "\"id\":$C1" "$P"
P=$(curl -s -H "$AC" $A/forum/users/$UB/comments)
expect_has "baskasinin yorumlari" "\"id\":$C1" "$P"

echo "== bildirimler"
N=$(curl -s -H "$AA" $A/notifications)
expect_has "konu sahibine yorum bildirimi" 'FORUM_TOPIC_COMMENT' "$N"
NB=$(curl -s -H "$AB" $A/notifications)
expect_has "yorum sahibine yanit bildirimi" 'FORUM_COMMENT_REPLY' "$NB"

echo "== sikayet + moderator"
RP=$(curl -s -w ' %{http_code}' -X POST -H "$AB" -H "$H" $A/reports -d "{\"targetType\":\"FORUM_TOPIC\",\"targetId\":$T1,\"reason\":\"SPAM\"}")
check "forum konusu sikayeti 201" 201 "${RP##* }"
check "kullanici moderator degil 403" 403 "$(code -X POST -H "$AB" -H "$H" $A/forum/topics/$T1/moderate -d '{"action":"LOCK"}')"
check "moderator: sabitle 200" 200 "$(code -X POST -H "$AM" -H "$H" $A/forum/topics/$T1/moderate -d '{"action":"PIN","reason":"duman"}')"
check "moderator: kilitle 200" 200 "$(code -X POST -H "$AM" -H "$H" $A/forum/topics/$T1/moderate -d '{"action":"LOCK","reason":"duman"}')"
check "kilitli konuya yorum 409" 409 "$(code -X POST -H "$AB" -H "$H" $A/forum/topics/$T1/comments -d '{"body":"kilitliyken yazi"}')"
check "moderator: kilidi ac 200" 200 "$(code -X POST -H "$AM" -H "$H" $A/forum/topics/$T1/moderate -d '{"action":"UNLOCK","reason":"duman"}')"
check "moderator: yorumu kaldir (B durum servisi) 200" 200 "$(code -X POST -H "$AM" -H "$H" $A/forum/comments/$C2/moderate -d '{"action":"REMOVE","reason":"duman testi"}')"
CL=$(curl -s -H "$AB" "$A/forum/topics/$T1/comments")
expect_not "kaldirilan yorum listede yok" "\"id\":$C2," "$CL"
check "moderator: yorumu geri al 200" 200 "$(code -X POST -H "$AM" -H "$H" $A/forum/comments/$C2/moderate -d '{"action":"RESTORE","reason":"duman testi"}')"
check "moderator: konuyu kaldir 200" 200 "$(code -X POST -H "$AM" -H "$H" $A/forum/topics/$T1/moderate -d '{"action":"REMOVE","reason":"duman testi"}')"
check "kaldirilan konu 404" 404 "$(code -H "$AB" $A/forum/topics/$T1)"
check "moderator: konuyu geri al 200" 200 "$(code -X POST -H "$AM" -H "$H" $A/forum/topics/$T1/moderate -d '{"action":"RESTORE","reason":"duman testi"}')"
check "geri acilan konu 200" 200 "$(code -H "$AB" $A/forum/topics/$T1)"
TVM=$(curl -s -H "$AM" $A/forum/topics/$T1)
expect_has "moderatore canModerate true (ForumPermissions<->PermissionMatrix)" '"canModerate":true' "$TVM"
expect_has "okura canModerate false" '"canModerate":false' "$(curl -s -H "$AB" $A/forum/topics/$T1)"
AR=$(curl -s -H "$AM" "$A/admin/forum/reports?status=OPEN")
expect_has "yonetici sikayet kuyrugu konuyu gosterir" "\"targetId\":$T1" "$AR"
AT=$(curl -s -H "$AM" "$A/admin/forum/topics?q=$W1")
expect_has "yonetici konu listesi" "\"id\":$T1" "$AT"
AX=$(curl -s -H "$AM" "$A/admin/forum/actions")
expect_has "islem kayitlari" '"action":"REMOVE"' "$AX"
check "yonetici kategoriler 200" 200 "$(code -H "$AM" $A/admin/forum/categories)"
check "kullanici yonetici ucu 403" 403 "$(code -H "$AB" $A/admin/forum/topics)"
RS=$(curl -s -w ' %{http_code}' -X POST -H "$AM" -H "$H" $A/admin/forum/reports/$(echo "$AR" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)/resolve -d '{"action":"DISMISS","message":"duman testi"}')
check "sikayet coz 200" 200 "${RS##* }"

echo "== anonimlik: mute anonimde uygulanmaz, engel uygulanir"
R2=$(curl -s -X POST -H "$AC" -H "$H" -H "Idempotency-Key: fsm-$SFX-2" $A/forum/topics \
  -d "{\"title\":\"Anonim $W1 itirafi\",\"body\":\"Gizli konu icerigi $W1\",\"categoryId\":$CAT,\"anonymous\":true,\"imageIds\":[]}")
T2=$(echo "$R2" | jid)
[ -n "$T2" ] || { echo "  FAIL anonim konu olusmadi: $R2"; exit 1; }
R3=$(curl -s -X POST -H "$AC" -H "$H" -H "Idempotency-Key: fsm-$SFX-3" $A/forum/topics \
  -d "{\"title\":\"Acik $W1 gonderisi\",\"body\":\"Acik konu icerigi baska $W1\",\"categoryId\":$CAT,\"anonymous\":false,\"imageIds\":[]}")
T3=$(echo "$R3" | jid)
[ -n "$T3" ] || { echo "  FAIL acik konu olusmadi: $R3"; exit 1; }
curl -s -o /dev/null -X POST -H "$AC" -H "$H" $A/forum/topics/$T1/comments -d "{\"body\":\"gizli yorumcu mesaji $W1\",\"anonymous\":true}"
TV2=$(curl -s -H "$AB" $A/forum/topics/$T2)
expect_not "anonim konuda yazar kimligi yok" "\"userId\":$UC" "$TV2"
expect_not "anonim konuda gercek ad yok" 'Forum Gizli' "$TV2"
check "B, C'yi sessize al" 200 "$(code -X PUT -H "$AB" $A/forum/mutes/$UC)"
FEED=$(curl -s -H "$AB" "$A/forum/topics?sort=NEWEST&size=30")
expect_has "sessize alinanin ANONIM konusu hala gorunur" "\"id\":$T2" "$FEED"
expect_not "sessize alinanin ACIK konusu gizli" "\"id\":$T3," "$FEED"
S=$(curl -s -H "$AB" "$A/forum/search?q=$W1&sort=NEWEST")
expect_has "arama: anonim konu (mute uygulanmaz)" "\"id\":$T2" "$S"
expect_not "arama: acik konu gizli (mute)" "\"id\":$T3," "$S"
CL=$(curl -s -H "$AB" "$A/forum/topics/$T1/comments?size=30")
expect_has "sessize alinanin anonim yorumu gorunur" 'gizli yorumcu mesaji' "$CL"
M=$(curl -s -H "$AB" $A/forum/mutes)
expect_has "mutes listesi" "\"userId\":$UC" "$M"
check "mute kaldir" 200 "$(code -X DELETE -H "$AB" $A/forum/mutes/$UC)"
check "B: anonim konunun yazarini engelle 200" 200 "$(code -X POST -H "$AB" $A/forum/topics/$T2/block-author)"
FEED=$(curl -s -H "$AB" "$A/forum/topics?sort=NEWEST&size=30")
expect_not "engel: anonim konu da gizli" "\"id\":$T2," "$FEED"
expect_not "engel: acik konu da gizli" "\"id\":$T3," "$FEED"
curl -s -o /dev/null -X DELETE -H "$AB" $A/users/$UC/block

echo "== paylasim (sohbette forum konusu karti)"
CV=$(curl -s -X POST -H "$H" -H "$AB" $A/conversations -d "{\"userId\":$UA}")
CID=$(echo "$CV" | jid)
if [ -n "$CID" ]; then
  SM=$(curl -s -w ' %{http_code}' -X POST -H "$H" -H "$AB" $A/conversations/$CID/messages -d "{\"clientId\":\"fsm-$SFX\",\"share\":{\"type\":\"FORUM_TOPIC\",\"id\":$T1}}")
  check "FORUM_TOPIC paylasimi 201" 201 "${SM##* }"
  expect_has "paylasim karti" '"type":"FORUM_TOPIC"' "$SM"
  expect_has "paylasim available" '"available":true' "$SM"
  SM=$(curl -s -w ' %{http_code}' -X POST -H "$H" -H "$AB" $A/conversations/$CID/messages -d "{\"clientId\":\"fsm-$SFX-c\",\"share\":{\"type\":\"FORUM_COMMENT\",\"id\":$C1}}")
  check "FORUM_COMMENT paylasimi 201" 201 "${SM##* }"
else
  echo "  FAIL sohbet olusmadi: $CV"; FAIL=1
fi
PG=$(curl -s "$BASE/s/f/$T1")
expect_has "OG sayfasi baslik" "$W1" "$PG"

echo "== konu silme"
check "konu sil 204" 204 "$(code -X DELETE -H "$AA" $A/forum/topics/$T1)"
check "silinen konu 404" 404 "$(code -H "$AB" $A/forum/topics/$T1)"

if [ "$FAIL" = 0 ]; then echo "TUMU TAMAM"; exit 0; else echo "BASARISIZ"; exit 1; fi

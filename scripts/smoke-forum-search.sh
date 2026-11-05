#!/usr/bin/env bash
# Kampus Forum E alani duman testi: arama (PostgreSQL tsvector), profil listeleri, bildirim tercihleri ve bildirimler,
# paylasim sayfasi, anonimlik sizintisi. GERCEK PostgreSQL gerekir (search_vec V1442; H2'de calismaz).
# Kullanim: BASE=http://localhost:8080 ./scripts/smoke-forum-search.sh
# Onkosul: compose'ta MAIL_ENABLED=false (dogrulama kodu log'dan okunur); A+B (konu/yorum) ve E birlesmis surum.
# Betik tekrar calistirilabilir. Betikler arasinda: docker compose exec -T redis redis-cli flushall (kayit ucu IP basina saatte 10).
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
has() { grep -q -- "$1"; }
expect_has() { # ad metin govde
  if printf '%s' "$3" | grep -q -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(printf '%s' "$3" | cut -c1-300)"; FAIL=1; fi
}
expect_not() { # ad metin govde
  if printf '%s' "$3" | grep -q -- "$2"; then echo "  FAIL $1 (olmamaliydi: $2)"; FAIL=1; else echo "  ok   $1"; fi
}

register() { # email ad
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Zk7-Qmv-Lpx92w\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Zk7-Qmv-Lpx92w\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4
}
uid_of() { curl -s -H "Authorization: Bearer $1" $A/profile | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

SFX=$RANDOM
TA=$(register "fsa$SFX@bingol.edu.tr" "Forum Yazar")
TB=$(register "fsb$SFX@bingol.edu.tr" "Forum Okur")
TC=$(register "fsc$SFX@bingol.edu.tr" "Forum Gizli")
[ -n "$TA" ] && [ -n "$TB" ] && [ -n "$TC" ] || { echo "kayit basarisiz"; exit 1; }
AA="Authorization: Bearer $TA"
AB="Authorization: Bearer $TB"
AC="Authorization: Bearer $TC"
UA=$(uid_of "$TA"); UB=$(uid_of "$TB")

CAT=$(curl -s -H "$AA" $A/forum/categories | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
[ -n "$CAT" ] || { echo "kategori yok (A migration'i uygulandi mi?)"; exit 1; }

W1="zeytinkoftesi$SFX"   # baslik kelimesi
W2="mercimekdolmasi$SFX" # govde kelimesi
W3="havucturusu$SFX"     # yorum kelimesi
W4="gizlisoz$SFX"        # anonim yorum kelimesi

echo "== girisiz ve gecersiz istekler"
check "girissiz arama 401" 401 "$(code "$A/forum/search?q=yemek")"
check "kisa sorgu 400" 400 "$(code -H "$AB" "$A/forum/search?q=a")"
check "bos sorgu 400" 400 "$(code -H "$AB" "$A/forum/search")"
check "gecersiz sort 400" 400 "$(code -H "$AB" "$A/forum/search?q=yemek&sort=DROP")"
curl -s -H "$AB" "$A/forum/search?q=a" | has 'FORUM_SEARCH_QUERY_TOO_SHORT' && echo "  ok   hata kodu" || { echo "  FAIL hata kodu"; FAIL=1; }

echo "== konu ve yorumlar"
R1=$(curl -s -X POST -H "$AA" -H "$H" -H "Idempotency-Key: fs-$SFX-1" $A/forum/topics \
  -d "{\"title\":\"Bugun $W1 var mi\",\"body\":\"Ogle yemegi hakkinda $W2 konusuyor\",\"categoryId\":$CAT,\"anonymous\":false,\"imageIds\":[]}")
T1=$(echo "$R1" | jid)
[ -n "$T1" ] || { echo "  FAIL konu olusmadi: $R1"; exit 1; }
R2=$(curl -s -X POST -H "$AC" -H "$H" -H "Idempotency-Key: fs-$SFX-2" $A/forum/topics \
  -d "{\"title\":\"Anonim $W1 itirafi\",\"body\":\"Gizli bir konu $W2\",\"categoryId\":$CAT,\"anonymous\":true,\"imageIds\":[]}")
T2=$(echo "$R2" | jid)
[ -n "$T2" ] || { echo "  FAIL anonim konu olusmadi: $R2"; exit 1; }
curl -s -o /dev/null -X POST -H "$AB" -H "$H" $A/forum/topics/$T1/comments -d "{\"body\":\"Bence $W3 daha guzel\"}"
curl -s -o /dev/null -X POST -H "$AC" -H "$H" $A/forum/topics/$T1/comments -d "{\"body\":\"Ben bir $W4 soylerim\",\"anonymous\":true}"
sleep 1

echo "== arama: baslik / govde / yorum eslesmesi"
S=$(curl -s -H "$AB" "$A/forum/search?q=$W1&sort=NEWEST")
expect_has "baslik eslesmesi" "\"matchedIn\":\"TITLE\"" "$S"
expect_has "konu bulundu" "\"id\":$T1" "$S"
expect_has "TopicSummary alanlari duz (likeCount)" '"likeCount"' "$S"
S=$(curl -s -H "$AB" "$A/forum/search?q=$W2")
expect_has "govde eslesmesi" "\"matchedIn\":\"BODY\"" "$S"
expect_has "snippet var" '"snippet":"' "$S"
S=$(curl -s -H "$AB" "$A/forum/search?q=$W3")
expect_has "yorum eslesmesi" "\"matchedIn\":\"COMMENT\"" "$S"
S=$(curl -s -H "$AB" "$A/forum/search?q=$W4")
expect_not "anonim yorum aramada YOK" "\"id\":$T1" "$S"
S=$(curl -s -H "$AB" "$A/forum/search?q=${W1:0:8}&sort=NEWEST")
expect_has "kismi kelime (baslik trigram)" "\"id\":$T1" "$S"
S=$(curl -s -H "$AB" "$A/forum/search?q=$W1&categoryId=$CAT")
expect_has "kategori suzgeci" "\"id\":$T1" "$S"
S=$(curl -s -H "$AB" "$A/forum/search?q=$W1&categoryId=999999999")
expect_not "baska kategori bos" "\"id\":$T1" "$S"
check "LIKE kacisi (yuzde) 200" 200 "$(code -H "$AB" "$A/forum/search?q=%25_%25")"
check "popular 200" 200 "$(code -H "$AB" $A/forum/search/popular)"

echo "== anonimlik: arama ve profilde kimlik sizmaz"
S=$(curl -s -H "$AB" "$A/forum/search?q=$W1&sort=NEWEST")
expect_has "anonim konu aramada" "\"id\":$T2" "$S"
expect_not "anonim konuda gercek ad yok" 'Forum Gizli' "$S"
UC=$(uid_of "$TC")
P=$(curl -s -H "$AB" "$A/forum/users/$UC/topics")
expect_not "baskasinin profilinde anonim konu YOK" "\"id\":$T2" "$P"
P=$(curl -s -H "$AB" "$A/forum/users/$UC/comments")
expect_not "baskasinin profilinde anonim yorum YOK" "$W4" "$P"
P=$(curl -s -H "$AB" "$A/forum/users/$UC/summary")
expect_has "ozet anonimsiz sayim (0/0)" '"topicCount":0' "$P"
P=$(curl -s -H "$AC" "$A/forum/me/topics")
expect_has "kendi listemde anonim konu VAR" "\"id\":$T2" "$P"
P=$(curl -s -H "$AB" "$A/forum/users/$UA/topics")
expect_has "baskasinin acik konusu listelenir" "\"id\":$T1" "$P"
P=$(curl -s -H "$AB" "$A/forum/me/comments")
expect_has "kendi yorumlarim" "$W3" "$P"
check "me/saved 200" 200 "$(code -H "$AB" $A/forum/me/saved)"
check "me/following 200" 200 "$(code -H "$AB" $A/forum/me/following)"

echo "== bildirimler (konu sahibine yorum, kendine yok, begeni tek, anonim ad)"
N=$(curl -s -H "$AA" $A/notifications)
expect_has "konu sahibine FORUM bildirimi" 'FORUM_TOPIC_COMMENT' "$N"
expect_has "anonim yorumcu Anonim # olarak" 'Anonim #' "$N"
expect_not "bildirimde gercek ad (anonim)" 'Forum Gizli' "$N"
curl -s -o /dev/null -X POST -H "$AA" -H "$H" $A/forum/topics/$T1/comments -d "{\"body\":\"kendi konuma yorum\"}"
sleep 1
curl -s -o /dev/null -X PUT -H "$AB" $A/forum/topics/$T1/like
curl -s -o /dev/null -X DELETE -H "$AB" $A/forum/topics/$T1/like
curl -s -o /dev/null -X PUT -H "$AB" $A/forum/topics/$T1/like
sleep 1
N=$(curl -s -H "$AA" $A/notifications)
CNT=$(printf '%s' "$N" | grep -o 'FORUM_TOPIC_LIKE' | wc -l | tr -d ' ')
check "al-ver-al tek begeni bildirimi" 1 "$CNT"
NB=$(curl -s -H "$AB" $A/notifications)
expect_not "kendi yorumum icin kendime bildirim yok" 'FORUM_TOPIC_COMMENT' "$NB"

echo "== bildirim tercihleri"
check "tercih GET 200" 200 "$(code -H "$AA" $A/forum/notification-prefs)"
P=$(curl -s -X PUT -H "$AA" -H "$H" $A/forum/notification-prefs -d '{"likes":false}')
expect_has "likes kapandi" '"likes":false' "$P"
expect_has "digerleri acik" '"topicComments":true' "$P"
curl -s -o /dev/null -X PUT -H "$AB" $A/forum/topics/$T2/like
P=$(curl -s -X PUT -H "$AA" -H "$H" $A/forum/notification-prefs -d '{"all":true,"likes":true}')
expect_has "geri acildi" '"likes":true' "$P"
check "girissiz tercih 401" 401 "$(code $A/forum/notification-prefs)"

echo "== engel: engelleyenin aramasinda yazar yok"
check "B, A'yi engelle 204/200" 1 "$( [ "$(code -X POST -H "$AB" $A/users/$UA/block)" -lt 300 ] && echo 1 || echo 0 )"
S=$(curl -s -H "$AB" "$A/forum/search?q=$W1&sort=NEWEST")
expect_not "engellenen yazarin konusu aramada yok" "\"id\":$T1" "$S"
curl -s -o /dev/null -X DELETE -H "$AB" $A/users/$UA/block

echo "== paylasim sayfasi"
PG=$(curl -s "$BASE/s/f/$T1")
expect_has "OG baslik (konu)" "$W1" "$PG"
PG2=$(curl -s "$BASE/s/f/$T2")
expect_has "anonim konu sayfasi: Anonim" 'Anonim' "$PG2"
expect_not "anonim konu sayfasinda gercek ad yok" 'Forum Gizli' "$PG2"
check "bilinmeyen konu notr sayfa 200" 200 "$(code "$BASE/s/f/999999999")"
check "yorum sayfasi 200" 200 "$(code "$BASE/s/fc/1")"

echo "== silinen konu aramadan ve paylasimdan duser"
check "konu sil 204" 204 "$(code -X DELETE -H "$AA" $A/forum/topics/$T1)"
sleep 1
S=$(curl -s -H "$AB" "$A/forum/search?q=$W1&sort=NEWEST")
expect_not "silinen konu aramada yok" "\"id\":$T1" "$S"
PG=$(curl -s "$BASE/s/f/$T1")
expect_not "silinen konu OG'de yok" "$W1" "$PG"

if [ "$FAIL" = 0 ]; then echo "TUMU TAMAM"; exit 0; else echo "BASARISIZ"; exit 1; fi

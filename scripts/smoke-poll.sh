#!/usr/bin/env bash
# Anket ve oylama icin uctan uca duman testi (gercek PostgreSQL gerekir: SKIP LOCKED/kilit, sayaclar, kismi indeksler).
# Kullanim: ADMIN_EMAIL=boss@bingol.edu.tr BASE=http://localhost:8080 ./scripts/smoke-poll.sh
# Onkosul: compose'ta MAIL_ENABLED=false (dogrulama kodu log'dan okunur) ve ADMIN_EMAILS=$ADMIN_EMAIL (smoke-admin.sh ile ayni).
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
has() { grep -q "$1"; }

register() { # email ad
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4
}

SFX=$RANDOM
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
TAD=$(register "$ADMIN_EMAIL" "Yonetici")
if [ -z "$TAD" ]; then
  TAD=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
fi
[ -n "$TAD" ] || { echo "yonetici token yok (ADMIN_EMAILS ayarli mi?)"; exit 1; }
TA=$(register "polla$SFX@bingol.edu.tr" "Oy Veren A")
TB=$(register "pollb$SFX@bingol.edu.tr" "Oy Veren B")
TC=$(register "pollc$SFX@bingol.edu.tr" "Oy Veren C")
[ -n "$TA" ] && [ -n "$TB" ] && [ -n "$TC" ] || { echo "kayit basarisiz"; exit 1; }
AD="Authorization: Bearer $TAD"
AA="Authorization: Bearer $TA"
AB="Authorization: Bearer $TB"
AC="Authorization: Bearer $TC"
CLOSES=$(date -u -d '+2 days' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v+2d +%Y-%m-%dT%H:%M:%SZ)

echo "== olusturma ve yetki"
check "girissiz 401" 401 "$(code $A/polls)"
BODY="{\"title\":\"Smoke anketi $SFX\",\"description\":\"aciklama\",\"type\":\"SINGLE\",\"scope\":\"GLOBAL\",\"options\":[\"Evet\",\"Hayir\",\"Belki\"],\"closesAt\":\"$CLOSES\",\"showResults\":\"ALWAYS\"}"
check "kullanici genel anket olusturamaz 403" 403 "$(code -X POST -H "$AA" -H "$H" $A/polls -d "$BODY")"
R=$(curl -s -X POST -H "$AD" -H "$H" $A/polls -d "$BODY")
PID=$(echo "$R" | jid)
[ -n "$PID" ] || { echo "  FAIL anket olusmadi: $R"; exit 1; }
echo "$R" | has '"status":"OPEN"' && echo "  ok   OPEN" || { echo "  FAIL durum: $R"; FAIL=1; }
OPT1=$(echo "$R" | grep -o '"options":\[{"id":[0-9]*' | grep -o '[0-9]*$')
OPT2=$(echo "$R" | grep -o '"id":[0-9]*,"text":"Hayir"' | grep -o '[0-9]*' | head -1)
check "tek secenek 400" 400 "$(code -X POST -H "$AD" -H "$H" $A/polls -d '{"title":"x","options":["tek"]}')"
check "gecmis kapanis 400" 400 "$(code -X POST -H "$AD" -H "$H" $A/polls -d '{"title":"x","options":["a","b"],"closesAt":"2001-01-01T00:00:00Z"}')"

echo "== oy verme (idempotent, degistirme, geri cekme)"
check "oy 200" 200 "$(code -X POST -H "$AA" -H "$H" $A/polls/$PID/vote -d "{\"optionIds\":[$OPT1]}")"
check "ayni oy tekrar 200" 200 "$(code -X POST -H "$AA" -H "$H" $A/polls/$PID/vote -d "{\"optionIds\":[$OPT1]}")"
V=$(curl -s -H "$AA" $A/polls/$PID)
echo "$V" | has '"totalVotes":1' && echo "  ok   tek oy sayildi" || { echo "  FAIL totalVotes: $V"; FAIL=1; }
check "oy degistir 200" 200 "$(code -X POST -H "$AA" -H "$H" $A/polls/$PID/vote -d "{\"optionIds\":[$OPT2]}")"
curl -s -H "$AB" $A/polls/$PID | has '"totalVotes":1' && echo "  ok   degisiklikte toplam sabit" || { echo "  FAIL degistirme sayaci"; FAIL=1; }
check "gecersiz secenek 400" 400 "$(code -X POST -H "$AB" -H "$H" $A/polls/$PID/vote -d '{"optionIds":[999999999]}')"
check "oy geri cek 200" 200 "$(code -X DELETE -H "$AA" $A/polls/$PID/vote)"
curl -s -H "$AB" $A/polls/$PID | has '"totalVotes":0' && echo "  ok   geri cekildi" || { echo "  FAIL geri cekme"; FAIL=1; }
check "olmayan anket 404" 404 "$(code -H "$AA" $A/polls/999999999)"

echo "== es zamanli oy (yaris): ayni kullanici 10 istek"
curl -s -o /dev/null -X POST -H "$AB" -H "$H" $A/polls/$PID/vote -d "{\"optionIds\":[$OPT1]}"
for i in 1 2 3 4 5 6 7 8 9 10; do
  curl -s -o /dev/null -X POST -H "$AC" -H "$H" $A/polls/$PID/vote -d "{\"optionIds\":[$OPT1]}" &
done
wait
curl -s -H "$AD" $A/admin/polls/$PID | has '"totalVotes":2' && echo "  ok   cift oy yok (B + C = 2)" || { echo "  FAIL yaris: $(curl -s -H "$AD" $A/admin/polls/$PID)"; FAIL=1; }

echo "== gizli oy / oy degistirme kapali"
R2=$(curl -s -X POST -H "$AD" -H "$H" $A/polls -d "{\"title\":\"Gizli $SFX\",\"options\":[\"X\",\"Y\"],\"anonymous\":true,\"allowChangeVote\":false,\"showResults\":\"AFTER_CLOSE\",\"closesAt\":\"$CLOSES\"}")
P2=$(echo "$R2" | jid)
X=$(echo "$R2" | grep -o '"options":\[{"id":[0-9]*' | grep -o '[0-9]*$')
check "gizli oy 200" 200 "$(code -X POST -H "$AA" -H "$H" $A/polls/$P2/vote -d "{\"optionIds\":[$X]}")"
check "degistirme kapali 409" 409 "$(code -X POST -H "$AA" -H "$H" $A/polls/$P2/vote -d "{\"optionIds\":[$((X + 1))]}")"
curl -s -H "$AA" $A/polls/$P2 | has '"resultsVisible":false' && echo "  ok   kapanmadan sonuc gizli" || { echo "  FAIL sonuc gorunurlugu"; FAIL=1; }
curl -s -H "$AD" $A/admin/polls/$P2/export.csv | has 'optionId,text,count' && echo "  ok   CSV (kimliksiz)" || { echo "  FAIL CSV"; FAIL=1; }
check "yonetici kapatir" 200 "$(code -X POST -H "$AD" $A/admin/polls/$P2/close)"
check "kapali ankete oy 409" 409 "$(code -X POST -H "$AB" -H "$H" $A/polls/$P2/vote -d "{\"optionIds\":[$X]}")"
curl -s -H "$AB" $A/polls/$P2 | has '"resultsVisible":true' && echo "  ok   kapaninca sonuc acik" || { echo "  FAIL kapanis sonucu"; FAIL=1; }

echo "== puanlama (RATING) ve menu anketi"
R3=$(curl -s -X POST -H "$AD" -H "$H" $A/polls -d "{\"title\":\"Puan $SFX\",\"type\":\"RATING\",\"closesAt\":\"$CLOSES\"}")
P3=$(echo "$R3" | jid)
check "puan 200" 200 "$(code -X POST -H "$AA" -H "$H" $A/polls/$P3/vote -d '{"rating":4}')"
check "puan disi 400" 400 "$(code -X POST -H "$AA" -H "$H" $A/polls/$P3/vote -d '{"rating":9}')"
curl -s -H "$AA" $A/polls/$P3 | has '"average":4.0' && echo "  ok   ortalama puan" || { echo "  FAIL ortalama"; FAIL=1; }
MC=$(code -H "$AA" $A/polls/menu/today)
if [ "$MC" = "204" ]; then echo "  ok   bugun yemek listesi yok -> 204"; else check "menu anketi 200" 200 "$MC"; fi

echo "== listeleme ve yonetici"
curl -s -H "$AB" "$A/polls?scope=open&size=50" | has "\"id\":$PID," && echo "  ok   acik listede" || { echo "  FAIL open listesi"; FAIL=1; }
curl -s -H "$AB" "$A/polls?scope=mine" | has "\"id\":$PID," && echo "  ok   mine (oy verdigim)" || { echo "  FAIL mine"; FAIL=1; }
curl -s -H "$AB" "$A/polls?scope=closed" | has "\"id\":$P2," && echo "  ok   closed listesi" || { echo "  FAIL closed"; FAIL=1; }
check "gecersiz scope 400" 400 "$(code -H "$AB" "$A/polls?scope=xx")"
check "kullanici admin ucu 403" 403 "$(code -H "$AB" $A/admin/polls)"
check "admin liste 200" 200 "$(code -H "$AD" "$A/admin/polls?status=OPEN")"
check "admin istatistik 200" 200 "$(code -H "$AD" $A/admin/polls/stats)"
BULK=$(curl -s -X POST -H "$AD" -H "$H" $A/admin/polls/bulk -d "{\"ids\":[$P3],\"action\":\"CANCEL\"}")
echo "$BULK" | has '"done":1' && echo "  ok   toplu iptal" || { echo "  FAIL bulk: $BULK"; FAIL=1; }
check "iptal edilene oy 409" 409 "$(code -X POST -H "$AB" -H "$H" $A/polls/$P3/vote -d '{"rating":3}')"

echo "== KVKK disa aktarim"
EX=$(curl -s -H "$AA" $A/users/me/export)
echo "$EX" | has '"polls"' && echo "  ok   export polls bolumu" || { echo "  FAIL export"; FAIL=1; }
curl -s -H "$AB" $A/users/me/export | grep -q 'Gizli' && { echo "  FAIL baskasinin gizli oyu B dosyasinda"; FAIL=1; } || echo "  ok   baskasinin gizli oyu yok"

echo "== temizlik"
check "anket sil 204" 204 "$(code -X DELETE -H "$AD" $A/polls/$PID)"
check "silinen 404" 404 "$(code -H "$AA" $A/polls/$PID)"
curl -s -o /dev/null -X DELETE -H "$AD" $A/admin/polls/$P2
curl -s -o /dev/null -X DELETE -H "$AD" $A/admin/polls/$P3

[ $FAIL -eq 0 ] && echo "TUMU GECTI" || echo "HATA VAR"
exit $FAIL

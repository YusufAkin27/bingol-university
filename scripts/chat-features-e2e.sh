#!/usr/bin/env bash
# T13 sohbet ozellikleri icin uctan uca betik (yanit, duzenleme, silme, tepki, okunmamis, sessize alma, arsiv).
# Kullanim: BASE=http://localhost:8080 ./scripts/chat-features-e2e.sh
# Onkosul: compose'ta MAIL_ENABLED=false (dogrulama kodu log'dan okunur). Her calistirmada yeni kullanicilar uretir.
# ASCII; tekrar calistirilabilir. Betikler arasi: docker compose exec -T redis redis-cli flushall (kayit ucu limiti).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0
THUMBS='👍'
POO='💩'

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
jget() { grep -o "\"$1\":[^,}]*" | head -1 | cut -d: -f2- | tr -d '"'; }

register() {
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c t
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  t=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  [ -n "$t" ] || t=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  echo "$t"
}

SFX=$RANDOM
echo "== kullanicilar"
T1=$(register "cfa$SFX@bingol.edu.tr" "Sohbet Ali"); T2=$(register "cfb$SFX@bingol.edu.tr" "Sohbet Ayse")
T3=$(register "cfc$SFX@bingol.edu.tr" "Sohbet Can")
[ -n "$T1" ] && [ -n "$T2" ] && [ -n "$T3" ] || { echo "kayit basarisiz"; exit 1; }
AUTH1="Authorization: Bearer $T1"; AUTH2="Authorization: Bearer $T2"; AUTH3="Authorization: Bearer $T3"
ID1=$(curl -s -H "$AUTH1" $A/users/me | idof); ID2=$(curl -s -H "$AUTH2" $A/users/me | idof)
ID3=$(curl -s -H "$AUTH3" $A/users/me | idof)

CID=$(curl -s -X POST -H "$H" -H "$AUTH1" $A/conversations -d "{\"userId\":$ID2}" | idof)
M1=$(curl -s -X POST -H "$H" -H "$AUTH1" $A/conversations/$CID/messages -d '{"text":"ilk mesaj","clientId":"cf-1"}' | idof)
check "mesaj 1 olustu" yes "$([ -n "$M1" ] && echo yes)"

echo "== yanitlama"
R=$(curl -s -w ' %{http_code}' -X POST -H "$H" -H "$AUTH2" $A/conversations/$CID/messages -d "{\"text\":\"yanit\",\"clientId\":\"cf-2\",\"replyToMessageId\":$M1}")
check "yanit 201" 201 "${R##* }"
M2=$(echo "$R" | idof)
check "onizleme metni" "ilk mesaj" "$(echo "$R" | grep -o '"replyTo":{[^}]*}' | grep -o '"text":"[^"]*' | cut -d'"' -f4)"
check "baska konusmaya ait yanit 404" 404 "$(code -X POST -H "$H" -H "$AUTH1" $A/conversations/$CID/messages -d '{"text":"x","clientId":"cf-x","replyToMessageId":99999999}')"

echo "== duzenleme"
check "baskasi duzenleyemez 403" 403 "$(code -X PATCH -H "$H" -H "$AUTH2" $A/messages/$M1 -d '{"text":"hack"}')"
R=$(curl -s -w ' %{http_code}' -X PATCH -H "$H" -H "$AUTH1" $A/messages/$M1 -d '{"text":"duzenlendi"}')
check "gonderen duzenler 200" 200 "${R##* }"
check "edited bayragi" true "$(echo "$R" | jget edited)"
check "bos metin 400" 400 "$(code -X PATCH -H "$H" -H "$AUTH1" $A/messages/$M1 -d '{"text":"   "}')"
check "uye olmayan 404" 404 "$(code -X PATCH -H "$H" -H "$AUTH3" $A/messages/$M1 -d '{"text":"x"}')"
check "gecmiste duzenlenmis metin" duzenlendi "$(curl -s -H "$AUTH2" "$A/conversations/$CID/messages?size=10" | grep -o '"text":"duzenlendi"' | head -1 | cut -d'"' -f4)"

echo "== tepkiler"
check "izinsiz emoji 400" 400 "$(code -X PUT -H "$H" -H "$AUTH2" $A/messages/$M1/reaction -d "{\"emoji\":\"$POO\"}")"
R=$(curl -s -w ' %{http_code}' -X PUT -H "$H" -H "$AUTH2" $A/messages/$M1/reaction -d "{\"emoji\":\"$THUMBS\"}")
check "tepki 200" 200 "${R##* }"
check "sayac 1" 1 "$(echo "$R" | grep -o '"count":[0-9]*' | head -1 | cut -d: -f2)"
curl -s -o /dev/null -X PUT -H "$H" -H "$AUTH1" $A/messages/$M1/reaction -d "{\"emoji\":\"$THUMBS\"}"
R=$(curl -s -X PUT -H "$H" -H "$AUTH2" $A/messages/$M1/reaction -d "{\"emoji\":\"$THUMBS\"}")
check "ayni tepki tekrar: sayac 2 (1 kullanici 1 tepki)" 2 "$(echo "$R" | grep -o '"count":[0-9]*' | head -1 | cut -d: -f2)"
check "uye olmayan tepki 404" 404 "$(code -X PUT -H "$H" -H "$AUTH3" $A/messages/$M1/reaction -d "{\"emoji\":\"$THUMBS\"}")"
check "tepki kaldir 200" 200 "$(code -X DELETE -H "$AUTH2" $A/messages/$M1/reaction)"
check "izinli emoji listesi" 200 "$(code -H "$AUTH1" $A/messages/reactions)"

echo "== okunmamis sayaci"
curl -s -o /dev/null -X POST -H "$H" -H "$AUTH1" $A/conversations/$CID/messages -d '{"text":"uc","clientId":"cf-3"}'
U=$(curl -s -H "$AUTH2" $A/conversations/unread-count)
check "okunmamis toplam >= 1" yes "$([ "$(echo "$U" | jget total)" -ge 1 ] && echo yes)"
M3=$(curl -s -H "$AUTH2" "$A/conversations/$CID/messages?size=1" | idof)
curl -s -o /dev/null -X POST -H "$H" -H "$AUTH2" $A/conversations/$CID/read -d "{\"lastMessageId\":$M3}"
check "okuyunca toplam 0" 0 "$(curl -s -H "$AUTH2" $A/conversations/unread-count | jget total)"

echo "== sessize alma"
check "gecersiz sure 400" 400 "$(code -X PUT -H "$H" -H "$AUTH2" $A/conversations/$CID/mute -d '{"durationMinutes":0}')"
R=$(curl -s -X PUT -H "$H" -H "$AUTH2" $A/conversations/$CID/mute -d '{"durationMinutes":60}')
check "muted bayragi" true "$(echo "$R" | jget muted)"
curl -s -o /dev/null -X POST -H "$H" -H "$AUTH1" $A/conversations/$CID/messages -d '{"text":"sessizken","clientId":"cf-4"}'
U=$(curl -s -H "$AUTH2" $A/conversations/unread-count)
check "sessizde: rozet toplami 0" 0 "$(echo "$U" | jget total)"
check "sessizde: mutedTotal >= 1" yes "$([ "$(echo "$U" | jget mutedTotal)" -ge 1 ] && echo yes)"
check "sessizlik kaldir 200" 200 "$(code -X DELETE -H "$AUTH2" $A/conversations/$CID/mute)"
check "uye olmayan 404" 404 "$(code -X PUT -H "$H" -H "$AUTH3" $A/conversations/$CID/mute -d '{"forever":true}')"

echo "== arsiv"
check "arsivle 200" 200 "$(code -X PUT -H "$H" -H "$AUTH2" $A/conversations/$CID/archive -d '{}')"
check "varsayilan listede yok" 0 "$(curl -s -H "$AUTH2" $A/conversations | grep -o "\"id\":$CID," | wc -l)"
check "arsiv listesinde var" yes "$([ "$(curl -s -H "$AUTH2" "$A/conversations?archived=true" | grep -c "\"id\":$CID,")" -ge 1 ] && echo yes)"
curl -s -o /dev/null -X POST -H "$H" -H "$AUTH1" $A/conversations/$CID/messages -d '{"text":"arsivden cikar","clientId":"cf-5"}'
check "yeni mesaj arsivden cikardi" yes "$([ "$(curl -s -H "$AUTH2" $A/conversations | grep -c "\"id\":$CID,")" -ge 1 ] && echo yes)"
curl -s -o /dev/null -X PUT -H "$H" -H "$AUTH2" $A/conversations/$CID/archive -d '{"keepArchived":true}'
curl -s -o /dev/null -X POST -H "$H" -H "$AUTH1" $A/conversations/$CID/messages -d '{"text":"yapiskan","clientId":"cf-6"}'
check "yapiskan arsiv korunur" yes "$([ "$(curl -s -H "$AUTH2" "$A/conversations?archived=true" | grep -c "\"id\":$CID,")" -ge 1 ] && echo yes)"
curl -s -o /dev/null -X DELETE -H "$AUTH2" $A/conversations/$CID/archive

echo "== silme (herkes icin)"
check "baskasi silemez (direkt) 403" 403 "$(code -X DELETE -H "$AUTH2" $A/messages/$M1)"
check "uye olmayan 404" 404 "$(code -X DELETE -H "$AUTH3" $A/messages/$M1)"
check "gonderen siler 204" 204 "$(code -X DELETE -H "$AUTH1" $A/messages/$M1)"
check "tekrar silme idempotent 204" 204 "$(code -X DELETE -H "$AUTH1" $A/messages/$M1)"
check "silinmis duzenlenemez 409" 409 "$(code -X PATCH -H "$H" -H "$AUTH1" $A/messages/$M1 -d '{"text":"geri"}')"
check "silinmis mesaja tepki 404" 404 "$(code -X PUT -H "$H" -H "$AUTH2" $A/messages/$M1/reaction -d "{\"emoji\":\"$THUMBS\"}")"
H2=$(curl -s -H "$AUTH2" "$A/conversations/$CID/messages?size=30")
check "gecmiste deleted=true" yes "$(echo "$H2" | grep -q '"deleted":true' && echo yes)"
check "gecmiste eski metin yok" 0 "$(echo "$H2" | grep -c 'duzenlendi')"
check "yanitin onizlemesi 'silindi'" yes "$(echo "$H2" | grep -q 'Bu mesaj silindi' && echo yes)"

echo "== grup: yonetici silme"
G=$(curl -s -X POST -H "$H" -H "$AUTH1" $A/conversations -d "{\"title\":\"cf grup\",\"memberIds\":[$ID2,$ID3]}" | idof)
GM=$(curl -s -X POST -H "$H" -H "$AUTH2" $A/conversations/$G/messages -d '{"text":"grup mesaji","clientId":"cfg-1"}' | idof)
check "uye baskasinin mesajini silemez 403" 403 "$(code -X DELETE -H "$AUTH3" $A/messages/$GM)"
check "grup yoneticisi siler 204" 204 "$(code -X DELETE -H "$AUTH1" $A/messages/$GM)"

echo "== kimlik"
check "girissiz duzenleme 401" 401 "$(code -X PATCH -H "$H" $A/messages/$M1 -d '{"text":"x"}')"
check "girissiz okunmamis 401" 401 "$(code $A/conversations/unread-count)"

echo
[ $FAIL = 0 ] && echo "TUMU GECTI" || { echo "BASARISIZ VAR"; exit 1; }

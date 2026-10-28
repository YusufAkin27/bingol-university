#!/usr/bin/env bash
# T15 kulup ekstralari uctan uca: sohbet odasi (uyelikle senkron, kapat/ac), duyuru (limit + bildirim),
# katilim sorulari (zorunlu yanit, yanit gizliligi), uye arama/filtre, istatistik (yetkili), logo/kapak.
# Kullanim: BASE=http://localhost:8115 ./scripts/club-extras-e2e.sh   (COMPOSE_PROJECT_NAME ile)
# Onkosul: compose'ta MAIL_ENABLED=false ve ADMIN_EMAILS=$ADMIN_EMAIL. Tekrar calistirilabilir (rastgele sonek).
# Betikler arasinda: docker compose exec -T redis redis-cli flushall (kayit ucu IP basina saatte 10).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
PNG=${PNG:-scripts/fixtures/media/tiny.png}
H='Content-Type: application/json'
FAIL=0
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
contains() { if printf '%s' "$3" | grep -q -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 ('$2' bulunamadi)"; FAIL=1; fi; }
lacks() { if printf '%s' "$3" | grep -q -- "$2"; then echo "  FAIL $1 ('$2' beklenmedik sekilde var)"; FAIL=1; else echo "  ok   $1"; fi; }
call() {
  local m=$1 p=$2 t=$3 d=${4:-}
  if [ -n "$d" ]; then
    CODE=$(curl -s -o "$TMP" -w '%{http_code}' -X "$m" -H "$H" -H "Authorization: Bearer $t" "$A$p" -d "$d")
  else
    CODE=$(curl -s -o "$TMP" -w '%{http_code}' -X "$m" -H "$H" -H "Authorization: Bearer $t" "$A$p")
  fi
  BODY=$(cat "$TMP")
}
step() { local name=$1 exp=$2; shift 2; call "$@"; check "$name" "$exp" "$CODE"; }
upload() { # ad beklenen YOL TOKEN
  CODE=$(curl -s -o "$TMP" -w '%{http_code}' -X POST -H "Authorization: Bearer $4" -F "file=@$PNG;type=image/png" "$A$2")
  BODY=$(cat "$TMP"); check "$1" "$3" "$CODE"
}
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
convof() { grep -o '"conversationId":[0-9]*' | head -1 | cut -d: -f2; }
register() {
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c tok
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  tok=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  if [ -z "$tok" ]; then
    tok=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  fi
  echo "$tok"
}

SFX=$RANDOM
echo "== kullanicilar"
T1=$(register "xsahip$SFX@bingol.edu.tr" "Sahip Kisi")
T2=$(register "xuye$SFX@bingol.edu.tr" "Uye Kisi")
T3=$(register "xbasvuran$SFX@bingol.edu.tr" "Basvuran Kisi")
T4=$(register "xyabanci$SFX@bingol.edu.tr" "Yabanci Kisi")
T5=$(register "xred$SFX@bingol.edu.tr" "Reddedilen Kisi")
TA=$(register "$ADMIN_EMAIL" "Sistem Yoneticisi")
[ -n "$T1" ] && [ -n "$T2" ] && [ -n "$T3" ] && [ -n "$T4" ] && [ -n "$T5" ] && [ -n "$TA" ] || { echo "kayit basarisiz"; exit 1; }
ID2=$(curl -s -H "Authorization: Bearer $T2" $A/users/me | idof)
ID3=$(curl -s -H "Authorization: Bearer $T3" $A/users/me | idof)
ID5=$(curl -s -H "Authorization: Bearer $T5" $A/users/me | idof)

echo "== acik kulup: sohbet odasi onayla birlikte kurulur"
step "olustur" 202 POST /communities "$T1" "{\"name\":\"Ekstra Kulup $SFX\",\"description\":\"t15\",\"visibility\":\"PUBLIC\",\"joinPolicy\":\"OPEN\"}"
C=$(printf '%s' "$BODY" | idof)
step "onay bekleyen kulupte oda yok (404)" 404 GET /communities/$C/chat-room "$T1"
step "admin onayla" 204 POST /admin/communities/$C/approve "$TA"
step "sahip odayi gorur" 200 GET /communities/$C/chat-room "$T1"
CONV=$(printf '%s' "$BODY" | convof)
contains "sahip odanin uyesi" '"joined":true' "$BODY"
[ -n "$CONV" ] && echo "  ok   conversationId=$CONV" || { echo "  FAIL conversationId yok"; FAIL=1; }
step "yabanci odayi goremez (404)" 404 GET /communities/$C/chat-room "$T4"
step "yabanci join-chat (404)" 404 POST /communities/$C/chat-room/join "$T4"

echo "== uyelik senkronu"
step "uye katilir" 200 POST /communities/$C/join "$T2"
step "uye odayi gorur" 200 GET /communities/$C/chat-room "$T2"
contains "uye odada" '"joined":true' "$BODY"
step "uye mesaj yazar" 201 POST /conversations/$CONV/messages "$T2" "{\"text\":\"selam oda\",\"clientId\":\"x$SFX-1\"}"
step "sahip mesaji gorur" 200 GET /conversations/$CONV/messages "$T1"
contains "mesaj listede" "selam oda" "$BODY"
step "yabanci mesaj yazamaz" 404 POST /conversations/$CONV/messages "$T4" "{\"text\":\"sizma\",\"clientId\":\"y$SFX-1\"}"
step "elle uye ekleme calismaz (yonetici degil)" 403 POST /conversations/$CONV/members "$T1" "{\"userIds\":[$ID3]}"

echo "== ayrilinca odadan cikar, ban"
step "uye ayrilir" 204 DELETE /communities/$C/membership "$T2"
step "ayrilan odayi goremez" 404 GET /communities/$C/chat-room "$T2"
step "ayrilan mesaj yazamaz" 404 POST /conversations/$CONV/messages "$T2" "{\"text\":\"hala mi\",\"clientId\":\"x$SFX-2\"}"
step "uye tekrar katilir" 200 POST /communities/$C/join "$T2"
step "yeniden odada" 200 GET /communities/$C/chat-room "$T2"
step "sahip uyeyi banlar" 204 DELETE "/communities/$C/members/$ID2?ban=true" "$T1"
step "banli odayi goremez" 404 GET /communities/$C/chat-room "$T2"
step "banli mesaj yazamaz" 404 POST /conversations/$CONV/messages "$T2" "{\"text\":\"ban\",\"clientId\":\"x$SFX-3\"}"

echo "== oda kapat/ac (MANAGE_MEMBERS)"
step "yabanci uye (T3) katilir" 200 POST /communities/$C/join "$T3"
step "duz uye kapatamaz" 403 PUT /communities/$C/chat-room/closed "$T3" '{"closed":true}'
step "sahip kapatir" 200 PUT /communities/$C/chat-room/closed "$T1" '{"closed":true}'
contains "kapali" '"closed":true' "$BODY"
lacks "kapali odada conversationId yok" '"conversationId":[0-9]' "$BODY"
step "kapali odada mesaj yok" 404 POST /conversations/$CONV/messages "$T3" "{\"text\":\"kapali\",\"clientId\":\"z$SFX-1\"}"
step "kapali odaya join 409" 409 POST /communities/$C/chat-room/join "$T3"
step "sahip acar" 200 PUT /communities/$C/chat-room/closed "$T1" '{"closed":false}'
step "acilinca uye geri" 200 GET /communities/$C/chat-room "$T3"
contains "uye yeniden odada" '"joined":true' "$BODY"

echo "== duyurular"
step "duz uye duyuru yazamaz" 403 POST /communities/$C/announcements "$T3" '{"text":"deneme"}'
step "yabanci duyuru yazamaz" 403 POST /communities/$C/announcements "$T4" '{"text":"deneme"}'
step "duyuru 1" 201 POST /communities/$C/announcements "$T1" "{\"text\":\"Toplanti yarin saat 18 $SFX\"}"
step "duyuru 2" 201 POST /communities/$C/announcements "$T1" '{"text":"Ikinci duyuru"}'
step "duyuru 3" 201 POST /communities/$C/announcements "$T1" '{"text":"Ucuncu duyuru"}'
step "gunluk 4. duyuru 429" 429 POST /communities/$C/announcements "$T1" '{"text":"Dorduncu duyuru"}'
contains "limit kodu" "ANNOUNCEMENT_LIMIT" "$BODY"
step "duyuru listesi" 200 GET /communities/$C/announcements "$T3"
contains "duyuru listede" "Toplanti yarin" "$BODY"
step "uye bildirim alir" 200 GET /notifications "$T3"
contains "duyuru bildirimi" "Toplanti yarin" "$BODY"
step "bildirim dilini kontrol: yazar kendine gondermez" 200 GET /notifications "$T1"
lacks "yazar kendi duyurusunu bildirim olarak almaz" "Toplanti yarin" "$BODY"

echo "== ozel kulup: katilim sorulari"
step "ozel kulup olustur" 202 POST /communities "$T1" "{\"name\":\"Gizli Ekstra $SFX\",\"description\":\"ic\",\"visibility\":\"PRIVATE\",\"joinPolicy\":\"APPROVAL\"}"
P=$(printf '%s' "$BODY" | idof)
step "admin onayla (ozel)" 204 POST /admin/communities/$P/approve "$TA"
step "yabanci soru koyamaz" 403 PUT /communities/$P/join-questions "$T4" '{"questions":["Neden katilmak istiyorsun?"]}'
step "4 soru reddedilir" 400 PUT /communities/$P/join-questions "$T1" '{"questions":["Soru bir?","Soru iki?","Soru uc?","Soru dort?"]}'
contains "soru limit kodu" "QUESTION_LIMIT" "$BODY"
step "sahip 2 soru koyar" 200 PUT /communities/$P/join-questions "$T1" '{"questions":["Neden katilmak istiyorsun?","Hangi bolumdesin?"]}'
QID1=$(printf '%s' "$BODY" | idof)
step "yabanci sorulari gorur (basvuru icin)" 200 GET /communities/$P/join-questions "$T4"
contains "soru metni" "Hangi bolumdesin" "$BODY"
QID2=$(curl -s -H "Authorization: Bearer $T4" $A/communities/$P/join-questions | grep -o '"id":[0-9]*' | sed -n 2p | cut -d: -f2)
step "yanitsiz basvuru 400" 400 POST /communities/$P/join "$T3"
contains "yanit zorunlu" "ANSWERS_REQUIRED" "$BODY"
step "eksik yanit 400" 400 POST /communities/$P/join "$T3" "{\"answers\":[{\"questionId\":$QID1,\"answer\":\"Ogrenmek\"}]}"
step "bos yanit 400" 400 POST /communities/$P/join "$T3" "{\"answers\":[{\"questionId\":$QID1,\"answer\":\"Ogrenmek\"},{\"questionId\":$QID2,\"answer\":\"   \"}]}"
step "yanitli basvuru" 200 POST /communities/$P/join "$T3" "{\"answers\":[{\"questionId\":$QID1,\"answer\":\"Ogrenmek istiyorum\"},{\"questionId\":$QID2,\"answer\":\"Bilgisayar\"}]}"
contains "bekliyor" "PENDING" "$BODY"
step "sahip yanitlari okur" 200 GET /communities/$P/requests/$ID3/answers "$T1"
contains "yanit 1" "Ogrenmek istiyorum" "$BODY"
contains "yanit 2" "Bilgisayar" "$BODY"
step "basvuran kendi yanitlarini yetkili ucundan okuyamaz" 403 GET /communities/$P/requests/$ID3/answers "$T3"
step "yabanci yanit okuyamaz" 403 GET /communities/$P/requests/$ID3/answers "$T4"
step "bekleyen oda goremez" 404 GET /communities/$P/chat-room "$T3"
step "onayla" 204 POST /communities/$P/requests/$ID3/approve "$T1"
step "onaylanan odayi gorur" 200 GET /communities/$P/chat-room "$T3"
step "ikinci basvuran" 200 POST /communities/$P/join "$T5" "{\"answers\":[{\"questionId\":$QID1,\"answer\":\"Merak\"},{\"questionId\":$QID2,\"answer\":\"Hukuk\"}]}"
step "reddet" 204 POST /communities/$P/requests/$ID5/reject "$T1"
step "reddedilenin yanitlari silindi (404)" 404 GET /communities/$P/requests/$ID5/answers "$T1"

echo "== uye listesi arama/filtre"
step "ad ile ara" 200 GET "/communities/$C/members/search?q=Sahip" "$T3"
contains "sahip bulundu" "Sahip Kisi" "$BODY"
lacks "baskasi gelmez" "Yabanci Kisi" "$BODY"
step "LIKE joker karakteri etkisiz" 200 GET "/communities/$C/members/search?q=%25" "$T3"
lacks "% hepsini eslemez" "Sahip Kisi" "$BODY"
step "rol filtresi" 200 GET "/communities/$C/members/search?role=OWNER" "$T3"
contains "owner listelendi" '"role":"OWNER"' "$BODY"
step "gecersiz rol 400" 400 GET "/communities/$C/members/search?role=KRAL" "$T3"
step "duz uye BANNED listesini goremez" 403 GET "/communities/$C/members/search?status=BANNED" "$T3"
step "sahip BANNED listesini gorur" 200 GET "/communities/$C/members/search?status=BANNED" "$T1"
contains "banli uye" "Uye Kisi" "$BODY"
step "yabanci ozel kulup uyelerini goremez" 403 GET "/communities/$P/members/search?q=a" "$T4"

echo "== istatistik (yalniz yetkililer)"
step "sahip istatistik" 200 GET /communities/$C/stats "$T1"
contains "uye sayisi" '"memberCount"' "$BODY"
contains "duyuru sayisi" '"announcementCount":3' "$BODY"
contains "sohbet aktif" '"chatActive":true' "$BODY"
step "duz uye istatistik 403" 403 GET /communities/$C/stats "$T3"
step "yabanci istatistik 403" 403 GET /communities/$C/stats "$T4"

echo "== logo ve kapak (T1 hatti)"
if [ -f "$PNG" ]; then
  upload "sahip logo yukler" 200 /communities/$C/logo "$T1"
  contains "logoUrl" '"logoUrl":"/files/avatars/' "$BODY"
  upload "duz uye logo yukleyemez" 403 /communities/$C/logo "$T3"
  upload "sahip kapak yukler" 200 /communities/$C/cover "$T1"
  contains "coverUrl" '"coverUrl":"/files/covers/' "$BODY"
  step "logo kaldir" 200 DELETE /communities/$C/logo "$T1"
  lacks "logo kalmadi" '"logoUrl":"/files' "$BODY"
else
  echo "  atlandi: $PNG yok"
fi

echo "== KVKK disa aktarim"
step "export" 200 GET /users/me/export "$T3"
contains "clubExtras bolumu" "clubExtras" "$BODY"

[ $FAIL -eq 0 ] && echo "TUMU GECTI" || { echo "BASARISIZLIK VAR"; exit 1; }

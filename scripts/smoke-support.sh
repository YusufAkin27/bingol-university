#!/usr/bin/env bash
# Destek, sozlesme, SSS, uygulama bilgisi, dil (i18n), disa aktarim ve push kampanyalari icin uctan uca duman testi.
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ./scripts/smoke-support.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur), ADMIN_EMAILS=$ADMIN_EMAIL
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 200)"; FAIL=1; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

# kayit + dogrulama -> access token. 3. arguman dil (tr|en|ar)
register() {
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true,\"language\":\"${3:-tr}\"}"
  sleep 1
  local c t
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  t=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Sifre1234\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  # Hesap onceden kayitliysa (ornek: onceki betik) giris yap
  if [ -z "$t" ]; then
    t=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" |
      grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  fi
  echo "$t"
}

SFX=$RANDOM
echo "== kullanicilar"
TTR=$(register "tr$SFX@bingol.edu.tr" "Kullanici TR" tr)
TEN=$(register "en$SFX@bingol.edu.tr" "User EN" en)
TAR=$(register "ar$SFX@bingol.edu.tr" "User AR" ar)
TA=$(register "$ADMIN_EMAIL" "Admin" tr)
[ -n "$TTR" ] && [ -n "$TEN" ] && [ -n "$TAR" ] || { echo "kayit basarisiz"; exit 1; }
[ -n "$TA" ] || { echo "UYARI: admin token yok; ADMIN_EMAIL daha once kayitli ve farkli sifreyle olabilir"; exit 1; }
ATR="Authorization: Bearer $TTR"; AEN="Authorization: Bearer $TEN"; AAR="Authorization: Bearer $TAR"; AAD="Authorization: Bearer $TA"
ID_EN=$(curl -s -H "$AEN" $A/users/me | idof)

echo "== dil (i18n)"
BAD='{"email":"nobody@bingol.edu.tr","password":"yanlisYanlis1"}'
has "hata TR" "E-posta veya" "$(curl -s -X POST -H "$H" $A/auth/login -d "$BAD")"
has "hata EN" "Incorrect email" "$(curl -s -X POST -H "$H" -H 'Accept-Language: en' $A/auth/login -d "$BAD")"
has "hata EN (en-US)" "Incorrect email" "$(curl -s -X POST -H "$H" -H 'Accept-Language: en-US,en;q=0.9' $A/auth/login -d "$BAD")"
has "hata AR" "$(printf '\xd8\xa7\xd9\x84\xd8\xa8\xd8\xb1\xd9\x8a\xd8\xaf')" "$(curl -s -X POST -H "$H" -H 'Accept-Language: ar' $A/auth/login -d "$BAD")"
has "desteklenmeyen dil TR'ye duser" "E-posta veya" "$(curl -s -X POST -H "$H" -H 'Accept-Language: fr' $A/auth/login -d "$BAD")"
has "kod makine okunur kalir (EN)" '"code":"INVALID_CREDENTIALS"' "$(curl -s -X POST -H "$H" -H 'Accept-Language: en' $A/auth/login -d "$BAD")"
NOTERMS="{\"email\":\"x$SFX@bingol.edu.tr\",\"password\":\"Sifre1234\",\"displayName\":\"X\",\"acceptTerms\":false}"
check "sozlesme kabulsuz kayit" 400 "$(code -X POST -H "$H" $A/auth/register -d "$NOTERMS")"
has "sozlesme hatasi EN" "agreements" "$(curl -s -X POST -H "$H" -H 'Accept-Language: en' $A/auth/register -d "$NOTERMS")"
has "kayit mesaji EN" "verification code has been sent" "$(curl -s -X POST -H "$H" -H 'Accept-Language: en' $A/auth/register -d "{\"email\":\"y$SFX@bingol.edu.tr\",\"password\":\"Sifre1234\",\"displayName\":\"Y\",\"acceptTerms\":true}")"
has "domain hatasi EN" "bingol.edu.tr" "$(curl -s -X POST -H "$H" -H 'Accept-Language: en' $A/auth/register -d "{\"email\":\"a@gmail.com\",\"password\":\"Sifre1234\",\"displayName\":\"Y\",\"acceptTerms\":true}")"
check "gecersiz dil degeri" 400 "$(code -X PATCH -H "$H" -H "$ATR" $A/users/me -d '{"language":"fr"}')"
has "profil dili" '"language":"en"' "$(curl -s -H "$AEN" $A/users/me)"

echo "== sozlesmeler"
has "liste" '"type":"KVKK"' "$(curl -s $A/legal)"
has "TERMS TR" '"lang":"tr"' "$(curl -s $A/legal/terms)"
has "TERMS EN yoksa TR" '"type":"TERMS"' "$(curl -s -H 'Accept-Language: en' $A/legal/terms)"
check "bilinmeyen tur" 404 "$(code $A/legal/nope)"
check "kayit onayi: bekleyen yok" "[]" "$(curl -s -H "$ATR" $A/legal/consents/pending)"
has "onay gecmisi" '"type":"TERMS"' "$(curl -s -H "$ATR" $A/legal/consents/mine)"
check "yetkisiz yayin 403" 403 "$(code -X POST -H "$H" -H "$ATR" $A/admin/legal/terms -d '{"tr":{"title":"x","content":"y"}}')"
PUB=$(curl -s -X POST -H "$H" -H "$AAD" $A/admin/legal/terms -d '{"tr":{"title":"Kullanim Kosullari v2","content":"yeni icerik"},"en":{"title":"Terms of Use v2","content":"new content"}}')
PUBV=$(echo "$PUB" | grep -o '[0-9]*' | head -1)
[ -n "$PUBV" ] && echo "  ok   yeni surum yayinla (v$PUBV)" || { echo "  FAIL yayin: $PUB"; FAIL=1; }
has "yeni surum EN" "Terms of Use v2" "$(curl -s -H 'Accept-Language: en' $A/legal/terms)"
has "yeni surum AR icin TR" "Kullanim Kosullari v2" "$(curl -s -H 'Accept-Language: ar' $A/legal/terms)"
has "yeniden onay bekliyor" '"type":"TERMS"' "$(curl -s -H "$ATR" $A/legal/consents/pending)"
check "eski surum 409" 409 "$(code -X POST -H "$H" -H "$ATR" $A/legal/consents -d "{\"items\":[{\"type\":\"TERMS\",\"version\":$((PUBV-1))}]}")"
check "guncel surum onay" 204 "$(code -X POST -H "$H" -H "$ATR" $A/legal/consents -d "{\"items\":[{\"type\":\"TERMS\",\"version\":$PUBV}]}")"
check "bekleyen kalmadi" "[]" "$(curl -s -H "$ATR" $A/legal/consents/pending)"

echo "== SSS"
has "SSS TR" '"category":"Hesap"' "$(curl -s $A/faq)"
has "SSS EN" '"category":"Account"' "$(curl -s -H 'Accept-Language: en' $A/faq)"
has "SSS AR" "$(printf '\xd8\xa7\xd9\x84\xd8\xad\xd8\xb3\xd8\xa7\xd8\xa8')" "$(curl -s -H 'Accept-Language: ar' $A/faq)"
FQ=$(curl -s -w " [%{http_code}]" -X POST -H "$H" -H "$AAD" $A/admin/faq -d '{"lang":"tr","category":"SmokeTest","question":"Soru?","answer":"Cevap."}')
check "SSS ekle (admin)" 201 "$(echo "$FQ" | grep -o "[0-9]*]$" | tr -d "]")"
FQID=$(echo "$FQ" | grep -o "\"id\":[0-9]*" | head -1 | cut -d: -f2)
check "SSS ekle (normal kullanici)" 403 "$(code -X POST -H "$H" -H "$ATR" $A/admin/faq -d '{"lang":"tr","category":"Test","question":"Soru?","answer":"Cevap."}')"

echo "== geri bildirim ve oneri panosu"
FB=$(curl -s -X POST -H "$H" -H "$ATR" $A/feedback -d '{"category":"SUGGESTION","subject":"Karanlik tema","message":"Karanlik tema eklenebilir mi?","appVersion":"1.0.0","platform":"ANDROID"}')
FID=$(echo "$FB" | grep -o '"id":[0-9]*' | cut -d: -f2)
[ -n "$FID" ] && echo "  ok   olustur (id=$FID)" || { echo "  FAIL olustur: $FB"; FAIL=1; }
check "gecersiz kategori" 400 "$(code -X POST -H "$H" -H "$ATR" $A/feedback -d '{"category":"X","subject":"a","message":"b"}')"
has "benimkiler" '"subject":"Karanlik tema"' "$(curl -s -H "$ATR" $A/feedback/mine)"
check "pano: henuz herkese acik degil, oy 404" 404 "$(code -X PUT -H "$AEN" $A/suggestions/$FID/vote)"
check "yonetici: durum+yanit+pano" 200 "$(code -X PATCH -H "$H" -H "$AAD" $A/admin/feedback/$FID -d '{"status":"PLANNED","adminResponse":"Planlandi, tesekkurler.","publicVisible":true}')"
check "oy ver" 204 "$(code -X PUT -H "$AEN" $A/suggestions/$FID/vote)"
check "oy ver (tekrar, idempotent)" 204 "$(code -X PUT -H "$AEN" $A/suggestions/$FID/vote)"
check "baska kullanici oy" 204 "$(code -X PUT -H "$AAR" $A/suggestions/$FID/vote)"
has "pano: 2 oy, bana ait oy" '"voteCount":2,"votedByMe":true' "$(curl -s -H "$AEN" "$A/suggestions?sort=top")"
check "oy geri al" 204 "$(code -X DELETE -H "$AAR" $A/suggestions/$FID/vote)"
has "pano: 1 oy" '"voteCount":1' "$(curl -s -H "$AEN" $A/suggestions)"
check "BUG herkese acik olamaz" 400 "$(code -X PATCH -H "$H" -H "$AAD" $A/admin/feedback/$(curl -s -X POST -H "$H" -H "$ATR" $A/feedback -d '{"category":"BUG","subject":"Hata","message":"Bir hata var"}' | grep -o '"id":[0-9]*' | cut -d: -f2) -d '{"publicVisible":true}')"
check "yonetici kuyrugu" 200 "$(code -H "$AAD" "$A/admin/feedback?status=NEW")"
has "kullaniciya bildirim gitti" "Geri bildiriminiz" "$(curl -s -H "$ATR" $A/notifications)"

echo "== destek talepleri"
TK=$(curl -s -X POST -H "$H" -H "$ATR" $A/support/tickets -d '{"category":"ACCOUNT","subject":"Giris sorunu","message":"Giris yapamiyorum."}')
TID=$(echo "$TK" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
[ -n "$TID" ] && echo "  ok   talep ac (id=$TID)" || { echo "  FAIL talep ac: $TK"; FAIL=1; }
check "baskasinin talebi 404" 404 "$(code -H "$AEN" $A/support/tickets/$TID)"
check "yonetici yanitla" 200 "$(code -X POST -H "$H" -H "$AAD" $A/admin/support/tickets/$TID/reply -d '{"text":"Merhaba, yardimci oluyoruz."}')"
has "durum ANSWERED" '"status":"ANSWERED"' "$(curl -s -H "$ATR" $A/support/tickets/$TID)"
has "personel mesaji gorunur" '"fromStaff":true' "$(curl -s -H "$ATR" $A/support/tickets/$TID)"
has "bildirim TR" "Destek talebiniz yan" "$(curl -s -H "$ATR" $A/notifications)"
check "kullanici yanitla" 200 "$(code -X POST -H "$H" -H "$ATR" $A/support/tickets/$TID/messages -d '{"text":"Tesekkurler."}')"
has "durum OPEN" '"status":"OPEN"' "$(curl -s -H "$ATR" $A/support/tickets/$TID)"
check "kapat" 204 "$(code -X POST -H "$ATR" $A/support/tickets/$TID/close)"
check "kapali talebe yanit 409" 409 "$(code -X POST -H "$H" -H "$ATR" $A/support/tickets/$TID/messages -d '{"text":"x"}')"
has "kapali hata EN" "closed" "$(curl -s -X POST -H "$H" -H 'Accept-Language: en' -H "$ATR" $A/support/tickets/$TID/messages -d '{"text":"x"}')"

echo "== uygulama bilgisi"
has "info" '"appName":"BÜ Kampüs"' "$(curl -s $A/app/info)"
has "diller" '"languages":["tr","en","ar"]' "$(curl -s $A/app/info)"
has "surum: guncel" '"updateRequired":false,"updateAvailable":false' "$(curl -s "$A/app/version?platform=ANDROID&version=1.0.0")"
check "ayar guncelle (min surum)" 204 "$(code -X PUT -H "$H" -H "$AAD" $A/admin/settings/min_version_android -d '{"value":"1.2.0"}')"
has "surum: zorunlu guncelleme" '"updateRequired":true' "$(curl -s "$A/app/version?platform=android&version=1.1.9")"
has "surum karsilastirma 1.10 > 1.9" '"updateRequired":false' "$(curl -s "$A/app/version?platform=ANDROID&version=1.10.0")"
check "gecersiz surum" 400 "$(code "$A/app/version?platform=ANDROID&version=abc")"
check "min surum geri al" 204 "$(code -X PUT -H "$H" -H "$AAD" $A/admin/settings/min_version_android -d '{"value":"1.0.0"}')"
check "bakim modu ac" 204 "$(code -X PUT -H "$H" -H "$AAD" $A/admin/settings/maintenance_mode -d '{"value":"true"}')"
has "bakim mesaji EN" "under maintenance" "$(curl -s -H 'Accept-Language: en' $A/app/info)"
check "bakim modu kapat" 204 "$(code -X PUT -H "$H" -H "$AAD" $A/admin/settings/maintenance_mode -d '{"value":"false"}')"
check "bilinmeyen ayar" 404 "$(code -X PUT -H "$H" -H "$AAD" $A/admin/settings/yok -d '{"value":"1"}')"
check "normal kullanici ayar 403" 403 "$(code -X PUT -H "$H" -H "$ATR" $A/admin/settings/website -d '{"value":"https://x.y"}')"

echo "== veri disa aktarim (KVKK)"
EXP=$(curl -s -H "$ATR" $A/users/me/export)
has "profil" '"profile"' "$EXP"
has "sozlesme onaylari" '"legalConsents"' "$EXP"
has "geri bildirimler" '"feedback"' "$EXP"
has "destek talepleri" '"supportTickets"' "$EXP"
check "giris olmadan 401" 401 "$(code $A/users/me/export)"

echo "== push kampanyalari"
check "normal kullanici 403" 403 "$(code -X POST -H "$H" -H "$ATR" $A/admin/push/audience-count -d '{"type":"ALL"}')"
has "kitle: herkes" '"count":' "$(curl -s -X POST -H "$H" -H "$AAD" $A/admin/push/audience-count -d '{"type":"ALL"}')"
check "kitle: gecersiz sinif" 400 "$(code -X POST -H "$H" -H "$AAD" $A/admin/push/audience-count -d '{"type":"CLASS_YEAR","value":"99"}')"
has "kitle: bos bolum sayimi 0" '"count":0' "$(curl -s -X POST -H "$H" -H "$AAD" $A/admin/push/audience-count -d '{"type":"DEPARTMENT","value":"Yok Boyle Bolum"}')"
check "bos kitleye kampanya 400" 400 "$(code -X POST -H "$H" -H "$AAD" $A/admin/push/campaigns -d '{"audience":{"type":"DEPARTMENT","value":"Yok Boyle Bolum"},"tr":{"title":"a","body":"b"}}')"
curl -s -o /dev/null -X PATCH -H "$H" -H "$ATR" $A/users/me -d "{\"department\":\"TestBolumu$SFX\",\"classYear\":2}"
has "kitle: bolum" '"count":1' "$(curl -s -X POST -H "$H" -H "$AAD" $A/admin/push/audience-count -d "{\"type\":\"DEPARTMENT\",\"value\":\"TestBolumu$SFX\"}")"
check "gecersiz URL hedefi" 400 "$(code -X POST -H "$H" -H "$AAD" $A/admin/push/campaigns -d '{"audience":{"type":"SELF"},"tr":{"title":"a","body":"b"},"target":{"type":"URL","value":"javascript:alert(1)"}}')"
check "tr zorunlu" 400 "$(code -X POST -H "$H" -H "$AAD" $A/admin/push/campaigns -d '{"audience":{"type":"SELF"}}')"
CAMP=$(curl -s -X POST -H "$H" -H "$AAD" $A/admin/push/campaigns -d "{\"audience\":{\"type\":\"USERS\",\"value\":\"$ID_EN\"},\"tr\":{\"title\":\"Merhaba\",\"body\":\"Test bildirimi\"},\"en\":{\"title\":\"Hello\",\"body\":\"Test notification\"},\"ar\":{\"title\":\"مرحبا\",\"body\":\"إشعار تجريبي\"},\"target\":{\"type\":\"NEWS\",\"value\":\"1\"}}")
CID=$(echo "$CAMP" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
[ -n "$CID" ] && echo "  ok   kampanya olustur (id=$CID)" || { echo "  FAIL kampanya: $CAMP"; FAIL=1; }
for i in $(seq 1 12); do
  ST=$(curl -s -H "$AAD" $A/admin/push/campaigns/$CID | grep -o '"status":"[A-Z]*"' | cut -d'"' -f4)
  [ "$ST" = "SENT" ] && break; sleep 3
done
check "kampanya gonderildi" SENT "$ST"
has "alici sayisi 1" '"recipientCount":1' "$(curl -s -H "$AAD" $A/admin/push/campaigns/$CID)"
NEN=$(curl -s -H "$AEN" $A/notifications)
has "EN kullanici EN metin alir" "Test notification" "$NEN"
has "yonlendirme verisi" 'target' "$NEN"
# zamanlanmis + iptal
FUT=$(date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v+1H +%Y-%m-%dT%H:%M:%SZ)
CID2=$(curl -s -X POST -H "$H" -H "$AAD" $A/admin/push/campaigns -d "{\"audience\":{\"type\":\"SELF\"},\"tr\":{\"title\":\"Ileri\",\"body\":\"Zamanlanmis\"},\"scheduledAt\":\"$FUT\"}" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
has "zamanlanmis bekliyor" '"status":"SCHEDULED"' "$(curl -s -H "$AAD" $A/admin/push/campaigns/$CID2)"
check "iptal" 204 "$(code -X POST -H "$AAD" $A/admin/push/campaigns/$CID2/cancel)"
check "ikinci iptal 409" 409 "$(code -X POST -H "$AAD" $A/admin/push/campaigns/$CID2/cancel)"
has "liste" '"items"' "$(curl -s -H "$AAD" $A/admin/push/campaigns)"
# yonetici kendine test
CID3=$(curl -s -X POST -H "$H" -H "$AAD" $A/admin/push/campaigns -d '{"audience":{"type":"SELF"},"tr":{"title":"Test","body":"Kendime"}}' | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
for i in $(seq 1 12); do
  ST=$(curl -s -H "$AAD" $A/admin/push/campaigns/$CID3 | grep -o '"status":"[A-Z]*"' | cut -d'"' -f4)
  [ "$ST" = "SENT" ] && break; sleep 3
done
check "SELF testi gonderildi" SENT "$ST"
has "yonetici bildirimi aldi" "Kendime" "$(curl -s -H "$AAD" $A/notifications)"

# test verisini temizle
[ -n "${FQID:-}" ] && curl -s -o /dev/null -X DELETE -H "$AAD" $A/admin/faq/$FQID

[ $FAIL -eq 0 ] && echo "TUMU GECTI" || echo "HATA VAR"
exit $FAIL

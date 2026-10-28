#!/usr/bin/env bash
# Yonetici kullanici derin yonetimi (P09) icin uctan uca duman testi: yetki (anonim 401, kullanici 403), profil mudahalesi,
# oturum listesi + tek oturum kapatma, FCM cihaz listesi (token maskeli) + silme, bildirim gecmisi, KVKK disa aktarma
# (sebep >= 20 + X-Admin-Confirm + gunde bir), toplu islem (kismi basari, ADMIN/kendi atlanir), liste suzgecleri ve CSV.
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ./scripts/smoke-admin-users.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur), ADMIN_EMAILS=$ADMIN_EMAIL, calisan postgres/redis konteynerleri.
# Idempotent: her calistirmada benzersiz kullanicilar; sebep zorunlulugu (X-Admin-Reason) aciktir.
# Not: KVKK disa aktarma hedef kullanici basina gunde bir kez; her calistirma yeni kullanici uretir, bu yuzden sorun olmaz.
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 300)"; FAIL=1; fi; }
hasnt() { if echo "$3" | grep -qF -- "$2"; then echo "  FAIL $1 (bulunmamali: $2)"; FAIL=1; else echo "  ok   $1"; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

register() {
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true,\"language\":\"tr\"}"
  sleep 1
  local c t
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  t=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Sifre1234\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  if [ -z "$t" ]; then
    t=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" |
      grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  fi
  echo "$t"
}

SFX=$RANDOM
U1E="udp1x$SFX@bingol.edu.tr"; U2E="udp2x$SFX@bingol.edu.tr"
R='X-Admin-Reason: duman testi sebebi'
LONG='X-Admin-Reason: KVKK basvurusu uzerine duman testi disa aktarmasi'

echo "== kullanicilar"
TA=$(register "$ADMIN_EMAIL" "Yonetici")
T1=$(register "$U1E" "Hedef Bir")
T2=$(register "$U2E" "Hedef Iki")
[ -n "$TA" ] && [ -n "$T1" ] && [ -n "$T2" ] || { echo "token yok"; exit 1; }
AAD="Authorization: Bearer $TA"
U1=$(curl -s -H "Authorization: Bearer $T1" $A/users/me | idof)
U2=$(curl -s -H "Authorization: Bearer $T2" $A/users/me | idof)
ADM=$(curl -s -H "$AAD" $A/users/me | idof)
# profil: biyografi yaz (temizlenecek)
curl -s -o /dev/null -X PATCH -H "$H" -H "Authorization: Bearer $T1" $A/users/me -d '{"bio":"temizlenecek biyografi"}'
# cihaz kaydi (token maskeleme icin)
TOK="smoke-fcm-token-$SFX-ABCDEFGHIJKLMNOPQRSTUVWXYZ-SONEK6"
curl -s -o /dev/null -X POST -H "$H" -H "Authorization: Bearer $T1" $A/devices -d "{\"fcmToken\":\"$TOK\",\"platform\":\"ANDROID\",\"appVersion\":\"1.0.0\"}"

echo "== yetki: anonim 401, normal kullanici 403"
for p in sessions push-devices notifications; do
  check "anonim $p" 401 "$(code $A/admin/users/$U1/$p)"
  check "kullanici $p" 403 "$(code -H "Authorization: Bearer $T2" $A/admin/users/$U1/$p)"
done
check "anonim profil" 401 "$(code -X PATCH -H "$H" $A/admin/users/$U1/profile -d '{"clearBio":true}')"
check "kullanici export" 403 "$(code -X POST -H "Authorization: Bearer $T2" $A/admin/users/$U1/export)"
check "kullanici bulk" 403 "$(code -X POST -H "$H" -H "Authorization: Bearer $T2" $A/admin/users/bulk -d '{"action":"SUSPEND","ids":[1],"reason":"x"}')"

echo "== profil mudahalesi"
check "sebepsiz profil" 400 "$(code -X PATCH -H "$AAD" -H "$H" $A/admin/users/$U1/profile -d '{"clearBio":true}')"
check "bos profil govdesi" 400 "$(code -X PATCH -H "$AAD" -H "$H" -H "$R" $A/admin/users/$U1/profile -d '{}')"
PR=$(curl -s -X PATCH -H "$AAD" -H "$H" -H "$R" $A/admin/users/$U1/profile -d '{"clearBio":true,"displayName":"Duzeltilmis Ad"}')
has "bio temizlendi" "\"bioCleared\":true" "$PR"
has "ad degisti" "\"displayNameChanged\":true" "$PR"
UD=$(curl -s -H "$AAD" $A/admin/users/$U1)
has "ayrintida yeni ad" "Duzeltilmis Ad" "$UD"
PR2=$(curl -s -X PATCH -H "$AAD" -H "$H" -H "$R" $A/admin/users/$U1/profile -d '{"clearBio":true}')
has "ikinci temizleme degisiklik yok" "\"bioCleared\":false" "$PR2"
check "olmayan kullanici profil" 404 "$(code -X PATCH -H "$AAD" -H "$H" -H "$R" $A/admin/users/987654321/profile -d '{"clearBio":true}')"

echo "== oturumlar"
SE=$(curl -s -H "$AAD" $A/admin/users/$U1/sessions)
has "oturum listesi" "\"items\"" "$SE"
SID=$(echo "$SE" | grep -o '"id":"[0-9a-f]\{16\}"' | head -1 | cut -d'"' -f4)
check "sebepsiz oturum kapatma" 400 "$(code -X DELETE -H "$AAD" $A/admin/users/$U1/sessions/aaaaaaaaaaaaaaaa)"
check "olmayan oturum" 404 "$(code -X DELETE -H "$AAD" -H "$R" $A/admin/users/$U1/sessions/aaaaaaaaaaaaaaaa)"
check "bozuk oturum kimligi" 404 "$(code -X DELETE -H "$AAD" -H "$R" $A/admin/users/$U1/sessions/XYZ)"
if [ -n "$SID" ]; then
  check "tek oturum kapatma" 204 "$(code -X DELETE -H "$AAD" -H "$R" $A/admin/users/$U1/sessions/$SID)"
  check "ayni oturum tekrar" 404 "$(code -X DELETE -H "$AAD" -H "$R" $A/admin/users/$U1/sessions/$SID)"
fi

echo "== FCM cihazlari (token maskeli)"
PD=$(curl -s -H "$AAD" $A/admin/users/$U1/push-devices)
has "cihaz listesi" "\"tokenTail\"" "$PD"
hasnt "token tam gorunmez" "smoke-fcm-token" "$PD"
DID=$(echo "$PD" | idof)
if [ -n "$DID" ]; then
  check "sebepsiz cihaz silme" 400 "$(code -X DELETE -H "$AAD" $A/admin/users/$U1/push-devices/$DID)"
  check "baska kullanicinin cihazi" 404 "$(code -X DELETE -H "$AAD" -H "$R" $A/admin/users/$U2/push-devices/$DID)"
  check "cihaz silme" 204 "$(code -X DELETE -H "$AAD" -H "$R" $A/admin/users/$U1/push-devices/$DID)"
fi

echo "== bildirim gecmisi"
NO=$(curl -s -H "$AAD" "$A/admin/users/$U1/notifications?size=5")
has "bildirim sayfasi" "\"totalItems\"" "$NO"
has "profil bildirimi" "Profiliniz" "$NO"
check "gecersiz tur" 400 "$(code -H "$AAD" "$A/admin/users/$U1/notifications?type=BOGUS")"
check "olmayan kullanici bildirimleri" 404 "$(code -H "$AAD" $A/admin/users/987654321/notifications)"

echo "== KVKK disa aktarma (iki asamali, gunde bir)"
check "sebepsiz" 400 "$(code -X POST -H "$AAD" -H "X-Admin-Confirm: $U2" $A/admin/users/$U2/export)"
check "kisa sebep" 400 "$(code -X POST -H "$AAD" -H "$R" -H "X-Admin-Confirm: $U2" $A/admin/users/$U2/export)"
check "onay basligi yok" 400 "$(code -X POST -H "$AAD" -H "$LONG" $A/admin/users/$U2/export)"
check "yanlis onay" 400 "$(code -X POST -H "$AAD" -H "$LONG" -H "X-Admin-Confirm: 1" $A/admin/users/$U2/export)"
curl -s -D /tmp/p09_h1.txt -X POST -H "$AAD" -H "$LONG" -H "X-Admin-Confirm: $U2" $A/admin/users/$U2/export -o /tmp/p09_exp.json
has "indirilebilir yanit" "attachment" "$(cat /tmp/p09_h1.txt)"
has "kullanici kimligi" "\"subjectUserId\":$U2" "$(cat /tmp/p09_exp.json)"
check "ikinci istek (gunluk sinir)" 429 "$(code -X POST -H "$AAD" -H "$LONG" -H "X-Admin-Confirm: $U2" $A/admin/users/$U2/export)"

echo "== toplu islem (kismi basari)"
BL=$(curl -s -X POST -H "$AAD" -H "$H" $A/admin/users/bulk -d "{\"action\":\"SUSPEND\",\"ids\":[$U1,$ADM,987654321],\"reason\":\"duman testi toplu askiya alma\"}")
has "toplu: 1 basarili" "\"done\":1" "$BL"
has "toplu: kendi hesabi atlandi" "\"SELF\"" "$BL"
has "toplu: olmayan basarisiz" "USER_NOT_FOUND" "$BL"
check "toplu: sebepsiz" 400 "$(code -X POST -H "$AAD" -H "$H" $A/admin/users/bulk -d "{\"action\":\"SUSPEND\",\"ids\":[$U1]}")"
IDS=$(seq -s, 900000001 900000101)
check "toplu: 101 id" 400 "$(code -X POST -H "$AAD" -H "$H" $A/admin/users/bulk -d "{\"action\":\"SUSPEND\",\"ids\":[$IDS],\"reason\":\"duman testi\"}")"
check "toplu: bos liste" 400 "$(code -X POST -H "$AAD" -H "$H" $A/admin/users/bulk -d '{"action":"SUSPEND","ids":[],"reason":"duman testi"}')"
UD2=$(curl -s -H "$AAD" $A/admin/users/$U1)
has "kullanici askida" "\"status\":\"SUSPENDED\"" "$UD2"
BL2=$(curl -s -X POST -H "$AAD" -H "$H" $A/admin/users/bulk -d "{\"action\":\"UNSUSPEND\",\"ids\":[$U1,$U2],\"reason\":\"duman testi askiyi kaldirma\"}")
has "askiyi kaldirma: 1 basarili" "\"done\":1" "$BL2"
has "askida olmayan atlandi" "NOT_SUSPENDED" "$BL2"
BL3=$(curl -s -X POST -H "$AAD" -H "$H" $A/admin/users/bulk -d "{\"action\":\"REVOKE_SESSIONS\",\"ids\":[$U1,$U2],\"reason\":\"duman testi oturum kapatma\"}")
has "oturum kapatma: 2 basarili" "\"done\":2" "$BL3"

echo "== liste suzgecleri ve CSV"
TODAY=$(date -u +%Y-%m-%d)
check "kayit tarihi araligi" 200 "$(code -H "$AAD" "$A/admin/users?createdFrom=$TODAY&createdTo=$TODAY")"
L=$(curl -s -H "$AAD" "$A/admin/users?q=udp1x$SFX&createdFrom=$TODAY&seenFrom=$TODAY")
has "suzgec sonucu" "\"totalItems\"" "$L"
check "ters aralik" 400 "$(code -H "$AAD" "$A/admin/users?createdFrom=2026-10-02&createdTo=2026-10-01")"
check "gecersiz tarih" 400 "$(code -H "$AAD" "$A/admin/users?seenFrom=dun")"
check "gecersiz siralama" 400 "$(code -H "$AAD" "$A/admin/users?sort=password_hash,asc")"
check "e-posta ile siralama kapali" 400 "$(code -H "$AAD" "$A/admin/users?sort=email,asc")"
check "fakulte siralamasi" 200 "$(code -H "$AAD" "$A/admin/users?sort=faculty,asc")"
curl -s -D /tmp/p09_h2.txt -H "$AAD" "$A/admin/users/export.csv?q=udp&createdFrom=$TODAY" -o /tmp/p09_users.csv
has "CSV content-type" "text/csv" "$(cat /tmp/p09_h2.txt)"
has "CSV basligi" "id,email,displayName" "$(cat /tmp/p09_users.csv)"
has "CSV tam e-posta" "$U2E" "$(cat /tmp/p09_users.csv)"
check "CSV ters aralik" 400 "$(code -H "$AAD" "$A/admin/users/export.csv?createdFrom=2026-10-02&createdTo=2026-10-01")"

echo "== denetim kaydi"
AU=$(curl -s -H "$AAD" "$A/admin/audit?targetType=USER&targetId=$U2&size=50")
has "denetim: USER hedefi" "\"targetType\":\"USER\"" "$AU"
has "denetim: disa aktarma" "disa aktarma" "$AU"

if [ "$FAIL" = "0" ]; then echo "TUMU TAMAM"; else echo "BASARISIZ ADIMLAR VAR"; exit 1; fi

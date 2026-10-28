#!/usr/bin/env bash
# Kulup ayrintili yetkiler, yetki yukseltme korumalari, sahiplik devri, davet kodu ve denetim kaydi (uctan uca).
# Kullanim: BASE=http://localhost:8110 ./scripts/club-permissions-smoke.sh   (COMPOSE_PROJECT_NAME=wt_t10 ile)
# Onkosul: compose'ta MAIL_ENABLED=false ve ADMIN_EMAILS=$ADMIN_EMAIL. Tekrar calistirilabilir (rastgele sonek).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
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
    CODE=$(curl -s -o "$TMP" -w '%{http_code}' -X "$m" -H "Content-Type: application/json" -H "Authorization: Bearer $t" "$A$p")
  fi
  BODY=$(cat "$TMP")
}
step() { local name=$1 exp=$2; shift 2; call "$@"; check "$name" "$exp" "$CODE"; }
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
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
T1=$(register "csahip$SFX@bingol.edu.tr" "Sahip")
T2=$(register "cmod$SFX@bingol.edu.tr" "Moderator")
T3=$(register "cuye$SFX@bingol.edu.tr" "Uye Bir")
T4=$(register "cuye2$SFX@bingol.edu.tr" "Uye Iki")
T5=$(register "cyonetici$SFX@bingol.edu.tr" "Yonetici Aday")
TA=$(register "$ADMIN_EMAIL" "Sistem Yoneticisi")
[ -n "$T1" ] && [ -n "$T2" ] && [ -n "$T3" ] && [ -n "$T4" ] && [ -n "$T5" ] && [ -n "$TA" ] || { echo "kayit basarisiz"; exit 1; }
ID1=$(curl -s -H "Authorization: Bearer $T1" $A/users/me | idof)
ID2=$(curl -s -H "Authorization: Bearer $T2" $A/users/me | idof)
ID3=$(curl -s -H "Authorization: Bearer $T3" $A/users/me | idof)
ID4=$(curl -s -H "Authorization: Bearer $T4" $A/users/me | idof)
ID5=$(curl -s -H "Authorization: Bearer $T5" $A/users/me | idof)

echo "== kulup kurulumu"
step "olustur" 202 POST /communities "$T1" "{\"name\":\"Yetki Kulubu $SFX\",\"description\":\"test\"}"
C=$(printf '%s' "$BODY" | idof)
step "admin onayla" 204 POST /admin/communities/$C/approve "$TA"
for t in "$T2" "$T3" "$T4" "$T5"; do step "katil" 200 POST /communities/$C/join "$t"; done

echo "== sablonlar ve kendi yetkim"
step "sablonlar" 200 GET /communities/permission-templates "$T1"
contains "POST_MANAGER sablonu" "POST_MANAGER" "$BODY"
step "sahip yetkileri" 200 GET /communities/$C/permissions/me "$T1"
contains "sahipte MANAGE_ROLES" "MANAGE_ROLES" "$BODY"
step "uye yetkileri bos" 200 GET /communities/$C/permissions/me "$T3"
contains "bos kume" '"permissions":\[\]' "$BODY"

echo "== sahip yetki verir (geriye uyum: eski rol ucu)"
step "rol ucu: moderator ata" 204 PUT /communities/$C/members/$ID2/role "$T1" '{"role":"MODERATOR"}'
step "moderator bilgi gunceller" 200 PATCH /communities/$C "$T2" '{"description":"yeni"}'
step "uye bilgi guncelleyemez" 403 PATCH /communities/$C "$T3" '{"description":"x"}'
step "uye OWNER atanamaz" 400 PUT /communities/$C/members/$ID3/role "$T1" '{"role":"OWNER"}'

echo "== ince yetki: Gonderi yoneticisi"
step "T4 gonderi atar" 201 POST /communities/$C/posts "$T4" '{"text":"Merhaba kulup"}'
P=$(printf '%s' "$BODY" | idof)
step "uye baskasinin gonderisini silemez" 403 DELETE /communities/$C/posts/$P "$T3"
step "sablon ver (POST_MANAGER)" 200 PUT /communities/$C/members/$ID3/permissions "$T1" '{"template":"POST_MANAGER"}'
contains "yalniz MANAGE_POSTS" '"permissions":\["MANAGE_POSTS"\]' "$BODY"
step "gonderi yoneticisi sabitler" 204 PUT /communities/$C/posts/$P/pin "$T3"
step "gonderi yoneticisi bilgi guncelleyemez" 403 PATCH /communities/$C "$T3" '{"description":"x"}'
step "gonderi yoneticisi uye cikaramaz" 403 DELETE /communities/$C/members/$ID4 "$T3"
step "gonderi yoneticisi siler" 204 DELETE /communities/$C/posts/$P "$T3"
step "yetkiyi geri al" 200 DELETE /communities/$C/members/$ID3/permissions "$T1"
step "artik silemez (yeni gonderi)" 201 POST /communities/$C/posts "$T4" '{"text":"ikinci"}'
P2=$(printf '%s' "$BODY" | idof)
step "geri alinan yetki" 403 DELETE /communities/$C/posts/$P2 "$T3"

echo "== ince yetki: Uye yoneticisi + etkinlik sorumlusu"
step "uye yoneticisi ver" 200 PUT /communities/$C/members/$ID3/permissions "$T1" '{"template":"MEMBER_MANAGER"}'
step "uye yoneticisi davet uretir" 201 POST /communities/$C/invites "$T3" '{"maxUses":1,"validHours":2}'
step "etkinlik sorumlusu ver (T4)" 200 PUT /communities/$C/members/$ID4/permissions "$T1" '{"template":"EVENT_MANAGER"}'
START=$(date -u -d '+3 days' +%Y-%m-%dT%H:%M:%SZ)
END=$(date -u -d '+3 days 2 hours' +%Y-%m-%dT%H:%M:%SZ)
step "etkinlik sorumlusu kulup etkinligi acar" 201 POST /events "$T4" "{\"title\":\"Kulup Bulusmasi\",\"startsAt\":\"$START\",\"endsAt\":\"$END\",\"communityId\":$C}"
step "yetkisiz uye kulup etkinligi acamaz" 403 POST /events "$T5" "{\"title\":\"x yetkisiz\",\"startsAt\":\"$START\",\"endsAt\":\"$END\",\"communityId\":$C}"

echo "== yetki yukseltme saldirilari"
step "moderator uyeyi yukseltemez" 403 PUT /communities/$C/members/$ID5/permissions "$T2" '{"role":"ADMIN"}'
step "moderator kendini yukseltemez" 403 PUT /communities/$C/members/$ID2/permissions "$T2" '{"role":"ADMIN"}'
step "uye yoneticisi yetki veremez" 403 PUT /communities/$C/members/$ID5/permissions "$T3" '{"template":"POST_MANAGER"}'
step "sahip kendi yetkisini degistiremez" 400 PUT /communities/$C/members/$ID1/permissions "$T1" '{"role":"MEMBER"}'
step "sistem yoneticisi sahibin yetkisini alamaz" 403 PUT /communities/$C/members/$ID1/permissions "$TA" '{"permissions":[]}'
contains "OWNER_PROTECTED" "OWNER_PROTECTED" "$BODY"
step "moderator sahibi cikaramaz" 403 DELETE /communities/$C/members/$ID1 "$T2"
step "gecersiz yetki adi" 400 PUT /communities/$C/members/$ID5/permissions "$T1" '{"permissions":["UCMAK"]}'
step "MANAGE_ROLES yalniz ADMIN rolune" 400 PUT /communities/$C/members/$ID5/permissions "$T1" '{"permissions":["MANAGE_ROLES"]}'
step "yonetici ata (T5)" 200 PUT /communities/$C/members/$ID5/permissions "$T1" '{"role":"ADMIN"}'
step "yonetici MANAGE_ROLES'suz yetki veremez" 403 PUT /communities/$C/members/$ID4/permissions "$T5" '{"template":"POST_MANAGER"}'
step "sahip yoneticiye MANAGE_ROLES verir" 200 PUT /communities/$C/members/$ID5/permissions "$T1" '{"permissions":["MANAGE_ROLES","MANAGE_POSTS","MANAGE_MEMBERS"]}'
step "yonetici ADMIN atayamaz" 403 PUT /communities/$C/members/$ID4/permissions "$T5" '{"role":"ADMIN"}'
step "yonetici kendi disindaki yetkiyi veremez" 403 PUT /communities/$C/members/$ID4/permissions "$T5" '{"permissions":["EDIT_INFO"]}'
step "yonetici MANAGE_ROLES veremez" 403 PUT /communities/$C/members/$ID4/permissions "$T5" '{"permissions":["MANAGE_ROLES"]}'
step "yonetici alt kumeyi verebilir" 200 PUT /communities/$C/members/$ID4/permissions "$T5" '{"permissions":["MANAGE_POSTS"]}'
step "yonetici moderatoru cikarabilir degil mi: esit olmayan sira" 204 DELETE /communities/$C/members/$ID2 "$T5"

echo "== denetim kaydi"
step "sahip denetimi gorur" 200 GET /communities/$C/audit "$T1"
contains "yetki kaydi" "PERMISSIONS_SET" "$BODY"
contains "cikarma kaydi" "MEMBER_REMOVED" "$BODY"
step "duz uye denetimi goremez" 403 GET /communities/$C/audit "$T4"
step "yabanci denetimi goremez" 403 GET /communities/$C/audit "$T2"

echo "== davet kodu"
step "davet uret" 201 POST /communities/$C/invites "$T1" '{"maxUses":1,"validHours":1}'
CODE1=$(printf '%s' "$BODY" | grep -o '"code":"[^"]*' | cut -d'"' -f4)
INV=$(printf '%s' "$BODY" | idof)
step "davet listesi" 200 GET /communities/$C/invites "$T1"
lacks "listede kod acik degil" "$CODE1" "$BODY"
step "bos kodla 400" 400 POST /communities/join-by-code "$T2" '{"code":""}'
step "kod yok 404" 404 POST /communities/join-by-code "$T2" '{"code":"ZZZZZZZZZZ"}'
step "T2 koda katilir (cikarilmisti)" 200 POST /communities/join-by-code "$T2" "{\"code\":\"$CODE1\"}"
contains "ACTIVE" '"status":"ACTIVE"' "$BODY"
step "tek kullanimlik: ikinci kisi 404" 404 POST /communities/join-by-code "$TA" "{\"code\":\"$CODE1\"}"
step "iptal edilebilir" 201 POST /communities/$C/invites "$T1" '{}'
CODE2=$(printf '%s' "$BODY" | grep -o '"code":"[^"]*' | cut -d'"' -f4)
INV2=$(printf '%s' "$BODY" | idof)
step "davet iptal" 204 DELETE /communities/$C/invites/$INV2 "$T1"
step "iptal edilen kod 404" 404 POST /communities/join-by-code "$TA" "{\"code\":\"$CODE2\"}"
step "yetkisiz davet uretemez" 403 POST /communities/$C/invites "$T2" '{}'

echo "== sahiplik devri"
step "onaysiz teklif 400" 400 POST /communities/$C/ownership-transfer "$T1" "{\"targetUserId\":$ID4,\"keepAsAdmin\":true,\"confirmIrreversible\":false}"
step "sahip olmayan teklif edemez" 403 POST /communities/$C/ownership-transfer "$T5" "{\"targetUserId\":$ID4,\"keepAsAdmin\":true,\"confirmIrreversible\":true}"
step "kendine devir 400" 400 POST /communities/$C/ownership-transfer "$T1" "{\"targetUserId\":$ID1,\"keepAsAdmin\":true,\"confirmIrreversible\":true}"
step "teklif" 201 POST /communities/$C/ownership-transfer "$T1" "{\"targetUserId\":$ID4,\"keepAsAdmin\":true,\"confirmIrreversible\":true}"
step "ikinci teklif 409" 409 POST /communities/$C/ownership-transfer "$T1" "{\"targetUserId\":$ID3,\"keepAsAdmin\":true,\"confirmIrreversible\":true}"
step "bekleyen teklif hedefe gorunur" 200 GET /communities/$C/ownership-transfer "$T4"
step "ucuncu kisi goremez" 404 GET /communities/$C/ownership-transfer "$T3"
step "hedef onaysiz kabul edemez" 400 POST /communities/$C/ownership-transfer/accept "$T4" '{"confirmIrreversible":false}'
step "sahip kabul edemez" 404 POST /communities/$C/ownership-transfer/accept "$T1" '{"confirmIrreversible":true}'
step "hedef reddeder" 200 POST /communities/$C/ownership-transfer/decline "$T4"
step "yeniden teklif" 201 POST /communities/$C/ownership-transfer "$T1" "{\"targetUserId\":$ID4,\"keepAsAdmin\":true,\"confirmIrreversible\":true}"
step "sahip geri ceker" 200 DELETE /communities/$C/ownership-transfer "$T1"
step "son teklif" 201 POST /communities/$C/ownership-transfer "$T1" "{\"targetUserId\":$ID4,\"keepAsAdmin\":true,\"confirmIrreversible\":true}"
step "hedef kabul eder" 200 POST /communities/$C/ownership-transfer/accept "$T4" '{"confirmIrreversible":true}'
step "yeni sahip" 200 GET /communities/$C "$T4"
contains "ownerId degisti" "\"ownerId\":$ID4" "$BODY"
contains "T4 OWNER" '"myRole":"OWNER"' "$BODY"
step "eski sahip ADMIN" 200 GET /communities/$C "$T1"
contains "eski sahip ADMIN" '"myRole":"ADMIN"' "$BODY"
step "eski sahip artik devredemez" 403 POST /communities/$C/ownership-transfer "$T1" "{\"targetUserId\":$ID3,\"keepAsAdmin\":true,\"confirmIrreversible\":true}"
step "devir kaydi denetimde" 200 GET /communities/$C/audit "$T4"
contains "TRANSFER_ACCEPTED" "TRANSFER_ACCEPTED" "$BODY"

echo "== KVKK disa aktarim"
call GET /users/me/export "$T4"
check "export 200" 200 "$CODE"
contains "clubPermissions bolumu" "clubPermissions" "$BODY"

if [ "$FAIL" = 0 ]; then echo "TAMAM: club-permissions-smoke"; else echo "HATA VAR: club-permissions-smoke"; exit 1; fi

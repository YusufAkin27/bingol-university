#!/usr/bin/env bash
# Yonetici rol/izin matrisi (P16) icin uctan uca duman testi: profil basina izin kararlari (403 ADMIN_PERMISSION_DENIED),
# maskeli e-posta (SUPPORT/VIEWER), profil atama (dogrudan), iki kisi onayi (oneren onaylayamaz, ikinci FULL onaylar),
# kendi profili / sabitli hesap / FULL'e dogrudan atama reddi, profil degisince eski token reddi, dil (tr/en).
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ADMIN_EMAIL2=boss2@bingol.edu.tr ./scripts/smoke-admin-rbac.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur) ve ADMIN_EMAILS=$ADMIN_EMAIL,$ADMIN_EMAIL2 (iki sabit FULL yonetici:
# iki kisi onayi icin ikinci FULL gerekir), calisan postgres/redis konteynerleri. Idempotent: her calistirmada yeni kullanicilar.
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
ADMIN_EMAIL2=${ADMIN_EMAIL2:-boss2@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
notcode() { if [ "$2" != "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenmeyen $2)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 300)"; FAIL=1; fi; }
hasnt() { if echo "$3" | grep -qF -- "$2"; then echo "  FAIL $1 (bulunmamali: $2)"; FAIL=1; else echo "  ok   $1"; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

login() {
  curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4
}

register() {
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true,\"language\":\"tr\"}"
  sleep 1
  local c t
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  t=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Sifre1234\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  if [ -z "$t" ]; then t=$(login "$1"); fi
  echo "$t"
}

SFX=$RANDOM
EM="rbacmod$SFX@bingol.edu.tr"; ES="rbacsup$SFX@bingol.edu.tr"; EE="rbaced$SFX@bingol.edu.tr"
EV="rbacview$SFX@bingol.edu.tr"; EU="rbacuser$SFX@bingol.edu.tr"
R='X-Admin-Reason: duman testi sebebi'

echo "== kullanicilar"
TB=$(register "$ADMIN_EMAIL" "Yonetici Bir")
TB2=$(register "$ADMIN_EMAIL2" "Yonetici Iki")
TM=$(register "$EM" "Rbac Moderator")
TS=$(register "$ES" "Rbac Destek")
TE=$(register "$EE" "Rbac Editor")
TV=$(register "$EV" "Rbac Izleyici")
TU=$(register "$EU" "Rbac Normal")
[ -n "$TB" ] && [ -n "$TB2" ] && [ -n "$TM" ] && [ -n "$TS" ] && [ -n "$TE" ] && [ -n "$TV" ] && [ -n "$TU" ] || { echo "token yok"; exit 1; }
B="Authorization: Bearer $TB"
B2="Authorization: Bearer $TB2"
# Iki kisi onayi icin ikinci sabit FULL yonetici gerekir; yoksa ATLANDI (smoke-all: cikis kodu 2 = atlandi)
if [ "$(code -H "$B2" $A/admin/rbac/me)" != "200" ]; then
  echo "ATLANDI: ADMIN_EMAILS ikinci yonetici ($ADMIN_EMAIL2) icermiyor"
  exit 2
fi
UM=$(curl -s -H "Authorization: Bearer $TM" $A/users/me | idof)
US=$(curl -s -H "Authorization: Bearer $TS" $A/users/me | idof)
UE=$(curl -s -H "Authorization: Bearer $TE" $A/users/me | idof)
UV=$(curl -s -H "Authorization: Bearer $TV" $A/users/me | idof)
UB=$(curl -s -H "$B" $A/users/me | idof)
UB2=$(curl -s -H "$B2" $A/users/me | idof)

echo "== sabit (ADMIN_EMAILS) yoneticiler FULL"
ME=$(curl -s -H "$B" $A/admin/rbac/me)
has "boss profili FULL" '"profile":"FULL"' "$ME"
has "boss sabit" '"pinned":true' "$ME"
has "boss izinleri" '"rbac.manage"' "$ME"

echo "== yetkisiz kimlikler"
check "anonim /rbac/me" 401 "$(code $A/admin/rbac/me)"
check "normal kullanici /rbac/me" 403 "$(code -H "Authorization: Bearer $TU" $A/admin/rbac/me)"

echo "== rol ADMIN yapilinca en dar profille (VIEWER) baslar"
for u in $UM $US $UE $UV; do
  check "rol ADMIN $u" 204 "$(code -X PATCH -H "$B" -H "$H" -H "$R" $A/admin/users/$u/role -d '{"role":"ADMIN"}')"
done
TV1=$(login "$EV")
VME=$(curl -s -H "Authorization: Bearer $TV1" $A/admin/rbac/me)
has "yeni yonetici VIEWER" '"profile":"VIEWER"' "$VME"

echo "== profil atama (dogrudan): VIEWER -> MODERATOR / SUPPORT / EDITOR"
RB='{"profile":"%s","reason":"duman testi atamasi"}'
check "kisa sebep reddi" 400 "$(code -X PUT -H "$B" -H "$H" $A/admin/rbac/users/$UM/profile -d '{"profile":"MODERATOR","reason":"x"}')"
check "MODERATOR ata" 204 "$(code -X PUT -H "$B" -H "$H" $A/admin/rbac/users/$UM/profile -d "$(printf "$RB" MODERATOR)")"
check "SUPPORT ata" 204 "$(code -X PUT -H "$B" -H "$H" $A/admin/rbac/users/$US/profile -d "$(printf "$RB" SUPPORT)")"
check "EDITOR ata" 204 "$(code -X PUT -H "$B" -H "$H" $A/admin/rbac/users/$UE/profile -d "$(printf "$RB" EDITOR)")"
check "ayni profil tekrar" 409 "$(code -X PUT -H "$B" -H "$H" $A/admin/rbac/users/$UE/profile -d "$(printf "$RB" EDITOR)")"
check "FULL'e dogrudan atama" 409 "$(code -X PUT -H "$B" -H "$H" $A/admin/rbac/users/$UE/profile -d "$(printf "$RB" FULL)")"
has "FULL'e dogrudan atama kodu" RBAC_APPROVAL_REQUIRED "$(curl -s -X PUT -H "$B" -H "$H" $A/admin/rbac/users/$UE/profile -d "$(printf "$RB" FULL)")"
has "kendi profili" RBAC_SELF_CHANGE "$(curl -s -X PUT -H "$B" -H "$H" $A/admin/rbac/users/$UB/profile -d "$(printf "$RB" VIEWER)")"
has "sabit hesap" ADMIN_EMAIL_PINNED "$(curl -s -X PUT -H "$B2" -H "$H" $A/admin/rbac/users/$UB/profile -d "$(printf "$RB" VIEWER)")"
check "normal kullaniciya profil" 409 "$(code -X PUT -H "$B" -H "$H" $A/admin/rbac/users/$(curl -s -H "Authorization: Bearer $TU" $A/users/me | idof)/profile -d "$(printf "$RB" VIEWER)")"

# yeni profille taze token
TM=$(login "$EM"); TS=$(login "$ES"); TE=$(login "$EE"); TV=$(login "$EV")
M="Authorization: Bearer $TM"; S="Authorization: Bearer $TS"; E="Authorization: Bearer $TE"; V="Authorization: Bearer $TV"
has "MODERATOR /rbac/me" '"profile":"MODERATOR"' "$(curl -s -H "$M" $A/admin/rbac/me)"
has "SUPPORT /rbac/me" '"profile":"SUPPORT"' "$(curl -s -H "$S" $A/admin/rbac/me)"
has "EDITOR /rbac/me" '"profile":"EDITOR"' "$(curl -s -H "$E" $A/admin/rbac/me)"

echo "== FULL (boss): her sey acik"
for p in users reports audit ops/health settings support/tickets news analytics/overview rbac/admins; do
  check "FULL GET $p" 200 "$(code -H "$B" $A/admin/$p)"
done

echo "== MODERATOR: kullanici/moderasyon/sohbet acik; rol, ayar, denetim, kampanya kapali"
check "MOD users" 200 "$(code -H "$M" $A/admin/users)"
check "MOD reports" 200 "$(code -H "$M" $A/admin/reports)"
notcode "MOD chat-messages" 403 "$(code -H "$M" $A/admin/chat-messages)"
check "MOD users/role" 403 "$(code -X PATCH -H "$M" -H "$H" -H "$R" $A/admin/users/$UV/role -d '{"role":"USER"}')"
check "MOD users delete" 403 "$(code -X DELETE -H "$M" -H "$R" $A/admin/users/$UV)"
check "MOD audit" 403 "$(code -H "$M" $A/admin/audit)"
check "MOD ops" 403 "$(code -H "$M" $A/admin/ops/health)"
check "MOD ayar yaz" 403 "$(code -X PUT -H "$M" -H "$H" $A/admin/settings/banner_text -d '{"value":"x"}')"
check "MOD kampanya" 403 "$(code -X POST -H "$M" -H "$H" $A/admin/push/campaigns -d '{}')"
check "MOD rbac yonetimi" 403 "$(code -H "$M" $A/admin/rbac/admins)"
has "MOD kullanici e-postasi maskesiz" "$EV" "$(curl -s -H "$M" "$A/admin/users?q=rbacview$SFX")"

echo "== SUPPORT: destek acik, kullanici e-postasi MASKELI; sohbet/rapor/oturum kapali"
check "SUP users" 200 "$(code -H "$S" $A/admin/users)"
SL=$(curl -s -H "$S" "$A/admin/users?q=rbacview$SFX")
has "SUP e-posta maskeli" "r***@bingol.edu.tr" "$SL"
hasnt "SUP tam e-posta yok" "$EV" "$SL"
check "SUP destek talepleri" 200 "$(code -H "$S" $A/admin/support/tickets)"
check "SUP reports" 403 "$(code -H "$S" $A/admin/reports)"
check "SUP chat-messages" 403 "$(code -H "$S" $A/admin/chat-messages)"
check "SUP kullanici oturumlari" 403 "$(code -H "$S" $A/admin/users/$UV/sessions)"
check "SUP kullanici suspend" 403 "$(code -X POST -H "$S" -H "$H" -H "$R" $A/admin/users/$UV/suspend -d '{"reason":"x"}')"
check "SUP kampanya" 403 "$(code -X POST -H "$S" -H "$H" $A/admin/push/campaigns -d '{}')"
notcode "SUP tek kullanici bildirimi izin katmanini gecer" 403 "$(code -X POST -H "$S" -H "$H" $A/admin/push/users/$UV/send -d '{}')"

echo "== EDITOR: icerik acik; kullanici/moderasyon/denetim kapali"
check "EDITOR news" 200 "$(code -H "$E" $A/admin/news)"
check "EDITOR menu" 200 "$(code -H "$E" $A/admin/menu)"
check "EDITOR users" 403 "$(code -H "$E" $A/admin/users)"
check "EDITOR reports" 403 "$(code -H "$E" $A/admin/reports)"
check "EDITOR audit" 403 "$(code -H "$E" $A/admin/audit)"
check "EDITOR kampanya" 403 "$(code -X POST -H "$E" -H "$H" $A/admin/push/campaigns -d '{}')"
check "EDITOR sozlesme yayin" 403 "$(code -X POST -H "$E" -H "$H" -H "$R" $A/admin/legal/terms -d '{}')"
check "EDITOR bilinmeyen modul (varsayilan: yalniz FULL)" 404 "$(code -H "$B" $A/admin/yeni-bilinmeyen-modul)"

echo "== VIEWER: her sey salt okunur; e-posta maskeli; yazma ve sohbet kapali"
check "VIEWER users" 200 "$(code -H "$V" $A/admin/users)"
VL=$(curl -s -H "$V" "$A/admin/users?q=rbacview$SFX")
hasnt "VIEWER tam e-posta yok" "$EV" "$VL"
check "VIEWER audit" 200 "$(code -H "$V" $A/admin/audit)"
check "VIEWER ops" 200 "$(code -H "$V" $A/admin/ops/health)"
check "VIEWER settings" 200 "$(code -H "$V" $A/admin/settings)"
check "VIEWER chat-messages" 403 "$(code -H "$V" $A/admin/chat-messages)"
check "VIEWER faq yaz" 403 "$(code -X POST -H "$V" -H "$H" $A/admin/faq -d '{}')"
check "VIEWER users export" 403 "$(code -H "$V" $A/admin/users/export.csv)"

echo "== 403 govdesi: kod + dil"
D=$(curl -s -H "$V" -H 'Accept-Language: en' -X PATCH -H "$H" -H "$R" $A/admin/users/$UM/role -d '{"role":"USER"}')
has "kod" ADMIN_PERMISSION_DENIED "$D"
has "gereken izin" users.role "$D"
has "EN metin" "You do not have permission" "$D"
DT=$(curl -s -H "$V" -X PATCH -H "$H" -H "$R" $A/admin/users/$UM/role -d '{"role":"USER"}')
has "TR metin" "yetkiniz yok" "$DT"

echo "== iki kisi onayi: VIEWER -> FULL"
PR=$(curl -s -X POST -H "$B" -H "$H" $A/admin/rbac/changes -d "{\"userId\":$UV,\"profile\":\"FULL\",\"reason\":\"ikinci FULL yonetici gerekli\"}")
has "oneri olustu" '"status":"PENDING"' "$PR"
CID=$(echo "$PR" | idof)
check "bekleyen oneri varken ikincisi" 409 "$(code -X POST -H "$B" -H "$H" $A/admin/rbac/changes -d "{\"userId\":$UV,\"profile\":\"FULL\",\"reason\":\"tekrar oneri denemesi\"}")"
has "oneren onaylayamaz" RBAC_SAME_APPROVER "$(curl -s -X POST -H "$B" $A/admin/rbac/changes/$CID/approve)"
check "yetkisiz profil onaylayamaz" 403 "$(code -X POST -H "$V" $A/admin/rbac/changes/$CID/approve)"
has "bekleyenler listesinde" "\"id\":$CID" "$(curl -s -H "$B2" "$A/admin/rbac/changes?status=PENDING")"
AP=$(curl -s -X POST -H "$B2" -H "$H" $A/admin/rbac/changes/$CID/approve -d '{"note":"onayladim"}')
has "ikinci FULL onayladi" '"status":"APPROVED"' "$AP"
has "tekrar karar yok" RBAC_CHANGE_DECIDED "$(curl -s -X POST -H "$B2" $A/admin/rbac/changes/$CID/reject)"
# profil degisince eski token reddedilir (rolechg isareti); taze token FULL
check "eski token reddi" 401 "$(code -H "$V" $A/admin/rbac/me)"
TV2=$(login "$EV")
has "taze token FULL" '"profile":"FULL"' "$(curl -s -H "Authorization: Bearer $TV2" $A/admin/rbac/me)"
check "yeni FULL denetimi gorur" 200 "$(code -H "Authorization: Bearer $TV2" $A/admin/audit)"

echo "== W1-B: yuzde-kodlu yol, hiyerarsi, users.verify, FULL rol dusurme (T-010/T-011/T-012/T-014)"
UU=$(curl -s -H "Authorization: Bearer $TU" $A/users/me | idof)
# yuzde-kodlu harf segmenti: 400 ADMIN_PATH_INVALID (kodsuz yol 403, kodlu yol da yetki atlatamaz)
check "SUPPORT kodsuz sohbet yolu" 403 "$(code -H "$S" $A/admin/users/$UU/conversations)"
check "SUPPORT kodlu sohbet yolu" 400 "$(code -g -H "$S" "$A/admin/users/$UU/%63onversations")"
has "kodlu yol kodu" ADMIN_PATH_INVALID "$(curl -s -g -H "$S" "$A/admin/users/$UU/%63onversations")"
check "SUPPORT kodlu CSV yolu" 400 "$(code -g -H "$S" "$A/admin/users/%65xport.csv")"
check "MOD kodlu rol yolu" 400 "$(code -g -X PATCH -H "$M" -H "$H" -H "$R" "$A/admin/users/$UV/%72ole" -d '{"role":"USER"}')"
check "kodlu yonetici on eki" 400 "$(code -g -H "$B" "$BASE/%61pi/admin/users")" # /%61pi: yonetici yolu cozulunce 400
# HEAD de GET kurallariyla degerlendirilir
check "SUPPORT HEAD sohbet 403" 403 "$(code -I -H "$S" $A/admin/users/$UU/conversations)"
# users.verify yalniz FULL + gerekce
check "MOD verify-email 403" 403 "$(code -X POST -H "$M" -H "$R" $A/admin/users/$UU/verify-email)"
check "FULL verify-email gerekcesiz 400" 400 "$(code -X POST -H "$B" $A/admin/users/$UU/verify-email)"
check "FULL verify-email gerekceli" 204 "$(code -X POST -H "$B" -H "$R" $A/admin/users/$UU/verify-email)"
check "MOD bekleyen kayit dogrulama 403" 403 "$(code -X POST -H "$M" -H "$R" $A/admin/pending-registrations/yok$SFX@bingol.edu.tr/verify)"
# hiyerarsi: MODERATOR, FULL yonetici hesabina mudahale edemez
check "MOD -> FULL oturum kapatma" 403 "$(code -X POST -H "$M" -H "$R" $A/admin/users/$UV/revoke-sessions)"
has "hiyerarsi kodu" ADMIN_TARGET_FORBIDDEN "$(curl -s -X POST -H "$M" -H "$R" $A/admin/users/$UV/revoke-sessions)"
check "MOD -> FULL sifirlama" 403 "$(code -X POST -H "$M" -H "$R" $A/admin/users/$UV/send-reset)"
check "MOD -> FULL profil mudahalesi" 403 "$(code -X PATCH -H "$M" -H "$H" -H "$R" $A/admin/users/$UV/profile -d '{"clearBio":true}')"
# FULL hedefin rolu tek basina dusurulemez (iki kisi onayi); kullanici silme de
check "FULL hedef rol dusurme 409" 409 "$(code -X PATCH -H "$B" -H "$H" -H "$R" $A/admin/users/$UV/role -d '{"role":"USER"}')"
has "FULL hedef rol dusurme kodu" RBAC_APPROVAL_REQUIRED "$(curl -s -X PATCH -H "$B" -H "$H" -H "$R" $A/admin/users/$UV/role -d '{"role":"USER"}')"
check "FULL hedef silme 409" 409 "$(code -X DELETE -H "$B" -H "$R" $A/admin/users/$UV)"
# reddedilen istek denetimde basari ozeti tasimaz
has "reddedilen istek denetimi" 'BASARISIZ: HTTP 409' "$(curl -s -H "$B" "$A/admin/audit?targetType=USER&targetId=$UV&status=4xx&size=20")"

echo "== FULL dusurme de iki kisi onayi ister"
has "dogrudan dusurme reddi" RBAC_APPROVAL_REQUIRED "$(curl -s -X PUT -H "$B" -H "$H" $A/admin/rbac/users/$UV/profile -d "$(printf "$RB" VIEWER)")"
PR2=$(curl -s -X POST -H "$B2" -H "$H" $A/admin/rbac/changes -d "{\"userId\":$UV,\"profile\":\"VIEWER\",\"reason\":\"gecici FULL geri aliniyor\"}")
CID2=$(echo "$PR2" | idof)
RJ=$(curl -s -X POST -H "$B2" -H "$H" $A/admin/rbac/changes/$CID2/reject -d '{"note":"vazgectim"}')
has "oneren geri cekebilir" '"status":"REJECTED"' "$RJ"
PR3=$(curl -s -X POST -H "$B2" -H "$H" $A/admin/rbac/changes -d "{\"userId\":$UV,\"profile\":\"VIEWER\",\"reason\":\"gecici FULL geri aliniyor\"}")
CID3=$(echo "$PR3" | idof)
has "dusurme onaylandi" '"status":"APPROVED"' "$(curl -s -X POST -H "$B" -H "$H" $A/admin/rbac/changes/$CID3/approve)"
TV3=$(login "$EV")
has "taze token VIEWER" '"profile":"VIEWER"' "$(curl -s -H "Authorization: Bearer $TV3" $A/admin/rbac/me)"
check "dusurulen FULL artik rbac yonetemez" 403 "$(code -H "Authorization: Bearer $TV3" $A/admin/rbac/admins)"

echo "== denetim kaydi"
AU=$(curl -s -H "$B" "$A/admin/audit?size=50")
has "profil degisikligi denetimde" "yonetici profili" "$AU"

echo "== matris"
MX=$(curl -s -H "Authorization: Bearer $TV3" $A/admin/rbac/matrix)
has "matris 5 profil" '"profiles":["FULL","MODERATOR","SUPPORT","EDITOR","VIEWER"]' "$MX"
has "matris izin" '"permission":"users.role"' "$MX"

if [ "$FAIL" = 0 ]; then echo "TAMAM: yonetici izin matrisi duman testi gecti"; else echo "BASARISIZ"; exit 1; fi

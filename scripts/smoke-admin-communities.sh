#!/usr/bin/env bash
# Yonetici kulup derin yonetimi + kulup icerigi moderasyonu (P06/P10) duman testi (curl).
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ./scripts/smoke-admin-communities.sh
# Onkosul: calisan yigin, MAIL_ENABLED=false (kod log'dan okunur), ADMIN_EMAILS=$ADMIN_EMAIL. app.admin.require-reason acik
# varsayilanda: yikici uclar X-Admin-Reason ister. Idempotent: her calistirmada benzersiz adlar; test kulupleri sonunda silinir.
# Betikler arasinda: docker compose exec -T redis redis-cli flushall (kayit ucu IP basina saatte 10 ile sinirli).
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
E1="clb1x$SFX@bingol.edu.tr"; E2="clb2x$SFX@bingol.edu.tr"; E3="clb3x$SFX@bingol.edu.tr"
TAG="SmokeKulup$SFX"

echo "== hazirlik: yonetici + 3 kullanici"
TA=$(register "$ADMIN_EMAIL" "Yonetici")
[ -n "$TA" ] || { echo "admin token yok (ADMIN_EMAILS ayarli mi?)"; exit 1; }
AAD="Authorization: Bearer $TA"
T1=$(register "$E1" "Kulup Sahibi"); T2=$(register "$E2" "Kulup Uyesi"); T3=$(register "$E3" "Kulup Hedefi")
[ -n "$T1" ] && [ -n "$T2" ] && [ -n "$T3" ] || { echo "kayit basarisiz"; exit 1; }
A1="Authorization: Bearer $T1"; A2="Authorization: Bearer $T2"; A3="Authorization: Bearer $T3"
ID1=$(curl -s -H "$A1" $A/users/me | idof); ID2=$(curl -s -H "$A2" $A/users/me | idof); ID3=$(curl -s -H "$A3" $A/users/me | idof)

echo "== yetki"
check "anonim liste 401" 401 "$(code "$A/admin/communities?page=0")"
check "kullanici liste 403" 403 "$(code -H "$A1" "$A/admin/communities?page=0")"
check "kullanici icerik 403" 403 "$(code -H "$A1" "$A/admin/community-posts")"

echo "== kulup olustur (kullanici) + uyeler"
CID=$(curl -s -X POST -H "$H" -H "$A1" $A/communities -d "{\"name\":\"$TAG\",\"description\":\"duman testi\",\"joinPolicy\":\"OPEN\",\"visibility\":\"PUBLIC\"}" | idof)
[ -n "$CID" ] || { echo "kulup olusmadi"; exit 1; }
check "uye2 katilir" 200 "$(code -X POST -H "$A2" $A/communities/$CID/join)"
check "hedef katilir" 200 "$(code -X POST -H "$A3" $A/communities/$CID/join)"

echo "== liste / suzgec / ayrinti / CSV"
L=$(curl -s -H "$AAD" "$A/admin/communities?page=0&size=5&q=$TAG")
has "liste: kulup bulunur" "\"name\":\"$TAG\"" "$L"
has "liste: sayfa alanlari" "\"totalPages\"" "$L"
check "gecersiz siralama 400" 400 "$(code -H "$AAD" "$A/admin/communities?page=0&sort=owner_id")"
check "eski onay kuyrugu ucu calisir" 200 "$(code -H "$AAD" "$A/admin/communities?status=PENDING_REVIEW")"
D=$(curl -s -H "$AAD" $A/admin/communities/$CID)
has "ayrinti: yetenekler" "\"canClose\":true" "$D"
CSV=$(curl -s -H "$AAD" "$A/admin/communities/export.csv?q=$TAG")
has "csv basligi" "id,ad,slug" "$CSV"
has "csv satiri" "$TAG" "$CSV"

echo "== duzenleme (sebep gerekmez)"
check "patch ad" 200 "$(code -X PATCH -H "$H" -H "$AAD" $A/admin/communities/$CID -d "{\"name\":\"$TAG Duzenli\"}")"
has "ad degisti" "$TAG Duzenli" "$(curl -s -H "$AAD" $A/admin/communities/$CID)"
check "bos patch 400" 400 "$(code -X PATCH -H "$H" -H "$AAD" $A/admin/communities/$CID -d '{}')"

echo "== uye rolu / cikarma"
check "rol: sebepsiz 400" 400 "$(code -X PATCH -H "$H" -H "$AAD" $A/admin/communities/$CID/members/$ID2/role -d '{"role":"MODERATOR"}')"
check "rol: MODERATOR" 200 "$(code -X PATCH -H "$H" -H "$AAD" -H 'X-Admin-Reason: duman testi rol' $A/admin/communities/$CID/members/$ID2/role -d '{"role":"MODERATOR"}')"
check "rol: OWNER verilemez" 400 "$(code -X PATCH -H "$H" -H "$AAD" -H 'X-Admin-Reason: duman testi rol' $A/admin/communities/$CID/members/$ID2/role -d '{"role":"OWNER"}')"
check "sahibin rolu dusurulemez" 409 "$(code -X PATCH -H "$H" -H "$AAD" -H 'X-Admin-Reason: duman testi rol' $A/admin/communities/$CID/members/$ID1/role -d '{"role":"MEMBER"}')"
check "sahip cikarilamaz" 403 "$(code -X DELETE -H "$AAD" -H 'X-Admin-Reason: duman testi cikar' $A/admin/communities/$CID/members/$ID1)"
check "uye listesi" 200 "$(code -H "$AAD" "$A/admin/communities/$CID/members?role=MODERATOR")"

echo "== gonderi / duyuru moderasyonu"
PID=$(curl -s -X POST -H "$H" -H "$A2" $A/communities/$CID/posts -d '{"text":"duman gonderisi"}' | idof)
[ -n "$PID" ] || { echo "gonderi olusmadi"; FAIL=1; }
has "icerik listesinde" "duman gonderisi" "$(curl -s -H "$AAD" "$A/admin/community-posts?communityId=$CID")"
check "metin duzenle" 200 "$(code -X PATCH -H "$H" -H "$AAD" $A/admin/community-posts/$PID -d '{"text":"duzenlenmis gonderi"}')"
check "gizle" 200 "$(code -X POST -H "$H" -H "$AAD" $A/admin/community-posts/$PID/hide -d '{"reason":"deneme"}')"
hasnt "gizli gonderi kulup akisinda yok" "duzenlenmis gonderi" "$(curl -s -H "$A2" $A/communities/$CID/posts)"
check "geri al" 200 "$(code -X POST -H "$H" -H "$AAD" $A/admin/community-posts/$PID/unhide)"
has "geri alinan gonderi akista" "duzenlenmis gonderi" "$(curl -s -H "$A2" $A/communities/$CID/posts)"
check "silme sebepsiz 400" 400 "$(code -X DELETE -H "$AAD" $A/admin/community-posts/$PID)"
check "silme" 200 "$(code -X DELETE -H "$AAD" -H 'X-Admin-Reason: duman testi sil' $A/admin/community-posts/$PID)"
check "silinen tekrar 404" 404 "$(code -X DELETE -H "$AAD" -H 'X-Admin-Reason: duman testi sil' $A/admin/community-posts/$PID)"

echo "== kapat / yeniden ac"
check "kapat sebepsiz 400" 400 "$(code -X POST -H "$AAD" $A/admin/communities/$CID/close)"
check "kapat" 200 "$(code -X POST -H "$AAD" -H 'X-Admin-Reason: duman testi kapat' $A/admin/communities/$CID/close)"
check "kapaliyken tekrar kapat 409" 409 "$(code -X POST -H "$AAD" -H 'X-Admin-Reason: duman testi kapat' $A/admin/communities/$CID/close)"
check "yeniden ac" 200 "$(code -X POST -H "$AAD" -H 'X-Admin-Reason: duman testi ac' $A/admin/communities/$CID/reopen)"

echo "== zorla devir"
check "devir: uye olmayan hedef 400" 400 "$(code -X POST -H "$H" -H "$AAD" -H 'X-Admin-Reason: duman testi devir' $A/admin/communities/$CID/transfer-ownership -d '{"targetUserId":99999999}')"
check "devir" 200 "$(code -X POST -H "$H" -H "$AAD" -H 'X-Admin-Reason: duman testi devir' $A/admin/communities/$CID/transfer-ownership -d "{\"targetUserId\":$ID3,\"keepAsAdmin\":true}")"
has "yeni sahip" "\"ownerId\":$ID3" "$(curl -s -H "$AAD" $A/admin/communities/$CID)"

echo "== denetim"
has "COMMUNITY hedefli denetim" "\"targetType\":\"COMMUNITY\"" "$(curl -s -H "$AAD" "$A/admin/audit?targetType=COMMUNITY&targetId=$CID")"
has "kulup ici denetim" "ADMIN_OWNER_TRANSFER" "$(curl -s -H "$AAD" $A/admin/communities/$CID/club-audit)"

echo "== silme (geri alinamaz)"
check "silme sebepsiz 400" 400 "$(code -X DELETE -H "$AAD" $A/admin/communities/$CID)"
R=$(curl -s -X DELETE -H "$AAD" -H 'X-Admin-Reason: duman testi temizlik' $A/admin/communities/$CID)
has "silindi + irreversible" "\"irreversible\":true" "$R"
check "silinen kulup kullaniciya 404" 404 "$(code -H "$A2" $A/communities/$CID)"
check "silinen tekrar silinemez" 404 "$(code -X DELETE -H "$AAD" -H 'X-Admin-Reason: duman testi temizlik' $A/admin/communities/$CID)"

if [ "$FAIL" = 0 ]; then echo "TAMAM: yonetici kulup duman testi gecti"; else echo "BASARISIZ: yukaridaki FAIL satirlarina bakin"; exit 1; fi

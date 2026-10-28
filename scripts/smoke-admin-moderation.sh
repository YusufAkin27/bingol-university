#!/usr/bin/env bash
# P11 duman testi (yonetici moderasyon tamamlama): yetki, ihlal listesi/afi, gizlenen icerik, sebep sablonu CRUD +
# eski uc geriye uyumu, rapor/itiraz CSV (BOM + baslik). Calisan compose yigina karsi, tekrar calistirilabilir, ASCII.
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ./scripts/smoke-admin-moderation.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur), ADMIN_EMAILS=$ADMIN_EMAIL, V730 migration uygulanmis.
# Not: ihlal AFFININ sayac etkisi birim/HTTP testlerinde dogrulanir (H2); burada tohum veri gerektirmeyen yollar denenir.
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 300)"; FAIL=1; fi; }
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
UE="smkmod$SFX@bingol.edu.tr"
echo "== hazirlik"
TA=$(register "$ADMIN_EMAIL" "Yonetici" )
TU=$(register "$UE" "Smoke Moderasyon")
[ -n "$TA" ] && [ -n "$TU" ] || { echo "token alinamadi (ADMIN_EMAILS ayarli mi?)"; exit 1; }
AD="Authorization: Bearer $TA"; US="Authorization: Bearer $TU"
UID1=$(curl -s -H "$US" $A/users/me | idof)

echo "== yetki"
for p in "moderation/strikes" "moderation/hidden" "moderation/reason-templates" "reports/export.csv" "appeals/export.csv"; do
  check "anonim $p" 401 "$(code $A/admin/$p)"
  check "kullanici $p" 403 "$(code -H "$US" $A/admin/$p)"
done

echo "== ihlal listesi ve af"
R=$(curl -s -H "$AD" "$A/admin/moderation/strikes?status=ALL&size=5")
has "liste bicimi" '"totalPages"' "$R"
has "liste items" '"items"' "$R"
check "kullanici ihlalleri (var)" 200 "$(code -H "$AD" $A/admin/users/$UID1/strikes)"
check "kullanici ihlalleri (yok)" 404 "$(code -H "$AD" $A/admin/users/999999999/strikes)"
check "af: kayit yok" 404 "$(code -X POST -H "$H" -H "$AD" $A/admin/moderation/strikes/999999999/forgive -d '{"reason":"yeterince uzun sebep"}')"
check "af: kisa sebep" 400 "$(code -X POST -H "$H" -H "$AD" $A/admin/moderation/strikes/1/forgive -d '{"reason":"kisa"}')"
check "af: anonim" 401 "$(code -X POST -H "$H" $A/admin/moderation/strikes/1/forgive -d '{"reason":"yeterince uzun sebep"}')"

echo "== gizlenen icerik"
has "gizli liste bicimi" '"totalPages"' "$(curl -s -H "$AD" "$A/admin/moderation/hidden?size=5")"
check "geri al: gizli degil" 404 "$(code -X POST -H "$H" -H "$AD" $A/admin/moderation/hidden/POST/999999999/restore -d '{"reason":"yeterince uzun sebep"}')"
check "geri al: gecersiz tur" 400 "$(code -X POST -H "$H" -H "$AD" $A/admin/moderation/hidden/NOPE/1/restore -d '{"reason":"yeterince uzun sebep"}')"

echo "== sebep sablonlari (V730 tohumu + CRUD + eski uc)"
LEG=$(curl -s -H "$AD" $A/admin/reports/reason-templates)
has "eski uc: SPAM" '"code":"SPAM"' "$LEG"
has "eski uc: texts" '"texts"' "$LEG"
TL=$(curl -s -H "$AD" $A/admin/moderation/reason-templates)
has "yonetim listesi: tohum" '"code":"OTHER"' "$TL"
has "yonetim listesi: ust sinir" '"max":50' "$TL"
CODE="SMK$SFX"
C=$(curl -s -X POST -H "$H" -H "$AD" $A/admin/moderation/reason-templates -d "{\"code\":\"$CODE\",\"textTr\":\"Smoke sablonu\",\"textEn\":\"Smoke template\"}")
TID=$(echo "$C" | idof)
[ -n "$TID" ] && echo "  ok   sablon olusturuldu (#$TID)" || { echo "  FAIL sablon olusmadi: $C"; FAIL=1; }
check "ayni kod" 409 "$(code -X POST -H "$H" -H "$AD" $A/admin/moderation/reason-templates -d "{\"code\":\"$CODE\",\"textTr\":\"x\"}")"
has "eski uc yeni sablonu da dondurur" "\"code\":\"$CODE\"" "$(curl -s -H "$AD" $A/admin/reports/reason-templates)"
check "sablon guncelle (pasif)" 200 "$(code -X PUT -H "$H" -H "$AD" $A/admin/moderation/reason-templates/$TID -d '{"textTr":"Smoke sablonu 2","active":false}')"
hasnt() { if echo "$3" | grep -qF -- "$2"; then echo "  FAIL $1 (bulunmamali: $2)"; FAIL=1; else echo "  ok   $1"; fi; }
hasnt "pasif sablon eski uctan kalkar" "\"code\":\"$CODE\"" "$(curl -s -H "$AD" $A/admin/reports/reason-templates)"
check "sablon sil: sebepsiz" 400 "$(code -X DELETE -H "$AD" $A/admin/moderation/reason-templates/$TID)"
check "sablon sil" 204 "$(code -X DELETE -H "$AD" -H 'X-Admin-Reason: smoke temizligi' $A/admin/moderation/reason-templates/$TID)"
check "sablon yok" 404 "$(code -X DELETE -H "$AD" -H 'X-Admin-Reason: smoke temizligi' $A/admin/moderation/reason-templates/$TID)"

echo "== CSV"
RC=$(curl -s -D - -H "$AD" "$A/admin/reports/export.csv?status=ALL" | head -c 600)
has "rapor csv: tur" 'text/csv' "$RC"
has "rapor csv: baslik" 'id,durum,karar' "$RC"
AC=$(curl -s -D - -H "$AD" "$A/admin/appeals/export.csv" | head -c 600)
has "itiraz csv: baslik" 'id,durum,kullaniciId' "$AC"

echo
[ "$FAIL" = 0 ] && echo "TUMU TAMAM" || { echo "HATA VAR"; exit 1; }

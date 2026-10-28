#!/usr/bin/env bash
# P15 duman testi (yonetici toplu islemler): haber toplu gizle/goster + CSV, akademik toplu islem + CSV, menu CSV/toplu silme,
# bekleyen kayit toplu iptal + maskeli CSV, kaynak durumu. Calisan compose yigina karsi, ASCII, tekrar calistirilabilir.
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ./scripts/smoke-admin-bulk.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur), ADMIN_EMAILS=$ADMIN_EMAIL.
# Kaynak siteye istek atan elle senkron YALNIZ SYNC=1 ile denenir (saatte 3 sinir: varsayilan atlanir).
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
UE="smkbulk$SFX@bingol.edu.tr"
echo "== hazirlik"
TA=$(register "$ADMIN_EMAIL" "Yonetici")
TU=$(register "$UE" "Smoke Toplu")
[ -n "$TA" ] && [ -n "$TU" ] || { echo "token alinamadi (ADMIN_EMAILS ayarli mi?)"; exit 1; }
AD="Authorization: Bearer $TA"; US="Authorization: Bearer $TU"

echo "== yetki"
for p in news/export.csv "academic/export.csv?entity=EXAM" menu/export.csv pending-registrations/export.csv sources/status; do
  check "anonim GET $p" 401 "$(code $A/admin/$p)"
  check "kullanici GET $p" 403 "$(code -H "$US" $A/admin/$p)"
done
for p in news/bulk academic/bulk menu/bulk-delete pending-registrations/bulk-cancel sources/sync; do
  check "anonim POST $p" 401 "$(code -X POST -H "$H" $A/admin/$p -d '{}')"
  check "kullanici POST $p" 403 "$(code -X POST -H "$H" -H "$US" $A/admin/$p -d '{}')"
done

echo "== haber: toplu gizle/goster"
NEWS=$(curl -s -H "$AD" "$A/admin/news?size=2")
IDS=$(echo "$NEWS" | grep -o '"id":[0-9]*' | cut -d: -f2 | head -2 | paste -sd, -)
if [ -n "$IDS" ]; then
  check "sebepsiz toplu gizle" 400 "$(code -X POST -H "$H" -H "$AD" $A/admin/news/bulk -d "{\"action\":\"HIDE\",\"ids\":[$IDS]}")"
  R=$(curl -s -X POST -H "$H" -H "$AD" $A/admin/news/bulk -d "{\"action\":\"HIDE\",\"ids\":[$IDS,987654321],\"reason\":\"smoke toplu gizleme\"}")
  has "rapor requested" '"requested":' "$R"
  has "olmayan kayit atlandi" 'NOT_FOUND' "$R"
  R2=$(curl -s -X POST -H "$H" -H "$AD" $A/admin/news/bulk -d "{\"action\":\"HIDE\",\"ids\":[$IDS],\"reason\":\"smoke tekrar\"}")
  has "tekrar gizleme atlanir" 'ALREADY_DONE' "$R2"
  curl -s -o /dev/null -X POST -H "$H" -H "$AD" $A/admin/news/bulk -d "{\"action\":\"UNHIDE\",\"ids\":[$IDS],\"reason\":\"smoke geri goster\"}"
else
  echo "  (haber yok: toplu haber adimi atlandi)"
fi
BIG=$(seq 900000001 900000201 | paste -sd, -)
BR=$(curl -s -X POST -H "$H" -H "$AD" $A/admin/news/bulk -d "{\"action\":\"HIDE\",\"ids\":[$BIG],\"reason\":\"smoke sinir\"}")
has "201 kayit -> BULK_LIMIT_EXCEEDED" 'BULK_LIMIT_EXCEEDED' "$BR"
CSV=$(curl -s -H "$AD" "$A/admin/news/export.csv?hidden=false")
has "haber CSV baslik" 'id,type,title,url' "$CSV"

echo "== akademik"
check "entity yok CSV" 400 "$(code -H "$AD" $A/admin/academic/export.csv)"
check "takvim CSV" 200 "$(code -H "$AD" "$A/admin/academic/export.csv?entity=CALENDAR")"
check "sinav CSV" 200 "$(code -H "$AD" "$A/admin/academic/export.csv?entity=EXAM")"
check "duyuru CSV" 200 "$(code -H "$AD" "$A/admin/academic/export.csv?entity=ANNOUNCEMENT")"
EV=$(curl -s -X POST -H "$H" -H "$AD" $A/admin/academic/events -d "{\"kind\":\"TATIL\",\"title\":\"=Smoke toplu $SFX\",\"startsAt\":\"2031-05-01\",\"allDay\":true,\"published\":false}")
EID=$(echo "$EV" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
if [ -n "$EID" ]; then
  R=$(curl -s -X POST -H "$H" -H "$AD" $A/admin/academic/bulk -d "{\"entity\":\"CALENDAR\",\"action\":\"PUBLISH\",\"ids\":[$EID],\"reason\":\"smoke yayin\"}")
  has "yayinlandi" '"done":1' "$R"
  R=$(curl -s -X POST -H "$H" -H "$AD" $A/admin/academic/bulk -d "{\"entity\":\"CALENDAR\",\"action\":\"PUBLISH\",\"ids\":[$EID],\"reason\":\"smoke yayin\"}")
  has "tekrar yayin atlandi" 'ALREADY_DONE' "$R"
  ACSV=$(curl -s -H "$AD" "$A/admin/academic/export.csv?entity=CALENDAR&q=Smoke%20toplu%20$SFX")
  has "CSV formul kacirma" "'=Smoke toplu $SFX" "$ACSV"
  R=$(curl -s -X POST -H "$H" -H "$AD" $A/admin/academic/bulk -d "{\"entity\":\"CALENDAR\",\"action\":\"DELETE\",\"ids\":[$EID],\"reason\":\"smoke silme\"}")
  has "silindi" '"done":1' "$R"
else
  echo "  (takvim kaydi olusmadi: $EV)"
  FAIL=1
fi

echo "== menu"
check "menu CSV" 200 "$(code -H "$AD" $A/admin/menu/export.csv)"
check "gecersiz tarih" 400 "$(code -X POST -H "$H" -H "$AD" $A/admin/menu/bulk-delete -d '{"dates":["31.12.2031"],"reason":"smoke gecersiz"}')"
MR=$(curl -s -X POST -H "$H" -H "$AD" $A/admin/menu/bulk-delete -d '{"dates":["2099-01-01"],"reason":"smoke olmayan gun"}')
has "olmayan gun atlandi" '"skipped":1' "$MR"

echo "== bekleyen kayit"
PE="smkpend$SFX@bingol.edu.tr"
curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$PE\",\"password\":\"Sifre1234\",\"displayName\":\"Bekleyen\",\"acceptTerms\":true,\"language\":\"tr\"}"
PR=$(curl -s -X POST -H "$H" -H "$AD" $A/admin/pending-registrations/bulk-cancel -d "{\"emails\":[\"$PE\",\"yok$SFX@bingol.edu.tr\"],\"reason\":\"smoke bekleyen iptal\"}")
has "bekleyen iptal edildi" '"done":1' "$PR"
hasnt "tam e-posta yanitta yok" "$PE" "$PR"
PCSV=$(curl -s -H "$AD" $A/admin/pending-registrations/export.csv)
has "bekleyen CSV baslik" 'emailMasked' "$PCSV"
hasnt "bekleyen CSV tam e-posta yok" "$PE" "$PCSV"

echo "== kaynak durumu"
S=$(curl -s -H "$AD" $A/admin/sources/status)
has "haber kaynagi" '"news":{' "$S"
has "menu kaynagi" '"menu":{' "$S"
has "saatlik sinir" '"syncPerHour":3' "$S"
check "sebepsiz senkron" 400 "$(code -X POST -H "$H" -H "$AD" $A/admin/sources/sync -d '{"source":"MENU"}')"
if [ "${SYNC:-0}" = "1" ]; then
  check "menu senkron" 200 "$(code -X POST -H "$H" -H "$AD" $A/admin/sources/sync -d '{"source":"MENU","reason":"smoke elle senkron"}')"
else
  echo "  (SYNC=1 verilmedi: elle senkron atlandi)"
fi

[ "$FAIL" = 0 ] && echo "TAMAM" || { echo "BASARISIZ"; exit 1; }

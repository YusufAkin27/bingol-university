#!/usr/bin/env bash
# DS1 duman testi (admin veri saklama): doluluk ucu, tablo listesi, dis aktarma -> makbuz (SHA-256 dogrulamali),
# onizleme, makbuzsuz silme reddi, makbuzlu silme (arka plan, ilerleme), zorla (makbuzsuz) silme gerekce kurali,
# silme/makbuz kayitlarinin silinemezligi. Calisan compose yigina karsi, ASCII, tekrar calistirilabilir.
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ./scripts/smoke-admin-retention.sh
# Onkosul: MAIL_ENABLED=false (kod log'dan okunur), ADMIN_EMAILS=$ADMIN_EMAIL (FULL), V830 uygulanmis.
# Not: yikici islem saatlik siniri (20) ve silme siniri (10) vardir; art arda kosarken Redis flushall yapin.
# Veri: profanity_hit_log'a field='smoke-ds1' etiketli ESKI (200 gun) kayitlar eklenir (docker compose exec postgres).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
DB_USER=${DB_USER:-bingol}
DB_NAME=${DB_NAME:-bingol}
H='Content-Type: application/json'
FAIL=0

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 300)"; FAIL=1; fi; }
hasnt() { if echo "$3" | grep -qF -- "$2"; then echo "  FAIL $1 (bulunmamali: $2)"; FAIL=1; else echo "  ok   $1"; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
sql() { docker compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -At -c "$1" 2>&1; }

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
UE="smkret$SFX@bingol.edu.tr"
echo "== hazirlik"
TA=$(register "$ADMIN_EMAIL" "Yonetici")
TU=$(register "$UE" "Smoke Retention")
[ -n "$TA" ] && [ -n "$TU" ] || { echo "token alinamadi (ADMIN_EMAILS ayarli mi?)"; exit 1; }
AD="Authorization: Bearer $TA"; US="Authorization: Bearer $TU"
TODAY=$(TZ=Europe/Istanbul date +%F)
TO=$(TZ=Europe/Istanbul date -d "$TODAY - 31 days" +%F)       # profanity_hit_log asgari 30 gun
RECENT=$(TZ=Europe/Istanbul date -d "$TODAY - 5 days" +%F)    # asgari sureden yeni
WORK=$(mktemp -d)

echo "== yetki"
check "anonim storage" 401 "$(code $A/admin/system/storage)"
check "kullanici storage" 403 "$(code -H "$US" $A/admin/system/storage)"
check "kullanici tablolar" 403 "$(code -H "$US" $A/admin/data-retention/tables)"
check "kullanici disa aktar" 403 "$(code -X POST -H "$H" -H "$US" $A/admin/data-retention/exports -d "{\"table\":\"profanity_hit_log\",\"to\":\"$TO\",\"reason\":\"yetkisiz deneme\"}")"

echo "== doluluk"
S=$(curl -s -H "$AD" $A/admin/system/storage)
has "database boyutu alani" '"database"' "$S"
has "veritabani sunucusu diski kaynagi" '"dbServerDisk"' "$S"
has "kaynak etiketi (MEASURED/COMPUTED/UNKNOWN)" '"source"' "$S"
has "esikler" '"warnPercent"' "$S"
echo "  bilgi: $(echo "$S" | grep -o '"dbServerDisk":{[^}]*}' | head -c 300)"
OV=$(curl -s -H "$AD" $A/admin/system/overview)
has "overview storage gostergesi" '"storage"' "$OV"

echo "== tablo listesi (beyaz liste)"
T=$(curl -s -H "$AD" $A/admin/data-retention/tables)
has "analytics_event listede" '"name":"analytics_event"' "$T"
has "message_access_audit silinemez" '"deletable":false' "$T"
hasnt "app_user listede yok" '"name":"app_user"' "$T"
hasnt "message listede yok" '"name":"message"' "$T"

echo "== tohum: 130 eski + 3 yeni kayit"
sql "DELETE FROM profanity_hit_log WHERE field = 'smoke-ds1'" > /dev/null
sql "INSERT INTO profanity_hit_log (field, entity, user_id, action, at) SELECT 'smoke-ds1', 'smoke', 1, 'BLOCK', now() - interval '200 days' FROM generate_series(1,130)" > /dev/null
sql "INSERT INTO profanity_hit_log (field, entity, user_id, action, at) SELECT 'smoke-ds1', 'smoke', 1, 'BLOCK', now() - interval '2 days' FROM generate_series(1,3)" > /dev/null
check "tohum eski" 130 "$(sql "SELECT count(*) FROM profanity_hit_log WHERE field='smoke-ds1' AND at < now() - interval '100 days'")"

echo "== onizleme: makbuz yok"
P=$(curl -s -H "$AD" "$A/admin/data-retention/tables/profanity_hit_log/purge-preview?to=$TO")
has "silinecek >= 130" '"rowsInRange":' "$P"
has "makbuz yok -> canPurge false" '"canPurge":false' "$P"
has "NO_RECEIPT engelleyici" 'NO_RECEIPT' "$P"
check "bilinmeyen tablo onizleme" 404 "$(code -H "$AD" "$A/admin/data-retention/tables/app_user/purge-preview?to=$TO")"
check "cok yeni aralik" 422 "$(code -H "$AD" "$A/admin/data-retention/tables/profanity_hit_log/purge-preview?to=$RECENT")"

echo "== silme dogrulamalari (hepsi reddedilir)"
PB="{\"table\":\"profanity_hit_log\",\"to\":\"$TO\",\"confirmTable\":\"profanity_hit_log\",\"reason\":\"smoke silme denemesi\"}"
check "Idempotency-Key yok" 400 "$(code -X POST -H "$H" -H "$AD" $A/admin/data-retention/purges -d "$PB")"
check "makbuzsuz silme" 409 "$(code -X POST -H "$H" -H "$AD" -H "Idempotency-Key: smoke-$SFX-a1" $A/admin/data-retention/purges -d "$PB")"
R=$(curl -s -X POST -H "$H" -H "$AD" -H "Idempotency-Key: smoke-$SFX-a2" $A/admin/data-retention/purges -d "$PB")
has "kod RETENTION_EXPORT_REQUIRED" 'RETENTION_EXPORT_REQUIRED' "$R"
check "yanlis onay" 400 "$(code -X POST -H "$H" -H "$AD" -H "Idempotency-Key: smoke-$SFX-a3" $A/admin/data-retention/purges -d "{\"table\":\"profanity_hit_log\",\"to\":\"$TO\",\"confirmTable\":\"baska\",\"reason\":\"smoke silme denemesi\"}")"
check "cok yeni aralik" 422 "$(code -X POST -H "$H" -H "$AD" -H "Idempotency-Key: smoke-$SFX-a4" $A/admin/data-retention/purges -d "{\"table\":\"profanity_hit_log\",\"to\":\"$RECENT\",\"confirmTable\":\"profanity_hit_log\",\"reason\":\"smoke silme denemesi\"}")"
check "silinemez tablo" 409 "$(code -X POST -H "$H" -H "$AD" -H "Idempotency-Key: smoke-$SFX-a5" $A/admin/data-retention/purges -d "{\"table\":\"message_access_audit\",\"to\":\"$(TZ=Europe/Istanbul date -d "$TODAY - 400 days" +%F)\",\"confirmTable\":\"message_access_audit\",\"reason\":\"smoke silme denemesi\"}")"
check "beyaz liste disi tablo" 404 "$(code -X POST -H "$H" -H "$AD" -H "Idempotency-Key: smoke-$SFX-a6" $A/admin/data-retention/purges -d "{\"table\":\"app_user\",\"to\":\"$TO\",\"confirmTable\":\"app_user\",\"reason\":\"smoke silme denemesi\"}")"
check "kayitlar yerinde" 133 "$(sql "SELECT count(*) FROM profanity_hit_log WHERE field='smoke-ds1'")"

echo "== disa aktarma (gerekce zorunlu) + makbuz"
check "gerekcesiz" 400 "$(code -X POST -H "$H" -H "$AD" $A/admin/data-retention/exports -d "{\"table\":\"profanity_hit_log\",\"to\":\"$TO\"}")"
check "cok yeni aralik" 422 "$(code -X POST -H "$H" -H "$AD" -H "X-Admin-Reason: smoke yedekleme" $A/admin/data-retention/exports -d "{\"table\":\"profanity_hit_log\",\"to\":\"$RECENT\"}")"
HTTP=$(curl -s -D "$WORK/h.txt" -o "$WORK/out.csv.gz" -w '%{http_code}' -X POST -H "$H" -H "$AD" -H "X-Admin-Reason: smoke yedekleme" \
  $A/admin/data-retention/exports -d "{\"table\":\"profanity_hit_log\",\"to\":\"$TO\"}")
check "disa aktarma" 200 "$HTTP"
RID=$(grep -i '^x-export-receipt-id:' "$WORK/h.txt" | tr -d '\r' | awk '{print $2}')
echo "  makbuz #$RID"
[ -n "$RID" ] || { echo "  FAIL makbuz basligi yok"; FAIL=1; RID=0; }
LINES=$(gzip -dc "$WORK/out.csv.gz" | wc -l | tr -d ' ')
gzip -dc "$WORK/out.csv.gz" | head -c 3 | od -c | head -1 | grep -q '357' && { echo "  FAIL BOM var"; FAIL=1; } || echo "  ok   BOM yok"
REC=$(curl -s -H "$AD" $A/admin/data-retention/exports/$RID)
has "makbuz COMPLETED" '"status":"COMPLETED"' "$REC"
ROWS=$(echo "$REC" | grep -o '"rowCount":[0-9]*' | cut -d: -f2)
check "CSV satir (baslik + makbuz satiri)" "$((ROWS + 1))" "$LINES"
[ "$ROWS" -ge 130 ] && echo "  ok   makbuz satir >= 130 ($ROWS)" || { echo "  FAIL makbuz satir $ROWS"; FAIL=1; }
SHA=$(echo "$REC" | grep -o '"sha256":"[0-9a-f]*' | cut -d'"' -f4)
LOCAL=$(sha256sum "$WORK/out.csv.gz" | cut -d' ' -f1)
check "indirilen dosyanin SHA-256'si makbuzla ayni" "$SHA" "$LOCAL"
LST=$(curl -s -H "$AD" "$A/admin/data-retention/exports?table=profanity_hit_log")
has "makbuz listede" "\"id\":$RID" "$LST"

echo "== onizleme: makbuz var"
P=$(curl -s -H "$AD" "$A/admin/data-retention/tables/profanity_hit_log/purge-preview?to=$TO")
has "canPurge true" '"canPurge":true' "$P"
has "makbuz bagli" "\"id\":$RID" "$P"

echo "== makbuzlu silme (arka plan)"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$AD" -H "Idempotency-Key: smoke-$SFX-b1" $A/admin/data-retention/purges \
  -d "{\"table\":\"profanity_hit_log\",\"to\":\"$TO\",\"confirmTable\":\"profanity_hit_log\",\"receiptId\":$RID,\"reason\":\"smoke silme: makbuz alindi\"}")
check "202" 202 "$(echo "$R" | tail -1)"
PID=$(echo "$R" | head -1 | idof)
ST=RUNNING
for i in $(seq 1 60); do
  ST=$(curl -s -H "$AD" $A/admin/data-retention/purges/$PID | grep -o '"status":"[A-Z]*' | cut -d'"' -f4)
  [ "$ST" != "RUNNING" ] && break
  sleep 1
done
check "temizlik tamamlandi" COMPLETED "$ST"
check "eski kayit kalmadi" 0 "$(sql "SELECT count(*) FROM profanity_hit_log WHERE field='smoke-ds1' AND at < now() - interval '100 days'")"
check "yeni kayitlara dokunulmadi" 3 "$(sql "SELECT count(*) FROM profanity_hit_log WHERE field='smoke-ds1'")"
PL=$(curl -s -H "$AD" $A/admin/data-retention/purges)
has "silme gecmisinde" "\"id\":$PID" "$PL"
has "makbuz bagli" "\"receiptId\":$RID" "$PL"

echo "== zorla (makbuzsuz) silme: gerekce >= 20"
sql "INSERT INTO profanity_hit_log (field, entity, user_id, action, at) SELECT 'smoke-ds1', 'smoke', 1, 'BLOCK', now() - interval '200 days' FROM generate_series(1,5)" > /dev/null
FB="\"table\":\"profanity_hit_log\",\"to\":\"$TO\",\"confirmTable\":\"profanity_hit_log\",\"forceWithoutExport\":true"
check "kisa gerekce" 400 "$(code -X POST -H "$H" -H "$AD" -H "Idempotency-Key: smoke-$SFX-c1" $A/admin/data-retention/purges -d "{$FB,\"reason\":\"kisa gerekce\"}")"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" -H "$AD" -H "Idempotency-Key: smoke-$SFX-c2" $A/admin/data-retention/purges \
  -d "{$FB,\"reason\":\"smoke: makbuzsuz silme icin yeterince uzun gerekce\"}")
check "zorla silme 202" 202 "$(echo "$R" | tail -1)"
FID=$(echo "$R" | head -1 | idof)
for i in $(seq 1 60); do
  ST=$(curl -s -H "$AD" $A/admin/data-retention/purges/$FID | grep -o '"status":"[A-Z]*' | cut -d'"' -f4)
  [ "$ST" != "RUNNING" ] && break
  sleep 1
done
check "zorla temizlik tamamlandi" COMPLETED "$ST"
has "zorla silme isaretli" '"forced":true' "$(curl -s -H "$AD" $A/admin/data-retention/purges/$FID)"

echo "== kanit tablolari silinemez (tetikleyici)"
DEL=$(sql "DELETE FROM data_export_receipt WHERE id = $RID")
has "makbuz silinemez" 'append-only' "$DEL"
DEL=$(sql "DELETE FROM data_purge_log WHERE id = $PID")
has "silme kaydi silinemez" 'append-only' "$DEL"

echo "== denetim"
AU=$(curl -s -H "$AD" "$A/admin/audit?q=data-retention&size=10")
has "denetimde disa aktarma" 'data-retention/exports' "$AU"
has "denetimde silme" 'data-retention/purges' "$AU"

sql "DELETE FROM profanity_hit_log WHERE field = 'smoke-ds1'" > /dev/null
rm -rf "$WORK"
echo
if [ $FAIL -eq 0 ]; then echo "TUM KONTROLLER GECTI"; else echo "BASARISIZ KONTROL VAR"; exit 1; fi

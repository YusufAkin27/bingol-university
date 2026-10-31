#!/usr/bin/env bash
# Silme defteri (T-064, A8-17) geri yukleme provasi / dogrulamasi. SALT OKUNUR: veritabanini degistirmez.
# Defterdeki (DELETION_LEDGER_FILE) her kullanici kimligi icin veritabaninda durumu listeler ve "canli gorunen"
# (DELETED degil) hesaplari raporlar. Backend acilista/geceleyin bu hesaplari yeniden anonimlestirir
# (DeletionLedgerReapplier); bu betik, o adim OLMADAN once neyin yeniden anonimlestirilecegini gosterir.
#
# Kullanim (staging geri yukleme provasi):
#   LEDGER=/ledger/deleted-users.log \
#   PSQL="docker compose -f docker-compose.prod.yml --env-file .env.prod exec -T postgres psql -U bingol_app -d bingol -At" \
#   bash scripts/ops/check-deletion-ledger.sh
# Cikis kodu: 0 = tum defter kayitlari DELETED (ya da hesap yok), 1 = yeniden anonimlestirilecek hesap var, 2 = hata.
set -u
LEDGER=${LEDGER:-}
PSQL=${PSQL:-}
[ -n "$LEDGER" ] && [ -f "$LEDGER" ] || { echo "LEDGER dosyasi yok: '$LEDGER'"; exit 2; }
[ -n "$PSQL" ] || { echo "PSQL komutu verilmedi"; exit 2; }

IDS=$(cut -f1 "$LEDGER" | grep -E '^[0-9]+$' | sort -un | paste -sd, -)
[ -n "$IDS" ] || { echo "defter bos"; exit 0; }
TOTAL=$(echo "$IDS" | tr ',' '\n' | wc -l | tr -d ' ')
echo "defter kayit sayisi (tekil kimlik): $TOTAL"

LIVE=$($PSQL -c "SELECT id || ' ' || status || ' ' || extract(epoch FROM created_at)::bigint FROM app_user WHERE id IN ($IDS) AND status <> 'DELETED' ORDER BY id") || { echo "veritabani sorgusu basarisiz"; exit 2; }
if [ -z "$LIVE" ]; then
  echo "TAMAM: defterdeki tum hesaplar DELETED (ya da yok); yeniden anonimlestirilecek hesap yok."
  exit 0
fi
N=$(echo "$LIVE" | wc -l | tr -d ' ')
echo "UYARI: $N hesap canli gorunuyor (geri yuklenmis olabilir). Backend acilista yeniden anonimlestirecek"
echo "(yalnizca hesap olusturma saniyesi defterdekiyle ayniysa; sutunlar: id durum olusturma_sn):"
echo "$LIVE"
exit 1

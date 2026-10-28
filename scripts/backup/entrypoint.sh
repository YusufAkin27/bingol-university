#!/usr/bin/env bash
# Kok olarak baslar: dizin izinlerini duzeltir, age anahtarini postgres'in okuyabilecegi yere kopyalar; metrik sunucusunu ve
# zamanlayiciyi "postgres" (uid 70) kullanicisiyla calistirir. TUM betikler tek kullanicidir (postgres): root sahipli dosya/dizin
# kalmasin diye elle cagrilar da bu dosya uzerinden (veya `exec -u postgres`) yapilmalidir (docs/BACKUP_RESTORE.md).
# Elle calistirma: entrypoint.sh <betik> [arg...]   (ornek: verify-restore.sh --latest)
set -euo pipefail
BACKUP_DIR="${BACKUP_DIR:-/var/backups}"
mkdir -p "$BACKUP_DIR/metrics" "$BACKUP_DIR/daily" "$BACKUP_DIR/weekly" "$BACKUP_DIR/monthly"

# age ozel anahtari (haftalik dogrulama / geri yukleme): host'taki dosya 0600 ve baska bir kullanicinin olabilir (uid 70 okuyamaz).
# Kok olarak (burada) okunur ve yalniz postgres'in okuyabildigi 0400 bir kopyaya yazilir; betikler BACKUP_AGE_IDENTITY_FILE'i kullanir.
# Kaynak: BACKUP_AGE_IDENTITY_SRC (varsayilan /run/backup/verify.key). Yoksa/okunamazsa sessizce gecilir (verify-restore net hata verir).
KEY_DIR="${BACKUP_AGE_KEY_DIR:-/run/age-key}"
prepare_key() {
  local src="${BACKUP_AGE_IDENTITY_SRC:-/run/backup/verify.key}"
  [ -f "$src" ] && [ -r "$src" ] || return 0
  install -d -m 0700 -o postgres -g postgres "$KEY_DIR" 2>/dev/null || return 0
  install -m 0400 -o postgres -g postgres "$src" "$KEY_DIR/age.key" 2>/dev/null || return 0
  export BACKUP_AGE_IDENTITY_FILE="$KEY_DIR/age.key"
}
prepare_key

if [ "$#" -gt 0 ]; then
  chown -R postgres:postgres "$BACKUP_DIR" 2>/dev/null || true
  [ -f "$BACKUP_DIR/metrics/backup.prom" ] || /opt/backup/lib.sh init-metrics
  chown -R postgres:postgres "$BACKUP_DIR/metrics" 2>/dev/null || true
  case "$1" in /*) exec su-exec postgres "$@";; *) exec su-exec postgres "/opt/backup/$@";; esac
fi

: "${BACKUP_AGE_RECIPIENT:?BACKUP_AGE_RECIPIENT gerekli}"
[ -f "$BACKUP_DIR/metrics/backup.prom" ] || /opt/backup/lib.sh init-metrics
chown -R postgres:postgres "$BACKUP_DIR"
chmod 755 "$BACKUP_DIR" "$BACKUP_DIR/metrics"

CRON_FILE=/tmp/backup.cron
{
  echo "${BACKUP_CRON:-5 * * * *} flock -n /tmp/backup.lock /opt/backup/backup.sh"
  echo "${BACKUP_VERIFY_CRON:-30 4 * * 0} flock -n /tmp/backup.lock /opt/backup/verify-restore.sh --latest"
} > "$CRON_FILE"

# Prometheus: http://backup:9199/backup.prom (node-exporter textfile icin ayni dosya: metrics/backup.prom)
httpd -f -p 9199 -h "$BACKUP_DIR/metrics" &

# Mutlak yol sart: supercronic PID 1 iken kendini os.Args[0] ile yeniden calistirir; "supercronic" (yolsuz) ENOENT verir
# ve yedek servisi hic baslamazdi (A4 selftest bulgusu).
exec su-exec postgres /usr/local/bin/supercronic "$CRON_FILE"

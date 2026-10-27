#!/usr/bin/env bash
# Kok olarak baslar: dizin izinlerini duzeltir; metrik sunucusunu ve zamanlayiciyi "postgres" kullanicisiyla calistirir.
# Elle calistirma: entrypoint.sh <betik> [arg...]   (ornek: verify-restore.sh --latest)
set -euo pipefail
BACKUP_DIR="${BACKUP_DIR:-/var/backups}"
mkdir -p "$BACKUP_DIR/metrics" "$BACKUP_DIR/daily" "$BACKUP_DIR/weekly" "$BACKUP_DIR/monthly"

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
  echo "${BACKUP_CRON:-0 3 * * *} /opt/backup/backup.sh"
  echo "${BACKUP_VERIFY_CRON:-30 4 * * 0} /opt/backup/verify-restore.sh --latest"
} > "$CRON_FILE"

# Prometheus: http://backup:9199/backup.prom (node-exporter textfile icin ayni dosya: metrics/backup.prom)
httpd -f -p 9199 -h "$BACKUP_DIR/metrics" &

exec su-exec postgres supercronic "$CRON_FILE"

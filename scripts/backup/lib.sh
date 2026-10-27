#!/usr/bin/env bash
# Ortak yardimcilar: log, metrik yazimi (Prometheus textfile bicimi), webhook bildirimi.
# Dogrudan cagri: lib.sh init-metrics

BACKUP_DIR="${BACKUP_DIR:-/var/backups}"
METRICS_DIR="${BACKUP_METRICS_DIR:-$BACKUP_DIR/metrics}"
METRICS_FILE="$METRICS_DIR/backup.prom"

log() { printf '%s [backup] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2; }
die() { log "HATA: $*"; exit 1; }

# metric_write <son_basari_ts> <son_calisma_ts> <durum 1/0> <sure_sn> <db_bayt> <dosya_bayt> <dogrulama_ts> <dogrulama_durum>
# Eski degerler korunur: bos arguman = mevcut degeri koru.
metric_get() { # metric_get <ad> -> deger (yoksa 0)
  local v
  v="$(grep -E "^$1 " "$METRICS_FILE" 2>/dev/null | awk '{print $2}' | head -1)"
  echo "${v:-0}"
}

metric_write() {
  mkdir -p "$METRICS_DIR"
  local ls="${1:-$(metric_get backup_last_success_timestamp_seconds)}"
  local lr="${2:-$(metric_get backup_last_run_timestamp_seconds)}"
  local st="${3:-$(metric_get backup_last_status)}"
  local du="${4:-$(metric_get backup_last_duration_seconds)}"
  local db="${5:-$(metric_get backup_last_db_bytes)}"
  local up="${6:-$(metric_get backup_last_uploads_bytes)}"
  local vs="${7:-$(metric_get backup_verify_last_success_timestamp_seconds)}"
  local vt="${8:-$(metric_get backup_verify_last_status)}"
  local tmp="$METRICS_FILE.tmp.$$"
  cat > "$tmp" <<PROM
# HELP backup_last_success_timestamp_seconds Son BASARILI yedegin unix zamani (uyari: time() - bu > 93600)
# TYPE backup_last_success_timestamp_seconds gauge
backup_last_success_timestamp_seconds $ls
# HELP backup_last_run_timestamp_seconds Son yedek denemesinin unix zamani
# TYPE backup_last_run_timestamp_seconds gauge
backup_last_run_timestamp_seconds $lr
# HELP backup_last_status Son yedek denemesi: 1 basarili, 0 basarisiz
# TYPE backup_last_status gauge
backup_last_status $st
# HELP backup_last_duration_seconds Son yedek suresi
# TYPE backup_last_duration_seconds gauge
backup_last_duration_seconds $du
# HELP backup_last_db_bytes Son veritabani yedeginin (sifreli) boyutu
# TYPE backup_last_db_bytes gauge
backup_last_db_bytes $db
# HELP backup_last_uploads_bytes Son dosya yedeginin (sifreli) boyutu
# TYPE backup_last_uploads_bytes gauge
backup_last_uploads_bytes $up
# HELP backup_verify_last_success_timestamp_seconds Son BASARILI geri yukleme dogrulamasinin unix zamani
# TYPE backup_verify_last_success_timestamp_seconds gauge
backup_verify_last_success_timestamp_seconds $vs
# HELP backup_verify_last_status Son geri yukleme dogrulamasi: 1 basarili, 0 basarisiz
# TYPE backup_verify_last_status gauge
backup_verify_last_status $vt
PROM
  mv -f "$tmp" "$METRICS_FILE"
  chmod 644 "$METRICS_FILE" 2>/dev/null || true
}

notify() { # notify <mesaj>: webhook'a basit JSON (Slack/Discord/Mattermost "text"/"content" uyumlu)
  [ -n "${BACKUP_WEBHOOK_URL:-}" ] || return 0
  local msg
  msg="$(printf '%s' "$1" | sed 's/\/\\/g; s/"/\\"/g')"
  curl -fsS -m 15 -H 'Content-Type: application/json' \
    -d "{\"text\":\"[BU Kampus yedek] $msg\",\"content\":\"[BU Kampus yedek] $msg\"}" \
    "$BACKUP_WEBHOOK_URL" >/dev/null 2>&1 || log "uyari: webhook gonderilemedi"
}

human() { numfmt --to=iec "${1:-0}" 2>/dev/null || echo "${1:-0}B"; }

if [ "${1:-}" = "init-metrics" ]; then
  metric_write 0 0 0 0 0 0 0 0
fi

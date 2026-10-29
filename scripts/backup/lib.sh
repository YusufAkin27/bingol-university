#!/usr/bin/env bash
# Ortak yardimcilar: log, metrik yazimi (Prometheus textfile bicimi), webhook bildirimi.
# Dogrudan cagri: lib.sh init-metrics

# Tek kullanici (postgres, uid 70) ve tutarli izinler: yeni dizin 750, dosya 640. Metrik/durum dosyalari acikca 644 yapilir
# (node-exporter ve backend okur). Betikler root olarak cagrilirsa drop_root ile postgres'e gecer (H2: root sahipli 700 dizin).
umask 027
BACKUP_DIR="${BACKUP_DIR:-/var/backups}"
METRICS_DIR="${BACKUP_METRICS_DIR:-$BACKUP_DIR/metrics}"
METRICS_FILE="$METRICS_DIR/backup.prom"

# drop_root <betik-yolu> [arg...]: root isek entrypoint uzerinden (chown + anahtar hazirligi) postgres'e gec. Root degilse hicbir sey yapmaz.
drop_root() {
  if [ "$(id -u)" = 0 ] && [ -x /opt/backup/entrypoint.sh ]; then
    printf '%s [backup] root olarak cagrildi; postgres kullanicisina geciliyor\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" >&2
    exec /opt/backup/entrypoint.sh "$@"
  fi
}

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
# HELP backup_last_success_timestamp_seconds Son BASARILI yedegin unix zamani (uyari: time() - bu > 10800, yani 3 saat)
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

# Durum JSON'u (gozlemlenebilirlik): BACKUP_STATUS_FILE (varsayilan $BACKUP_DIR/last-success.json);
# basarisizlik dosyasi ayni dizinde last-failure.json. Gecici ada yazilip atomik tasinir.
STATUS_FILE="${BACKUP_STATUS_FILE:-$BACKUP_DIR/last-success.json}"
FAILURE_FILE="$(dirname "$STATUS_FILE")/last-failure.json"

json_esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n\r'; }

# status_success <dosya-adi> <sizeBytes> <durationSec> <dbOk true/false> <filesOk true/false>
status_success() {
  local tmp="$STATUS_FILE.tmp.$$"
  mkdir -p "$(dirname "$STATUS_FILE")"
  # Backend BackupStatusProvider "lastSuccessAt" alanini (ISO-8601 UTC, 'Z' sonekli) okur; "time" ayni degerin takma adi.
  # Yerel saat dilimli ("+0300") biçim Instant.parse ile ayrisamaz -> gosterge hep UNKNOWN olurdu (M25).
  local now; now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '{"lastSuccessAt":"%s","time":"%s","file":"%s","sizeBytes":%s,"durationSec":%s,"dbOk":%s,"filesOk":%s}\n' \
    "$now" "$now" "$(json_esc "$1")" "$2" "$3" "$4" "$5" > "$tmp"
  mv -f "$tmp" "$STATUS_FILE"
  chmod 644 "$STATUS_FILE" 2>/dev/null || true
  # basarili yedekten sonra eski basarisizlik kaydi yaniltici olur
  rm -f "$FAILURE_FILE"
}

# status_failure <hata-metni> <durationSec> <dbOk> <filesOk>
status_failure() {
  local tmp="$FAILURE_FILE.tmp.$$"
  mkdir -p "$(dirname "$FAILURE_FILE")"
  printf '{"time":"%s","error":"%s","durationSec":%s,"dbOk":%s,"filesOk":%s}\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$(json_esc "$1")" "$2" "$3" "$4" > "$tmp"
  mv -f "$tmp" "$FAILURE_FILE"
  chmod 644 "$FAILURE_FILE" 2>/dev/null || true
}

# prune <dizin> <tut>: yalniz YEDEK adli (YYYYmmddTHHMMSS) dizinleri siler; en yeni <tut> GECERLI yedek (SHA256SUMS + db.dump.age
# var) ve onlardan yeni her sey kalir, daha eskiler silinir. GECERLI yedek sayisi <tut>'tan azsa HICBIR SEY silinmez (eldeki son iyi
# yedekler korunur). Yalnizca basarili yedekten SONRA cagrilir. <tut> < 1 ise saklama KAPALIDIR (haftalik/aylik varsayilani 0):
# bos dizinde sessiz kalir (eski surumdeki "prune sayisi gecersiz (0)" uyarisi her saat yanlis alarm veriyordu); dizinde yedek
# varsa bir kez uyarir, yine de silmez (guvenli taraf).
prune() {
  local keep="${2:-0}" d valid=0 cnt
  if ! [ "$keep" -ge 1 ] 2>/dev/null; then
    cnt="$(ls -1 "$1" 2>/dev/null | grep -cE '^[0-9]{8}T[0-9]{6}$' || true)"
    [ "${cnt:-0}" -eq 0 ] || log "uyari: $1 icin saklama kapali/gecersiz ($keep) ama $cnt yedek var; silme yapilmadi"
    return 0
  fi
  local names; names="$(ls -1 "$1" 2>/dev/null | grep -E '^[0-9]{8}T[0-9]{6}$' | sort -r || true)"
  local total_valid=0
  for d in $names; do [ -s "$1/$d/SHA256SUMS" ] && [ -s "$1/$d/db.dump.age" ] && total_valid=$((total_valid+1)); done
  if [ "$total_valid" -lt "$keep" ]; then
    log "saklama: $1 icinde $total_valid gecerli yedek var (< $keep); silme yapilmadi"
    return 0
  fi
  for d in $names; do
    if [ "$valid" -ge "$keep" ]; then
      log "siliniyor: $1/$d"
      # Temizlik hatasi yedegi/uzak kopyayi BASARISIZ saymaz (izin sorunu yedekleme zincirini kirmasin)
      rm -rf "${1:?}/$d" || log "uyari: $1/$d silinemedi (sahiplik/izin?); sonraki calismada yeniden denenir"
    elif [ -s "$1/$d/SHA256SUMS" ] && [ -s "$1/$d/db.dump.age" ]; then
      valid=$((valid+1))
    fi
  done
}

notify() { # notify <mesaj>: webhook'a basit JSON (Slack/Discord/Mattermost "text"/"content" uyumlu)
  [ -n "${BACKUP_WEBHOOK_URL:-}" ] || return 0
  local msg
  # json_esc ile tek yerden kacis (eski sed ifadesi gecersizdi: bildirim hic gitmiyordu)
  msg="$(json_esc "$1")"
  curl -fsS -m 15 -H 'Content-Type: application/json' \
    -d "{\"text\":\"[BU Kampus yedek] $msg\",\"content\":\"[BU Kampus yedek] $msg\"}" \
    "$BACKUP_WEBHOOK_URL" >/dev/null 2>&1 || log "uyari: webhook gonderilemedi"
}

human() { numfmt --to=iec "${1:-0}" 2>/dev/null || echo "${1:-0}B"; }

if [ "${1:-}" = "init-metrics" ]; then
  metric_write 0 0 0 0 0 0 0 0
fi

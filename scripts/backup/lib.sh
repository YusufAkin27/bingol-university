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
  # yerel/uzak/zamanlama/saklama alanlari (GDRIVE-BACKUP); hata yedegi basarisiz saymaz
  status_enrich || log "uyari: durum dosyasi zenginlestirilemedi"
}

# ---------------------------------------------------------------------------------------------------------------------
# Yerel/uzak kopya durumu (GDRIVE-BACKUP). last-success.json'a local/remote/schedule/retention nesneleri eklenir; eski alanlar
# (lastSuccessAt, time, file...) aynen kalir. Uzak durum $REMOTE_STATE_FILE'dadir (remote-sync.sh yazar; yalniz kisa hata metni,
# uzak adi ve sayilar; hedef yolu/belirtec ASLA). jq yoksa zenginlestirme sessizce atlanir.
# ---------------------------------------------------------------------------------------------------------------------
REMOTE_STATE_FILE="${BACKUP_REMOTE_STATE_FILE:-$BACKUP_DIR/remote-state.json}"
STAMP_RE='^[0-9]{8}T[0-9]{6}$'

now_iso() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

# stamp_to_iso <YYYYmmddTHHMMSS> (yerel saat) -> ISO-8601 UTC; cevrilemezse bos
stamp_to_iso() {
  local s="$1" e
  e="$(date -d "${s:0:4}-${s:4:2}-${s:6:2} ${s:9:2}:${s:11:2}:${s:13:2}" +%s 2>/dev/null)" || return 0
  date -u -d "@$e" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
}

# Yalniz rclone UZAK ADI (iki nokta oncesi); gecersiz/yoksa bos. Yol ve belirtec bu fonksiyondan cikmaz.
remote_name() {
  local n
  case "${BACKUP_REMOTE:-}" in *:*) n="${BACKUP_REMOTE%%:*}";; *) return 0;; esac
  printf '%s' "$n" | grep -E '^[A-Za-z0-9_.-]+$' || true
}

# drive | other. alias/crypt/chunker/compress zincirini en fazla 4 basamak izler; `rclone config dump` ciktisi borudan okunur,
# log'a yazilmaz.
remote_kind() {
  local n dump i t r
  n="$(remote_name)"
  [ -n "$n" ] && command -v jq >/dev/null && command -v rclone >/dev/null || { echo other; return 0; }
  dump="$(rclone config dump 2>/dev/null)" || { echo other; return 0; }
  for i in 1 2 3 4; do
    t="$(printf '%s' "$dump" | jq -r --arg n "$n" '.[$n].type // empty' 2>/dev/null)"
    case "$t" in
      drive) echo drive; return 0;;
      alias|crypt|chunker|compress|cache)
        r="$(printf '%s' "$dump" | jq -r --arg n "$n" '.[$n].remote // empty' 2>/dev/null)"
        case "$r" in *:*) n="${r%%:*}";; *) break;; esac;;
      *) break;;
    esac
  done
  echo other
}

# local_stats_json -> {"count":N,"bytes":B,"oldestAt":"..Z"|null}; damga basina bir sayilir (haftalik/aylik sabit baglar tekrar saymaz)
local_stats_json() {
  local names count oldest bytes="0" t dirs=() oiso
  names="$(for t in daily weekly monthly; do ls -1 "$BACKUP_DIR/$t" 2>/dev/null; done | grep -E "$STAMP_RE" | sort -u || true)"
  if [ -z "$names" ]; then echo '{"count":0,"bytes":0,"oldestAt":null}'; return 0; fi
  count="$(printf '%s\n' "$names" | wc -l | tr -d ' ')"
  oldest="$(printf '%s\n' "$names" | head -1)"
  for t in daily weekly monthly; do [ -d "$BACKUP_DIR/$t" ] && dirs+=("$BACKUP_DIR/$t"); done
  # tek du cagrisi: sabit baglar (cp -al) bir kez sayilir
  bytes="$(du -sk "${dirs[@]}" 2>/dev/null | awk '{s+=$1} END{print s*1024+0}')"
  oiso="$(stamp_to_iso "$oldest")"
  jq -nc --argjson c "$count" --argjson b "${bytes:-0}" --arg o "$oiso" '{count:$c,bytes:$b,oldestAt:(if $o=="" then null else $o end)}'
}

remote_json() {
  local st='{}'
  if [ -z "${BACKUP_REMOTE:-}" ]; then
    echo '{"configured":false,"kind":null,"name":null,"lastSuccessAt":null,"lastVerifiedAt":null,"lastError":null,"bytes":null,"count":null}'
    return 0
  fi
  [ -s "$REMOTE_STATE_FILE" ] && st="$(jq -c '.' "$REMOTE_STATE_FILE" 2>/dev/null || echo '{}')"
  printf '%s' "$st" | jq -c --arg name "$(remote_name)" --arg kind "$(remote_kind)" '{
      configured: true, kind: $kind, name: (if $name == "" then null else $name end),
      lastSuccessAt: (.lastSuccessAt // null), lastVerifiedAt: (.lastVerifiedAt // null),
      lastError: (.lastError // null), bytes: (.bytes // null), count: (.count // null)}'
}

# Ayarlanan saklama/zamanlama (yonetim paneli "kurulum" ekrani icin); degerler sir degildir.
retention_json() {
  jq -nc --argjson ld "${BACKUP_KEEP_DAILY:-3}" --argjson lw "${BACKUP_KEEP_WEEKLY:-0}" --argjson lm "${BACKUP_KEEP_MONTHLY:-0}" \
    --argjson rd "${BACKUP_REMOTE_KEEP_DAILY:-7}" --argjson rw "${BACKUP_REMOTE_KEEP_WEEKLY:-4}" --argjson rm "${BACKUP_REMOTE_KEEP_MONTHLY:-6}" \
    '{localDaily:$ld,localWeekly:$lw,localMonthly:$lm,remoteDaily:$rd,remoteWeekly:$rw,remoteMonthly:$rm}' 2>/dev/null || echo 'null'
}
schedule_json() {
  jq -nc --arg c "${BACKUP_CRON:-5 * * * *}" --arg v "${BACKUP_VERIFY_CRON:-30 4 * * 0}" --arg r "${BACKUP_REMOTE_CRON:-35 3 * * *}" \
    --argjson on "$([ -n "${BACKUP_REMOTE:-}" ] && echo true || echo false)" \
    '{cron:$c,verifyCron:$v,remoteCron:(if $on then $r else null end)}'
}

# status_enrich: mevcut last-success.json'a local/remote/schedule/retention ekler (yoksa yalniz bunlarla olusturur).
# Eszamanli yazarlar (backup.sh :05, remote-sync.sh :35) .status.lock ile sirali.
status_enrich() {
  command -v jq >/dev/null || return 0
  local cur='{}' tmp="$STATUS_FILE.tmp.$$"
  mkdir -p "$(dirname "$STATUS_FILE")" "$BACKUP_DIR" 2>/dev/null || true
  (
    flock -x 8 || exit 1   # busybox flock: -w yok; kritik bolum kisa (jq + mv), bekleme zararsiz
    [ -s "$STATUS_FILE" ] && cur="$(jq -c 'if type=="object" then . else {} end' "$STATUS_FILE" 2>/dev/null || echo '{}')"
    printf '%s' "$cur" | jq -c --argjson l "$(local_stats_json)" --argjson r "$(remote_json)" \
        --argjson s "$(schedule_json)" --argjson t "$(retention_json)" \
        '. + {local:$l, remote:$r, schedule:$s, retention:$t}' > "$tmp" || { rm -f "$tmp"; exit 1; }
    mv -f "$tmp" "$STATUS_FILE"
    chmod 644 "$STATUS_FILE" 2>/dev/null || true
  ) 8>"$BACKUP_DIR/.status.lock"
}

# state_merge '<json-nesne>': uzak durum dosyasina alanlari birlestirir (atomik)
state_merge() {
  local cur='{}' tmp="$REMOTE_STATE_FILE.tmp.$$"
  [ -s "$REMOTE_STATE_FILE" ] && cur="$(jq -c '.' "$REMOTE_STATE_FILE" 2>/dev/null || echo '{}')"
  printf '%s' "$cur" | jq -c --argjson a "$1" '. + $a' > "$tmp" && mv -f "$tmp" "$REMOTE_STATE_FILE"
  chmod 640 "$REMOTE_STATE_FILE" 2>/dev/null || true
}

# metric_remote_write: backup_remote.prom (Prometheus textfile). Durum dosyasindan okunur; aga cikmaz.
metric_remote_write() {
  command -v jq >/dev/null || return 0
  mkdir -p "$METRICS_DIR"
  local st='{}' loc cfg=0 ts vs ok b c lc lb lo oiso
  [ -s "$REMOTE_STATE_FILE" ] && st="$(jq -c '.' "$REMOTE_STATE_FILE" 2>/dev/null || echo '{}')"
  [ -z "${BACKUP_REMOTE:-}" ] || cfg=1
  loc="$(local_stats_json)"
  to_ts() { [ -n "$1" ] && [ "$1" != null ] && date -u -d "$1" +%s 2>/dev/null || echo 0; }
  ts="$(to_ts "$(printf '%s' "$st" | jq -r '.lastSuccessAt // empty')")"
  vs="$(to_ts "$(printf '%s' "$st" | jq -r '.lastVerifiedAt // empty')")"
  ok="$(printf '%s' "$st" | jq -r 'if (.lastError // null) == null then 1 else 0 end')"
  [ "$cfg" = 1 ] && [ -s "$REMOTE_STATE_FILE" ] || ok=1
  b="$(printf '%s' "$st" | jq -r '.bytes // 0')"; c="$(printf '%s' "$st" | jq -r '.count // 0')"
  lc="$(printf '%s' "$loc" | jq -r '.count')"; lb="$(printf '%s' "$loc" | jq -r '.bytes')"
  oiso="$(printf '%s' "$loc" | jq -r '.oldestAt // empty')"; lo="$(to_ts "$oiso")"
  local tmp="$METRICS_DIR/backup_remote.prom.tmp.$$"
  cat > "$tmp" <<PROM
# HELP backup_remote_configured Uzak kopya (BACKUP_REMOTE) tanimli mi: 1 evet, 0 hayir
# TYPE backup_remote_configured gauge
backup_remote_configured $cfg
# HELP backup_remote_last_success_timestamp_seconds Son BASARILI ve dogrulanmis uzak yuklemenin unix zamani
# TYPE backup_remote_last_success_timestamp_seconds gauge
backup_remote_last_success_timestamp_seconds $ts
# HELP backup_remote_last_verified_timestamp_seconds Uzak kopyanin son dogrulama zamani
# TYPE backup_remote_last_verified_timestamp_seconds gauge
backup_remote_last_verified_timestamp_seconds $vs
# HELP backup_remote_last_status Son uzak yukleme denemesi: 1 basarili (ya da kapali), 0 basarisiz
# TYPE backup_remote_last_status gauge
backup_remote_last_status $ok
# HELP backup_remote_bytes Uzak hedefteki toplam yedek boyutu (bayt)
# TYPE backup_remote_bytes gauge
backup_remote_bytes $b
# HELP backup_remote_count Uzak hedefteki yedek dizini sayisi
# TYPE backup_remote_count gauge
backup_remote_count $c
# HELP backup_local_count Yerel yedek sayisi (damga basina)
# TYPE backup_local_count gauge
backup_local_count $lc
# HELP backup_local_bytes Yerel yedeklerin disk boyutu (bayt)
# TYPE backup_local_bytes gauge
backup_local_bytes $lb
# HELP backup_local_oldest_timestamp_seconds En eski yerel yedegin unix zamani
# TYPE backup_local_oldest_timestamp_seconds gauge
backup_local_oldest_timestamp_seconds $lo
PROM
  mv -f "$tmp" "$METRICS_DIR/backup_remote.prom"
  chmod 644 "$METRICS_DIR/backup_remote.prom" 2>/dev/null || true
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

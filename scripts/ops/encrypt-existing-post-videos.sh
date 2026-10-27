#!/usr/bin/env bash
# Eski DUZ gonderi videolarini sifreleme gocu (ve istege bagli yeniden sarma) - isletim betigi.
# Isi backend'in TranscodeWorker'i yapar (acik anahtarla, her yoklamada kucuk partiler, CPU dostu); bu betik
# ayari acar, ilerlemeyi izler ve bitince kapatmayi hatirlatir.
#
# Kullanim (repo kokunden, sunucuda):
#   bash scripts/ops/encrypt-existing-post-videos.sh --status
#   bash scripts/ops/encrypt-existing-post-videos.sh --run                 # duz videolari sifrele
#   bash scripts/ops/encrypt-existing-post-videos.sh --reseal-key k1       # k1 ile sarili DEK'leri aktif anahtarla yeniden yaz
# Ortam: ENV_FILE (.env.prod), PROJECT (bu), COMPOSE_FILES ("-f docker-compose.prod.yml")
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

ENV_FILE="${ENV_FILE:-.env.prod}"
PROJECT="${PROJECT:-bu}"
COMPOSE_FILES="${COMPOSE_FILES:--f docker-compose.prod.yml}"
DC=(docker compose -p "$PROJECT" $COMPOSE_FILES --env-file "$ENV_FILE")
MODE=""; RESEAL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --status) MODE=status; shift;;
    --run) MODE=run; shift;;
    --reseal-key) MODE=reseal; RESEAL="$2"; shift 2;;
    *) echo "bilinmeyen arguman: $1" >&2; exit 2;;
  esac
done
[ -n "$MODE" ] || { sed -n 2,12p "$0"; exit 2; }
[ -f "$ENV_FILE" ] || { echo "$ENV_FILE yok" >&2; exit 1; }

q() { "${DC[@]}" exec -T postgres psql -U bingol -d bingol -Atc "$1"; }

status() {
  echo "gonderi videolari: toplam=$(q "select count(*) from post_media where kind='VIDEO'")" \
       "duz(sifresiz)=$(q "select count(*) from post_media where kind='VIDEO' and encrypted=false")" \
       "sifreli=$(q "select count(*) from post_media where kind='VIDEO' and encrypted=true")"
  echo "sifreli videolar ana anahtar kimligine gore:"
  q "select split_part(wrapped_dek, ':', 1) as anahtar, count(*) from post_media where kind='VIDEO' and encrypted=true group by 1 order by 1"
  echo "donusturme kuyrugu:"
  q "select coalesce(transcode_status,'-'), count(*) from post_media where kind='VIDEO' group by 1 order by 1"
}

setenv() { # setenv KEY VALUE: .env dosyasinda anahtari ayarlar (yoksa ekler); sir degil, yalniz bayrak
  local k="$1" v="$2"
  if grep -q "^$k=" "$ENV_FILE"; then
    sed -i.bak "s|^$k=.*|$k=$v|" "$ENV_FILE" && rm -f "$ENV_FILE.bak"
  else
    printf '%s=%s\n' "$k" "$v" >> "$ENV_FILE"
  fi
}

wait_zero() { # wait_zero <sql> <aciklama>
  local n
  while true; do
    n="$(q "$1")"
    echo "$(date '+%T') kalan: $n ($2)"
    [ "$n" = 0 ] && break
    sleep 20
  done
}

case "$MODE" in
  status) status;;
  run)
    echo "Once yedek alin: ${DC[*]} exec backup /opt/backup/backup.sh"
    setenv MEDIA_ENCRYPT_EXISTING true
    "${DC[@]}" up -d backend
    wait_zero "select count(*) from post_media where kind='VIDEO' and encrypted=false and (transcode_status is null or transcode_status in ('DONE','FAILED'))" "sifrelenecek duz video"
    status
    echo "Bitti. MEDIA_ENCRYPT_EXISTING true kalabilir (yeni duz kayit olusmaz; bos dongu)."
    ;;
  reseal)
    [[ "$RESEAL" =~ ^[A-Za-z0-9_.-]{1,32}$ ]] || { echo "gecersiz anahtar kimligi" >&2; exit 2; }
    echo "UYARI: yeni anahtar CRYPTO_MASTER_KEYS'e eklenip CRYPTO_ACTIVE_KEY_ID olarak ayarli olmalidir (docs/KEY_MANAGEMENT.md bolum 3)."
    setenv MEDIA_RESEAL_KEY_ID "$RESEAL"
    "${DC[@]}" up -d backend
    wait_zero "select count(*) from post_media where kind='VIDEO' and encrypted=true and wrapped_dek like '$RESEAL:%'" "$RESEAL ile sarili video"
    setenv MEDIA_RESEAL_KEY_ID ""
    "${DC[@]}" up -d backend
    status
    echo "Bitti; MEDIA_RESEAL_KEY_ID bosaltildi. '$RESEAL' anahtarini SILMEYIN: eski yedekler hala onunla sarili DEK icerir."
    ;;
esac

#!/usr/bin/env bash
# Yedekten geri yukleme PROVASI (VPS taklidi, yerelde, yeniden calistirilabilir). Gercek sunucuya/yigina DOKUNMAZ.
#
# Akis:  source  -> uretim compose'u (proje "rel1", ayri port) tohum veriyle + yuklenmis fotografla acilir
#        backup  -> gercek yedek betigiyle (backup.sh, age sifreli) yedek alinir, yedek hosta kopyalanir
#        destroy -> yigin TAMAMEN silinir (docker compose down -v: veritabani, uploads, redis, yedek volume'u)
#        restore -> YENI bos yiginda YALNIZ yedekten + age ozel anahtarindan geri yuklenir (restore-live.sh), uygulama acilir
#        verify  -> saglik, Flyway surumu, tablo sayilari, dosya ozeti, API parmak izi (sohbet metni cozulur, fotograf baytlari)
#
# Kullanim:  bash scripts/restore-drill.sh [all|source|backup|destroy|restore|verify|build|clean]     (varsayilan: all)
# Onkosul:   Docker + Compose >= 2.24, node (JSON/parmak izi), curl, openssl, sha256sum.
# Ortam (hepsi istege bagli):
#   PROJECT=rel1            compose proje adi (volume'lar rel1_*)
#   PORT=18090              backend'in hosttaki 127.0.0.1 portu (yalniz bu prova icin)
#   DRILL_DIR=/c/bu_restore_drill   calisma dizini (anahtarlar, env, yedek kopyasi). ASCII yol kullanin (Windows'ta /c/...).
#   BACKEND_IMAGE=bu-rel1-backend:drill   Imaj yoksa COMMITLI kaynaktan (git archive $BUILD_REF, varsayilan HEAD) derlenir; baska
#                           ajanlarin bitmemis calisma-agaci degisikliklerine bagli degildir. BUILD=1 ile zorla yeniden derle;
#                           OVERLAY="backend/src/.../X.java ..." commitsiz duzeltmeleri uzerine kopyalar.
#   SEED=1                  kaynak yiginda tohum veri (dev,seed profili); 0 = bos veritabani (yalniz altyapi denemesi)
# Cikis kodu: 0 = tum denetimler gecti.
#
# GUVENLIK: sirlar bu betikle URETILIR ama yalniz $DRILL_DIR altina yazilir (repoya yazilmaz), prova bitince `clean` siler.
# Gercek sunucu icin .env.prod / deploy/ dosyalarina bu betik DOKUNMAZ.
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
REPO="$(pwd)"
REPO_W="$( (pwd -W 2>/dev/null) || pwd)"          # node (Windows) icin C:/... bicimi
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'

PROJECT="${PROJECT:-rel1}"
PORT="${PORT:-18090}"
SEED="${SEED:-1}"
if [ -z "${DRILL_DIR:-}" ]; then
  if [ -d /c ]; then DRILL_DIR=/c/bu_restore_drill; else DRILL_DIR="${TMPDIR:-/tmp}/bu_restore_drill"; fi
fi
BACKEND_IMAGE="${BACKEND_IMAGE:-bu-rel1-backend:drill}"
SEED_PASSWORD="${SEED_PASSWORD:-DevSeed-2026!}"      # docs/DEV_SEED.md (yalniz yerel tohum)
mkdir -p "$DRILL_DIR"
DRILL_DIR="$(cd "$DRILL_DIR" && pwd)"
DRILL_W="$(cd "$DRILL_DIR" && (pwd -W 2>/dev/null || pwd))"     # compose'a Windows bicimi (C:/...) verilir
ENVF="$DRILL_DIR/env.$PROJECT"
OVR="$DRILL_DIR/override.yml"
KEY="$DRILL_DIR/kurtarma.age.key"
BKP="$DRILL_DIR/backup-copy"
SNAP_DIR="$DRILL_DIR/snap"
TIMES="$DRILL_DIR/times.txt"
BASE="http://127.0.0.1:$PORT"
# docker.exe (Windows) bash yolunu (/c/...) anlamaz: compose argumanlarina Windows bicimi verilir
ENVF_W="$DRILL_W/env.$PROJECT"; OVR_W="$DRILL_W/override.yml"
DC=(docker compose -p "$PROJECT" -f docker-compose.prod.yml -f "$OVR_W" --env-file "$ENVF_W")
SERVICES=(postgres redis backend backup)               # caddy/web provada yok (TLS/alan adi gerektirir)

log()  { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die()  { echo "HATA: $*" >&2; exit 1; }
now()  { date +%s; }
mark() { echo "$1 $2" >> "$TIMES"; }                  # asama adi, sure (sn)

setenv() { # ANAHTAR DEGER -> env dosyasinda varsa degistir, yoksa ekle
  local k="$1" v="$2"
  { grep -v "^$k=" "$ENVF" 2>/dev/null || true; echo "$k=$v"; } > "$ENVF.tmp" && mv "$ENVF.tmp" "$ENVF"
  chmod 600 "$ENVF" 2>/dev/null || true
}

need() { command -v "$1" >/dev/null 2>&1 || die "gerekli arac yok: $1"; }
for t in docker node curl sha256sum openssl; do need "$t"; done

write_override() {
  cat > "$OVR" <<EOF
# restore-drill.sh tarafindan uretilir. Provada Caddy/web yok; backend yalniz 127.0.0.1'e yayinlanir.
services:
  caddy:
    profiles: ["never"]
  web:
    profiles: ["never"]
  backend:
    ports:
      - "127.0.0.1:${PORT}:8080"
    environment:
      # prod profili MAIL_ENABLED=false'u reddeder; prova gercek SMTP gondermez, kodlar log'a yazilir (yalniz bu bindirmede)
      APP_MAIL_ALLOW_LOG_ONLY: "true"
EOF
}

prepare() {
  [ -f "$ENVF" ] && [ -f "$KEY" ] && return 0
  log "hazirlik: sirlar ve age anahtari uretiliyor ($DRILL_DIR)"
  bash scripts/ops/gen-secrets.sh --env prod --out "$ENVF" --force >/dev/null
  # age anahtar cifti: yedek imajindaki age-keygen ile (host'ta age gerekmez). Ozel anahtar YALNIZ $DRILL_DIR'de.
  write_override
  "${DC[@]}" build backup >/dev/null
  local img="${PROJECT}-backup"
  docker run --rm --entrypoint age-keygen "$img" > "$KEY" 2> "$DRILL_DIR/keygen.err" || die "age-keygen basarisiz"
  chmod 600 "$KEY" 2>/dev/null || true
  local pub; pub="$(sed -n 's/^# public key: //p' "$KEY" | head -1)"
  [ -n "$pub" ] || pub="$(sed -n 's/^Public key: //p' "$DRILL_DIR/keygen.err" | head -1)"
  [ -n "$pub" ] || die "age genel anahtari okunamadi"
  mkdir -p "$DRILL_DIR/metrics"
  setenv BACKUP_AGE_RECIPIENT "$pub"
  setenv BACKUP_METRICS_DIR "$DRILL_W/metrics"
  setenv DOMAIN localhost
  setenv ACME_EMAIL drill@example.invalid
  setenv CORS_ORIGINS https://localhost
  setenv PUBLIC_WEB_URL https://localhost
  setenv ADMIN_EMAILS seed.admin@bingol.edu.tr
  setenv MAIL_ENABLED false
  setenv MAIL_HOST ""
  setenv INITIAL_FILL false
  setenv BACKEND_IMAGE "$BACKEND_IMAGE"
  # kucuk makine: bellek sinirlari
  setenv BACKEND_MEM_LIMIT 1g
  setenv BACKEND_CPUS 2
  setenv POSTGRES_MEM_LIMIT 768m
  setenv PG_SHARED_BUFFERS 128MB
  setenv PG_EFFECTIVE_CACHE_SIZE 384MB
  setenv MEDIA_TRANSCODE_ENABLED false
  setenv MEDIA_ENCRYPT_EXISTING false
  # saatlik zamanlayici prova sirasinda araya girmesin
  setenv BACKUP_CRON "0 0 1 1 *"
  setenv BACKUP_VERIFY_CRON "0 0 1 1 *"
  log "hazir. Ozel anahtar: $KEY (SIR: repoya koymayin)"
}

wait_health() { # saniye
  local t="${1:-300}" i=0
  until curl -fsS -m 3 "$BASE/actuator/health" 2>/dev/null | grep -q '"UP"'; do
    i=$((i+3)); [ "$i" -gt "$t" ] && { "${DC[@]}" logs --tail 40 backend >&2 || true; die "backend $t sn icinde saglikli olmadi"; }
    sleep 3
  done
}

psql_q() { "${DC[@]}" exec -T postgres psql -U bingol -d bingol -At -c "$1"; }

# --- parmak izi: API uzerinden (tohum kullanicisiyla giris, sohbet metni cozulmus, gonderi/avatar baytlari) ---
fingerprint() { # cikti: ANAHTAR=DEGER satirlari
  node - "$BASE" "seed.ayse@bingol.edu.tr" "$SEED_PASSWORD" "$REPO_W/scripts/fixtures/media/tiny.png" "${1:-read}" <<'JS'
const [base, email, password, png, mode] = process.argv.slice(2);
const crypto = require('crypto'), fs = require('fs');
const sha = (b) => crypto.createHash('sha256').update(b).digest('hex');
const out = (k, v) => console.log(k + '=' + v);
(async () => {
  const j = async (path, opt = {}) => {
    const r = await fetch(base + path, opt);
    if (!r.ok) throw new Error(path + ' -> ' + r.status + ' ' + (await r.text()).slice(0, 200));
    return r;
  };
  const login = await (await j('/api/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }) })).json();
  const auth = { Authorization: 'Bearer ' + login.accessToken };
  if (mode === 'upload') {                       // gercek yukleme yolundan avatar
    const fd = new FormData();
    fd.append('file', new Blob([fs.readFileSync(png)], { type: 'image/png' }), 'a.png');
    await j('/api/users/me/avatar', { method: 'POST', headers: auth, body: fd });
  }
  const me = await (await j('/api/users/me', { headers: auth })).json();
  out('api.me.email', me.email);
  out('api.me.avatar', me.avatarUrl ? 'var' : 'yok');
  if (me.avatarUrl) {
    const r = await fetch(me.avatarUrl.startsWith('http') ? me.avatarUrl : base + me.avatarUrl, { headers: auth });
    out('api.avatar.sha256', r.ok ? sha(Buffer.from(await r.arrayBuffer())) : 'HTTP' + r.status);
  }
  // sohbetler: metin cozulerek gelir (CRYPTO_MASTER_KEYS yanlissa/eksikse burada patlar)
  const convs = await (await j('/api/conversations', { headers: auth })).json();
  const list = Array.isArray(convs) ? convs : (convs.items || convs.content || []);
  out('api.conversations', list.length);
  let texts = [];
  for (const c of list) {
    const m = await (await j('/api/conversations/' + c.id + '/messages?size=50', { headers: auth })).json();
    for (const x of (m.items || m.content || [])) texts.push(c.id + ':' + x.id + ':' + (x.text ?? ''));
  }
  texts.sort();
  out('api.messages', texts.length);
  out('api.messages.sha256', sha(texts.join('\n')));
  out('api.messages.sample', JSON.stringify((texts[0] || '').slice(0, 60)));
  // kesfet akisi: gonderi gorselleri
  const feed = await (await j('/api/feed?size=15', { headers: auth })).json();
  const posts = Array.isArray(feed) ? feed : (feed.items || feed.content || []);
  out('api.feed.posts', posts.length);
  const hashes = [];
  for (const p of posts) {
    for (const m of (p.media || [])) {                 // media: [{id, kind, url, thumbUrl...}]
      if (!m.url) continue;
      const r = await fetch(m.url.startsWith('http') ? m.url : base + m.url, { headers: auth });
      hashes.push(p.id + '/' + m.id + ':' + (r.ok ? sha(Buffer.from(await r.arrayBuffer())) : 'HTTP' + r.status));
    }
  }
  hashes.sort();
  out('api.feed.images', hashes.length);
  out('api.feed.images.sha256', sha(hashes.join('\n')));
  out('api.feed.images.failed', hashes.filter((h) => h.includes('HTTP')).length);
})().catch((e) => { console.error('FINGERPRINT HATASI: ' + e.message); process.exit(3); });
JS
}

# --- parmak izi: veritabani + dosya sistemi (backend DURDURULMUSKEN alinir; yazma yok) ---
db_fingerprint() {
  local t
  echo "flyway.last=$(psql_q "select version from flyway_schema_history where success order by installed_rank desc limit 1")"
  echo "flyway.count=$(psql_q "select count(*) from flyway_schema_history where success")"
  for t in app_user community user_event post post_media conversation message conversation_key poll notification support_ticket legal_acceptance; do
    echo "db.$t=$(psql_q "select count(*) from $t" 2>/dev/null || echo yok)"
  done
  echo "db.message.ciphertext=$(psql_q "select count(*) from message where body_ciphertext is not null" 2>/dev/null || echo ?)"
  echo "db.message.plaintext_body=$(psql_q "select count(*) from message where body is not null and body <> ''" 2>/dev/null || echo ?)"
}
files_fingerprint() { # uploads volume'u (yedek servisi salt okunur baglar)
  "${DC[@]}" exec -T backup sh -c 'cd /data/uploads && echo "files.count=$(find . -type f | wc -l)" && echo "files.bytes=$(find . -type f -exec cat {} + | wc -c)" && echo "files.sha256=$(find . -type f -exec sha256sum {} + | sort -k2 | sha256sum | cut -d" " -f1)"'
}

build_backend() {
  local ref="${BUILD_REF:-HEAD}" sha src
  sha="$(git rev-parse --short "$ref")"; src="$DRILL_DIR/src-$sha"
  log "backend imaji commitli kaynaktan derleniyor ($ref=$sha; birkac dakika, Maven bellek ister)"
  mkdir -p "$src"
  git archive "$ref" backend | tar -x -C "$src"
  # OVERLAY="backend/src/..." : commit EDILMEMIS duzeltmeyi (calisma agacindan) denemek icin dosyalari uzerine kopyalar
  for f in ${OVERLAY:-}; do mkdir -p "$src/$(dirname "$f")" && cp "$f" "$src/$f" && log "ust uste bindirildi: $f"; done
  # Agir derlemeleri siraya sokan kilit (scripts/with-lock.sh); yoksa dogrudan
  local lock=(); [ -f scripts/with-lock.sh ] && lock=(bash scripts/with-lock.sh)
  "${lock[@]}" docker build -t "$BACKEND_IMAGE" "$DRILL_W/src-$sha/backend"
  echo "$sha" > "$DRILL_DIR/backend.sha"
}

phase_source() {
  local t0; t0=$(now)
  case "$PROJECT" in bu|bu-staging|bu-prod|production) die "PROJECT=$PROJECT gercek yigin adi gibi: prova ayri bir ad ister (varsayilan rel1)";; esac
  write_override; prepare
  log "onceki prova artiklari siliniyor (down -v, yalniz proje $PROJECT)"
  "${DC[@]}" down -v --remove-orphans >/dev/null 2>&1 || true   # eski volume'larda baska surumun Flyway gecmisi kalmasin
  setenv BACKEND_IMAGE "$BACKEND_IMAGE"          # env onceki kosudan kalmis olabilir
  [ -f "$TIMES" ] && rm -f "$TIMES"
  log "kaynak yigin kuruluyor (proje $PROJECT, port $PORT, imaj $BACKEND_IMAGE)"
  if [ "$SEED" = 1 ]; then setenv SPRING_PROFILES_ACTIVE "dev,seed"; else setenv SPRING_PROFILES_ACTIVE "prod"; fi
  if [ "${BUILD:-0}" = 1 ] || ! docker image inspect "$BACKEND_IMAGE" >/dev/null 2>&1; then
    build_backend
  fi
  "${DC[@]}" up -d "${SERVICES[@]}"
  wait_health 400
  if [ "$SEED" = 1 ]; then
    log "tohum verinin bitmesi bekleniyor"
    local i=0
    until "${DC[@]}" logs backend 2>&1 | grep -q 'DEV TOHUM: tamam'; do
      i=$((i+3)); [ "$i" -gt 240 ] && die "tohum 240 sn icinde bitmedi"; sleep 3
    done
    log "ek yukleme: avatar (gercek yukleme hatti)"
    fingerprint upload > "$DRILL_DIR/api.upload.out"
    sleep 2
  fi
  mkdir -p "$SNAP_DIR"
  fingerprint read > "$SNAP_DIR/api.before" || die "API parmak izi alinamadi"
  log "backend durduruluyor (tutarli parmak izi icin yazma yok)"
  "${DC[@]}" stop backend >/dev/null
  { db_fingerprint; files_fingerprint; } > "$SNAP_DIR/state.before"
  mark source $(( $(now) - t0 ))
  log "kaynak durum:"; sed 's/^/    /' "$SNAP_DIR/api.before" "$SNAP_DIR/state.before"
}

phase_backup() {
  local t0; t0=$(now)
  log "yedek aliniyor (backup.sh: pg_dump + uploads, age sifreli)"
  "${DC[@]}" exec -T -u postgres backup /opt/backup/backup.sh
  local name
  name="$("${DC[@]}" exec -T backup sh -c 'ls -1 /var/backups/daily | sort | tail -1' | tr -d '\r')"
  [ -n "$name" ] || die "yedek dizini bulunamadi"
  log "yedek: $name ; hosta kopyalaniyor (uzak kopya taklidi)"
  rm -rf "$BKP"; mkdir -p "$BKP"
  docker run --rm -v "${PROJECT}_backups:/b:ro" -v "$DRILL_W/backup-copy:/o" alpine:3 \
    sh -c "cp -a /b/daily/$name/. /o/ && chmod -R a+rX /o"
  ( cd "$BKP" && sha256sum -c SHA256SUMS )
  echo "$name" > "$DRILL_DIR/backup.name"
  ls -l "$BKP" | sed 's/^/    /'
  # Uzak kopya yedek dizininde acik metin sir/anahtar icermemeli (sifreli dosyalar)
  if grep -aq 'PGPASSWORD\|AGE-SECRET-KEY' "$BKP"/db.dump.age "$BKP"/uploads.tar.zst.age 2>/dev/null; then die "yedekte acik metin sir bulundu"; fi
  mark backup $(( $(now) - t0 ))
}

phase_destroy() {
  local t0; t0=$(now)
  log "yigin TAMAMEN siliniyor (down -v: tum volume'lar)"
  "${DC[@]}" down -v --remove-orphans
  for v in pgdata redisdata uploads backups; do
    docker volume inspect "${PROJECT}_$v" >/dev/null 2>&1 && die "volume hala var: ${PROJECT}_$v"
  done
  [ -d "$BKP" ] && [ -f "$KEY" ] || die "yedek kopyasi veya ozel anahtar eksik: geri yukleme imkansiz"
  mark destroy $(( $(now) - t0 ))
}

phase_restore() {
  local t0; t0=$(now)
  [ -f "$BKP/db.dump.age" ] || die "yedek kopyasi yok ($BKP); once backup"
  write_override
  setenv SPRING_PROFILES_ACTIVE "prod"       # geri yukleme PROD profiliyle acilir (ProdSettingsValidator + Flyway out-of-order=false)
  log "YENI bos yigin: yalniz postgres + redis"
  "${DC[@]}" up -d postgres redis
  local i=0
  until "${DC[@]}" exec -T postgres pg_isready -U bingol -d bingol >/dev/null 2>&1; do
    i=$((i+2)); [ "$i" -gt 90 ] && die "postgres hazir degil"; sleep 2
  done
  log "restore-live.sh (kuru dogrulama, DB, uploads, redis, baslatma)"
  local t1; t1=$(now)
  ENV_FILE="$ENVF_W" PROJECT="$PROJECT" COMPOSE_FILES="-f docker-compose.prod.yml -f $OVR_W" \
    bash scripts/backup/restore-live.sh "$BKP" "$KEY" --yes
  mark restore_live $(( $(now) - t1 ))
  local t2; t2=$(now)
  wait_health 400
  mark app_up $(( $(now) - t2 ))
  mark restore_total $(( $(now) - t0 ))
}

phase_verify() {
  local rc=0
  wait_health 120
  mkdir -p "$SNAP_DIR"
  fingerprint read > "$SNAP_DIR/api.after" || { echo "FAIL API parmak izi (sohbet cozulemedi / giris basarisiz)"; rc=1; }
  "${DC[@]}" stop backend >/dev/null
  { db_fingerprint; files_fingerprint; } > "$SNAP_DIR/state.after"
  "${DC[@]}" start backend >/dev/null
  echo "--- karsilastirma (kaynak -> geri yuklenen) ---"
  if diff <(sort "$SNAP_DIR/state.before") <(sort "$SNAP_DIR/state.after"); then echo "PASS veritabani + dosya parmak izi ayni"; else echo "FAIL veritabani/dosya farki"; rc=1; fi
  if [ -f "$SNAP_DIR/api.after" ] && diff "$SNAP_DIR/api.before" "$SNAP_DIR/api.after"; then echo "PASS API parmak izi ayni (giris, sohbet metni cozuldu, gonderi/avatar baytlari)"; else echo "FAIL API farki"; rc=1; fi
  wait_health 120
  curl -fsS "$BASE/actuator/health" | grep -q '"UP"' && echo "PASS saglik UP" || { echo "FAIL saglik"; rc=1; }
  if [ "${SEED:-1}" = 1 ]; then
    grep -q '^db.app_user=[1-9]' "$SNAP_DIR/state.after" && echo "PASS kullanici sayisi > 0" || { echo "FAIL kullanici yok"; rc=1; }
    grep -q '^files.count=[1-9]' "$SNAP_DIR/state.after" && echo "PASS dosya sayisi > 0" || { echo "FAIL dosya yok"; rc=1; }
    grep -q '^api.messages=[1-9]' "$SNAP_DIR/api.after" && echo "PASS cozulmus sohbet mesaji > 0" || { echo "FAIL sohbet mesaji yok"; rc=1; }
    grep -q '^api.feed.images=[1-9]' "$SNAP_DIR/api.after" && grep -q '^api.feed.images.failed=0' "$SNAP_DIR/api.after" && echo "PASS gonderi gorselleri aciliyor" || { echo "FAIL gonderi gorseli"; rc=1; }
  fi
  echo "--- sureler (sn) ---"; cat "$TIMES" 2>/dev/null || true
  return "$rc"
}

phase_clean() {
  log "temizlik: yigin + volume'lar + calisma dizini ($DRILL_DIR)"
  [ -f "$ENVF" ] && "${DC[@]}" down -v --remove-orphans 2>/dev/null || true
  rm -rf "$DRILL_DIR"
}

CMD="${1:-all}"
case "$CMD" in
  all)     phase_source; phase_backup; phase_destroy; phase_restore; phase_verify ;;
  source)  phase_source ;;
  backup)  phase_backup ;;
  destroy) phase_destroy ;;
  restore) phase_restore ;;
  verify)  phase_verify ;;
  build)   build_backend ;;
  clean)   phase_clean ;;
  *) echo "kullanim: $0 [all|source|backup|destroy|restore|verify|build|clean]" >&2; exit 2 ;;
esac

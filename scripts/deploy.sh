#!/usr/bin/env bash
# BU Kampus: yerelden tek komutla VDS'e dagitim (kod aktar -> .env.prod yoksa uret -> derle -> baslat -> saglik -> geri alma -> isitma).
# Kullanim:  scripts/deploy.sh [--dry-run] [--no-build] [--rollback] [--ip-test] [--ref <git-ref>] [--skip-warmup] [--skip-cleanup]
#   --dry-run      Sunucuya DOKUNMAZ; adimlari ve komutlari yazdirir (yerel salt-okur kontroller calisir).
#   --no-build     Imaj derlemez; mevcut yerel imajlarla `up -d` (yeni surum aktarilir ama derlenmez).
#   --rollback     Onceki surume doner (onceki imajlar :previous etiketli + onceki surum dizini).
#   --ip-test      Alan adi/DNS HAZIR DEGILKEN: Caddy yalniz HTTP (http://<IP>) ile ayaga kalkar, sertifika denenmez.
#                  .env.prod degismez (DOMAIN/CORS/PUBLIC_WEB_URL yalnizca bu calistirma icin ortamdan ezilir).
#   --ref          Dagitilacak git surumu (varsayilan HEAD). Yalniz COMMIT'LENMIS dosyalar aktarilir (git archive).
#   --skip-warmup  scripts/warmup.sh calistirma.
#   --skip-cleanup Basarili dagitimdan sonra disk temizligi kurulumunu/calistirmasini (scripts/ops/install-cleanup.sh) atlar.
#                  Temizlik hatasi dagitimi BASARISIZ saymaz (yalniz uyari). Ayrinti: docs/DEPLOY_SCRIPT.md "Disk temizligi".
# Ortam: SKIP_TESTS=1 yerel kapilari (web lint/typecheck/test/build/check:bundle) atlar.
# Yapilandirma: repo kokunde GITIGNORED `.deploy.env` (asla commit etme, loga yazma):
#   DEPLOY_HOST, DEPLOY_USER (sudo'lu hesap; varsayilan deploy), DEPLOY_DOMAIN,
#   DEPLOY_ACME_EMAIL (ilk .env.prod uretiminde ZORUNLU: Let's Encrypt bildirim adresi; varsayilan yok),
#   istege bagli: DEPLOY_KEY (varsayilan ~/.ssh/bu_deploy_ed25519), DEPLOY_ADMIN_EMAILS,
#   DEPLOY_MAIL_USER / DEPLOY_MAIL_PASSWORD (Brevo SMTP; yoksa MAIL_ENABLED=false baslar), DEPLOY_WWW (1 varsayilan),
#   DEPLOY_MAIL_FROM, DEPLOY_MAIL_REPLY_TO, DEPLOY_MAIL_FROM_NAME (gorunen ad; varsayilan "BU Kampus" + Turkce karakterler),
#   DEPLOY_ADMIN_PATH (gizli yonetim yolu; web imajina VITE_ADMIN_PATH olarak derlenir),
#   DEPLOY_STORAGE_DB_DISK_CAPACITY_BYTES (varsayilan 48 GiB), DEPLOY_STORAGE_RESERVED_BYTES (varsayilan 10 GiB).
# .env.prod ANAHTAR SENKRONU: yukaridaki DEPLOY_* degerleri sunucudaki .env.prod'a YALNIZ anahtar yoksa/bossa ya da
#   sablon (YER_TUTUCU/example) degerindeyse yazilir; elle degistirilmis deger ASLA ezilmez. ADMIN_PASSWORD ve
#   ADMIN_BASIC_ENABLED'e dokunulmaz (uretimde Basic yonetici girisi kapali kalir).
#   Parola ile giris DESTEKLENMEZ (sunucuda parola girisi kapali): anahtar kullanilir.
# Sunucu duzeni: /opt/bukampus/{releases/<sha>,current,.env.prod}  /opt/bukampus-data/{backup-metrics,secrets}
# Sirlar: .env.prod YOKSA sunucuda uretilir (izin 600) ve yerel kopya .deploy/generated-secrets.txt (600) yazilir; VARSA ASLA ezilmez.
# Cikis kodu: 0 tamam; 1 dagitim/saglik basarisiz (otomatik geri alma denendi); 2 kullanim/yapilandirma hatasi.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
ROOT="$(pwd)"

DRY=0; NOBUILD=0; ROLLBACK=0; IPTEST=0; REF="HEAD"; WARMUP=1; CLEANUP=1
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift;;
    --no-build) NOBUILD=1; shift;;
    --rollback) ROLLBACK=1; shift;;
    --ip-test) IPTEST=1; shift;;
    --ref) REF="${2:?--ref deger ister}"; shift 2;;
    --skip-warmup) WARMUP=0; shift;;
    --skip-cleanup) CLEANUP=0; shift;;
    -h|--help) sed -n '2,23p' "$0"; exit 0;;
    *) echo "bilinmeyen arguman: $1" >&2; exit 2;;
  esac
done

log()  { printf '%s [deploy] %s\n' "$(date '+%F %T')" "$*"; }
warn() { printf '%s [deploy] UYARI: %s\n' "$(date '+%F %T')" "$*" >&2; }
die()  { printf '%s [deploy] HATA: %s\n' "$(date '+%F %T')" "$*" >&2; exit "${2:-2}"; }
plan() { printf '    [dry-run] %s\n' "$*"; }

# --- yapilandirma (.deploy.env: tirnakli degerleri kabuk kendisi cozer; HICBIR YERDE yazdirilmaz) ---
[ -f .deploy.env ] || die ".deploy.env yok (DEPLOY_HOST, DEPLOY_USER, DEPLOY_DOMAIN)"
set +x
set -a; . ./.deploy.env; set +a
HOST="${DEPLOY_HOST:?DEPLOY_HOST gerekli}"
DOMAIN="${DEPLOY_DOMAIN:?DEPLOY_DOMAIN gerekli}"
SSH_USER="${DEPLOY_USER:-deploy}"
if [ "$SSH_USER" = root ]; then
  warn "DEPLOY_USER=root: sunucuda root SSH girisi kapali; 'deploy' kullaniliyor (.deploy.env'i guncelleyin)"
  SSH_USER=deploy
fi
KEY="${DEPLOY_KEY:-$HOME/.ssh/bu_deploy_ed25519}"
# Let's Encrypt kayit e-postasi (sertifika sona erme bildirimleri): GERCEK, okunan bir adres olmali; alan adi altinda varsayilan kutu YOKTUR.
ACME_EMAIL="${DEPLOY_ACME_EMAIL:-}"
unset DEPLOY_PASSWORD   # bu betik parolayi hic kullanmaz
[ -f "$KEY" ] || { [ "$DRY" = 1 ] || die "SSH anahtari yok: $KEY"; warn "SSH anahtari yok: $KEY (dry-run devam ediyor)"; }

SSH_OPTS=(-i "$KEY" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new
          -o ServerAliveInterval=30 -o ServerAliveCountMax=6 -o ConnectTimeout=20)
# UFW "limit 22/tcp" (30 sn'de 6 yeni baglanti) baglantilari dusurur: ssh cagrilari arasi en az 8 sn (damga dosyasi alt kabuklarda da gecerli)
SSH_STAMP="${TMPDIR:-/tmp}/bu-deploy-ssh-stamp"
rsh() {
  local now last=0 w
  now=$(date +%s); [ -f "$SSH_STAMP" ] && last=$(cat "$SSH_STAMP" 2>/dev/null || echo 0)
  w=$((8 - (now - last)))
  if [ "$w" -gt 0 ]; then sleep "$w"; fi
  date +%s > "$SSH_STAMP"
  ssh "${SSH_OPTS[@]}" "$SSH_USER@$HOST" "$@"
}

BASEDIR=/opt/bukampus
DATADIR=/opt/bukampus-data
PROJECT=bu

# Mutasyon yapan her sunucu islemi bu sarmalayicidan gecer: dry-run'da yalniz aciklama basilir.
remote() { # remote "<aciklama>" <ssh argumanlari...>  (stdin korunur)
  local what="$1"; shift
  if [ "$DRY" = 1 ]; then plan "sunucu: $what"; cat >/dev/null 2>&1 </dev/null || true; return 0; fi
  log "sunucu: $what"; rsh "$@"
}

[ "$DRY" = 1 ] && log "DRY-RUN: sunucuya dokunulmayacak"
log "hedef: $SSH_USER@$HOST  alan adi: $DOMAIN  mod: $([ "$IPTEST" = 1 ] && echo 'IP testi (HTTP)' || echo 'HTTPS (Caddy/Let'"'"'s Encrypt)')"

# --- DNS on kontrolu (bilgi; dagitimi engellemez) ---
dns_check() {
  local ips=""
  if command -v dig >/dev/null; then ips="$(dig +short A "$DOMAIN" 2>/dev/null | tr '\n' ' ')"
  elif command -v nslookup >/dev/null; then ips="$(nslookup "$DOMAIN" 2>/dev/null | awk '/^Address/ && NR>2 {print $2}' | tr '\n' ' ')"; fi
  case " $ips " in
    *" $HOST "*) DNS_OK=1; log "DNS tamam: $DOMAIN -> $HOST";;
    *) DNS_OK=0
       warn "$DOMAIN su an $HOST adresine COZUMLENMIYOR (bulunan: ${ips:-yok}). Let's Encrypt sertifikasi DNS yonlenene kadar ALINAMAZ."
       warn "Gerekli: $DOMAIN ve www.$DOMAIN icin A kaydi $HOST. Bu arada HTTP testi: scripts/deploy.sh --ip-test  (http://$HOST/)";;
  esac
}
DNS_OK=0
[ "$IPTEST" = 1 ] || dns_check

# =====================================================================================================
# --rollback
# =====================================================================================================
REMOTE_COMMON='
set -euo pipefail
BASEDIR=/opt/bukampus; PROJECT=bu
ENVF=$BASEDIR/.env.prod
if [ "${IPTEST:-0}" = 1 ]; then
  export DOMAIN="http://$HOST_IP" WWW_DOMAIN="http://www.invalid.test" CORS_ORIGINS="http://$HOST_IP" PUBLIC_WEB_URL="http://$HOST_IP"
fi
dc() { docker compose -p $PROJECT -f docker-compose.prod.yml -f deploy/compose.bukampus.yml --env-file "$ENVF" "$@"; }
rlog() { printf "%s [server] %s\n" "$(date "+%F %T")" "$*"; }
wait_healthy() { # servis saniye
  local svc="$1" limit="$2" t=0 cid st
  while [ "$t" -lt "$limit" ]; do
    cid="$(dc ps -q "$svc" 2>/dev/null | head -1 || true)"
    if [ -n "$cid" ]; then
      st="$(docker inspect -f "{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}" "$cid" 2>/dev/null || echo none)"
      [ "$st" = healthy ] && return 0
      [ "$st" = exited ] && return 1
    fi
    sleep 5; t=$((t+5))
  done
  return 1
}
edge_ok() { # Caddy uzerinden uca-uc: IP testinde HTTP, alan adinda yerel Host + -k (DNS/sertifika olmasa da TLS yanit verir)
  if [ "${IPTEST:-0}" = 1 ]; then
    curl -fsS -m 10 -o /dev/null "http://$HOST_IP/api/status"
  else
    curl -fsSk -m 10 -o /dev/null --resolve "$DOM:443:127.0.0.1" "https://$DOM/api/status" 2>/dev/null \
      || curl -fsS -m 10 -o /dev/null "https://$DOM/api/status"
  fi
}
do_rollback() {
  local prev; prev="$(cat "$BASEDIR/.previous_release" 2>/dev/null || true)"
  [ -n "$prev" ] && [ -d "$BASEDIR/releases/$prev" ] || { rlog "geri alinacak onceki surum yok"; return 1; }
  rlog "geri aliniyor -> $prev"
  cd "$BASEDIR/releases/$prev"
  for img in $(dc config --images 2>/dev/null | sort -u); do
    case "$img" in *:local) base="${img%:local}"
      if docker image inspect "$base:previous" >/dev/null 2>&1; then docker tag "$base:previous" "$img"; fi;; esac
  done
  dc up -d --no-build --remove-orphans
  if wait_healthy backend 300; then
    ln -sfn "releases/$prev" "$BASEDIR/current"
    cp "$BASEDIR/.current_release" "$BASEDIR/.failed_release" 2>/dev/null || true
    echo "$prev" > "$BASEDIR/.current_release"
    rlog "geri alma TAMAM: $prev calisiyor"; return 0
  fi
  rlog "geri alinan surum de saglikli degil"; dc logs --tail=60 backend || true; return 1
}
'

if [ "$ROLLBACK" = 1 ]; then
  log "GERI ALMA istendi"
  remote "onceki surume don (imajlar :previous, dizin .previous_release)" \
    "env HOST_IP='$HOST' DOM='$DOMAIN' IPTEST='$IPTEST' bash -s" <<EOF || die "geri alma basarisiz; elle mudahale: ssh $SSH_USER@$HOST, $BASEDIR/releases/*" 1
$REMOTE_COMMON
do_rollback
EOF
  log "bitti"; exit 0
fi

# =====================================================================================================
# 1) yerel kapilar
# =====================================================================================================
SHA="$(git rev-parse --verify "$REF^{commit}" 2>/dev/null)" || die "git surumu bulunamadi: $REF"
SHORT="${SHA:0:10}"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
log "1/7 yerel kapilar: dal=$BRANCH hedef commit=$SHORT"
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  warn "calisma agaci TEMIZ DEGIL: commit'lenmemis degisiklikler sunucuya GITMEZ (yalniz $SHORT aktarilir)"
fi
if ! git branch -r --contains "$SHA" 2>/dev/null | grep -q .; then
  warn "$SHORT henuz uzak depoya push edilmemis gorunuyor (aktarim git archive ile yapildigindan sunucu yine de alir)"
fi
if [ "${SKIP_TESTS:-0}" = 1 ]; then
  log "SKIP_TESTS=1: web kapilari atlandi"
elif [ "$DRY" = 1 ]; then
  plan "yerel: cd web && npm run lint && npm run typecheck && npm test && npm run build && npm run check:bundle"
else
  (cd web && npm run lint && npm run typecheck && npm test && npm run build && npm run check:bundle) \
    || die "yerel web kapilari basarisiz; duzeltin ya da SKIP_TESTS=1" 1
  log "web kapilari gecti (backend Maven derlemesi/testleri sunucuda imaj derlemesinde calisir)"
fi

# =====================================================================================================
# 2) kodu sunucuya aktar (git archive | ssh tar); sirlar/.env aktarilmaz
# =====================================================================================================
log "2/7 kod aktarimi: releases/$SHORT"
remote "dizinleri hazirla (sudo): $BASEDIR, $DATADIR/backup-metrics (uid 70 = yedek konteyneri), $DATADIR/secrets" \
  "sudo -n bash -s" <<EOF
set -euo pipefail
install -d -o $SSH_USER -g $SSH_USER -m 755 $BASEDIR $BASEDIR/releases $DATADIR
install -d -o 70 -g 70 -m 755 $DATADIR/backup-metrics
install -d -o $SSH_USER -g $SSH_USER -m 700 $DATADIR/secrets
EOF
if [ "$DRY" = 1 ]; then
  plan "yerel: git archive $SHORT (mobile/, brand/, test-results/ haric) | ssh tar -x -C $BASEDIR/releases/$SHORT"
else
  rsh "rm -rf $BASEDIR/releases/$SHORT.tmp && mkdir -p $BASEDIR/releases/$SHORT.tmp"
  git -c core.autocrlf=false archive --format=tar "$SHA" -- . ':(exclude)mobile' ':(exclude)brand' ':(exclude)test-results' ':(exclude)docs/perf-results' \
    | rsh "tar -x -C $BASEDIR/releases/$SHORT.tmp --no-same-owner --exclude='*.key'"
  rsh "set -e; rm -rf $BASEDIR/releases/$SHORT; mv $BASEDIR/releases/$SHORT.tmp $BASEDIR/releases/$SHORT; \
       cd $BASEDIR/releases/$SHORT && git_files=\$(find . -type f | wc -l) && echo \"aktarilan dosya: \$git_files\" && test -f docker-compose.prod.yml && test -f deploy/compose.bukampus.yml"
fi

# =====================================================================================================
# 3) .env.prod (yoksa uret; VARSA ASLA EZME)
# =====================================================================================================
log "3/7 .env.prod kontrolu"
HAVE_ENV=0
if [ "$DRY" = 0 ]; then
  # ssh cikis kodu: 0 = dosya var, 1 = dosya YOK, 255 = baglanti hatasi (dosya yok SAYILMAZ: yanlislikla yeniden uretilmesin)
  tries=0
  while :; do
    rc=0; rsh "test -f $BASEDIR/.env.prod" || rc=$?
    case "$rc" in
      0) HAVE_ENV=1; break;;
      1) break;;
      255) tries=$((tries+1))
           [ "$tries" -ge 3 ] && die ".env.prod kontrolu icin SSH baglantisi kurulamadi (ufw limit 22/tcp veya ag olabilir); bir sure bekleyip tekrar calistirin" 1
           warn "SSH baglanti hatasi (deneme $tries/3); 30 sn beklenip yeniden denenecek"; sleep 30;;
      *) die ".env.prod kontrolu beklenmeyen cikis kodu: $rc" 1;;
    esac
  done
fi
if [ "$HAVE_ENV" = 1 ]; then
  log ".env.prod mevcut: DEGISTIRILMEDI"
else
  [ "$DRY" = 1 ] && [ -z "$ACME_EMAIL" ] && warn "DEPLOY_ACME_EMAIL tanimli degil: ilk .env.prod uretiminde dagitim DURUR (gercek bir adres gerekir)"
  [ "$DRY" = 1 ] && plan "sunucu: $BASEDIR/.env.prod YOKSA: gen-secrets.sh ile uretilir (DB/JWT/ADMIN/CRYPTO/DEVICE sirlari, izin 600), DOMAIN=$DOMAIN, CORS/PUBLIC_WEB_URL=https://$DOMAIN, WWW_DOMAIN, BACKUP_METRICS_DIR, age yedek anahtar cifti (ozel anahtar yerel .deploy/'a alinip sunucudan SILINIR)"
  if [ "$DRY" = 0 ]; then
    [ -n "$ACME_EMAIL" ] || die "DEPLOY_ACME_EMAIL gerekli (.deploy.env): Let's Encrypt bildirimleri icin gercek bir e-posta adresi; ilk .env.prod uretimi icin zorunlu" 2
    mkdir -p .deploy; umask 077
    WWW_DOMAIN_VAL="www.$DOMAIN"; [ "${DEPLOY_WWW:-1}" = 1 ] || WWW_DOMAIN_VAL="http://www.invalid.test"
    MAIL_ON=false; [ -n "${DEPLOY_MAIL_USER:-}" ] && [ -n "${DEPLOY_MAIL_PASSWORD:-}" ] && MAIL_ON=true
    # DEPLOY_MAIL_PASSWORD gövdede (stdin) tasinir; komut satirinda GORUNMEZ
    {
      printf 'DOMAIN_V=%q\nACME_V=%q\nWWW_V=%q\nADMIN_V=%q\nMAIL_ON=%q\nMAIL_USER_V=%q\nMAIL_PASS_V=%q\n' \
        "$DOMAIN" "$ACME_EMAIL" "$WWW_DOMAIN_VAL" "${DEPLOY_ADMIN_EMAILS:-}" "$MAIL_ON" "${DEPLOY_MAIL_USER:-}" "${DEPLOY_MAIL_PASSWORD:-}"
      cat <<'REMOTE'
set -euo pipefail
BASEDIR=/opt/bukampus; DATADIR=/opt/bukampus-data
cd "$BASEDIR/releases/$(cat "$BASEDIR/.next_release")"
[ -f "$BASEDIR/.env.prod" ] && { echo "env zaten var"; exit 0; }
bash scripts/ops/gen-secrets.sh --out "$BASEDIR/.env.prod" >/dev/null
setv() { # setv ANAHTAR DEGER (ENVIRON ile: ters egik cizgi/ozel karakter guvenli; yoksa sona ekler)
  K="$1" V="$2" awk 'BEGIN{k=ENVIRON["K"]; v=ENVIRON["V"]; f=0} index($0, k"=")==1 {print k"="v; f=1; next} {print} END{if(!f) print k"="v}' "$BASEDIR/.env.prod" > "$BASEDIR/.env.prod.new"
  mv "$BASEDIR/.env.prod.new" "$BASEDIR/.env.prod"; chmod 600 "$BASEDIR/.env.prod"
}
setv DOMAIN "$DOMAIN_V"
setv ACME_EMAIL "$ACME_V"
setv WWW_DOMAIN "$WWW_V"
setv CORS_ORIGINS "https://$DOMAIN_V,https://www.$DOMAIN_V"
setv PUBLIC_WEB_URL "https://$DOMAIN_V"
setv BACKUP_METRICS_DIR "$DATADIR/backup-metrics"
[ -n "$ADMIN_V" ] && setv ADMIN_EMAILS "$ADMIN_V"
setv MAIL_ENABLED "$MAIL_ON"
if [ "$MAIL_ON" = true ]; then setv MAIL_USERNAME "$MAIL_USER_V"; setv MAIL_PASSWORD "$MAIL_PASS_V"; fi
# Yedek sifreleme anahtar cifti: genel anahtar .env.prod'a, OZEL anahtar yerele alinip sunucudan silinir
umask 077
age-keygen -o "$DATADIR/secrets/backup.age.key" 2>/dev/null
PUBK="$(age-keygen -y "$DATADIR/secrets/backup.age.key")"
setv BACKUP_AGE_RECIPIENT "$PUBK"
echo GENERATED
REMOTE
    } > .deploy/.env-gen.sh
    # release adini sunucuya yaz (betik icinde okunur)
    rsh "echo $SHORT > $BASEDIR/.next_release"
    OUT="$(rsh "bash -s" < .deploy/.env-gen.sh)" || { rm -f .deploy/.env-gen.sh; die ".env.prod uretimi basarisiz" 1; }
    rm -f .deploy/.env-gen.sh
    if printf '%s' "$OUT" | grep -q GENERATED; then
      log ".env.prod URETILDI (sunucuda, izin 600)"
      {
        echo "# Uretim: $(date '+%F %T') - $HOST - BU DOSYAYI GUVENLI YERE YEDEKLEYIN (sifre yoneticisi + cevrimdisi kasa). Commit etmeyin."
        rsh "grep -E '^(DB_PASSWORD|JWT_SECRET|ADMIN_PASSWORD|CRYPTO_MASTER_KEYS|CRYPTO_ACTIVE_KEY_ID|DEVICE_HMAC_KEY|BACKUP_AGE_RECIPIENT)=' $BASEDIR/.env.prod"
        echo "# --- age OZEL anahtari (yedek cozmek icin; sunucudan silindi) ---"
        rsh "cat $DATADIR/secrets/backup.age.key"
      } > .deploy/generated-secrets.txt
      chmod 600 .deploy/generated-secrets.txt 2>/dev/null || true
      rsh "shred -u $DATADIR/secrets/backup.age.key 2>/dev/null || rm -f $DATADIR/secrets/backup.age.key"
      log "yerel sir kopyasi: .deploy/generated-secrets.txt (gitignored). Sunucudaki ozel age anahtari SILINDI."
      [ "$MAIL_ON" = true ] || warn "MAIL_ENABLED=false: e-posta gonderilmez, dogrulama kodlari backend log'una yazilir. Brevo bilgileriyle .env.prod'u guncelleyin (docs/MAIL_DELIVERABILITY.md bolum 9)"
      [ -n "${DEPLOY_ADMIN_EMAILS:-}" ] || warn "ADMIN_EMAILS sablon degerinde (admin@example.edu.tr): .env.prod icinde gercek yonetici e-postasini girin"
    fi
  fi
fi
# sunucuya hedef release adini her durumda yaz (derleme adimi okur)
if [ "$DRY" = 0 ]; then rsh "echo $SHORT > $BASEDIR/.next_release"; fi

# --- 3b) .env.prod anahtar senkronu (yerel DEPLOY_* degerleri; mevcut elle degerler ASLA ezilmez) ---
# Gizli yonetim yolu: bicim denetimi + bastaki '/' (deger HICBIR YERE yazdirilmaz).
ADMIN_PATH_V=""
if [ -n "${DEPLOY_ADMIN_PATH:-}" ]; then
  ADMIN_PATH_V="/${DEPLOY_ADMIN_PATH#/}"; ADMIN_PATH_V="${ADMIN_PATH_V%/}"
  printf '%s' "$ADMIN_PATH_V" | grep -Eq '^/[A-Za-z0-9][A-Za-z0-9._~-]{2,60}(/[A-Za-z0-9._~-]+)*$' \
    || die "DEPLOY_ADMIN_PATH gecersiz (harf/rakam/._~- ve '/', en az 3 karakter)"
  case "${ADMIN_PATH_V#/}" in api|api/*|files|files/*|ws|ws/*|assets|assets/*|fonts|fonts/*|actuator|actuator/*|tr|tr/*|en|en/*|ar|ar/*)
    die "DEPLOY_ADMIN_PATH ayrilmis bir yolla cakisiyor (api, files, ws, assets, fonts, actuator, tr, en, ar)";; esac
fi
STORAGE_CAP_V="${DEPLOY_STORAGE_DB_DISK_CAPACITY_BYTES:-51539607552}"   # 48 GiB (VDS diski 48 GB)
STORAGE_RES_V="${DEPLOY_STORAGE_RESERVED_BYTES:-10737418240}"           # 10 GiB: isletim sistemi + docker imajlari + gunlukler
case "$STORAGE_CAP_V$STORAGE_RES_V" in *[!0-9]*) die "DEPLOY_STORAGE_* yalniz rakam (bayt) olmali";; esac
mask_state() { if [ -n "$1" ]; then printf '***'; else printf '(yok: sablon/varsayilan)'; fi; }
if [ "$DRY" = 1 ]; then
  plan "sunucu: .env.prod anahtar senkronu (yalniz eksik/bos/sablon ise yazilir, mevcut deger ezilmez; degerler MASKELI):"
  plan "    MAIL_FROM=$(mask_state "${DEPLOY_MAIL_FROM:-}") MAIL_REPLY_TO=$(mask_state "${DEPLOY_MAIL_REPLY_TO:-}") MAIL_FROM_NAME=$(mask_state "${DEPLOY_MAIL_FROM_NAME:-BU Kampus}")"
  plan "    ADMIN_PATH=$(mask_state "$ADMIN_PATH_V") (web imajina VITE_ADMIN_PATH olarak derlenir) ADMIN_EMAILS=$(mask_state "${DEPLOY_ADMIN_EMAILS:-}")"
  plan "    MAIL_USERNAME=$(mask_state "${DEPLOY_MAIL_USER:-}") MAIL_PASSWORD=$(mask_state "${DEPLOY_MAIL_PASSWORD:-}")"
  plan "    STORAGE_DB_DISK_CAPACITY_BYTES=$STORAGE_CAP_V STORAGE_RESERVED_BYTES=$STORAGE_RES_V"
  plan "    ADMIN_BASIC_ENABLED yazilmaz/degistirilmez (uretimde kapali); ADMIN_PASSWORD'e dokunulmaz"
else
  mkdir -p .deploy; umask 077
  {
    printf 'V_MAIL_FROM=%q\nV_MAIL_REPLY_TO=%q\nV_MAIL_FROM_NAME=%q\nV_ADMIN_PATH=%q\nV_ADMIN_EMAILS=%q\n' \
      "${DEPLOY_MAIL_FROM:-}" "${DEPLOY_MAIL_REPLY_TO:-}" "${DEPLOY_MAIL_FROM_NAME:-BÜ Kampüs}" "$ADMIN_PATH_V" "${DEPLOY_ADMIN_EMAILS:-}"
    printf 'V_MAIL_USER=%q\nV_MAIL_PASS=%q\nV_STORAGE_CAP=%q\nV_STORAGE_RES=%q\n' \
      "${DEPLOY_MAIL_USER:-}" "${DEPLOY_MAIL_PASSWORD:-}" "$STORAGE_CAP_V" "$STORAGE_RES_V"
    cat <<'REMOTE'
set -euo pipefail
ENVF=/opt/bukampus/.env.prod
[ -f "$ENVF" ] || { echo "ENVSYNC: .env.prod yok"; exit 0; }
getv() { # son tanimin degeri (bastaki/sondaki tirnak atilir)
  tr -d '\r' < "$ENVF" | awk -v k="$1" 'index($0,k"=")==1 {sub(/^[^=]*=/,""); v=$0} END{gsub(/^["\047]|["\047]$/,"",v); print v}'
}
putv() { # putv ANAHTAR DEGER (ENVIRON: ozel karakter guvenli; yoksa sona ekler)
  K="$1" V="$2" awk 'BEGIN{k=ENVIRON["K"]; v=ENVIRON["V"]; f=0} index($0, k"=")==1 {print k"="v; f=1; next} {print} END{if(!f) print k"="v}' "$ENVF" > "$ENVF.new"
  mv "$ENVF.new" "$ENVF"; chmod 600 "$ENVF"
}
is_tpl() { case "$1" in ""|YER_TUTUCU*|*example.edu.tr*|*example.com*|no-reply@bingol.edu.tr) return 0;; esac; return 1; }
WROTE=""
sync_tpl() { # anahtar yoksa/bossa/sablon degerindeyse yaz
  local k="$1" v="$2" cur
  [ -n "$v" ] || return 0
  cur="$(getv "$k")"
  if is_tpl "$cur"; then
    [ "$cur" = "$v" ] || { putv "$k" "$v"; WROTE="$WROTE $k"; }
  fi
}
sync_miss() { # yalniz anahtar yoksa/bossa; sablon degeri sayilmaz
  local k="$1" v="$2" cur
  [ -n "$v" ] || return 0
  cur="$(getv "$k")"
  if [ -z "$cur" ]; then putv "$k" "$v"; WROTE="$WROTE $k"; fi
}
sync_tpl MAIL_FROM "$V_MAIL_FROM"
sync_tpl MAIL_REPLY_TO "$V_MAIL_REPLY_TO"
sync_miss MAIL_FROM_NAME "$V_MAIL_FROM_NAME"
sync_miss ADMIN_PATH "$V_ADMIN_PATH"
sync_tpl ADMIN_EMAILS "$V_ADMIN_EMAILS"
# SMTP: yalniz ikisi de sablondaysa yaz; yazildiysa e-posta acilir
if [ -n "$V_MAIL_USER" ] && [ -n "$V_MAIL_PASS" ]; then
  if is_tpl "$(getv MAIL_USERNAME)" && is_tpl "$(getv MAIL_PASSWORD)"; then
    putv MAIL_USERNAME "$V_MAIL_USER"; putv MAIL_PASSWORD "$V_MAIL_PASS"; putv MAIL_ENABLED true
    WROTE="$WROTE MAIL_USERNAME MAIL_PASSWORD MAIL_ENABLED"
  fi
fi
cur="$(getv STORAGE_DB_DISK_CAPACITY_BYTES)"
case "$cur" in ""|0) putv STORAGE_DB_DISK_CAPACITY_BYTES "$V_STORAGE_CAP"; WROTE="$WROTE STORAGE_DB_DISK_CAPACITY_BYTES";; esac
sync_miss STORAGE_RESERVED_BYTES "$V_STORAGE_RES"
echo "ENVSYNC: yazilan anahtarlar:${WROTE:- (yok; her sey zaten ayarli)}"
if [ "$(getv ADMIN_BASIC_ENABLED)" = true ]; then echo "ENVSYNC-UYARI: ADMIN_BASIC_ENABLED=true (uretimde kapali olmali; elle degistirin)"; fi
exit 0
REMOTE
  } > .deploy/.env-sync.sh
  OUT="$(rsh "bash -s" < .deploy/.env-sync.sh)" || { rm -f .deploy/.env-sync.sh; die ".env.prod anahtar senkronu basarisiz" 1; }
  rm -f .deploy/.env-sync.sh
  printf '%s\n' "$OUT" | grep '^ENVSYNC' | while IFS= read -r l; do log "$l"; done
  if printf '%s' "$OUT" | grep -q 'yazilan anahtarlar:.*ADMIN_PATH'; then
    log "ADMIN_PATH degisti: web imaji yeniden derlenecek (--no-build ile calistirmayin)"
  fi
fi

# =====================================================================================================
# 4) derle + baslat (onceki imajlar :previous), 5) saglik + otomatik geri alma
# =====================================================================================================
log "4/7 derleme ve baslatma$([ "$NOBUILD" = 1 ] && echo ' (--no-build)')"
log "5/7 saglik bekleme (/actuator/health konteyner icinden; Caddy uca-uc)"
DEPLOY_RC=0
remote "docker compose build + up -d; saglik; basarisizsa otomatik geri alma" \
  "env HOST_IP='$HOST' DOM='$DOMAIN' IPTEST='$IPTEST' NOBUILD='$NOBUILD' REL='$SHORT' bash -s" <<EOF || DEPLOY_RC=$?
$REMOTE_COMMON
cd "\$BASEDIR/releases/\$REL"
dc config -q || { rlog "compose yapilandirmasi gecersiz (eksik degisken?)"; exit 3; }
CUR="\$(cat "\$BASEDIR/.current_release" 2>/dev/null || true)"
# onceki imajlari :previous etiketle (yalniz yerel derlenen :local imajlar)
for img in \$(dc config --images 2>/dev/null | sort -u); do
  case "\$img" in *:local) docker image inspect "\$img" >/dev/null 2>&1 && docker tag "\$img" "\${img%:local}:previous";; esac
done
if [ -n "\$CUR" ] && [ "\$CUR" != "\$REL" ]; then echo "\$CUR" > "\$BASEDIR/.previous_release"; fi
if [ "\$NOBUILD" != 1 ]; then rlog "imajlar derleniyor (ilk derleme 5-15 dk surebilir)"; dc build; fi
dc up -d --remove-orphans
OK=1
wait_healthy backend 360 || { rlog "backend saglikli olmadi"; OK=0; }
if [ "\$OK" = 1 ]; then wait_healthy caddy 90 || { rlog "caddy saglikli degil"; OK=0; }; fi
if [ "\$OK" = 1 ]; then
  sleep 3
  if edge_ok; then rlog "uca-uc /api/status: 200"
  elif [ "\${IPTEST:-0}" = 1 ]; then rlog "uca-uc HTTP kontrolu basarisiz"; OK=0
  else rlog "UYARI: HTTPS uca-uc kontrolu gecmedi (DNS/sertifika henuz hazir degilse beklenir); konteynerler saglikli"; fi
fi
if [ "\$OK" = 1 ]; then
  ln -sfn "releases/\$REL" "\$BASEDIR/current"
  echo "\$REL" > "\$BASEDIR/.current_release"
  # son 3 surum dizinini tut
  ls -1dt "\$BASEDIR"/releases/*/ 2>/dev/null | tail -n +4 | xargs -r rm -rf
  docker image prune -f >/dev/null 2>&1 || true
  rlog "TAMAM: \$REL"
  exit 0
fi
rlog "BASARISIZ. backend son gunlugu:"; dc logs --tail=60 backend || true
if [ -n "\$CUR" ] && [ "\$CUR" != "\$REL" ]; then
  rlog "otomatik geri alma"; echo "\$CUR" > "\$BASEDIR/.previous_release"; do_rollback && exit 1 || exit 2
fi
rlog "ilk kurulum: geri alinacak onceki surum yok; gunlukler: docker compose -p bu logs"
exit 1
EOF
if [ "$DEPLOY_RC" != 0 ]; then
  case "$DEPLOY_RC" in
    2) die "dagitim basarisiz VE geri alma basarisiz: elle mudahale gerekli (ssh $SSH_USER@$HOST; $BASEDIR/releases)" 1;;
    3) die "compose yapilandirma hatasi (.env.prod eksik degisken?)" 1;;
    *) die "dagitim basarisiz (varsa onceki surume donuldu); gunlukler: ssh $SSH_USER@$HOST 'cd $BASEDIR/current && docker compose -p bu -f docker-compose.prod.yml -f deploy/compose.bukampus.yml --env-file $BASEDIR/.env.prod logs --tail=100'" 1;;
  esac
fi

# =====================================================================================================
# 6) isitma  7) ozet
# =====================================================================================================
if [ "$WARMUP" = 1 ]; then
  if [ "$IPTEST" = 1 ]; then WBASE="http://$HOST"
  elif [ "$DNS_OK" = 1 ]; then WBASE="https://$DOMAIN"
  else WBASE=""; fi
  if [ -n "$WBASE" ]; then
    log "6/7 soguk JVM isitma: $WBASE"
    remote "scripts/warmup.sh (BASE=$WBASE)" "cd $BASEDIR/current && BASE='$WBASE' bash scripts/warmup.sh" \
      || warn "isitma hata orani esigini asti (dagitim geri alinmadi); backend gunlugune bakin"
  else
    warn "6/7 isitma ATLANDI: alan adi henuz sunucuya cozumlenmiyor (DNS sonrasi: ssh $SSH_USER@$HOST 'cd $BASEDIR/current && BASE=https://$DOMAIN bash scripts/warmup.sh')"
  fi
else
  log "6/7 isitma atlandi (--skip-warmup)"
fi

# --- 6b) disk temizligi: betik + systemd timer kurulumu (idempotent) ve bir kez calistirma. Hata dagitimi BASARISIZ saymaz. ---
# Yalniz basarili dagitimdan sonra gelir (basarisizlikta yukarida die ile cikildi; geri alma yolunda eski imajlar/dizin korunur).
if [ "$CLEANUP" = 1 ]; then
  if [ "$DRY" = 1 ]; then
    bash scripts/ops/install-cleanup.sh --dry-run --run --ref "$SHA" || warn "disk temizligi dry-run basarisiz (dagitim etkilenmedi)"
  else
    log "6b/7 disk temizligi: betik + timer kurulumu ve bir kez calistirma (scripts/ops/install-cleanup.sh)"
    bash scripts/ops/install-cleanup.sh --run --ref "$SHA"       || warn "disk temizligi kurulumu/calistirmasi basarisiz (dagitim TAMAM sayildi); elle: scripts/ops/install-cleanup.sh --run"
  fi
else
  log "6b/7 disk temizligi atlandi (--skip-cleanup)"
fi

log "7/7 OZET"
if [ "$DRY" = 1 ]; then
  log "dry-run bitti: sunucuda hicbir sey degismedi"
else
  log "surum: $SHORT  sunucu: $HOST  durum:"
  rsh "cd $BASEDIR/current && docker compose -p $PROJECT -f docker-compose.prod.yml -f deploy/compose.bukampus.yml --env-file $BASEDIR/.env.prod ps --format 'table {{.Service}}\t{{.Status}}'" || true
  if [ "$IPTEST" = 1 ]; then
    log "IP testi: http://$HOST/  (HTTPS YOK). DNS yonlenince: scripts/deploy.sh (--ip-test olmadan)"
  elif [ "$DNS_OK" = 1 ]; then
    log "site: https://$DOMAIN/  (sertifika ilk istekte alinir; Caddy gunlugunu izleyin)"
  else
    warn "DNS hazir degil: https://$DOMAIN calismaz. A kaydi: $DOMAIN ve www.$DOMAIN -> $HOST"
  fi
fi
if [ "$DRY" = 0 ]; then
  log "SONRAKI ADIMLAR (ayrinti: docs/DEPLOY_SCRIPT.md):"
  log "  1) .deploy/generated-secrets.txt (varsa) icerigini sifre yoneticisine + cevrimdisi kasaya tasiyin, sonra yerel kopyayi guvenle silin (CRYPTO_MASTER_KEYS kaybi = sifreli veri kaybi)."
  log "  2) Yonetici hesabi: DEPLOY_ADMIN_EMAILS adresiyle sitedeki yonetici kayit sayfasindan kayit olun -> e-postaya gelen kod -> giris; panel ADMIN_PATH degeriniz altindadir (ayarlanmadiysa /admin)."
fi

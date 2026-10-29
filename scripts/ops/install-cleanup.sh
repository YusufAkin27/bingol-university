#!/usr/bin/env bash
# Sunucuya disk temizligi betigini ve systemd timer'ini kurar (idempotent: degismeyen dosya yeniden yazilmaz).
# Kullanim: scripts/ops/install-cleanup.sh [--dry-run] [--ref <git-ref>] [--run] [--run-dry]
#   --dry-run   Sunucuya dokunmaz; ne yapilacagini yazar.
#   --ref       Dosyalar bu git surumunden alinir (deploy.sh bunu aktarilan commit ile cagirir); yoksa calisma agaci.
#   --run       Kurulumdan sonra temizligi bir kez gercekten calistirir (deploy.sh bunu kullanir).
#   --run-dry   Kurulumdan sonra temizligi --dry-run ile calistirir.
# Kurulan: /opt/bukampus/bin/docker-cleanup.sh, /etc/systemd/system/bu-docker-cleanup.{service,timer} (timer etkin: gunluk 04:30).
# Yapilandirma: repo kokundeki GITIGNORED `.deploy.env` (DEPLOY_HOST, DEPLOY_USER, DEPLOY_KEY) - deploy.sh ile ayni.
# Sunucuda `sudo -n` (parolasiz) gerekir. Parola/.env.prod icerigi hicbir yerde okunmaz ya da yazdirilmaz.
# Cikis kodu: 0 tamam; 1 kurulum/calistirma hatasi; 2 kullanim/yapilandirma hatasi.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

DRY=0; REF=""; RUN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift;;
    --ref) REF="${2:?--ref deger ister}"; shift 2;;
    --run) RUN=run; shift;;
    --run-dry) RUN=dry; shift;;
    -h|--help) sed -n '2,11p' "$0"; exit 0;;
    *) echo "bilinmeyen arguman: $1" >&2; exit 2;;
  esac
done
log()  { printf '%s [install-cleanup] %s\n' "$(date '+%F %T')" "$*"; }
die()  { printf '%s [install-cleanup] HATA: %s\n' "$(date '+%F %T')" "$*" >&2; exit "${2:-2}"; }

[ -f .deploy.env ] || die ".deploy.env yok (DEPLOY_HOST, DEPLOY_USER)"
set +x; set -a; . ./.deploy.env; set +a
HOST="${DEPLOY_HOST:?DEPLOY_HOST gerekli}"
SSH_USER="${DEPLOY_USER:-deploy}"; [ "$SSH_USER" != root ] || SSH_USER=deploy
KEY="${DEPLOY_KEY:-$HOME/.ssh/bu_deploy_ed25519}"
unset DEPLOY_PASSWORD

FILES=(scripts/ops/docker-cleanup.sh deploy/systemd/bu-docker-cleanup.service deploy/systemd/bu-docker-cleanup.timer)
STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"' EXIT
for f in "${FILES[@]}"; do
  if [ -n "$REF" ]; then git show "$REF:$f" > "$STAGE/$(basename "$f")" 2>/dev/null || die "$REF icinde $f yok"
  else [ -f "$f" ] || die "$f yok"; cp "$f" "$STAGE/$(basename "$f")"; fi
done
for f in "$STAGE"/*; do tr -d '\r' < "$f" > "$f.lf" && mv "$f.lf" "$f"; done   # CRLF'e karsi
bash -n "$STAGE/docker-cleanup.sh" || die "docker-cleanup.sh sozdizimi gecersiz"

if [ "$DRY" = 1 ]; then
  log "[dry-run] sunucuya kopyalanacak: ${FILES[*]}"
  log "[dry-run] sunucu: /opt/bukampus/bin/docker-cleanup.sh (root 755), systemd service+timer (root 644), daemon-reload, enable --now bu-docker-cleanup.timer"
  [ -z "$RUN" ] || log "[dry-run] kurulumdan sonra temizlik calistirilir ($RUN)"
  exit 0
fi
[ -f "$KEY" ] || die "SSH anahtari yok: $KEY"

# ufw limit 22/tcp: ssh cagrilari arasi >= 8 sn (deploy.sh ile AYNI damga dosyasi)
SSH_OPTS=(-i "$KEY" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30 -o ConnectTimeout=20)
SSH_STAMP="${TMPDIR:-/tmp}/bu-deploy-ssh-stamp"
rsh() {
  local now last=0 w
  now=$(date +%s); [ -f "$SSH_STAMP" ] && last=$(cat "$SSH_STAMP" 2>/dev/null || echo 0)
  w=$((8 - (now - last))); if [ "$w" -gt 0 ]; then sleep "$w"; fi
  date +%s > "$SSH_STAMP"
  ssh "${SSH_OPTS[@]}" "$SSH_USER@$HOST" "$@"
}

PAYLOAD="$(tar -cf - -C "$STAGE" . | base64 | tr -d '\n')"
log "kuruluyor: $SSH_USER@$HOST"
rsh "sudo -n bash -s" <<EOF || die "kurulum basarisiz" 1
set -euo pipefail
PAYLOAD='$PAYLOAD'
T="\$(mktemp -d)"; trap 'rm -rf "\$T"' EXIT
printf '%s' "\$PAYLOAD" | base64 -d | tar -x -C "\$T"
CHANGED=0
inst() { # inst kaynak hedef mod
  if [ -f "\$2" ] && cmp -s "\$1" "\$2"; then echo "degismedi: \$2"; else install -m "\$3" -o root -g root "\$1" "\$2"; echo "yazildi: \$2"; CHANGED=1; fi
}
install -d -o root -g root -m 755 /opt/bukampus/bin
bash -n "\$T/docker-cleanup.sh"
inst "\$T/docker-cleanup.sh" /opt/bukampus/bin/docker-cleanup.sh 755
inst "\$T/bu-docker-cleanup.service" /etc/systemd/system/bu-docker-cleanup.service 644
inst "\$T/bu-docker-cleanup.timer" /etc/systemd/system/bu-docker-cleanup.timer 644
systemd-analyze verify /etc/systemd/system/bu-docker-cleanup.service /etc/systemd/system/bu-docker-cleanup.timer
[ "\$CHANGED" = 0 ] || systemctl daemon-reload
systemctl enable --now bu-docker-cleanup.timer >/dev/null 2>&1
systemctl is-enabled bu-docker-cleanup.timer
systemctl list-timers bu-docker-cleanup.timer --no-pager | head -3
EOF

case "$RUN" in
  run) log "temizlik calistiriliyor (deploy kullanicisi)"; rsh "/opt/bukampus/bin/docker-cleanup.sh" ;;
  dry) log "temizlik --dry-run"; rsh "/opt/bukampus/bin/docker-cleanup.sh --dry-run" ;;
esac
log "tamam"

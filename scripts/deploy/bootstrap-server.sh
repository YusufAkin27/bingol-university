#!/usr/bin/env bash
# Ubuntu 22.04/24.04 sunucu hazirligi: Docker, ufw (yalniz 22/80/443), fail2ban, otomatik guvenlik guncellemesi.
# Kullanim (root): bash bootstrap-server.sh [--ssh-port 22] [--deploy-user bu]
# Tekrar calistirilabilir (idempotent). SSH anahtarinizi EKLEMEDEN parola girisini kapatmayin: bu betik kapatmaz,
# yalniz oneriyi yazdirir.
set -euo pipefail

SSH_PORT=22
DEPLOY_USER=bu
while [ $# -gt 0 ]; do
  case "$1" in
    --ssh-port) SSH_PORT="$2"; shift 2;;
    --deploy-user) DEPLOY_USER="$2"; shift 2;;
    *) echo "bilinmeyen arguman: $1" >&2; exit 2;;
  esac
done
[ "$(id -u)" = 0 ] || { echo "root olarak calistirin (sudo)" >&2; exit 1; }
. /etc/os-release
[ "${ID:-}" = ubuntu ] || echo "UYARI: Ubuntu disi sistem ($ID); adimlar uyarlanmali"

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends ca-certificates curl gnupg ufw fail2ban unattended-upgrades \
  apt-listchanges age openssl git jq

# --- Docker (resmi depo) ---
if ! command -v docker >/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
systemctl enable --now docker

# Docker log donusumu (konteyner bazli max-size compose'ta da var; bu ikinci emniyet)
mkdir -p /etc/docker
if [ ! -f /etc/docker/daemon.json ]; then
  cat > /etc/docker/daemon.json <<'JSON'
{ "log-driver": "json-file", "log-opts": { "max-size": "10m", "max-file": "5" }, "live-restore": true }
JSON
  systemctl restart docker
fi

# --- dagitim kullanicisi ---
id "$DEPLOY_USER" >/dev/null 2>&1 || adduser --disabled-password --gecos "" "$DEPLOY_USER"
usermod -aG docker "$DEPLOY_USER"

# --- guvenlik duvari: yalniz SSH + HTTP(S). Docker, ufw'yi atlayabilir: postgres/redis zaten port yayinlamaz ---
ufw default deny incoming
ufw default allow outgoing
ufw allow "${SSH_PORT}/tcp" comment ssh
ufw allow 80/tcp comment http-acme
ufw allow 443/tcp comment https
ufw allow 443/udp comment http3
ufw --force enable

# --- fail2ban: SSH ---
cat > /etc/fail2ban/jail.d/bu-sshd.local <<EOF
[sshd]
enabled = true
port = ${SSH_PORT}
maxretry = 5
findtime = 10m
bantime = 1h
EOF
systemctl enable --now fail2ban
systemctl restart fail2ban

# --- otomatik guvenlik guncellemesi (yeniden baslatma elle: docker konteynerleri kisa sure kesilir) ---
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
cat > /etc/apt/apt.conf.d/52bu-unattended <<'EOF'
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOF
systemctl enable --now unattended-upgrades

# --- cekirdek sertlestirme (hafif) ---
cat > /etc/sysctl.d/99-bu.conf <<'EOF'
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
vm.swappiness = 10
EOF
sysctl --system >/dev/null

mkdir -p /opt/bu && chown "$DEPLOY_USER":"$DEPLOY_USER" /opt/bu

cat <<EOF

TAMAM. Sonraki adimlar:
 1. /opt/bu altina repoyu klonlayin (kullanici: $DEPLOY_USER) ve: bash scripts/ops/gen-secrets.sh
 2. DNS A/AAAA kaydi bu sunucuyu gostersin; 80/443 acik olmali (Let's Encrypt).
 3. SSH: yalniz anahtar girisi onerilir (/etc/ssh/sshd_config: PasswordAuthentication no, PermitRootLogin no);
    anahtarinizin calistigini ayri bir oturumda dogruladiktan SONRA uygulayin.
 4. Bu betik SSH ayarini DEGISTIRMEZ. Ilk dagitim: bash scripts/deploy/update.sh --first
EOF

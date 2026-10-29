# deploy.sh: yerelden VDS'e dağıtım (bukampus.com.tr)

`scripts/deploy.sh` yerel makineden SSH ile tek komutta dağıtır. Sunucu tarafı (`scripts/deploy/update.sh`) depoyu `git pull` ile çeken, sunucuda git erişimi gerektiren yoldur; `deploy.sh` ise özel depoya sunucudan erişim gerekmesin diye kodu `git archive | ssh tar` ile aktarır. İkisi birlikte kullanılmaz: sunucu düzeni `deploy.sh` içindir.

## Sunucu (DEP1 ile hazırlandı)

- Ubuntu 24.04, kullanıcı `deploy` (sudo, parolasız; yalnız SSH anahtarı), root girişi ve parola ile SSH **kapalı** (`/etc/ssh/sshd_config.d/00-bu-hardening.conf`, `AllowUsers deploy`).
- ufw: 22 (hız sınırlı), 80, 443/tcp, 443/udp. fail2ban (sshd), unattended-upgrades (yalnız güvenlik), chrony, `Europe/Istanbul`, 2 GB swap, `vm.swappiness=10`, `vm.overcommit_memory=1`, THP kapalı, journald 500 MB.
- Docker Engine + compose eklentisi; `daemon.json`: json-file 10m x 3, `live-restore`.
- Dizinler: `/opt/bukampus/{releases/<sha>,current,.env.prod}`, `/opt/bukampus-data/{backup-metrics,secrets}`. Postgres/uploads/yedekler Docker adlandırılmış birimlerindedir (`/var/lib/docker/volumes`, tek 48 GB bölüm).
- Özel anahtar yerelde `~/.ssh/bu_deploy_ed25519` (repo dışı). Bağlantı: `ssh -i ~/.ssh/bu_deploy_ed25519 deploy@77.83.37.160`.

## Kullanım

```bash
# repo kokunde .deploy.env (gitignored): DEPLOY_HOST, DEPLOY_USER=deploy, DEPLOY_DOMAIN
# istege bagli: DEPLOY_KEY, DEPLOY_ACME_EMAIL, DEPLOY_ADMIN_EMAILS, DEPLOY_MAIL_USER, DEPLOY_MAIL_PASSWORD
scripts/deploy.sh --dry-run          # sunucuya dokunmadan adimlari yazdirir
scripts/deploy.sh --ip-test          # DNS hazir degilken: yalniz HTTP, http://<IP>/ uzerinden test
scripts/deploy.sh                    # gercek dagitim (HTTPS, DNS hazir olmali)
scripts/deploy.sh --no-build         # derlemeden mevcut imajlarla baslat
scripts/deploy.sh --rollback         # onceki surume don
SKIP_TESTS=1 scripts/deploy.sh       # yerel web kapilarini atla
```

Adımlar: (1) yerel kapılar (git durumu uyarısı; `web`: lint, typecheck, test, build, `check:bundle`), (2) `git archive` ile yalnız **commit'lenmiş** kodu `releases/<sha>`'ya aktarma (`mobile/` ve `brand/` hariç), (3) sunucuda `.env.prod` yoksa üretme (varsa asla ezilmez), (4) önceki imajları `:previous` etiketleyip `docker compose build` + `up -d`, (5) `backend` ve `caddy` sağlık bekleme, başarısızsa otomatik geri alma, (6) `scripts/warmup.sh`, (7) özet.

## Sırlar

`.env.prod` ilk kez üretilirken (`scripts/ops/gen-secrets.sh`) `DB_PASSWORD`, `JWT_SECRET`, `ADMIN_PASSWORD`, `CRYPTO_MASTER_KEYS`/`CRYPTO_ACTIVE_KEY_ID`, `DEVICE_HMAC_KEY` rastgele oluşur. Sunucuda izin 600'dür. Yerel kopya `.deploy/generated-secrets.txt` (gitignored) dosyasına yazılır: **şifre yöneticisine ve çevrimdışı kasaya taşıyın**; `CRYPTO_MASTER_KEYS` kaybı şifreli verinin kaybıdır. Yedek şifreleme için sunucuda bir `age` anahtar çifti üretilir: genel anahtar `BACKUP_AGE_RECIPIENT`'e yazılır, **özel anahtar yerel dosyaya alınıp sunucudan silinir**.

`DEPLOY_MAIL_USER/DEPLOY_MAIL_PASSWORD` verilmezse `MAIL_ENABLED=false` başlar (doğrulama kodları backend günlüğüne yazılır; yalnız ön test için). Brevo bilgileri sonradan `.env.prod`'a girilir ve `docker compose ... up -d backend` ile uygulanır.

## Caddy ve www

`deploy/compose.bukampus.yml` bindirmesi `deploy/Caddyfile.bukampus` dosyasını bağlar: paylaşılan `deploy/Caddyfile` (`/etc/caddy/Caddyfile.base`) içe aktarılır, ek olarak `www.<alan>` kalıcı olarak apex'e yönlenir. `.env.prod` içinde `WWW_DOMAIN=www.bukampus.com.tr`. Bindirme port yayınlamaz (docs/DEPLOY.md A4: kök `docker-compose.yml` ile birleştirmek yasaktır; bu bindirme onunla birleştirilmez).

## DNS yönlenmeden önce

Let's Encrypt sertifikası, `bukampus.com.tr` ve `www.bukampus.com.tr` sunucu IP'sine çözümlenmeden **alınamaz** (deploy.sh bunu açıkça uyarır; sağlık denetimi konteyner durumuna bakar, HTTPS uçtan uca kontrolü başarısız olsa da dağıtımı geri almaz). Beklerken `--ip-test` ile `http://77.83.37.160/` üzerinden sistem denenebilir; `.env.prod` değişmez. DNS yönlendikten sonra `--ip-test` olmadan yeniden çalıştırın.

## Gerekli DNS kayıtları

| Ad | Tür | Değer |
|---|---|---|
| `bukampus.com.tr` | A | `77.83.37.160` |
| `www.bukampus.com.tr` | A | `77.83.37.160` |

E-posta (Brevo; alan adı `bukampus.online` kullanılıyorsa onun DNS'inde): SPF, DKIM ve DMARC kayıtları [MAIL_DELIVERABILITY.md](MAIL_DELIVERABILITY.md) bölüm 9'dadır.

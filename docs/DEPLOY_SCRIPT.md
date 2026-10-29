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
# istege bagli: DEPLOY_KEY, DEPLOY_ACME_EMAIL, DEPLOY_ADMIN_EMAILS, DEPLOY_MAIL_USER, DEPLOY_MAIL_PASSWORD,
#   DEPLOY_MAIL_FROM, DEPLOY_MAIL_REPLY_TO, DEPLOY_MAIL_FROM_NAME, DEPLOY_ADMIN_PATH,
#   DEPLOY_STORAGE_DB_DISK_CAPACITY_BYTES, DEPLOY_STORAGE_RESERVED_BYTES
scripts/deploy.sh --dry-run          # sunucuya dokunmadan adimlari yazdirir
scripts/deploy.sh --ip-test          # DNS hazir degilken: yalniz HTTP, http://<IP>/ uzerinden test
scripts/deploy.sh                    # gercek dagitim (HTTPS, DNS hazir olmali)
scripts/deploy.sh --no-build         # derlemeden mevcut imajlarla baslat
scripts/deploy.sh --rollback         # onceki surume don
SKIP_TESTS=1 scripts/deploy.sh       # yerel web kapilarini atla
```

Adımlar: (1) yerel kapılar (git durumu uyarısı; `web`: lint, typecheck, test, build, `check:bundle`), (2) `git archive` ile yalnız **commit'lenmiş** kodu `releases/<sha>`'ya aktarma (`mobile/` ve `brand/` hariç), (3) sunucuda `.env.prod` yoksa üretme (varsa asla ezilmez) ve ardından **anahtar senkronu** (aşağıda), (4) önceki imajları `:previous` etiketleyip `docker compose build` + `up -d`, (5) `backend` ve `caddy` sağlık bekleme, başarısızsa otomatik geri alma, (6) `scripts/warmup.sh`, (7) özet.

## Sırlar

`.env.prod` ilk kez üretilirken (`scripts/ops/gen-secrets.sh`) `DB_PASSWORD`, `JWT_SECRET`, `ADMIN_PASSWORD`, `CRYPTO_MASTER_KEYS`/`CRYPTO_ACTIVE_KEY_ID`, `DEVICE_HMAC_KEY` rastgele oluşur. Sunucuda izin 600'dür. Yerel kopya `.deploy/generated-secrets.txt` (gitignored) dosyasına yazılır: **şifre yöneticisine ve çevrimdışı kasaya taşıyın**; `CRYPTO_MASTER_KEYS` kaybı şifreli verinin kaybıdır. Yedek şifreleme için sunucuda bir `age` anahtar çifti üretilir: genel anahtar `BACKUP_AGE_RECIPIENT`'e yazılır, **özel anahtar yerel dosyaya alınıp sunucudan silinir**.

`DEPLOY_MAIL_USER/DEPLOY_MAIL_PASSWORD` verilmezse `MAIL_ENABLED=false` başlar (doğrulama kodları backend günlüğüne yazılır; yalnız ön test için). Brevo bilgileri sonradan `.env.prod`'a girilir ve `docker compose ... up -d backend` ile uygulanır.

## `.env.prod` anahtar senkronu ve yönetim yolu

Her dağıtımda (`.env.prod` yeni üretilmiş ya da var olsa da) `.deploy.env` içindeki değerler sunucudaki `.env.prod`'a **yalnız anahtar yoksa/boşsa ya da şablon değerindeyse** (`YER_TUTUCU…`, `example`) yazılır; elle değiştirilmiş değer **asla ezilmez**. Yazılan anahtarların yalnız **adları** günlüğe çıkar, değerler hiçbir yerde basılmaz (`--dry-run` çıktısında da maskelidir).

| `.deploy.env` | `.env.prod` | Kural |
|---|---|---|
| `DEPLOY_MAIL_FROM` | `MAIL_FROM` | boş/şablon ise |
| `DEPLOY_MAIL_REPLY_TO` | `MAIL_REPLY_TO` | boş/şablon ise |
| `DEPLOY_MAIL_FROM_NAME` (yoksa `BÜ Kampüs`) | `MAIL_FROM_NAME` | yoksa/boşsa |
| `DEPLOY_ADMIN_EMAILS` | `ADMIN_EMAILS` | boş/şablon ise |
| `DEPLOY_MAIL_USER` + `DEPLOY_MAIL_PASSWORD` | `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_ENABLED=true` | ikisi de şablondaysa |
| `DEPLOY_ADMIN_PATH` | `ADMIN_PATH` | yoksa/boşsa; biçim doğrulanır (`/` ile başlar, ayrılmış yollarla çakışmaz) |
| `DEPLOY_STORAGE_DB_DISK_CAPACITY_BYTES` (varsayılan `51539607552` = 48 GiB) | `STORAGE_DB_DISK_CAPACITY_BYTES` | yoksa/boş/0 ise |
| `DEPLOY_STORAGE_RESERVED_BYTES` (varsayılan `10737418240` = 10 GiB) | `STORAGE_RESERVED_BYTES` | yoksa/boşsa |

Depolama değerleri DS1 doluluk uyarısı içindir (`GET /api/admin/system/storage`): VDS diski 48 GB olduğundan yüzde `DB + yüklemeler + yedek + reserved` / kapasite olarak hesaplanır; `reserved` işletim sistemi, Docker imajları ve günlükler payıdır.

`ADMIN_PATH` web imajına **derleme argümanı** (`VITE_ADMIN_PATH`) olarak geçer (`docker-compose.prod.yml` `build.args` + `web/Dockerfile` `ARG`): değeri değiştirirseniz `--no-build` **kullanmayın**; yol istemci paketinde açık yazılıdır, güvenlik önlemi değil yalnız gürültü azaltmadır (`/api/admin/**` yine ADMIN yetkisiyle korunur). Ayarlıysa `/admin` rotası kayıtlı değildir; panel ve yönetici kaydı `ADMIN_PATH değeriniz` altındadır (`<ADMIN_PATH değeriniz>/login`, `<ADMIN_PATH değeriniz>/register`).

Yönetici Basic auth (`ADMIN_BASIC_ENABLED`) üretimde **kapalıdır**; betik bu anahtarı yazmaz/açmaz (açıksa yalnız uyarır). `.env` içindeki yerel `ADMIN_PASSWORD` sunucuya **taşınmaz**: üretimde `gen-secrets.sh`'ın ürettiği 24 karakterli rastgele değer geçerlidir.

## İlk dağıtımdan sonra yapmanız gerekenler

1. **Üretilen sırları yedekleyin.** Betik `.env.prod`'u sunucuda üretir ve yerel kopyayı `.deploy/generated-secrets.txt` (gitignored, izin 600) dosyasına yazar: `DB_PASSWORD`, `JWT_SECRET`, `ADMIN_PASSWORD`, `CRYPTO_MASTER_KEYS` (+ `CRYPTO_ACTIVE_KEY_ID`), `DEVICE_HMAC_KEY`, `BACKUP_AGE_RECIPIENT` ve yedek **age özel anahtarı** (sunucudan silinir). Dosyanın tamamını şifre yöneticisine **ve** çevrimdışı kasaya taşıyın, ardından yerel kopyayı güvenle silin. `CRYPTO_MASTER_KEYS` kaybı şifreli mesaj/video verisinin geri dönüşsüz kaybıdır; age özel anahtarı olmadan yedekler açılamaz. Ayrıntı: [KEY_MANAGEMENT.md](KEY_MANAGEMENT.md).
2. **Yönetici hesabını kaydedin.** `ADMIN_EMAILS` içindeki adres (`DEPLOY_ADMIN_EMAILS`, ör. `ysufakin23@gmail.com`) `bingol.edu.tr` olmak zorunda değildir; sunucu yalnız bu adreslere alan adı kısıtını atlatır:
   1. Tarayıcıda `https://bukampus.com.tr/<ADMIN_PATH değeriniz>/register` adresini açın (`ADMIN_PATH` ayarlı değilse `/admin/register`; giriş sayfasındaki "Yönetici hesabı oluşturun" bağlantısı da aynı yere gider).
   2. Ad soyad, `DEPLOY_ADMIN_EMAILS` adresi, en az 8 karakterli bir şifre girin, metinleri kabul edin.
   3. O adrese gelen 6 haneli kodu girin (10 dk geçerli; gelmezse "Kodu yeniden gönder"). Mail ayarı kapalıysa (`MAIL_ENABLED=false`) kod backend günlüğündedir: `docker compose -p bu ... logs backend`.
   4. Doğrulama sonrası otomatik giriş yapılır; rol ADMIN (profil FULL) olur ve panel açılır. Sonraki girişler `<ADMIN_PATH değeriniz>/login` üzerindendir. Bu şifre yalnızca sizin belirlediğiniz şifredir; `.env.prod`'daki `ADMIN_PASSWORD` yönetici hesabının şifresi **değildir** (Basic yöntemi üretimde kapalıdır).
3. Başka bir adresle kayıt olursanız (listede yoksa) sunucu okul dışı alan adını reddeder; listede olmayan bir `bingol.edu.tr` hesabı doğrulanır ama panelde "yetkiniz yok" görür. Yeni yönetici eklemek için `.env.prod` `ADMIN_EMAILS` değerini güncelleyip backend'i yeniden başlatın (ya da panelden mevcut bir yönetici rolü verir).
4. DNS/Brevo adımları (SPF, DKIM, DMARC) için [MAIL_DELIVERABILITY.md](MAIL_DELIVERABILITY.md) bölüm 9. Maillerde görünen gönderen adı `BÜ Kampüs`'tür; Gmail'deki yuvarlak profil resmi BIMI olmadan değişmez.

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

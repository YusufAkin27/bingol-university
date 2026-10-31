# deploy.sh: yerelden VDS'e dağıtım (bukampus.com.tr)

`scripts/deploy.sh` yerel makineden SSH ile tek komutta dağıtır ve **üretimin tek doğru dağıtım yoludur** ([DEPLOY.md](DEPLOY.md) bölüm 0). Sunucu tarafı (`scripts/deploy/update.sh`) depoyu `git pull` ile çeken, sunucuda git erişimi gerektiren alternatif yoldur (staging); `deploy.sh` ise özel depoya sunucudan erişim gerekmesin diye kodu `git archive | ssh tar` ile aktarır. İkisi birlikte kullanılmaz: sunucu düzeni `deploy.sh` içindir.

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
#   DEPLOY_STORAGE_DB_DISK_CAPACITY_BYTES, DEPLOY_STORAGE_RESERVED_BYTES,
#   DEPLOY_BACKUP_REMOTE, DEPLOY_BACKUP_WEBHOOK_URL, DEPLOY_ALLOW_LOG_ONLY, DEPLOY_MAIL_ON_SERVER
scripts/deploy.sh --dry-run          # sunucuya dokunmadan adimlari yazdirir
scripts/deploy.sh --ip-test          # DNS hazir degilken: yalniz HTTP, http://<IP>/ uzerinden test
scripts/deploy.sh                    # gercek dagitim (HTTPS, DNS hazir olmali)
scripts/deploy.sh --ref <git-ref>    # HEAD yerine belirli commit/etiket (yalniz commit'lenmis dosyalar gider)
scripts/deploy.sh --no-build         # derlemeden mevcut imajlarla baslat
scripts/deploy.sh --skip-backup      # dagitim oncesi yedegi atla (ONERILMEZ)
scripts/deploy.sh --skip-warmup      # scripts/warmup.sh calistirma
scripts/deploy.sh --skip-cleanup     # disk temizligi kurulumunu/calistirmasini atla
scripts/deploy.sh --rollback         # onceki surume don
scripts/deploy.sh -h                 # tam yardim (basliktaki tum bayrak ve DEPLOY_* anahtarlari)
SKIP_TESTS=1 scripts/deploy.sh       # yerel web kapilarini atla
HEALTH_WAIT_BACKEND=900 scripts/deploy.sh   # backend saglik bekleme suresi (sn, varsayilan 600)
```

Adımlar: (0) **e-posta ön koşulu** (aşağıda; bilgi yoksa HİÇBİR şey aktarılmadan reddedilir), (1) yerel kapılar (git durumu uyarısı; `web`: lint, typecheck, test, build, `check:bundle`), (2) `git archive` ile yalnız **commit'lenmiş** kodu `releases/<sha>`'ya aktarma (`mobile/` ve `brand/` hariç), (3) sunucuda `.env.prod` yoksa üretme (varsa asla ezilmez) ve ardından **anahtar senkronu** (aşağıda; uyarılar ve e-posta denetimi), (4) **bekleyen Flyway migration uyarısı + dağıtım öncesi şifreli yedek (başarısızsa DUR)**, sonra önceki imajları `:previous` etiketleyip `docker compose build` + `up -d`, (5) `backend` ve `caddy` sağlık bekleme (`HEALTH_WAIT_BACKEND`, varsayılan 600 sn; soğuk açılış 262-465 sn), başarısızsa otomatik geri alma, (6) `scripts/warmup.sh`, (7) özet.

Çıkış kodları: 0 tamam; 1 dağıtım/sağlık/**yedek** başarısız; 2 kullanım/yapılandırma hatası (ör. e-posta bilgisi yok). `-h` çıktısı betiğin başlık yorumunun tamamıdır.

## Sırlar

`.env.prod` ilk kez üretilirken (`scripts/ops/gen-secrets.sh`) `DB_PASSWORD`, `JWT_SECRET`, `ADMIN_PASSWORD`, `CRYPTO_MASTER_KEYS`/`CRYPTO_ACTIVE_KEY_ID`, `DEVICE_HMAC_KEY` rastgele oluşur. Sunucuda izin 600'dür. Yerelde **iki AYRI dosya** yazılır (gitignored, izin 600): `.deploy/generated-secrets.txt` (uygulama sırları + `CRYPTO_MASTER_KEYS`) ve `.deploy/backup-age-private.key` (yedek **age ÖZEL anahtarı**). **İkisini şifre yöneticisine ve çevrimdışı kasaya, FARKLI emanet yerlerine taşıyın** (tek yerde ikisi birden = tek hata noktası); `CRYPTO_MASTER_KEYS` kaybı şifreli verinin kaybıdır, age özel anahtarı olmadan yedekler açılamaz. Yedek şifreleme için sunucuda bir `age` anahtar çifti üretilir: genel anahtar `BACKUP_AGE_RECIPIENT`'e yazılır; özel anahtar **yerel kopya doğrulanınca** (`AGE-SECRET-KEY-` satırı var) sunucudan silinir, doğrulanamazsa silinmez ve uyarı verilir. Emanet düzeni ve tatbikat günlüğü: [KEY_MANAGEMENT.md](KEY_MANAGEMENT.md), [RUNBOOK.md](RUNBOOK.md) bölüm 12.

**E-posta ön koşulu (prod'da zorunlu).** `MAIL_ENABLED=false` ile prod profili **BAŞLAMAZ** (`ProdSettingsValidator`; bilinçli `APP_MAIL_ALLOW_LOG_ONLY=true` verilmedikçe). Bu yüzden `deploy.sh` Brevo bilgisi (`DEPLOY_MAIL_USER` + `DEPLOY_MAIL_PASSWORD`) yoksa dağıtımı **baştan reddeder** (adım 0, çıkış 2; eskiden derleme + otomatik geri alma yaşanırdı). Gerçek çalıştırmada yerelde bilgi yoksa sunucudaki `.env.prod` denetlenir (SMTP etkin değilse ya da ilk kurulumsa reddedilir); `--dry-run` sunucuya bakmadığından yerel bilgi ya da `DEPLOY_MAIL_ON_SERVER=1` ister. Yalnız **bilinçli ve geçici** log-only için `DEPLOY_ALLOW_LOG_ONLY=1`: yeni `.env.prod`'a `MAIL_ENABLED=false` + `APP_MAIL_ALLOW_LOG_ONLY=true` yazılır (kodlar backend günlüğüne düşer, e-posta GİTMEZ; gerçek kullanıcıya açmadan önce kaldırın). Brevo bilgileri sonradan `.env.prod`'a girilirse `docker compose ... up -d backend` ile uygulanır.

## SSH hız sınırı ve ACME e-postası

Sunucuda `ufw limit 22/tcp` (30 sn'de 6 yeni bağlantı) olduğundan betik her ssh çağrısı arasında en az 8 sn bekler; `.env.prod` var mı denetiminde ssh çıkış kodu ayrılır (0 var, 1 yok, **255 bağlantı hatası** = "yok" sayılmaz, 3 kez 30 sn arayla yeniden denenir, olmazsa durur). `DEPLOY_ACME_EMAIL` ilk `.env.prod` üretiminde **zorunludur** (Let's Encrypt bildirim adresi; `admin@<alan>` varsayımı kaldırıldı, o kutu yoktur).

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
| `DEPLOY_BACKUP_REMOTE` | `BACKUP_REMOTE` | yoksa/boşsa; boş kalırsa UYARI (yedekler yalnız sunucu diskinde) |
| `DEPLOY_BACKUP_WEBHOOK_URL` | `BACKUP_WEBHOOK_URL` | yoksa/boşsa; boş kalırsa UYARI |

Depolama değerleri DS1 doluluk uyarısı içindir (`GET /api/admin/system/storage`): VDS diski 48 GB olduğundan yüzde `DB + yüklemeler + yedek + reserved` / kapasite olarak hesaplanır; `reserved` işletim sistemi, Docker imajları ve günlükler payıdır.

`ADMIN_PATH` web imajına **derleme argümanı** (`VITE_ADMIN_PATH`) olarak geçer (`docker-compose.prod.yml` `build.args` + `web/Dockerfile` `ARG`): değeri değiştirirseniz `--no-build` **kullanmayın**; yol istemci paketinde açık yazılıdır, güvenlik önlemi değil yalnız gürültü azaltmadır (`/api/admin/**` yine ADMIN yetkisiyle korunur). Ayarlıysa `/admin` rotası kayıtlı değildir; panel ve yönetici kaydı `ADMIN_PATH değeriniz` altındadır (`<ADMIN_PATH değeriniz>/login`, `<ADMIN_PATH değeriniz>/register`).

Yönetici Basic auth (`ADMIN_BASIC_ENABLED`) üretimde **kapalıdır**; betik bu anahtarı yazmaz/açmaz (açıksa yalnız uyarır). `.env` içindeki yerel `ADMIN_PASSWORD` sunucuya **taşınmaz**: üretimde `gen-secrets.sh`'ın ürettiği 24 karakterli rastgele değer geçerlidir.

## İlk dağıtımdan sonra yapmanız gerekenler

1. **Üretilen sırları yedekleyin.** Betik `.env.prod`'u sunucuda üretir ve yerel kopyaları iki ayrı dosyaya yazar (gitignored, izin 600): `.deploy/generated-secrets.txt` (`DB_PASSWORD`, `JWT_SECRET`, `ADMIN_PASSWORD`, `CRYPTO_MASTER_KEYS` + `CRYPTO_ACTIVE_KEY_ID`, `DEVICE_HMAC_KEY`, `BACKUP_AGE_RECIPIENT`) ve `.deploy/backup-age-private.key` (yedek **age özel anahtarı**, sunucudan silinir). İki dosyayı şifre yöneticisine **ve** çevrimdışı kasaya, **farklı yerlere** taşıyın; her emanetin "fiilen okundu" testini yapın ve RUNBOOK bölüm 12'deki tatbikat günlüğüne işleyin; ardından yerel kopyaları güvenle silin. `CRYPTO_MASTER_KEYS` kaybı şifreli mesaj/video verisinin geri dönüşsüz kaybıdır; age özel anahtarı olmadan yedekler açılamaz. Ayrıntı: [KEY_MANAGEMENT.md](KEY_MANAGEMENT.md).
2. **Yönetici hesabını kaydedin.** `ADMIN_EMAILS` içindeki adres (`DEPLOY_ADMIN_EMAILS`, ör. `ysufakin23@gmail.com`) `bingol.edu.tr` olmak zorunda değildir; sunucu yalnız bu adreslere alan adı kısıtını atlatır:
   1. Tarayıcıda `https://bukampus.com.tr/<ADMIN_PATH değeriniz>/register` adresini açın (`ADMIN_PATH` ayarlı değilse `/admin/register`; giriş sayfasındaki "Yönetici hesabı oluşturun" bağlantısı da aynı yere gider).
   2. Ad soyad, `DEPLOY_ADMIN_EMAILS` adresi, en az 8 karakterli bir şifre girin, metinleri kabul edin.
   3. O adrese gelen 6 haneli kodu girin (10 dk geçerli; gelmezse "Kodu yeniden gönder"). Yalnız bilinçli log-only kuruluysa (`APP_MAIL_ALLOW_LOG_ONLY=true`) kod backend günlüğündedir: `docker compose -p bu ... logs backend`.
   4. Doğrulama sonrası otomatik giriş yapılır; rol ADMIN (profil FULL) olur ve panel açılır. Sonraki girişler `<ADMIN_PATH değeriniz>/login` üzerindendir. Bu şifre yalnızca sizin belirlediğiniz şifredir; `.env.prod`'daki `ADMIN_PASSWORD` yönetici hesabının şifresi **değildir** (Basic yöntemi üretimde kapalıdır).
3. Başka bir adresle kayıt olursanız (listede yoksa) sunucu okul dışı alan adını reddeder; listede olmayan bir `bingol.edu.tr` hesabı doğrulanır ama panelde "yetkiniz yok" görür. Yeni yönetici eklemek için `.env.prod` `ADMIN_EMAILS` değerini güncelleyip backend'i yeniden başlatın (ya da panelden mevcut bir yönetici rolü verir). **`ADMIN_EMAILS`'e en az 2 adres yazın (K-31):** tek FULL yöneticiyle iki kişi onayı gerektiren işlemler (FULL ata/düşür) kilitlenir ve panelden ikinci FULL yaratılamaz; `DEPLOY_ADMIN_EMAILS` tek adresse `deploy.sh`, `.env.prod`'da 2'den az adres varsa backend uyarır.
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

## Disk temizliği (CLN1)

Sunucu diski 48 GB; eski Docker imajları, build önbelleği ve eski sürüm dizinleri zamanla birikir. Bu yüzden iki katmanlı, **kalıcı veriye dokunmayan** temizlik vardır:

- **`scripts/ops/docker-cleanup.sh`** (sunucuda `/opt/bukampus/bin/docker-cleanup.sh`, kullanıcı `deploy`, `flock` ile tek örnek; `--dry-run` yalnız yazar): (a) dangling imajlar; (b) hiçbir konteynerce kullanılmayan, `:previous`/`:local`/`:latest` etiketi taşımayan ve 7 günden eski `bu-*` imajları; (c) `docker builder prune --reserved-space 2GB --filter until=72h` (Docker 29'da `--keep-storage` yerine; eski sürümde otomatik `--keep-storage`); (d) `releases/` altında `current` ve `.previous_release` (ile `.current_release`/`.next_release`) hariç en yeni 2 sürüm dizini kalır, gerisi silinir (yalnız `^[0-9a-f]{10}$` adları, sembolik bağlara dokunmaz, `readlink -f` ile yol geçişi denetimi, `current` belirlenemezse hiçbir şey silinmez); (e) 24 saatten eski durmuş konteynerlerden yalnızca adı `bu-` ile başlamayan ve `bu` compose projesine ait olmayanlar. Her adımın önce/sonra disk kullanımı loga yazılır; sonda `docker system df` + `df -h /` özeti, kullanım %85'i geçerse `logger -p user.warning -t bu-docker-cleanup`.
- **ASLA** `docker volume prune`, `docker system prune --volumes`, `docker volume rm`: `pgdata`, `uploads`, `backups`, `caddy_data` (TLS sertifikaları) kalıcı veridir. Betik bunları hiç çağırmaz.
- **Zamanlama:** `bu-docker-cleanup.timer` (günlük 04:30 Europe/Istanbul, `Persistent=true`, `RandomizedDelaySec=300`) -> `bu-docker-cleanup.service` (kullanıcı `deploy`, `Nice=10`, `IOSchedulingClass=idle`, `ProtectSystem=strict`, yazma yalnız `/opt/bukampus` ve `/run/lock`). Çakışma: 03:00 `DbMaintenanceJob`, 04:00 cihaz temizliği, saatlik :05 yedek; Pazar 04:30'daki geri yükleme doğrulaması ile aynı saate gelir ama temizlik IO "idle" sınıfındadır ve ayrı kaynaklara dokunur. Kayıtlar: `journalctl -u bu-docker-cleanup`, durum: `systemctl list-timers bu-docker-cleanup.timer`.
- **Kurulum:** `scripts/ops/install-cleanup.sh [--dry-run] [--ref <git-ref>] [--run|--run-dry]` (idempotent; değişmeyen dosyayı yeniden yazmaz; `sudo -n` gerekir; ssh aralık kuralı deploy.sh ile aynı damga dosyasını paylaşır). Birim dosyaları `deploy/systemd/`.
- **deploy.sh ile ilişki:** başarılı dağıtımdan sonra (geri alma devreye girmediyse) `6b/7` adımı kurulumu günceller ve temizliği bir kez çalıştırır; **hata dağıtımı başarısız saymaz**, yalnız uyarı verir. Atlamak için `--skip-cleanup`. Dağıtım zaten son 3 sürüm dizinini tutar ve `docker image prune -f` çalıştırır; temizlik betiği bunun üstüne zamanlanmış güvenlik ağıdır.
- **Geri alma güvencesi:** `:previous` imaj etiketleri ve `.previous_release` dizini hiçbir koşulda silinmez, dolayısıyla `deploy.sh --rollback` temizlikten sonra da çalışır.
- **StorageAlertJob ile ilişki:** uygulama içindeki `StorageAlertJob` (%80 uyarı / %90 kritik) doluluğu yöneticiye bildirir; bu temizlik ise dolmasını önlemeye çalışır (betiğin %85 `logger` uyarısı yalnızca sunucu günlüğüne düşer, yönetici bildirimi değildir).
- **Beklenti:** yeni kurulumda imajlar/önbellek 7 ve 3 günden gençtir; ilk günlerde neredeyse hiçbir şey silinmez, birikim 3-7. günden sonra temizlenir (ayarlar: `IMAGE_MIN_AGE_DAYS`, `KEEP_RELEASES`, `BUILDER_RESERVED`, `BUILDER_UNTIL`).

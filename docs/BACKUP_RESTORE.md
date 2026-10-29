# Yedekleme ve Geri Yükleme

Kapsam: PostgreSQL veritabanı + yüklenen dosyalar (`uploads` volume: avatarlar, kapaklar, sohbet/gönderi medyası). Kaynak kod: `scripts/backup/`. Servis: `docker-compose.prod.yml` içinde `backup`. Anahtarlar: [KEY_MANAGEMENT.md](KEY_MANAGEMENT.md). Olay müdahalesi: [RUNBOOK.md](RUNBOOK.md).

## 1. Hedefler

| Hedef | Değer | Nasıl sağlanır |
|---|---|---|
| **RPO** (kabul edilen en çok veri kaybı) | **1 saat** | Saatlik yedek (`BACKUP_CRON=5 * * * *`). Güncel politika özeti: [BACKUP.md](BACKUP.md). Daha sıkı RPO için WAL arşivi (pgBackRest/WAL-G) gerekir. |
| **RTO** (kabul edilen en uzun kesinti) | **2 saat** | Aşağıdaki geri yükleme adımları; veritabanı ~birkaç GB için `pg_restore` dakikalar sürer. Yılda 2 tatbikatta süre ölçülür. |
| Saklama | **En yeni 3 yedek** (3 saatlik pencere) | `BACKUP_KEEP_DAILY=3`; haftalık/aylık varsayılan kapalı (`BACKUP_KEEP_WEEKLY/MONTHLY=0`, açılırsa hardlink kopyası). **Uzak kopya (`BACKUP_REMOTE`) olmadan disk kaybı = tüm yedeklerin kaybı.** |
| Doğrulama | Haftalık otomatik geri yükleme denemesi | Pazar 04:30 `verify-restore.sh --latest` (aşağıda). |

KVKK: yedekler kişisel veri içerir. Saklama süresi (öneri <= 12 ay, aylık en eski) saklama politikasıyla uyumlu olmalıdır (`docs/legal/internal/01_saklama_ve_imha_politikasi.md`); **silinen hesaplar yedekten geri yüklenince yeniden anonimleştirilmelidir** (bölüm 5, adım 7).

## 2. Ne yedeklenir, nasıl korunur

Her yedek `daily/<YYYYMMDDTHHMMSS>/` altında dört dosyadır:

| Dosya | İçerik |
|---|---|
| `db.dump.age` | `pg_dump -Fc` çıktısı, **age** ile şifreli (akış: diske açık metin yazılmaz) |
| `uploads.tar.zst.age` | `uploads` volume'u (`tar` + `zstd`), age ile şifreli |
| `manifest.json` | Flyway sürümü, tablo satır sayıları, dosya sayısı, boyutlar (geri yükleme doğrulaması bunlarla karşılaştırır) |
| `SHA256SUMS` | Üç dosyanın SHA-256 özeti (kopyalama/bozulma tespiti) |

- **Şifreleme: [age](https://age-encryption.org).** Sunucuda yalnızca **genel anahtar** bulunur (`BACKUP_AGE_RECIPIENT=age1...`). Sunucu ele geçirilse bile yedek dosyaları (özellikle sunucu dışına kopyalananlar) çözülemez. **Özel anahtar sunucuda DEĞİLDİR**; çevrimdışı kasada + şifre yöneticisinde saklanır.
- İki alıcı kullanılır (isteğe bağlı ama önerilir): (1) çevrimdışı kasadaki kurtarma anahtarı `BACKUP_AGE_RECIPIENT`; (2) haftalık **otomatik** doğrulama için sunucuda duran ayrı bir doğrulama anahtarı `BACKUP_VERIFY_AGE_RECIPIENT` (özel anahtarı `deploy/backup-keys/verify.key`). İkincisi, yedekten yalnızca sunucudaki veriyi çözebilir; zaten canlı veritabanı da orada olduğundan ek bir risk yaratmaz, ama **sunucu dışına kopyalanan yedekler** kurtarma anahtarı olmadan çözülemez ve doğrulama anahtarı sunucudan çıkmaz.
- **Uzak kopya:** `BACKUP_REMOTE` (rclone hedefi, ör. `s3crypt:bu-yedek`) tanımlıysa her yedek yüklenir (`deploy/rclone/rclone.conf` salt okunur bağlanır; gizlidir, commit'lenmez). Aynı veri merkezinde tek kopya yedek sayılmaz: **mutlaka farklı sağlayıcı/bölgede bir uzak kopya** tutun; uzak tarafta nesne kilidi (object lock) / sürümleme ve yaşam döngüsü kuralı (ör. 400 gün) önerilir.
- Yedek **kendi başına** `CRYPTO_MASTER_KEYS` içermez. Mesajlar ve gönderi videoları ana anahtarla şifrelidir; **ana anahtar olmadan yedek geri yüklense bile bu veriler okunamaz** (bölüm 6, [KEY_MANAGEMENT.md](KEY_MANAGEMENT.md)).

### Kurulum (bir kez)

```bash
# Çevrimdışı bir makinede (sunucuda DEĞİL):
age-keygen -o kurtarma.age.key        # "Public key: age1..." satırını not edin -> BACKUP_AGE_RECIPIENT
age-keygen -o verify.age.key          # haftalık otomatik doğrulama anahtarı -> BACKUP_VERIFY_AGE_RECIPIENT
# kurtarma.age.key: şifre yöneticisi + çevrimdışı kasa (>= 2 yer, KEY_MANAGEMENT.md)
# verify.age.key  : sunucuya, deploy/backup-keys/verify.key olarak; sunucu dışına yedeği YOKTUR (kaybolursa yenisi üretilir)
#   İzin: konteynerdeki zamanlayıcı postgres (uid 70) olarak çalışır; 0600 + başka sahip ise okuyamaz. Ya
#   `sudo chown 70:70 deploy/backup-keys/verify.key && chmod 0400 deploy/backup-keys/verify.key`, ya da yedek konteyneri
#   başlarken kök olarak okunup postgres'e özel 0400 kopya (/run/age-key/age.key) yapılır (anahtar sonradan konduysa
#   `docker compose restart backup`). Okunamazsa doğrulama sessiz kalmaz: backup_verify_last_status 0 + webhook + BackupVerifyFailed.

# Sunucuda .env.prod:
#   BACKUP_AGE_RECIPIENT=age1...   BACKUP_VERIFY_AGE_RECIPIENT=age1...   BACKUP_REMOTE=...   BACKUP_WEBHOOK_URL=...
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build backup
docker compose -f docker-compose.prod.yml --env-file .env.prod exec -u postgres backup /opt/backup/backup.sh --dry-run
```

## 3. Zamanlama, metrik, uyarı

- `backup` servisi (supercronic): `BACKUP_CRON` (varsayılan **her saat :05**, `Europe/Istanbul`) ve `BACKUP_VERIFY_CRON` (varsayılan **pazar 04:30**).
- **Başarısızlıkta:** betik sıfır olmayan kodla çıkar, `backup_last_status 0` yazar, `BACKUP_WEBHOOK_URL`'e bildirim gönderir. Yarım yedek (`.partial-*`) silinir; önceki yedekler korunur.
- **Metrikler** (Prometheus textfile biçimi, `monitoring/textfile/backup.prom` ← `BACKUP_METRICS_DIR`; aynı dosya `http://backup:9199/backup.prom` ile de sunulur):

| Metrik | Anlam |
|---|---|
| `backup_last_success_timestamp_seconds` | Son **başarılı** yedek (unix sn). `monitoring/prometheus/alert.rules.yml` `BackupTooOld` bunu bekler (36 saat; saatlik yedekte ~3 saate çekin). |
| `backup_last_run_timestamp_seconds`, `backup_last_status` | Son deneme ve sonucu (1/0) |
| `backup_last_duration_seconds`, `backup_last_db_bytes`, `backup_last_uploads_bytes` | Süre ve (şifreli) boyutlar |
| `backup_verify_last_success_timestamp_seconds`, `backup_verify_last_status` | Son başarılı geri yükleme doğrulaması. **Öneri: `time() - backup_verify_last_success_timestamp_seconds > 9*86400` uyarısı.** |

- Yönetici API'si `GET /api/admin/ops/backup-status` aynı `backup.prom` dosyasını okur (backend'e salt okunur bağlıdır).
- Dosya `/var/backups/last_success` (unix sn) yedek konteynerinde de tutulur.

## 4. Elle komutlar

```bash
DC="docker compose -f docker-compose.prod.yml --env-file .env.prod"
$DC exec -u postgres backup /opt/backup/backup.sh --dry-run        # bağlantı, anahtar, disk, uzak hedef denemesi; hiçbir şey yazmaz
$DC exec -u postgres backup /opt/backup/backup.sh                  # hemen yedek al
$DC exec backup ls -l /var/backups/daily               # yedekleri listele
$DC exec -u postgres backup /opt/backup/verify-restore.sh --latest # geçici sunucuda geri yükleme denemesi (canlıya dokunmaz)
```

`scripts/backup/selftest.sh` (Docker gerekir, repo kökünden): geçici postgres + geçici volume'lar + yeni age anahtarıyla tüm hattı (dry-run, yedek, sha256, doğrulama, `restore.sh`, bozuk yedek reddi, canlı DB hedefi reddi) uçtan uca dener; çalışan yığına dokunmaz.

### `verify-restore.sh` ne kanıtlar?

"Geri yükleme denenmiş yedek" kanıtıdır. Yedeği **geçici bir PostgreSQL sunucusuna** (aynı imajda `initdb`, soket, canlı sunucuya bağlanmaz) yükler ve şunları denetler:
1. SHA-256 özetleri,
2. `pg_restore --exit-on-error` hatasız bitti mi,
3. Flyway sürümü manifest ile **birebir** aynı mı,
4. Her tablo mevcut mu ve satır sayısı manifest değerinin en az %95'i mi (yedek ile sayım arasında geçen sürede silinmeler için tolerans `--tolerance`),
5. Uploads arşivi çıkarılıyor mu ve dosya sayısı manifest ile uyumlu mu (>= %95).

Sonuç `backup_verify_*` metriğine yazılır; başarısızlık webhook ile bildirilir. Kimlik dosyası yoksa (çıkış kodu 3) yalnız SHA-256 denetlenir ve metrik **güncellenmez** (uyarı zamanla tetiklenir).

## 5. Geri yükleme (felaket kurtarma) - adım adım

Hedef süre: 2 saat. Gerekenler: (a) yedek dosyaları (sunucudan, uzak kopyadan ya da `rclone copy`), (b) **kurtarma age özel anahtarı** (çevrimdışı kasa), (c) **`CRYPTO_MASTER_KEYS`** (ve `.env.prod` sırları: şifre yöneticisi), (d) yeni/temiz sunucu: `scripts/deploy/bootstrap-server.sh`.

1. **Sunucuyu hazırlayın** (yeni sunucuysa): `bash scripts/deploy/bootstrap-server.sh`, repoyu klonlayın, `.env.prod`'u şifre yöneticisinden geri koyun (**aynı `CRYPTO_MASTER_KEYS`, `JWT_SECRET`, `DEVICE_HMAC_KEY`**: değişirse bölüm 6'daki sonuçlar doğar). DNS'i yeni sunucuya çevirin.
2. **Yedeği getirin:** uzak kopyadan `rclone copy s3crypt:bu-yedek/<damga> ./restore-in/` (ya da eski sunucudan `scp`). `SHA256SUMS` ile doğrulayın: `cd restore-in && sha256sum -c SHA256SUMS`.
3. **Yalnız altyapıyı başlatın:** `DC up -d postgres redis` (backend henüz **başlatılmaz**: boş şemaya Flyway yazmasın).
4. **Veritabanını yükleyin** (backup konteyneri imajı araçları taşır; özel anahtarı geçici olarak bağlayın, iş bitince silin):
   ```bash
   docker compose -f docker-compose.prod.yml --env-file .env.prod run --rm \
     -v "$PWD/restore-in:/restore:ro" -e BACKUP_AGE_IDENTITY_SRC=/run/restore-key/restore.key \
     -v "$PWD/kurtarma.age.key:/run/restore-key/restore.key:ro" \
     backup restore.sh /restore --target-db bingol_restore --uploads-to /tmp/up
   ```
   `restore.sh` yeni bir veritabanı (`bingol_restore`) oluşturur ve yükler; canlı veritabanı adı (`bingol`) bilinçli `--overwrite-live` olmadan **reddedilir**. Boş yeni sunucuda doğrudan canlı adına yüklemek için `--target-db bingol --overwrite-live` kullanın (backend kapalıyken). `restore.sh` her zaman ÖNCE kuru doğrulama yapar (sha256, anahtar okunabilir/geçerli, `age -d | pg_restore --list`, tam şifre çözme, uploads arşivi); başarısızsa hiçbir şey değişmez (`--check-only` yalnız bunu yapar). `--overwrite-live` mevcut canlı veritabanını **silmez**: yeni veritabanı geçici adla kurulur, canlı ad `bingol_prev_<damga>` olarak SAKLANIR ve yenisi yerine konur (sorun yoksa `dropdb bingol_prev_...`). Yedek dizini başka sahipli/0700 ise konteynerdeki postgres okuyamaz: `chmod -R a+rX <yedek-dizini>` (içerik age ile şifreli; `restore-live.sh` bunu kendisi yapar).
5. **Dosyaları yükleyin:** `--uploads-to` ile çıkarılan dizini `uploads` volume'una taşıyın (`docker run --rm -v <proje>_uploads:/d -v $PWD/up:/s alpine cp -a /s/. /d/`; sahibi `1001` olmalı: `chown -R 1001 /d`).
6. **Backend'i başlatın:** `DC up -d`. Açılışta `ProdSettingsValidator` ve `KeyProvider` anahtarları doğrular; Flyway yalnızca eksik migration'ları uygular.
7. **KVKK sonrası işlemler:** yedeğin alındığı tarihten sonra **silinen/anonimleştirilen hesapları yeniden anonimleştirin** (silme günlüğü/denetim kaydından: `docs/legal/internal/01_saklama_ve_imha_politikasi.md`), bildirim ve oturumlar zaten geçersizdir (Redis boş: kullanıcılar yeniden giriş yapar).
8. **Doğrulama:** `curl -f https://$DOMAIN/actuator/health` (iç ağdan), girişle bir mesajı/gönderi videosunu açın (şifre çözme = ana anahtar doğru), `GET /api/admin/ops/health`, bir yedek daha alın (`backup.sh`) ve `verify-restore.sh --latest` çalıştırın.
9. **Olay kaydı:** neden, süre (RTO ölçümü), kaybolan veri aralığı (RPO), alınan dersler `docs/RUNBOOK.md` olay şablonuna yazılır.

Yalnız tek tablo/veri kurtarma: `restore.sh ... --target-db bingol_restore` ile ayrı veritabanına yükleyip gereken satırları `psql`/`pg_dump -t` ile canlıya aktarın; canlı üzerine tam geri yükleme yapmayın.

## 6. Anahtar bağımlılığı (kritik)

| Yedekte olan | Okunması için gereken |
|---|---|
| Veritabanı + dosyalar (age şifreli) | **age özel anahtarı** (kurtarma) |
| Şifreli sohbet mesajları (`message`), konuşma DEK'leri (`conversation_key`), gönderi videoları (`post_media.wrapped_dek`, diskteki `BUP1` dosyalar), sohbet görselleri | **`CRYPTO_MASTER_KEYS`** (ilgili `id`'li anahtar) |

`CRYPTO_MASTER_KEYS` yedeğin **içinde değildir** ve olmamalıdır. Yedek ve anahtar birbirinden ayrı korunur; ikisi birden gerektiği için yalnız birinin sızması veriyi açmaz. Anahtar kaybı = bu verilerin kalıcı kaybı (bkz. KEY_MANAGEMENT.md "Kaybın sonuçları").

## 7. Tatbikat kontrol listesi (yılda 2 kez)

Tarih: ______  Yapan: ______  Hedef süre (RTO): 2 sa  Gerçekleşen: ______

- [ ] Kurtarma age özel anahtarı çevrimdışı kasadan **fiilen** alındı ve `age -d` ile bir yedek çözüldü (anahtar çalışıyor)
- [ ] `CRYPTO_MASTER_KEYS` ve `.env.prod` sırları şifre yöneticisinden alındı; ikinci konumla (kasa) **aynı** olduğu doğrulandı
- [ ] Uzak kopyadan (yerel yedek kullanılmadan) en son yedek indirildi, `sha256sum -c` geçti
- [ ] Temiz bir ortamda (staging ya da yeni VM) bölüm 5 adımları baştan sona uygulandı
- [ ] Uygulama açıldı; Flyway sürümü yedektekiyle aynı; giriş çalışıyor
- [ ] Bir **sohbet mesajı** ve bir **gönderi videosu** çözülüp görüntülendi (ana anahtar doğrulaması)
- [ ] Yüklenen dosyalar (avatar, sohbet görseli) açılıyor; dosya sayısı manifest ile uyumlu
- [ ] `verify-restore.sh` çıktısı (Flyway/tablo/dosya sayıları) kaydedildi; `backup_verify_last_success_timestamp_seconds` güncel
- [ ] Süre ölçüldü: indirme __ dk, yükleme __ dk, doğrulama __ dk, toplam __ dk (RTO <= 120 dk)
- [ ] Silinen hesapların yeniden anonimleştirme adımı denendi
- [ ] Webhook/uyarı zinciri denendi (bilerek bozuk yedek -> bildirim geldi mi)
- [ ] Bulgular ve düzeltmeler bu belgeye/RUNBOOK'a işlendi; verify.key ve kurtarma anahtarı sahipleri güncel

Her tatbikatın kaydı (tarih, süre, bulgu) `docs/RUNBOOK.md` sonundaki "Tatbikat günlüğü" tablosuna eklenir.

## 8. Sınırlar

- Mantıksal yedek (`pg_dump`) günlüktür; gün içindeki veri RPO kapsamı dışındadır. Yedek sırasında yazılan dosyalar bir sonraki yedeğe girer (`tar --warning=no-file-changed`).
- Uploads ve veritabanı aynı anda atomik değildir; yetim dosya/satır için süpürücüler (`MediaOrphanSweeper`, `PostMediaJanitor`) vardır.
- Redis yedeklenmez (geçici veri); kayıp sonucu: kullanıcılar yeniden giriş yapar.
- `backups` volume'u aynı sunucudadır; sunucu kaybı için **uzak kopya şarttır**.

## 9. Saatlik politika, durum JSON'u ve tek komutla canlı geri yükleme

Saatlik/son-3 politikası, `last-success.json` / `last-failure.json` biçimi, şifreleme ve `.env` yedeği kararları: [BACKUP.md](BACKUP.md). Sunucuda tek komutla geri yükleme (uygulamayı durdurur, DB + dosyaları geri koyar, Redis'i temizler, başlatır; onay ister, **sunucuda denenmemiş betik: ilk kullanımı staging'de deneyin**):

```bash
bash scripts/backup/restore-live.sh <yedek-dizini> <kurtarma.age.key>
```

`restore-live.sh` yığını durdurmadan ÖNCE yedeği kuru doğrular (yanlış/okunamayan anahtar veya bozuk dump: hiçbir şey değişmez), anahtarı konteynere `/run/restore-key/restore.key` olarak bağlar (servisin `:ro /run/backup` bağlamasının altına değil) ve postgres için 0400 kopyaya çevirir, canlı veritabanını silmez (`bingol_prev_<damga>`), uploads'ı önce geçici dizine çıkarıp sonra yerine koyar, adım hatasında yığını yeniden başlatmaya çalışır. Geçici yığında uçtan uca denenmiştir (yanlış anahtar: yığın dokunulmadan kalır; doğru anahtar: DB + dosyalar geri gelir).

## 10. Geri yükleme provası (VPS taklidi, yerelde): `scripts/restore-drill.sh`

Amaç: yedeğin **gerçekten** geri yüklenebildiğini, yeni boş bir yığında yalnız yedek + age özel anahtarıyla uygulamanın açıldığını ve verinin birebir döndüğünü, gerçek sunucuya dokunmadan kanıtlamak. Bu bölüm REL1 provasının (2026-10-29) sonucunu ve yeniden çalıştırma yolunu verir. Betik **yerel Docker** içindir; gerçek VPS'te aynı komutlar bölüm 5 ve 9'daki gibidir.

### 10.1 Ne yapar
`bash scripts/restore-drill.sh [all|source|backup|destroy|restore|verify|build|clean]` (varsayılan `all`; her aşama ayrı da çalışır, tekrar çalıştırılabilir):

| Aşama | İşlem |
|---|---|
| `source` | Üretim compose'u (`docker-compose.prod.yml`) proje adı `rel1`, `127.0.0.1:18090`, Caddy/web olmadan; `dev,seed` profiliyle **tohum veri** (12 kullanıcı, 5 kulüp, 15 gönderi, şifreli sohbetler, anketler) + gerçek yükleme hattından bir **avatar**; sırlar ve age anahtar çifti `$DRILL_DIR` altında üretilir (repoya yazılmaz). Backend durdurulup tutarlı **parmak izi** alınır |
| `backup` | Gerçek `backup.sh` (pg_dump + uploads, age şifreli), yedek `daily/<damga>` hosta kopyalanır (uzak kopya taklidi), `sha256sum -c` |
| `destroy` | `docker compose down -v`: veritabanı, uploads, redis ve **yedek volume'u dahil her şey** silinir |
| `restore` | **Yeni boş** yığın (yalnız postgres + redis), sonra `scripts/backup/restore-live.sh` (kuru doğrulama, DB, uploads, Redis temizliği, başlatma); uygulama bu kez **`prod` profiliyle** (`ProdSettingsValidator`, Flyway `out-of-order=false`) açılır |
| `verify` | Sağlık UP; Flyway son sürümü ve sayısı; tablo satır sayıları; uploads dosya sayısı/bayt/SHA-256 özeti; API: tohum kullanıcıyla giriş, **sohbet metinlerinin çözülmesi** (`CRYPTO_MASTER_KEYS` doğru), gönderi görselleri ve avatar baytlarının SHA-256'sı; kaynakla birebir karşılaştırma. Fark varsa çıkış kodu 1 |
| `clean` | Yığını ve `$DRILL_DIR`'i siler |

Ortam: `PROJECT=rel1`, `PORT=18090`, `DRILL_DIR=/c/bu_restore_drill` (ASCII yol; Windows'ta Türkçe karakterli yoldan bind mount'tan kaçınmak için), `BACKEND_IMAGE=bu-rel1-backend:drill` (yoksa `git archive HEAD` ile **commitli kaynaktan** derlenir; `OVERLAY="yol1 yol2"` ile commitsiz düzeltmeler üstüne kopyalanır), `SEED=0` (boş veritabanı). Gereken: Docker + Compose >= 2.24, node, curl, openssl.

### 10.2 Sonuç (REL1 koşusu)
Tüm denetimler **PASS**: sağlık UP; Flyway son sürüm (820) ve 81 başarılı kayıt aynı; 12 kullanıcı, 15 gönderi, 10 gönderi medyası, 4 sohbet/8 mesaj/4 sohbet anahtarı, 4 anket, 25 bildirim satırları aynı; 43 dosya / 515 042 bayt / aynı SHA-256 özeti; yedek öncesi ve sonrası **aynı** çözülmüş sohbet metni özeti ve **aynı** gönderi/avatar bayt özetleri.

| Ölçülen süre (Docker Desktop, 8 GB RAM, Windows; küçük VPS'e yaklaşık) | Süre |
|---|---|
| Kaynak yığını kurma + tohum (imaj hazırken; yük altında 55-165 sn) | ~55-165 sn |
| Yedek alma (43 dosya, ~0,5 MB uploads + küçük DB; `backup.sh`) | 3-9 sn |
| Yığını silme (`down -v`) | 2-13 sn |
| **Geri yükleme** (`restore-live.sh`: kuru doğrulama + DB + dosyalar + başlatma; 4 koşu) | **11-38 sn (son koşu 15 sn)** |
| Uygulamanın açılıp `UP` olması (soğuk JVM, Flyway doğrulaması) | 54-60 sn |
| **Boş yığından açık uygulamaya toplam** (postgres/redis başlatma dahil; son tam koşu 78 sn, tüm betik 6 dk 14 sn) | **78-85 sn** |

**Bu süreler küçük veriyle ölçüldü.** Gerçek sürede ölçeklenen kısım indirme (uzak kopya) ve `pg_restore`/uploads çıkarma süresidir (veri boyutuyla doğru orantılı); kabaca saniyeler yerine "veri GB'ı başına dakikalar" bekleyin. RTO hedefi (2 sa) için ayrıca: sunucu kurulumu (`bootstrap-server.sh`, ~10 dk), repo klonu, `.env.prod`'u şifre yöneticisinden geri koyma, DNS yayılması (TTL), indirme. İlk gerçek tatbikatta (bölüm 7) bu kalemleri ölçüp tabloya ekleyin.

### 10.3 Prova sırasında bulunan ve düzeltilen sorunlar
Prova, `docker-compose.prod.yml` ile gerçek (kısıtlı, salt okunur, `cap_drop: ALL`) kapsayıcılarda ilk kez uçtan uca koşturuldu ve **üç gerçek hata** buldu (bunlar olmadan VPS'te yedek hattı ve uygulama açılmazdı):

1. **Redis açılmıyordu.** `redis:7-alpine` giriş betiği `setpriv` ile kullanıcı düşürür; `cap_drop: ALL` + `SETUID/SETGID` yok => `setpriv: setresuid failed: Operation not permitted` sonsuz döngüsü (konteyner "unhealthy"). Düzeltme: redis servisine `cap_add: CHOWN, SETUID, SETGID`.
2. **Yedek servisi (`backup`) sürekli yeniden başlıyordu.** `entrypoint.sh` kök olarak `chown -R postgres /var/backups` yapıp ardından `chmod 755` çalıştırıyordu; dizin artık postgres'e ait olduğundan kök için `chmod` **CAP_FOWNER** ister (compose'ta yok) => `Operation not permitted`, `set -e` ile çıkış, döngü. Düzeltme: yedek servisine `cap_add: FOWNER`; ayrıca `chmod` hatası artık ölümcül değil (uyarı basar; Docker Desktop/Windows bind mount'unda chmod hiç desteklenmez). `scripts/backup/selftest.sh` bu hatayı yakalayamıyordu çünkü kısıtlı yetkilerle (`cap_drop: ALL`) koşmuyor.
3. **Backend `prod` profilinde HİÇ açılmıyordu** (`Parameter 0 of method uniqueSchemaNames in OpenApiConfig required a bean of type ObjectMapperProvider`). Prod'da `springdoc.api-docs.enabled=false` iken springdoc `ObjectMapperProvider` bean'ini üretmez, ama `OpenApiConfig.uniqueSchemaNames` kayıtsız şartsız ona bağlıydı. Düzeltme: bean `@ConditionalOnProperty(springdoc.api-docs.enabled)` ile koşullandı. Dev/test (api-docs açık) davranışı değişmez.

Ayrıca belgelenen davranış: prod profili `MAIL_ENABLED=false` ile **başlamayı reddeder** (`app.mail.allow-log-only=true` bilinçli verilmedikçe); prova yalnız bu bindirmede `APP_MAIL_ALLOW_LOG_ONLY=true` kullanır, gerçek `.env.prod`'da kullanılmaz.

### 10.4 Anahtar saklama uyarısı (tekrar)
Prova kendi geçici age anahtarını `$DRILL_DIR/kurtarma.age.key` altında üretir ve `clean` ile siler. **Gerçek kurtarma özel anahtarı hiçbir koşulda sunucuda, repoda, yedek dizininde ya da yedekle aynı kasada durmaz**: çevrimdışı kasa + parola yöneticisi (>= 2 yer). `CRYPTO_MASTER_KEYS` yedeğin içinde değildir: ikisinden biri kayıpsa geri yükleme ya yapılamaz (age anahtarı) ya da mesajlar/gönderi videoları okunamaz (ana anahtar). Prova bunu doğrular: `verify` aşaması sohbet metnini ancak doğru ana anahtarla çözer.

### 10.5 Kapsam dışı / doğrulanmadı
- Gerçek VPS, gerçek alan adı, Caddy/TLS, uzak kopya (`BACKUP_REMOTE`/rclone), webhook uyarısı ve haftalık `verify-restore.sh` (doğrulama anahtarı gerektirir) bu provada **denenmedi**.
- Tohum veri küçüktür; büyük veride süre ve disk/RAM davranışı ölçülmedi.
- Redis oturumları yedeklenmez: geri yüklemeden sonra herkes yeniden giriş yapar (provada Redis temizlenir, tasarım gereği).

### 10.6 Gerçek VPS'te aynı akış (komut özeti)

Prova betiğinin `restore` aşamasının gerçek karşılığı (yeni/boş sunucu, `.env.prod` şifre yöneticisinden geri konmuş, repo klonlu; ayrıntı bölüm 5 ve 9):

```bash
DC="docker compose -p bu -f docker-compose.prod.yml --env-file .env.prod"
mkdir restore-in && rclone copy s3crypt:bu-yedek/<damga> ./restore-in/ && (cd restore-in && sha256sum -c SHA256SUMS)   # uzak kopyadan
$DC up -d postgres redis                                    # backend'i BAŞLATMAYIN
# kurtarma.age.key çevrimdışı kasadan geçici olarak getirilir (sunucuda kalıcı DEĞİL)
bash scripts/backup/restore-live.sh ./restore-in ./kurtarma.age.key      # kuru doğrulama -> DB -> uploads -> Redis -> başlat
shred -u ./kurtarma.age.key 2>/dev/null || rm -f ./kurtarma.age.key      # iş bitince özel anahtarı sunucudan sil
curl -fsS https://<alan>/api/status; BASE=https://<alan> bash scripts/warmup.sh
```

Beklenen süre: küçük veride betik kısmı **15-40 sn** + uygulama açılışı **~1 dk** (provada ölçüldü); gerçek veride indirme ve `pg_restore` veri boyutuyla büyür. Toplam RTO hedefi 2 saat içinde kalmak için yılda 2 tatbikatta (bölüm 7) gerçek süreyi bu belgeye yazın.

## 11. Yedeklerin sunucu DIŞINA kopyalanması (uzak kopya): adım adım

**Durum tespiti (REL1b incelemesi):** `docker-compose.prod.yml` `backup` servisi rclone içerir (imaj `rclone` kurar, `deploy/rclone/` salt okunur `/config/rclone` olarak bağlanır, `RCLONE_CONFIG=/config/rclone/rclone.conf`) ve `scripts/backup/backup.sh` `BACKUP_REMOTE` doluysa her yedeği `rclone copy ... --checksum` ile `${BACKUP_REMOTE}/<damga>` altına yükler. **Ama `BACKUP_REMOTE` varsayılan olarak BOŞTUR** (`.env.prod.example`: `BACKUP_REMOTE=`); boşsa yedekler yalnız VPS'in `backups` volume'unda kalır, yani sunucu diski ya da hesabı giderse yedekler de gider. `deploy/compose.bukampus.yml` yalnız Caddy www yönlendirmesidir, yedek ayarı içermez. Yani **mekanizma var, açık değil**: aşağıdaki adımlar onu açar. Bu bölümdeki adımlar rclone sözdizimi düzeyinde (yerel `alias` uzağıyla `lsd` + `copy`) denendi; **gerçek bir sağlayıcı hesabına karşı DENENMEDİ** (hesap yok); ilk gerçek yüklemeyi `--dry-run` ve elle yedekle mutlaka doğrulayın.

Neden güvenli: yüklenen her şey zaten **age ile şifrelidir** (`db.dump.age`, `uploads.tar.zst.age`); sağlayıcı yalnız şifreli bayt görür. Ek rclone `crypt` katmanı gerekmez (dosya adları yalnız zaman damgasıdır).

### 11.1 Sağlayıcı seçimi (ucuz/ücretsiz, S3 uyumlu)

| Seçenek | Not (fiyat/kota değişir, kayıt sırasında doğrulayın) |
|---|---|
| Cloudflare R2 | S3 uyumlu, çıkış (egress) ücreti yok; ücretsiz katman birkaç GB'a kadar yeterli olabilir |
| Backblaze B2 | S3 uyumlu veya yerel B2 API; ilk 10 GB ücretsiz, sonrası GB başına çok düşük; uygulama anahtarı tek kovaya kısıtlanabilir |
| Hetzner Storage Box / başka bir VPS | `sftp` ile; ayrı sağlayıcı/veri merkezi olduğu sürece uygundur |

Kural: **farklı sağlayıcıda/bölgede** olsun (VPS ile aynı firmada ikinci disk yetmez). Boyut hesabı: saatlik yedek x 24 x gün; `BACKUP_KEEP_DAILY=3` yalnız YEREL saklamayı sınırlar, **uzak tarafta silme yoktur** (`rclone copy`, `sync` değil), bu yüzden uzak kovada yaşam döngüsü kuralı (11.4) şarttır.

### 11.2 Kova ve kısıtlı anahtar oluşturma (R2 / B2 örneği)

1. Sağlayıcıda **özel (public olmayan) bir kova** açın, ör. `bu-yedek`. Sürümleme/nesne kilidi varsa açın (fidye yazılımı ve yanlışlıkla silmeye karşı).
2. **Yalnız o kovaya** erişen bir API anahtarı üretin (R2: "Object Read & Write" belirteci, kova kısıtlı; B2: "Application Key", tek kova, `listFiles/readFiles/writeFiles`). Hesabın ana anahtarını SUNUCUYA KOYMAYIN. Mümkünse silme yetkisi olmayan bir anahtar tercih edin (sunucu ele geçirilirse saldırgan uzak kopyayı silemesin); silme yetkisi gerekirse yaşam döngüsü kuralı sağlayıcı tarafında çalışır, anahtara gerek duymaz.
3. Anahtar kimliği, gizli anahtar ve (R2 için) uç nokta adresini (`https://<hesapno>.r2.cloudflarestorage.com`) not edin. Bunlar SIRDIR: yalnız sunucudaki `deploy/rclone/rclone.conf` (gitignored) ve şifre yöneticinizde durur.

### 11.3 Sunucuda `deploy/rclone/rclone.conf`

Önemli: preflight `rclone lsd <uzak>:` çalıştırır. Kovaya kısıtlı anahtarla **kova listeleme** yetkisi olmayabileceğinden uzağı bir `alias` ile kovanın İÇİNE bağlayın; böylece `lsd` kova içeriğini listeler ve yetki sorunu çıkmaz.

```ini
# deploy/rclone/rclone.conf   (chmod 0644 veya chown 70:70 + 0400: konteynerdeki postgres kullanıcısı okuyabilmeli)
[r2]
type = s3
provider = Cloudflare
access_key_id = <ANAHTAR_KIMLIGI>
secret_access_key = <GIZLI_ANAHTAR>
endpoint = https://<HESAP_NO>.r2.cloudflarestorage.com
acl = private
no_check_bucket = true

[bukup]
type = alias
remote = r2:bu-yedek
```

Backblaze B2 için `[r2]` yerine:

```ini
[b2]
type = b2
account = <APPLICATION_KEY_ID>
key = <APPLICATION_KEY>
hard_delete = false
[bukup]
type = alias
remote = b2:bu-yedek
```

Hetzner Storage Box (sftp): `type = sftp`, `host = uXXXXX.your-storagebox.de`, `user = uXXXXX`, `port = 23`, `pass = <rclone obscure ile gizlenmiş parola>` (veya `key_file`); alias `remote = box:bu-yedek`.

Yapılandırma dosyasını da şifrelemek isterseniz `rclone config` ile parola koyun ve parolayı `.env.prod` içinde `RCLONE_CONFIG_PASS` olarak verin (compose bunu servise geçirir); aksi hâlde dosya izni 600/ilgili kullanıcıyla sınırlı kalmalıdır.

### 11.4 `.env.prod` ve ilk deneme

```bash
# .env.prod
BACKUP_REMOTE=bukup:yedek          # alias:alt-dizin; backup.sh "bukup:yedek/<damga>" altına yükler
```

```bash
DC="docker compose -p bu -f docker-compose.prod.yml --env-file .env.prod"
$DC up -d backup                                              # ortam değişkeni değişti: yeniden oluşturur
$DC exec -u postgres backup rclone lsd bukup:                 # uzağa erişim (hata verirse conf/yetki)
$DC exec -u postgres backup /opt/backup/backup.sh --dry-run   # bağlantı, anahtar, disk, UZAK HEDEF denemesi; hiçbir şey yazmaz
$DC exec -u postgres backup /opt/backup/backup.sh             # gerçek yedek + yükleme
$DC exec -u postgres backup rclone lsf bukup:yedek/ --max-depth 1   # damga dizini görünmeli
```

Yükleme hatası yedeği **başarısız** sayar (`backup_last_status`, webhook, `last-failure.json`); yerel kopya yine de alınmış ve rotasyon uygulanmıştır, yani sağlayıcı kesintisi yereli bozmaz ama uyarı üretir.

Sağlayıcı tarafında **yaşam döngüsü kuralı** koyun (saatlik yedek ~24 dizin/gün birikir): ör. 7 günden eski saatlik yedekleri sil ya da son 3 günü tut + günde bir yedeği 30-90 gün sakla; sağlayıcı panelinde "lifecycle / delete after N days". Kaynak: sağlayıcı belgesi (alanlar zamanla değişir).

### 11.5 Uzaktan geri yükleme denemesi (zorunlu, bölüm 7 ile birlikte)

Uzak kopya, geri yüklenebildiği gösterilmedikçe yok sayılır: başka bir bilgisayarda/geçici dizinde `rclone copy bukup:yedek/<damga> ./restore-in/ && (cd restore-in && sha256sum -c SHA256SUMS)`, sonra bölüm 10.6 akışı. Sunucunun rclone.conf'u kaybolursa uzak kopyaya erişmek için sağlayıcı anahtarlarını da şifre yöneticisinde tutun.

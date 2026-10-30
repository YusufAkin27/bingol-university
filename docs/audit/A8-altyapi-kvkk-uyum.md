# A8 - Altyapı, Dağıtım ve KVKK/Uyum Denetimi

Tarih: 2026-10-31 · Denetçi: A8 (yalnız okuma; kod/yapılandırma değiştirilmedi) · Dal: `feature/mobil-uygulama` (son commit 2026-10-30)

**Kapsam kuralı:** Üretim sunucusuna (77.83.37.160 / bukampus.com.tr) hiçbir erişim yapılmadı (ssh, curl, port/TLS/DNS taraması yok). Üretim durumu yalnız repodaki betik, belge ve yapılandırmadan çıkarıldı. A7 yalıtılmış test yığını hazır değildi (`C:\bu_qa\QA-STACK.txt` yok) → **dinamik test yapılmadı**. Bulgularda sır değeri yazılmaz; yalnız dosya yolu ve değişken adı verilir.

## 1. Özet

| Şiddet | Adet |
|---|---|
| KRİTİK | 1 |
| YÜKSEK | 7 |
| ORTA | 16 |
| DÜŞÜK | 9 |
| **Toplam** | **33** |

**En kritik 5:** A8-01 (tek VPS, yedekler aynı sunucuda, 3 saatlik pencere, sunucu dışı kopya yok) · A8-02 (CRYPTO_MASTER_KEYS / age anahtarı emanet düzeni doğrulanmamış) · A8-03 (harici izleme/uyarı dağıtılmamış) · A8-04 (aydınlatma metni yeni işlemleri kapsamıyor, metinler taslak, VERBİS açık) · A8-05/06 (Play Veri Güvenliği çökme beyanı gerçekle çelişiyor; READ_MEDIA_* politika riski).

**Olumlu bulgular (korunmalı):** GitHub Actions üçüncü taraf eylemleri tam SHA'ya sabitli; backend imajı root olmayan kullanıcıyla çalışır; prod compose'ta `read_only`, `cap_drop: ALL`, `no-new-privileges`, bellek/CPU sınırı, log dönüşümü var; postgres/redis `internal` ağda ve host'a port yayınlamıyor (`ports: !reset []` + `scripts/ci/compose-ports-check.sh` CI kapısı); Caddy HSTS/nosniff/DENY/Referrer-Policy/Permissions-Policy, `/actuator` ve `/swagger` için 404, gövde sınırı (128 KB / 2 MB / 55 MB), `read_header 10s`; yedekler age ile şifreli, SHA-256'lı, supercronic SHA doğrulamalı, yarım yedek rotasyonu tetiklemiyor; `REL1` yerel geri yükleme provası PASS; `AccountDataPurger` kapsamlı; cihaz kimliği HMAC; repo geçmişinde özel anahtar/keystore/`.env`/`AKIA`/AGE-SECRET-KEY bulunmadı; `secret-files-check.sh` + gitleaks + CodeQL + dependency-review + Dependabot var; deploy.sh'ta sır maskeleme, `.env.prod` asla ezilmez, otomatik geri alma.

---

## 2. Bulgular

Sahip kısaltmaları: **kod**, **altyapı**, **hukuk**, **ürün** (karar).

### KRİTİK

**A8-01 · KRİTİK · Tek VPS + yedekler aynı sunucuda + sunucu dışı kopya yok (SPOF) · sahip: altyapı/ürün**
- Yer: `docker-compose.prod.yml:300-354` (`backup`: `BACKUP_REMOTE:-` boş, `BACKUP_KEEP_DAILY:-3`, `BACKUP_KEEP_WEEKLY/MONTHLY:-0`), `.env.prod.example` (`BACKUP_REMOTE=`, `BACKUP_WEBHOOK_URL=`), `docs/BACKUP_RESTORE.md` bölüm 1 ve 8 ("`backups` volume'u aynı sunucudadır; sunucu kaybı için uzak kopya şarttır").
- Risk/etki: Disk arızası, sağlayıcı sorunu, yanlış `docker volume rm`, fidye yazılımı veya yönetici hatası pgdata + uploads + backups'ın **hepsini birlikte** yok eder. Saklama "en yeni 3 saatlik yedek": bozulma/yanlış silme 3 saatten geç fark edilirse geri dönülecek temiz yedek yoktur (haftalık/aylık kapalı). `deploy.sh` güvenli ilk kurulumda `BACKUP_REMOTE` boş bırakıyor, yani "uzak kopya şarttır" kuralı yalnız belgede.
- Kanıt: yukarıdaki satırlar; `deploy.sh` `.env.prod` üretiminde `BACKUP_REMOTE`/`BACKUP_WEBHOOK_URL` set etmiyor; `ProdSettingsValidator` bunları zorunlu kılmıyor (CLAUDE.md "bilinen eksik").
- Öneri: (1) farklı sağlayıcı/bölgede nesne depolama (rclone crypt, yalnız-yazma anahtarı, object lock/sürümleme) + `BACKUP_REMOTE` doldurma; (2) saatlik yanında günlük 7 / haftalık 4 / aylık 3 kopya (`BACKUP_KEEP_*`) - şifreli olduğundan disk maliyeti düşük; (3) `BACKUP_WEBHOOK_URL` zorunlu; (4) `ProdSettingsValidator`'a uyarı: prod'da `BACKUP_REMOTE` boşsa açılışta WARN + yönetici paneli sistem durumunda KIRMIZI; (5) VPS sağlayıcının anlık görüntü (snapshot) hizmeti ek katman.

### YÜKSEK

**A8-02 · YÜKSEK · Anahtar emanet düzeni (CRYPTO_MASTER_KEYS, age kurtarma anahtarı) doğrulanmamış, tek kişi/tek makineye bağlı · sahip: altyapı/ürün**
- Yer: `scripts/deploy.sh` (`.deploy/generated-secrets.txt` yazımı, ~satır 285-296), `docs/KEY_MANAGEMENT.md` bölüm 4, `docs/RUNBOOK.md` bölüm 12 ("Sır/anahtar değişiklik günlüğü" ve "Tatbikat günlüğü" **boş**).
- Risk/etki: `CRYPTO_MASTER_KEYS` kaybı = tüm sohbet mesajları, sohbet görselleri ve gönderi videolarının kalıcı kaybı; age kurtarma anahtarı kaybı = tüm yedeklerin çözülememesi. `deploy.sh` bu iki sırrı **aynı yerel dosyada** (`.deploy/generated-secrets.txt`: DB_PASSWORD, JWT_SECRET, ADMIN_PASSWORD, CRYPTO_MASTER_KEYS, DEVICE_HMAC_KEY ve age ÖZEL anahtarı) topluyor; belge "yedek ile anahtar aynı kasada durmaz" diyor, betik bunun tersini üretiyor. Shamir bölme, çevrimdışı kasa ve "kasadaki kopya fiilen okundu" doğrulaması için hiçbir kayıt yok (LAUNCH_CHECKLIST maddeleri işaretsiz). Yerel `.deploy/` şu an boş (dosya taşınmış/silinmiş olabilir) ama nereye taşındığı repoda kanıtlı değil.
- Kanıt: `.deploy/` dizini boş; RUNBOOK günlük tabloları boş; `docs/LAUNCH_CHECKLIST.md` 66-67, 72, 74-75 işaretsiz.
- Öneri: (1) CRYPTO_MASTER_KEYS'i **bugün** iki bağımsız yere (şifre yöneticisi + çevrimdışı) yedekleyip "fiilen okundu" testini yapın ve RUNBOOK tatbikat günlüğüne yazın; (2) age özel anahtarını CRYPTO anahtarından **ayrı** kasaya koyun; (3) `deploy.sh`'ı iki ayrı dosya üretecek şekilde değiştirin (kod); (4) ikinci bir yönetici/sahip ekleyin (A8-22).

**A8-03 · YÜKSEK · Harici izleme ve uyarı zinciri dağıtılmamış · sahip: altyapı**
- Yer: `scripts/deploy.sh` yalnız `docker-compose.prod.yml` + `deploy/compose.bukampus.yml` kullanır; `monitoring/docker-compose.monitoring.yml` hiçbir dağıtım betiğinde yok; `docs/DEPLOY.md:244-248` ve `docs/LAUNCH_CHECKLIST.md:74` Uptime Kuma'yı yalnız **öneri** olarak yazar (işaretsiz); `BACKUP_WEBHOOK_URL` boş; `SystemAlertService` uyarıyı yalnız **uygulama içi** yönetici bildirimi olarak gönderir (e-posta yok, `docs/changes/ops.md`).
- Risk/etki: Sunucu/backend çökerse, disk dolarsa, yedek başarısız olursa, TLS sertifikası yenilenmezse **kimseye haber gitmez** (uygulama içi bildirim sunucu çöktüğünde ulaşmaz). Kesinti kullanıcı şikâyetiyle fark edilir.
- Öneri: Ücretsiz bir dış izleyici (UptimeRobot/Uptime Kuma başka makinede/BetterStack) ile `https://bukampus.com.tr/api/status` + TLS süresi + `BACKUP_WEBHOOK_URL` (Telegram/ntfy/e-posta) bugün açılsın; backup `last-success` bayatlığı için Healthchecks.io tipi "dead-man" ping (saatlik yedek bitince ping).

**A8-04 · YÜKSEK · Aydınlatma/gizlilik metinleri yeni işlemleri kapsamıyor; metinler taslak; VERBİS/yurt dışı aktarım açık · sahip: hukuk/ürün**
- Yer: yayındaki metinler `backend/src/main/resources/db/migration/V820__legal_terms_v4.sql` (docs/legal/*_tr.md ile aynı içerik); `docs/LAUNCH_CHECKLIST.md:11-15`; `docs/LEGAL_NOTES.md`.
- Kanıt (V820 ve docs/legal'de arama sonuçları 0): **galeri/otomatik galeriye kaydetme** (`mobile/lib/features/chat/photo_autosave.dart` - gelen/giden sohbet fotoğraflarını "BU Kampus" albümüne yazar; cihaz yedeği/bulut fotoğraf senkronu aydınlatma dışında şifresiz kopya üretir), **yerel mesaj önbelleği** (`mobile/lib/core/cache/message_cache.dart`: sohbet başına 20 mesaj, **düz JSON**, uygulama sandbox'ında), **çökme/hata raporları** (V860 `crash_event`: maskelenmiş yığın izi, işletim sistemi sürümü, cihaz modeli, ekran adı; 30 gün), **kamera/mikrofon** kullanımı ve **görüntü kırpma** (kırpma cihazda; yalnız kısa not yeterli), **isteğe bağlı Sentry** (`SENTRY_DSN`, A8-20), `app_user.email_sha256` (kayıtlı kullanıcının kendi e-posta SHA-256 özeti kalıcı saklanıyor, A8-15). Rehber eşleştirme ve cihaz kaydı metinde var.
- Risk/etki: KVKK m.10 aydınlatma yükümlülüğü ve Play/Apple beyanlarıyla tutarsızlık. Avukat incelemesi, VERBİS kaydı (eşik/istisna değerlendirmesi), Firebase/Brevo yurt dışı aktarım kararı ve 18 yaş maddesi LAUNCH_CHECKLIST'te hâlâ açık; CLAUDE.md sözleşmeleri "taslak" diyor.
- Öneri: Yeni sözleşme sürümü (Flyway yeni V-numarası, `scripts/build-legal-migration-v820.js` benzeri) ile "Cihazda saklananlar" (mesaj önbelleği, galeriye kaydetme, bildirim token'ı), "Hata raporları" ve "Kamera/mikrofon/rehber/galeri izinleri" bölümleri; eksik işlemler listesi §4'te. Avukat onayı olmadan yayınlamayın.

**A8-05 · YÜKSEK · Play "Veri güvenliği" taslağı çökme günlüğü beyanıyla gerçek uygulama çelişiyor · sahip: ürün/hukuk**
- Yer: `docs/store/data_safety.md:34` ("Anonim `app_error` olayı ... mesaj/yığın/kişisel veri yok") ↔ `backend/.../V860__crash_reports.sql` (`crash_event.stack TEXT NOT NULL`, `device_model`, `os_version`, `screen`), `mobile/lib/core/crash/crash_reporter.dart` (maskelenmiş yığın izi gönderir).
- Risk/etki: Yanlış beyan Play politika ihlali (yayın askıya alma). Ayrıca "Cihaz veya diğer kimlikler" satırı `X-Device-Id` (uygulamaya özel kimlik, HMAC'li saklanır) ve IP'yi doğru kapsıyor; ama çökme raporlarındaki cihaz modeli/OS sürümü beyan edilmeli.
- Öneri: §3'teki taslak tabloyu kullanın; çökme günlüklerini "toplanıyor, paylaşılmıyor (kendi sunucumuz), zorunlu değil (ayarlardan kapatılabilir)" olarak güncelleyin (kod `CrashReporter` "Ayarlardan kapatılabilir" diyor; mevcut belge "kapatılamaz" yazıyor - birini düzeltin).

**A8-06 · YÜKSEK · `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` Play politikası ve gerekçe riski · sahip: ürün/kod**
- Yer: `mobile/android/app/src/main/AndroidManifest.xml:16-18`; `docs/store/data_safety.md:50` ("Doğrulanmadı ... Plan B: Photo Picker").
- Risk/etki: Play (2025+ Foto/Video İzinleri politikası) yalnız çekirdek işlevi geniş galeri erişimi gerektiren uygulamalara bu izni verir; sohbet uygulaması için sistem fotoğraf seçici beklenir → beyan reddi/yayın engeli. Ayrıca `photo_manager` + `gal` (otomatik kaydetme, `WRITE_EXTERNAL_STORAGE` maxSdk 28) birlikte kullanımı gerekçeyi karmaşıklaştırır. `READ_CONTACTS` zaten hassas izin (video + gerekçe istenir), `RECORD_AUDIO`/`CAMERA` kullanım gerekçesi mevcut.
- Öneri: Seçiciyi `image_picker` Photo Picker'a taşıyıp `READ_MEDIA_*` kaldırın (kendi albümüne yazma için `gal` kullanımı ayrıca değerlendirilmeli); iOS `NSPhotoLibraryUsageDescription` buna göre sadeleşir. Karar: ürün.

**A8-07 · YÜKSEK · Yerel gizli dosyalar OneDrive ile bulutla senkronize klasörde · sahip: altyapı (geliştirici makinesi)**
- Yer: proje yolu `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`: `.deploy.env` (VDS IP, `DEPLOY_USER`, **`DEPLOY_PASSWORD`** (betik kullanmıyor ama düz metin duruyor), **Brevo SMTP kullanıcı/parola**, yönetici e-postası, gizli yönetim yolu), `.env`, `.deploy/` (üretimde `generated-secrets.txt` buraya yazılır; A8-02) ve `.git` dizininin kendisi.
- Risk/etki: Microsoft hesabı ele geçirilirse/OneDrive paylaşımı yanlış açılırsa tüm dağıtım ve SMTP sırları sızar; `chmod 600` NTFS'te etkisizdir (`deploy.sh` `umask 077`/`chmod 600`'e güveniyor). OneDrive ayrıca `.git` nesne dosyalarını bozabilir (senkron çakışması).
- Öneri: Depoyu OneDrive dışına (`C:\src\bingol-university`) taşıyın veya en azından `.deploy*`, `.env*` dosyalarını OneDrive "yedekleme/senkron dışı" yapın; kullanılmayan `DEPLOY_PASSWORD` ve Brevo SMTP parolasını rotasyona alıp sunucuda `.env.prod`'da güncelleyin; sırları şifre yöneticisine taşıyın. (Sır değerleri bu rapora yazılmadı.)

**A8-08 · YÜKSEK · E-posta teslim edilebilirliği ve günlük kota kayıt hunisini tıkayabilir · sahip: altyapı/ürün**
- Yer: `docs/MAIL_DELIVERABILITY.md` (bölüm 9 ve 109-146: gönderen alan adı `bukampus.online`, site `bukampus.com.tr`), `docs/LAUNCH_CHECKLIST.md:29-56` (DNS/SPF/DKIM/DMARC maddeleri işaretsiz; "Gönderim sonrası spam testi" yapılmamış), `.env.prod.example` `MAIL_DAILY_LIMIT=300`, `docker-compose.prod.yml:140-146`.
- Kanıt/risk: Belge `MAIL_DELIVERABILITY.md:102`: "Gerçek SMTP ile gönderim bu sürümde denenmedi". Önceki analiz (görev notu): `bukampus.online` için DKIM var, **SPF ve MX yok** - bu repodan doğrulanamaz (DNS sorgusu yapılmadı). SPF olmadan DMARC (SPF ya da DKIM hizalaması gerekir; DKIM hizalıysa geçer ama kurumsal alıcılar `bingol.edu.tr` çoğunlukla SPF'siz postaya sert davranır) → doğrulama kodları spam/karantinaya düşer, kayıt tıkanır. `MAIL_DAILY_LIMIT=300` (Brevo ücretsiz katman) ≈ günde 300 doğrulama/sıfırlama e-postası; 20k kullanıcı hedefinde tek günlük kayıt dalgası kotayı bitirir, `MAIL_QUOTA_EXHAUSTED` ile kayıt 503 verir. Okul e-posta sistemi (muhtemelen Google/Microsoft) alıcı tarafında karantina yapabilir; okul BT'si ile beyaz liste görüşmesi yapılmamış (belgede yok).
- Öneri: (1) SPF `v=spf1 include:spf.brevo.com ~all`, DMARC `p=none` + rua, MX/Email Routing kayıtlarını tamamlayın ve `mail-tester` + gerçek `@bingol.edu.tr` hesabına teslim testi yapın; (2) okulun BT birimiyle gönderen alan adı/IP beyaz liste yazışması; (3) ücretli plan ya da ikinci sağlayıcı; kota %80'de uyarı; (4) Reply-To olarak kişisel Gmail yerine alan adı kutusu (A8-22).

### ORTA

**A8-09 · ORTA · `scripts/deploy.sh` (fiili üretim yolu) dağıtım öncesi yedek almıyor; iki farklı dağıtım yolu birbirinden ayrışmış · sahip: altyapı/kod**
- Yer: `scripts/deploy.sh` (yedek adımı yok; `grep backup.sh` boş) ↔ `scripts/deploy/update.sh:62-66` (yedek alır, `--no-backup` ile geçilir), `docs/DEPLOY.md:311` ("`update.sh` dağıtımdan hemen önce yedek aldığı için ..."). Sunucu düzeni `/opt/bukampus/releases/<sha>` yalnız `deploy.sh` ile uyumlu (`update.sh` `.git` bekler, `git pull`).
- Risk/etki: Flyway geri sarılmaz; şemayı değiştiren sürümde otomatik geri alma eski imajı yeni şemayla başlatır. En fazla 1 saatlik saatlik yedek vardır ama "tam dağıtım öncesi" yedeği garanti değildir. Belge, fiilen kullanılmayan betiğe dayanıyor.
- Öneri: `deploy.sh`'a `backup.sh` çağrısı (başarısızsa dur) + bekleyen migration varsa uyarı; `docs/DEPLOY.md`'yi gerçek akışa göre düzeltin; ya da `update.sh`'ı kaldırın.

**A8-10 · ORTA · Geri yükleme üretimde hiç denenmedi; "tatbikat günlüğü" boş · sahip: altyapı**
- Yer: `docs/RUNBOOK.md:127-131` (boş tablo), `docs/BACKUP_RESTORE.md:7` ve bölüm 9 ("sunucuda denenmemiş betik"), bölüm 10 (yalnız yerel REL1 provası, 2026-10-29).
- Risk/etki: RTO 2 saat iddiası ölçülmemiş (indirme + `pg_restore` + DNS + bootstrap süresi gerçek veriyle bilinmiyor); `verify-restore.sh` haftalık doğrulama canlı sunucuda çalışıyor mu bilinmiyor (`backup_verify_*` metriği izlenmiyor, A8-03).
- Öneri: Staging'de yeni VM'de baştan sona tatbikat (kontrol listesi BACKUP_RESTORE bölüm 7), süreleri RUNBOOK'a yazın; sonra altı ayda bir.

**A8-11 · ORTA · İmaj sürümleri kayan etiketli; imaj/CVE taraması yok · sahip: altyapı**
- Yer: `docker-compose.prod.yml` `caddy:2-alpine`, `postgres:16-alpine`, `redis:7-alpine`; `backend/Dockerfile` `maven:3-eclipse-temurin-17`, `eclipse-temurin:17-jre`; `web/Dockerfile` `node:22-alpine`, `nginx:1.27-alpine`; `.github/workflows/*` içinde Trivy/Grype/Snyk **yok**.
- Risk/etki: Sunucuda her `docker compose build/pull` farklı bir taban imaj getirebilir (tekrarlanamaz derleme, sürpriz büyük sürüm: postgres 16 küçük sürüm sorunsuz, `caddy:2` serbest); bilinen CVE'ler görünmez; backend imajı sunucu üzerinde derleniyor (A8-32). `apt-get install ffmpeg` sürümü sabit değil (medya işleme saldırı yüzeyi: ffmpeg CVE'leri).
- Öneri: Etiketleri küçük sürüme (`postgres:16.x-alpine`) ve zamanla özet (`@sha256:`) sabitleyin (Dependabot docker ekosistemi ekleyin); CI'ya `aquasecurity/trivy-action` (SHA'lı) ile imaj taraması; ffmpeg'i yalnız gerektiğinde güncelleyen düzenli yeniden derleme.

**A8-12 · ORTA · Uygulama PostgreSQL süper kullanıcısıyla bağlanıyor · sahip: kod/altyapı**
- Yer: `docker-compose.prod.yml:259-261` (`POSTGRES_USER: bingol` = süper kullanıcı) ve `DB_USER: bingol` (satır 114); Flyway ve uygulama aynı hesabı kullanır; `pg_stat_statements` yüklü.
- Risk/etki: Uygulamada SQL enjeksiyonu/RCE durumunda `COPY ... TO PROGRAM`, tüm veritabanlarını okuma, `pg_read_server_files` gibi süper kullanıcı yeteneklerine erişim; yetki ayrımı yok.
- Öneri: İki rol: `bingol_owner` (Flyway, DDL) ve `bingol_app` (yalnız DML, süper kullanıcı değil, `statement_timeout` rol düzeyi); yedek için salt-okunur `bingol_backup`.

**A8-13 · ORTA · Dağıtım hesabı docker grubunda + parolasız sudo; SSH ana makine anahtarı ilk bağlantıda kabul · sahip: altyapı**
- Yer: `scripts/deploy/bootstrap-server.sh:`(`usermod -aG docker "$DEPLOY_USER"`), `scripts/deploy.sh` (`sudo -n bash -s`, `StrictHostKeyChecking=accept-new`, `SSH_OPTS`), `scripts/ops/docker-cleanup.sh` ("kullanıcı: deploy (docker grubunda)").
- Risk/etki: `deploy` hesabının anahtarı (geliştirici makinesi, `~/.ssh/bu_deploy_ed25519`) çalınırsa sunucuda fiilen root (docker grubu + sudo). `accept-new` ilk bağlantıda MITM'e açık (TOFU); `known_hosts` parmak izi belgede/repoda doğrulanmıyor. `bootstrap-server.sh` SSH sertleştirmeyi **uygulamıyor** (yalnız öneri yazar): parola girişi/root girişi kapalı mı repodan doğrulanamaz (`deploy.sh` yorumu "sunucuda parola girişi kapalı" diyor; kanıt yok).
- Öneri: Anahtarı parolalı + ssh-agent/donanım anahtarı; `known_hosts` parmak izini bir kez elle doğrulayıp `StrictHostKeyChecking=yes`; sudo'yu yalnız gerekli komutlara kısıtlayın (sudoers); bootstrap betiğine `PasswordAuthentication no`/`PermitRootLogin no` doğrulaması (anahtar testi sonrası).

**A8-14 · ORTA · "Herkes için silinen" mesajlar varsayılan süresiz saklanıyor; hesap silinince mesajlar kalıyor · sahip: ürün/hukuk**
- Yer: `backend/src/main/resources/application.properties:211` (`app.chat.deleted-retention-days=${CHAT_DELETED_RETENTION_DAYS:0}`), `DeletedMessageRetention.java` (0 = hiçbir şey yapmaz), `docs/DEPLOY.md:181`; `AccountDataPurger` javadoc ("Sohbet geçmişi başkalarının verisi olduğundan satırlar silinmez"). Sözleşme (V820 EN "Deleted and edited messages") bunu açıklıyor.
- Risk/etki: Şifreli de olsa silinmiş mesaj + düzenleme geçmişi + ekler sınırsız tutulur; KVKK m.4/(2)-(ç) ve saklama ilkesi ("gereken süre") ve "silinen kullanıcı verisi" beklentisiyle gerilim; kullanıcı gizli olarak silindi sanır. Hesap silen kullanıcının gönderdiği mesaj içeriği anonim yazarla kalır (hukuki dayanak/meşru menfaat metinde açıkça yazılı mı: kısmen).
- Öneri: Üretimde `CHAT_DELETED_RETENTION_DAYS` (örn. 90-180) ayarlayın ve saklama politikasıyla (`docs/legal/internal/01`) eşleyin; hesap silmede kullanıcının kendi mesajlarının içeriğinin silinmesi (tombstone) seçeneğini ürün olarak değerlendirin.

**A8-15 · ORTA · `app_user.email_sha256` tuzsuz SHA-256, kalıcı; aydınlatmada yok · sahip: kod/hukuk**
- Yer: `backend/.../user/User.java` (`emailSha256`, `syncEmailHash`), rehber eşleştirme (`profile/ContactMatchService.java`), `docs/legal/privacy_tr.md:42/75` (yalnız rehberden gelen özetlerin saklanmadığı yazıyor).
- Risk/etki: Tuzsuz e-posta özeti, `bingol.edu.tr` adres uzayı küçük/tahmin edilebilir olduğundan sözlükle kolayca geri çözülür; yani "özet" takma adlandırma, anonimleştirme değil. Veritabanı sızarsa e-postalar yeniden elde edilir (zaten e-posta açık saklı - ek risk sınırlı); asıl risk rehber eşleştirmenin başkasının "kimin üye olduğunu" saatlik sınırla sorgulatabilmesi (profil gizlilik ayarlarına saygı gösteriliyor). Politikada "kendi e-posta özetiniz saklanır" ifadesi yok.
- Öneri: Gizlilik metnine ekleyin; rehber eşleştirmede istemci tarafı tuz/HMAC mümkün değil (sunucu da hesaplamalı) - bu yüzden sorgu başına limit, gizlilik kapsamı ("rehberde bulunabilir" tercihi) ve kötüye kullanım izleme (saatlik 500 limit) yeterli mi hukuk/ürün kararı.

**A8-16 · ORTA · Hesap silmede temizlenmeyen kullanıcı bağlantılı log/kayıt tabloları · sahip: kod**
- Yer: `profile/AccountDataPurger.java` listeleri `DELETES`/`SCRUBS` (aşağıdakiler yok); retention işleri: `AccessBanRetentionJob` (`app.security.ban-log-retention-days=90`), `app.dbmaint.log-days=90`.
- Kanıt/etki: `blocked_attempt_log` (IP + cihaz özeti + `user_id`), `profanity_hit_log` (`user_id`), `message_attachment_view` (kim hangi eki gördü; DataExporter'da da görünmüyor), `admin_audit` (yol içinde kullanıcı kimliği olabilir; 365 gün), `legal_acceptance` (bilinçli korunuyor), `moderation_strike`/`report` (bilinçli) hesap silmede silinmez; yalnız zamanla temizlenir (90-730 gün). `report.target` metinleri ve `event_certificate` başka kullanıcıya ait olabilir. Yedekler de bu verileri taşır.
- Öneri: `blocked_attempt_log` ve `profanity_hit_log` için `DELETES`'e `user_id` satırı; `message_attachment_view` için `DELETE ... WHERE viewer_id` (sütun adını doğrulayın) + `DataExporter`; bilinçli korunanları `docs/DATABASE.md` matrisine "gerekçe + süre" ile işleyin (aşağıda §3 KVKK matrisi).

**A8-17 · ORTA · Yedeklerde silinmiş kullanıcı verisi ve yeniden anonimleştirme prosedürü manuel · sahip: altyapı/hukuk**
- Yer: `docs/BACKUP_RESTORE.md:13` ve bölüm 5 adım 7 ("silme günlüğü/denetim kaydından ... yeniden anonimleştirin"), bölüm 2 (uzak tarafta 400 gün yaşam döngüsü önerisi) ↔ `docs/legal/internal/01_saklama_ve_imha_politikasi.md` (öneri <= 12 ay).
- Risk/etki: Geri yüklemede silinmiş hesaplar canlanır; `deleted_at`/anonim satırlar yedekten önceki hâle döner ve silinen kimlikleri tutan bir "silme defteri" (yalnız kimlik/zaman damgası, DB dışı) yok, yani adım 7 uygulanamayabilir. Önerilen 400 günlük uzak saklama 12 ayı aşıyor (politikayla çelişir). Şu an yerel pencere yalnız 3 saat olduğundan risk düşük; A8-01 çözülüp uzak kopya eklenince büyür.
- Öneri: Silinen kullanıcı kimliklerini ayrı, yedekle ilişkisiz bir "silme defteri"ne (hashli kullanıcı id + tarih; `data_purge_log` benzeri ama yedek kapsamı dışında dosya/Redis) yazın; geri yükleme betiğine "defteri yeniden uygula" adımı ekleyin; uzak saklama süresini politikayla hizalayın (<= 365 gün).

**A8-18 · ORTA · Yaş sınırı belirsiz (18+ beyanı ↔ <18 yasal temsilci maddesi) · sahip: hukuk/ürün**
- Yer: `docs/store/data_safety.md` §1 ve §4 (hedef kitle 18+); `docs/legal/terms_tr.md` madde 4 ("18 yaş altına yasal temsilci izniyle"); `docs/LEGAL_NOTES.md` madde 10 (avukat sorusu açık); kayıt akışında doğum tarihi/yaş doğrulaması yok (yalnız `bingol.edu.tr` e-postası).
- Risk/etki: Üniversite öğrencilerinin bir kısmı 17 yaşında olabilir; Play hedef kitlesi 18+ beyan edilip kullanım koşulları <18'e izin verirse tutarsızlık; KVKK'da çocuk verisi için ek özen beklentisi.
- Öneri: Tek tutarlı karar (kayıtta "18 yaşından büyüğüm / yasal temsilci izni var" onayı + metin) ve Play hedef kitle beyanının buna uyumu - avukat.

**A8-19 · ORTA · Yönetici sohbet çözme (`CRYPTO_ADMIN_DECRYPT_ENABLED=true`) varsayılan açık · sahip: ürün/hukuk**
- Yer: `docker-compose.prod.yml:127`, `.env.prod.example`, `docs/legal/internal/04_yonetici_mesaj_erisim_politikasi.md`, `message_access_audit` (append-only tetikleyici, 730 gün, `reason >= 10` karakter), V820 sözleşme "tamamen gizli değil" uyarısı.
- Risk/etki: FULL profilli yönetici (ve `ADMIN_EMAILS` hesapları) gerekçeyle özel mesajları okuyabilir; sızan yönetici hesabı = mesaj ifşası. İyi tarafı: denetim kaydı değiştirilemez, kullanıcıya metinle bildirilmiş.
- Öneri: Çözme yetkisini ayrı izne bağlayıp (iki kişi onayı, P16 RBAC ile) yalnız şikâyet kaydı olan konuşmalarda açın; kullanıcıya erişim sonrası bildirim politikası (hukuk).

**A8-20 · ORTA · İsteğe bağlı Sentry (`SENTRY_DSN`): üçüncü taraf aktarımı belgelenmemiş · sahip: hukuk/altyapı**
- Yer: `backend/pom.xml:45` (`sentry-logback`), `docker-compose.prod.yml:149`, `docs/legal/internal/08_tedarikci_veri_isleyen_listesi.md` (Sentry yok), `docs/OBSERVABILITY.md`.
- Risk/etki: DSN doldurulursa hata günlükleri (e-posta/IP parçaları içerebilir; `LogMasking` kısmi) yurt dışına gider; tedarikçi listesinde, aydınlatmada ve Play beyanında (üçüncü taraf paylaşımı) yok. CrashReporter "üçüncü taraf yok" iddiası yalnız mobil için doğru.
- Öneri: Kullanılmayacaksa DSN'yi boş bırakmayı `ProdSettingsValidator`'da belgeleyin; kullanılacaksa PII kapatma (`send-default-pii=false`), veri bölgesi AB, tedarikçi listesi + aydınlatma güncellemesi.

**A8-21 · ORTA · iOS gizlilik bildirimleri: `PrivacyInfo.xcprivacy` yok; izin metinleri kısmen yanıltıcı; yerel ağ izni yayın sürümünde · sahip: kod/ürün**
- Yer: `mobile/ios/Runner/Info.plist` (`NSContactsUsageDescription`: "rehberiniz sunucuya gönderilmez" - oysa e-posta SHA-256 özetleri gönderiliyor; `NSLocalNetworkUsageDescription` + `NSAllowsLocalNetworking`), `mobile/ios/Runner/` içinde `*.xcprivacy` yok.
- Risk/etki: Apple App Store incelemesinde gizlilik bildirim dosyası/gerekçe eksikliği ve "geliştirme sunucusu için yerel ağ" izin penceresi ret nedeni olabilir; iOS aktif dağıtım ücretsiz Apple ID ile kısıtlı (CLAUDE.md).
- Öneri: Uygulama düzeyinde `PrivacyInfo.xcprivacy` (toplanan veri türleri §3'teki Apple etiketleriyle), rehber metnini "rehberinizdeki e-postaların geri döndürülemez özetleri eşleştirme için gönderilir" yapın, yerel ağ anahtarlarını yalnız debug/profile yapılandırmasına alın.

**A8-22 · ORTA · Operasyonel tek nokta: tek sahip, kişisel iletişim adresi, olay mudahale kaydı yok · sahip: ürün**
- Yer: `.github/CODEOWNERS` (yalnız `@YusufAkin27`), `docs/store/*` ve LAUNCH_CHECKLIST (destek/Reply-To/mağaza iletişimi kişisel Gmail), `.deploy.env` (yönetici e-postası tek), `docs/LAUNCH_CHECKLIST.md:12` (Play kişisel hesap adresi yayımlıyor), `docs/RUNBOOK.md` günlük tabloları boş, `docs/legal/internal/03_veri_ihlali_mudahale_plani.md` (72 saat KVKK Kurul bildirimi planı var; sorumlu kişi/rota listesi doldurulmuş mu belirsiz).
- Risk/etki: Bus-factor 1: erişim kaybı (hesap, telefon, hastalık) hâlinde sunucu, GitHub, Play, Brevo, alan adı kaydı kilitlenir. Veri ihlali anında iletişim kişisel posta kutusundadır; kurumsal güven ve KVKK iletişim yükümlülüğü zayıf.
- Öneri: İkinci yönetici (GitHub org + Play + sunucu + alan adı + Brevo), alan adı üzerinde `destek@`/`kvkk@`/`guvenlik@` kutuları (Cloudflare Email Routing yeterli), olay kaydı şablonunun ilk tatbikatı.

**A8-23 · ORTA · Kenar (Caddy) katmanında hız sınırı/WAF yok; erişim günlüğü saklama süresi tanımsız · sahip: altyapı**
- Yer: `deploy/Caddyfile` (rate_limit modülü yok; yalnız gövde sınırı ve `read_header`), `docker-compose.prod.yml:15-19` (log: json-file 10m × 5), Caddy `log { output stdout; format json }` (istemci IP + tam URI).
- Risk/etki: Hız sınırı yalnız uygulama içinde (Redis); Redis düşerse "auth çalışmaz" davranışı sürer, ama kenarda hiçbir DoS/ kaba kuvvet sönümlemesi yok (bağlantı sayısı, Slowloris için yalnız `read_header`). Erişim günlükleri IP içerir: saklama süresi boyuta bağlı (yaklaşık günler), yazılı bir süre ve gerekçe yok; gizlilik metni IP için 90 gün diyor (uygulama tablosu), Caddy günlüğü bu söze dahil değil. `/support/track?token=` gibi sorgu dizisi taşıyan URL'ler günlüğe girer (token SHA-256'lı saklanıyor ama günlük ham URI tutar).
- Öneri: `caddy-ratelimit` yerine Cloudflare (DNS zaten planlı, LAUNCH_CHECKLIST 1.1) ücretsiz DDoS/WAF/Rate limiting önüne; Caddy günlüğünde `uri` sorgu dizisini filtreleyin (`log { format filter { request>uri query { delete token } } }`); saklama süresini belge ve gizlilik metniyle eşleyin.

**A8-24 · ORTA · Cihazda düz metin mesaj önbelleği ve otomatik galeriye kayıt, "şifreli saklanır" algısı ile çelişiyor · sahip: ürün/kod/hukuk**
- Yer: `mobile/lib/core/cache/message_cache.dart` (sohbet başına 20 mesaj, düz JSON dosya; `cache_policy.dart` başlığı ise "sohbet mesajları diske yazılmaz" der - iki belge çelişiyor), `mobile/lib/features/chat/photo_autosave.dart`, Android `allowBackup="false"` + `data_extraction_rules.xml` (iyi), iOS için eşdeğer yedek dışlama doğrulanmadı.
- Risk/etki: Kök/jailbreak veya cihaz yedeği ile son mesajlar okunabilir; galeriye kaydedilen fotoğraflar uygulama güvenliği dışındadır ve bulut galeriye gidebilir. Ayarla kapatılabilir olması (otomatik kaydetme "ayar açıldıktan sonra") hafifletici.
- Öneri: Önbelleği `flutter_secure_storage` anahtarıyla şifreleyin veya kapatma seçeneği; iOS dosyalarını `NSURLIsExcludedFromBackupKey` ile işaretleyin; aydınlatma metni (A8-04).

### DÜŞÜK

**A8-25 · DÜŞÜK · `mail_outbox.vars_json` doğrulama/sıfırlama kodunu düz metin tutuyor · sahip: kod**
- Yer: `mail/MailService.java:87-122` (`vars("code", code ...)`), V110 (`vars_json VARCHAR(4000)`), saklama `DbMaintenanceJob.mailSent` (SENT: 7 gün; DEAD: 30 gün), `MailQueueWorker.logForDevelopment`.
- Etki: 10 dk geçerli kod 7-30 gün DB'de ve yedekte kalır (kısa ömürlü, ama okuma yetkisi olanlar bekleyen kodları görebilir; `mail_outbox` yönetici panelinden listelenebilir mi: `smoke-admin-mailops.sh` kapsamı).
- Öneri: Gönderim başarılı olunca (veya her durumda) `vars_json`'dan `code` anahtarını sil/maskele; DEAD kayıtlarda da.

**A8-26 · DÜŞÜK · Redis parolasız · sahip: altyapı**
- Yer: `docker-compose.prod.yml:287` (`redis-server --appendonly yes ...` `requirepass` yok); `internal` ağ + host portu yok.
- Etki: Ağ içinden erişen herhangi bir ele geçirilmiş konteyner (ör. `backup` hem `internal` hem `edge`ta) refresh token özetlerini, `suspended:` işaretlerini, bekleyen kayıt verisini (`reg:<email>` parola özeti içerebilir) okur/yazar.
- Öneri: `--requirepass` + `REDIS_PASSWORD` (Spring `spring.data.redis.password`), `backup` servisinin `edge` ağından ayrılması ya da çıkışı yalnız rclone için ayrı ağ.

**A8-27 · DÜŞÜK · Başlık ince ayarları · sahip: altyapı/kod**
- Yer: `web/nginx-security.conf` (CSP `connect-src 'self' ws: wss:` her ana makineye açık, `style-src 'unsafe-inline'`), `deploy/Caddyfile:45` (HSTS `includeSubDomains` var, `preload` yok; alt alanlar HTTPS'e hazır değilse risk), API yanıtlarında CSP yok (JSON için gerekmiyor), `Cross-Origin-Resource-Policy` yok.
- Öneri: `connect-src 'self' wss://bukampus.com.tr`; HSTS preload yalnız tüm alt alanlar HTTPS olunca.

**A8-28 · DÜŞÜK · "Gizli yönetim yolu" güvenlik önlemi değil, istemci paketinde açık · sahip: bilgi**
- Yer: `web/Dockerfile` (`ARG VITE_ADMIN_PATH` derleme zamanında JS'e gömülür), `web/src/adminBase.ts` (belge kendisi "güvenlik önlemi değil" der).
- Etki: Yol, herkese açık `assets/*.js` içinde aranabilir; yönetici API'si JWT+RBAC ile korunuyor (iyi). Gerçek yol değeri repoda bulunmadı (git geçmişinde `grep` sonucu yok).
- Öneri: Yola güvenmeyin; yönetici arayüzüne IP kısıtı veya Cloudflare Access/2FA düşünün.

**A8-29 · DÜŞÜK · `SECURITY.md` yer tutucu e-posta; `security.txt` iletişimi bir web sayfası · sahip: ürün**
- Yer: `SECURITY.md` (`<GUVENLIK_E_POSTASI>`), `web/public/.well-known/security.txt` (`Contact: {{ORIGIN}}/tr/security`, Expires 2027-10-26).
- Öneri: `Contact: mailto:guvenlik@...` ekleyin; Expires'ı yıllık takvime bağlayın.

**A8-30 · DÜŞÜK · `google-services.json` depoda; API anahtarı kısıtlaması işaretsiz · sahip: altyapı**
- Yer: `mobile/android/app/google-services.json` (izli; geçmiş: commit `97e6f2a`, `b11eb54`), `docs/LAUNCH_CHECKLIST.md:92` (kısıtlama işaretsiz).
- Etki: Firebase istemci anahtarları gizli sayılmaz, ancak kısıtlanmamışsa kota/kötüye kullanım açığıdır. Servis hesabı özel anahtarı (FCM_CREDENTIALS_JSON) depoda **yok** (iyi).
- Öneri: Google Cloud Console'da anahtarı Android paket adı + SHA-1 imzasıyla ve yalnız gereken API'lerle kısıtlayın.

**A8-31 · DÜŞÜK · Yük altında/arızada bakım davranışı: Caddy sağlık denetimi tüm siteyi 503 yapar · sahip: altyapı/kod**
- Yer: `deploy/Caddyfile:32-37` (aktif sağlık denetimi; backend sağlıksızsa `reverse_proxy` 503, statik web yine `web:80`), `appinfo` `maintenance_mode` (uygulama içi banner, trafik kesmez).
- Etki: Planlı migration/ağır yük sırasında kullanıcıya düzgün bir "Bakımda" yanıtı yok (API 503 ham). Mobil istemci 503/`DB_TIMEOUT` ele alıyorsa tolere edilir; web yönetim panelinde belirsiz.
- Öneri: Caddy `handle_errors` ile 502/503 için `Retry-After` ve JSON `{code:"MAINTENANCE"}` gövdesi; dağıtım betiği migration varken bakım bayrağını açsın.

**A8-32 · DÜŞÜK · İmajlar üretim sunucusunda derleniyor (kayıt defteri yok); geri alma 1 seviye · sahip: altyapı**
- Yer: `scripts/deploy.sh` (`dc build`; ilk derleme "5-15 dk", Maven + npm sunucuda), `:previous` etiketi tek seviye, `docker-cleanup.sh KEEP_RELEASES=2`.
- Etki: Derleme sırasında canlı servislerle CPU/RAM/disk yarışı (2 GB'lık sınırlı VPS'te OOM → kesinti riski); iki sürüm geriye dönülemez. CI GHCR'ye imaj itiyor (`ci.yml:249`) ama sunucu onları kullanmıyor.
- Öneri: CI imajını `sha-<commit>` etiketiyle çekmeye geçin (staging zaten böyle: `deploy-staging.yml`), derleme sunucudan çıksın.

**A8-33 · DÜŞÜK · Sır/anahtar rotasyon ve olay günlükleri boş; yıllık rotasyon takvimi yok · sahip: altyapı**
- Yer: `docs/RUNBOOK.md` bölüm 12 (iki tablo boş), `docs/KEY_MANAGEMENT.md` bölüm 3 ("yılda bir" rotasyon önerisi).
- Etki: İlk rotasyon/sızıntı tatbikatı yapılmadı; `DEPLOY_PASSWORD` gibi kullanılmayan sırlar dosyada kalıyor (A8-07).
- Öneri: Takvime 6 aylık "sır gözden geçirme" ve ilk SMTP/FCM rotasyonunu yazın.

---

## 3. Tablolar

### 3.1 KVKK veri matrisi (kişisel veri tutan tablolar ve süreçler)

Kaynak: `backend/src/main/resources/db/migration/*.sql` (87 dosya), `AccountDataPurger`, `ProfileService.anonymize`, `DbMaintenanceJob`, `DataExporter` bean'leri (bölüm adları: profile, devices, notifications, notificationPreferences, notificationSettings, accessHistory, activity, dailyOpens, analyticsEvents, bookmarks, blockedUserIds, follows, posts, postLikes, communityMemberships, communityPosts, conversationMemberships, sentMessages, sentChatImages, messageReactions, polls, supportTickets, feedback, feedbackVotes, reportsFiled, moderation, mailCampaigns, legalConsents, timetable, eventApplications/Attendance/Rsvps, createdEvents, eventExtras, clubExtras, clubPermissions, grants, profilePrivacy). "?" = repodan kesin doğrulanamadı.

| Tablo / veri | Kişisel veri | (a) Dışa aktarma | (b) Hesap silme / anonimleştirme | (c) Saklama ve gece temizliği | Not / açık nokta |
|---|---|---|---|---|---|
| `app_user` | e-posta, ad, bölüm, fakülte, sınıf, bio, avatar, `email_sha256` | Evet (`profile`) | Anonimleştirilir (e-posta `deleted-<id>@deleted.invalid`, alanlar null, `email_sha256` null) | Satır kalır (referans bütünlüğü) | `email_sha256` tuzsuz, aydınlatmada yok (A8-15) |
| `device` (FCM token) | FCM belirteci, platform, sürüm, dil | Evet (`devices`) | Silinir | 60 gün görülmeyen gece temizliği | Token Google'a gider (FCM) |
| `push_outbox` | `payload_json` (başlık/gövde; mesaj önizlemesi varsayılan kapalı), `fcm_token_hash` | Hayır (geçici) | Silinir | Worker + `DbMaintenance`/admin temizliği (SENT/DEAD süresi: ? ) | Önizleme tercihi `notification_pref.message_preview` (V896) |
| `notification`, `notification_pref`, `notification_subtype_pref` | bildirim başlık/gövde, tercihler | Evet (`notifications`, `notificationPreferences`, `notificationSettings`) | Silinir | Okunmuş 30 gün, okunmamış 90 gün, kullanıcı başına üst sınır | Mesaj önizlemesi bildirim tablosuna YAZILMAZ (`MessageService`) |
| `mail_outbox` | alıcı e-posta, **doğrulama/sıfırlama kodu (düz)** `vars_json` | Hayır | Satır silinmez (kullanıcı id'si yok; yalnız adres) | SENT 7 gün, DEAD 30 gün | A8-25 |
| `mail_suppression` | e-posta SHA-256 + neden | Hayır | Korunur | süresiz | Duyuru aboneliği iptali kanıtı; hash tuzsuz |
| `mail_campaign_recipient` | kullanıcı id + durum | Evet (`mailCampaigns`) | Silinir | kampanya ile | — |
| `user_device_log` | cihaz HMAC özeti, IP, platform, sürüm, olay | Evet (`accessHistory`) | Silinir | 90 gün (`AccessBanRetentionJob`) | Cihaz kimliği HMAC (iyi); IP ham |
| `blocked_attempt_log` | IP, cihaz özeti, `user_id`, yol | Hayır | **Silinmez** | 90 gün | A8-16 |
| `access_ban`, `ban280_anonymizer_range` | IP/CIDR/cihaz özeti, gerekçe | Hayır | Korunur (yasak izi) | yasak süresi / `BAN_LOG` | Moderasyon izi (gerekçe belgede) |
| `analytics_event`, `activity_daily`, `analytics_event_daily` | ekran/olay adı, günlük açılış | Evet (`analyticsEvents`, `activity`, `dailyOpens`) | Ham olay ve günlük aktiflik silinir; `analytics_event_daily` toplulaştırılmış (kişisel değil) | Ham 45 gün, `activity_daily` 400 gün | — |
| `crash_event`, `crash_group`, `crash_group_version` | OS sürümü, cihaz modeli, ekran, maskelenmiş yığın; kullanıcı kimliği YOK | Hayır (anonim) | Uygulanmaz | 30 gün (`DbMaintenanceJob`) | Aydınlatma/Play beyanı eksik (A8-04/05) |
| `message`, `message_revision`, `message_reaction`, `conversation_key` | şifreli mesaj gövdesi, düzenleme geçmişi | Gönderilen mesajlar (`sentMessages`, `messageReactions`); silinmiş mesajlar hariç | Satırlar KALIR (yazar anonim), odalardan çıkış yapılır | "Herkes için sil" süresiz (varsayılan 0 gün), `DeletedMessageRetention` isteğe bağlı | A8-14 |
| `message_attachment` (+ `message_attachment_view`) | sohbet görseli/video (şifreli dosya), görüntüleme kaydı | `sentChatImages` | Dosyalar/satırlar kalır (mesajla); `message_attachment_view` silinmez (?) | Tek gösterimlik 365 gün (`view-once-retention-days`) | A8-16; video üst verisi temizlenmiyor (topluluk kuralları 42) |
| `message_access_audit` | yönetici erişim kaydı (IP, gerekçe) | Hayır | Korunur | 730 gün (gece job) | Append-only tetikleyici |
| `conversation_member`, `chat_room_link` | üyelik | `conversationMemberships` | `left_at` işaretlenir | oda kapanışı + bakım | — |
| `post`, `post_media`, `post_like`, `user_follow*` | gönderi metni/foto, beğeni, takip | `posts`, `postLikes`, `follows` | `PostAccountPurger`/`SocialAccountPurger` (silinir) | Silinen gönderi medyası 30 gün | video özelliği kaldırıldı |
| `community_*`, `club_*`, `event_*`, `event_attendance`, `event_certificate` | üyelik, başvuru yanıtları, yoklama, sertifika adı | `communityMemberships`, `eventApplications`, `eventAttendance`, `eventRsvps`, `eventExtras`, `clubExtras` | Üyelik/yanıt/geri bildirim silinir; başvuru notları null; sertifika adı "Silinmiş kullanıcı"; yoklama ve sayaçlar anonim kalır | süresiz (istatistik) | `club_audit` 730 gün |
| `poll_ballot`, `poll_vote` | seçmen kaydı (silinir), oy (user_id null yapılır) | `polls` (kendi oyu: ? ) | Ballot silinir, oy anonim | anket ömrü | Oy gizli (kimlik hiçbir uçta gösterilmez) |
| `support_ticket`, `support_message`, `feedback`, `moderation_appeal`, `report` | serbest metin, e-posta (herkese açık talep), kimlik | `supportTickets`, `feedback`, `moderation`, `reportsFiled` | Metin `[silindi]` yapılır, satır kalır | Herkese açık talep 365 gün + gece temizliği; doğrulanmamış 24 sa | `support_track_token` SHA-256 |
| `legal_acceptance` | kullanıcı id, belge, sürüm, zaman (IP yok) | Evet (`legalConsents`) | **Bilerek korunur** (hukuki kanıt) | süresiz | Aydınlatmada belirtilmiş (V820) |
| `user_block`, `bookmark`, `club_join_answer`, `event_feedback`, `feedback_vote`, `notification_*` | tercih/etkileşim | Evet | Silinir | — | — |
| `tt_*`, `exam_schedule`, `academic_event`, `announcement_read`, `department_announcement` | ders programı, okundu bilgisi | `timetable` | `AcademicAccountPurger` | — | — |
| `profile_privacy` | gizlilik ayarları | Evet (`profilePrivacy`) | Silinir | — | — |
| `profanity_hit_log` | alan, `user_id`, eylem | Hayır | **Silinmez** | `app.dbmaint.log-days` 90 | A8-16 |
| `moderation_strike`, `suspend_recommendation`, `moderation_target_state`, `blocked_content_hash` | moderasyon kararları | `moderation` (kısmen) | Bilerek korunur | süresiz / ? | Gerekçe: moderasyon denetimi |
| `admin_audit` | yönetici e-posta, yol, IP | Hayır (yönetici verisi) | Korunur | 365 gün | Yol içinde kullanıcı id olabilir |
| `data_export_receipt`, `data_purge_log` | yönetici işlem kayıtları | Hayır | Silinemez (tasarım) | süresiz | Veri saklama (DS1) |
| `app_setting`, `faq_item`, `news_item`, `menu_day`, `menu_item_calorie`, `sync_status`, `legal_document` | kişisel değil | — | — | — | Kişisel olmayan referans veri |
| Redis `reg:<email>` (parola özeti dahil) | e-posta, görünen ad, parola özeti | — | — | 1 saat TTL | Parolasız Redis (A8-26) |
| Redis `rt:*`, `rtu:*`, `pwchg:*`, `suspended:*`, `rolechg:*`, `seen:*`, `act:*`, `presence:*`, `lastseen:*`, `rl:*` | token özetleri, kullanıcı id, e-posta/IP özetleri | — | Çıkışta/şifre değişiminde silinir | Çoğu TTL'li; `suspended:*` TTL'siz (bilerek); `lastseen:*` TTL: ? | Redis yedeklenmez |
| Yedekler (`backups` volume, uzak kopya) | tüm yukarıdakiler (age şifreli) | — | Silinenler yedekten canlanır (A8-17) | 3 saatlik pencere (yerel); uzak: yok | A8-01/17 |
| Sunucu günlükleri (Caddy JSON, backend, postgres) | IP, URI, e-posta parçaları (maskeli) | — | — | Docker `json-file` boyuta göre (10 MB × 5) | A8-23 |

**Üçüncü taraflar:** Google Firebase/FCM (push: başlık/gövde, token; mesaj önizlemesi varsayılan KAPALI - `app.push.message-preview:false`), Brevo (SMTP: e-posta adresi + kod içeriği), barındırma sağlayıcısı (VPS), Let's Encrypt (alan adı), isteğe bağlı Sentry (A8-20). Yurt dışı aktarım değerlendirmesi: `docs/legal/internal/05`, durum LAUNCH_CHECKLIST'te açık.

### 3.2 Play Veri Güvenliği taslağı (güncellenmiş öneri)

`docs/store/data_safety.md` temel alınmıştır; **kalın** satırlar mevcut belgeden farklıdır. Form genel: tüm veriler aktarımda şifreli (HTTPS/WSS), kullanıcı silme isteyebilir (uygulama içi + web), uygulama hedef kitlesi 18+ (A8-18 uyumlandırılmalı).

| Play türü | Toplanır | Paylaşılır* | Zorunlu | Amaç | Not |
|---|---|---|---|---|---|
| Ad | Evet | Hayır | Evet | İşlevsellik, hesap | Görünen ad |
| E-posta | Evet | Hayır | Evet | İşlevsellik, hesap, iletişim | bingol.edu.tr |
| Kullanıcı kimlikleri | Evet | Hayır | Evet | İşlevsellik | iç kimlik, isteğe bağlı okul numarası |
| Fotoğraflar | Evet | Hayır | Hayır | İşlevsellik | profil/gönderi/sohbet; EXIF temizlenir; galeriye kaydetme yerel |
| Videolar | Evet | Hayır | Hayır | İşlevsellik | sohbet videosu (üst veri temizlenmez) |
| Ses | Evet | Hayır | Hayır | İşlevsellik | video kaydı sesi |
| Uygulama içi mesajlar | Evet | Hayır | Hayır | İşlevsellik | sunucuda zarf şifreli; yönetici erişimi denetimli |
| Kişiler | Evet (geçici) | Hayır | Hayır | İşlevsellik | rehber e-posta SHA-256 özeti, saklanmaz |
| Uygulama etkileşimleri | Evet | Hayır | Evet | Analitik, işlevsellik | ekran/olay adı |
| **Çökme günlükleri** | **Evet** | Hayır (kendi sunucumuz) | **Hayır (ayarlardan kapatılabilir; kod ile belgeyi hizalayın)** | Analitik | **maskelenmiş yığın izi, OS sürümü, ekran; 30 gün** |
| **Tanılama / Cihaz veya diğer kimlikler** | Evet | **Evet (FCM belirteci Google'a)** | Evet | İşlevsellik (bildirim), dolandırıcılık önleme/güvenlik | uygulamaya özel cihaz kimliği (HMAC'li saklanır), FCM belirteci, **cihaz modeli/OS sürümü (çökme raporunda)**; IP güvenlik günlüğünde 90 gün |
| Diğer kullanıcı içeriği | Evet | Hayır | Hayır | İşlevsellik | gönderi, destek/geri bildirim, anket |
| Konum / finansal / sağlık / SMS / takvim / dosya | Hayır | — | — | — | izin yok |

\* Play "paylaşım" tanımı: hizmet sağlayıcı işleyiciler dışlanıyorsa FCM belirteci "paylaşılan" sayılmayabilir; hukuk onayı gerekir.

**İzinler ve gerekçeler:** `CAMERA` (QR yoklama, profil fotoğrafı), `RECORD_AUDIO` (video kaydı sesi), `READ_CONTACTS` (hassas; tanıtım videosu + gerekçe gerekir), `POST_NOTIFICATIONS`, `READ_MEDIA_IMAGES/VIDEO` (**A8-06: Photo Picker'a geçilmeli**), `RECEIVE_BOOT_COMPLETED` (etkinlik hatırlatma alarmlarını yeniden kurma), `WRITE_EXTERNAL_STORAGE` yalnız API ≤ 28, `INTERNET`. Konum, SMS, arama, takvim yok.

### 3.3 Apple App Privacy etiketi taslağı

| Kategori | Veri | Kullanıcıya bağlı | İzleme | Amaç |
|---|---|---|---|---|
| Contact Info | Ad, e-posta | Evet | Hayır | Uygulama işlevselliği, hesap |
| Contacts | Rehber e-posta özetleri (geçici) | Hayır (saklanmaz) | Hayır | Uygulama işlevselliği |
| User Content | Fotoğraf/video, mesajlar, gönderiler, destek metni | Evet | Hayır | Uygulama işlevselliği |
| Identifiers | Kullanıcı kimliği, cihaz kimliği (HMAC), push token | Evet | Hayır | İşlevsellik, güvenlik |
| Usage Data | Ürün etkileşimi (ekran/olay) | Evet | Hayır | Analitik |
| Diagnostics | Çökme verisi, cihaz modeli/OS | Hayır (kullanıcı kimliği yok) | Hayır | Uygulama işlevselliği/analitik |

---

## 4. Aydınlatma/gizlilik metinlerinde EKSİK işlemler listesi (A8-04 ayrıntısı)

1. Çökme/hata raporu toplama (içerik, 30 gün, kapatma yolu, üçüncü taraf yok).
2. Otomatik galeriye kaydetme (kapsam, tek gösterimlik hariç, cihaz bulut yedeği uyarısı).
3. Cihazda yerel mesaj önbelleği (son 20 mesaj/sohbet, çıkışta silinir).
4. Kamera ve mikrofon izni (QR yoklama, profil, video; kayıt cihazda, yükleme kullanıcı eylemiyle).
5. Fotoğraf seçimi/kırpma (cihazda; yeniden kodlama sunucuda var).
6. Kayıtlı kullanıcının kendi e-posta SHA-256 özetinin saklanması (rehber eşleştirme için, hesap silinince silinir).
7. Push cihaz kaydı ayrıntıları: platform, uygulama sürümü, dil, son görülme; 60 gün temizlik; mesaj önizleme tercihi (varsayılan kapalı).
8. Caddy/sunucu erişim günlükleri (IP, URI) ve saklama süresi.
9. İsteğe bağlı Sentry (kullanılacaksa).
10. Yedekleme (şifreli, saklama pencereleri, silinen verinin yedekte kalma süresi).

---

## 5. Neye bakılamadı

- **Üretim sunucusu:** hiçbir erişim yok; UFW/SSH sertleştirme, çalışan konteyner durumu, gerçek `.env.prod` içeriği (özellikle `BACKUP_REMOTE`, `BACKUP_WEBHOOK_URL`, `CHAT_DELETED_RETENTION_DAYS`, `MAIL_*`), sertifika ve DNS (SPF/MX/DKIM/DMARC) durumu doğrulanmadı. Önceki analizdeki "bukampus.online DKIM var, SPF/MX yok" bilgisi görev notundan alındı.
- **Dinamik testler:** A7 yalıtılmış yığın hazır değildi; `GET /api/users/me/export` kapsamı, hesap silme sonrası tablo durumu, rehber eşleştirme sızıntısı, Redis TTL'leri ve gerçek log içeriği çalıştırılarak doğrulanmadı (yalnız kaynak kod okundu).
- **GitHub tarafı:** depo gerçekten private mı, dal koruması/zorunlu inceleme, Environment gizli bilgileri, Dependabot/CodeQL uyarı durumu ve Actions günlükleri görülmedi.
- **Git geçmişi:** `git log -S` ile özel anahtar başlığı, `AGE-SECRET-KEY-1`, `private_key_id`, `ghp_` ve `.env`/keystore/`key.properties`(gerçek)/servis hesabı dosyası arandı; HEAD'de AIza ön ekli bir istemci anahtarı (`google-services.json`, A8-30) dışında sır bulunmadı. Her blob içerik taraması (`gitleaks` full-history) yerel yürütülmedi.
- **Mobil:** iOS yerel yedek dışlama, release yapılandırmasında cleartext kapalı mı (`allowCleartext` varsayılanı), `ProGuard/R8` ve gerçek cihaz izin akışı doğrulanmadı; `photo_manager`/`gal` paketlerinin gerçek izin istemleri derlenmiş manifestte (merged manifest) bakılmadı.
- **Hukuki içerik:** metinlerin yasal yeterliliği (m.10, VERBİS eşiği, yurt dışı aktarım açık rızası) hukuk görüşü gerektirir; burada yalnız eksik işlem envanteri çıkarıldı.
- **İzleme yığını:** `monitoring/` yapılandırmalarının (alert kuralları, Alertmanager alıcıları) dağıtılmış olup olmadığı; yalnız dağıtım betiklerinde çağrılmadığı görüldü.

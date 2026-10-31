# Yayın kontrol listesi (alan adı, e-posta, VPS, mağaza)

Bu belge **sıra ve sorumluluk** listesidir; ayrıntıyı tekrarlamaz, ilgili belgeye bağlanır. Çelişki halinde bağlanan belge geçerlidir: [DEPLOY.md](DEPLOY.md), [MAIL_DELIVERABILITY.md](MAIL_DELIVERABILITY.md) bölüm 9, [BACKUP_RESTORE.md](BACKUP_RESTORE.md), [KEY_MANAGEMENT.md](KEY_MANAGEMENT.md), [PUSH_SETUP.md](PUSH_SETUP.md), [ANDROID_RELEASE.md](ANDROID_RELEASE.md), [DEVICE_TEST_PLAN.md](DEVICE_TEST_PLAN.md), [store/](store/README.md), [LEGAL_NOTES.md](LEGAL_NOTES.md).

Durum işaretleri: `[ ]` yapılmadı, `[x]` yapıldı. **Sizin yapmanız gerekenler** (hesap, ödeme, kimlik, anahtar üretimi) "SİZ" etiketli; kod/belge tarafı hazırdır. Hiçbir sır bu listeye yazılmaz; örnek değerler uydurmadır (`203.0.113.x` belge IP aralığıdır).

## Aşama 0. Hukuk ve kimlik kararları (yayından ÖNCE, SİZ)

[LEGAL_NOTES.md](LEGAL_NOTES.md) "Yayın öncesi avukat kontrol listesi" 17 maddedir. Avukat görüşüne kadar **kapalı test** (davetli, az sayıda kişi) kabul edilebilir; **herkese açık yayın** için en az şunlar kapanmalıdır (öneri; hukuki görüş değildir):

- [ ] Madde 1 üniversite adı/içerik kullanım izni ("resmî değil" yaklaşımı yeter mi); mağaza metinleri bu yaklaşıma göre yazıldı ([store/](store/README.md)).
- [ ] Madde 2 VERBİS/KEP ve şahsi adresin herkese açık yayımı (Play kişisel hesapta adresi gösterir).
- [ ] Madde 3 yurt dışı aktarım (Firebase, Brevo), madde 5 duyuru e-postası (ticari ileti), madde 10 yaş (<18).
- [ ] Madde 11 Arapça çeviri hukuk incelemesi (yoksa Arapça mağaza metni eklemeyin).
- [ ] Avukat metni değiştirirse: yeni migration + yeni sözleşme sürümü ([LEGAL_NOTES.md](LEGAL_NOTES.md) bölüm 9); **yeniden onay zorlaması** mobil sürüm çıktıktan sonra ([DEPLOY.md](DEPLOY.md) 14.4).

## Aşama 1. Alan adı ve DNS (site: bukampus.com.tr; e-posta gönderen alan adı: bukampus.online)

1. [ ] **SİZ:** alan adı kayıt şirketinde ad sunucularını Cloudflare'e çevirin (Cloudflare hesabı, alan adı ekle, verilen iki NS'i kayıt şirketine girin). Cloudflare "Active" olana dek bekleyin.
2. [ ] **TTL stratejisi:** ilk kurulumda tüm kayıtlar `Auto`/300 sn; VPS IP'sini değiştirme (geçiş, taşıma) olasılığı geçince A kaydını 3600 sn'ye çıkarın. Geçişten en az 24 saat önce TTL'i 300'e indirin (eski TTL kadar beklemek gerekir).
3. [ ] **A/AAAA:** VPS kurulduktan sonra. Örnek (değerler uydurma):

| Tür | Ad | Değer | Bulut | TTL | Not |
|---|---|---|---|---|---|
| A | `@` | `203.0.113.10` (VPS IPv4) | **DNS only (gri)** | 300 | Caddy Let's Encrypt (HTTP-01) için doğrudan sunucuya gelmeli; gri bulutta kalması önerilir |
| AAAA | `@` | VPS IPv6 (varsa) | DNS only | 300 | Yoksa eklemeyin |
| CNAME | `www` | `bukampus.com.tr` | DNS only | 300 | `deploy/Caddyfile.bukampus` + `deploy/compose.bukampus.yml` (`WWW_DOMAIN=www.bukampus.com.tr`) `www` -> apex yönlendirmesini ve sertifikayı sağlar; DNS'te bu kaydın olması yeterli. Kullanmayacaksanız kaydı eklemeyin |

4. [ ] **E-posta kayıtları** (Brevo + Cloudflare Email Routing). Adımlar ve açıklamalar [MAIL_DELIVERABILITY.md](MAIL_DELIVERABILITY.md) 9.1-9.2, 9.5; özet:

| Tür | Ad | Değer | Not |
|---|---|---|---|
| TXT | `@` | `brevo-code:<panelden kopyalayın>` | Brevo alan adı sahipliği |
| CNAME veya TXT | `brevo1._domainkey`, `brevo2._domainkey` | `<panelde yazan tam değer>` | DKIM; **DNS only**; değeri asla uydurmayın/elle yazmayın |
| TXT | `@` (SPF, **tek kayıt**) | `v=spf1 include:spf.brevo.com include:_spf.mx.cloudflare.net ~all` | Email Routing kullanıyorsanız Cloudflare'in include'u da; iki ayrı `v=spf1` kaydı SPF'i bozar. Güncel include adlarını iki sağlayıcının belgesinden doğrulayın |
| MX | `@` (bukampus.online) | Cloudflare Email Routing'in verdiği 3 kayıt | İsteğe bağlı: yalnız `dmarc@bukampus.online` raporlarını Gmail'e almak için (9.5). Routing etkinleştirince Cloudflare ekler. Kullanmazsanız MX ve Cloudflare include'u eklemeyin |
| TXT | `_dmarc` | `v=DMARC1; p=none; rua=mailto:dmarc@bukampus.online` | **bukampus.online** DNS'inde. 2-4 hafta `p=none`, rapor temizse `quarantine`, sonra `reject` ([MAIL_DELIVERABILITY.md](MAIL_DELIVERABILITY.md) bölüm 2 madde 3). `dmarc@` Cloudflare Email Routing ile Gmail'e yönlendirilir (9.5) |

5. [ ] Doğrulama (VPS'ten bağımsız, kendi bilgisayarınızdan): `nslookup -type=TXT bukampus.online`, `nslookup -type=TXT _dmarc.bukampus.online`, `nslookup -type=CNAME brevo1._domainkey.bukampus.online` değerleri döndürmeli; site için `nslookup bukampus.com.tr`. `bukampus.com.tr` posta göndermez: null SPF/DMARC kayıtları [MAIL_DELIVERABILITY.md](MAIL_DELIVERABILITY.md) 9.2.

## Aşama 2. E-posta teslimi (Brevo)

1. [ ] **SİZ:** Brevo hesabı (2 adımlı doğrulama açık), `bukampus.online` alanı ekle, kayıtlar yayılınca "Authenticated/Verified" olana dek bekleyin; gönderici `noreply@bukampus.online` ekle ([MAIL_DELIVERABILITY.md](MAIL_DELIVERABILITY.md) 9.1). SMTP giriş adı ve **SMTP anahtarı** üretin (sır: yalnız `.env.prod`).
2. [ ] **MAIL_FROM değişikliği (dearfuture.info -> bukampus.online):** yerel `.env`'de `MAIL_FROM` ve `MAIL_REPLY_TO` şu an `dearfuture.info` adreslerine ayarlı (repoda yok, yalnız sizin gitignored dosyanızda). Sıra:
   - a) Brevo'da `bukampus.online` doğrulandıktan **sonra** değiştirin (önce değiştirirseniz Brevo gönderimi reddeder, kayıt kodu gitmez).
   - b) `.env` (yerel) ve sunucudaki `.env.prod`: `MAIL_FROM=noreply@bukampus.online`, `MAIL_REPLY_TO=ysufakin23@gmail.com`, `PUBLIC_WEB_URL=https://bukampus.com.tr` (abonelik/takip bağlantıları kökü), `MAIL_DAILY_LIMIT=300`, `MAIL_DAILY_RESERVE=60` ([MAIL_DELIVERABILITY.md](MAIL_DELIVERABILITY.md) 9.3).
   - c) Uygulama: `docker compose -p bu -f docker-compose.prod.yml --env-file .env.prod up -d backend` (yalnız `restart` ortam değişkenini yenilemez; **yeniden oluşturma** gerekir). `ProdSettingsValidator` "From alanı SMTP kullanıcı alanından farklı" uyarısı verir; Brevo için beklenen uyarıdır.
   - d) Eski `dearfuture.info` göndericisini Brevo'dan silmeyin; geçiş doğrulanana kadar yedek kalsın.
3. [ ] **Gönderim sonrası spam testi** (gerçek SMTP ile; yerelde `MAIL_ENABLED=false` iken mümkün değil):
   - [ ] https://www.mail-tester.com'in verdiği tek kullanımlık adrese, **uygulamayla aynı SMTP ve gönderici** ile bir deneme postası yollayın. Uygulama yalnız `bingol.edu.tr` adreslerine kayıt kodu gönderdiği için (kayıt kısıtı) bunu uygulamadan yapamazsınız; sunucuda `swaks` ya da Brevo panelindeki test gönderimi kullanın, örn. (parola komut satırına yazılmasın diye ortamdan): `swaks --to <mail-tester-adresi> --from noreply@bukampus.online --server smtp-relay.brevo.com:587 -tls --auth LOGIN --auth-user "$MAIL_USERNAME" --auth-password "$MAIL_PASSWORD" --header "Subject: BU Kampus test" --body "Merhaba, bu bir deneme postasidir."`. Skor 9+/10; SPF, DKIM, DMARC "pass".
   - [ ] Kendi Gmail'inize gerçek kayıt/şifre sıfırlama kodu yollayın: Gmail > ⋮ > **"Orijinali göster"**: `SPF: PASS`, `DKIM: PASS`, `DMARC: PASS`; spam klasörüne düşmediğini ve `Message-ID`'nin `@bukampus.online` olduğunu doğrulayın.
   - [ ] Bir `bingol.edu.tr` kutusuna (üniversite posta sistemi) kod gönderin: spam/karantina mı? Üniversite filtreleri sertse BT'den `bukampus.online` ve Brevo IP'lerini güvenli listeye alma isteyin ([LEGAL_NOTES.md](LEGAL_NOTES.md) madde 14).
   - [ ] `GET /api/admin/system/overview` > `mail.dailyQuota` artıyor; yönetici paneli > Mail kuyruğu DEAD yok.
   - Ayrıntı ve araç listesi: [MAIL_DELIVERABILITY.md](MAIL_DELIVERABILITY.md) bölüm 6, 9.6.
4. [ ] **Destek adresi:** `ysufakin23@gmail.com` (Reply-To, mağaza iletişim e-postası ve `support_email` ayarı aynı adres; V481 zaten bunu yazar). İsteğe bağlı: `bukampus.online` üzerinde Cloudflare Email Routing ile `dmarc@` -> Gmail ([MAIL_DELIVERABILITY.md](MAIL_DELIVERABILITY.md) 9.5).
5. [ ] **SİZ:** Google Postmaster Tools'a `bukampus.online` ekleyin (ilk haftalarda spam oranı ve alan adı itibarı).

## Aşama 3. VPS ilk kurulum sırası (Ubuntu 24.04)

Önerilen: 2 vCPU / 4 GB RAM / yeterli SSD (veri x4 + yedekler). Ayrıntı ve komutlar [DEPLOY.md](DEPLOY.md) bölüm 0 ve 13; sıra:

1. [ ] **SİZ:** VPS'i kurun (Ubuntu 24.04 LTS), yalnız IP'yi not edin. DNS A kaydını girin (Aşama 1.3); yayılmadan ilk dağıtım yapmayın (Let's Encrypt hız sınırı).
2. [ ] **SSH anahtarı:** yerelde `ssh-keygen -t ed25519`; `ssh-copy-id root@<ip>`; anahtarla girişi **ayrı bir oturumda** deneyin. Bu doğrulanmadan parola girişini kapatmayın.
3. [ ] **Sunucu hazırlığı** (tek betik, tekrar çalıştırılabilir): `git clone <repo> /opt/bu && cd /opt/bu && sudo bash scripts/deploy/bootstrap-server.sh --deploy-user bu` yapar: Docker (resmî depo + Compose eklentisi), **UFW** (yalnız 22, 80, 443/tcp+udp), **fail2ban** (sshd), **otomatik güvenlik güncellemesi** (`unattended-upgrades`, otomatik yeniden başlatma KAPALI), saat dilimi `Europe/Istanbul`, **2 GB swap** (`vm.swappiness=10`), Docker log döndürme.
4. [ ] SSH sertleştirme: `/etc/ssh/sshd_config` içinde `PasswordAuthentication no`, `PermitRootLogin no`; `systemctl reload ssh`. `chown -R bu:bu /opt/bu`; bundan sonra `su - bu`.
5. [ ] **Sırlar:** `bash scripts/ops/gen-secrets.sh` -> `.env.prod` (izin 600). Elle doldurun: `DOMAIN=bukampus.com.tr`, `ACME_EMAIL`, `CORS_ORIGINS=https://bukampus.com.tr`, `PUBLIC_WEB_URL=https://bukampus.com.tr`, `ADMIN_EMAILS` (**en az 2 adres**: tek FULL yöneticide iki kişi onayı kilitlenir, K-31), `MAIL_*` (Aşama 2; **prod `MAIL_ENABLED=false` ile açılmaz**), `BACKUP_AGE_RECIPIENT`. **`.env.prod` ve `CRYPTO_MASTER_KEYS` bu adımda şifre yöneticisine + çevrimdışı kasaya kopyalanır** ([KEY_MANAGEMENT.md](KEY_MANAGEMENT.md)); yedeğe girmez, kaybı şifreli mesajların kalıcı kaybıdır.
6. [ ] **Yedek anahtarları:** çevrimdışı makinede `age-keygen -o kurtarma.age.key` (özel anahtar sunucuya KONMAZ, parola yöneticisi + kasa) ve doğrulama anahtarı; genel anahtarlar `.env.prod`'a; **`BACKUP_REMOTE` (farklı sağlayıcıda/bölgede rclone crypt hedefi) canlıdan önce ZORUNLUDUR** (boşsa yedekler yalnız VPS diskindedir; backend açılışta uyarır) ve `BACKUP_WEBHOOK_URL` doldurulur ([BACKUP_RESTORE.md](BACKUP_RESTORE.md) bölüm 2 ve 11). Anahtar emaneti: `CRYPTO_MASTER_KEYS` ve age özel anahtarı **iki ayrı dosya, iki ayrı yer**; "fiilen okundu" testi [RUNBOOK.md](RUNBOOK.md) bölüm 12 tatbikat günlüğüne işlenir (H-02).
7. [ ] **FCM (isteğe bağlı, sonra):** [PUSH_SETUP.md](PUSH_SETUP.md); boşsa yalnız uygulama içi bildirim.
8. [ ] **İlk dağıtım:** yerelden `bash scripts/deploy.sh --dry-run`, ardından `bash scripts/deploy.sh` (Brevo bilgisi yoksa baştan reddeder; `.env.prod` üretir, derler, başlatır, soğuk açılışı 262-465 sn bekler, ısıtır; sunucu içinde elle çalışılacaksa alternatif `scripts/deploy/update.sh --first`). Sonra `curl -I https://bukampus.com.tr/` (200 + geçerli sertifika), `https://bukampus.com.tr/api/status`, `https://bukampus.com.tr/actuator/health` **404** olmalı.
9. [ ] **Isıtma + duman:** `BASE=https://bukampus.com.tr bash scripts/warmup.sh`, ardından `BASE=https://bukampus.com.tr bash scripts/staging-smoke.sh` ([DEPLOY.md](DEPLOY.md) 14.2).
10. [ ] **İlk yönetici:** `ADMIN_EMAILS`'teki adresle kayıt + doğrulama; panel `https://bukampus.com.tr/admin`. Kayıt kodu e-postası gerçekten gelmeli (Aşama 2 tamam).
11. [ ] **İLK YEDEK ve geri yükleme:** `exec -u postgres backup /opt/backup/backup.sh --dry-run`, sonra elle bir yedek, **uzak kopyada göründüğünü** doğrulayın, `verify-restore.sh --latest` geçsin. İlk canlı verinin üzerine yazmadan önce **staging'de `restore-live.sh`** deneyin ([BACKUP_RESTORE.md](BACKUP_RESTORE.md) bölüm 10: yerel tatbikat betiği `scripts/restore-drill.sh`).
12. [ ] **Güvenlik duvarı doğrulaması** (dışarıdan, kendi bilgisayarınızdan): yalnız 22/80/443 açık olmalı (`nmap -Pn <ip>` ya da çevrimiçi port tarayıcı); 5432/6379/8080 kapalı. (UFW Docker yayınlarını engellemez; compose zaten yalnız Caddy'yi yayınlar: [DEPLOY.md](DEPLOY.md) A4.)
13. [ ] **HARİCİ İZLEME (ZORUNLU, H-03):** uygulama içi uyarı sunucu/backend çökünce ulaşmaz; bu yüzden **sunucudan bağımsız** bir makine/hizmette: (a) UptimeRobot ya da başka makinedeki Uptime Kuma ile `https://bukampus.com.tr/api/status` monitörü (1-2 dk), (b) TLS sertifika süresi monitörü, (c) Healthchecks.io ölü adam anahtarı: her başarılı yedekte ping, 2-3 saat gelmezse e-posta. Ayrıca yönetici paneli > Sistem ([DEPLOY.md](DEPLOY.md) "Harici izleme" ve "Sistem durumu..." bölümleri).
14. [ ] **Tatbikat:** staging'de `update.sh` + `rollback.sh` (üretimde `deploy.sh --rollback`); saat/uyarı zincirini (yedek başarısız -> bildirim) bir kez bozarak deneyin.

### Caddy / TLS / ortam değişkeni özeti

| Ayar | Değer | Not |
|---|---|---|
| `DOMAIN` | `bukampus.com.tr` | Caddy otomatik Let's Encrypt; `caddy_data` volume'unu kaybetmeyin |
| `ACME_EMAIL` | sizin e-postanız | Sertifika bitiş uyarıları |
| `CORS_ORIGINS` | `https://bukampus.com.tr` | `*` ve `localhost` kabul edilmez; web paneli ve site aynı kökende; mobil CORS'tan etkilenmez |
| `PUBLIC_WEB_URL` | `https://bukampus.com.tr` | Destek takip bağlantıları, abonelik bağlantıları ve e-posta içindeki adresler; **https ve herkese açık** olmalı |
| `MAIL_FROM` / `MAIL_REPLY_TO` | `noreply@bukampus.online` / `ysufakin23@gmail.com` | Aşama 2 |
| `LEGAL_ENFORCE_REACCEPT` | **false** (varsayılan) | Yalnız mobil sürüm yayınlandıktan SONRA ([DEPLOY.md](DEPLOY.md) 14.4); `.env.prod`'a yazmak yeter (compose iletir) |
| `BACKUP_REMOTE` / `BACKUP_WEBHOOK_URL` | **dolu** (rclone crypt uzak hedefi / webhook) | Boşsa yedek yalnız VPS diskindedir; backend açılışta uyarır |
| `ADMIN_EMAILS` | **>= 2 adres** | Tek FULL yöneticide iki kişi onayı kilitlenir (K-31) |
| TLS | Let's Encrypt (HTTP-01, 80 açık) | HSTS `deploy/Caddyfile` içinde; sertifika yenileme otomatik |

## Aşama 4. Mobil sürüm ve mağaza

1. [ ] **SİZ:** upload keystore üretimi, `key.properties`, Play Console hesabı ([ANDROID_RELEASE.md](ANDROID_RELEASE.md) bölüm 2 ve 8).
2. [ ] `google-services.json` API anahtarı kısıtlaması ve FCM ([PUSH_SETUP.md](PUSH_SETUP.md) bölüm 6).
3. [ ] Gerçek cihaz testi: [DEVICE_TEST_PLAN.md](DEVICE_TEST_PLAN.md) (T1-T6 ve T8 geçmeden mağazaya gönderilmez).
4. [ ] Mağaza metinleri, Veri güvenliği, içerik derecelendirme, ekran görüntüleri: [store/README.md](store/README.md).
5. [ ] Gizlilik politikası (`https://bukampus.com.tr/tr/privacy`) ve hesap silme (`https://bukampus.com.tr/tr/delete-account`) sayfaları **canlıda açılıyor** (3 dil: `/tr`, `/en`, `/ar`); `staging-smoke.sh` bunları denetler.
6. [ ] Play kapalı test -> (koşullar sağlanınca) üretim; **bu sırada** `LEGAL_ENFORCE_REACCEPT` kapalı.
7. [ ] Yayın sonrası: [DEPLOY.md](DEPLOY.md) 14.4 adımları ve `min_version_android` ayarı.

## Sorumluluk özeti

| SİZ (hesap/ödeme/kimlik/sır) | Hazır (repoda) |
|---|---|
| Cloudflare, Brevo, Play Console, Firebase hesapları; VPS satın alma | Betikler: `bootstrap-server.sh`, `deploy.sh` (üretim), `update.sh`, `rollback.sh`, `restore-live.sh`, `restore-drill.sh`, `warmup.sh`, `staging-smoke.sh` |
| Upload keystore, age kurtarma anahtarı, `.env.prod`, `CRYPTO_MASTER_KEYS` saklama | Belgeler: bu liste, DEPLOY 14, BACKUP_RESTORE 10, DEVICE_TEST_PLAN, store/ |
| Avukat görüşü, VERBİS/KEP kararı, üniversite izni | Sözleşme metinleri (taslak), `LEGAL_NOTES.md` soru listesi |
| Gerçek cihaz testi, ekran görüntüleri, FCM anahtarı | Test planı, çekim yönergesi, push kodu |

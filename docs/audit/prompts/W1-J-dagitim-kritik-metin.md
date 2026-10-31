# W1-J - Dağıtım hattı düzeltmeleri ve KRİTİK metin düzeltmeleri

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 1. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: M (≈1-1.5 gün).

Sen **W1-J** iş akışı ajanısın (Prod compose değişken iletimi, MAIL_ENABLED belge/kod uyumu, deploy.sh yedek ve anahtar dosyası, ProdSettingsValidator uyarıları, Caddy log, KRİTİK metinler (A9-01/02/03)). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: Yok; DEPLOY'DAN ÖNCE tamamlanmalı
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: scripts: `bash -n`, `node scripts/check-workflows.js`, `scripts/ci/compose-ports-check.sh`; backend: ProdSettingsValidatorTest, I18nMessagesIntegrityTest; mobil: l10n_test + ilgili 2 widget testi

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w1j && mkdir -p /c/bu_verify_w1j && git archive HEAD | tar -x -C /c/bu_verify_w1j`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w1j/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w1j/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yalıtılmış yığın (smoke):** temiz kopyada `.env.example` -> `.env` (DB_PASSWORD, JWT_SECRET >=32, ADMIN_PASSWORD, `ADMIN_EMAILS=boss@bingol.edu.tr`, `MAIL_ENABLED=false`, `LEGAL_ENFORCE_REACCEPT=false`), `export COMPOSE_PROJECT_NAME=bu_w1j BACKEND_PORT=18170 WEB_PORT=28170`, `docker compose up -d --build`, `BASE=http://localhost:18170 ADMIN_PASSWORD=... ONLY="smoke-..." bash scripts/smoke-all.sh`; bitince `docker compose down -v`. A7 ortak yığınına (18081) ve `flushall` ile başkalarının verisine DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W1-J: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (11)

#### T-122 - Tüm cihazlardan çıkış metni 'Hesabınız kapatılacak' (hesap silinecek sanılır)  [KRİTİK | kanıt PV]
- **Kaynak bulgular:** A9-01 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil l10n/app_tr.arb:61 settingsLogoutAllBody (+ üretilmiş app_localizations_tr.dart)
- **Düzeltme:** 'Tüm cihazlardaki oturumlarınız kapatılacak ve yeniden giriş yapmanız gerekecek.'; flutter gen-l10n
- **Test gereksinimi:** l10n_test; ARB 3 dil eşitliği

#### T-123 - Şifre sıfırlama yanıtı 'bağlantı' diyor, e-postaya KOD gidiyor  [KRİTİK | kanıt PV]
- **Kaynak bulgular:** A9-02 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** backend i18n/messages.properties:336 msg.forgot.sent (tr)
- **Düzeltme:** 'Hesap uygunsa e-posta adresinize şifre sıfırlama kodu gönderildi.' (i18n kilidi)
- **Test gereksinimi:** I18nMessagesIntegrityTest; POST forgot-password 202 gövdesi

#### T-124 - Marka yazımı: 'BU Kampüs'/'BU KAMPÜS'/'BU Kampus' (karşılama, ana sayfa, ICS takvim adı, sistem uyarı konusu); doğrusu 'BÜ Kampüs'  [KRİTİK | kanıt PV]
- **Kaynak bulgular:** A9-03 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil features/auth/welcome_page.dart:166, features/home/home_parts.dart:498-501 (+home_tab.dart:421 yorum); backend event/extras/IcsService:42, IcsWriter:25 (PRODID teknik kalabilir), academic/IcsBuilder:40, observability/SystemAlertService:111
- **Düzeltme:** Kullanıcıya görünen tüm yerler 'BÜ Kampüs' (takvim adı, ekran, konu satırı); PRODID/log ASCII kalabilir
- **Test gereksinimi:** Widget testi 2 ekran; IcsWriterTest takvim adı; SystemAlertServiceTest konu

#### T-136 - Tek VPS + yedekler aynı sunucuda + sunucu dışı kopya yok (SPOF); saklama 'en yeni 3 saatlik'; BACKUP_REMOTE/BACKUP_WEBHOOK_URL boş  [KRİTİK | kanıt S]
- **Kaynak bulgular:** A8-01, A8-10 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** docker-compose.prod.yml (300-354 backup), .env.prod.example, scripts/deploy.sh (.env.prod üretimi), config/ProdSettingsValidator, docs/BACKUP_RESTORE.md
- **Düzeltme:** KOD (W1-J): prod'da BACKUP_REMOTE boşsa açılışta WARN + yönetici sistem durumunda KIRMIZI; deploy.sh uzak yedek/webhook bilgisi yoksa uyarı verir; BACKUP_KEEP_DAILY 7 / WEEKLY 4 / MONTHLY 3 varsayılanı; İNSAN (H-01): farklı sağlayıcı/bölgede rclone crypt, yalnız-yazma anahtarı, VPS anlık görüntü
- **Test gereksinimi:** ProdSettingsValidatorTest uyarı; backup betiği duman
- **Bağımlılık:** H-01

#### T-137 - Anahtar emanet düzeni (CRYPTO_MASTER_KEYS, age kurtarma anahtarı) doğrulanmamış; deploy.sh ikisini aynı yerel dosyaya yazıyor  [YÜKSEK | kanıt S]
- **Kaynak bulgular:** A8-02 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** scripts/deploy.sh (.deploy/generated-secrets.txt ~285-296), docs/KEY_MANAGEMENT.md bölüm 4, docs/RUNBOOK.md bölüm 12
- **Düzeltme:** KOD (W1-J): deploy.sh age özel anahtarını CRYPTO anahtarlarından AYRI dosyaya yazar; RUNBOOK tatbikat günlüğü şablonu; İNSAN (H-02): iki bağımsız yere yedek + 'fiilen okundu' testi
- **Test gereksinimi:** bash -n + prepare dry-run
- **Bağımlılık:** H-02

#### T-138 - Harici izleme ve uyarı zinciri dağıtılmamış (monitoring/ hiçbir betikte yok; uygulama içi uyarı sunucu çökünce ulaşmaz)  [YÜKSEK | kanıt S]
- **Kaynak bulgular:** A8-03 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** scripts/deploy.sh, monitoring/docker-compose.monitoring.yml, docs/DEPLOY.md (244-248), docs/LAUNCH_CHECKLIST.md (74)
- **Düzeltme:** DOC (W1-J): LAUNCH_CHECKLIST ve DEPLOY'a zorunlu harici izleme adımı (UptimeRobot/Uptime Kuma başka makinede: /api/status + TLS süresi + Healthchecks.io yedek dead-man ping); İNSAN (H-03): kurulum
- **Test gereksinimi:** Belge incelemesi
- **Bağımlılık:** H-03

#### T-144 - Prod compose belgelerde '.env.prod'a yazın' denen ~150 değişkeni konteynere İLETMİYOR (LEGAL_ENFORCE_REACCEPT, FCM_CREDENTIALS_FILE, DB_POOL_*, OBS_ALERT_*, BLOCK_ANONYMIZERS, BAN_*, PUSH_*, CHAT_*, MEDIA_*...)  [YÜKSEK | kanıt SV]
- **Kaynak bulgular:** A17-02, A17-12, A17-23 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** docker-compose.prod.yml (111-176 environment), docs/DEPLOY.md, .env.example, .env.prod.example, docs/PUSH_SETUP.md
- **Düzeltme:** backend servisine env_file: .env.prod ekle (veya belgelenen değişkenleri tek tek ${X:-} ile ilet; en azından LEGAL_ENFORCE_REACCEPT, FCM_CREDENTIALS_FILE, DB_POOL_*, OBS_ALERT_*, BLOCK_ANONYMIZERS, BAN_*); örnek dosyalara eksik anahtarlar (CACHE_ENABLED, DEVICE_HMAC_KEY, MAIL_UNSUBSCRIBE_KEY, SENTRY_DSN, ADMIN_BASIC_ENABLED, MAIL_SSL...); CLAUDE.md ortam değişkeni listesi; DEPLOY.md 'yalnız compose'ta listelenenler iletilir' notu
- **Test gereksinimi:** scripts/ci/compose-ports-check.sh + yeni 'compose config' değişken iletimi kontrolü; staging'de LEGAL_ENFORCE_REACCEPT=true geçiş denemesi
- **Bağımlılık:** DEPLOY ÖNCESİ ZORUNLU

#### T-145 - Prod'da MAIL_ENABLED=false 'uyarı, kodlar log'a yazılır' diye belgelenmiş ama ProdSettingsValidator uygulamayı BAŞLATMAZ (allow-log-only compose'a iletilmiyor)  [YÜKSEK | kanıt SV]
- **Kaynak bulgular:** A17-01 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** docs/DEPLOY.md (66-70,143), docs/DEPLOY_SCRIPT.md Sırlar, scripts/deploy.sh (18, 295), config/ProdSettingsValidator (102-109), docker-compose.prod.yml
- **Düzeltme:** DEPLOY.md bölüm 2 'Uyarı' listesinden çıkar → 'HATA (allow-log-only olmadan açılmaz)'; deploy.sh Brevo bilgisi yoksa dağıtımı baştan reddeder (veya bilinçli APP_MAIL_ALLOW_LOG_ONLY=true iletir); başlık/uyarı metinleri düzelt
- **Test gereksinimi:** deploy.sh --dry-run mail bilgisi yok senaryosu; bash -n
- **Bağımlılık:** DEPLOY ÖNCESİ ZORUNLU

#### T-146 - DEPLOY.md hâlâ update.sh yolunu 'önerilen' anlatıyor, fiilî yol scripts/deploy.sh; deploy.sh dağıtım öncesi yedek almıyor; -h çıktısı kesik; açılış 262-465 sn iken update.sh bekleme süresi 240  [YÜKSEK | kanıt S]
- **Kaynak bulgular:** A17-03, A8-09, A17-20, A7-15 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** docs/DEPLOY.md (7-24,146-158,259+), docs/DEPLOY_SCRIPT.md, scripts/deploy.sh (44 sed 2,23p; yedek adımı yok), scripts/deploy/update.sh (62-66,84)
- **Düzeltme:** DEPLOY.md bölüm 0/14.2'ye 'üretimde scripts/deploy.sh' ve --ref/--dry-run/--rollback; deploy.sh'a backup.sh çağrısı (başarısızsa dur) + bekleyen migration uyarısı; sed -n 2,28p; --ref/--skip-warmup/--skip-cleanup belgele; start_period / wait_healthy süresi yapılandırılabilir
- **Test gereksinimi:** bash -n; deploy.sh --dry-run

#### T-147 - Kenar (Caddy) katmanında hız sınırı/WAF yok; erişim günlüğünde tam URI (support/track?token= dahil), saklama süresi tanımsız; CSP connect-src geniş, HSTS preload  [ORTA | kanıt S]
- **Kaynak bulgular:** A8-23, A8-27 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** deploy/Caddyfile (log, header), web/nginx-security.conf
- **Düzeltme:** Caddy log filter: sorgu dizisinden token sil; connect-src 'self' wss://bukampus.com.tr; günlük saklama süresi belge+gizlilik metniyle eşle; Cloudflare/WAF önerisi K-29 (İNSAN)
- **Test gereksinimi:** caddy validate; web CSP E2E
- **Bağımlılık:** K-29
- **KARAR (varsayılan = ÖNERİ):** K-29 Kenar koruması (Cloudflare/WAF) | Seçenekler: (a) Yok; (b) Cloudflare proxy + rate limiting; (c) caddy-ratelimit | ÖNERİ: (b) (DNS zaten planlı).

#### T-153 - Prod'da tek sabit FULL yönetici: ikinci FULL panelden yaratılamaz (iki kişi onayı kilitlenir)  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A14-17 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** config/ProdSettingsValidator, docs/DEPLOY.md, scripts/smoke-admin-rbac.sh
- **Düzeltme:** ADMIN_EMAILS en az 2 adres değilse açılışta WARN; DEPLOY.md notu (K-31)
- **Test gereksinimi:** ProdSettingsValidatorTest
- **Bağımlılık:** K-31
- **KARAR (varsayılan = ÖNERİ):** K-31 Prod ADMIN_EMAILS ≥2 ve Sentry | Seçenekler: (a)/(b) | ÖNERİ: ADMIN_EMAILS en az 2 adres (validator WARN); Sentry kullanılmasın (DSN boş), kullanılacaksa AB bölgesi + send-default-pii=false + tedarikçi listesi.

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- docker-compose.prod.yml, docker-compose.yml (yalnız env iletimi), scripts/deploy.sh, scripts/deploy/**, deploy/Caddyfile, .env.example, .env.prod.example
- docs/DEPLOY.md, docs/DEPLOY_SCRIPT.md, docs/LAUNCH_CHECKLIST.md, docs/RUNBOOK.md (tatbikat şablonu), docs/BACKUP_RESTORE.md (ilgili bölümler)
- backend config/ProdSettingsValidator.java (+test)
- observability/SystemAlertService.java (yalnız e-posta konusu), event/extras/IcsService.java, IcsWriter.java, academic/IcsBuilder.java (yalnız kullanıcıya görünen takvim adı)
- i18n/messages*.properties (YALNIZ msg.forgot.sent satırı; kilit: i18n-messages)
- mobile/lib/features/auth/welcome_page.dart, mobile/lib/features/home/home_parts.dart (marka yazımı)
- mobile/lib/l10n/app_tr.arb satır 61 (YALNIZ settingsLogoutAllBody; kilit: arb; önek yok - mevcut anahtar)

**Dokunmayacakların (başka iş akışının):**
- CLAUDE.md (W3-D'nin; ortam değişkenleri listesini docs/DEPLOY.md ve .env örneklerine yaz), diğer tüm uygulama kodu

Paylaşılan dosya kilitleri: arb, i18n-messages, docs-shared. Flyway aralığın: **-**, indeks öneki **-**. Mobil l10n öneki: **yok (yalnız mevcut anahtar metni)**.
Yalıtılmış yığın portların: BACKEND_PORT=18170, WEB_PORT=28170, COMPOSE_PROJECT_NAME=bu_w1j.

## 4. ÖZEL TALİMATLAR

Prod'a HİÇ bağlanma; dağıtım betiklerini yalnız --dry-run ve bash -n ile doğrula. Compose değişikliği: backend servisine `env_file: .env.prod` TERCİH EDİLİR ama gizli değerlerin `docker inspect` ile sızmasını ve .env.prod'daki yorum/boşluk biçimini düşün; alternatif: eksik değişkenleri tek tek `${X:-}` ile ilet. Her iki yolda da `docker compose -f docker-compose.prod.yml config` ile doğrula (sırlar maskeli). ProdSettingsValidator yeni UYARILAR (hata değil): BACKUP_REMOTE boş, ADMIN_EMAILS <2 adres (K-31), SENTRY_DSN dolu; mevcut hata kuralları DEĞİŞMEZ. A9-03: yalnız kullanıcıya görünen metin (ICS X-WR-CALNAME, ekran, konu satırı); PRODID ve log ASCII kalır. İNSAN eylemleri (H-01..H-05) için kod yazma; yalnız belge/uyarı.

## 5. TEST ve DOĞRULAMA

- scripts: `bash -n`, `node scripts/check-workflows.js`, `scripts/ci/compose-ports-check.sh`; backend: ProdSettingsValidatorTest, I18nMessagesIntegrityTest; mobil: l10n_test + ilgili 2 widget testi
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- docker compose -f docker-compose.prod.yml config çıktısında belgelenen değişkenler backend environment'ında görünür (LEGAL_ENFORCE_REACCEPT, FCM_CREDENTIALS_FILE, DB_POOL_*, OBS_ALERT_*, BLOCK_ANONYMIZERS, BAN_*)
- deploy.sh --dry-run: Brevo bilgisi yoksa baştan red; yedek adımı var
- DEPLOY.md bölüm 0/2/14.2 gerçek akışı anlatır
- A9-01/02/03 düzeltmeleri testli
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.

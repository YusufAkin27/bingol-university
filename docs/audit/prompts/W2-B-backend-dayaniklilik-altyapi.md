# W2-B - Backend dayanıklılık ve altyapı sertleştirme

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 2. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: M.

Sen **W2-B** iş akışı ajanısın (FCM timeout/scheduler havuzu/scraper bütçesi, küçük performans, imaj sabitleme+tarama, DB rolleri, Redis parolası). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: W2-C ile FirebaseFcmSender çakışmasın: bu akışta yalnız zaman aşımı ayarı
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar; workflow YAML (check-workflows.js)

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w2b && mkdir -p /c/bu_verify_w2b && git archive HEAD | tar -x -C /c/bu_verify_w2b`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w2b/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w2b/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yalıtılmış yığın (smoke):** temiz kopyada `.env.example` -> `.env` (DB_PASSWORD, JWT_SECRET >=32, ADMIN_PASSWORD, `ADMIN_EMAILS=boss@bingol.edu.tr`, `MAIL_ENABLED=false`, `LEGAL_ENFORCE_REACCEPT=false`), `export COMPOSE_PROJECT_NAME=bu_w2b BACKEND_PORT=18220 WEB_PORT=28220`, `docker compose up -d --build`, `BASE=http://localhost:18220 ADMIN_PASSWORD=... ONLY="smoke-..." bash scripts/smoke-all.sh`; bitince `docker compose down -v`. A7 ortak yığınına (18081) ve `flushall` ile başkalarının verisine DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W2-B: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (5)

#### T-074 - FCM istemcisinde bağlantı/okuma zaman aşımı yok; push zamanlayıcıyı bloke eder; @Scheduled işler 2 iş parçacıklı WebSocket broker havuzunu paylaşıyor; scraper toplam süre bütçesi yok  [ORTA | kanıt PT]
- **Kaynak bulgular:** A2-10, A2-11, A2-18 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** notification/fcm/FirebaseFcmSender (41), notification/outbox/PushOutboxWorker (60,112-115), application.properties (spring.task.scheduling.pool.size), news/NewsScraper+NewsSyncService, menu/MenuScraper
- **Düzeltme:** setConnectTimeout(5000)/setReadTimeout(10000), invokeAll(…,30s), push ayrı yürütücü; scheduling.pool.size=8 veya SchedulingConfigurer; scraper iş başına 5 dk bütçe aşılırsa markMaintenance
- **Test gereksinimi:** İş parçacığı dökümü sched-* ; PushOutboxWorkerTest zaman aşımı

#### T-148 - İmajlar kayan etiketli (caddy:2, postgres:16, redis:7, temurin:17, node:22, nginx:1.27); CVE/imaj taraması yok; ffmpeg sürümü sabit değil; imajlar sunucuda derleniyor  [ORTA | kanıt S]
- **Kaynak bulgular:** A8-11, A8-32 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** docker-compose.prod.yml, backend/Dockerfile, web/Dockerfile, .github/workflows/*, dependabot.yml
- **Düzeltme:** Küçük sürüme ve zamanla özete (sha256 özeti) sabitle; Dependabot docker ekosistemi; CI'ya SHA'lı trivy-action; CI imajını sha-<commit> ile çekme (derleme sunucudan çıksın)
- **Test gereksinimi:** CI yeşil; workflow YAML geçerli (scripts/check-workflows.js)

#### T-149 - Uygulama PostgreSQL süper kullanıcısıyla bağlanıyor (Flyway ile aynı hesap)  [ORTA | kanıt S]
- **Kaynak bulgular:** A8-12 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** docker-compose.prod.yml (259-261, 114), Flyway yapılandırması, backup rolü
- **Düzeltme:** bingol_owner (Flyway/DDL) + bingol_app (yalnız DML, süper değil, rol düzeyi statement_timeout) + salt-okunur bingol_backup; önce staging (K-28)
- **Test gereksinimi:** Staging'de migration + smoke-all
- **Bağımlılık:** K-28
- **KARAR (varsayılan = ÖNERİ):** K-28 Veritabanı rol ayrımı | Seçenekler: (a) Mevcut; (b) owner/app/backup rolleri | ÖNERİ: (b) önce staging; prod'a yayın sonrası bakım penceresinde.

#### T-075 - Backend performans küçükleri: PostRank tam yeniden yazım, C1 geçersiz kılma Redis kesintisinde kayıp, istek başı Redis komut sayısı/presence 2 SET, depolama raporu dakikada bir, sohbet listesi tüm üyeleri yükler, /api/faculties önbelleksiz, log gürültüsü  [DÜŞÜK | kanıt PT]
- **Kaynak bulgular:** A2-14, A2-15, A2-16, A2-17, A2-19, A7-10, A7-12 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** post/PostRankService, common/cache/CacheService, common/RateLimiter, messaging/ws/PresenceService.refreshLocal, observability/StorageUsageService, messaging/ConversationService (450), profile/ProfileController /api/faculties, logging yapılandırması
- **Düzeltme:** Eşik üstü değişen satırlar; pendingInvalidate telafisi; RateLimiter tek Lua/INCR sonrası getExpire n==1; presence pipeline + lastseen kapanışta; rapor TTL 5 dk; grup odalarında count projeksiyonu; faculties Cache-Control public; hibernate JDBC error ve STOMP hata seviyesi
- **Test gereksinimi:** Madde başına ölçüm/birim testi

#### T-150 - Redis parolasız; backup servisi hem internal hem edge ağında  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A8-26 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** docker-compose.prod.yml (287), spring.data.redis.password, backup ağı
- **Düzeltme:** --requirepass + REDIS_PASSWORD; backup edge ağından ayrı çıkış
- **Test gereksinimi:** ProdSettingsValidatorTest; staging
- **Bağımlılık:** T-003

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- notification/fcm/FirebaseFcmSender.java, notification/outbox/PushOutboxWorker.java, application*.properties (scheduling.pool), news/*Scraper*, menu/MenuScraper, common/cache/CacheService, common/RateLimiter, messaging/ws/PresenceService.refreshLocal, observability/StorageUsageService, profile/ProfileController (/api/faculties)
- Dockerfile'lar, docker-compose.prod.yml, .github/workflows/*, dependabot.yml

**Dokunmayacakların (başka iş akışının):**
- W2-C push mantığı (PushDispatcher, PushMessages, kampanya)

Paylaşılan dosya kilitleri: app-props, docs-shared. Flyway aralığın: **V970-V974**, indeks öneki **ops9_**. Mobil l10n öneki: **-**.
Yalıtılmış yığın portların: BACKEND_PORT=18220, WEB_PORT=28220, COMPOSE_PROJECT_NAME=bu_w2b.

## 4. ÖZEL TALİMATLAR

T-149 ve T-150 yalnız K-28/K-31 onayından sonra uygulanır; önce staging.

## 5. TEST ve DOĞRULAMA

- backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar; workflow YAML (check-workflows.js)
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- İş parçacığı dökümünde sched-* havuzu
- CI yeşil + trivy adımı
- staging'de rol ayrımı kanıtı (K-28 onaylıysa)
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.

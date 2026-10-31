# W3-F - Backend DÜŞÜK paketi

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 3. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: L.

Sen **W3-F** iş akışı ajanısın (Mesajlaşma/alan/güvenlik/küçük hatalar, CSV tekrar, PII/yaş kararları). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: K-17, K-18, K-26
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w3f && mkdir -p /c/bu_verify_w3f && git archive HEAD | tar -x -C /c/bu_verify_w3f`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w3f/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w3f/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yalıtılmış yığın (smoke):** temiz kopyada `.env.example` -> `.env` (DB_PASSWORD, JWT_SECRET >=32, ADMIN_PASSWORD, `ADMIN_EMAILS=boss@bingol.edu.tr`, `MAIL_ENABLED=false`, `LEGAL_ENFORCE_REACCEPT=false`), `export COMPOSE_PROJECT_NAME=bu_w3f BACKEND_PORT=18330 WEB_PORT=28330`, `docker compose up -d --build`, `BASE=http://localhost:18330 ADMIN_PASSWORD=... ONLY="smoke-..." bash scripts/smoke-all.sh`; bitince `docker compose down -v`. A7 ortak yığınına (18081) ve `flushall` ile başkalarının verisine DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W3-F: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (8)

#### T-039 - Mesajlaşma/oturum küçükleri: clientId kota harcaması, örtük okundu, kapalı sohbette düzenleme, push önizleme vekil çifti, imzalı URL TTL, FCM token URL'de, null eleman 500, WS 16 KB, view-once/silme saklama notları  [DÜŞÜK | kanıt PS]
- **Kaynak bulgular:** A10-14, A10-15, A10-17, A10-18, A10-21, A10-22, A10-23, A10-24, A10-25, A10-26, A1-24, A1-29, A1-37 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** messaging/MessageService.send/persist (276,281,367), MessageActionService.access, media/MediaUrlSigner, ClientStateController+NotificationController+DeviceService (token body), ConversationService (null eleman)
- **Düzeltme:** Kota artışı yalnız gerçek insert; markConversationRead; kapalı sohbette 409 CONVERSATION_CLOSED; push kesmesi kod noktası; silinince imza anahtarı/TTL 60 sn; FCM token gövdede + logda maskele; null eleman 400
- **Test gereksinimi:** İlgili birim testleri; smoke-messaging

#### T-056 - Alan mantığı küçükleri: dönem silme hayalet ders, anket güncelle/oy yarışı, duyuru günlük sınır yarışı, bitmiş etkinlikte RSVP iptali, toplu bildirim alt türü, süren sınav listeden düşer, katılım sorusu yanıtı, kapak oranı, erken sertifika; silinmiş kulüpte yetki devamı; etkinlik spam sınırı  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A12-11, A12-12, A12-13, A12-15, A12-18, A12-20, A12-21, A12-22, A12-23, A1-34, A1-35 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** academic/TimetableService.deleteSemester, poll/PollService.update, event/extras/AnnouncementService.send, EventService.cancelRsvp, NotificationRepository.insertForAll, ExamService.upcoming, ClubJoinFormService.setQuestions, CommunityService.setCover/setLogo, CertificateService.issue, ClubRoleService/ClubOwnershipService/ClubInviteService, EventAdmissionHooks.beforeCreate
- **Düzeltme:** Her madde için hedefli düzeltme (ayrıntı rapor satırları): dönem silinirken dersler onaylı silinir; update'te COUNT(poll_ballot); sayaç atomik; endsAt sonrası 409 EVENT_ENDED; subtype yaz; starts_at>=now-3h; metin değişince yanıtları sil; DELETED/HIDDEN kulüpte işlem reddi; EventAdmissionHooks.beforeCreate bağla; sertifika zamanı K-18
- **Test gereksinimi:** Madde başına birim testi
- **KARAR (varsayılan = ÖNERİ):** K-18 Sertifika verme zamanı | Seçenekler: (a) Mevcut; (b) etkinlik bitişinden sonra | ÖNERİ: (b).

#### T-066 - Metinde PII (telefon/IBAN/TC) filtresi yok; görsel moderasyon yok; kriz yönlendirmesi ve yaş beyanı yok; 18+ ↔ <18 temsilci tutarsızlığı  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A16-14, A16-15, A16-16, A8-18 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** moderation ContentGuard, ContentBlocklist, kayıt akışı, docs/store/data_safety.md, terms madde 4
- **Düzeltme:** K-17/K-26 kararlarına göre: PII uyarısı/maskeleme; yeni hesap ilk 3 gönderi inceleme bayrağı; raporlama ekranında 112/PDR notu; kayıtta 18+ beyanı
- **Test gereksinimi:** ContentGuard PII testleri
- **Bağımlılık:** K-17,K-26
- **KARAR (varsayılan = ÖNERİ):** K-17 Yaş beyanı | Seçenekler: (a) Kayıtta '18 yaşından büyüğüm / yasal temsilci iznim var' onayı; (b) 18 yaş altı yasak | ÖNERİ: (a) + Play hedef kitle 18+ ile hukukçu onayı.
- **KARAR (varsayılan = ÖNERİ):** K-26 Görsel moderasyon seviyesi | Seçenekler: (a) Risk kabulü + belge; (b) yeni hesap ilk 3 gönderi incelemeli; (c) pHash/NSFW sağlayıcı | ÖNERİ: (a)+(b) şimdi (docs/MODERATION.md'ye risk kabulü), (c) yayın sonrası.

#### T-067 - Tek IP ile kayıt/kod posta bütçesi tüketilebilir (IP başına günde 3000 kod isteği)  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A16-19 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mail/MailService.requireCodeQuota
- **Düzeltme:** IP başına günlük kod isteğini 300'e indir (kampüs NAT'ı yapılandırılabilir); doluluk uyarısı SystemAlertService
- **Test gereksinimi:** Limit testi

#### T-154 - Altyapı küçükleri: gizli yönetim yolu güvenlik değil, SECURITY.md/security.txt iletişim, google-services.json API anahtarı kısıtı, Caddy bakım yanıtı, rotasyon günlükleri  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A8-28, A8-29, A8-30, A8-31 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** web/Dockerfile (VITE_ADMIN_PATH), SECURITY.md, web/public/.well-known/security.txt, deploy/Caddyfile (handle_errors), docs/RUNBOOK.md
- **Düzeltme:** security.txt Contact: mailto; Caddy handle_errors 502/503 → JSON MAINTENANCE + Retry-After; İNSAN (H-07): API anahtarı paket+SHA-1 kısıtı; admin arayüzüne IP/Cloudflare Access
- **Test gereksinimi:** -
- **Bağımlılık:** H-07

#### T-164 - Backend küçükleri: kcal ondalık sessiz kırpılıyor, toplu kalori geçersiz tarih tüm isteği reddediyor (belge: gevşek), arama QUERY_TOO_SHORT tutarsız, HEAD → 401, log pattern requestId, anonim /api/hello, rate limit reddedilen isteği sayıyor, merkezî hata zarfı artıkları  [DÜŞÜK | kanıt P]
- **Kaynak bulgular:** A7-04, A7-05, A7-06, A7-11, A14-15, A14-16, A1-38 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** menu/dto/MenuCalorieDtos (Integer kcal), MenuCalorieService.applyBulk (76-89), search/SearchQuery+SearchService, config/SecurityConfig (116,127 HEAD), logging.pattern.console, health/HelloController, data-retention purge limiter
- **Düzeltme:** ACCEPT_FLOAT_AS_INT=false/Number kontrolü; satır bazlı skipped(DATE_INVALID); QUERY_TOO_SHORT; requestMatchers GET+HEAD; %X{requestId}; boş items için ayrı hata kodu; purge limitinde yalnız başarılı/geçerli istek say + Retry-After
- **Test gereksinimi:** Birim/entegrasyon testleri; smoke-menu-calories

#### T-165 - Güvenlik tasarım notları: JWT iss/aud ve email claim, suspended TTL'siz, logout limitsiz; Basic auth kullanıcı adı kilitleme; RateLimiter taşma kovası; çıkış sonrası access 15 dk; cihaz/GPS notları  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A1-30, A1-31, A1-39, A11-13 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** auth/jwt/JwtService, config/BasicAuthThrottleFilter, common/RateLimiter, AuthController.logout
- **Düzeltme:** iss/aud ekle (geriye uyumlu geçiş), logout limiter, sid bazlı iptal değerlendir, taşma kovası belgesi; Basic sayacı IP+kullanıcı adı
- **Test gereksinimi:** JwtServiceTest; BasicAuthThrottleFilterTest

#### T-166 - CSV hücre kaçışı 4 kopya (Csv, AttendanceService, ProfanityAdminController, PollAdminService): CSV enjeksiyonu kuralı tek yerde değil  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A18-K1 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** admin/Csv.java (kanonik), event/AttendanceService (~202), moderation/profanity/ProfanityAdminController (~229), poll/PollAdminService (~162)
- **Düzeltme:** Tümü Csv.cell/row'a; davranış farkı testle sabitlenir (formül ön ekleri = + - @ TAB CR)
- **Test gereksinimi:** CsvTest + her export için enjeksiyon testi

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- T listesindeki dosyalar

**Dokunmayacakların (başka iş akışının):**
- mobil, web

Paylaşılan dosya kilitleri: i18n-messages. Flyway aralığın: **V1000-V1009**, indeks öneki **lowb_**. Mobil l10n öneki: **-**.
Yalıtılmış yığın portların: BACKEND_PORT=18330, WEB_PORT=28330, COMPOSE_PROJECT_NAME=bu_w3f.

## 4. ÖZEL TALİMATLAR

Kartlardaki 'Düzeltme' satırları yeterlidir; karar bekleyen (K-xx) maddelerde ÖNERİ varsayılanını uygula ve raporda belirt. Dosya sahipliği çakışması görürsen DUR ve raporla.

## 5. TEST ve DOĞRULAMA

- backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- her T testli
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.

# W1-A - Backend: kimlik, oturum, hesap yaşam döngüsü, hata zarfı

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 1. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: L (≈2 gün).

Sen **W1-A** iş akışı ajanısın (Kayıtta ad politikası, yönetici kendini silme, Redis devre kesici, hata zarfı/Basic 401, parola politikası, kilit DoS, refresh idempotansı, oturum iptalinde FCM cihaz silme). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: Yok (Dalga 1 başlangıcı)
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w1a && mkdir -p /c/bu_verify_w1a && git archive HEAD | tar -x -C /c/bu_verify_w1a`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w1a/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w1a/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yalıtılmış yığın (smoke):** temiz kopyada `.env.example` -> `.env` (DB_PASSWORD, JWT_SECRET >=32, ADMIN_PASSWORD, `ADMIN_EMAILS=boss@bingol.edu.tr`, `MAIL_ENABLED=false`, `LEGAL_ENFORCE_REACCEPT=false`), `export COMPOSE_PROJECT_NAME=bu_w1a BACKEND_PORT=18110 WEB_PORT=28110`, `docker compose up -d --build`, `BASE=http://localhost:18110 ADMIN_PASSWORD=... ONLY="smoke-..." bash scripts/smoke-all.sh`; bitince `docker compose down -v`. A7 ortak yığınına (18081) ve `flushall` ile başkalarının verisine DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W1-A: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 1b. SÖZLEŞMELER (aynı dalgada paralel çalışan akışlarla; alan/davranış adlarını DEĞİŞTİRME)

- **C7** (W1-A <-> W1-G): Sunucu refresh idempotansı (T-007) ve mobil oturum nesli (T-084) birbirinden bağımsız; ikisi de gerekli.

## 2. KAPSAM - T maddeleri (9)

#### T-001 - Kayıtta görünen ad politikası (DisplayNamePolicy) atlanıyor; e-posta yerel kısmında % ve ardışık nokta kabul  [YÜKSEK | kanıt PV]
- **Kaynak bulgular:** A16-01, A11-03, A11-08 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** backend auth/AuthService.register (154-158), auth/AccountCreator, profile/naming/DisplayNamePolicy; mobil core/identifier.dart regex (W3-G)
- **Düzeltme:** register içinde DisplayNamePolicy.normalize (ADMIN_EMAILS muaf, kod gönderiminden ÖNCE), en az 2 karakter; yerel kısım regex: ardışık nokta ve % yasak; mevcut ihlalli adlar için yalnız-okuma admin sorgusu/rapor (silme yok)
- **Test gereksinimi:** AuthServiceTest: Rektörlük Duyuru, Admin Destek, ZWSP+RLO, <script>, bit.ly adlı kayıt 400; a%evil.com@bingol.edu.tr 400; smoke.sh/smoke-student-number.sh güncelle

#### T-002 - Yönetici DELETE /api/users/me ile kendini siler (son yönetici korunmuyor); silmede oturum iptali ve rol temizliği yok  [YÜKSEK | kanıt PV]
- **Kaynak bulgular:** A11-01, A1-23, A11-09 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** profile/ProfileService.deleteAccount/anonymize, profile/ProfileController; referans admin/AdminUserService.delete
- **Düzeltme:** role==ADMIN ise 409 ADMIN_CANNOT_SELF_DELETE (önce rol devri) veya requireAnotherAdmin; ADMIN_EMAILS/pinned için ek koruma; anonimleştirmede role=USER, adminProfile=null; sonunda sessions.revokeAll(id)
- **Test gereksinimi:** ProfileServiceTest: tek/çok yöneticili senaryo; silme sonrası eski refresh 401 ve rtu:<id> temiz; smoke-admin güncelle

#### T-003 - Redis kesilince kimlikli tüm istekler 2 sn sonra 500; Tomcat iş parçacıkları tükeniyor; Redis zaman aşımı yalnız prod profilinde  [YÜKSEK | kanıt P]
- **Kaynak bulgular:** A2-03, A2-13 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** auth/jwt/JwtAuthFilter.check, common/RateLimiter, analytics/ActivityTracker, application.properties (spring.data.redis.timeout)
- **Düzeltme:** İlk Redis hatasında redisDownUntil=now+5sn devre kesici: bu aralıkta Redis'e gitmeden 503 REDIS_UNAVAILABLE + Retry-After:5 (ApiAuthenticationEntryPoint zinciri); komut zaman aşımı 500 ms; zaman aşımlarını application.properties'e taşı (prod yalnız ezer); fail-closed güvenlik tercihi korunur
- **Test gereksinimi:** Birim: Redis hata fırlatan sahte template ile JwtAuthFilter 503; QA yığınında docker stop redis altında 250 eşzamanlı istek <1 sn 503 ve /api/news 200

#### T-004 - Standart hata zarfı yok: /api/admin 401 yanıtı WWW-Authenticate: Basic taşıyor (panel donuyor); 403/404/405/415 çerçeve hataları code'suz; Content-Language/Vary yok  [YÜKSEK | kanıt P]
- **Kaynak bulgular:** A14-06, A7-03, A11-16, A9-29 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** config/SecurityConfig, common/ApiAuthenticationEntryPoint, AccessDeniedHandler, yeni ErrorController/ResponseEntityExceptionHandler, common/ApiExceptionHandler (catch-all 500+traceId)
- **Düzeltme:** Bearer/JSON isteklerinde Basic entry point kapalı, WWW-Authenticate yalnız başlıksız isteğe; 401/403/404/405/415/400 hepsi {code,message,traceId}; kimlikli 403 FORBIDDEN yerelleştirilmiş; Content-Language ve Vary: Accept-Language; yakalanmamış Exception → 500 + traceId; Tomcat HTML hata sayfası maskele
- **Test gereksinimi:** MockMvc: bozuk Bearer admin yolu 401 başlıksız+code; DELETE /api/news 405 zarflı; web client.test.ts 401→refresh akışı; smoke-admin

#### T-005 - Parola politikası yok (yalnız 8-72 karakter): 12345678, password kabul  [ORTA | kanıt P]
- **Kaynak bulgular:** A1-19, A11-04 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** auth/dto/RegisterRequest, ResetPasswordRequest, ChangePasswordRequest, AuthService; mobil kayıt ekranı göstergesi (W3-G)
- **Düzeltme:** PasswordPolicy: yaygın parola listesi (ilk 10k, kaynak dosya), e-posta/ad/okul numarası içermeme; hata PASSWORD_TOO_WEAK (3 dilde); yönetici hesaplarında uzunluk sertliği K-09 kararına göre
- **Test gereksinimi:** AuthServiceTest: 12345678, password1, <okul no> kayıt/reset/change 400 PASSWORD_TOO_WEAK; geçerli parola 200
- **KARAR (varsayılan = ÖNERİ):** K-09 Parola politikası sertliği | Seçenekler: (a) 8 karakter + yaygın liste; (b) 10 karakter + yaygın liste + kişisel veri içermeme; (c) karakter sınıfı zorunluluğu | ÖNERİ: (b) ve yöneticiler için 12 karakter. Karakter sınıfı zorunluluğu (NIST) gereksiz; yaygın-parola listesi (10k) + e-posta/okul numarası/ad içermeme yeterli. Mobilde anlık gösterge.

#### T-006 - Hesap kilidi kastı: NAT/sahte X-Device-Id ile hedefli giriş kilidi; kod kilidi yeni kodla açılmıyor  [ORTA | kanıt P]
- **Kaynak bulgular:** A1-20, A11-05 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** auth/LoginThrottle, auth/AuthController.login, auth/token/VerificationService.issue
- **Düzeltme:** Kilit yerine artan gecikme; hesap geneli tavan yalnız bilinmeyen cihaz/IP için, son başarılı giriş cihazları muaf; issue() kapsamlı (ns:sc:<email>:<ip>) sayaç/kilit anahtarlarını da sıfırlar (kümeye yaz); Retry-After metni doğru
- **Test gereksinimi:** LoginThrottleTest: 31 yanlış farklı cihaz sonrası gerçek sahip giriş; VerificationServiceTest: 5 yanlış + yeni kod + doğru kod 200

#### T-007 - Kaybolan refresh yanıtı sonrası yeniden deneme TÜM cihazlardaki oturumları kapatıyor (sunucu tarafı)  [ORTA | kanıt P]
- **Kaynak bulgular:** A11-06 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** auth/AuthService.refresh (379-395), auth/token/RefreshTokenService (detectReuse, reuseGrace=10sn)
- **Düzeltme:** Tüketimde rtnext:<oldhash> (30-60 sn TTL, şifreli) yeni çifti sakla; aynı eski token tekrar gelirse AYNI çifti döndür; revokeAll yalnız pencere dışı yeniden kullanımda
- **Test gereksinimi:** RefreshTokenServiceTest: yanıt kaybı simülasyonu 10sn içinde/sonrası; çalıntı yeniden kullanım hâlâ tüm oturumları kapatır
- **Bağımlılık:** mobil taraf: T-084

#### T-008 - Oturum iptalinde (logout-all, şifre değişimi/sıfırlama) FCM cihaz kaydı silinmiyor; kilit ekranında mesaj bildirimi sürüyor  [ORTA | kanıt PV]
- **Kaynak bulgular:** A1-14, A13-02 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** notification/SessionDeviceCleaner.onSessionsRevoked, auth/token/SessionService.revokeAll, SessionDeviceCleanerTest
- **Düzeltme:** client==null && !newLogin olayında devices.deleteAllByUser(userId); test beklentisini tersine çevir (aktif cihaz girişten sonra kendini yeniden kaydeder)
- **Test gereksinimi:** SessionDeviceCleanerTest güncelle; QA: 2 cihaz kaydı → logout-all → device 0

#### T-009 - Kimlik küçükleri: askı→SESSION_REPLACED yanıltması, unsuspend silinmişte işareti siler, Redis askı işareti commit öncesi, sıfırlamada aynı parola/e-posta bildirimi yok, kod özeti tuzsuz  [DÜŞÜK | kanıt PS]
- **Kaynak bulgular:** A11-07, A11-14, A11-15, A11-18, A11-19 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** auth/AuthService.refresh, auth/token/VerificationService.hash, moderation/UserModerationService (suspend/unsuspend; W1-A'ya ait), profile/ProfileService.anonymize
- **Düzeltme:** refresh'te önce kullanıcı durumu: SUSPENDED → 403 ACCOUNT_SUSPENDED; unsuspend yalnız SUSPENDED ise işaret sil+bildir; suspended:<id> yazımı TransactionSynchronization.afterCommit; reset-password aynı parolayı reddet + güvenlik e-postası; kod özeti HMAC(pepper,email:code)
- **Test gereksinimi:** Birim testleri her madde için; smoke-single-session.sh geçmeli

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- backend/src/main/java/edu/bingol/backend/auth/** (AuthService, AuthController, AccountCreator, LoginThrottle, jwt/JwtAuthFilter, token/*)
- profile/ProfileService.java (YALNIZ deleteAccount/anonymize) ve profile/ProfileController.java (silme ucu)
- moderation/UserModerationService.java (suspend/unsuspend; bu dosya yalnız W1-A'nındır)
- notification/SessionDeviceCleaner.java + test
- config/SecurityConfig.java
- common/ApiExceptionHandler.java, common/ApiAuthenticationEntryPoint.java, yeni ErrorController/AccessDeniedHandler, common/RateLimiter.java (yalnız devre kesici), analytics/ActivityTracker.java
- application.properties (yalnız spring.data.redis.* zaman aşımı satırları; kilit: app-props)
- i18n/auth*.properties; i18n/messages*.properties yalnız kilitle (kilit: i18n-messages)
- ilgili backend/src/test/** testleri; scripts/smoke.sh, smoke-student-number.sh, smoke-single-session.sh güncellemesi

**Dokunmayacakların (başka iş akışının):**
- admin/**, support/**, messaging/**, event/**, community/**, poll/**, post/**, moderation/ (UserModerationService dışı), mobil, web

Paylaşılan dosya kilitleri: i18n-messages, app-props. Flyway aralığın: **V900-V909**, indeks öneki **aut9_**. Mobil l10n öneki: **-**.
Yalıtılmış yığın portların: BACKEND_PORT=18110, WEB_PORT=28110, COMPOSE_PROJECT_NAME=bu_w1a.

## 4. ÖZEL TALİMATLAR

Redis devre kesicisinde fail-closed güvenlik tercihi KORUNUR (askı/rol kontrolü atlanmaz): Redis yokken kimlikli istek 503 döner, geçer değil. RateLimiter'a dokunuşun yalnız devre kesici; T-060 (W2-E) ve T-075 (W2-B) aynı dosyaya sonra gelecek. Parola politikası için K-09 varsayılanı (b): min 10, yaygın-parola listesi (10k, kaynak dosyayı src/main/resources altına koy), e-posta/okul numarası/görünen ad içermeme; yöneticiler 12. register'daki DisplayNamePolicy çağrısı e-posta kodu GÖNDERİLMEDEN önce olmalı. T-004: WebSecurity entry point'i /api/admin/** için de ApiAuthenticationEntryPoint kullanmalı; bozuk Bearer'da WWW-Authenticate: Basic ASLA gönderilmez (yalnız Basic istemci için, Authorization başlığı hiç yoksa ve Basic etkinse). Ağ çağrısı/prod yok.

## 5. TEST ve DOĞRULAMA

- backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- T maddelerinin tamamı kod+test ile yeşil
- smoke.sh + smoke-single-session.sh + smoke-student-number.sh yalıtılmış yığında yeşil
- docs/changes/auth.md güncel
- yeni hata kodları 3 dilde (i18n-dupkeys temiz)
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.

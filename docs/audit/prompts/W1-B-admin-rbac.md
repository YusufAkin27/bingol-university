# W1-B - Backend: yönetici paneli yetkisi, yol çözümleme, hiyerarşi, denetim

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 1. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: L (≈2 gün).

Sen **W1-B** iş akışı ajanısın (%-kodlu yol bypass, kodsuz doğrulama, rol onayı bypass, gerekçe kuralları, hiyerarşi, çözme kotası, denetim kalitesi, ayar doğrulama). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: T-010 ilk; T-013 ve T-016 ona bağlı
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar (RbacCoverageTest ve AdminPermissionPolicyTest ZORUNLU)

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w1b && mkdir -p /c/bu_verify_w1b && git archive HEAD | tar -x -C /c/bu_verify_w1b`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w1b/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w1b/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yalıtılmış yığın (smoke):** temiz kopyada `.env.example` -> `.env` (DB_PASSWORD, JWT_SECRET >=32, ADMIN_PASSWORD, `ADMIN_EMAILS=boss@bingol.edu.tr`, `MAIL_ENABLED=false`, `LEGAL_ENFORCE_REACCEPT=false`), `export COMPOSE_PROJECT_NAME=bu_w1b BACKEND_PORT=18120 WEB_PORT=28120`, `docker compose up -d --build`, `BASE=http://localhost:18120 ADMIN_PASSWORD=... ONLY="smoke-..." bash scripts/smoke-all.sh`; bitince `docker compose down -v`. A7 ortak yığınına (18081) ve `flushall` ile başkalarının verisine DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W1-B: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 1b. SÖZLEŞMELER (aynı dalgada paralel çalışan akışlarla; alan/davranış adlarını DEĞİŞTİRME)

- **C8** (W1-B -> W2-K): Yeni izin `users.verify` (yalnız FULL) ve gerekçe kuralları; web nav/GuardedAction bunu W2-K'da izler.

## 2. KAPSAM - T maddeleri (8)

#### T-010 - Yüzde-kodlu yol segmentiyle (/%63onversations, /%65xport.csv) admin RBAC, gerekçe/hız ve denetim atlatılıyor (VIEWER özel mesaj ve tüm kullanıcı CSV'sini okur)  [YÜKSEK | kanıt PV]
- **Kaynak bulgular:** A1-01, A1-37 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** admin/rbac/AdminPermissionInterceptor (36: getRequestURI), admin/AdminGuardInterceptor, admin/AuditRecorder.shouldAudit, AuditInterceptor, AuditAccessDeniedHandler, AdminPermissionPolicy
- **Düzeltme:** Tek çözümleyici AdminPaths.of(req) (ServletRequestPathUtils parsed path veya BEST_MATCHING_PATTERN); tüm interceptor'lar onu kullanır; /api/admin/** yolunda % (e-posta için %40 hariç) görürse 400 filtre; HEAD davranışını hizala
- **Test gereksinimi:** AdminPermissionPolicyTest: her (method,path) için her harfi %xx yapan türetilmiş varyantlar; MockMvc VIEWER /users/1/%63onversations 403, MODERATOR PATCH /users/1/%72ole 403

#### T-011 - Yönetici kodsuz 'bekleyen kayıt doğrulama' / verify-email ile e-posta sahipliğini atlayıp hesap açıyor; ADMIN_EMAILS terfisi  [YÜKSEK | kanıt PS]
- **Kaynak bulgular:** A14-05, A1-05, A1-38 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** admin/AdminAccountVerificationService (verifyPending, verifyUser), auth/AccountCreator (ADMIN_EMAILS terfisi), AdminPermissionPolicy, AdminGuardPolicy; log: LogMasking
- **Düzeltme:** Yeni users.verify izni (yalnız FULL), gerekçe ≥5 + yıkıcı kural; adminProperties.isAdminEmail(email) ise reddet; AccountCreator terfisi yalnız e-posta kodu doğrulamalı çağrıda; ADMIN_VERIFY logunda e-postayı maskele; denetimde 'kod atlandı' özeti
- **Test gereksinimi:** MODERATOR ile verify 403; FULL gerekçesiz 400; adminEmail hedef 409; RbacCoverageTest + PermissionMatrix testi

#### T-012 - Rol düşürme/silme uçları iki kişi onayı ve 'son FULL' korumasını atlıyor (PATCH /users/{id}/role, DELETE, bulk)  [YÜKSEK | kanıt P]
- **Kaynak bulgular:** A14-04, A1-06 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** admin/AdminUserService.changeRole/delete/requireAnotherAdmin, admin/rbac/RbacService, AdminUserBulkService
- **Düzeltme:** Hedefin etkin profili FULL ise RBAC_APPROVAL_REQUIRED (RbacService.needsApproval paylaş); countFullAdmins()<=1 → 409; bulk/delete aynı kural
- **Test gereksinimi:** Tek FULL ile ikinci FULL rol düşürme 409; iki kişi onayı akışı yeşil; smoke-admin-rbac

#### T-013 - Gerekçe/yıkıcı-işlem kuralı boşlukları: gönderi gizle/kalıcı sil, haber gizle, kullanıcı askıya alma, access-ban, kampanyalar, rewrap, ayarlar, itiraz kararı gerekçesiz  [YÜKSEK | kanıt P]
- **Kaynak bulgular:** A14-07, A14-12, A1-33 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** admin/AdminGuardPolicy (reasonMin/destructive kuralları)
- **Düzeltme:** posts DELETE/hide/unhide, news PATCH, users/{id}/suspend, verify-email|send-reset|revoke-sessions, access-bans POST, push/mail campaigns, crypto/rewrap, settings PUT, appeals decide için gerekçe ≥5 ve yıkıcı hız sınırı; X-Admin-Reason içerik doğrulaması (CRLF yok)
- **Test gereksinimi:** AdminGuardPolicyTest her yeni kural; smoke-admin-moderation
- **Bağımlılık:** T-010

#### T-014 - users.write hedef yönetici hesabını ayırt etmiyor: MODERATOR FULL yöneticinin profili/oturumları/şifresini değiştirebilir  [ORTA | kanıt P]
- **Kaynak bulgular:** A1-07, A14-08 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** admin/AdminAccountVerificationService, AdminUserExtrasController.patchProfile, AdminUserSessionService.revoke, AdminPushDeviceService.delete, Targets
- **Düzeltme:** Targets içinde 'hedef ADMIN ise yalnız FULL' kuralı (askı/bulk'taki gibi)
- **Test gereksinimi:** MODERATOR→FULL hedef: profile/revoke-sessions/send-reset 403

#### T-015 - Sohbet çözme kotası (admin-decrypt-per-hour/max-messages) kodda kullanılmıyor; userId suzgeçsiz akış gezdirilebilir; gerekçe ≥10  [ORTA | kanıt S]
- **Kaynak bulgular:** A1-08 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** crypto/AdminDecryptService.record, admin chat viewer (AdminChatViewerController), CryptoProperties, application.properties
- **Düzeltme:** limiter.check('admindecrypt:'+adminId, props.adminDecryptPerHour(), 1sa); genel akışta userId/conversationId zorunlu; gerekçe ≥20; hacim eşiğinde SystemAlertService uyarısı
- **Test gereksinimi:** Kota aşımı 429; zorunlu filtre testi; smoke-admin-chat
- **KARAR (varsayılan = ÖNERİ):** K-13 Yönetici sohbet çözme (CRYPTO_ADMIN_DECRYPT_ENABLED) | Seçenekler: (a) Açık; (b) kapalı varsayılan; (c) açık ama rapor kimliği/iki kişi onayı zorunlu | ÖNERİ: (c): yalnız şikâyet kaydı bağlı konuşmalarda, gerekçe ≥20 + rapor kimliği, saatlik kota, FULL + (isteğe bağlı) ikinci onay; kullanıcıya erişim sonrası bildirim hukuk görüşüyle.

#### T-016 - Denetim kalitesi: reddedilen istek için başarı özeti yazılıyor; kişisel veri okuyan GET'ler denetimsiz (sessions, push-devices, pending, tickets, strikes, mail/outbox)  [ORTA | kanıt P]
- **Kaynak bulgular:** A14-12, A14-13, A1-33 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** admin/AuditRecorder.shouldAudit, AuditContext.summary çağrıları, @AuditRead
- **Düzeltme:** Özeti işlem tamamlandıktan SONRA ve yalnız başarıda yaz; users.pii uçlarının tamamı denetime girsin; kişisel veri GET'leri @AuditRead
- **Test gereksinimi:** AuditRecorderTest; 400 dönen DELETE /users/1 özet içermemeli
- **Bağımlılık:** T-010

#### T-017 - support_email/contact_email biçim doğrulaması yok (Reply-To başlık enjeksiyonu riski); URL ayarlarında şema denetimi eksik  [ORTA | kanıt P]
- **Kaynak bulgular:** A14-11 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** admin settings servisi (PUT /api/admin/settings/{key}), appinfo/AppSettings
- **Düzeltme:** E-posta anahtarlarında biçim + satır sonu reddi; URL anahtarlarında https şeması; geçersiz 400 SETTING_INVALID (3 dil)
- **Test gereksinimi:** SettingsServiceTest: not-an-email, <script>, CRLF reddi

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- backend/.../admin/** HARİÇ admin/AuditRepository.java ve admin/UserFilter.java (W1-C'nin)
- admin/rbac/** (AdminPermissionPolicy yalnız kilitle: admin-policy)
- admin/AdminGuardPolicy.java, AdminGuardInterceptor, AuditRecorder, AuditInterceptor, AuditAccessDeniedHandler
- auth/AccountCreator.java'ya YALNIZ ADMIN_EMAILS terfisi satırı (W1-A ile aynı dosya: önce W1-A'nın push ettiğini doğrula; çakışırsa koordinatöre bildir)
- crypto/AdminDecryptService + admin sohbet görüntüleyici denetleyicisi (AdminChatViewerController) + CryptoProperties
- appinfo/ ayar servisi (PUT /api/admin/settings/{key} doğrulaması)
- i18n/ops.properties, modadmin*, chatadmin* (kilit: i18n-messages ortak dosya ise)
- docs/ADMIN_API.md ve docs/changes/ops.md (kilit: docs-shared)
- ilgili testler: AdminPermissionPolicyTest, RbacCoverageTest, AdminGuardPolicyTest; scripts/smoke-admin*.sh

**Dokunmayacakların (başka iş akışının):**
- PII maskeleme dosyaları (W1-C'nin listesi), kullanıcı API'leri (community/event/poll/post), mobil, web

Paylaşılan dosya kilitleri: admin-policy, i18n-messages, docs-shared. Flyway aralığın: **V910-V919 (gerekmezse kullanma)**, indeks öneki **adm9_**. Mobil l10n öneki: **-**.
Yalıtılmış yığın portların: BACKEND_PORT=18120, WEB_PORT=28120, COMPOSE_PROJECT_NAME=bu_w1b.

## 4. ÖZEL TALİMATLAR

AdminPaths çözümleyicisini BİR sınıf olarak yaz (ör. admin/AdminPaths); Spring'in ServletRequestPathUtils.getParsedRequestPath(req) veya HandlerMapping.BEST_MATCHING_PATTERN_ATTRIBUTE kullan; interceptor sıralamasında BEST_MATCHING_PATTERN henüz yoksa parsed path. Yeni admin ucu YOK; yalnız mevcutlar. users.verify yeni izin: PermissionMatrix'e yalnız FULL olarak ekle; eski MODERATOR yetkisi KALKAR (davranış değişikliği: docs/changes/ops.md'ye yaz). 'Hiyerarşi' için Targets yardımcısına tek yerden kural koy. DİKKAT: auth/AccountCreator.java W1-A ile ortak - aynı anda düzenleme yapma, önce `git log -1 -- <dosya>` ve `git status` ile W1-A'nın bitirdiğini gör; bitmediyse bu satırı SON adıma bırak.

## 5. TEST ve DOĞRULAMA

- backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar (RbacCoverageTest ve AdminPermissionPolicyTest ZORUNLU)
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- Her admin ucu bir izne eşli (RbacCoverageTest yeşil)
- Türetilmiş %xx varyant testi yeşil
- smoke-admin.sh, smoke-admin-rbac.sh (ikinci yönetici ile), smoke-admin-moderation.sh yalıtılmış yığında yeşil
- docs/ADMIN_API.md yeni users.verify izni ve gerekçe kuralları
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.

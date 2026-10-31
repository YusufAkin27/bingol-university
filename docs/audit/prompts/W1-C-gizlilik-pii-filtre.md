# W1-C - Backend: yönetici PII maskeleme, destek temizliği, içerik filtresi, takip önerisi

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 1. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: L (≈2 gün).

Sen **W1-C** iş akışı ajanısın (Maskeleme tek yerde (JSON+CSV+kitle önizleme), destek temizliği transaction hatası, ownTicket NPE, filtre atlatmaları, takip önerisi sorgusu). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: Yok
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar; PostgreSQL'e özel takip önerisi sorgusu için 20k seed ile EXPLAIN (scripts/perf/seed-20k.sql)

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w1c && mkdir -p /c/bu_verify_w1c && git archive HEAD | tar -x -C /c/bu_verify_w1c`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w1c/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w1c/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yalıtılmış yığın (smoke):** temiz kopyada `.env.example` -> `.env` (DB_PASSWORD, JWT_SECRET >=32, ADMIN_PASSWORD, `ADMIN_EMAILS=boss@bingol.edu.tr`, `MAIL_ENABLED=false`, `LEGAL_ENFORCE_REACCEPT=false`), `export COMPOSE_PROJECT_NAME=bu_w1c BACKEND_PORT=18130 WEB_PORT=28130`, `docker compose up -d --build`, `BASE=http://localhost:18130 ADMIN_PASSWORD=... ONLY="smoke-..." bash scripts/smoke-all.sh`; bitince `docker compose down -v`. A7 ortak yığınına (18081) ve `flushall` ile başkalarının verisine DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W1-C: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (7)

#### T-018 - Admin PII maskeleme yalnız kullanıcı liste/detayında: kitle önizleme, destek, geri bildirim, rapor, strike, kulüp üye/CSV, gönderi, access-ban, mail suppression, audit ve CSV uçları maskesiz e-posta/IP döndürüyor  [KRİTİK | kanıt PS]
- **Kaynak bulgular:** A14-01, A14-02, A14-03, A1-04 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** notification/campaign/CampaignService+AudienceResolver(SamplePerson), community/admin/ClubAdminQueryService, ClubContentAdminService, post/admin/AdminPostService, moderation/admin/ModAdminDtos+AdminReportContextService, support/ticket/TicketService, support/admin/SupportExportController, mail/admin/MailSuppressionAdminService, accessban/AccessBanDtos, admin/AuditRepository, event admin CSV
- **Düzeltme:** PermissionAwareMasking.email/opaque her DTO fabrikasında (merkezî EmailView/serializer tercih); CSV'lerde canSeePii() yoksa maskeli ya da users.export iste; audit CSV'de ip için users.pii; mail kampanya önizlemesi dahil
- **Test gereksinimi:** Genel sızıntı testi: SUPPORT/VIEWER/EDITOR JWT ile tüm /api/admin GET uçlarını (OpenAPI'den) gezip yanıtta @ içeren maskesiz e-posta ara (RbacCoverageTest benzeri); smoke-admin-support/moderation

#### T-020 - Herkese açık destek temizliği @Transactional dolanıyor: doğrulanmamış (24 sa) ve süresi dolan talepler HİÇ silinmiyor (KVKK saklama)  [YÜKSEK | kanıt PV]
- **Kaynak bulgular:** A7-01 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** support/ticket/PublicSupportService.scheduledCleanup→cleanup (180-192)
- **Düzeltme:** scheduledCleanup üstüne @Transactional veya TransactionTemplate/ayrı bean; hata yutma yerine metrik
- **Test gereksinimi:** scheduledCleanup() doğrudan çağıran test (proxy dışı) 24 sa+365 gün silmeyi doğrular

#### T-022 - İçerik filtresi bağlantı/e-posta biçimli boşluksuz parçayı tümden atlıyor (orospu@x.y gönderi olarak yayınlandı)  [YÜKSEK | kanıt PV]
- **Kaynak bulgular:** A16-03 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** moderation/profanity/ProfanityMatcher.isLinkLike (237,269)
- **Düzeltme:** Parçayı @ / . : üzerinden de bölüp aynı eşleştirmeden geçir; atlama yalnız tam geçerli URL/e-posta ayrıştırması başarılıysa; gerçek URL ayrıca kara liste
- **Test gereksinimi:** ProfanityMatcherTest: orospu@x.y, siktir@a.b, www.orospu, orospu://x engellenir; Sikke/Bingöl yanlış pozitifi artmaz; smoke-profanity

#### T-024 - Takip önerileri sorgusu O(kullanıcı x kulüp²): 20 eşzamanlı çağrıda 503 DB_TIMEOUT, p95 4.6 sn  [YÜKSEK | kanıt P]
- **Kaynak bulgular:** A2-01 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** post/follow/FollowService.suggestions (214-245), user_block indeksleri
- **Düzeltme:** Aday kümesini 'benim kulüplerim' CTE + (department,class_year) indeksiyle ≤300 adaya daralt; CASE'i bir kez hesapla; sonucu kullanıcı başına 10-30 dk önbellekle; user_block (blocker_id,blocked_id) ve (blocked_id,blocker_id) indeksleri (yeni V9xx)
- **Test gereksinimi:** EXPLAIN karşılaştırması (20k seed); QA yığınında c=20 200 istek p95<500 ms ve 503=0; mevcut Follow testleri

#### T-021 - Genel destek talebi kimliği için kullanıcı uçlarında 500 (NPE) ve varlık oracle'ı  [ORTA | kanıt PV]
- **Kaynak bulgular:** A1-22, A7-02, A12-05 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** support/ticket/TicketService.ownTicket (177)
- **Düzeltme:** t.getUserId()==null || !equals → 404 TICKET_NOT_FOUND (Objects.equals)
- **Test gereksinimi:** GET/messages/close public talep id'si ile 404; TicketServiceTest

#### T-023 - Filtre izin listesi gevşek biçimi gerçek küfrü açıyor (sikis, siki, sikici, amina koydum); homoglif/leet eksikleri  [ORTA | kanıt P]
- **Kaynak bulgular:** A16-04, A16-18 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** moderation/profanity/ProfanityMatcher.addAllow, ProfanityText.map, profanity-tr/en/ar.txt
- **Düzeltme:** Gevşek biçimi yalnız uzun sözcüklere tam eşleşme izni; sikis/siki ayrı engelleme; 'amına koy*' kalıbı; confusables tablosu (Kiril ѕ і ф, Yunan); phuck/fvck türevleri; admin 'metni dene' kutusu araç notu
- **Test gereksinimi:** Çevrimdışı koşum örnekleri birim teste: Pornografi Semineri, Sikkim yanlış pozitif kalır/kalkar kararı belgeli
- **Bağımlılık:** T-022

#### T-019 - Maskeli profilde q= araması e-postayı yeniden kurmaya izin veriyor (arama kehaneti)  [DÜŞÜK | kanıt PS]
- **Kaynak bulgular:** A1-32, A14-18 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** admin/UserFilter (51-53), mail/admin/MailSuppressionAdminService.hashesFor
- **Düzeltme:** canSeePii() yoksa q yalnız display_name/okul numarasında; en az uzunluk
- **Test gereksinimi:** VIEWER q=tam-e-posta sonuç vermez
- **Bağımlılık:** T-018

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- notification/campaign/CampaignService.java ve AudienceResolver.java (YALNIZ SamplePerson maskeleme)
- community/admin/** ve event/admin/** (maskeleme)
- post/admin/AdminPostService.java
- moderation/admin/** (ModAdminDtos, AdminReportContextService), moderation/profanity/** (ProfanityMatcher, ProfanityText, liste dosyaları; ProfanityAdminController W3-F'nin)
- support/** (ticket/TicketService, PublicSupportService, admin/SupportExportController)
- mail/admin/MailSuppressionAdminService.java
- accessban/AccessBanDtos.java
- admin/AuditRepository.java ve admin/UserFilter.java (bu iki dosya admin paketinde ama W1-C'nindir)
- post/follow/FollowService.java (YALNIZ suggestions) + yeni migration (user_block indeksleri)
- ilgili testler ve scripts/smoke-admin-support.sh, smoke-admin-moderation.sh, smoke-profanity.sh, public-support-e2e.sh

**Dokunmayacakların (başka iş akışının):**
- admin/rbac/**, admin/Admin*Service (W1-B), messaging/**, event/** (admin/ hariç), mobil, web

Paylaşılan dosya kilitleri: i18n-messages. Flyway aralığın: **V920-V929**, indeks öneki **prv9_**. Mobil l10n öneki: **-**.
Yalıtılmış yığın portların: BACKEND_PORT=18130, WEB_PORT=28130, COMPOSE_PROJECT_NAME=bu_w1c.

## 4. ÖZEL TALİMATLAR

Maskeleme için merkezî bir yol seç: DTO üretiminde PermissionAwareMasking.email/opaque (mevcut) çağrısını EVRENSEL kıl; çağıran admin profilini AdminPermissionContext'ten oku. Destek ucunda SUPPORT profili yanıt yazmak için e-postaya ihtiyaç duyar: PermissionMatrix users.pii olmayan SUPPORT için maskeli e-posta göster, yanıt e-postası sunucuda gönderilir (istemci e-postayı bilmez); bunu docs/ADMIN_API.md'de belgele. CSV'de e-posta sütunu maskeli veya users.export zorunlu. ProfanityMatcher değişikliklerinde yanlış pozitifleri (Sikke, Scunthorpe, Bingöl, Cumartesi) test ederek koru. Takip önerisi: EXPLAIN çıktısını docs/PERFORMANCE.md'ye ekle.

## 5. TEST ve DOĞRULAMA

- backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar; PostgreSQL'e özel takip önerisi sorgusu için 20k seed ile EXPLAIN (scripts/perf/seed-20k.sql)
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- SUPPORT/VIEWER/EDITOR JWT ile tüm /api/admin GET uçlarında maskesiz e-posta yok (yeni genel sızıntı testi)
- scheduledCleanup() doğrudan testi yeşil
- ProfanityMatcher yeni testleri yeşil; smoke-profanity
- follow-suggestions c=20 p95 < 500 ms, 503=0
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.

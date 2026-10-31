# W1-F - Backend: etkinlik, kulüp, anket, duyuru alan mantığı ve sistem-admin yetkisi

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 1. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: XL (≈3 gün).

Sen **W1-F** iş akışı ajanısın (Sistem ADMIN rolü, etkinlik yetkisi canlı kulüp bağı, hedef kitle İ eşlemesi, goingCount, yoklama PII, legacy sohbet, kapsam, kulüp silinince anket, CSV, avatar (kulüp/etkinlik parçası)). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: T-040 PermissionMatrix/JWT 'ap' talebini YALNIZ OKUR (W1-B ile dosya çakışması yok)
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar; İ eşlemesi PostgreSQL'e özeldir: H2 testi yetmez, PG'de smoke veya Testcontainers benzeri doğrulama

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w1f && mkdir -p /c/bu_verify_w1f && git archive HEAD | tar -x -C /c/bu_verify_w1f`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w1f/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w1f/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yalıtılmış yığın (smoke):** temiz kopyada `.env.example` -> `.env` (DB_PASSWORD, JWT_SECRET >=32, ADMIN_PASSWORD, `ADMIN_EMAILS=boss@bingol.edu.tr`, `MAIL_ENABLED=false`, `LEGAL_ENFORCE_REACCEPT=false`), `export COMPOSE_PROJECT_NAME=bu_w1f BACKEND_PORT=18160 WEB_PORT=28160`, `docker compose up -d --build`, `BASE=http://localhost:18160 ADMIN_PASSWORD=... ONLY="smoke-..." bash scripts/smoke-all.sh`; bitince `docker compose down -v`. A7 ortak yığınına (18081) ve `flushall` ile başkalarının verisine DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W1-F: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (9)

#### T-040 - Sistem ADMIN rolü kullanıcı API'lerinde (kulüp/etkinlik/anket/gönderi yönetimi) RBAC profilini ve admin denetimini atlıyor (VIEWER bile kulüp siler)  [YÜKSEK | kanıt S]
- **Kaynak bulgular:** A1-02 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** common/CurrentUser.isAdmin, community/Actor, community/permissions/ClubPermissions, community/CommunityService (197,285,554), event/EventService (724,898), poll/PollAccess (77,86), post/PostController.delete (71)
- **Düzeltme:** Actor.admin yerine ilgili izne bağlı systemAdmin(perm) (JWT ap + PermissionMatrix; ör. content.write/content.hide); bu kolun kullanımı AuditContext ile admin_audit'e yazılsın veya admin müdahalesi yalnız /api/admin/**'e taşınsın (önerilen: ilki, FULL/izinli profil)
- **Test gereksinimi:** VIEWER JWT ile DELETE /api/posts/{başkasının} 403; FULL 204 + admin_audit satırı; kulüp/etkinlik/anket eşleniği
- **Bağımlılık:** PermissionMatrix API (yalnız okuma)

#### T-041 - Etkinlik yönetimi canlı kulüp yetkisine bağlı değil: yasaklanan/çıkarılan oluşturan ve kulüp dışı ortak organizatör katılımcı PII'sine, duyuruya, seriye erişiyor; seri ile onaysız ACTIVE kopya  [YÜKSEK | kanıt S]
- **Kaynak bulgular:** A1-03, A12-08 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** event/EventService.canManage/requireManager (723-745), event/extras/CoOrganizerService (48-84,114-117), SeriesService (57-71), AttendanceService (155), ClubMemberLeftEvent / EventRoomClubListener
- **Düzeltme:** canManage: creator/co-organizer ek olarak communities.can(a,cid,MANAGE_EVENTS) (BANNED/üye değilse false); requireManager'da önce ensureVisible; CoOrganizerService.add hedefin ACTIVE üyeliğini ister; seri kopya status staff değilse PENDING_REVIEW; ClubMemberLeftEvent'te co-organizer kayıtları ve RSVP temizliği; ACTIVE etkinliğin non-staff içerik değişikliği yeniden PENDING_REVIEW
- **Test gereksinimi:** Creator ban sonrası attendees/mark/announce/series/checkin-code 403/404; kulüp dışı co-organizer series 403; smoke-communities-events, smoke-club-lifecycle

#### T-042 - Hedef kitle SQL eşlemesi büyük İ ile başlayan bölüm/fakültelerde çalışmıyor (duyuru, anket sayaçları, bildirim hedefi sessizce kayıp); sınıf alanı doğrulanmıyor; liste/sayaç tutarsız  [YÜKSEK | kanıt P]
- **Kaynak bulgular:** A12-01, A12-17, A12-16 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** academic/DepartmentAnnouncementService (audienceSql/field/audienceIds/userField), poll/PollAccess (eligibleCount, audienceUserIds), PollRepository.countOpen/countClosed, PollService.applyAudience/audNorm
- **Düzeltme:** Tek normalize fonksiyonu (MenuItemKey benzeri: İ/ı/I→i, NFD) hem Java hem SQL'de; tercih: katalogdan kimlikle eşleme; sınıf için ExamService GRADES kümesi doğrulaması; sayaç = liste mantığı
- **Test gereksinimi:** İşletme/İktisat/İlahiyat bölümlü kullanıcı için scope=mine ve audience-count; anket totalCount/openCount; PG üzerinde smoke (H2 yetmez)

#### T-043 - UserEvent.goingCount tam-varlık UPDATE ile ezilebilir (kayıtları kapat/başlık düzenle sırasında kapasite aşımı)  [ORTA | kanıt S]
- **Kaynak bulgular:** A12-02 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** event/UserEvent.goingCount, EventService.update/setRegistrationClosed/setCover/removeCover/review/cancelInternal
- **Düzeltme:** goingCount @Column(updatable=false) (Poll.voterCount gibi) veya @DynamicUpdate; sayaç yalnız koşullu UPDATE'lerle değişir
- **Test gereksinimi:** Eşzamanlı RSVP+kayıtları-kapat entegrasyon testi; mevcut event testleri

#### T-044 - Yoklama işaretleme ile RSVP'siz kullanıcıya sahte yoklama + ad/bölüm sızıntısı (gizlilik ve engel yok sayılıyor)  [ORTA | kanıt S]
- **Kaynak bulgular:** A1-09 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** event/AttendanceService.markOne/bulk/list/csv (143,154-180,211-235)
- **Düzeltme:** markOne yalnız o etkinlikte GOING/yoklama kaydı olana; liste bölümü AvatarVisibility.visibleOwners(DEPARTMENT) ile süzülür; engelli çiftler gizli
- **Test gereksinimi:** RSVP'siz uid ile PUT attendance 4xx; ONLY_ME bölüm listede null

#### T-045 - Etkinlik sohbetinde legacy uç INTERESTED ile onaysız giriş (APPROVAL modu atlanıyor)  [ORTA | kanıt S]
- **Kaynak bulgular:** A1-10 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** event/EventChatService (40: GET /api/events/{id}/chat), event/chat/EventChatService.eligible
- **Düzeltme:** allowed = rsvp.status==GOING || canManage; legacy ucu event.chat.EventChatService'e yönlendir
- **Test gereksinimi:** INTERESTED RSVP ile /chat 403/404; GOING 200

#### T-046 - Anket hedef kitlesi yalnız listede süzülüyor, ID ile doğrudan açık; bölüm/fakülte duyurusu kapsam dışı kullanıcıya ID ile açık  [ORTA | kanıt PS]
- **Kaynak bulgular:** A1-17, A12-10 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** poll/PollAccess.canView (97-106), PollService.get (85-91), academic/DepartmentAnnouncementService.get/markRead
- **Düzeltme:** canView: audienceMatches(p,user) || canManage; duyuru get/markRead kapsam denetimi K-19 kararına göre (öneri: kapsam dışına 404, scope=all yalnız kapsamsızları listeler)
- **Test gereksinimi:** Farklı bölümden kullanıcı GET /api/polls/{id} 404/403; duyuru eşleniği
- **Bağımlılık:** T-042
- **KARAR (varsayılan = ÖNERİ):** K-19 Duyuru kapsamı: gizlilik mi ilgi filtresi mi? | Seçenekler: (a) İlgi filtresi (mevcut) - belgele; (b) kapsam dışına 404, 'Tümü' yalnız kapsamsız duyurular | ÖNERİ: (b). Anket tarafıyla (T-046) tutarlı; sınav yeri/not gibi içerik sızmaz. 'Tümü' sekmesi ürün olarak gerekiyorsa kapsamsız duyurular + 'başka bölümler' başlığı gövdesiz özet.

#### T-047 - Kulüp silinince kulüp anketleri açık, oylanabilir ve bildirim gönderiyor (poll dinleyicisi yok)  [ORTA | kanıt P]
- **Kaynak bulgular:** A12-03 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** community/extras/ClubExtrasHooks.onCommunityDeleted, ClubDeletedEvent dinleyicileri, poll/PollAccess.canView/eligible
- **Düzeltme:** ClubDeletedEvent için poll dinleyicisi (OPEN/DRAFT → CANCELLED/CLOSED, bildirimleri durdur); canView/eligible kulübün ACTIVE olmasını da denetler
- **Test gereksinimi:** Kulüp sil → anket state kapalı, vote 4xx

#### T-048 - Anket CSV dışa aktarımı showResults (AFTER_CLOSE/AFTER_VOTE) kuralını deliyor  [ORTA | kanıt P]
- **Kaynak bulgular:** A12-04 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** poll/PollController.export → PollAdminService.csvFor
- **Düzeltme:** CSV'ye resultsVisible mantığı: kapanmadan 409 veya boş (admin ucu ayrı kalır)
- **Test gereksinimi:** AFTER_CLOSE açıkken export 409

### Paylaşılan T maddeleri (başka iş akışıyla ortak; YALNIZ senin parçan)

#### T-027 - Avatar gizliliği (ONLY_ME/SHARED_CONTEXT) ve moderasyon avatar_hidden sohbet/kulüp/etkinlik/gönderi uçlarında uygulanmıyor  [YÜKSEK | kanıt PS]
- **Kaynak bulgular:** A11-02, A1-12 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** Parça 1 (W1-D): messaging/ConversationService 207-214,514-518, WS olay avatar URL'leri; Parça 2 (W1-F): community/CommunityService 619, CommunityPostService 190, extras/ClubMemberSearchService 64, event/EventService 677,879, extras/CoOrganizerService 83,109, admission/EventAdmissionService 281
- **Düzeltme:** Her DTO kurucusunda AvatarVisibility.visibleOwners(viewer, ids, AVATAR); visibility==null iken avatar gönderme (fail-closed); getAvatarUrl() kullanımı için ArchUnit/grep testi
- **Test gereksinimi:** ONLY_ME avatarlı kullanıcı için üye listesi/arama/sohbet listesinde avatarUrl null; avatar_hidden testi; QueryRulesTest benzeri tarama

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- event/** (event/admin/**, event/chat/EventChatMaintenance.java [W1-D] ve event/extras/IcsService.java+IcsWriter.java [W1-J] HARİÇ)
- community/** (community/admin/** HARİÇ)
- poll/**
- academic/DepartmentAnnouncementService.java ve ortak audience yardımcıları
- common/CurrentUser.java
- post/PostController.java (YALNIZ delete içindeki admin kapısı)
- i18n/event*.properties, community*.properties, poll*.properties, academic*.properties
- docs/changes/event.md, community.md, poll.md
- ilgili testler; scripts/smoke-communities-events.sh, smoke-club-lifecycle.sh, smoke-poll.sh, smoke-academic.sh, event-admission-e2e.sh, club-permissions-smoke.sh

**Dokunmayacakların (başka iş akışının):**
- messaging/**, admin/** (RBAC), */admin/** (W1-C), event/extras/IcsService.java+IcsWriter.java (W1-J), mobil

Paylaşılan dosya kilitleri: i18n-messages, docs-shared. Flyway aralığın: **V950-V959**, indeks öneki **evt9_**. Mobil l10n öneki: **-**.
Yalıtılmış yığın portların: BACKEND_PORT=18160, WEB_PORT=28160, COMPOSE_PROJECT_NAME=bu_w1f.

## 4. ÖZEL TALİMATLAR

T-040: sistem ADMIN'in kullanıcı API'sindeki yetkisi artık Actor.admin==true yerine ilgili izne bağlı (content.write / content.hide / comms.announce vb.); izin yoksa 403, varsa admin_audit'e satır yazılır (AuditRecorder'ı çağır, W1-B dosyasını DEĞİŞTİRME - public API yoksa kendi küçük yardımcını yaz). Basic auth yöneticisi (basic-admin) her zaman FULL sayılır. T-042: Java ve SQL için TEK normalize kuralı (İ/ı/I->i, NFD, strip); mümkünse katalog kimliği; mevcut PollAccess/DepartmentAnnouncementService sorgularını aynı fonksiyonla besle. T-027 Parça 2 (kulüp/etkinlik DTO'ları) sana ait; Parça 1 (mesajlaşma) W1-D'nin. T-041'de co-organizer kayıtları ClubMemberLeftEvent'te temizlenir; mevcut verideki kulüp dışı co-organizer'lar için migration GEREKMEZ (çalışma zamanı kontrolü yeter).

## 5. TEST ve DOĞRULAMA

- backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar; İ eşlemesi PostgreSQL'e özeldir: H2 testi yetmez, PG'de smoke veya Testcontainers benzeri doğrulama
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- Her T için regresyon testi (rapor 'Regresyon' satırları)
- smoke-communities-events (SKIP_REMINDER=1), smoke-club-lifecycle, smoke-poll, smoke-academic yalıtılmış yığında yeşil
- İşletme/İktisat/İlahiyat bölümlü kullanıcıyla scope=mine ve audience-count PG'de doğrulandı
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.

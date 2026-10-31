# W2-A - Backend performans: sorgu ve veri yolu

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 2. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: L.

Sen **W2-A** iş akışı ajanısın (Görsel işleme işlem dışı, anket oy sayaç, takip akışı, bakım parçaları, events N+1, indeks/HOT). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: Dalga 1 W1-E/W1-F/W1-C bitmiş olmalı
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar + 20k seed EXPLAIN/ölçüm

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w2a && mkdir -p /c/bu_verify_w2a && git archive HEAD | tar -x -C /c/bu_verify_w2a`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w2a/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w2a/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yalıtılmış yığın (smoke):** temiz kopyada `.env.example` -> `.env` (DB_PASSWORD, JWT_SECRET >=32, ADMIN_PASSWORD, `ADMIN_EMAILS=boss@bingol.edu.tr`, `MAIL_ENABLED=false`, `LEGAL_ENFORCE_REACCEPT=false`), `export COMPOSE_PROJECT_NAME=bu_w2a BACKEND_PORT=18210 WEB_PORT=28210`, `docker compose up -d --build`, `BASE=http://localhost:18210 ADMIN_PASSWORD=... ONLY="smoke-..." bash scripts/smoke-all.sh`; bitince `docker compose down -v`. A7 ortak yığınına (18081) ve `flushall` ile başkalarının verisine DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W2-A: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (6)

#### T-068 - Avatar/kapak/logo yükleme görüntü işlemeyi DB işlemi ve Hikari bağlantısı içinde yapıyor (24 eşzamanlı yüklemede 24 idle in transaction)  [ORTA | kanıt P]
- **Kaynak bulgular:** A2-05 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** profile/ProfileService.setAvatar (175-187), community/CommunityService.setCover/setLogo (329,345), event/EventService.setCover (385), messaging/ConversationService.setAvatar (242), menu/MenuAdminService (60)
- **Düzeltme:** media.storeImage işlem DIŞINDA, ardından kısa TransactionTemplate ile URL yaz (5 yerde aynı desen)
- **Test gereksinimi:** 24 eşzamanlı yükleme: idle in transaction ≈0; mevcut yükleme testleri

#### T-069 - Tek ankete oy: sıcak satır tavanı ~30 oy/sn (voter_count UPDATE kilidi)  [ORTA | kanıt P]
- **Kaynak bulgular:** A2-06 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** poll/PollVoteService.applyCounters (157-173), poll.voter_count
- **Düzeltme:** voter_count'u oy yazımından çıkar (COUNT/30 sn önbellek/asenkron) veya N parçalı sayaç; en azından poll UPDATE'i işlemin son ifadesi
- **Test gereksinimi:** c=50 oy p95<300 ms; sayaç bütünlüğü (100 ballot=100 oy) korunur; smoke-poll

#### T-070 - Takip ettiklerim akışı gönderi sayısıyla doğrusal tarıyor (21 satır için 28.440 satır elendi)  [ORTA | kanıt P]
- **Kaynak bulgular:** A2-07 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** post/social/SocialFeedRepository (FOLLOWING sorgusu, 20-34), post310_author_idx
- **Düzeltme:** UNION ALL ile takip edilen yazar başına author indeksi + LIMIT veya kullanıcı başına gelen kutusu/önbellek
- **Test gereksinimi:** EXPLAIN: tampon 26k → <500

#### T-071 - Gece bakımında 5000'lik silme parçası statement_timeout (8 sn) sınırına yakın; hata yutulunca tablo hiç temizlenmez  [ORTA | kanıt P]
- **Kaynak bulgular:** A2-08 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** dbmaint/DbMaintenanceJob (137-147), dbmaint/ChunkedDeleter (55-78)
- **Düzeltme:** Bakım bağlantısında SET LOCAL statement_timeout=60000; bildirim/mail parçası 1000-2000; başarısız parça metriği+JobMonitor uyarısı
- **Test gereksinimi:** 800k bildirimli tabloda parça süresi ölçümü; ChunkedDeleter testi
- **Bağımlılık:** T-073

#### T-072 - GET /api/events kulüp başına 1 sorgu (N+1): 30 SQL/istek  [ORTA | kanıt P]
- **Kaynak bulgular:** A2-09 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** event/EventService.manageableIds (894-917), CommunityMemberRepository.findByUserIdAndCommunityIdIn
- **Düzeltme:** Tek findByUserIdAndCommunityIdIn + bellekte izin haritası
- **Test gereksinimi:** pg_stat_statements: 30→~11 SQL/istek

#### T-073 - Kullanılmayan/gereksiz indeksler (message 3, notification 2, analytics_event_user 133 MB) ve HOT'u engelleyen idx_app_user_last_seen / rank_score  [ORTA | kanıt PT]
- **Kaynak bulgular:** A2-12 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** yeni migration (DROP INDEX CONCURRENTLY), message/notification/app_user/post tabloları
- **Düzeltme:** Önce üretimde 2 hafta pg_stat_user_indexes ile idx_scan doğrula (H-08); sonra yeni V9xx ile düşür; analytics_event_user kısmi/BRIN
- **Test gereksinimi:** Flyway PG'de uygulanır; yazma yükü ölçümü (ön/son)
- **Bağımlılık:** H-08, K-33
- **KARAR (varsayılan = ÖNERİ):** K-33 Gereksiz indekslerin silinmesi | Seçenekler: (a) Üretimde idx_scan'e bak (2 hafta), sonra sil; (b) hemen | ÖNERİ: (a) (H-08).

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- T maddelerinin dosyaları (ProfileService.setAvatar, CommunityService.setCover/setLogo, EventService.setCover/manageableIds, ConversationService.setAvatar, MenuAdminService, PollVoteService, SocialFeedRepository, DbMaintenanceJob, ChunkedDeleter, yeni migration)

**Dokunmayacakların (başka iş akışının):**
- push, mesaj fanout, mobil, web

Paylaşılan dosya kilitleri: docs-shared. Flyway aralığın: **V960-V969**, indeks öneki **prf9_**. Mobil l10n öneki: **-**.
Yalıtılmış yığın portların: BACKEND_PORT=18210, WEB_PORT=28210, COMPOSE_PROJECT_NAME=bu_w2a.

## 4. ÖZEL TALİMATLAR

T-073: üretim idx_scan doğrulaması (H-08) olmadan DROP yazma; migration dosyası hazır ama 'K-33 onayı bekler' yorumuyla ayrı commit. CONCURRENTLY için ayrı migration + .sql.conf executeInTransaction=false.

## 5. TEST ve DOĞRULAMA

- backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar + 20k seed EXPLAIN/ölçüm
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- Her T için ölçüm öncesi/sonrası docs/PERFORMANCE.md
- smoke-poll, smoke-all ilgili alt küme
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.

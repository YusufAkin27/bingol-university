# W2-E - Backend moderasyon ve kötüye kullanım

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 2. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: L.

Sen **W2-E** iş akışı ajanısın (Rapor paketi, yeniden kayıt/strike, nefret listesi, hız sınırı kapsamı). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: K-15, K-27 kararları
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar + RateLimitCoverageTest (yeni)

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w2e && mkdir -p /c/bu_verify_w2e && git archive HEAD | tar -x -C /c/bu_verify_w2e`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w2e/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w2e/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yalıtılmış yığın (smoke):** temiz kopyada `.env.example` -> `.env` (DB_PASSWORD, JWT_SECRET >=32, ADMIN_PASSWORD, `ADMIN_EMAILS=boss@bingol.edu.tr`, `MAIL_ENABLED=false`, `LEGAL_ENFORCE_REACCEPT=false`), `export COMPOSE_PROJECT_NAME=bu_w2e BACKEND_PORT=18250 WEB_PORT=28250`, `docker compose up -d --build`, `BASE=http://localhost:18250 ADMIN_PASSWORD=... ONLY="smoke-..." bash scripts/smoke-all.sh`; bitince `docker compose down -v`. A7 ortak yığınına (18081) ve `flushall` ile başkalarının verisine DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W2-E: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (4)

#### T-057 - Rapor sistemi: kolektif şikâyetle otomatik gizleme (çete), hedef görünürlüğü denetlenmiyor (varlık oracle'ı), raporlanamayan türler (grup, duyuru, anket, kapak)  [ORTA | kanıt PS]
- **Kaynak bulgular:** A16-08, A1-15, A16-11 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** moderation/ReportService.applyPolicy (73-95), ReportTargetHandler SPI + handlers (community/CommunityReportHandlers, event/EventReportHandler, post/admin/PostReportHandlers, moderation/UserReportHandler, profile/privacy/AvatarReportHandler), ReportTargetType
- **Düzeltme:** exists(viewerId,id) ile loadVisible/engel/üyelik; eşiğe sayılan raporlayıcıları cihaz/IP kümesine göre tekilleştir; kulüp için eşik 5 + admin önceliği; CONVERSATION/ANNOUNCEMENT/POLL türleri; kapak türleri için handler veya enum'dan kaldır
- **Test gereksinimi:** Görünmeyen hedefe rapor 404; 3 aynı cihaz hesabı eşiği tetiklemez; smoke-admin-moderation

#### T-058 - Hesabı silip aynı e-postayla yeniden kayıt strike/şikâyet geçmişini sıfırlıyor; cihaz/IP erişim engeli kolay aşılıyor  [ORTA | kanıt S]
- **Kaynak bulgular:** A16-09, A16-10 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** profile/ProfileService.anonymize, auth/AuthService.register, accessban/ClientContexts, AccessBanFilter
- **Düzeltme:** Silinen e-posta özeti (email_sha256) + strike sayısı ayrı 'ihlal defteri'nde; yeniden kayıtta devral veya N gün bekle; açık şikâyeti olan hesabın silinmesi bekletilir; ban hedefi doğrulanmış e-posta özeti; cihaz kuralı ek sinyal
- **Test gereksinimi:** Strike'lı hesap sil+yeniden kayıt → strike devralınır
- **Bağımlılık:** K-15
- **KARAR (varsayılan = ÖNERİ):** K-15 Hesabı silip yeniden kayıt: strike devri | Seçenekler: (a) Hayır; (b) e-posta özeti + strike 12 ay ihlal defterinde, yeniden kayıtta devral; (c) açık şikâyeti olan hesap silme 7 gün beklesin | ÖNERİ: (b)+(c). Defter yalnız özet ve sayı tutar (KVKK: meşru menfaat, saklama süresi belgeli).

#### T-059 - Nefret söylemi / terör / kendine zarar için kelime kümesi yok; Kürtçe (Kurmancî/Zazakî) kapsanmıyor  [ORTA | kanıt P]
- **Kaynak bulgular:** A16-05 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** moderation/profanity listeleri (profanity_term, admin paneli), ProfanityHitLog
- **Düzeltme:** Ayrı kategori ve admin panelinden genişletilebilir küme; Kürtçe liste (topluluk danışmanı); hit günlüğü periyodik gözden geçirme
- **Test gereksinimi:** Kategori başına örnek testler
- **Bağımlılık:** K-27
- **KARAR (varsayılan = ÖNERİ):** K-27 Nefret/terör/Kürtçe kelime kümesi | Seçenekler: (a) Boş bırak; (b) admin panelinden genişletilebilir kategori + ilk 100 terim; Kürtçe için topluluk/Bingöl uzmanı | ÖNERİ: (b).

#### T-060 - Yazma/okuma uçlarında hız sınırı eksikleri (block, legal consents/accept, PATCH /users/me, GET /users/{id}, follow günlük tavan, suggestions vote, ticket close, presence, notifications, bookmarks, logout)  [DÜŞÜK | kanıt PS]
- **Kaynak bulgular:** A16-13, A1-25 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** BlockController, LegalController (+AcceptRequest.items @Size), ProfileController.update/get, FollowController, SuggestionController, TicketController, NotificationController, BookmarkController, AuthController.logout
- **Düzeltme:** İlgili uçlara limiter.check; profile:update 10/sa, görünen ad 7 gün cooldown (+geçmiş), block 60/sa, follow günlük 500, /users/{id} dk/gün kotası; RateLimitCoverageTest (her yazma ucunda limiter çağrısı)
- **Test gereksinimi:** RateLimitCoverageTest + uç başına 429 testi

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- moderation/**, accessban/**, ReportTargetHandler uygulamaları (community/event/post/profile handler dosyaları), ilgili controller'lara limiter

**Dokunmayacakların (başka iş akışının):**
- messaging, event mantığı

Paylaşılan dosya kilitleri: i18n-messages. Flyway aralığın: **V990-V994**, indeks öneki **mod9_**. Mobil l10n öneki: **-**.
Yalıtılmış yığın portların: BACKEND_PORT=18250, WEB_PORT=28250, COMPOSE_PROJECT_NAME=bu_w2e.

## 4. ÖZEL TALİMATLAR

Kartlardaki 'Düzeltme' satırları yeterlidir; karar bekleyen (K-xx) maddelerde ÖNERİ varsayılanını uygula ve raporda belirt. Dosya sahipliği çakışması görürsen DUR ve raporla.

## 5. TEST ve DOĞRULAMA

- backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar + RateLimitCoverageTest (yeni)
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- RateLimitCoverageTest yeşil
- smoke-admin-moderation, smoke-access-ban, smoke-block-shadow
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.

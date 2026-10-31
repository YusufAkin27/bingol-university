# W4-B - Backend + web ölü kod ve tekrar

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 4. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: L.

Sen **W4-B** iş akışı ajanısın (Backend/web ölü kod, video hattı (K-10), eski enum (K-11), CSV/Range tekrar). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: K-10, K-11, H-08
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar; web kalite kapıları

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w4b && mkdir -p /c/bu_verify_w4b && git archive HEAD | tar -x -C /c/bu_verify_w4b`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w4b/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w4b/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yalıtılmış yığın (smoke):** temiz kopyada `.env.example` -> `.env` (DB_PASSWORD, JWT_SECRET >=32, ADMIN_PASSWORD, `ADMIN_EMAILS=boss@bingol.edu.tr`, `MAIL_ENABLED=false`, `LEGAL_ENFORCE_REACCEPT=false`), `export COMPOSE_PROJECT_NAME=bu_w4b BACKEND_PORT=18410 WEB_PORT=28410`, `docker compose up -d --build`, `BASE=http://localhost:18410 ADMIN_PASSWORD=... ONLY="smoke-..." bash scripts/smoke-all.sh`; bitince `docker compose down -v`. A7 ortak yığınına (18081) ve `flushall` ile başkalarının verisine DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W4-B: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (6)

#### T-169 - Backend ölü kod: fırlatılmayan hata kodu çevirileri (POST_TOO_LONG, UNSUPPORTED_LANGUAGE, TURKISH_CONTENT_REQUIRED, DECRYPT_*), eski mail.* anahtarları, bağlanmamış app.dbmaint.log-days, ~25 çağrılmayan metot, PostRank yorum bileşeni, HelloController  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A18-B1, A18-B2, A18-B3, A18-B4, A18-B5 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** backend i18n/*.properties, application.properties (297), AccessBan/Community/Event/Media/Poll/Post/User/Mail repoları ve servisleri (B3 tablosu), post/PostRank, health/HelloController
- **Düzeltme:** B1 (3 dosyada sil + web admin.err.DECRYPT_* satırları), B2.1 (sil veya profanity_hit_log saklamasına bağla), B3 G dereceli sil, B4.2-3 comments parametresi, B5.1 sil
- **Test gereksinimi:** mvn test; I18nMessagesIntegrityTest; QueryRulesTest; RbacCoverageTest; OpenApiExportTest
- **Bağımlılık:** T-063 (log-days kararı)

#### T-170 - Gönderi video hattı tasarımca kapalı ama ~1000+ satır kod/ayar yaşıyor (PostMediaService.uploadVideo/readVideo, transcode/*, CDN, ayarlar); sohbet videosu meta temizliği için transcode koduna ihtiyaç var (çelişki)  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A18-B7, A18-B2 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** post/media/PostMediaService, media/PrivateMediaStore, media/PostVideoCipher, media/transcode/*, app.media.transcode/cdn.*, app.post.media.video-*
- **Düzeltme:** K-10: önce üretimde post_media kind='VIDEO' sayısı (H-08); transcode/VideoTranscoder korunur (T-038), gönderiye özgü yükleme/CDN/Range/ayarlar silinir
- **Test gereksinimi:** mvn test; smoke-posts
- **Bağımlılık:** K-10, H-08, T-038
- **KARAR (varsayılan = ÖNERİ):** K-10 Gönderi video hattı silinsin mi? | Seçenekler: (a) Hepsini sil; (b) gönderiye özgü yükleme/CDN/Range/ayarları sil, VideoTranscoder/TranscodeService koru ve sohbette kullan; (c) dokunma | ÖNERİ: (b). Önce üretimde SELECT count(*) FROM post_media WHERE kind='VIDEO' (H-08). 0 ise gönderi tarafı silinir; transcode çekirdeği sohbet videosu için yeniden kullanılır.

#### T-171 - Eski bildirim türleri POST_COMMENT/COMMENT_REPLY/POST_MENTION enum'da (eski satırlar okunabilsin diye bilerek bırakıldı)  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A18-B4 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** notification/NotificationType, NotificationSubtype, PushMessages, NotificationService; web adminPushOps.ts + admin-p09.ts
- **Düzeltme:** K-11: önce DELETE migration (notification + push_outbox eski satırlar), sonra enum; aksi halde yorumla bırak
- **Test gereksinimi:** Flyway PG; mvn test
- **Bağımlılık:** K-11, H-08
- **KARAR (varsayılan = ÖNERİ):** K-11 Eski bildirim enum'ları | Seçenekler: (a) Önce veri migration'ı sonra enum; (b) bırak | ÖNERİ: (b) şimdilik bırak + 'legacy' yorumu. Silinirse eski satırlar IllegalArgumentException verir; kazanç düşük. İlk sürüm yayını sonrası, veri temizliği migration'ıyla birlikte.

#### T-172 - Web ölü kod: PlaceholderPage, ~13 kullanılmayan dışa aktarım, ~50 sahipsiz sözlük anahtarı, 32 sahipsiz CSS sınıfı, en/ar admin sözlükleri (292 KB) ve tür-tipli API pilotu + 1.27 MB schema.d.ts (karar)  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A18-W1, A18-W2, A18-W3, A18-W4, A18-W5, A18-W6, A18-W7, A18-W8, A18-W9 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** web/src/components/PlaceholderPage.tsx, api/*, i18n/{en,ar}/admin-*.ts, bundles/admin.{en,ar}.ts, api/typed/*, api/generated/schema.d.ts, *.module.css
- **Düzeltme:** G olanları sil; W5/W6 için karar notu (proje kararı 'admin yalnız Türkçe' → en/ar admin dosyaları ve check-i18n TR_ONLY mantığı sadeleşir); npm run lint && typecheck && test && build && check:contract && check:i18n
- **Test gereksinimi:** web kalite kapıları yeşil; bundle bütçesi

#### T-173 - HTTP Range yazıcı 2 kopya (mesaj ve gönderi videosu) ve CSV akış kabuğu 4 kopya  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A18-K2, A18-K3 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** messaging/media/MessageAttachmentService.writeVideo (526), post/media/PostMediaService.writeVideo (500), admin/bulk/AdminBulkController.stream, event/admin/EventAdminOpsController, moderation/admin/ModerationExportController, support/admin/SupportExportController
- **Düzeltme:** common/web/RangeResponses ve CsvResponse.stream ortak yardımcılar (video_hatti kararına göre biri düşebilir)
- **Test gereksinimi:** mvn test; smoke-chat-receipts-video
- **Bağımlılık:** T-170

#### T-175 - Web tekrar: GuardedDialog ↔ GuardedAction, akademik/yönetim sayfaları iskeleti, UserDevices tekrarı  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A18-K14, A18-K15 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** web/src/components/admin/guard/*, GuardedDialog.tsx, pages/admin/Academic*, HiddenContentPage/StrikesPage, UserDevices.tsx
- **Düzeltme:** useGuardedMutation + AdminListPage iskeleti
- **Test gereksinimi:** web kalite kapıları

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- backend/**, web/src/**

**Dokunmayacakların (başka iş akışının):**
- mobil

Paylaşılan dosya kilitleri: i18n-messages. Flyway aralığın: **(veri temizliği gerekirse V1020+)**, indeks öneki **olu9_**. Mobil l10n öneki: **-**.
Yalıtılmış yığın portların: BACKEND_PORT=18410, WEB_PORT=28410, COMPOSE_PROJECT_NAME=bu_w4b.

## 4. ÖZEL TALİMATLAR

Kartlardaki 'Düzeltme' satırları yeterlidir; karar bekleyen (K-xx) maddelerde ÖNERİ varsayılanını uygula ve raporda belirt. Dosya sahipliği çakışması görürsen DUR ve raporla.

## 5. TEST ve DOĞRULAMA

- backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar; web kalite kapıları
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- mvn test + RbacCoverageTest + OpenApiExportTest
- web kapıları
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.

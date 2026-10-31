# W3-H - Test/CI, hukuk ve mağaza belgeleri

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 3. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: M.

Sen **W3-H** iş akışı ajanısın (Shots testleri, flaky, ws-test, smoke; yeni sözleşme sürümü; Play/Apple belgeleri). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: K-24, K-25 (avukat onayı olmadan sözleşme YAYINLANMAZ)
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: scripts + testler

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w3h && mkdir -p /c/bu_verify_w3h && git archive HEAD | tar -x -C /c/bu_verify_w3h`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w3h/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w3h/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yalıtılmış yığın (smoke):** temiz kopyada `.env.example` -> `.env` (DB_PASSWORD, JWT_SECRET >=32, ADMIN_PASSWORD, `ADMIN_EMAILS=boss@bingol.edu.tr`, `MAIL_ENABLED=false`, `LEGAL_ENFORCE_REACCEPT=false`), `export COMPOSE_PROJECT_NAME=bu_w3h BACKEND_PORT=18340 WEB_PORT=28340`, `docker compose up -d --build`, `BASE=http://localhost:18340 ADMIN_PASSWORD=... ONLY="smoke-..." bash scripts/smoke-all.sh`; bitince `docker compose down -v`. A7 ortak yığınına (18081) ve `flushall` ile başkalarının verisine DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W3-H: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (3)

#### T-139 - Aydınlatma/gizlilik metinleri yeni işlemleri kapsamıyor (galeriye kaydet, yerel mesaj önbelleği, çökme raporu, kamera/mikrofon, Sentry, email_sha256, push cihaz meta, sunucu günlükleri, yedekleme); metinler taslak; VERBİS/yurt dışı aktarım açık  [YÜKSEK | kanıt S]
- **Kaynak bulgular:** A8-04 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** backend db/migration (V820 legal_terms_v4), docs/legal/*.md, scripts/build-legal-migration-v820.js, docs/LEGAL_NOTES.md
- **Düzeltme:** Yeni sözleşme sürümü (yeni V-numarası) 'Cihazda saklananlar', 'Hata raporları', 'İzinler' bölümleriyle; avukat onayı OLMADAN yayınlanmaz (K-24, H-06)
- **Test gereksinimi:** LegalMigration*FileTest (LF normalize); acceptance-status
- **Bağımlılık:** K-24, H-06
- **KARAR (varsayılan = ÖNERİ):** K-24 Aydınlatma/sözleşme yeni sürümü | Seçenekler: (a) Avukat onayından sonra tek seferde; (b) önce taslak yayın | ÖNERİ: (a). Yeni V-numarası + scripts/build-legal-migration; LEGAL_ENFORCE_REACCEPT açma kararı ayrı (T-144 düzelince).

#### T-140 - Play Veri Güvenliği taslağı çökme günlüğü beyanıyla çelişiyor ('kişisel veri yok', 'kapatılamaz'); cihaz/OS kimlik satırları eksik  [YÜKSEK | kanıt S]
- **Kaynak bulgular:** A8-05 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** docs/store/data_safety.md (34), V860 crash_event, mobil crash_reporter
- **Düzeltme:** data_safety.md'yi rapor §3.2 tablosuna göre güncelle; çökme raporu 'ayarlardan kapatılabilir' (K-25); Apple App Privacy eşleşmesi docs/ios-store/APP_PRIVACY.md
- **Test gereksinimi:** Belge incelemesi; H-13 Play Console girişi
- **Bağımlılık:** K-25, H-13
- **KARAR (varsayılan = ÖNERİ):** K-25 Çökme raporu kapatılabilirliği ve beyan | Seçenekler: (a) Kapatılabilir (kod doğru), belgeyi düzelt; (b) zorunlu | ÖNERİ: (a). settingsCrashReportsDesc şeffaflık metni ilgili ekrana 'Ayrıntı' olarak bağlansın.

#### T-163 - Test/CI sağlamlığı: 29 *_shots_test.dart koşulsuz skip ve expect içermiyor, shots çürümesi (_tapText), zamana bağlı flaky test (push_foreground_test), ws-test.js eskimiş, smoke betikleri 429/ön koşul varsayımları, scripts/ci/* izlenmiyor, QA genişlik/erişilebilirlik kancası repoda yok  [DÜŞÜK | kanıt PS]
- **Kaynak bulgular:** A4-19, A4-21, A6-30, A6-31, A7-07, A7-14 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobile/test/redesign/*_shots_test.dart, test/push_foreground_test.dart (160-170), scripts/ws-test.js, scripts/smoke-*.sh, scripts/smoke-all.sh, scripts/ci/changes.sh+secret-files-check.sh
- **Düzeltme:** Etiketle hariç tut (dart_test.yaml store-shots), seçili sahnelere golden/semantik expect; fakeAsync; ws-test.js gölge engel semantiği + taze kullanıcı; smoke betiklerine Retry-After bekleme ve ön koşul doğrulama; FLUSH_CMD bash -c; QA_W/qa_a11y kancasını kalıcı yap; scripts/ci/* commit
- **Test gereksinimi:** flutter test paralel koşuda yeşil; ws-test.js 0 FAIL; smoke-all.sh

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- mobile/test/**, scripts/*.sh|js, docs/store/**, docs/ios-store/**, docs/legal/**, yeni migration (sözleşme sürümü)

**Dokunmayacakların (başka iş akışının):**
- uygulama kodu

Paylaşılan dosya kilitleri: docs-shared. Flyway aralığın: **V1010-V1019**, indeks öneki **lgl9_**. Mobil l10n öneki: **-**.
Yalıtılmış yığın portların: BACKEND_PORT=18340, WEB_PORT=28340, COMPOSE_PROJECT_NAME=bu_w3h.

## 4. ÖZEL TALİMATLAR

Kartlardaki 'Düzeltme' satırları yeterlidir; karar bekleyen (K-xx) maddelerde ÖNERİ varsayılanını uygula ve raporda belirt. Dosya sahipliği çakışması görürsen DUR ve raporla.

## 5. TEST ve DOĞRULAMA

- scripts + testler
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- smoke-all.sh yalıtılmış yığında yeşil
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.

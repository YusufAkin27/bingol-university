# W3-D - Belge, CLAUDE.md ve openapi

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 3. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: M.

Sen **W3-D** iş akışı ajanısın (A17/A18 belge düzeltmeleri, CLAUDE.md, openapi yenileme). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: Tüm önceki dalgalar
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: Belge bağlantı betiği; OpenApiExportTest

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w3d && mkdir -p /c/bu_verify_w3d && git archive HEAD | tar -x -C /c/bu_verify_w3d`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w3d/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w3d/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yığın gerekmez** (bu iş akışı mobil/web/belge ağırlıklı): testleri birim/widget/sahte sunucu (MockClient, yerel HttpServer; A15 yöntemi) ile yaz; bir backend yığını gerekirse yalnız kendi COMPOSE_PROJECT_NAME ve boş port ile kur, A7 ortak yığınına (18081) DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W3-D: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (2)

#### T-161 - Belge-kod tutarsızlıkları: push.md/MOBILE_API_GUIDE (collapse_key, akıllı bildirim), CLAUDE.md (Flyway aralıkları V880-V896, duman listesi, paket haritası academic/catalog, SchedulerLock ve zamanlayıcı tablosu, bilinen sınırlamalar: EN/AR çeviri ve sözleşme, bekleyen kayıt TTL 72 sa, ortam değişkenleri), MOBILE_UI haritası, DATABASE.md (37 tablo), ADMIN_API push-devices, MOBILE_API_GUIDE (thumbEdge, HTTP önbellek), CHANGELOG, MOBILE_PAGES, MOBILE_DESIGN_SYSTEM NUL baytı, push.md P2 notu, README BOM, betik atıfları, POSTS_DESIGN 410 anlatımı, çift belgeler  [ORTA | kanıt SV]
- **Kaynak bulgular:** A17-04, A17-06, A17-07, A17-08, A17-09, A17-10, A17-11, A17-13, A17-14, A17-15, A17-16, A17-17, A17-18, A17-19, A17-21, A17-22, A17-24, A9-41, A11-20, A7-13, A18-D1, A18-D2, A18-D3, A18-D4, A18-D5, A18-D6, A18-D7, A18-D8 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** CLAUDE.md, docs/changes/push.md, docs/MOBILE_API_GUIDE.md, docs/MOBILE_UI.md, docs/DATABASE.md, docs/ADMIN_API.md, docs/CHANGELOG.md, docs/MOBILE_PAGES.md, docs/MOBILE_DESIGN_SYSTEM.md (49), README.md, docs/POSTS_DESIGN.md, notifications_page ölü dalları (A17-21 W4-A), LegalMigrationV820FileTest (CRLF normalize)
- **Düzeltme:** A17/A18 belge listelerindeki her madde için düzeltme (rapor önerileri); NUL/0x08 baytı temizle; BOM kaldır; eskimiş belgeleri docs/archive/'e al; CLAUDE.md İlgili belgeler listesini güncelle (docs/audit eklenir); A17-21 ve A17-24 kod tarafı ilgili iş akışlarına
- **Test gereksinimi:** Belge bağlantı/dosya referansı betiği; grep NUL=0; LegalMigration*FileTest CRLF/LF
- **Bağımlılık:** tüm dalgaların sonu

#### T-162 - docs/openapi.json bayat: messagePreview (V896), PushDeviceInfo.lastPush*, LogoutRequest; her API değişiminde yeniden üretilmeli  [ORTA | kanıt PV]
- **Kaynak bulgular:** A7-09, A17-05 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** docs/openapi.json (OpenApiExportTest -Dopenapi.out), web check:contract, scripts/openapi-check.js
- **Düzeltme:** Her dalga SONUNDA koordinatör/W3-D yeniden üretir: OpenApiExportTest ile docs/openapi.json, sonra web check:contract + gen-mobile-models
- **Test gereksinimi:** scripts/openapi-check.js DRIFT yok
- **Bağımlılık:** tüm dalgaların sonu

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- CLAUDE.md, docs/** (audit hariç), README.md

**Dokunmayacakların (başka iş akışının):**
- kod

Paylaşılan dosya kilitleri: docs-shared. Flyway aralığın: **-**, indeks öneki **-**. Mobil l10n öneki: **-**.

## 4. ÖZEL TALİMATLAR

Kartlardaki 'Düzeltme' satırları yeterlidir; karar bekleyen (K-xx) maddelerde ÖNERİ varsayılanını uygula ve raporda belirt. Dosya sahipliği çakışması görürsen DUR ve raporla.

## 5. TEST ve DOĞRULAMA

- Belge bağlantı betiği; OpenApiExportTest
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- scripts/openapi-check.js DRIFT yok
- NUL/BOM yok
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.

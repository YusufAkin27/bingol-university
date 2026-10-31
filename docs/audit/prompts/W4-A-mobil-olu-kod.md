# W4-A - Mobil ölü kod ve tekrar birleştirme

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 4. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: L.

Sen **W4-A** iş akışı ajanısın (Erişilemeyen dosyalar, ölü semboller, ölü ARB anahtarları, tekrar birleştirme (arayüz kilitli)). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: W3-B bitmiş (ARB), W1-G T-091 bitmiş (SettingsPage)
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol + shots piksel karşılaştırması

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w4a && mkdir -p /c/bu_verify_w4a && git archive HEAD | tar -x -C /c/bu_verify_w4a`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w4a/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w4a/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yığın gerekmez** (bu iş akışı mobil/web/belge ağırlıklı): testleri birim/widget/sahte sunucu (MockClient, yerel HttpServer; A15 yöntemi) ile yaz; bir backend yığını gerekirse yalnız kendi COMPOSE_PROJECT_NAME ve boş port ile kur, A7 ortak yığınına (18081) DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W4-A: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (3)

#### T-167 - Mobil ölü kod: erişilemeyen 7 dosya (destek_widgets, profile_posts_section, profile_paged_list, SettingsPage, academic_picker, push_channels, media_source_sheet), ~45 çağrılmayan sembol, test köprüsü semboller, referanssız varlıklar  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A18-M1.1, A18-M1.2, A18-M1.3, A18-M1.4, A18-M1.5, A18-M1.6, A18-M1.7, A18-M3, A18-M4.2, A18-M4.3 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil lib/features/support/destek_widgets.dart, posts/profile_posts_section.dart, profile/profile_paged_list.dart, profile/settings_page.dart (T otokayit sonrası), widgets/academic_picker.dart, core/push/push_channels.dart, kök logo.png, mobile/design/*.dc.html, M3 sembol tablosu
- **Düzeltme:** G dereceli olanları sil; O dereceli olanlarda testleri canlı yola taşıyıp sil; her adımda flutter analyze && flutter test; settings_page silinmeden ÖNCE T otokayit anahtarı canlı sayfada olmalı
- **Test gereksinimi:** flutter analyze 0 warning; flutter test yeşil; gen-l10n
- **Bağımlılık:** T-091

#### T-168 - 397 ölü ARB anahtarı (%14.5): postCompose*/postView* 100, story* 25, profile* 33, p10* 16 ... (3 dil)  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A18-M2, A9-33 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil l10n/app_{tr,en,ar}.arb, scripts/i18n-audit.js (--unused-keys ekle)
- **Düzeltme:** Betikle sil + flutter gen-l10n; p* önekli anahtarlar yalnız devam eden iş yoksa; A9 dalgaları bittikten SONRA
- **Test gereksinimi:** gen-l10n; l10n_test; 3 dil anahtar eşitliği
- **Bağımlılık:** W3-B bitmeli

#### T-174 - Mobil tekrar: akademik seçici 3 kopya, 3 takip düğmesi, 8 EmptyCard + 5 TabBar, _two ×4 / süre biçimleyici / _isArabic / tarih biçimleyiciler, sayfalama iskeleti ×9, doğrulama kodu sayfaları ×2, disk önbellek kökleri ×3  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A18-K5, A18-K6, A18-K7, A18-K8, A18-K9, A18-K10, A18-K11, A18-K12, A18-K13 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil features/auth/widgets/auth_academic.dart, profile/edit_profile_page.dart, widgets/academic_pickers.dart, follow/*, profile/profily_widgets.dart, widgets/bu_state.dart, core/format.dart (yeni), core/cache/*
- **Düzeltme:** Davranışı koruyarak tek yardımcıya birleştir; arayüz KİLİTLİ olduğundan golden/shots ile piksel eşitliği doğrula
- **Test gereksinimi:** flutter test + shots karşılaştırması
- **Bağımlılık:** T-167

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- mobile/lib/**, ARB

**Dokunmayacakların (başka iş akışının):**
- backend, web

Paylaşılan dosya kilitleri: arb. Flyway aralığın: **-**, indeks öneki **-**. Mobil l10n öneki: **-**.

## 4. ÖZEL TALİMATLAR

Kartlardaki 'Düzeltme' satırları yeterlidir; karar bekleyen (K-xx) maddelerde ÖNERİ varsayılanını uygula ve raporda belirt. Dosya sahipliği çakışması görürsen DUR ve raporla.

## 5. TEST ve DOĞRULAMA

- mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol + shots piksel karşılaştırması
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- flutter analyze && flutter test yeşil
- golden/shots eşit
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.

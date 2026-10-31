# W2-H - Mobil performans ve boyut

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 2. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: M.

Sen **W2-H** iş akışı ajanısın (Jank paketi, görsel bellek, APK boyutu). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: K-02
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol + flutter build apk --analyze-size

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w2h && mkdir -p /c/bu_verify_w2h && git archive HEAD | tar -x -C /c/bu_verify_w2h`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w2h/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w2h/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yığın gerekmez** (bu iş akışı mobil/web/belge ağırlıklı): testleri birim/widget/sahte sunucu (MockClient, yerel HttpServer; A15 yöntemi) ile yaz; bir backend yığını gerekirse yalnız kendi COMPOSE_PROJECT_NAME ve boş port ile kur, A7 ortak yığınına (18081) DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W2-H: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (3)

#### T-109 - Mobil render/jank ORTA-DÜŞÜK paketi: alt gezinme BackdropFilter, sekme fade+scale, BuPageScaffold sliver fade, bildirim ListView(children), ChatTab _visible, 1 dk rozet zamanlayıcısı, avatar overdraw, gölge/opaklık kullanımı, galeri albüm sayımı, disk önbellek jsonEncode  [ORTA | kanıt T]
- **Kaynak bulgular:** A5-07, A5-08, A5-09, A5-10, A5-11, A5-16, A5-18, A5-19, A5-20, A5-21 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil features/shell/floating_nav.dart (154,230-251), app_shell.dart (227-243,62), widgets/bu_page_scaffold.dart (196), features/notifications/notifications_page.dart (324-450), features/chat/chat_tab.dart (464-476), widgets/bu_default_avatar.dart, message_bubble.dart (804), media_library.dart (75-78)
- **Düzeltme:** σ 8-10 veya düşük-uçta düz yüzey; yalnız Fade; ilk açılışta animasyonu atla; SliverList.builder + önceden grup başlığı indeksi; _visible önbellek; paused'ta rozet zamanlayıcıyı iptal; Opacity→FadeTransition; Future.wait; ham bodyBytes yaz
- **Test gereksinimi:** Sentetik frame testleri; profile modda GPU thread ölçümü (H-09)

#### T-110 - Görsel çözümleme bütçesi 80 MB/200 görsel (Keşfet 1000 px, sohbet 720 px); kırpma sayfasında tam çözünürlüklü Image.memory + codec ile ikinci çözümleme  [ORTA | kanıt T]
- **Kaynak bulgular:** A5-12, A5-13, A5-22 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil core/cache/cache_lifecycle.dart (50-54), posts/post_card.dart (44), chat/message_bubble.dart (740), media_crop/crop_page.dart (46-53,305), crop_engine.dart
- **Düzeltme:** Bütçeyi cihaz RAM'ine göre 50 MB; sohbet cacheWidth ≈ balon genişliği x dpr; ImageDescriptor ile boyut oku, Image.memory'ye cacheWidth; media_crop.dart/compose_post_page seçici sınırı doğrula
- **Test gereksinimi:** dumpsys meminfo ölçümü (H-09); crop birim testi

#### T-111 - AAB/APK boyutu: kullanılmayan marka PNG'leri (~1.05 MB), Lucide değişken fontları (1.4 MB), ML Kit paketli (2.7 MB), geniş R8 keep kuralları, Inter ağırlıkları  [ORTA | kanıt S]
- **Kaynak bulgular:** A5-14, A5-20, A18-M4 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil pubspec.yaml assets (branding), lucide_icons_flutter (dependency_overrides), proguard-rules.pro, fonts
- **Düzeltme:** Referanssız marka PNG'lerini pubspec assets'ten çıkar (test için test/ altına taşı); logo.png kök kopyası; lucide yerel kopya; R8 keep'leri daralt (FCM+QR+kamera duman testi); ML Kit unbundled yalnız K-02 kararıyla; intl sürüm sabitle
- **Test gereksinimi:** flutter build apk --analyze-size öncesi/sonrası; release AAB'de FCM/QR/kamera duman testi
- **Bağımlılık:** K-02
- **KARAR (varsayılan = ÖNERİ):** K-02 ML Kit QR modeli: paketli / paketsiz | Seçenekler: (a) Paketli kal; (b) unbundled | ÖNERİ: (a) Paketli kal. QR yalnız yoklamada ama Huawei/GMS'siz öğrenci cihazlarında bozulmak istenmez; boyut kazancını marka PNG, Lucide, R8 ve Inter'den al (~3.5-4 MB).

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- features/shell/floating_nav.dart, app_shell.dart (animasyon), widgets/bu_page_scaffold.dart, notifications_page.dart, widgets/bu_default_avatar.dart, media_crop/**, pubspec.yaml assets, proguard-rules.pro, fonts

**Dokunmayacakların (başka iş akışının):**
- chat_detail_page (W2-I)

Paylaşılan dosya kilitleri: arb. Flyway aralığın: **-**, indeks öneki **-**. Mobil l10n öneki: **p35**.

## 4. ÖZEL TALİMATLAR

Kartlardaki 'Düzeltme' satırları yeterlidir; karar bekleyen (K-xx) maddelerde ÖNERİ varsayılanını uygula ve raporda belirt. Dosya sahipliği çakışması görürsen DUR ve raporla.

## 5. TEST ve DOĞRULAMA

- mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol + flutter build apk --analyze-size
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- Boyut tablosu öncesi/sonrası
- release AAB'de FCM+QR+kamera duman testi (H-09)
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.

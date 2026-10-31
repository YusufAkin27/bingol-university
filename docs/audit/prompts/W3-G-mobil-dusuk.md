# W3-G - Mobil DÜŞÜK paketi

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 3. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: M.

Sen **W3-G** iş akışı ajanısın (Medya host denetimi, saat dilimi, lint, iOS yerel ağ, push küçükleri). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: K-07
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w3g && mkdir -p /c/bu_verify_w3g && git archive HEAD | tar -x -C /c/bu_verify_w3g`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w3g/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w3g/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yığın gerekmez** (bu iş akışı mobil/web/belge ağırlıklı): testleri birim/widget/sahte sunucu (MockClient, yerel HttpServer; A15 yöntemi) ile yaz; bir backend yığını gerekirse yalnız kendi COMPOSE_PROJECT_NAME ve boş port ile kur, A7 ortak yığınına (18081) DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W3-G: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (3)

#### T-080 - Push küçükleri: kampanya URL hedefi mobilde açılmıyor, anket kilidi/communities bayrağı kapsamı, sessiz bastırma metriği, kullanılmayan yük alanları, derleme koruması, ön plan sayaçları, push sağlık ekranı sunucu doğrulaması, belge sürüklenmesi  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A13-06, A13-07, A13-09, A13-10, A13-11, A13-12, A13-13, A13-15, A13-16, A13-17, A13-19, A13-08 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil notifications_page/notif_row, core/push/*, build.gradle.kts, PushGate, PushPayload, docs/MOBILE_PUSH.md
- **Düzeltme:** URL hedefi için url_launcher (https); push.suppressed{reason} sayacı; senderAvatarUrl şeritte kullan veya sunucudan çıkar; google-services.json yoksa sürüm derlemesi hata; GET /api/devices ile token son-6 doğrulaması; belge düzeltmeleri
- **Test gereksinimi:** İlgili birim testleri

#### T-107 - Yetkili medya isteklerinde ana makine denetimi yok (Authorization harici host'a gidebilir); 15 dk ömürlü jeton Image.network başlığında  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A4-12, A4-D1 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil features/chat/chat_media.dart (10), posts/post_models.dart (11), chat_media_viewer.dart (66,107), photo_autosave.dart (74)
- **Düzeltme:** Bearer yalnız apiOrigin ile aynı ana makinede ve https; başlık istek anında üretilir
- **Test gereksinimi:** chatMediaUrl/başlık yardımcıları: yabancı host'ta Authorization yok

#### T-176 - Mobil küçükleri: launchUrl hata yakalama yok, saat dilimi (etkinlik/menü cihaz saatine bağlı; Europe/Istanbul sabit olmalı), lint (discarded/unawaited_futures), mesaj önbelleği LRU yazma zamanı, iOS yerel ağ anahtarları yayında (CI siler), bundle id kararı, ölü yapılandırma  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A4-16, A4-17, A4-20, A12-14, A15-25, A8-21 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil home_tab.dart (244-249), events_page.dart (25,35), event_detail_page.dart (705), event_form_page.dart, menu_page.dart (44,106), core/api.dart (216), message_cache.dart, ios/Runner/Info.plist (NSAllowsLocalNetworking), scripts/ios/prepare-ci.sh
- **Düzeltme:** try/catch+toast; kampüs günü/saati için sabit +03:00 yardımcısı (akademik gibi); kritik yollarda unawaited+catchError ve CI'da unawaited_futures kademeli; Info.plist yerel ağ anahtarlarını Debug/Profile'a sınırla; mesaj önbelleği LRU okuma zamanı
- **Test gereksinimi:** TZ farkıyla menü today testi; flutter analyze
- **Bağımlılık:** K-07
- **KARAR (varsayılan = ÖNERİ):** K-07 iOS yayın kararları (IOS_RELEASE K1-K9) | Seçenekler: IOS_RELEASE.md §1 tablosu | ÖNERİ: Bundle id: tr.com.bukampus.app (Android ile aynı; App Store Connect'e yüklemeden ÖNCE karar verilmeli, sonra değişmez). iPhone-only. Ad 'BÜ Kampüs' + alt başlıkta bağımsız; üniversite destek mektubu varsa ek. 24 saat taahhüdünü ancak gerçekten üstlenebiliyorsanız yazın. Bireysel hesap, yalnız Türkiye.

### Paylaşılan T maddeleri (başka iş akışıyla ortak; YALNIZ senin parçan)

#### T-080 - Push küçükleri: kampanya URL hedefi mobilde açılmıyor, anket kilidi/communities bayrağı kapsamı, sessiz bastırma metriği, kullanılmayan yük alanları, derleme koruması, ön plan sayaçları, push sağlık ekranı sunucu doğrulaması, belge sürüklenmesi  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A13-06, A13-07, A13-09, A13-10, A13-11, A13-12, A13-13, A13-15, A13-16, A13-17, A13-19, A13-08 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil notifications_page/notif_row, core/push/*, build.gradle.kts, PushGate, PushPayload, docs/MOBILE_PUSH.md
- **Düzeltme:** URL hedefi için url_launcher (https); push.suppressed{reason} sayacı; senderAvatarUrl şeritte kullan veya sunucudan çıkar; google-services.json yoksa sürüm derlemesi hata; GET /api/devices ile token son-6 doğrulaması; belge düzeltmeleri
- **Test gereksinimi:** İlgili birim testleri

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- T listesindeki dosyalar

**Dokunmayacakların (başka iş akışının):**
- backend

Paylaşılan dosya kilitleri: arb. Flyway aralığın: **-**, indeks öneki **-**. Mobil l10n öneki: **p42**.

## 4. ÖZEL TALİMATLAR

Kartlardaki 'Düzeltme' satırları yeterlidir; karar bekleyen (K-xx) maddelerde ÖNERİ varsayılanını uygula ve raporda belirt. Dosya sahipliği çakışması görürsen DUR ve raporla.

## 5. TEST ve DOĞRULAMA

- mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- flutter analyze 0 warning
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.

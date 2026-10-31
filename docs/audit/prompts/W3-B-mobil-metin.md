# W3-B - Mobil metin ve çok dil

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 3. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: L.

Sen **W3-B** iş akışı ajanısın (Hitap, çoğul, terim, çeviri düzeltmeleri, 'Resmi' etiketi, A9 küçükleri). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: K-01, K-22, K-23
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol + i18n-audit.js

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w3b && mkdir -p /c/bu_verify_w3b && git archive HEAD | tar -x -C /c/bu_verify_w3b`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w3b/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w3b/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yığın gerekmez** (bu iş akışı mobil/web/belge ağırlıklı): testleri birim/widget/sahte sunucu (MockClient, yerel HttpServer; A15 yöntemi) ile yaz; bir backend yığını gerekirse yalnız kendi COMPOSE_PROJECT_NAME ve boş port ile kur, A7 ortak yığınına (18081) DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W3-B: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (7)

#### T-125 - 'Resmi' etiketi: sınav sekmesi/rozeti 'Resmi program' ve 'Resmi dönem'; kullanılmayan ARB anahtarları (eventListOfficial, homeOfficialEvent, akademik2OfficialTag); 'bağımsız/resmî değil' beyanı yalnız Çocuk güvenliği sayfasında, Hakkında/alt bilgide yok  [KRİTİK | kanıt PV]
- **Kaynak bulgular:** A9-04, A16-17, A3-14, A9-26 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil l10n (acadExamsTabOfficial vb.), features/academic/exams_page.dart (190,397,471), Profil>Hakkında; web SiteLayout alt bilgi + Hakkında + i18n tr/en/ar
- **Düzeltme:** K-01: sınav sekmesi 'Üniversite programı'; 'Resmi tatil' kalır; ölü anahtarlar silinir; Hakkında + web alt bilgi'ye 3 dilli tek satır bağımsızlık beyanı; resmî/resmi tek yazım
- **Test gereksinimi:** l10n_test; web i18n eşitliği (check:i18n)
- **Bağımlılık:** K-01
- **KARAR (varsayılan = ÖNERİ):** K-01 'Resmî' etiketi ve bağımsızlık beyanı | Seçenekler: (a) Etiketler kalsın; (b) 'Üniversite programı/takvimi' olarak değiştir; (c) tüm 'resmi' sözcükleri kaldır | ÖNERİ: (b): 'Resmi tatil' kalır; sınav/dönem etiketi 'Üniversite programı'; ölü ARB anahtarlarını sil; Profil>Hakkında ve web alt bilgisine tek satır 'Bağımsız bir uygulamadır; Bingöl Üniversitesi'nin resmî uygulaması değildir' (3 dil). Kod doğrulaması: rozet anahtarları kullanılmıyor, yalnız sınav sekmesi görünür; risk düşük-orta ama App Store 4.1 için ucuz önlem.

#### T-126 - Sen/siz hitabı aynı ekran ve akışta karışık (~120 siz, ~90 sen); sunucu bildirimlerinde 2 sen  [YÜKSEK | kanıt S]
- **Kaynak bulgular:** A9-06, A9-36, A9-38 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil l10n app_tr.arb (auth, profil2, p19-p23, chat...), backend messages/notif (notif.post.like.body, notif.user.follow.body)
- **Düzeltme:** K-22 kararı (öneri: siz); anahtar bazlı sen/siz listesi → ekran ekran toplu düzeltme; küçük TR yazım hataları (A9-36) birlikte
- **Test gereksinimi:** Betik: sen-ek tarama (-in/-ın yok); l10n_test
- **Bağımlılık:** K-22
- **KARAR (varsayılan = ÖNERİ):** K-22 Hitap tonu | Seçenekler: (a) siz; (b) sen | ÖNERİ: (a) siz: hukuk metni, e-posta, izin, hata ve sunucu bildirimleri zaten siz.

#### T-127 - Çoğul/tekil işlenmiyor (2736 anahtarda yalnız 2 ICU plural): EN '1 members/likes', AR 3-10/11+ biçimleri; backend AR notif.*.many; AR göreli zaman kısaltmaları; EN 'Members: {count}' yapısı  [YÜKSEK | kanıt S]
- **Kaynak bulgular:** A9-08, A9-39, A9-43 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil ARB (homeMemberCount, p12Count*, p11LikeCount, p13Poll*, p17DayPlanned, p20Range*, commonDaysAgo...), backend messages_ar.properties (204,74-76, notif.message.many)
- **Düzeltme:** ICU {n, plural, ...} (ar: zero/one/two/few/many/other); backend MessageFormat choice veya cümleyi sayı-dostu yeniden kur; AR anadil incelemesi H-14
- **Test gereksinimi:** l10n_test çoğul örnekleri (1,2,3,11,100)
- **Bağımlılık:** H-14

#### T-128 - Terim birliği: Kulüp/Topluluk, Şikâyet/Rapor, Yönetici/Admin/Moderatör/Organizatör (AR dört karşılık), Konuşma/Sohbet, Düzenleyen/Organizatör, Gönderi/Paylaşım/Yazı, Tek gösterimlik/gönderimlik, İptal/Vazgeç, Kontenjan/kota/kapasite  [YÜKSEK | kanıt S]
- **Kaynak bulgular:** A9-09, A9-10, A9-12, A9-13, A9-14, A9-15, A9-27, A9-28, A9-37 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil ARB, backend messages/community/event/modadmin/clubadmin*.properties, web site.ts + admin.nav
- **Düzeltme:** K-23 terim sözlüğü; bulk değişim betiği; web 'Topluluk' → 'Kulüp' (belge adı 'Topluluk Kuralları' hariç)
- **Test gereksinimi:** Terim tarama betiği 0 sapma; i18n bütünlük testleri
- **Bağımlılık:** K-23
- **KARAR (varsayılan = ÖNERİ):** K-23 Terim sözlüğü | Seçenekler: Kulüp/Sohbet/Şikâyet/Gönderi/Yönetici (sistem) - Kulüp yöneticisi - Moderatör/Organizatör/Yoklama/Giriş yap/Vazgeç ve İptal et/Tek gösterimlik/Kontenjan | ÖNERİ: Onayla (A9 önerisi); 'Topluluk Kuralları' belge adı olarak kalır; AR terimleri anadil incelemesinden sonra (H-14).

#### T-132 - Kalan sabit/yerelleştirilmemiş metinler ve ölü uzun açıklamalar: eventErrorText yedeği, academic_models yedekleri, settingsCrashReportsDesc kullanılmıyor (şeffaflık), profilePrefsDeleteAccountBody (yanıltıcı ölü anahtar), validateEmail ölü  [ORTA | kanıt S]
- **Kaynak bulgular:** A9-21, A9-22, A9-23, A7-16 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil features/events/event_parts.dart (57), academic_models.dart, auth_widgets.dart, widgets/report_sheet.dart, ARB; scripts/i18n-audit.js
- **Düzeltme:** eventErrorText yedeğini l.eventListRegClosedError ile değiştir; kullanılmayan uzun hata raporu metnini ilgili ekrana 'Ayrıntı' olarak bağla veya kaldır (K-25); yanıltıcı ölü anahtarları sil
- **Test gereksinimi:** i18n-audit.js: 78 satır → hedef 0
- **Bağımlılık:** K-25
- **KARAR (varsayılan = ÖNERİ):** K-25 Çökme raporu kapatılabilirliği ve beyan | Seçenekler: (a) Kapatılabilir (kod doğru), belgeyi düzelt; (b) zorunlu | ÖNERİ: (a). settingsCrashReportsDesc şeffaflık metni ilgili ekrana 'Ayrıntı' olarak bağlansın.

#### T-133 - Yanlış/yanıltıcı çeviriler ve EN tutarsızlıkları (Good afternoon, Delivered/Forwarded, log in/sign in, US/UK, Title Case 90+ metin, yayımla/yayınla, resmi/resmî, nokta/üç nokta)  [ORTA | kanıt S]
- **Kaynak bulgular:** A9-24, A9-25, A9-26, A9-31, A9-32, A9-35 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil ARB (homeGreetDay, chatMiscStatusDelivered, chatDetailForwarded, loginReplacedNotice en, errUploadQuota, notif.news.many.HABER...), web i18n
- **Düzeltme:** Tek EN yazım standardı (US), Log in/Log out/Sign up, cümle düzeni başlıklar, '…' tek biçim
- **Test gereksinimi:** Dizgi tarama betiği

#### T-135 - A9 küçükleri: tenvin yazımı karışık, TR küçük yazım hataları, {reason} birleştirme, sözleşme dil uyarısı, bildirim büyük harf, sürüm metni, CLAUDE.md eski cümle  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A9-34, A9-40, A9-42, A9-44, A9-45, A9-41 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil ARB, backend ar properties, legalReacceptIntro*
- **Düzeltme:** Tenvin tek biçim (ًا); sözleşme dil uyarısı ('bağlayıcı sürüm Türkçedir'); AR anadil incelemesi H-14
- **Test gereksinimi:** AR tarama betiği
- **Bağımlılık:** H-14

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- mobile/lib/l10n/*.arb, features içi sabit metinler, iOS InfoPlist.strings

**Dokunmayacakların (başka iş akışının):**
- backend properties (W3-C)

Paylaşılan dosya kilitleri: arb. Flyway aralığın: **-**, indeks öneki **-**. Mobil l10n öneki: **p41**.

## 4. ÖZEL TALİMATLAR

Kartlardaki 'Düzeltme' satırları yeterlidir; karar bekleyen (K-xx) maddelerde ÖNERİ varsayılanını uygula ve raporda belirt. Dosya sahipliği çakışması görürsen DUR ve raporla.

## 5. TEST ve DOĞRULAMA

- mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol + i18n-audit.js
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- tr/en/ar anahtar eşitliği
- terim tarama betiği 0 sapma
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.

# W3-A - Mobil tasarım tutarlılığı

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 3. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: XL.

Sen **W3-A** iş akışı ajanısın (Diyalog birleştirme, tipografi, dar ekran, kNavInset, medya balonları, dokunma, kontrast, tutarsızlıklar, RTL). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: K-20, K-21 kararları; W1-G/H/I, W2-G/H/I bitmiş
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol + A6 shots koşusu (tr390/ar390/tr320, 1.3x)

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w3a && mkdir -p /c/bu_verify_w3a && git archive HEAD | tar -x -C /c/bu_verify_w3a`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w3a/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w3a/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yığın gerekmez** (bu iş akışı mobil/web/belge ağırlıklı): testleri birim/widget/sahte sunucu (MockClient, yerel HttpServer; A15 yöntemi) ile yaz; bir backend yığını gerekirse yalnız kendi COMPOSE_PROJECT_NAME ve boş port ile kur, A7 ortak yığınına (18081) DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W3-A: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (10)

#### T-112 - Onay diyaloglarının 6 farklı düzeni; BuDialog yalnız 2 yerde; ham SnackBar 6 yerde; hap/banner/alt sayfa kopya sınıfları; token dışı yarıçap ~70 yer  [YÜKSEK | kanıt PS]
- **Kaynak bulgular:** A6-01, A6-20 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil widgets/bu_overlays.dart (BuDialog), chat_detail_page.dart _ChatConfirmDialog, chat_info_parts.dart, event_parts.dart, etkinlik2_settings_page.dart, event_form_page.dart, club_ref_widgets.dart, club_detail_sheets.dart, post_actions.dart, compose_post_page.dart, chat_sheet_parts.dart, semester_sheet.dart, 6 ham SnackBar
- **Düzeltme:** Tek BuDialog.confirm (simge, başlık, mesaj, tehlikeli düğme) ve kopyaların ona taşınması; ham SnackBar → BuToast; golden/ekran görüntüsü testleri ile piksel koruması (arayüz KİLİTLİ)
- **Test gereksinimi:** Golden/shots testleri; mevcut widget testleri; A6 dar ekran koşusu
- **Bağımlılık:** K-21
- **KARAR (varsayılan = ÖNERİ):** K-21 Tipografi ölçeği | Seçenekler: (a) Mevcut; (b) min 11 sp, mikro/caption birleşsin, iki tip sistemi tek; (c) tüm ölçek +1 sp | ÖNERİ: (b). Arayüz kilitli olduğundan değişiklik tüm shots'larla yeniden onaylanmalı; kullanıcı onayı şart.

#### T-113 - Yazı ölçeği %10 küçültülmüş (gövde 13.5, mikro 9.9); iki paralel tip sistemi (BuType ↔ TextTheme)  [YÜKSEK | kanıt S]
- **Kaynak bulgular:** A6-07 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil core/typography.dart, core/theme/bu_text_theme.dart, media_picker_page/media_preview_page fontSize:10
- **Düzeltme:** K-21: min 11-11.5 sp; BuType.micro/caption kullanımdan kaldır; iki sistemi birleştir; 1.3x büyük yazı testleri korunur
- **Test gereksinimi:** Büyük yazı + 320 dp taşma testi; kontrast testi
- **Bağımlılık:** K-21
- **KARAR (varsayılan = ÖNERİ):** K-21 Tipografi ölçeği | Seçenekler: (a) Mevcut; (b) min 11 sp, mikro/caption birleşsin, iki tip sistemi tek; (c) tüm ölçek +1 sp | ÖNERİ: (b). Arayüz kilitli olduğundan değişiklik tüm shots'larla yeniden onaylanmalı; kullanıcı onayı şart.

#### T-114 - Dar ekranda (320 dp, 1.3x) sohbet listesi başlıkları 3 harfe iniyor; tür çipi/saat/susturma genişliği yiyor  [YÜKSEK | kanıt P]
- **Kaynak bulgular:** A6-04 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil features/chat/chat_tab.dart (~878), chatlist_widgets.dart
- **Düzeltme:** Başlık satırı Row[Expanded(title), meta]; çip ve saat ikinci satıra; 1.3x/320 dp'de maxLines:2
- **Test gereksinimi:** tr320 1.3x shots sahnesi + taşma testi

#### T-115 - kNavInset=100 sabiti gerçek alt çubuk yüksekliğiyle uyuşmuyor (iPhone 34 dp / Android 3 tuş)  [YÜKSEK | kanıt S]
- **Kaynak bulgular:** A6-06 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil widgets/bu_widgets.dart (926), chat_tab, clubs_tab, discover_masonry, home_tab, home_parts, profile_tab, core/app_gate.dart (242)
- **Düzeltme:** FloatingNav.height + gap + MediaQuery.viewPadding.bottom hesaplayan tek yardımcı (BuScrollPadding); klavye açıkken küçülsün
- **Test gereksinimi:** Güvenli alan 34 ve 48 dp ile widget testi

#### T-116 - 'Fotoğrafları galeriye kaydet' açıklamasındaki asıl uyarı kırpılıyor — AMA ekran ulaşılamayan SettingsPage'de (çözüm T-091 ile yeni yerde)  [YÜKSEK | kanıt PV]
- **Kaynak bulgular:** A6-05 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil features/profile/settings_page.dart (350, ölü sayfa)
- **Düzeltme:** Anahtar canlı sayfaya taşınınca açıklama kırpılmadan uzayabilir; settings_page W4'te silinir
- **Test gereksinimi:** Yeni yerde 320 dp 1.3x shots
- **Bağımlılık:** T-091
- **KARAR (varsayılan = ÖNERİ):** K-12 Galeriye otomatik kaydetme | Seçenekler: (a) Varsayılan açık; (b) varsayılan KAPALI, açıkça etkinleştirme + ilk fotoğrafta rıza; (c) özelliği kaldır | ÖNERİ: (b); anahtar canlı 'Profil > Gizlilik ve veriler' sayfasına taşınır (şimdiki tek anahtar ulaşılamayan SettingsPage içinde); yalnız birebir sohbet; çıkışta ayar ve kayıt listesi temizlenir.

#### T-117 - Medya balonları: 3 fotoğraflı ızgarada boş 4. hücre, '+N' ile saat çipi çakışması, video yükleme halkası ile %65 çakışması, tek gösterimlik kartta kırpılan yönerge, arama kulüp satırı 320 dp taşması  [ORTA | kanıt P]
- **Kaynak bulgular:** A6-08, A6-09, A6-10, A6-11, A6-12 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil features/chat/message_bubble.dart (_LocalGrid/_MediaGrid, DurationPill 561, ViewOnceCard 972), features/search/search_page.dart (911-960)
- **Düzeltme:** 3 görselde 1 büyük + 2 küçük; +N katmanı üst-orta; yükleme göstergesi tek öğe; ViewOnceCard çok satır; kulüp kartı satırı Flexible
- **Test gereksinimi:** tr390/tr320/ar390 shots; taşma=0

#### T-118 - Dokunma hedefi 48 dp altı (beğeni 44, sekmeler 44, takvim hücreleri, gönderen avatarı 28) ve etiketsiz dokunulabilir düğümler  [ORTA | kanıt P]
- **Kaynak bulgular:** A6-14, A6-15 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil posts/like_button.dart (349), chat_new_parts.dart (154), chat_info_page.dart (573), chat_sheet_parts.dart (12,39), çip/segment/takvim bileşenleri
- **Düzeltme:** BuPressable/çip/segment minHeight 48 (görsel küçük kalabilir); 28 dp avatarı SizedBox(48)+Semantics(label: ad); büyük avatar etiketi
- **Test gereksinimi:** androidTapTargetGuideline/labeledTapTargetGuideline shots koşusu

#### T-119 - Kontrast: bildirim tercihlerinde pasif satır ~2.5:1, koyu temada açık/kapalı anahtar ayrımı zayıf, alfa'lı hint (%60-70) 2.6-3.3:1, ders renkleri koyu temada (RENK-1 ile kısmen kapandı)  [ORTA | kanıt PV]
- **Kaynak bulgular:** A6-17, A6-23, A6-25, A6-29 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil features/profile/notification_prefs_page.dart (~363), features/auth/widgets/auth_ref.dart (691), events/event_detail_page.dart (1124), event_form_page.dart (1337), polls/poll_detail_page.dart (874,951), academic/academic_models.dart (100-109 koyu doğrulama)
- **Düzeltme:** Pasif satıra kilit/'Duyurular'a bağlı' ipucu, başlık ≥4.5:1; hint alfa kaldır (t.mut doğrudan); koyu anahtar iz/başparmak 3:1; ders rengi koyu tema kontrast testi renk_paleti_test'e ekle
- **Test gereksinimi:** renk_paleti_test genişlet; shots koyu tema

#### T-120 - Tutarsızlıklar: avatar şekli (kare/daire), üstbilgi biçimi, ikon seti karışımı (Material+Lucide, 38 kaçak), segment font boyutu 320 dp, kamera izin ekranı çıkmaz sokak, kulüp logosu baş harf ve ölü SohbetyAvatar, ölü BuPageRoute  [ORTA | kanıt PS]
- **Kaynak bulgular:** A6-13, A6-18, A6-19, A6-21, A6-22, A6-24, A6-32 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil chatlist_widgets.dart (216), conversation_actions.dart (29), settings/notification_prefs/push_help headers, floating_nav.dart, discover_tab.dart (173), media_camera_page izin ekranı, events_page segment, sohbety_widgets.dart (256), widgets/bu_motion_widgets.dart (210)
- **Düzeltme:** K-20 avatar kuralı; tek BuHeader; ikon kararı belgeli (alt çubuk Material kalacaksa kasıtlı); kamera izin ekranına 'Ayarlardan aç'; ölü kod W4
- **Test gereksinimi:** Shots karşılaştırma; ilgili widget testleri
- **Bağımlılık:** K-20
- **KARAR (varsayılan = ÖNERİ):** K-20 Avatar şekli kuralı | Seçenekler: (a) Hepsi daire; (b) kişi daire, grup/kulüp/etkinlik yuvarlak kare | ÖNERİ: (b), sohbet listesi ve başlık aynı kuralı kullanır.

#### T-121 - RTL: tek yönlü left/right dolgu ve yön duyarsız simgeler; karma yönlü ipucu; Arapça yazı tipi Inter'da yok  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A6-26, A6-27, A6-28, A4-18 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil notification_prefs_page.dart (363), events_page.dart (1723), widgets/academic_picker.dart (144,206 — W4'te silinecek), club_detail_sheets/page, academic_calendar_page.dart (113), buDirIcon eksik yerler
- **Düzeltme:** EdgeInsetsDirectional.only(start:); buDirIcon; e-posta/numara ipucunu Directionality.ltr içine al; Arapça için paketli Naskh/IBM Plex Arabic değerlendir (O-7)
- **Test gereksinimi:** Directionality.rtl golden/ölçüm testi

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- mobile/lib/widgets/**, features/** UI dosyaları (T listesi), core/typography.dart, core/theme/**

**Dokunmayacakların (başka iş akışının):**
- backend, web

Paylaşılan dosya kilitleri: arb. Flyway aralığın: **-**, indeks öneki **-**. Mobil l10n öneki: **p40**.

## 4. ÖZEL TALİMATLAR

Kartlardaki 'Düzeltme' satırları yeterlidir; karar bekleyen (K-xx) maddelerde ÖNERİ varsayılanını uygula ve raporda belirt. Dosya sahipliği çakışması görürsen DUR ve raporla.

## 5. TEST ve DOĞRULAMA

- mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol + A6 shots koşusu (tr390/ar390/tr320, 1.3x)
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- Piksel eşitliği: golden/shots öncesi-sonrası (arayüz KİLİTLİ)
- K-20/K-21 onaylı
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.

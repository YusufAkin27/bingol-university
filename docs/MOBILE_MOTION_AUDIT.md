# Mobil hareket (animasyon) denetimi

Tarih: 2026-11-02. Kapsam: `mobile/lib` (300 Dart dosyası). İlkeler: LottieFiles `motion-design-skill` (MIT; süre/eğri/yay tabloları, kalite kontrol listesi), Apple HIG hareket/geri bildirim/erişilebilirlik sayfaları. Karar: "kurumsal + sıcak" (bkz. [MOBILE_MOTION.md](MOBILE_MOTION.md)). Arayüz KİLİTLİ: yalnız hareket değişti, görünüm/yerleşim/iş mantığı değişmedi.

Kapsam dışı (başka ajanlar çalışıyor, DOKUNULMADI): `core/push/*`, `features/notifications/*`, `features/campus*`, `core/analytics*`. Bu dosyalara düşen notlar sondaki "Sonradan uygulanacaklar" bölümündedir.

## 1. Envanter özeti

| Yapı | Adet | Not |
|---|---|---|
| `AnimationController` | 24 | 5 döngü (`repeat`; hepsi azaltılmış harekette durur) |
| `AnimatedContainer` / `AnimatedSize` / `AnimatedSwitcher` | 53 / 28 / 26 | seçim, açılır form alanı, ikon değişimi |
| `AnimatedOpacity` / `AnimatedScale` / `AnimatedAlign` / `AnimatedDefaultTextStyle` | 28 / 15 / 8 / 19 | çoğu `BuMotion.of` ile |
| `TweenAnimationBuilder` | 21 | sayaç, ilerleme, renk |
| `Hero` (`BuHero`, `newsHero`) | 15 | haber/gönderi fotoğrafı uçuşu |
| Sayfa geçişleri | tema + `BuPageRoute` + 1 özel `PageRouteBuilder` (fotoğraf görüntüleyici) | `ThemeData.pageTransitionsTheme` tek yerde (`BuPageTransitions`) |
| Alt sayfa / diyalog / toast | 37 sayfa açılışı, 3 ortak stil (`BuMotionStyles`) | 5 alt sayfa ortak stili kullanmıyordu |
| `BuPressable` | 121 kullanım | basma geri bildirimi tek bileşen |
| Kademeli giriş (`BuStaggerItem`/`BuFadeSlideIn`) | 48 | |
| Özel painter animasyonu | iskelet, beğeni patlaması, QR köşeleri/tarama çizgisi, yazıyor noktaları | |
| Lottie | yok (paket de yok) | |

Önceki "D1" çalışması sayesinde temel sağlamdı (BuMotion, BuPressable, BuStaggerItem, BuMotionStyles, tahmini geri tema); denetim bu temelin kaçaklarını ve eski tek-sıfır sürelerini buldu.

## 2. Bulgular

Önem ölçeği kontrol listesindeki gibidir (CRITICAL: doğrusal uzamsal eğri, yalnız opaklıkla iletilen önemli durum, >1/3 ekran, kademe >500 ms, düzen kasması; HIGH: süre/eğri uyuşmazlığı, azaltılmış hareket alternatifi yok, kişilik tutarsızlığı; MEDIUM: ince ayar).

**Toplam: 31 bulgu. CRITICAL 0, HIGH 21 (21 düzeltildi), MEDIUM 10 (6 düzeltildi, 4 bilinçli olarak bırakıldı).**

CRITICAL: bulunmadı. Doğrusal eğri yalnız geri sayım ilerleme çubuğunda (`etkinlik2_widgets.dart`, ilerleme için serbest); kademe toplamı en çok 350 ms; tek karede 20'den çok eleman hareket etmiyor. "Yalnız opaklık" olan iskelet -> içerik geçişi ölçek olarak CRITICAL sayılabilirdi, ancak içerik gelişi önemli durum değişimi sayılmadığı için HIGH (H-07) olarak ele alındı ve düzeltildi.

### HIGH

| # | Dosya(lar) | Önce | İlke ihlali | Düzeltme | Durum |
|---|---|---|---|---|---|
| H-01 | `core/theme/bu_motion.dart` (+ ~210 çağrı yeri) | 150 / 250 / 400 ms | Karar ölçeği 200 / 300 / 450; iki ayrı süre sözlüğü | `core/motion/bu_motion.dart` tek kaynak; `short`=quick 200, `medium`=standard 300, `long`=page 400; eski adlar takma ad | Düzeltildi |
| H-02 | `forgot_password_page` (3), `login_page` (2), `auth_academic` (1) | `AnimatedSize` 200-240 ms sabit, bazılarında `BuMotion.of` yok | Azaltılmış hareket alternatifi yok; sabit süre | `BuMotion.of(context, BuMotion.medium)` + `standard` eğri | Düzeltildi |
| H-03 | `main.dart` (karşılama -> giriş) | 320 ms, `easeOutCubic`/`easeIn`, azaltılmışta bile kayıyor | Azaltılmış hareket yok; ad-hoc eğri | `fadeOf` + `exit` (0,7x) + emphasizedDecelerate/accelerate; azaltılmışta 100 ms solma, kayma yok | Düzeltildi |
| H-04 | `notification_prefs_page` (anahtar), `legal_reaccept_page` (onay kutusu) | 160 / 200 ms sabit | Azaltılmış hareket yok | `BuMotion.of` + standard | Düzeltildi |
| H-05 | `chat_detail_page` (4: alıntıya git, sona git, aşağı kaydır, `ensureVisible`), `club_form_page` (2), `discover_masonry` (1) | `animateTo` 200-300 ms, her zaman animasyonlu | Vestibüler tetikleyici; azaltılmış hareket yok | `BuMotion.scrollTo`: azaltılmışta `jumpTo`, aksi halde 300 ms standard | Düzeltildi |
| H-06 | 41 `Curves.*` kullanımı (24 dosya) | easeOut x15, easeOutCubic x15, easeOutBack x8, easeInOut x4, easeIn x1 | Ad-hoc eğriler, kişilik tutarsız; easeOutBack ~%10 taşma | Standard / decelerate / accelerate / `success` (~%7); döngülerde sinüs (`easeInOutSine`) | Düzeltildi |
| H-07 | `core/motion/bu_swap_in.dart` (10 ekran), `widgets/bu_state.dart` (`_Enter`) | 250 ms yalnız opaklık, çıkış=giriş; durum içeriği 400 ms + 14 dp | Önemli durumda yalnız opaklık; çıkış > giriş*0,7 | Fade + 8 dp yükselme, çıkış 0,7x; `BuStateSwitcher`, `BuFadeSlideIn` | Düzeltildi |
| H-08 | `posts/like_button.dart` (kalp) | 520 ms, tepe 1,38 (%38), çıkışta easeInOut | Beğeni taşması %2-5 olmalı | 450 ms, 1 -> 1,08 (decelerate) -> 1 (settle %3) | Düzeltildi |
| H-09 | `posts/like_button.dart` (patlama) | Her karede `MaskFilter.blur(10)` | Pahalı boyama | Tek dolgu halkası, blur yok | Düzeltildi |
| H-10 | `posts/like_button.dart` (çift dokunma kalbi) | 520 ms, çıkışta 1,0 -> 1,3 büyüyor | Çıkışta büyütme yasak | 450 ms, .85 -> 1,05 -> 1, çıkışta ölçek sabit | Düzeltildi |
| H-11 | `auth/widgets/auth_motion.dart` (`AuthShake`) | 380 ms, +-9 dp, 2,5 salınım | Hata sarsıntısı hafif olmalı (300-400 ms, 2-3 salınım) | Merkezi `BuShake`: 320 ms, +-6 dp, 2,5 sönümlü salınım; taşma/ölçek yok | Düzeltildi |
| H-12 | `widgets/bu_pressable.dart` (121 kullanım) | Basma ve bırakma 150 ms, aynı eğri | Bırakma 200-300 ms'de yerleşmeli; basma <150 ms | Basma 120 ms standard, bırakma 300 ms `settle` (%3) | Düzeltildi |
| H-13 | `sohbety_sheet`, `home_tab` ("daha fazla"), `legal_reaccept_page`, `academic_pickers`, `report_sheet` | Framework varsayılan alt sayfa animasyonu | Ortak giriş/çıkış stili yok; kişilik tutarsız | `sheetAnimationStyle: BuMotionStyles.sheet(context)` (300 giriş / 200 çıkış, azaltılmışta 0) | Düzeltildi |
| H-14 | `chat/bubble_entry.dart` | Gönderilen 250 ms + 14 dp, alınan 150 ms | Sohbette ağır hareket olmamalı | Hepsi 200 ms, 10 dp; yalnız taze balonda | Düzeltildi |
| H-15 | `core/motion/bu_count_up.dart` (`BuPop`, rozet) | tepe 1,18, 250 ms | Rozet/geri bildirim taşması >%10 | tepe 1,10 (başarı bütçesi), 300 ms, `settle` ile yerleşme | Düzeltildi |
| H-16 | `widgets/bu_motion_widgets.dart` (`BuStaggerItem`) | adım 40 ms, süre 400 ms | Standart kademe 50-100 ms | adım 50 ms (`BuMotion.stagger`), süre 300 ms, azami 8 öğe (toplam <=350 ms gecikme) | Düzeltildi |
| H-17 | `chat/message_actions.dart` (mesaj menüsü), `chat_tab`, `message_requests_page`, `follow_requests_page` | 180 / 220 ms sabit | Sabit süre, azaltılmış hareket (zaten vardı) ama token dışı | `BuMotion.short` | Düzeltildi |
| H-18 | `chat/message_bubble.dart` (kaydırıp yanıtla geri dönüş) | 220 ms sabit | Token dışı | `BuMotion.short` | Düzeltildi |
| H-19 | `posts/post_detail_page`, `widgets/bu_overlays` (klavye payı) | 120 ms sabit | Token dışı | `durations.micro` | Düzeltildi |
| H-20 | `chat/chat_wallpaper.dart` | 150 ms sabit | Token dışı | `BuMotion.short` | Düzeltildi |
| H-21 | `home/home_parts.dart` (bölüm göster/gizle) | 220 ms sabit | Token dışı | `BuMotion.medium` | Düzeltildi |

### MEDIUM

| # | Dosya(lar) | Durum önce | Düzeltme | Durum |
|---|---|---|---|---|
| M-01 | `widgets/sistem_widgets.dart` (`MaintenanceBand`/`StaleBanner`), `menu/menu_parts.dart` (`MenuStaleBanner`) | Bakım/eski veri bantları hareketsiz beliriyor | `BuFadeSlideIn(offset: -8)`: üstten 8 dp süzülür, 300 ms (yer açma animasyonu yok, yerleşim aynı) | Düzeltildi |
| M-02 | `widgets/bu_skeleton.dart` | Eğri `easeInOut`, 1100 ms yarım dalga | Sinüs eğrisi, `durations.ambient` (1400 ms); azaltılmışta durur (zaten vardı) | Düzeltildi |
| M-03 | `system/gate_views.dart` | `easeInOut`, 4 nefes | Sinüs eğrisi (döngü); azaltılmışta durur | Düzeltildi |
| M-04 | `auth/otp_code_boxes.dart` (rakam girişi) | `easeOutBack` | `BuMotion.success` | Düzeltildi |
| M-05 | `core/motion/bu_count_up.dart` (`BuCountUp`) | 400 ms | 450 ms (`slow`, sayaç) | Düzeltildi |
| M-06 | Çoklu: `widgets/bu_motion_widgets.dart` `BuStaggerItem` iç stagger sabiti | `BuMotion.stagger` Duration alanıydı | `stagger(index, {step,max})` işlevi | Düzeltildi |
| M-07 | `AnimatedSize` (28 yer) | Düzen tetikleyici | Kalan: 200-300 ms, form alanı/aç-kapa gerçek yerleşim değişimi; transform ile eşdeğeri yok; ölçülmüş kare düşmesi yok | Bırakıldı (cihazda ölçülmedi) |
| M-08 | `AnimatedContainer` (53 yer, çoğu seçim rengi/kenarlık/ölçü) | Boyut içerenler düzen tetikler | Kalan: küçük (anahtar başı, çip) | Bırakıldı |
| M-09 | `chat/message_actions.dart` (`showGeneralDialog`) | Giriş ve çıkış aynı süre | Çıkış süresi ayrı verilemiyor (API sınırı); süre 200 ms, kısa | Bırakıldı |
| M-10 | `platform/qr_scan_page.dart` tarama çizgisi | 2200 ms x 6 = 13 sn | Sonlu (6 tur), azaltılmışta durur, başarıda kilitlenir; 5 sn üstü ama pil/dikkat yönünden sınırlı | Bırakıldı |

## 3. Zaten uyumlu olanlar (değiştirilmedi)

- Sayfa geçişi: Android `PredictiveBackPageTransitionsBuilder`, iOS `CupertinoPageTransitionsBuilder` (kenardan geri kaydırma), tek yerden `BuPageTransitions.theme`; azaltılmışta geçiş anlık.
- Alt sekme geçişi: `AppShell` sekme içeriği 300 ms çapraz solma (anlık değil); `FloatingNav` ikon/rozet geçişleri token'lı.
- Sohbet: kaydırırken animasyon yok; yalnız taze mesaj balonu fade (+ gönderilende kısa yükselme); iskelet tek ticker.
- Toast/diyalog: `BuMotionStyles` (giriş 300, çıkış 200, azaltılmışta 0).
- Pull-to-refresh: Material `RefreshIndicator` (marka renkleri + hafif titreşim), özel animasyon yok.
- Hero: `BuHero` köşe yarıçapı uçuşu; azaltılmış hareketle de çalışır (rota animasyonu 0).

## 4. Sonradan uygulanacaklar (bu ajanın dokunmadığı dosyalar)

| Dosya | Not |
|---|---|
| `core/push/push_banner.dart` | Bildirim şeridi 220 ms sabit + `Curves.easeOutCubic`: `BuMotion.curves.emphasizedDecelerate` ile 300 ms giriş, kapanış `BuMotion.exit` (210 ms) + `accelerate`; üstten kayarak insin. Azaltılmışta yalnız 100 ms solma (`BuMotion.fadeOf`). |
| `features/notifications/notif_row.dart`, `notifications_page.dart` | `AnimatedScale` rozet için `BuMotion.curves.settle`; liste ilk belirişi için `BuFadeSlideIn(index: i)` yalnız ilk 6-8 öğe; okundu geçişleri kısa (`quick`). Takma ad süreler yeni ölçeğe zaten bağlı (otomatik). |
| `features/campus*` | Yeni ekranlar `BuFadeSlideIn`/`BuStateSwitcher`/`BuPressable` kullanmalı; sabit `Duration` ve `Curves.*` yazılmamalı. |
| `core/analytics*` | Hareket yok. |

Not: bu dosyalar `BuMotion.short/medium/emphasizedDecelerate` adlarını kullanıyor; adlar korunduğu için derleme bozulmadı, süreler yeni ölçeğe otomatik taşındı.

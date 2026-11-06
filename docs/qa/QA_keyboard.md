# QA: Klavye, ekran taşması ve buton erişilebilirliği (2026-11-06)

Dal: `fix/keyboard-20261106`. Kapsam: `mobile/` (Flutter). Ortak altyapı: `mobile/lib/widgets/bu_keyboard.dart`
(`widgets/bu.dart` ile dışa açılır). Testler: `mobile/test/qa_keyboard/`.

## Kök nedenler

1. **`Scaffold.bottomNavigationBar` klavyenin ARKASINDA kalır.** Scaffold gövdeyi klavye kadar küçültür ama alt çubuğu
   ekranın en altına koyar; klavye onu örter. `BuPageScaffold.bottomBar` bunu doğrudan geçiriyordu: destek talebi yanıt
   yazma alanı ve etkinlik ayarlarındaki Kaydet çubuğu klavye açıkken görünmüyordu. Çözüm: `BuKeyboardLift` (alta klavye
   yüksekliği kadar boşluk + alt ağaçta `viewInsets` sıfırlanır, çift boşluk yok); `BuPageScaffold` artık her `bottomBar`'ı
   bununla sarar, `BuFormActionBar` da kendi içinde kullanır.
2. **Uzun formlarda eylem düğmesi kaydırmanın en sonundaydı** (anket, destek talebi, ders/sınav, kulüp, etkinlik formu):
   klavye açıkken düğmeye ulaşmak için uzun kaydırma gerekiyordu. Çözüm: düğme sabit alt eylem çubuğuna (klavyenin hemen
   üstünde) alındı.
3. **Boş alana dokununca klavye kapanmıyordu.** Çözüm: uygulama kökünde `BuTapOutsideUnfocus` (translucent, düğme/alan
   dokunuşlarını engellemez). `BuPageScaffold` listeleri artık `keyboardDismissBehavior: onDrag`.
4. **Sayfa değişince klavye/odak.** Önceki sayfadaki odak geri dönüşte yeniden klavye açabiliyordu. Çözüm:
   `BuFocusRouteObserver` (yalnız `PageRoute` itme/geri/değiştirme; alt sayfa/diyalog etkilenmez).
5. **Alt sayfa kapanınca odak kalıyordu.** `BuSheet.show` artık, açılırken klavye kapalıysa, kapanışta odağı temizler.
6. **Yeni anket seçeneği klavyenin arkasında kalabiliyordu.** Anket ve forum anket oluşturucuda ekleme sonrası
   `BuKeyboard.ensureVisible`.
7. **Etkinlik formu, kulüp bilgi kutusu**: iki `Flexible` içeren `Row` 320 dp + 2.0 yazı ölçeğinde 15 px taşıyordu
   (klavyeyle ilgisiz, testte yakalandı) -> `Wrap`.
8. `SingleChildScrollView` Scaffold gövdesinde gevşek kısıt aldığı için kısa formda kaydırma alanı içeriğe büzülür ve altındaki
   boşluk ölü kalırdı -> `BuFormScaffold` içinde `SizedBox.expand`.

Yanlış yol notu: iç içe `Scaffold(resizeToAvoidBottomInset)` + elle `viewInsets` padding (çift boşluk) aranmış, ekranların
tamamında bulunmadı: elle `viewInsets` yalnız `resizeToAvoidBottomInset:false` olan forum yorum ekranlarında ve Scaffold
dışındaki alt sayfalarda var (tek boşluk, doğru).

## Ortak altyapı (`bu_keyboard.dart`)

| Öğe | Görev |
|---|---|
| `BuKeyboard.inset/isOpen/dismiss/ensureVisible/bottomPadding` | `viewInsetsOf` tabanlı (yalnız ilgili alt ağaç yeniden kurulur); odaklı alanı görünür kılar |
| `BuTapOutsideUnfocus` | boş alana dokununca odağı bırakır |
| `BuEnsureVisibleOnFocus` | odak alınca satırı görünür tutar |
| `BuKeyboardLift` | `bottomNavigationBar` içeriğini klavyenin üstüne taşır |
| `BuFormActionBar` | sabit alt eylem çubuğu (SafeArea + klavye kaldırma, tek boşluk) |
| `BuFormScaffold` | kaydırılabilir gövde + sabit eylem çubuğu iskeleti |
| `BuFocusRouteObserver` | sayfa geçişinde odağı bırakır |
| `showBuFormSheet` | `BuSheet` (isScrollControlled, safe area, klavyeye göre küçülen gövde, sabit eylemler, kapanışta unfocus) |

## Envanter (TextField içeren 55 dosya)

Durum: DÜZELTİLDİ = bu dalda değişti, TEST = klavyeli widget testi var, TAMAM = incelendi, sorun yok (yeniden yazılmadı).

| Dosya / ekran | Bulgu | Kök neden | Düzeltme | Test |
|---|---|---|---|---|
| `polls/poll_form_page.dart` (anket oluştur) | Yayınla en sonda; yeni seçenek klavyenin altında kalabilir | sabit çubuk yok, ensureVisible yok | `bottomBar: BuFormActionBar`, `_revealAddRow`, submit'te unfocus | TEST `keyboard_screens_test` (12 seçenek, 320x568, x1.3/2.0) DÜZELTİLDİ |
| `support/support_new_ticket_page.dart` | Gönder en sonda | sabit çubuk yok | `BuFormActionBar` | TEST DÜZELTİLDİ |
| `support/support_ticket_page.dart` (yanıt yaz) | Yanıt alanı klavyenin arkasında | `bottomBar` = `bottomNavigationBar` | `BuPageScaffold` -> `BuKeyboardLift` | TEST DÜZELTİLDİ |
| `events/etkinlik2_settings_page.dart` | Kaydet çubuğu klavyenin arkasında | aynı | aynı (`BuKeyboardLift`) | TEST DÜZELTİLDİ |
| `events/event_form_page.dart` | Oluştur en sonda; 2.0 ölçekte taşma | sabit çubuk yok; Row+2 Flexible | `BuFormActionBar`, `Wrap` | TEST DÜZELTİLDİ |
| `clubs/club_form_page.dart` | Oluştur/Kaydet en sonda | sabit çubuk yok | `BuFormActionBar` | TEST DÜZELTİLDİ |
| `academic/course_form_page.dart`, `exam_form_page.dart` | Kaydet en sonda | sabit çubuk yok | `AkadBottomBar` (Scaffold gövdesinde, klavye üstü) + `onDrag` | TEST DÜZELTİLDİ |
| `forum/.../poll_builder.dart` | yeni seçenek klavyenin altında kalabilir | ensureVisible yok | `BuKeyboard.ensureVisible` | mevcut forum testleri |
| `widgets/bu_overlays.dart` (`BuSheet`/`BuBottomSheet`) | kapanışta odak kalır; sürükleyince klavye kapanmaz | - | `whenComplete` unfocus, `onDrag`, `viewInsetsOf` | TEST (`showBuFormSheet`) DÜZELTİLDİ |
| `widgets/bu_page_scaffold.dart` (çok sayıda sayfa) | `bottomBar` klavye arkası; dokununca kapanma yok | bkz. kök neden 1, 3 | lift + `onDrag` + `BuTapOutsideUnfocus` | TEST DÜZELTİLDİ |
| `auth/widgets/auth_ref.dart` (`RefPage`: giriş, kayıt, şifre sıfırlama, doğrulama kodu, 2FA) | boş alana dokununca kapanma | - | `BuTapOutsideUnfocus` (gövde zaten kaydırılabilir + onDrag) | auth testleri TAMAM |
| `main.dart` (kök) | sayfa değişince odak; boş alana dokunma | - | `BuFocusRouteObserver`, kökte `BuTapOutsideUnfocus` | TEST (`BuFocusRouteObserver`) DÜZELTİLDİ |
| `posts/compose_post_page.dart` (Paylaş) | Paylaş üst çubukta (hep erişilebilir), liste `onDrag` | - | kök dokunma ile kapanma yeterli | TAMAM |
| `forum/.../create_topic_page.dart`, `edit_topic_page.dart` | Yayınla üst çubukta, liste `onDrag` | - | - | TAMAM |
| `forum/.../comment_thread_page.dart`, `topic_detail_page.dart` | `resizeToAvoidBottomInset:false` + tek `viewInsets` padding | bilinçli, çift boşluk yok | - | TAMAM |
| `chat/chat_detail_page.dart` (yazma, düzenleme) | Column + composer, resize açık | - | - | TAMAM |
| `chat/media_preview_page.dart` | resize + tek viewInsets | - | - | mevcut test (x1.3 + klavye) TAMAM |
| `profile/password_page.dart`, `account_security_page.dart`, `profil2_delete_account_page.dart` | ListView `onDrag`, resize açık | - | kökte dokunma ile kapanma | TAMAM |
| `auth/onboarding/onboarding_flow.dart`, `profile_setup_page.dart` | kaydırılabilir gövde | - | - | TAMAM |
| `search/*`, `chat/new_chat_page.dart`, `contacts_match_page.dart` | liste + `onDrag`, resize açık | - | - | TAMAM |
| `widgets/report_sheet.dart`, `widgets/academic_pickers.dart`, `reels/reels_comments.dart`, `events/etkinlik3_moderators_page.dart`, `chat/sohbety_sheet.dart` | elle `viewInsets` (Scaffold dışı alt sayfa: tek boşluk, doğru) | - | - | TAMAM (kapanışta odak temizliği yalnız `BuSheet` tabanlılarda) |
| `BuSheet` kullanan diğer alt sayfalar (etkinlik başvuru, kulüp katılım, silme onayı...) | klavye payı `BuBottomSheet` içinde | - | unfocus eklendi | TEST (genel) |
| Diyaloglar (`_EditDialog`, yeniden adlandır, yeni dönem) | `SingleChildScrollView` içinde, `Dialog` klavyeye göre kayar | - | - | TAMAM |

## Çalıştırılan testler

Bkz. rapor (`mobile/test/qa_keyboard/keyboard_infra_test.dart`, `keyboard_screens_test.dart`).

## Doğrulanamayan

- **iOS cihaz/simülatör bu makinede yok**: gerçek iOS klavye animasyonu, home indicator ve `viewInsets` davranışı yalnız
  widget testlerinde simüle edildi (`view.padding`/`viewInsets`), cihazda doğrulanmadı.
- Android'de gerçek klavye uygulamaları (Gboard dışı), gesture/3 tuş gezinme ve sistem geri tuşuyla klavye kapatma elle
  denenmedi; geri tuşunun ilk basışta klavyeyi kapatması Android sisteminin işidir, kodda engellenmedi (`PopScope` değişmedi).
- Oturum gerektiren ekranlar emülatörde denenmedi (canlı hesap kullanılmadı).

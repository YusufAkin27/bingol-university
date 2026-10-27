# Mobil çok dilli arayüz (tr / en / ar)

## Mimari
- ARB: `mobile/lib/l10n/app_tr.arb` (şablon, `@anahtar` yer tutucuları burada), `app_en.arb`, `app_ar.arb`. `l10n.yaml` → çıktı `lib/l10n/app_localizations*.dart` (depoya girer). Yeni dize: üç ARB'ye ekle, `flutter gen-l10n` (veya `flutter pub get`/test) çalıştır.
- Kullanım: `context.l10n.anahtar` (`core/locale_controller.dart` uzantısı). Temsilci yoksa (eski testler) Türkçeye düşer. Apostrof (`'`) ARB metinlerinde kullanılmaz (ICU kaçışı); `’` ya da cümleyi değiştir.
- Yerel ayar çözümü (`resolveAppLocale`): kullanıcı seçimi (Ayarlar > Dil: Sistem/Türkçe/English/العربية, `FlutterSecureStorage` `app_language`) > cihaz dili (tr/en/ar ise) > İngilizce.
- `LocaleController` çözülen kodu `ApiClient.lang`'a yazar (`Accept-Language`, kayıt `language`, push `locale`). Girişten sonra ve dil değişince `PATCH /users/me {language}` ile sunucu profil dili eşitlenir.
- Arapça RTL otomatik (`Directionality`); yeni kodda `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `start/end` kullan. Yazı tipi: Inter Arapça glifleri taşımaz, sistem yedeği kullanılır.
- Cümle parçalama yapma (Arapça sözdizimi farklı): `authTermsPrefix/Link/Sep/...` örneği gibi bütün cümleyi tek anahtarda tut ya da sıra-bağımsız parçala.
- Test: `test/l10n_test.dart` (çözüm birim testi + 3 dil widget testi, 320 dp, RTL).

## Yapıldı (ilk dalga)
main (hata/yapılandırma görünümü, temsilciler), alt gezinme, kabuk (çıkış ipucu), sistem kapıları (güncelleme/erişim engeli), `widgets/common.dart` (yükleniyor/yeniden dene), Ayarlar (dil seçimi dahil), giriş / kayıt / şifre sıfırlama / kod doğrulama / yeni şifre ekranları.

## Kalan iş listesi (dosya → önerilen anahtar öneki)
Güncel sayı için: `node scripts/i18n-audit.js --files` (dosya başına yerelleştirilmemiş satır sayısı). Öneri sırası ve önekler:

| Dosya(lar) | Önek |
|---|---|
| `features/chat/*` (chat_tab, chat_detail_page, chat_info_*, new_chat_page, forward_sheet, message_bubble, conversation_actions, media_*) | `chat` |
| `features/clubs/*` | `club` |
| `features/events/*` | `event` |
| `features/home/home_tab.dart`, `features/discover/*`, `features/news/*`, `features/menu/*` | `home`, `discover`, `news`, `menu` |
| `features/profile/*` (profile_tab, edit_profile, user_profile, my_*, privacy_data, notification_prefs, blocked_users, legal) | `profile` |
| `features/posts/*`, `features/stories/*`, `features/polls/*` | `post`, `story`, `poll` |
| `features/academic/*`, `core/academic_catalog.dart`, `widgets/academic_picker.dart` | `academic` |
| `features/support/*` | `support` |
| `features/search/*`, `features/notifications/*`, `features/platform/qr_scan_page.dart` | `search`, `notif`, `qr` |
| `widgets/report_sheet.dart`, `widgets/bu_widgets.dart`, `core/permissions/*`, `features/auth/permissions_page.dart` | `report`, `common`, `perm` |
| Bağlamsız yardımcılar: `widgets/common.dart` (tarih/ay/gün adları, `relTime`), `features/auth/auth_widgets.dart` (doğrulayıcılar), `errorText` | `date`, `validation`, `error` — bağlam parametresi ya da `lookupAppLocalizations(locale)` gerekir |

Not: sunucu hata mesajları `Accept-Language` ile zaten çevrilmiş gelir; istemcide yalnız sabit metinler çevrilir. Tarih biçimleri için `intl` `DateFormat(…, locale)` kullan; Arapçada rakamlar `intl` varsayılanıyla (Batı rakamları) kalır, Arap-Hint rakamı istenirse `NumberFormat` + `ar` yerel ayarı.

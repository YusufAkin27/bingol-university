# Animasyon denetimi: profile-group

Kapsam: `mobile/lib/features/{profile,auth,accounts,legal,platform,widgets}`. Tarih: 2026-11-13.

## Genel durum

- Ortak yardımcılar (`BuStaggerItem`, `BuPressable`, `BuSwapIn`, `BuPopIcon`) bu grupta zaten yaygın: `profile_tab` (hero + bölümler aşamalı, `AnimatedSwitcher` yükleme geçişi), `profile_paged_list`, `my_events_page`, `saved_news_page` (aşamalı + satır çıkış küçülmesi), `profile_content_tabs`, `profile_inline_edit` (`AnimatedSize/Switcher`), `verify_email_card`.
- `auth/` ayrı bir hareket dili kullanıyor (`AuthShake` hata sarsıntısı, `otp_code_boxes`, `login_underline_field`, `auth_ref`, `welcome_page`, `onboarding_flow`); yeterli, sonsuz döngü yok. Dokunulmadı.
- `platform/qr_scan_page` ve `profile_qr_scan_page`: tarama çizgisi `AnimationController` (tarama süresince döner, kamera ekranı; kabul edilebilir, sayfa kapanınca dispose).
- `widgets/` klasörü ana ekran widget'ı (yerel) kodu, UI animasyonu yok. `accounts/account_sheet` alt sayfa: `BuSheet` geçişi kullanıyor.

## Bulgular

| Sayfa | Dosya:satır | Mevcut | Eksik/zayıf | İyileştirme | Durum |
|---|---|---|---|---|---|
| Ayarlar | `profile/settings_page.dart` ListView | yok (tüm bölümler anında) | statik, giriş hissi yok | 5 bölüm `BuStaggerScope` + `BuStaggerItem` (solma + 14 dp yükselme, en çok 8 öğe) | yapıldı |
| Profil menüsü | `profile/profile_menu_page.dart` | yok | aynı | 3 kart grubu aşamalı giriş | yapıldı |
| Cihazlarım | `profile/devices_page.dart` | yalnız iskelet | içerik aniden gelir | giriş metni + iki bölüm aşamalı | yapıldı |
| Engellenenler | `profile/blocked_users_page.dart` | yok | liste aniden | not + grup aşamalı | yapıldı |
| Bildirim tercih anahtarı | `profile/notification_prefs_page.dart:51` | `AnimatedContainer` 160 ms sabit | "animasyonları azalt" yok sayılıyor | `BuMotion.of` ile sarıldı | yapıldı |
| Sözleşme yeniden onay | `legal/legal_reaccept_page.dart:364` | `AnimatedContainer` 200 ms sabit | aynı | `BuMotion.of` | yapıldı |

## Açık / ortak dosya önerileri (dokunulmadı)

- `ProfilFlatToggle` içinde Material `Switch` kullanılıyor; `PrefSwitch` ile görsel dil farklı. Ortak bir `BuSwitch` olursa tek yerde animasyon/reduced-motion denetimi yapılabilir (`widgets/`).
- `ProfilFlatRow`/`ProfilRow`/`ProfilyRow` `InkWell` kullanıyor (dalga efekti); `BuPressable` ölçek geri bildirimi ikon/düğme ajanının kapsamında, satırlara taşınması orada karar verilmeli.
- Kalan profil alt sayfaları (`account_security`, `password`, `two_factor`, `privacy_data`, `profil2_*`) form/anahtar ağırlıklı; aşamalı giriş eklenmedi (kısa formlarda gereksiz, odak/klavye ile çakışma riski).

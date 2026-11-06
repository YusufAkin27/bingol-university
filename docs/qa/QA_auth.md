# QA alani 1: Giris / Kayit / Sifre / OAuth / 2FA / Profil / Ayarlar / Hesap guvenligi / Gizlilik / Bildirim tercihleri

Tarih: 2026-11-06. Mobil dal `qa/auth-20261106`, backend dal `qa/auth-be-20261106` (taban: `deploy/release4-20261106`).
Yontem: kod incelemesi (mobil + backend sozlesme karsilastirmasi) + etkilesimli widget testleri (FakeBackend). Canli sunucuya
istek atilmadi.

## 1. Envanter

Durum sutunu: Y = yukleniyor, B = bos, H = hata, C = cevrimdisi, S = basari. "Test" sutunu mevcut ya da bu turda yazilan test.

### 1.1 Giris / kayit / dogrulama / sifre sifirlama (`features/auth/**`)

| Ekran | Ogeler | Durumlar | Test |
|---|---|---|---|
| Karsilama (`auth_landing_page`) | Google/Apple dugmeleri, e-posta ile giris, kayit, yardim, surum | Y (dugme meşgul), H (OAuth hatalari), iptal | `oauth_login_test`, `auth_redesign_test` |
| Giris (`login_page`) | e-posta, sifre (goster/gizle), "Sifremi unuttum", "Giris yap", "Kayit ol", yardim, surum/Hakkinda, bekleyen dogrulama bandi (Dogrulamayi tamamla / Baska hesap), "baska cihazda giris" bandi | Y, H (401, 429 + Retry-After, 5xx, ag), EMAIL_NOT_VERIFIED > yeniden kod + dogrulama, 2FA 202 > kod ekrani | `auth_redesign_test`, `two_factor_test`, `qa_auth1_test` (401/429/5xx/cevrimdisi/cift dokunma) |
| Kayit (`register_page`) | ad, e-posta (strict), sifre (8 degil 6-72 karakter/72 bayt), sozlesme/gizlilik baglantilari, "Kayit ol", "Giris yap" | H (409, 400 alias, 429, 5xx), `verificationDeferred` 201 > oturum | `auth_redesign_test`, `qa_auth1_test` (409, uzun girdi, RTL, 1.3 olcek) |
| E-posta dogrulama (`verify_code_page`) | 6 kutu, yeniden gonder (geri sayim), "E-postayi degistir", parola kaniti alani (uygulama yeniden acildiysa), "Baska hesapla giris" | H (INVALID_CODE, TOO_MANY_ATTEMPTS, 429), S (yesil kutular) | `qt_verify_deferred_test`, `auth_redesign_test` |
| Sifremi unuttum 1/3 (`forgot_password_page`) | e-posta, "Kod gonder", "Giris'e don", "Sure doldu" bandi | H (404 ACCOUNT_NOT_FOUND, 429, ag), **RESEND_COOLDOWN** | `qa_auth1_test` |
| Kod 2/3 (`reset_code_page`) | 6 kutu, yeniden gonder, "E-postayi degistir" | H, TOO_MANY_ATTEMPTS | `password_page_test` |
| Yeni sifre 3/3 (`new_password_page`) | yeni sifre + tekrar, "Guncelle" | H (INVALID_CODE > "Sure doldu" geri donusu, PASSWORD_UNCHANGED, politika) | `password_page_test` |
| Basari (`reset_success_page`) | "Girise don" | S | `password_page_test` |
| 2FA girisi (`two_factor_code_page`) | 6 kutu, "bu cihaza guven" anahtari, yeniden gonder (3/10 dk), sure doldu > geri | H (TWO_FACTOR_*), 429 geri sayim | `two_factor_test` |
| OAuth akisi (`oauth_flow`, `auth_landing_page`) | Google/Apple, 2FA challenge, profil tamam degil > onboarding | H (OAUTH_*), iptal, cift dokunma | `oauth_login_test`, `oauth_onboarding_test` |
| Gercek e-posta (`real_email_page`) | Apple gizli adres > gercek e-posta + kod | H | `real_email_test` |
| Profil kurulumu / fotograf / izinler | ad-soyad, bolum, sinif, fotograf, bildirim izni | H, atlama | `profile_setup_test`, `profile_photo_setup_test`, `permissions_test` |

### 1.2 Profil / ayarlar / hesap guvenligi (`features/profile/**`)

| Ekran | Ogeler | Durumlar | Test |
|---|---|---|---|
| Ayarlar (`settings_page`) | dil secici (sistem/tr/en/ar), tema (sistem/acik/koyu), bildirim durumu, cikis (onayli), hesap/gizlilik/yasal satirlari | H (dil PATCH sessiz) | `profil2_test`, `theme_test` |
| Hesap ve guvenlik (`account_security_page`) | e-posta karti, Sifre, 2FA satiri (durum), bagli hesaplar (Google/Apple baglama/kaldirma), Cihazlarim | Y/H (identities), OAUTH_DISABLED gizleme, 409 OAUTH_LAST_LOGIN_METHOD, **parolasiz baglama** | `password_page_test`, `oauth_login_test`, `qa_auth1_test` |
| Sifre (`password_page`) | mevcut/yeni/tekrar, "Guncelle", "Sifreni mi unuttun" (kod gonder), sure doldu notu | H (WRONG_PASSWORD, PASSWORD_UNCHANGED/TOO_LONG/**TOO_WEAK**), 429, ag, **RESEND_COOLDOWN**, **parolasiz hesap** | `password_page_test`, `qa_auth1_test` |
| 2FA ayari (`two_factor_page`) | anahtar (ac/kapat), kapatma diyalogu (sifre), guvenilen cihaz listesi/silme | Y/H, 409, 404 | `two_factor_test`, `qa_auth1_test` |
| Cihazlarim (`devices_page`) | liste, tek cihaz cikisi, "tum cihazlardan cik", bu cihaz cikisi | Y/B/H, 404 (zaten kapanmis) | `devices_page_test` |
| Gizlilik (`privacy_data_page`) | gorunurluk secimleri, gizli hesap, e-posta goster, engellenenler sayisi | H (geri alma + "tekrar dene") | `profil2_test`, `w1g_autosave_privacy_test` |
| Engellenenler (`blocked_users_page`) | sayfali liste, engeli kaldir | Y/B/H | `profil2_test` |
| Verilerim (`profil2_my_data_page`) | dışa aktar (`/users/me/export`) | Y/H | `profil2_test` |
| Hesabi sil (`profil2_delete_account_page`) | uyari, onay kutusu, "Devam et", sifre sayfasi, **parolasiz hesap** | H (WRONG_PASSWORD, 429), S | `profil2_test`, `qa_auth1_test` |
| Bildirim tercihleri (`notification_prefs_page`) | ana anahtarlar, alt turler, onizlemeyi gizle, hatirlaticilar, izin durumu | Y/H, iyimser kayit + geri alma, sirali PUT | `notif_settings_test`, `notif2_prefs_test` |
| Yasal (`legal_pages`, `features/legal/**`) | surumlu metin, yeniden onay | Y/H | `legal_reaccept_test` |

## 2. Bulgular

Siddet: kritik / yuksek / orta / dusuk. Tur: HATA, YANLIS MANTIK, IYILESTIRME.

| Id | Siddet | Tur | Ekran | Adim | Beklenen / gercek | Kok neden | Duzeltme |
|---|---|---|---|---|---|---|---|
| QA-AUTH-01 | kritik | YANLIS MANTIK | Hesabi sil, hesap baglama, 2FA kapatma | Google/Apple ile acilmis (parolasiz) hesapla Ayarlar > Hesabi sil | Beklenen: hesap silinebilmeli (KVKK + App Store 5.1.1(v)). Gercek: yalniz sifre sorulur; kullanicinin sifresi yok, `WRONG_PASSWORD` ile sonsuza dek reddedilir. Ayni sekilde "Google/Apple bagla" sifre ister (sunucu `reauth*` bekler), "2FA kapat" sifre ister | Mobil, sunucunun parolasiz hesap icin hazir yeniden dogrulama sozlesmesini (`DELETE /users/me {provider,token,nonce}`, `POST /auth/oauth/link {reauth*}`) hic kullanmiyordu; hesabin parolasiz oldugunu bilmiyordu (`/auth/me` bildirmiyordu) | YAPILDI. Backend: `GET /auth/me` `hasPassword` (geriye uyumlu ek alan). Mobil: `Session.hasPassword`; silme sayfasi sagayici yeniden dogrulamasi; baglama `reauth*`; 2FA kapatma > Sifre sayfasina yonlendirme + not; sifre sayfasi "Sifre belirle" (e-posta kodu). Test: `qa_auth1_test`, `AuthServiceOAuthLoginTest.meReportsWhetherTheAccountHasAUsablePassword` |
| QA-AUTH-02 | yuksek | YANLIS MANTIK | Sifremi unuttum (giris + Sifre sayfasi) | Kod gonder > kod ekrani > geri > yeniden "Kod gonder" | Beklenen: kod hala gecerli, kod ekranina donulur. Gercek: sunucu 180 sn icinde 429 RESEND_COOLDOWN verir, kullanici hata bandinda kalir; gecerli kodu girecegi ekrana ulasamaz (ekran yigininda geri donus yok) | Bekleme hatasi "basarisiz" sayiliyordu; oysa kod zaten gonderilmis | YAPILDI: `RESEND_COOLDOWN` > kod ekrani acilir (iki akista). Test: `qa_auth1_test` |
| QA-AUTH-03 | yuksek | HATA | Kok navigator, oturum suresi dolmasi | Ayarlar/Sifre gibi bir alt sayfa acikken refresh basarisiz (401) | Beklenen: giris ekrani. Gercek: `signOut(remote:false)` rota yigitini temizlemiyor; ust sayfa giris ekranini orter, istekler 401 verir | Yalniz `forceSignOut` `popUntil` yapiyordu | YAPILDI: `signOut` sonunda `popUntil(isFirst)`. Test: `qa_auth1_test` (QA-AUTH-04 grubu) |
| QA-AUTH-04 | orta | YANLIS MANTIK | Sifre degistirme | Yonetici hesabi (min 12 karakter, yaygin sifre yasagi) mobilde 8 karakterlik sifre girer | Beklenen: sunucunun gerekcesi. Gercek: 400 PASSWORD_TOO_WEAK/SHORT > genel "Sifre guncellenemedi" (yaniltici) | Istemci politikasi sunucudan farkli; kod ozel ele alinmiyordu | YAPILDI: gerekce alanin altinda; diger 4xx icin sunucu mesaji gosterilir. Test: `qa_auth1_test` |
| QA-AUTH-05 | orta | YANLIS MANTIK | 2FA | Parolasiz hesap 2FA'yi acar, sonra kapatmak ister | Sunucu kapatmada sifre ister (`INVALID_PASSWORD`); sifre yok > hesap kalici olarak 2FA'da kalir | Sunucu kuralı | KISMEN: mobil yonlendirir (QA-AUTH-01). Kalici cozum (sagayici/e-posta kodu ile 2FA kapatma) KARAR BEKLIYOR (guvenlik tasarimi) |
| QA-AUTH-06 | dusuk | IYILESTIRME | Sifre sayfasi | Gonderilirken alanlar kilitlenmiyor (mevcut/yeni/tekrar) | Gonderim sirasinda duzenlenebilir | `_PwField` `enabled` almiyor | YAPILMADI (dusuk; cift gonderim `_busy` ile engelli) |
| QA-AUTH-07 | dusuk | OLU KOD / YEREL. | `auth_widgets.dart` | `validateEmail`, `validateNewPassword` | Sert kodlu Turkce metin, uygulamada kullanilmiyor (yalniz `auth_test`) | Eski dogrulayicilar | YAPILMADI (testi `auth_test` kullaniyor; silmek test degisikligi ister). Yeni kod `newPasswordValidator(context)` kullanir |
| QA-AUTH-08 | dusuk | YANLIS MANTIK | Kayit | Kayit e-postasi `+etiket` | Istemci regex'i `+`'ya izin verir, sunucu 400 EMAIL_ALIAS_NOT_ALLOWED > alan altinda gosterilir | Bilincli (sunucu hatasi yerelde gosteriliyor) | DUZELTILMEDI (calisiyor) |
| QA-AUTH-09 | bilgi | KARAR | Sifremi unuttum | Kayitsiz e-posta | 404 ACCOUNT_NOT_FOUND (hesap varligi sezilir) | Kullanici karari (CLAUDE.md: bilincli istisna), IP/e-posta hiz sinirlari var | Degistirilmedi |

## 3. Kod incelemesi: kontrol edilip sorun bulunmayanlar

- Giris: sifre kirpilmaz, e-posta normalize edilir, 429 `Retry-After` ayri satir, EMAIL_NOT_VERIFIED yeniden kod gonderir (429'da sessiz), 2FA challenge yalniz bellekte.
- Kayit: `acceptTerms` her zaman gonderilir, ertelenmis dogrulamada (201 + jeton) oturum acilir ve kok sayfaya donulur.
- Dogrulama: parola kaniti bellekte tutulur, yoksa kullanicidan istenir; TOO_MANY_ATTEMPTS yeni kodu hemen acar.
- Cikis: jeton silme siraya dizili, silme basarisiz olursa `signed_out` isareti; push belirteci cikis istegine eklenir.
- Gizlilik/bildirim tercihleri: iyimser kayit + hata durumunda geri alma, sirali PUT.

## 4. Test sayilari

Bkz. rapor (alan testleri + `test/qa_auth1_test.dart`).

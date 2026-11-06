# Mobil: Google / Apple ile giriş + profil tamamlama

Sunucu tarafı ve kimlik/proje kurulumu: `docs/OAUTH_SETUP.md`, sözleşme: `docs/changes/auth.md`, `docs/MOBILE_API_GUIDE.md`.
Bu dosya yalnız mobil istemcinin davranışını ve kullanıcının sağlaması gereken yapılandırmayı anlatır.

## Düğmeler ne zaman görünür

Bayrak değerleri tek yerde: `lib/core/oauth_config.dart` (`--dart-define`, varsayılan KAPALI; sahte çalışma yok).

| Düğme | Görünme koşulu |
|---|---|
| Google ile devam et | `--dart-define=GOOGLE_SIGNIN=true` (varsayılan KAPALI; sunucuda `GOOGLE_CLIENT_IDS` hazır olunca açılır) **ve** web istemci kimliği dolu (varsayılanı kodda gömülü, `GOOGLE_SERVER_CLIENT_ID` ile geçersiz kılınır) |
| Apple ile devam et | `--dart-define=APPLE_SIGNIN=true` **ve** platform iOS (Android'de Apple için sunucuda Services ID yapılandırılmadı: düğme gizli) |
| E-posta ile devam et | her zaman |

Ek olarak sunucu `404 OAUTH_DISABLED` dönerse ilgili düğme o uygulama oturumu boyunca gizlenir. Hesap ve güvenlik > "Bağlı hesaplar"
bölümü yalnız en az bir yöntem açıkken görünür.

## Kullanıcının yapması gerekenler (kod değil, yapılandırma)

- **Google**: istemci kimlikleri (proje bu-kampus, numara 825713637416) KODDA varsayılan olarak gömülüdür (gizli değil, herkese açık
  tanımlayıcı): `lib/core/oauth_config.dart` (`kDefaultGoogleServerClientId` = WEB, `kDefaultGoogleIosClientId` = iOS) ve iOS'ta
  `ios/Runner/Info.plist` (`GIDClientID` + ters kimlik URL şeması `com.googleusercontent.apps.<no>-<id>`). Android istemcisi
  (paket `tr.com.bukampus.app` + imza SHA-1) yalnız Google Cloud eşlemesidir, kodda gerekmez; Android'de `serverClientId` = WEB
  kimliği kullanılır. Play App Signing kullanılıyorsa Play Console'daki **uygulama imzalama** SHA-1 de ayrıca bir Android
  istemcisi olarak eklenmelidir (yükleme anahtarı yetmez). Değiştirmek için: `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` /
  `GOOGLE_IOS_CLIENT_ID=...` (Codemagic/`build-ipa.sh`: aynı adlı ortam değişkenleri); iOS kimliğini değiştirirseniz Info.plist de
  değişmeli (`python -I -X utf8 scripts/ios/check-ios-static.py` tutarlılığı denetler). Düğmeyi açmak: `GOOGLE_SIGNIN=true`
  (yalnızca sunucu `GOOGLE_CLIENT_IDS` = web,android,ios ile hazırken).
- **Apple**: Apple Developer'da App ID için "Sign in with Apple" yeteneği açılmalı, sonra `Runner.entitlements` içine
  `com.apple.developer.applesignin` eklenmeli (bu iş mobil ajan tarafından yapılmadı: yetenek açılmadan imza hatası olur).
  Ardından `--dart-define=APPLE_SIGNIN=true` ile derlenir.

## Akış özeti

- `AuthLandingPage` (çıkış yapmış kök ekran) -> `runOAuthSignIn` -> `Session.loginWithGoogle/loginWithApple`
  (`POST /auth/oauth/google|apple`; gövdeye `client:mobile` eklenir). Apple nonce: ham değer sunucuya, SHA-256 özeti Apple'a.
- 202 + `twoFactorRequired`: mevcut `TwoFactorLoginPage` yolu. 409 `OAUTH_LINK_REQUIRED`: otomatik birleşme yok; kullanıcıya
  "önce e-posta ve şifrenle gir, sonra Hesap ve güvenlik'ten bağla" yönlendirmesi + e-posta düğmesi.
- Profil kapısı (`ProfileCompletionGate`): `GET /users/me` `profileCompleted:false` ya da herhangi bir uçta 403
  `PROFILE_INCOMPLETE` (`ApiClient.onProfileIncomplete` -> `Session.profileIncompleteSignal`) ise kabuk yerine 2 aşamalı
  `OnboardingFlow` gösterilir (`PUT /users/me/onboarding`, alan eşlemesi tek dosyada: `features/auth/data/onboarding_api.dart`).
  `profileCompleted` alanı yoksa (eski sunucu) eski bölüm + sınıf kuralı geçerlidir.
- Taslak (ad/soyad/kullanıcı adı/seçimler; biyografi ve fotoğraf yok) yalnız güvenli yerel depoda; çıkışta ve başarıda silinir.
  Fotoğraf profil kaydından sonra yüklenir.
- Bağlama: `GET /auth/oauth/identities`, `POST /auth/oauth/link` (şifre yeniden doğrulaması), `DELETE /auth/oauth/link/{provider}`.

## Test durumu

Sağlayıcı SDK'ları arayüz + sahte uygulama ile test edilir (`test/oauth_login_test.dart`, `test/oauth_onboarding_test.dart`).
Gerçek Google/Apple girişi cihaz/kimlik gerektirir ve macOS/Android cihazda elle doğrulanmalıdır.

## Google paketi ve iOS bağımlılık çözümü (SwiftPM)

Çözüm: `google_sign_in: 7.2.0` + `google_sign_in_ios: ^6.4.0` (alt sınır ZORUNLU, düşürmeyin). Neden: `firebase_core 5.1.0` /
`firebase_messaging 17.0.1` Firebase iOS SDK **13.1.1**'e kilitlidir (`exact`); bu SDK `gtm-session-fetcher "4.0.0"..<"6.0.0"` ve
`app-check "12.0.0"..<"13.0.0"` ister. `google_sign_in_ios 6.3.x` GoogleSignIn-iOS 9.x'e (`gtm-session-fetcher` 3.x, SwiftPM
`from: 3.3.0` = <4.0.0) bağlıydı: çakışma. `google_sign_in_ios 6.4.0` (2026-11-05) GoogleSignIn-iOS `"9.0.0"..<"11.0.0"` kabul eder ve
SwiftPM 10.1.0'ı seçer (`gtm-session-fetcher "3.3.0"..<"6.0.0"`, `app-check "11.0.0"..<"13.0.0"`, GTMAppAuth 6, AppAuth 3);
GoogleSignIn-iOS 10.1.0 değişiklik günlüğü bunu açıkça belirtir ("apps using Swift Package Manager can now upgrade to Firebase 13").
Aralıkların kesişimi: gtm-session-fetcher 4.x-5.x, app-check 12.x, GoogleUtilities 8.1.4+ (hepsi çözülebilir). 10.0.0 sürümü
`app-check 11.x` ister ve Firebase 13 ile ÇAKIŞIR; SwiftPM yine de 10.1.0'ı seçebilir. iOS 15 alt sınırı projeyle uyumludur.
Windows'ta SwiftPM çözümlemesi çalıştırılamaz: gerçek doğrulama Codemagic/macOS derlemesindedir. Bu çözüm tutmazsa yedek:
`flutter config --no-enable-swift-package-manager` (CocoaPods; Firebase 13 pod'u ile GoogleSignIn 10.1.0 pod'u da uyumlu aralıktadır)
ya da `kGoogleSignInCompiled=false` + paketi çıkarma (commit 0aee636f).

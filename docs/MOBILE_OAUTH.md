# Mobil: Google / Apple ile giriş + profil tamamlama

Sunucu tarafı ve kimlik/proje kurulumu: `docs/OAUTH_SETUP.md`, sözleşme: `docs/changes/auth.md`, `docs/MOBILE_API_GUIDE.md`.
Bu dosya yalnız mobil istemcinin davranışını ve kullanıcının sağlaması gereken yapılandırmayı anlatır.

## Düğmeler ne zaman görünür

Bayrak değerleri tek yerde: `lib/core/oauth_config.dart` (`--dart-define`, varsayılan KAPALI; sahte çalışma yok).

| Düğme | Görünme koşulu |
|---|---|
| Google ile devam et | `--dart-define=GOOGLE_SIGNIN=true` **ve** `--dart-define=GOOGLE_SERVER_CLIENT_ID=<web istemci kimliği>` |
| Apple ile devam et | `--dart-define=APPLE_SIGNIN=true` **ve** platform iOS (Android'de Apple için sunucuda Services ID yapılandırılmadı: düğme gizli) |
| E-posta ile devam et | her zaman |

Ek olarak sunucu `404 OAUTH_DISABLED` dönerse ilgili düğme o uygulama oturumu boyunca gizlenir. Hesap ve güvenlik > "Bağlı hesaplar"
bölümü yalnız en az bir yöntem açıkken görünür.

## Kullanıcının yapması gerekenler (kod değil, yapılandırma)

- **Google**: Google Cloud'da web + Android (paket `tr.com.bukampus.app`, imza SHA-1/SHA-256) + iOS OAuth istemcileri.
  `GOOGLE_SERVER_CLIENT_ID` = web istemci kimliği (sunucunun doğruladığı ID token hedef kitlesi). iOS için ayrıca
  `Info.plist`'e `GIDClientID` (ya da `--dart-define=GOOGLE_IOS_CLIENT_ID=...`) ve ters istemci kimliği URL şeması
  (`CFBundleURLTypes`) eklenmelidir. Bu repoda gerçek kimlik YOKTUR.
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

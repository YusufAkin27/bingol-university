import 'package:flutter/foundation.dart';

/// Google / Apple ile giriş yapılandırması: bayrak değerleri TEK yerde (derleme anında `--dart-define`).
///
/// - Google: `--dart-define=GOOGLE_SIGNIN=true --dart-define=GOOGLE_SERVER_CLIENT_ID=<web istemci kimliği>`.
///   İkisi de yoksa Google düğmesi hiç görünmez (sahte çalışma yok). iOS için isteğe bağlı
///   `--dart-define=GOOGLE_IOS_CLIENT_ID=<iOS istemci kimliği>` (yoksa Info.plist `GIDClientID` okunur).
/// - Apple: `--dart-define=APPLE_SIGNIN=true`; YALNIZ iOS'ta görünür. Android'de Apple için sunucuda Services ID
///   gerekir ve yapılandırılmadı: Android'de düğme gizlidir. Varsayılan KAPALI: iOS'ta "Sign in with Apple" yeteneği
///   App ID'de açılmadan imza hatası olur (bkz. docs/OAUTH_SETUP.md, docs/MOBILE_OAUTH.md).
///
/// Ek olarak sunucu 404 `OAUTH_DISABLED` dönerse o sağlayıcı bu uygulama oturumu boyunca gizlenir
/// ([Session.oauthDisabled]).
/// Google giriş SDK'sı derlemeye dahil mi (şu an HAYIR: iOS bağımlılık çakışması).
const bool kGoogleSignInCompiled = false;

class OAuthConfig {
  const OAuthConfig({
    this.googleFlag = false,
    this.googleServerClientId = '',
    this.googleIosClientId = '',
    this.appleFlag = false,
    this.appleSupportedPlatform = false,
  });

  /// Derleme anı değerleri (`String.fromEnvironment` yalnız const bağlamda çalışır).
  static const _googleFlag = bool.fromEnvironment('GOOGLE_SIGNIN');
  static const _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  static const _googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static const _appleFlag = bool.fromEnvironment('APPLE_SIGNIN');

  /// Çalışan uygulamanın yapılandırması; testler bunu değiştirir ve geri alır.
  static OAuthConfig current = OAuthConfig.fromEnvironment();

  factory OAuthConfig.fromEnvironment() => OAuthConfig(
        // Google paketi bu sürümde çıkarıldı (iOS SwiftPM çakışması: `oauth_services.dart` notu): bayrak açık olsa bile
        // üretimde düğme HER ZAMAN gizli (`kGoogleSignInCompiled`).
        googleFlag: _googleFlag && kGoogleSignInCompiled,
        googleServerClientId: _googleServerClientId,
        googleIosClientId: _googleIosClientId,
        appleFlag: _appleFlag,
        appleSupportedPlatform: defaultTargetPlatform == TargetPlatform.iOS,
      );

  final bool googleFlag;
  final String googleServerClientId;
  final String googleIosClientId;
  final bool appleFlag;

  /// Apple düğmesi yalnız iOS'ta çalışır (Android web/OAuth akışı sunucuda yapılandırılmadı).
  final bool appleSupportedPlatform;

  /// Google düğmesi: bayrak açık ve web istemci kimliği verilmiş.
  bool get googleEnabled => googleFlag && googleServerClientId.trim().isNotEmpty;

  /// Apple düğmesi: bayrak açık ve iOS.
  bool get appleEnabled => appleFlag && appleSupportedPlatform;

  /// En az bir sosyal yöntem açık mı (ayırıcı "veya" ve bağlı hesaplar bölümü için).
  bool get anyEnabled => googleEnabled || appleEnabled;
}

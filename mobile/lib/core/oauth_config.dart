import 'package:flutter/foundation.dart';

/// Google / Apple ile giriş yapılandırması: bayrak değerleri TEK yerde (derleme anında `--dart-define`).
///
/// - Google: düğme için `--dart-define=GOOGLE_SIGNIN=true` ŞART (sunucuda `GOOGLE_CLIENT_IDS` hazır olunca açılır;
///   varsayılan KAPALI) ve web istemci kimliği dolu olmalı. İstemci kimlikleri GİZLİ DEĞİLDİR (herkese açık tanımlayıcı);
///   varsayılanları aşağıda gömülüdür, `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` / `GOOGLE_IOS_CLIENT_ID=...` ile
///   geçersiz kılınır (boş verilirse düğme gizlenir). iOS tarafında aynı iOS kimliği `Info.plist` `GIDClientID` ve
///   ters kimlik URL şemasıdır (bkz. docs/MOBILE_OAUTH.md).
/// - Apple: `--dart-define=APPLE_SIGNIN=true`; YALNIZ iOS'ta görünür. Android'de Apple için sunucuda Services ID
///   gerekir ve yapılandırılmadı: Android'de düğme gizlidir. Varsayılan KAPALI: iOS'ta "Sign in with Apple" yeteneği
///   App ID'de açılmadan imza hatası olur (bkz. docs/OAUTH_SETUP.md, docs/MOBILE_OAUTH.md).
///
/// Ek olarak sunucu 404 `OAUTH_DISABLED` dönerse o sağlayıcı bu uygulama oturumu boyunca gizlenir
/// ([Session.oauthDisabled]).
/// Google giriş SDK'sı derlemeye dahil mi (`google_sign_in` 7.2.0 + `google_sign_in_ios` >=6.4.0: iOS SwiftPM'de
/// GoogleSignIn-iOS 10.x, Firebase iOS SDK 13 ile birlikte çözülür; ayrıntı pubspec.yaml ve docs/MOBILE_OAUTH.md).
const bool kGoogleSignInCompiled = true;

/// Google OAuth istemci kimlikleri (proje bu-kampus). Gizli değildir; derleme anında dart-define ile değiştirilebilir.
/// WEB istemcisi = ID token hedef kitlesi (sunucu `GOOGLE_CLIENT_IDS` içinde de olmalı); Android'de `serverClientId` olarak
/// da bu kullanılır (Android istemcisi yalnız paket + imza eşlemesi içindir, kodda gerekmez).
const String kDefaultGoogleServerClientId =
    '825713637416-mhung4r1or7ca6b2icqggitnapoai80l.apps.googleusercontent.com';
const String kDefaultGoogleIosClientId =
    '825713637416-e9vlno4a7bk0sa9cvftmdqe0alklur4j.apps.googleusercontent.com';

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
  static const _googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: kDefaultGoogleServerClientId);
  static const _googleIosClientId =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID', defaultValue: kDefaultGoogleIosClientId);
  static const _appleFlag = bool.fromEnvironment('APPLE_SIGNIN');

  /// Çalışan uygulamanın yapılandırması; testler bunu değiştirir ve geri alır.
  static OAuthConfig current = OAuthConfig.fromEnvironment();

  factory OAuthConfig.fromEnvironment() => OAuthConfig(
        // Düğme: derleme sabiti (SDK dahil) + GOOGLE_SIGNIN bayrağı + dolu web istemci kimliği (`googleEnabled`).
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

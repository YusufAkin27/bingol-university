import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../oauth_config.dart';

/// Desteklenen dış kimlik sağlayıcıları. [wire]: sunucu yolundaki/gövdesindeki ad.
enum OAuthProvider {
  google('google'),
  apple('apple');

  const OAuthProvider(this.wire);
  final String wire;

  static OAuthProvider? tryParse(Object? v) {
    final s = v is String ? v.toLowerCase() : null;
    for (final p in values) {
      if (p.wire == s) return p;
    }
    return null;
  }
}

/// Google'dan alınan kimlik: sunucu yalnız [idToken]'ı doğrular; ad yalnız ön doldurma ipucudur.
class GoogleCredential {
  const GoogleCredential({required this.idToken, this.displayName});

  final String idToken;
  final String? displayName;

  @override
  String toString() => 'GoogleCredential(<gizli>)';
}

/// Apple'dan alınan kimlik. [nonce] HAM rastgele değerdir (sunucuya bu gider); Apple isteğine SHA-256 özeti verilmiştir.
/// [firstName]/[lastName] yalnız İLK yetkilendirmede gelir.
class AppleCredential {
  const AppleCredential({required this.identityToken, required this.nonce, this.firstName, this.lastName});

  final String identityToken;
  final String nonce;
  final String? firstName;
  final String? lastName;

  @override
  String toString() => 'AppleCredential(<gizli>)';
}

/// Sağlayıcı SDK'sı kullanıcı iptali dışında bir nedenle başarısız oldu (yapılandırma, ağ, desteklenmiyor).
/// Kullanıcı iptali istisna DEĞİLDİR: servisler null döner ve arayüz sessizce geri döner.
class OAuthFailure implements Exception {
  const OAuthFailure(this.code);

  final String code;

  @override
  String toString() => 'OAuthFailure($code)';
}

abstract class GoogleSignInService {
  /// Hesap seçtirir ve ID token döner; kullanıcı vazgeçtiyse null.
  Future<GoogleCredential?> signIn();
}

abstract class AppleSignInService {
  /// Apple sayfasını açar; kullanıcı vazgeçtiyse null.
  Future<AppleCredential?> signIn();
}

/// Uygulamanın kullandığı servisler; testler sahte uygulamalarla değiştirir.
class OAuthServices {
  OAuthServices({GoogleSignInService? google, AppleSignInService? apple})
      : google = google ?? GoogleSignInServiceImpl(),
        apple = apple ?? AppleSignInServiceImpl();

  static OAuthServices current = OAuthServices();

  final GoogleSignInService google;
  final AppleSignInService apple;
}

/// [GoogleSignIn] (google_sign_in 7.x): `serverClientId` = web istemci kimliği (ID token'ın hedef kitlesi).
class GoogleSignInServiceImpl implements GoogleSignInService {
  Future<void>? _init;

  Future<void> _ensureInit() => _init ??= () async {
        final c = OAuthConfig.current;
        await GoogleSignIn.instance.initialize(
          serverClientId: c.googleServerClientId,
          clientId: c.googleIosClientId.isEmpty ? null : c.googleIosClientId,
        );
      }();

  @override
  Future<GoogleCredential?> signIn() async {
    try {
      await _ensureInit();
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      // Bir sonraki dokunuşta hesap seçici yeniden açılsın (SDK oturumu uygulama oturumu değildir).
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
      if (token == null || token.isEmpty) throw const OAuthFailure('NO_ID_TOKEN');
      return GoogleCredential(idToken: token, displayName: account.displayName);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      _init = null; // yapılandırma hatası sonrası yeniden başlatılabilsin
      throw OAuthFailure(e.code.name);
    } on OAuthFailure {
      rethrow;
    } catch (e) {
      _init = null;
      throw const OAuthFailure('GOOGLE_ERROR');
    }
  }
}

/// [SignInWithApple] (iOS yerel akış). Nonce: 32 bayt rastgele; Apple'a SHA-256 hex özeti, sunucuya ham değer gider.
class AppleSignInServiceImpl implements AppleSignInService {
  @override
  Future<AppleCredential?> signIn() async {
    final raw = newOAuthNonce();
    try {
      final c = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: sha256Hex(raw),
      );
      final token = c.identityToken;
      if (token == null || token.isEmpty) throw const OAuthFailure('NO_IDENTITY_TOKEN');
      return AppleCredential(identityToken: token, nonce: raw, firstName: c.givenName, lastName: c.familyName);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw OAuthFailure(e.code.name);
    } on OAuthFailure {
      rethrow;
    } catch (e) {
      throw const OAuthFailure('APPLE_ERROR');
    }
  }
}

/// Kriptografik olarak güçlü, URL güvenli 32 baytlık ham nonce.
@visibleForTesting
String newOAuthNonce([Random? random]) {
  final r = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => r.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

/// SHA-256 özeti (küçük harf hex): Apple isteğindeki nonce.
String sha256Hex(String input) => sha256.convert(utf8.encode(input)).toString();

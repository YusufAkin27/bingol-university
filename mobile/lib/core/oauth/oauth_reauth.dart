import 'oauth_services.dart';

/// Parolasız (yalnız Google/Apple ile açılmış) hesapta hassas işlem (hesap silme, hesap bağlama) için sağlayıcının
/// TAZE kimliği. Belirteç yalnız bellekte tutulur ve tek istekte gönderilir.
class OAuthReauth {
  const OAuthReauth(this.provider, this.token, [this.nonce]);

  final OAuthProvider provider;
  final String token;
  final String? nonce;

  @override
  String toString() => 'OAuthReauth(<gizli>)';
}

/// [p] sağlayıcısının hesap seçicisini açar. Kullanıcı vazgeçerse null; hata [OAuthFailure] ya da başka istisna fırlatır.
Future<OAuthReauth?> freshOAuthCredential(OAuthProvider p) async {
  final svc = OAuthServices.current;
  if (p == OAuthProvider.google) {
    final c = await svc.google.signIn();
    return c == null ? null : OAuthReauth(p, c.idToken);
  }
  final c = await svc.apple.signIn();
  return c == null ? null : OAuthReauth(p, c.identityToken, c.nonce);
}

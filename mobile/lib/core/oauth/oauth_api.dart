import '../api.dart';
import 'oauth_services.dart';

/// Bağlı dış hesap (`GET /auth/oauth/identities`).
class OAuthIdentity {
  const OAuthIdentity({required this.provider, this.emailMasked});

  final OAuthProvider provider;
  final String? emailMasked;
}

/// Hesap bağlama uçları (Hesap ve güvenlik > Bağlı hesaplar). Sözleşme: docs/changes/auth.md.
class OAuthApi {
  OAuthApi(this.api);

  final ApiClient api;

  /// `GET /auth/oauth/identities`. Yanıt biçimi toleranslıdır: düz liste, `{items:[...]}` ya da `{identities:[...]}`;
  /// satır `{provider, emailMasked?}`; bilinmeyen sağlayıcılar atlanır.
  Future<List<OAuthIdentity>> identities() async {
    final r = await api.get('/auth/oauth/identities', force: true);
    final list = r is List ? r : (r is Map ? (r['items'] ?? r['identities']) : null);
    if (list is! List) throw ApiError(0, 'BAD_RESPONSE', '');
    final out = <OAuthIdentity>[];
    for (final e in list) {
      if (e is! Map) continue;
      final p = OAuthProvider.tryParse(e['provider']);
      if (p == null) continue;
      final m = e['emailMasked'] ?? e['email'];
      out.add(OAuthIdentity(provider: p, emailMasked: m is String ? m : null));
    }
    return out;
  }

  /// `POST /auth/oauth/link {provider, token, nonce?, password}`: şifre yeniden doğrulaması zorunludur.
  /// 403 `WRONG_PASSWORD`, 409 (başka hesaba bağlı) ApiError olarak çıkar.
  Future<void> link(OAuthProvider provider, {required String token, String? nonce, required String password}) async {
    await api.post('/auth/oauth/link', {
      'provider': provider.wire,
      'token': token,
      if (nonce != null) 'nonce': nonce,
      'password': password,
    });
  }

  /// `DELETE /auth/oauth/link/{provider}`: 409 `OAUTH_LAST_LOGIN_METHOD` = tek giriş yöntemi, kaldırılamaz.
  Future<void> unlink(OAuthProvider provider) => api.delete('/auth/oauth/link/${provider.wire}');
}

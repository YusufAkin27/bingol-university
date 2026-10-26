import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';
import 'badges.dart';

enum SessionState { loading, signedOut, signedIn }

/// Oturum durumu + kimlik uçları. Token'lar Keychain/Keystore'da tutulur.
class Session extends ChangeNotifier {
  Session(this.api) {
    api.onTokensChanged = _persist;
    api.onSessionExpired = () => signOut(remote: false);
  }

  final ApiClient api;

  /// Alt gezinme/üst çan rozetleri; sayfalar okuyunca değerini düşürür.
  final badges = AppBadges();
  final _storage = const FlutterSecureStorage();

  SessionState state = SessionState.loading;
  int? userId;
  String? displayName;
  String? email;

  Future<void> restore() async {
    try {
      final a = await _storage.read(key: 'access');
      final r = await _storage.read(key: 'refresh');
      if (a != null && r != null) {
        api.tokens = Tokens(a, r);
        await _loadMe();
        return;
      }
    } catch (_) {
      // Depo okunamazsa oturumsuz başla.
    }
    _set(SessionState.signedOut);
  }

  Future<void> _loadMe() async {
    try {
      final me = await api.get('/auth/me') as Map<String, dynamic>;
      userId = (me['id'] as num?)?.toInt();
      displayName = me['displayName'] as String?;
      email = me['email'] as String?;
      _set(SessionState.signedIn);
    } on ApiError catch (e) {
      // Ağ yokken oturumu silmeyiz; yalnızca sunucudan gelen 401 oturumu bitirir.
      if (e.isNetwork) {
        _set(SessionState.signedIn);
      } else {
        await signOut(remote: false);
      }
    }
  }

  /// Profil düzenlendikten sonra karşılama adını tazeler.
  Future<void> refreshName() async {
    try {
      final me = await api.get('/auth/me') as Map<String, dynamic>;
      displayName = me['displayName'] as String?;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> login(String email, String password) async {
    final res = await api.post('/auth/login', {'email': email.trim(), 'password': password}, false);
    await _accept(res);
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await api.post(
      '/auth/register',
      {
        'email': email.trim(),
        'password': password,
        'displayName': displayName.trim(),
        'acceptTerms': true,
        'language': api.lang,
      },
      false,
    );
  }

  Future<void> resendCode(String email) =>
      api.post('/auth/resend-code', {'email': email.trim()}, false);

  Future<void> verifyEmail(String email, String code) async {
    final res = await api.post('/auth/verify-email', {'email': email.trim(), 'code': code.trim()}, false);
    await _accept(res);
  }

  Future<void> forgotPassword(String email) =>
      api.post('/auth/forgot-password', {'email': email.trim()}, false);

  /// Kodu doğrular; doğruysa yeni şifre adımı için tek kullanımlık anahtar döner.
  Future<String> verifyResetCode(String email, String code) async {
    final res = await api.post(
      '/auth/verify-reset-code',
      {'email': email.trim(), 'code': code.trim()},
      false,
    ) as Map<String, dynamic>;
    return res['resetToken'] as String;
  }

  Future<void> resetPassword(String email, String resetToken, String newPassword) => api.post(
        '/auth/reset-password',
        {'email': email.trim(), 'resetToken': resetToken, 'newPassword': newPassword},
        false,
      );

  Future<void> signOut({bool remote = true}) async {
    final refresh = api.tokens?.refresh;
    if (remote && refresh != null) {
      try {
        await api.post('/auth/logout', {'refreshToken': refresh}, false);
      } catch (_) {
        // Çıkış yerelde her durumda tamamlanır.
      }
    }
    await api.setTokens(null);
    badges.reset();
    userId = null;
    displayName = null;
    email = null;
    _set(SessionState.signedOut);
  }

  Future<void> _accept(dynamic res) async {
    await api.setTokens(Tokens.fromJson(res as Map<String, dynamic>));
    await _loadMe();
  }

  Future<void> _persist(Tokens? t) async {
    try {
      if (t == null) {
        await _storage.delete(key: 'access');
        await _storage.delete(key: 'refresh');
      } else {
        await _storage.write(key: 'access', value: t.access);
        await _storage.write(key: 'refresh', value: t.refresh);
      }
    } catch (_) {
      // Depo yazılamazsa oturum yalnızca bellekte kalır.
    }
  }

  void _set(SessionState s) {
    state = s;
    notifyListeners();
  }
}

/// Hata kodlarına kullanıcı metni: sunucu zaten istek dilinde `message` döner; yalnızca ağ hatası yerelde.
String errorText(Object e) {
  if (e is ApiError) {
    if (e.isNetwork) return 'Sunucuya ulaşılamadı. Bağlantınızı kontrol edin.';
    if (e.message.isNotEmpty) return e.message;
    if (e.status == 429) return 'Çok fazla deneme. Lütfen biraz bekleyin.';
  }
  return 'Bir sorun oluştu. Lütfen tekrar deneyin.';
}

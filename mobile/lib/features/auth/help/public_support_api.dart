import '../../../core/api.dart';
import '../../../core/secure_store.dart';

/// Herkese açık destek talebi (T27, `/api/public/support/**`): hesapsız, e-posta doğrulamalı. Tek HTTP katmanı
/// [ApiClient] kullanılır, `auth: false` (oturum/401 mantığına girmez). E-posta ve mesaj metni LOGLANMAZ.
class PublicSupportApi {
  PublicSupportApi(this._api);

  final ApiClient _api;

  static const messageMin = 10;
  static const messageMax = 2000;
  static const nameMax = 80;
  static const emailMax = 254;

  /// Talebi gönderir ve e-postaya 6 haneli kod yollatır. `website` bal kabağı alanı gerçek kullanıcıda HER ZAMAN boştur;
  /// `elapsedMs` formun açılışından gönderime geçen süredir.
  Future<void> submit({
    required String name,
    required String email,
    required String category,
    required String message,
    required int elapsedMs,
  }) =>
      _api.post('/public/support/tickets', {
        'name': name.trim(),
        'email': email.trim(),
        'category': category,
        'message': message.trim(),
        'website': '',
        'elapsedMs': elapsedMs,
      }, false);

  /// Kodu doğrular; başarıda takip jetonunu döner.
  Future<String> verify(String email, String code) async {
    final r = await _api.post('/public/support/tickets/verify', {'email': email.trim(), 'code': code}, false) as Map<String, dynamic>;
    return r['trackToken'] as String;
  }

  Future<Map<String, dynamic>> track(String token) async =>
      await _api.post('/public/support/track', {'token': token}, false) as Map<String, dynamic>;

  Future<Map<String, dynamic>> reply(String token, String text) async =>
      await _api.post('/public/support/track/messages', {'token': token, 'text': text.trim()}, false) as Map<String, dynamic>;
}

/// Takip jetonu yalnız bu cihazın güvenli deposunda tutulur (düz metin tercih/önbellek yok); çıkış/hesap silmede
/// `registerUserDataCleaners` ile temizlenir.
class TrackTokenStore {
  static const _key = 'public_support_track_token';

  static Future<String?> read() async {
    try {
      final v = await kDeviceSecureStorage.read(key: _key);
      return (v == null || v.isEmpty) ? null : v;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String token) async {
    try {
      await kDeviceSecureStorage.write(key: _key, value: token);
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      await kDeviceSecureStorage.delete(key: _key);
    } catch (_) {}
  }
}

/// İstemci doğrulaması (sunucu yine doğrular). Hatasız alanlar `null`.
class PublicSupportErrors {
  const PublicSupportErrors({this.name, this.email, this.message});

  final PublicFieldError? name;
  final PublicFieldError? email;
  final PublicFieldError? message;

  bool get ok => name == null && email == null && message == null;
}

enum PublicFieldError { required, invalid, tooShort, tooLong }

final _emailRe = RegExp(r'^[^\s@<>,;]+@[^\s@<>,;]+\.[^\s@<>,;]{2,}$');

PublicSupportErrors validatePublicSupport({required String name, required String email, required String message}) {
  final n = name.trim();
  final e = email.trim();
  final m = message.trim();
  return PublicSupportErrors(
    name: n.isEmpty ? PublicFieldError.required : (n.length > PublicSupportApi.nameMax ? PublicFieldError.tooLong : null),
    email: e.isEmpty
        ? PublicFieldError.required
        : (e.length > PublicSupportApi.emailMax || !_emailRe.hasMatch(e) ? PublicFieldError.invalid : null),
    message: m.isEmpty
        ? PublicFieldError.required
        : (m.length < PublicSupportApi.messageMin
            ? PublicFieldError.tooShort
            : (m.length > PublicSupportApi.messageMax ? PublicFieldError.tooLong : null)),
  );
}

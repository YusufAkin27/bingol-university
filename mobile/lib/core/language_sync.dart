import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';

/// Profil dilini (bildirim/e-posta dili) sunucuyla eşitler; ama her açılışta DEĞİL, yalnız değişince:
/// son başarıyla gönderilen "kullanıcı|dil" cihazda tutulur, aynıysa istek atılmaz. Kullanıcıya özeldir
/// (çıkışta [clear] ile silinir; bkz. `registerUserDataCleaners`).
class LanguageSync {
  const LanguageSync._();

  static const key = 'synced_language';

  /// Dil son eşitlenenden farklıysa `PATCH /users/me {language}` atar. Hata sızdırmaz; başarısızsa bir sonraki
  /// açılışta yeniden denenir.
  static Future<bool> sync(ApiClient api, int? userId, String lang, {FlutterSecureStorage storage = const FlutterSecureStorage()}) async {
    final want = '${userId ?? 0}|$lang';
    try {
      if (await storage.read(key: key) == want) return false;
    } catch (_) {}
    try {
      await api.patch('/users/me', {'language': lang});
    } catch (_) {
      return false;
    }
    try {
      await storage.write(key: key, value: want);
    } catch (_) {}
    return true;
  }

  static Future<void> clear() async {
    try {
      await const FlutterSecureStorage().delete(key: key);
    } catch (_) {}
  }
}

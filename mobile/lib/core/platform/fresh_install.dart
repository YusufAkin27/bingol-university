import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// iOS Keychain kayıtları uygulama SİLİNSE de cihazda kalır; yeniden kurulumda eski oturum jetonları
/// (`access`/`refresh`) otomatik giriş yaptırırdı. Uygulama kapsayıcısındaki dosyalar ise silinmeyle gider:
/// ilk açılışta (işaret dosyası yoksa) önce işareti yazar, sonra OTURUM anahtarlarını siler.
/// Cihaz kimliği (`device_id`) bilerek korunur: yeniden kurulumla erişim engeli (cihaz yasağı) aşılamasın.
/// Android'de (Keystore kayıtları silinmeyle gider) ve işaret yazılamıyorsa (her açılışta çıkış yaptırmamak için)
/// hiçbir şey yapmaz. Hata sızdırmaz.
class FreshInstallGuard {
  FreshInstallGuard._();

  static const _marker = '.bu_installed';
  static const sessionKeys = ['access', 'refresh'];

  /// Silme yapıldıysa true. Parametreler testler içindir.
  static Future<bool> run({
    bool? isIOS,
    Future<Directory> Function()? supportDir,
    Future<void> Function(String key)? deleteKey,
  }) async {
    final ios = isIOS ?? (!kIsWeb && Platform.isIOS);
    if (!ios) return false;
    try {
      final dir = await (supportDir ?? getApplicationSupportDirectory)();
      final f = File('${dir.path}${Platform.pathSeparator}$_marker');
      if (await f.exists()) return false;
      await dir.create(recursive: true);
      await f.writeAsString('1', flush: true); // önce işaret: yazılamazsa silmeye hiç girişilmez
      final del = deleteKey ?? (String k) => const FlutterSecureStorage().delete(key: k);
      for (final k in sessionKeys) {
        try {
          await del(k);
        } catch (_) {}
      }
      return true;
    } catch (e) {
      debugPrint('FreshInstallGuard: ${e.runtimeType}');
      return false;
    }
  }
}

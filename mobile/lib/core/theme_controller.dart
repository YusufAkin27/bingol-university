import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Görünüm seçimi: Sistem / Açık / Koyu. Seçim cihazda saklanır.
class ThemeController extends ChangeNotifier {
  ThemeMode mode = ThemeMode.system;
  final _storage = const FlutterSecureStorage();
  static const _key = 'theme_mode';

  Future<void> load() async {
    try {
      mode = switch (await _storage.read(key: _key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      notifyListeners();
    } catch (_) {
      // Depo okunamazsa sistem teması kalır.
    }
  }

  Future<void> set(ThemeMode m) async {
    mode = m;
    notifyListeners();
    try {
      await _storage.write(key: _key, value: switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      });
    } catch (_) {}
  }
}

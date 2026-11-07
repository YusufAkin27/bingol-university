import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Görünüm seçimi: Sistem / Açık / Koyu. Seçim cihazda saklanır (kalıcı). Tercih HİÇ yoksa (ilk açılış) varsayılan
/// Premium Black (koyu) olur; kayıtlı kullanıcı tercihi (sistem dahil) aynen korunur. `Sistem` seçiliyken platform
/// parlaklığı değişince `MaterialApp` temayı anında günceller (uygulama yeniden başlamaz, ekran durumu korunur).
class ThemeController extends ChangeNotifier {
  /// Tercih yokken varsayılan: Premium Black.
  static const ThemeMode defaultMode = ThemeMode.dark;

  ThemeMode mode = defaultMode;
  final _storage = const FlutterSecureStorage();
  static const _key = 'theme_mode';

  Future<void> load() async {
    try {
      mode = switch (await _storage.read(key: _key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => defaultMode,
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
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
  }
}

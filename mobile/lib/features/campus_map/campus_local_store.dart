import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Kampüs haritasının YEREL verisi (sunucu ucu yok): favori yerler ve son aramalar.
/// Kullanıcıya özeldir; çıkışta [clear] ile silinir (bkz. `registerUserDataCleaners`).
class CampusLocalStore {
  const CampusLocalStore._();

  static const favoritesKey = 'campus_favorites';
  static const recentKey = 'campus_recent_searches';
  static const promptKey = 'campus_loc_prompt_dismissed';
  static const maxRecent = 8;
  static const _storage = FlutterSecureStorage();

  static Future<Set<int>> loadFavorites() async {
    try {
      final raw = await _storage.read(key: favoritesKey);
      if (raw == null) return {};
      return {for (final e in (jsonDecode(raw) as List)) if (e is num) e.toInt()};
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveFavorites(Set<int> ids) async {
    try {
      if (ids.isEmpty) {
        await _storage.delete(key: favoritesKey);
      } else {
        await _storage.write(key: favoritesKey, value: jsonEncode(ids.toList()..sort()));
      }
    } catch (_) {}
  }

  /// Son aramalar: en yeni başta, tekrarsız.
  static Future<List<String>> loadRecent() async {
    try {
      final raw = await _storage.read(key: recentKey);
      if (raw == null) return const [];
      return (jsonDecode(raw) as List).map((e) => '$e').take(maxRecent).toList();
    } catch (_) {
      return const [];
    }
  }

  /// [term] başa eklenir; aynı terim ([fold] ile büyük/küçük harf ve aksan duyarsız) tekrarlanmaz.
  static List<String> pushRecent(List<String> current, String term, String Function(String) fold) {
    final t = term.trim();
    if (t.length < 2) return current;
    return [t, ...current.where((e) => fold(e) != fold(t))].take(maxRecent).toList();
  }

  static Future<void> saveRecent(List<String> list) async {
    try {
      if (list.isEmpty) {
        await _storage.delete(key: recentKey);
      } else {
        await _storage.write(key: recentKey, value: jsonEncode(list.take(maxRecent).toList()));
      }
    } catch (_) {}
  }

  /// "Konumunuzu kullanalım mı?" kartında "Şimdi değil" seçildi mi (kart her açılışta tekrar çıkmasın).
  static Future<bool> loadPromptDismissed() async {
    try {
      return await _storage.read(key: promptKey) == '1';
    } catch (_) {
      return false;
    }
  }

  static Future<void> savePromptDismissed() async {
    try {
      await _storage.write(key: promptKey, value: '1');
    } catch (_) {}
  }

  /// Çıkış / hesap değişimi: favoriler + son aramalar + izin kartı tercihi.
  static Future<void> clear() async {
    try {
      await _storage.delete(key: favoritesKey);
      await _storage.delete(key: recentKey);
      await _storage.delete(key: promptKey);
    } catch (_) {}
  }
}

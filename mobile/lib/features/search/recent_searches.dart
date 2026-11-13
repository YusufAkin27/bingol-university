import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Arama geçmişi (son 10 terim). Kullanıcıya özeldir (kişi adı olabilir): çıkışta [clear] ile silinir
/// (bkz. `registerUserDataCleaners`).
class RecentSearches {
  const RecentSearches._();

  static const key = 'recent_searches';
  static const max = 10;
  static const _storage = FlutterSecureStorage();

  /// Hesap bazlı anahtar: aynı cihazda başka hesap açılınca geçmiş karışmaz.
  static String _key(int? userId) => userId == null ? key : '${key}_$userId';

  static Future<List<String>> load([int? userId]) async {
    try {
      final raw = await _storage.read(key: _key(userId));
      if (raw == null) return const [];
      return (jsonDecode(raw) as List).map((e) => e.toString()).take(max).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(int? userId, List<String> list) async {
    try {
      await _storage.write(key: _key(userId), value: jsonEncode(list.take(max).toList()));
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
  }

  /// Tek hesabın geçmişini siler ("Temizle").
  static Future<void> clearFor(int? userId) async {
    try {
      await _storage.delete(key: _key(userId));
    } catch (_) {
      // Bilerek yutulur.
    }
  }

  /// Çıkışta: tüm hesapların ve eski ortak anahtarın geçmişi silinir.
  static Future<void> clear() async {
    try {
      final all = await _storage.readAll();
      for (final k in all.keys) {
        if (k == key || k.startsWith('${key}_')) await _storage.delete(key: k);
      }
      await _storage.delete(key: key);
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
  }
}

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Arama geçmişi (son 8 terim). Kullanıcıya özeldir (kişi adı olabilir): çıkışta [clear] ile silinir
/// (bkz. `registerUserDataCleaners`).
class RecentSearches {
  const RecentSearches._();

  static const key = 'recent_searches';
  static const max = 8;
  static const _storage = FlutterSecureStorage();

  static Future<List<String>> load() async {
    try {
      final raw = await _storage.read(key: key);
      if (raw == null) return const [];
      return (jsonDecode(raw) as List).map((e) => e.toString()).take(max).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(List<String> list) async {
    try {
      await _storage.write(key: key, value: jsonEncode(list.take(max).toList()));
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }
}

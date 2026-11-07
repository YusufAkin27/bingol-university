import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Forum son aramaları (cihazda; sunucuda arama günlüğü YOK). En çok [max] terim, en yeni başta.
/// Kullanıcıya özeldir: çıkışta [clear] ile silinir (bkz. `registerUserDataCleaners`).
class ForumRecentSearches {
  const ForumRecentSearches._();

  static const key = 'forum_recent_searches';
  static const max = 10;
  static const _storage = FlutterSecureStorage();

  static Future<List<String>> load() async {
    try {
      final raw = await _storage.read(key: key);
      if (raw == null) return const [];
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final e in list)
          if (e is String && e.trim().isNotEmpty) e.trim()
      ].take(max).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _save(List<String> list) async {
    try {
      await _storage.write(key: key, value: jsonEncode(list.take(max).toList()));
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
  }

  /// Terimi başa ekler (büyük/küçük harf duyarsız yinelenen önceki kayıt silinir); güncel listeyi döner.
  static Future<List<String>> add(String term) async {
    final q = term.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (q.length < 2) return load();
    final cur = await load();
    final lower = q.toLowerCase();
    final next = [q, ...cur.where((e) => e.toLowerCase() != lower)].take(max).toList();
    await _save(next);
    return next;
  }

  static Future<List<String>> remove(String term) async {
    final lower = term.trim().toLowerCase();
    final next = (await load()).where((e) => e.toLowerCase() != lower).toList();
    await _save(next);
    return next;
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: key);
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
  }
}

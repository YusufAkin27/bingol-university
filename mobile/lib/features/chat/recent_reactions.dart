import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'emoji_presentation.dart';

/// User-specific recently used reactions (up to 8 stored, 6 shown in the quick bar); cleared on account changes.
abstract final class RecentReactions {
  static const key = 'chat_recent_reactions';
  static const defaults = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
  static const barSize = 6;
  static const storedMax = 8;
  static const _storage = FlutterSecureStorage();
  static Future<void> _writes = Future<void>.value();
  static int _epoch = 0;

  /// Görünüm seçicisi eksik emojiler (❤) renkli çizilsin diye tamamlanır.
  static String display(String emoji) => withEmojiPresentation(emoji);

  static bool isEmoji(String value) =>
      value.isNotEmpty &&
      value.characters.length == 1 &&
      value.length <= 16 &&
      RegExp(
        r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2300}-\u{23FF}\u{2B00}-\u{2BFF}\u{2190}-\u{21FF}\u{25A0}-\u{25FF}\u2934\u2935\u24C2\u00A9\u00AE\u203C\u2049\u2122\u2139\u3030\u303D\u3297\u3299\u20E3]',
        unicode: true,
      ).hasMatch(value);

  /// Cihazda saklanan, gerçekten kullanılmış tepkiler (en yeni önde, en çok [storedMax]).
  static Future<List<String>> loadRecent() async {
    try {
      final raw = await _storage.read(key: key);
      if (raw != null) {
        return <String>{
          ...(jsonDecode(raw) as List).whereType<String>().where(isEmoji).map(display)
        }.take(storedMax).toList();
      }
    } catch (_) {}
    return const [];
  }

  /// Hızlı tepki çubuğu: son kullanılanlar + sunucu listesi + varsayılanlar (en çok [barSize]).
  static Future<List<String>> load({List<String> fallback = defaults}) async {
    final recent = await loadRecent();
    return <String>{
      ...recent,
      ...fallback.where(isEmoji).map(display),
      ...defaults
    }.take(barSize).toList();
  }

  static Future<void> record(String emoji) {
    if (!isEmoji(emoji)) return Future<void>.value();
    final epoch = _epoch;
    return _writes = _writes.then((_) async {
      if (epoch != _epoch) return;
      final old = await loadRecent();
      if (epoch != _epoch) return;
      final next = <String>{display(emoji), ...old}.take(storedMax).toList();
      await _storage.write(key: key, value: jsonEncode(next));
    }).catchError((Object _) {});
  }

  static Future<void> clear() {
    _epoch++;
    return _writes = _writes
        .then((_) => _storage.delete(key: key))
        .catchError((Object _) {});
  }
}

import 'emoji_data.dart';

/// Tepki seçicinin kategorileri; sıra = sekme sırası, [id] `emoji_data.dart` anahtarıdır.
enum EmojiCategory {
  faces('faces', '😀'),
  people('people', '👋'),
  nature('nature', '🐻'),
  food('food', '🍔'),
  activities('activities', '⚽'),
  travel('travel', '🚗'),
  objects('objects', '💡'),
  symbols('symbols', '❤️'),
  flags('flags', '🏁');

  const EmojiCategory(this.id, this.glyph);
  final String id;

  /// Sekme simgesi olarak çizilen temsilci emoji.
  final String glyph;
}

class EmojiEntry {
  const EmojiEntry(this.emoji, this.haystack);
  final String emoji;

  /// Katlanmış (küçük harf, aksansız) arama metni: İngilizce + Türkçe + Arapça ad ve anahtar kelimeler.
  final String haystack;
}

/// Yerel emoji kataloğu (Unicode emoji 15.0, ten rengi yok). İlk kullanımda bir kez ayrıştırılır.
abstract final class EmojiCatalog {
  static Map<EmojiCategory, List<EmojiEntry>>? _all;

  static Map<EmojiCategory, List<EmojiEntry>> get all => _all ??= _parse();

  static Map<EmojiCategory, List<EmojiEntry>> _parse() {
    final out = <EmojiCategory, List<EmojiEntry>>{};
    for (final c in EmojiCategory.values) {
      final raw = kEmojiData[c.id] ?? '';
      final list = <EmojiEntry>[];
      for (final line in raw.split('\n')) {
        final row = line.trim();
        if (row.isEmpty) continue;
        final p = row.split('|');
        list.add(EmojiEntry(p.first, fold(p.skip(1).join(' '))));
      }
      out[c] = list;
    }
    return out;
  }

  static const _map = {
    'ı': 'i',
    'ç': 'c',
    'ğ': 'g',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
  };

  /// Türkçe farkındalıklı küçültme + aksan atma ("İstanbul" ile "istanbul" eşleşir).
  static String fold(String s) {
    final lower = s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
    final b = StringBuffer();
    for (final ch in lower.split('')) {
      b.write(_map[ch] ?? ch);
    }
    return b.toString();
  }

  /// Her sözcüğün geçtiği emojiler; en çok [limit] sonuç.
  static List<EmojiEntry> search(String query, {int limit = 240}) {
    final terms =
        fold(query.trim()).split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    if (terms.isEmpty) return const [];
    final out = <EmojiEntry>[];
    for (final c in EmojiCategory.values) {
      for (final e in all[c]!) {
        if (terms.every(e.haystack.contains)) {
          out.add(e);
          if (out.length >= limit) return out;
        }
      }
    }
    return out;
  }
}

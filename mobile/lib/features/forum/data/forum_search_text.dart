/// Forum aramasında saf metin yardımcıları (UI'siz test edilir).
library;

/// Arama terimini sadeleştirir: kenar boşlukları atılır, ardışık boşluklar tek boşluk olur.
String normalizeForumQuery(String q) => q.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Sunucunun kabul ettiği en kısa terim uzunluğu.
const int kForumSearchMinChars = 2;

bool forumQueryActive(String q) => normalizeForumQuery(q).runes.length >= kForumSearchMinChars;

/// Tek karakteri uzunluğu DEĞİŞTİRMEDEN katlar (Türkçe: İ, I, ı hepsi `i`; böylece "ILIK" ile "ılık" eşleşir ve
/// indeksler özgün metinle birebir kalır; Dart'ın `toLowerCase`i 'İ'yi iki kod birimine çevirip indeksleri kaydırır).
String _foldChar(String ch) => switch (ch) {
      'İ' || 'I' || 'ı' => 'i',
      'Ş' => 'ş',
      'Ğ' => 'ğ',
      'Ü' => 'ü',
      'Ö' => 'ö',
      'Ç' => 'ç',
      _ => ch.length == 1 ? ch.toLowerCase() : ch,
    };

String _fold(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final f = _foldChar(ch);
    b.write(f.length == ch.length ? f : ch);
  }
  return b.toString();
}

/// Metin parçası ve vurgulu mu bilgisi.
class ForumTextSegment {
  const ForumTextSegment(this.text, this.highlight);

  final String text;
  final bool highlight;

  @override
  bool operator ==(Object other) => other is ForumTextSegment && other.text == text && other.highlight == highlight;

  @override
  int get hashCode => Object.hash(text, highlight);

  @override
  String toString() => '${highlight ? '[' : ''}$text${highlight ? ']' : ''}';
}

/// [text] içinde [query] sözcüklerinin (en az 2 karakter) geçtiği yerleri işaretler; harf büyüklüğü ve Türkçe
/// İ/ı farkı yok sayılır. Birbirine değen/çakışan eşleşmeler birleşir. Eşleşme yoksa tek parça döner.
List<ForumTextSegment> splitForumHighlight(String text, String query) {
  if (text.isEmpty) return const [];
  final terms = {
    for (final w in normalizeForumQuery(query).split(' '))
      if (w.runes.length >= kForumSearchMinChars) _fold(w),
  }.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  if (terms.isEmpty) return [ForumTextSegment(text, false)];
  final folded = _fold(text);
  final marks = List<bool>.filled(text.length, false);
  var any = false;
  for (final term in terms) {
    var from = 0;
    while (true) {
      final i = folded.indexOf(term, from);
      if (i < 0) break;
      for (var k = i; k < i + term.length && k < marks.length; k++) {
        marks[k] = true;
      }
      any = true;
      from = i + term.length;
    }
  }
  if (!any) return [ForumTextSegment(text, false)];
  final out = <ForumTextSegment>[];
  var start = 0;
  for (var i = 1; i <= text.length; i++) {
    if (i == text.length || marks[i] != marks[start]) {
      out.add(ForumTextSegment(text.substring(start, i), marks[start]));
      start = i;
    }
  }
  return out;
}

/// Yazı biçimi varsayılan olan emojilere (❤ ♥ ☺ ✌ …) renkli emoji görünüm seçicisi (U+FE0F) ekler.
///
/// Seçici eksik gelince (klavye/sunucu/eski sürüm) sistem bu karakterleri yazı glifiyle çizer: kırmızı kalp siyah çıkar.
/// Açıkça yazı biçimi istenmişse (U+FE0E) dokunulmaz. Metin içeriği aynı kalır, yalnız görünüm seçici eklenir.
library;

import 'package:flutter/painting.dart' show TextStyle, TextSpan, InlineSpan;

final RegExp _textDefault = RegExp(
  '[❤❣♥♠♣♦☺☹☀-☄☎☑☘☝☠✌✍✏✔✖❄❇⚙⚠]'
  '(?![︎️])',
);

String withEmojiPresentation(String s) =>
    s.isEmpty ? s : s.replaceAllMapped(_textDefault, (m) => '${m[0]}️');

/// Emoji katarları için renkli emoji yazı tipi. Inter'de ❤ ♥ ☀ gibi karakterlerin TEK RENKLİ glifleri var; bu yüzden
/// emoji yazı tipi açıkça verilmezse kalp renkli emoji yerine metin renginde (beyaz/siyah) çizilir.
const TextStyle kEmojiFontStyle = TextStyle(
    fontFamily: 'Apple Color Emoji',
    fontFamilyFallback: ['Noto Color Emoji', 'Segoe UI Emoji']);

final RegExp _emojiRun = RegExp(
    '(?:[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B50}\u{2B55}\u{231A}\u{231B}\u{23E9}-\u{23F3}\u{2705}\u{2728}\u{274C}\u{274E}\u{2753}-\u{2755}\u{2757}\u{2795}-\u{2797}\u{2B1B}\u{2B1C}]'
    '[\u{FE0F}\u{1F3FB}-\u{1F3FF}]?(?:\u{200D}[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2640}\u{2642}][\u{FE0F}\u{1F3FB}-\u{1F3FF}]?)*)+',
    unicode: true);

/// Metni, emoji katarları renkli emoji yazı tipiyle ve [scale] kat büyük çizilecek biçimde TextSpan'e böler.
TextSpan emojiAwareSpan(String text, TextStyle style, {double scale = 1.3}) {
  final s = withEmojiPresentation(text);
  final ms = _emojiRun.allMatches(s).toList();
  if (ms.isEmpty) return TextSpan(text: s, style: style);
  final big = kEmojiFontStyle.copyWith(fontSize: (style.fontSize ?? 14) * scale);
  final out = <InlineSpan>[];
  var i = 0;
  for (final m in ms) {
    if (m.start > i) out.add(TextSpan(text: s.substring(i, m.start)));
    out.add(TextSpan(text: m.group(0), style: big));
    i = m.end;
  }
  if (i < s.length) out.add(TextSpan(text: s.substring(i)));
  return TextSpan(style: style, children: out);
}

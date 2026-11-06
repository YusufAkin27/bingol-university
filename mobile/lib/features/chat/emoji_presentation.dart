/// Yazı biçimi varsayılan olan emojilere (❤ ♥ ☺ ✌ …) renkli emoji görünüm seçicisi (U+FE0F) ekler.
///
/// Seçici eksik gelince (klavye/sunucu/eski sürüm) sistem bu karakterleri yazı glifiyle çizer: kırmızı kalp siyah çıkar.
/// Açıkça yazı biçimi istenmişse (U+FE0E) dokunulmaz. Metin içeriği aynı kalır, yalnız görünüm seçici eklenir.
library;

import 'package:flutter/painting.dart' show TextStyle;

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

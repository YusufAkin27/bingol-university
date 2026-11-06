/// Yazı biçimi varsayılan olan emojilere (❤ ♥ ☺ ✌ …) renkli emoji görünüm seçicisi (U+FE0F) ekler.
///
/// Seçici eksik gelince (klavye/sunucu/eski sürüm) sistem bu karakterleri yazı glifiyle çizer: kırmızı kalp siyah çıkar.
/// Açıkça yazı biçimi istenmişse (U+FE0E) dokunulmaz. Metin içeriği aynı kalır, yalnız görünüm seçici eklenir.
library;

final RegExp _textDefault = RegExp(
  '[❤❣♥♠♣♦☺☹☀-☄☎☑☘☝☠✌✍✏✔✖❄❇⚙⚠]'
  '(?![︎️])',
);

String withEmojiPresentation(String s) =>
    s.isEmpty ? s : s.replaceAllMapped(_textDefault, (m) => '${m[0]}️');

/// Yazi bicimi varsayilan olan emojilere (kalp, kalp isareti vb.) renkli emoji gorunum secicisi (U+FE0F) ekler.
///
///
/// Seçici eksik gelince (klavye/sunucu/eski sürüm) sistem bu karakterleri yazı glifiyle çizer: kırmızı kalp siyah çıkar.
/// Açıkça yazı biçimi istenmişse (U+FE0E) dokunulmaz. Metin içeriği aynı kalır, yalnız görünüm seçici eklenir.
library;

import 'package:flutter/widgets.dart';

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
/// Emoji, düz yazıya göre sohbet balonlarıyla aynı oranda (1.36) büyük; başlıklarda sohbetten %20 fazla (1.632).
const double kEmojiScale = 1.36; // önceki 1.7 değerinden %20 küçük (kullanıcı kararı 2026-11-08)
const double kEmojiTitleScale = 1.632; // sohbetten %20 büyük

TextSpan emojiAwareSpan(String text, TextStyle style, {double scale = kEmojiScale}) {
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

/// Yazarken emojileri renkli yazı tipiyle ve %30 büyük çizen denetleyici (metin değerine dokunmaz).
class EmojiTextEditingController extends TextEditingController {
  EmojiTextEditingController({super.text, this.scale = kEmojiScale});

  final double scale;

  /// IME metni değiştirince yazı biçimi varsayılan emojilere (kalp vb.) renkli sunum seçicisi eklenir; imleç kaydırılır.
  @override
  set value(TextEditingValue v) {
    final fixed = withEmojiPresentation(v.text);
    if (fixed.length == v.text.length) {
      super.value = v;
      return;
    }
    int shift(int off) {
      if (off < 0) return off;
      var add = 0;
      for (final m in _textDefault.allMatches(v.text)) {
        if (m.end <= off) add++;
      }
      return off + add;
    }
    super.value = TextEditingValue(
      text: fixed,
      selection: TextSelection(
        baseOffset: shift(v.selection.baseOffset),
        extentOffset: shift(v.selection.extentOffset),
        affinity: v.selection.affinity,
        isDirectional: v.selection.isDirectional,
      ),
    );
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final base = style ?? const TextStyle();
    final s = text;
    final ms = _emojiRun.allMatches(s).toList();
    if (ms.isEmpty) return TextSpan(text: s, style: base);
    final big = kEmojiFontStyle.copyWith(fontSize: (base.fontSize ?? 14) * scale);
    final out = <InlineSpan>[];
    var i = 0;
    for (final m in ms) {
      if (m.start > i) out.add(TextSpan(text: s.substring(i, m.start)));
      out.add(TextSpan(text: m.group(0), style: big));
      i = m.end;
    }
    if (i < s.length) out.add(TextSpan(text: s.substring(i)));
    return TextSpan(style: base, children: out);
  }
}

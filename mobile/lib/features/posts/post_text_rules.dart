import 'package:flutter/services.dart';

/// Gönderi metni: isteğe bağlı, istenen uzunlukta, çok satırlı. Sunucunun gizli üst sınırı 2200 karakter / 40 satırdır
/// (aşılırsa 422 `POST_TEXT_TOO_LONG`). İstemci bu sınırı kullanıcıya GÖSTERMEZ: ne sayaç ne uyarı; giriş sınırda
/// sessizce durur.
const kPostMaxChars = 2200;
const kPostMaxLines = 40;

/// [text] sınırlara sığacak şekilde kırpılır: en çok [kPostMaxLines] satır ve [kPostMaxChars] karakter.
String clampPostText(String text) {
  var out = text;
  final lines = out.split('\n');
  if (lines.length > kPostMaxLines) out = lines.take(kPostMaxLines).join('\n');
  if (out.length > kPostMaxChars) {
    var end = kPostMaxChars;
    // Vekil çiftin (emoji) ortasından kesilmesin.
    final unit = out.codeUnitAt(end - 1);
    if (unit >= 0xD800 && unit <= 0xDBFF) end--;
    out = out.substring(0, end);
  }
  return out;
}

/// Giriş biçimlendirici: aşan kısmı sessizce keser (yapıştırmada da); imleç sınıra çekilir.
class PostTextLimiter extends TextInputFormatter {
  const PostTextLimiter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final clamped = clampPostText(newValue.text);
    if (clamped == newValue.text) return newValue;
    final off = newValue.selection.baseOffset.clamp(0, clamped.length);
    return TextEditingValue(text: clamped, selection: TextSelection.collapsed(offset: off));
  }
}

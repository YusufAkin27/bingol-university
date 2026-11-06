import 'package:flutter/services.dart';

/// Metin uzunluğunu UTF-16 kod birimi olarak sınırlar (Dart `String.length` ve sunucu Java `@Size`/`String.length()`
/// ile AYNI birim). Flutter'ın `maxLength` sınırı grafem sayar: çok emojili metin alanda sınırın altında görünüp
/// sunucuda 400 `VALIDATION_ERROR` alırdı (QA5-12). Vekil çift (emoji) ortadan bölünmez.
class Utf16LengthLimiter extends TextInputFormatter {
  const Utf16LengthLimiter(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.length <= max) return newValue;
    var cut = max;
    // Vekil çiftin ortasında kesme: yüksek vekil (D800-DBFF) sonda kalırsa onu da at.
    final last = text.codeUnitAt(cut - 1);
    if (last >= 0xD800 && last <= 0xDBFF) cut--;
    final cutText = text.substring(0, cut);
    final off = newValue.selection.baseOffset.clamp(0, cut);
    return TextEditingValue(text: cutText, selection: TextSelection.collapsed(offset: off));
  }
}

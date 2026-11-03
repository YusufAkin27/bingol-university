import 'package:flutter/services.dart';

import 'locale_controller.dart';

/// Ad soyad yazarken her kelimenin ilk harfini büyük, kalanını küçük yapar ("ahmet yılmaz" -> "Ahmet Yılmaz",
/// "AYŞE" -> "Ayşe"). Kelime sınırı: boşluk, tire ve kesme işareti. Türkçede (ya da dil henüz bilinmiyorken) i/İ ve ı/I
/// kuralı uygulanır; başka dillerde yerel ayardan bağımsız standart büyük/küçük harf. Her karakter tek karaktere
/// dönüştüğü için uzunluk ve imleç konumu korunur.
class NameCaseFormatter extends TextInputFormatter {
  const NameCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = titleCaseName(newValue.text);
    if (text == newValue.text) return newValue;
    return newValue.copyWith(text: text);
  }
}

/// [NameCaseFormatter]'ın saf işlevi (test ve yapıştırma için).
String titleCaseName(String input) {
  final lang = LocaleController.current?.locale.languageCode;
  final turkish = lang == null || lang == 'tr';
  final out = StringBuffer();
  var boundary = true;
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    final isBoundary = ch == ' ' || ch == '-' || ch == "'" || ch == '’';
    if (isBoundary) {
      out.write(ch);
      boundary = true;
      continue;
    }
    out.write(boundary ? _upper(ch, turkish) : _lower(ch, turkish));
    boundary = false;
  }
  return out.toString();
}

String _upper(String ch, bool turkish) {
  if (turkish) {
    if (ch == 'i') return 'İ';
    if (ch == 'ı') return 'I';
  }
  final u = ch.toUpperCase();
  return u.length == ch.length ? u : ch; // ß -> SS gibi uzunluk değiştirenler olduğu gibi kalır
}

String _lower(String ch, bool turkish) {
  if (turkish) {
    if (ch == 'I') return 'ı';
    if (ch == 'İ') return 'i';
  }
  final l = ch.toLowerCase();
  return l.length == ch.length ? l : ch; // İ -> i̇ (iki kod birimi) gibi durumlar olduğu gibi kalır
}

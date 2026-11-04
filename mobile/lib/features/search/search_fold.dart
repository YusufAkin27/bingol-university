import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Arama eşleştirmesi için büyük/küçük harf ve Türkçe karakter duyarsız katlama. UZUNLUK KORUNUR (her karakter bir
/// karaktere gider), böylece katlanmış metindeki konum özgün metne birebir uygulanır (vurgulama).
/// İ/I/ı -> i, ş -> s, ğ -> g, ü -> u, ö -> o, ç -> c (sunucu `foldTr` ile aynı mantık).
String searchFold(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    b.write(switch (c) {
      'İ' || 'I' || 'ı' => 'i',
      'ş' || 'Ş' => 's',
      'ğ' || 'Ğ' => 'g',
      'ü' || 'Ü' => 'u',
      'ö' || 'Ö' => 'o',
      'ç' || 'Ç' => 'c',
      _ => c.length == 1 ? c.toLowerCase() : c,
    });
  }
  return b.toString();
}

/// [text] içinde [query]'nin (katlanmış) eşleşen parçalarını marka rengi + 600 ağırlıkla vurgular.
/// Eşleşme yoksa ya da katlama uzunluğu bozulursa (nadir birleşik karakterler) düz metin döner.
InlineSpan searchHighlight(BuildContext context, String text, String query, TextStyle base) {
  final t = context.bu;
  final q = searchFold(query.trim());
  if (q.isEmpty) return TextSpan(text: text, style: base);
  final src = searchFold(text);
  if (src.length != text.length) return TextSpan(text: text, style: base);
  final spans = <InlineSpan>[];
  var from = 0;
  while (true) {
    final i = src.indexOf(q, from);
    if (i < 0) break;
    if (i > from) spans.add(TextSpan(text: text.substring(from, i), style: base));
    spans.add(TextSpan(text: text.substring(i, i + q.length), style: base.copyWith(fontWeight: FontWeight.w700, color: t.pr)));
    from = i + q.length;
  }
  if (spans.isEmpty) return TextSpan(text: text, style: base);
  if (from < text.length) spans.add(TextSpan(text: text.substring(from), style: base));
  return TextSpan(children: spans);
}

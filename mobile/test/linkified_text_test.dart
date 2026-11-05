import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/widgets/linkified_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitLinks', () {
    test('duyuru metnindeki adres bağlantı olur, cümle sonu noktası dışarıda kalır', () {
      const text = 'Görev Talebi İşlemleri https://gis.osym.gov.tr/ internet adresinden 05.11.2026 tarihine kadar.';
      final segs = splitLinks(text);
      final link = segs.where((s) => s.uri != null).toList();
      expect(link, hasLength(1));
      expect(link.single.text, 'https://gis.osym.gov.tr/');
      expect(link.single.uri.toString(), 'https://gis.osym.gov.tr/');
      expect(segs.map((s) => s.text).join(), text, reason: 'metin kaybı olmamalı');
    });

    test('sondaki nokta, virgül ve kapanan parantez bağlantıya dahil edilmez', () {
      for (final tail in ['.', ',', ';', ':', '!', '?', ')']) {
        final segs = splitLinks('(bkz https://ornek.bingol.edu.tr/duyuru$tail');
        final link = segs.firstWhere((s) => s.uri != null);
        expect(link.text, 'https://ornek.bingol.edu.tr/duyuru', reason: 'ek: $tail');
      }
    });

    test('http ve www adresleri https açılır', () {
      expect(splitLinks('http://a.bingol.edu.tr/x').single.uri.toString(), 'https://a.bingol.edu.tr/x');
      expect(splitLinks('www.bingol.edu.tr').single.uri.toString(), 'https://www.bingol.edu.tr');
    });

    test('birden çok bağlantı ve düz metin sırası korunur', () {
      const text = 'a https://x.edu.tr/1 b http://y.edu.tr/2 c';
      final segs = splitLinks(text);
      expect(segs.map((s) => s.text).join(), text);
      expect(segs.where((s) => s.uri != null), hasLength(2));
    });

    test('bağlantı yoksa tek düz parça döner; boş metin boş liste', () {
      expect(splitLinks('Sadece metin.').single.uri, isNull);
      expect(splitLinks(''), isEmpty);
    });

    test('geçersiz ya da güvenli olmayan şema bağlantı sayılmaz', () {
      expect(splitLinks('javascript:alert(1)').every((s) => s.uri == null), isTrue);
      expect(splitLinks('ftp://x.edu.tr/a').every((s) => s.uri == null), isTrue);
      expect(splitLinks('https://').every((s) => s.uri == null), isTrue);
      expect(normalizeHref('https://nodot'), isNull);
    });
  });

  testWidgets('LinkifiedText bağlantıyı tıklanabilir span olarak çizer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BuTheme.light(),
        home: const Scaffold(
          body: LinkifiedText('İşlem için https://gis.osym.gov.tr/ adresine gidin.', style: TextStyle(fontSize: 16)),
        ),
      ),
    );
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    final tappable = <TextSpan>[];
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.recognizer is TapGestureRecognizer) tappable.add(span);
      return true;
    });
    expect(tappable, hasLength(1));
    expect(tappable.single.text, 'https://gis.osym.gov.tr/');
    expect(tappable.single.style?.decoration, TextDecoration.underline);
  });
}

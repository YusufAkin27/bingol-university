import 'package:bu_kampus/core/name_format.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('titleCaseName (Türkçe)', () {
    test('her kelimenin ilk harfi büyük, kalanı küçük', () {
      expect(titleCaseName('ahmet yılmaz'), 'Ahmet Yılmaz');
      expect(titleCaseName('AYŞE KAYA'), 'Ayşe Kaya');
      expect(titleCaseName('mEHMET ali'), 'Mehmet Ali');
    });

    test('Türkçe i/İ ve ı/I kuralı', () {
      expect(titleCaseName('ilker ışık'), 'İlker Işık');
      expect(titleCaseName('İLKER IŞIK'), 'İlker Işık');
      expect(titleCaseName('ibrahim'), 'İbrahim');
    });

    test('boşluk, tire ve kesme kelime sınırıdır; ardışık boşluk korunur', () {
      expect(titleCaseName('ali-can öztürk'), 'Ali-Can Öztürk');
      expect(titleCaseName("o'brien"), "O'Brien");
      expect(titleCaseName('ayşe  nur'), 'Ayşe  Nur');
      expect(titleCaseName(''), '');
    });
  });

  test('formatlayıcı uzunluğu ve imleç konumunu korur', () {
    const f = NameCaseFormatter();
    const old = TextEditingValue(text: 'ahme', selection: TextSelection.collapsed(offset: 4));
    const next = TextEditingValue(text: 'ahmet', selection: TextSelection.collapsed(offset: 5));
    final out = f.formatEditUpdate(old, next);
    expect(out.text, 'Ahmet');
    expect(out.selection.baseOffset, 5);
  });
}

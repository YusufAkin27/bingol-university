import 'package:bu_kampus/features/chat/long_message.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_test/flutter_test.dart';

// Uzun mesaj: sınır (kod noktası), 400 + 700 kesimi, kelime/grafem sınırı.

String _words(int n) {
  final b = StringBuffer();
  var i = 0;
  while (b.length < n) {
    b.write('kelime${i++} ');
  }
  return b.toString().substring(0, n);
}

void main() {
  test('sinir 10000; sayım kod noktasıdır (emoji 1, Türkçe 1, satır sonu 1)', () {
    expect(kChatMaxLen, 10000);
    expect(chatMsgLen('😀' * 10000), 10000);
    expect(('😀' * 10000).length, 20000);
    expect(chatMsgLen('çğıöşü\nİ'), 8);
    expect(chatMsgLen('a' * 10001) > kChatMaxLen, isTrue);
    expect(kChatCounterFrom, lessThan(kChatMaxLen));
  });

  for (final n in [100, 400]) {
    test('$n karakter: kesilmez', () {
      final v = longMsgView(_words(n));
      expect(v.truncated, isFalse);
      expect(v.shown, _words(n));
      expect(v.canCollapse, isFalse);
    });
  }

  for (final n in [401, 800, 1100, 1101, 2000, 5000, 10000]) {
    test('$n karakter: ilk görünüm 400 (kelime sınırında) + devamı var', () {
      final text = _words(n);
      final v = longMsgView(text);
      expect(v.truncated, isTrue);
      expect(v.shown.length, lessThanOrEqualTo(kLongMsgBase));
      expect(v.shown.length, greaterThan(kLongMsgBase - 20));
      expect(text.startsWith(v.shown), isTrue);
      // Kelime ortasından kesilmez: kesimden sonraki karakter boşluk ya da kesilen metin tam kelimelerle biter.
      expect(text[v.shown.length], ' ');
    });
  }

  test('her basışta +700: 400 -> 1100 -> 1800 ... tamamı açılınca Daha az göster', () {
    final text = _words(2000);
    var limit = nextLongMsgLimit(null);
    expect(limit, 1100);
    var v = longMsgView(text, limit: limit);
    expect(v.truncated, isTrue);
    expect(v.shown.length, inInclusiveRange(1050, 1100));
    limit = nextLongMsgLimit(limit);
    expect(limit, 1800);
    v = longMsgView(text, limit: limit);
    expect(v.truncated, isTrue);
    limit = nextLongMsgLimit(limit);
    expect(limit, 2500);
    v = longMsgView(text, limit: limit);
    expect(v.truncated, isFalse);
    expect(v.shown, text);
    expect(v.canCollapse, isTrue);
    // Daralt: sınır sıfırlanır (null) -> 400.
    expect(longMsgView(text).shown.length, lessThanOrEqualTo(kLongMsgBase));
  });

  test('10000 karakter 15 basışta tamamen açılır', () {
    final text = _words(10000);
    int? limit;
    var presses = 0;
    while (longMsgView(text, limit: limit).truncated) {
      limit = nextLongMsgLimit(limit);
      presses++;
      expect(presses, lessThan(20));
    }
    expect(presses, 14); // 400 + 14*700 = 10200 >= 10000
    expect(longMsgView(text, limit: limit).shown, text);
  });

  test('emoji/grafem içinden kesilmez (ZWJ aile, bayrak, birleşik işaret)', () {
    const family = '👨‍👩‍👧‍👦'; // 1 grafem, 11 UTF-16 birimi
    const flag = '🇹🇷';
    final text = (family + flag + 'é') * 200; // her biri 3 grafem
    final v = longMsgView(text);
    expect(v.truncated, isTrue);
    expect(v.shown.characters.length, lessThanOrEqualTo(kLongMsgBase));
    // Kesilen metnin son grafemi tam bir birimdir (yarım ZWJ / tek bayrak yok).
    final last = v.shown.characters.last;
    expect(['é', family, flag], contains(last));
    expect(v.shown.runes.contains(0xFFFD), isFalse);
    // Tek bir tuhaf yarım vekil yok.
    for (var i = 0; i < v.shown.length; i++) {
      final c = v.shown.codeUnitAt(i);
      if (c >= 0xD800 && c <= 0xDBFF) {
        expect(v.shown.codeUnitAt(i + 1) & 0xFC00, 0xDC00);
        i++;
      }
    }
  });

  test('boşluğu olmayan uzun blok: grafem sınırında tam 400', () {
    final v = longMsgView('a' * 5000);
    expect(v.truncated, isTrue);
    expect(v.shown.length, kLongMsgBase);
  });

  test('Türkçe, çok satırlı ve bağlantılı metin', () {
    final tr = 'Öğrenci işleri çağrı şüphesiz ığdır '.padRight(900, 'İğüş ');
    final v = longMsgView(tr);
    expect(v.truncated, isTrue);
    expect(tr.startsWith(v.shown), isTrue);

    final multi = List.generate(120, (i) => 'Satır $i burada').join('\n');
    final m = longMsgView(multi);
    expect(m.truncated, isTrue);
    expect(m.shown.endsWith('\n'), isFalse);
    expect(multi.startsWith(m.shown), isTrue);

    final link = '${_words(380)} https://www.bingol.edu.tr/duyurular/ornek-uzun-baglanti ve devami ${_words(500)}';
    final l = longMsgView(link);
    expect(l.truncated, isTrue);
    // Bağlantı ortasından kesilmez: kesim boşlukta.
    expect(link[l.shown.length], anyOf(' ', '\n'));
  });

  test('arama eşleşmesi gizli kalmaz (keepVisible)', () {
    final text = '${_words(2000)} HEDEF kelime';
    final off = text.indexOf('HEDEF');
    final v = longMsgView(text, keepVisible: off + 5);
    expect(v.shown.contains('HEDEF'), isTrue);
    expect(longMsgView(text).shown.contains('HEDEF'), isFalse);
  });

  test('emoji ağırlıklı metin: UTF-16 uzun, grafem kısa ise kesilmez', () {
    final text = '😀' * 300; // 600 UTF-16, 300 grafem
    final v = longMsgView(text);
    expect(v.truncated, isFalse);
    expect(v.shown, text);
  });
}

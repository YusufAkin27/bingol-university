import 'dart:convert';

import 'package:bu_kampus/features/events/qr_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bağımsız çözücü: üreticinin çıktısını QR şartnamesine göre okuyup doğrular
/// (biçim bilgisi BCH'si, Reed-Solomon sendromları, veri kodsözcükleri, metin).

// Hata düzeltme düzeyi M: [blok1 sayısı, blok1 veri, blok2 sayısı, blok2 veri, blok başına EC].
const _blocks = <List<int>>[
  [1, 16, 0, 0, 10],
  [1, 28, 0, 0, 16],
  [1, 44, 0, 0, 26],
  [2, 32, 0, 0, 18],
  [2, 43, 0, 0, 24],
  [4, 27, 0, 0, 16],
  [4, 31, 0, 0, 18],
  [2, 38, 2, 39, 22],
  [3, 36, 2, 37, 22],
  [4, 43, 1, 44, 26],
];
const _align = <List<int>>[
  [],
  [6, 18],
  [6, 22],
  [6, 26],
  [6, 30],
  [6, 34],
  [6, 22, 38],
  [6, 24, 42],
  [6, 26, 46],
  [6, 28, 50],
];

int _version(QrCode q) => (q.size - 17) ~/ 4;

bool _isFunction(int x, int y, int size) {
  if (x <= 8 && y <= 8) return true;
  if (x >= size - 8 && y <= 8) return true;
  if (x <= 8 && y >= size - 8) return true;
  if (x == 6 || y == 6) return true;
  final v = (size - 17) ~/ 4;
  final ap = _align[v - 1];
  for (var i = 0; i < ap.length; i++) {
    for (var j = 0; j < ap.length; j++) {
      final corner = (i == 0 && j == 0) || (i == 0 && j == ap.length - 1) || (i == ap.length - 1 && j == 0);
      if (corner) continue;
      if ((x - ap[i]).abs() <= 2 && (y - ap[j]).abs() <= 2) return true;
    }
  }
  if (v >= 7) {
    if (x >= size - 11 && x <= size - 9 && y < 6) return true;
    if (y >= size - 11 && y <= size - 9 && x < 6) return true;
  }
  return false;
}

int _gfExp(int i) {
  var x = 1;
  for (var k = 0; k < i % 255; k++) {
    x <<= 1;
    if (x & 0x100 != 0) x ^= 0x11D;
  }
  return x;
}

int _gfMul(int a, int b) {
  var r = 0;
  while (b > 0) {
    if (b & 1 != 0) r ^= a;
    a <<= 1;
    if (a & 0x100 != 0) a ^= 0x11D;
    b >>= 1;
  }
  return r;
}

/// Kodsözcük polinomunu (en yüksek derece önde) α^0..α^(ec-1) noktalarında değerlendirir.
bool _syndromesZero(List<int> codewords, int ec) {
  for (var i = 0; i < ec; i++) {
    final a = _gfExp(i);
    var acc = 0;
    for (final c in codewords) {
      acc = _gfMul(acc, a) ^ c;
    }
    if (acc != 0) return false;
  }
  return true;
}

int _bch15(int data5) {
  var rem = data5;
  for (var i = 0; i < 10; i++) {
    rem = (rem << 1) ^ ((rem >> 9) * 0x537);
  }
  return ((data5 << 10) | rem) ^ 0x5412;
}

({int bits1, int bits2}) _formatBits(QrCode q) {
  final s = q.size;
  int b(int x, int y) => q.isDark(x, y) ? 1 : 0;
  // Sol-üst kopya (şartname sırası: bit 0 en düşük anlamlı).
  var f1 = 0;
  for (var i = 0; i <= 5; i++) {
    f1 |= b(8, i) << i;
  }
  f1 |= b(8, 7) << 6;
  f1 |= b(8, 8) << 7;
  f1 |= b(7, 8) << 8;
  for (var i = 9; i < 15; i++) {
    f1 |= b(14 - i, 8) << i;
  }
  var f2 = 0;
  for (var i = 0; i < 8; i++) {
    f2 |= b(s - 1 - i, 8) << i;
  }
  for (var i = 8; i < 15; i++) {
    f2 |= b(8, s - 15 + i) << i;
  }
  return (bits1: f1, bits2: f2);
}

bool _maskAt(int mask, int x, int y) => switch (mask) {
      0 => (x + y) % 2 == 0,
      1 => y % 2 == 0,
      2 => x % 3 == 0,
      3 => (x + y) % 3 == 0,
      4 => (x ~/ 3 + y ~/ 2) % 2 == 0,
      5 => (x * y) % 2 + (x * y) % 3 == 0,
      6 => ((x * y) % 2 + (x * y) % 3) % 2 == 0,
      _ => ((x + y) % 2 + (x * y) % 3) % 2 == 0,
    };

/// Matrisi çözüp metni döndürür; herhangi bir şartname ihlalinde `fail` eder.
String _decode(QrCode q) {
  final s = q.size;
  final v = _version(q);
  final f = _formatBits(q);
  expect(f.bits1, f.bits2, reason: 'iki biçim bilgisi kopyası aynı olmalı');
  // Geçerli bir BCH kodsözcüğü mü ve EC düzeyi M (00) mu.
  final data5 = (f.bits1 ^ 0x5412) >> 10;
  expect(_bch15(data5), f.bits1, reason: 'biçim bilgisi BCH geçerli');
  expect(data5 >> 3, 0, reason: 'EC düzeyi M');
  final mask = data5 & 7;

  // Zigzag veri okuma.
  final bits = <int>[];
  for (var right = s - 1; right >= 1; right -= 2) {
    if (right == 6) right = 5;
    final upward = ((right + 1) & 2) == 0;
    for (var vert = 0; vert < s; vert++) {
      for (var j = 0; j < 2; j++) {
        final x = right - j;
        final y = upward ? s - 1 - vert : vert;
        if (_isFunction(x, y, s)) continue;
        bits.add((q.isDark(x, y) != _maskAt(mask, x, y)) ? 1 : 0);
      }
    }
  }
  final b = _blocks[v - 1];
  final total = b[0] * (b[1] + b[4]) + b[2] * (b[3] + b[4]);
  final bytes = <int>[
    for (var i = 0; i < total; i++)
      [for (var k = 0; k < 8; k++) bits[i * 8 + k]].fold<int>(0, (a, e) => (a << 1) | e),
  ];

  // Deinterleave.
  final nBlocks = b[0] + b[2];
  final dataLens = [for (var i = 0; i < nBlocks; i++) i < b[0] ? b[1] : b[3]];
  final blocks = List.generate(nBlocks, (_) => <int>[]);
  var pos = 0;
  final maxData = dataLens.reduce((a, c) => a > c ? a : c);
  for (var i = 0; i < maxData; i++) {
    for (var k = 0; k < nBlocks; k++) {
      if (i < dataLens[k]) blocks[k].add(bytes[pos++]);
    }
  }
  final ecs = List.generate(nBlocks, (_) => <int>[]);
  for (var i = 0; i < b[4]; i++) {
    for (var k = 0; k < nBlocks; k++) {
      ecs[k].add(bytes[pos++]);
    }
  }
  final stream = <int>[];
  for (var k = 0; k < nBlocks; k++) {
    expect(_syndromesZero([...blocks[k], ...ecs[k]], b[4]), isTrue, reason: 'blok $k Reed-Solomon sendromu sıfır');
    stream.addAll(blocks[k]);
  }

  // Bayt kipi: 0100 + sayaç + veri.
  var bp = 0;
  int take(int n) {
    var r = 0;
    for (var i = 0; i < n; i++) {
      final byte = stream[bp >> 3];
      r = (r << 1) | ((byte >> (7 - (bp & 7))) & 1);
      bp++;
    }
    return r;
  }

  expect(take(4), 4, reason: 'bayt kipi göstergesi');
  final len = take(v >= 10 ? 16 : 8);
  final out = [for (var i = 0; i < len; i++) take(8)];
  return utf8.decode(out);
}

void _expectFinder(QrCode q, int cx, int cy) {
  for (var dy = -3; dy <= 3; dy++) {
    for (var dx = -3; dx <= 3; dx++) {
      final d = dx.abs() > dy.abs() ? dx.abs() : dy.abs();
      final dark = d != 2;
      expect(q.isDark(cx + dx, cy + dy), dark, reason: 'bulucu ($cx,$cy) ofset ($dx,$dy)');
    }
  }
  // Ayırıcı halka açık renk (matris sınırları içinde).
  for (var dy = -4; dy <= 4; dy++) {
    for (var dx = -4; dx <= 4; dx++) {
      final d = dx.abs() > dy.abs() ? dx.abs() : dy.abs();
      if (d != 4) continue;
      final x = cx + dx, y = cy + dy;
      if (x < 0 || y < 0 || x >= q.size || y >= q.size) continue;
      expect(q.isDark(x, y), isFalse, reason: 'ayırıcı ($x,$y)');
    }
  }
}

void main() {
  group('QrCode boyut ve sürüm', () {
    final cases = <int, int>{
      // bayt sayısı -> beklenen sürüm (EC düzeyi M kapasiteleri: 14, 26, 42, 62, 84, 106, 122, 152, 180, 213)
      1: 1,
      14: 1,
      15: 2,
      26: 2,
      27: 3,
      42: 3,
      43: 4,
      62: 4,
      63: 5,
      84: 5,
      85: 6,
      106: 6,
      107: 7,
      122: 7,
      123: 8,
      152: 8,
      153: 9,
      180: 9,
      181: 10,
      213: 10,
    };
    cases.forEach((bytes, version) {
      test('$bytes bayt -> sürüm $version', () {
        final q = QrCode.tryEncode('a' * bytes);
        expect(q, isNotNull);
        expect(_version(q!), version);
        expect(q.size, version * 4 + 17);
      });
    });

    test('214 bayt sığmaz -> null', () {
      expect(QrCode.tryEncode('a' * 214), isNull);
    });

    test('UTF-8 çok baytlı karakterler bayt olarak sayılır', () {
      final q = QrCode.tryEncode('ğ' * 8); // 16 bayt -> sürüm 2
      expect(q, isNotNull);
      expect(_version(q!), 2);
    });

    test('boş metin sürüm 1', () {
      final q = QrCode.tryEncode('');
      expect(q, isNotNull);
      expect(q!.size, 21);
    });
  });

  group('QrCode sabit desenler', () {
    for (final text in ['HELLO', 'bingol-checkin:5.123.abc', 'a' * 100, 'b' * 200]) {
      test('bulucu, zamanlama, karanlık modül: ${text.length} karakter', () {
        final q = QrCode.tryEncode(text)!;
        final s = q.size;
        _expectFinder(q, 3, 3);
        _expectFinder(q, s - 4, 3);
        _expectFinder(q, 3, s - 4);
        for (var i = 8; i < s - 8; i++) {
          expect(q.isDark(i, 6), i.isEven, reason: 'yatay zamanlama $i');
          expect(q.isDark(6, i), i.isEven, reason: 'dikey zamanlama $i');
        }
        expect(q.isDark(8, s - 8), isTrue, reason: 'karanlık modül');
        final v = _version(q);
        final ap = _align[v - 1];
        for (var i = 0; i < ap.length; i++) {
          for (var j = 0; j < ap.length; j++) {
            final corner = (i == 0 && j == 0) || (i == 0 && j == ap.length - 1) || (i == ap.length - 1 && j == 0);
            if (corner) continue;
            for (var dy = -2; dy <= 2; dy++) {
              for (var dx = -2; dx <= 2; dx++) {
                final d = dx.abs() > dy.abs() ? dx.abs() : dy.abs();
                expect(q.isDark(ap[i] + dx, ap[j] + dy), d != 1, reason: 'hizalama ${ap[i]},${ap[j]}');
              }
            }
          }
        }
      });
    }
  });

  group('QrCode çözülebilirlik (bağımsız çözücü)', () {
    final samples = <String>[
      'HELLO',
      'bingol-checkin:5.123.abc',
      'https://www.bingol.edu.tr/yoklama?kod=ABC-123',
      'Türkçe: ğüşiöçĞÜŞİÖÇ',
      'x' * 14,
      'y' * 15,
      'z' * 42,
      'w' * 43,
      'v' * 84, // çok bloklu
      'u' * 122, // sürüm 7: sürüm bilgisi alanı
      'ö' * 76, // 152 bayt, sürüm 8
      'q' * 213, // sürüm 10, 16 bit sayaç
    ];
    for (final t in samples) {
      test('çözüm eşleşir: ${t.length} karakter', () {
        final q = QrCode.tryEncode(t)!;
        expect(_decode(q), t);
      });
    }

    test('sürüm 7+ sürüm bilgisi alanı geçerli BCH', () {
      final q = QrCode.tryEncode('u' * 122)!;
      expect(_version(q), 7);
      final s = q.size;
      var bits = 0;
      for (var i = 0; i < 18; i++) {
        final a = s - 11 + i % 3, b = i ~/ 3;
        final dark = q.isDark(a, b);
        expect(q.isDark(b, a), dark, reason: 'iki kopya aynı');
        if (dark) bits |= 1 << i;
      }
      expect(bits >> 12, 7);
      var rem = 7;
      for (var i = 0; i < 12; i++) {
        rem = (rem << 1) ^ ((rem >> 11) * 0x1F25);
      }
      expect(bits & 0xFFF, rem);
    });

    test('aynı metin her seferinde aynı matrisi üretir', () {
      final a = QrCode.tryEncode('bingol-checkin:5.123.abc')!;
      final b = QrCode.tryEncode('bingol-checkin:5.123.abc')!;
      expect(a.size, b.size);
      for (var y = 0; y < a.size; y++) {
        for (var x = 0; x < a.size; x++) {
          expect(a.isDark(x, y), b.isDark(x, y));
        }
      }
    });
  });

  group('QrView', () {
    testWidgets('çizer ve fallback yalnız sığmazsa görünür', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Column(children: [
          const QrView(data: 'bingol-checkin:5.123.abc', size: 180, fallback: Text('YEDEK')),
          QrView(data: 'a' * 300, size: 180, fallback: const Text('YEDEK')),
        ]),
      ));
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('YEDEK'), findsOneWidget); // yalnız ikincisi
      expect(tester.takeException(), isNull);
    });

    testWidgets('320 dp genişlikte çökmeden çizilir; veri değişince yeniden üretir', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Widget host(String d) => MaterialApp(home: Scaffold(body: Center(child: QrView(data: d))));
      await tester.pumpWidget(host('A'));
      await tester.pumpWidget(host('B' * 100));
      expect(tester.takeException(), isNull);
    });
  });
}

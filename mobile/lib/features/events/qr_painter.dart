import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/theme.dart';

/// Saf Dart QR üretici: bayt kipi, hata düzeltme düzeyi M, sürüm 1-10 (en çok 213 bayt).
/// Yoklama kodları kısa olduğu için yeterlidir; sığmazsa [QrCode.tryEncode] null döner.
class QrCode {
  QrCode._(this.size, this._m);

  final int size;
  final List<List<bool>> _m;

  bool isDark(int x, int y) => _m[y][x];

  // Sürüm başına (veri kodsözcüğü blokları): [kısa blok sayısı, kısa blok veri, uzun blok sayısı, uzun blok veri], EC/blok.
  static const _blocks = <List<int>>[
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
  static const _align = <List<int>>[
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

  static QrCode? tryEncode(String text) {
    final data = utf8.encode(text);
    for (var v = 1; v <= 10; v++) {
      final b = _blocks[v - 1];
      final dataCw = b[0] * b[1] + b[2] * b[3];
      final countBits = v >= 10 ? 16 : 8;
      if (4 + countBits + data.length * 8 > dataCw * 8) continue;
      return _build(v, _codewords(v, data, dataCw, countBits));
    }
    return null;
  }

  static List<int> _codewords(int v, List<int> data, int dataCw, int countBits) {
    final bits = <int>[];
    void put(int val, int len) {
      for (var i = len - 1; i >= 0; i--) {
        bits.add((val >> i) & 1);
      }
    }

    put(4, 4);
    put(data.length, countBits);
    for (final d in data) {
      put(d, 8);
    }
    final cap = dataCw * 8;
    for (var i = 0; i < 4 && bits.length < cap; i++) {
      bits.add(0);
    }
    while (bits.length % 8 != 0) {
      bits.add(0);
    }
    final bytes = <int>[];
    for (var i = 0; i < bits.length; i += 8) {
      var x = 0;
      for (var j = 0; j < 8; j++) {
        x = (x << 1) | bits[i + j];
      }
      bytes.add(x);
    }
    for (var pad = 0xEC; bytes.length < dataCw; pad ^= 0xEC ^ 0x11) {
      bytes.add(pad);
    }

    // Bloklara böl, her bloğa Reed-Solomon ekle, araya serpiştir.
    final b = _blocks[v - 1];
    final ecLen = b[4];
    final gen = _generator(ecLen);
    final dataBlocks = <List<int>>[];
    var pos = 0;
    for (var i = 0; i < b[0] + b[2]; i++) {
      final len = i < b[0] ? b[1] : b[3];
      dataBlocks.add(bytes.sublist(pos, pos + len));
      pos += len;
    }
    final ecBlocks = [for (final d in dataBlocks) _remainder(d, gen)];
    final out = <int>[];
    final maxLen = dataBlocks.last.length;
    for (var i = 0; i < maxLen; i++) {
      for (final d in dataBlocks) {
        if (i < d.length) out.add(d[i]);
      }
    }
    for (var i = 0; i < ecLen; i++) {
      for (final e in ecBlocks) {
        out.add(e[i]);
      }
    }
    return out;
  }

  // GF(256), polinom 0x11D.
  static final List<int> _exp = _expTable();
  static final List<int> _log = _logTable();

  static List<int> _expTable() {
    final t = List<int>.filled(512, 0);
    var x = 1;
    for (var i = 0; i < 255; i++) {
      t[i] = x;
      x <<= 1;
      if (x & 0x100 != 0) x ^= 0x11D;
    }
    for (var i = 255; i < 512; i++) {
      t[i] = t[i - 255];
    }
    return t;
  }

  static List<int> _logTable() {
    final t = List<int>.filled(256, 0);
    for (var i = 0; i < 255; i++) {
      t[_exp[i]] = i;
    }
    return t;
  }

  static int _mul(int a, int b) => (a == 0 || b == 0) ? 0 : _exp[_log[a] + _log[b]];

  static List<int> _generator(int degree) {
    var g = <int>[1];
    for (var i = 0; i < degree; i++) {
      final next = List<int>.filled(g.length + 1, 0);
      for (var j = 0; j < g.length; j++) {
        next[j] ^= g[j];
        next[j + 1] ^= _mul(g[j], _exp[i]);
      }
      g = next;
    }
    return g; // baştaki katsayı 1, en yüksek dereceden
  }

  static List<int> _remainder(List<int> data, List<int> gen) {
    final ecLen = gen.length - 1;
    final rem = List<int>.filled(ecLen, 0);
    for (final d in data) {
      final factor = d ^ rem[0];
      for (var i = 0; i < ecLen - 1; i++) {
        rem[i] = rem[i + 1];
      }
      rem[ecLen - 1] = 0;
      for (var i = 0; i < ecLen; i++) {
        rem[i] ^= _mul(gen[i + 1], factor);
      }
    }
    return rem;
  }

  static QrCode _build(int v, List<int> codewords) {
    final size = v * 4 + 17;
    final m = List.generate(size, (_) => List<bool>.filled(size, false));
    final fn = List.generate(size, (_) => List<bool>.filled(size, false));

    void set(int x, int y, bool dark) {
      m[y][x] = dark;
      fn[y][x] = true;
    }

    for (var i = 0; i < size; i++) {
      set(6, i, i % 2 == 0);
      set(i, 6, i % 2 == 0);
    }
    void finder(int cx, int cy) {
      for (var dy = -4; dy <= 4; dy++) {
        for (var dx = -4; dx <= 4; dx++) {
          final d = dx.abs() > dy.abs() ? dx.abs() : dy.abs();
          final x = cx + dx, y = cy + dy;
          if (x >= 0 && x < size && y >= 0 && y < size) set(x, y, d != 2 && d != 4);
        }
      }
    }

    finder(3, 3);
    finder(size - 4, 3);
    finder(3, size - 4);
    final ap = _align[v - 1];
    for (var i = 0; i < ap.length; i++) {
      for (var j = 0; j < ap.length; j++) {
        final corner = (i == 0 && j == 0) || (i == 0 && j == ap.length - 1) || (i == ap.length - 1 && j == 0);
        if (corner) continue;
        for (var dy = -2; dy <= 2; dy++) {
          for (var dx = -2; dx <= 2; dx++) {
            final d = dx.abs() > dy.abs() ? dx.abs() : dy.abs();
            set(ap[i] + dx, ap[j] + dy, d != 1);
          }
        }
      }
    }

    void format(int mask) {
      final data = mask; // M düzeyi göstergesi 00
      var rem = data;
      for (var i = 0; i < 10; i++) {
        rem = (rem << 1) ^ ((rem >> 9) * 0x537);
      }
      final bits = ((data << 10) | rem) ^ 0x5412;
      bool bit(int i) => (bits >> i) & 1 != 0;
      for (var i = 0; i <= 5; i++) {
        set(8, i, bit(i));
      }
      set(8, 7, bit(6));
      set(8, 8, bit(7));
      set(7, 8, bit(8));
      for (var i = 9; i < 15; i++) {
        set(14 - i, 8, bit(i));
      }
      for (var i = 0; i < 8; i++) {
        set(size - 1 - i, 8, bit(i));
      }
      for (var i = 8; i < 15; i++) {
        set(8, size - 15 + i, bit(i));
      }
      set(8, size - 8, true);
    }

    format(0); // alanı işlevsel olarak ayır
    if (v >= 7) {
      var rem = v;
      for (var i = 0; i < 12; i++) {
        rem = (rem << 1) ^ ((rem >> 11) * 0x1F25);
      }
      final bits = (v << 12) | rem;
      for (var i = 0; i < 18; i++) {
        final bit = (bits >> i) & 1 != 0;
        final a = size - 11 + i % 3, b = i ~/ 3;
        set(a, b, bit);
        set(b, a, bit);
      }
    }

    // Veri yerleşimi (zigzag).
    var idx = 0;
    for (var right = size - 1; right >= 1; right -= 2) {
      if (right == 6) right = 5;
      for (var vert = 0; vert < size; vert++) {
        for (var j = 0; j < 2; j++) {
          final x = right - j;
          final upward = ((right + 1) & 2) == 0;
          final y = upward ? size - 1 - vert : vert;
          if (!fn[y][x] && idx < codewords.length * 8) {
            m[y][x] = (codewords[idx >> 3] >> (7 - (idx & 7))) & 1 != 0;
            idx++;
          }
        }
      }
    }

    bool maskAt(int mask, int x, int y) {
      switch (mask) {
        case 0:
          return (x + y) % 2 == 0;
        case 1:
          return y % 2 == 0;
        case 2:
          return x % 3 == 0;
        case 3:
          return (x + y) % 3 == 0;
        case 4:
          return (x ~/ 3 + y ~/ 2) % 2 == 0;
        case 5:
          return x * y % 2 + x * y % 3 == 0;
        case 6:
          return (x * y % 2 + x * y % 3) % 2 == 0;
        default:
          return ((x + y) % 2 + x * y % 3) % 2 == 0;
      }
    }

    void applyMask(int mask) {
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          if (!fn[y][x] && maskAt(mask, x, y)) m[y][x] = !m[y][x];
        }
      }
    }

    var best = 0;
    var bestScore = 1 << 30;
    for (var mask = 0; mask < 8; mask++) {
      applyMask(mask);
      format(mask);
      final s = _penalty(m, size);
      if (s < bestScore) {
        bestScore = s;
        best = mask;
      }
      applyMask(mask); // geri al
    }
    applyMask(best);
    format(best);
    return QrCode._(size, m);
  }

  static int _penalty(List<List<bool>> m, int size) {
    var score = 0;
    // Kural 1 ve 3: satır/sütun taramaları.
    const pat = [true, false, true, true, true, false, true, false, false, false, false];
    for (final horizontal in [true, false]) {
      for (var a = 0; a < size; a++) {
        final line = [for (var b = 0; b < size; b++) horizontal ? m[a][b] : m[b][a]];
        var run = 1;
        for (var i = 1; i <= size; i++) {
          if (i < size && line[i] == line[i - 1]) {
            run++;
          } else {
            if (run >= 5) score += 3 + (run - 5);
            run = 1;
          }
        }
        for (var i = 0; i + 11 <= size; i++) {
          var f = true, r = true;
          for (var k = 0; k < 11; k++) {
            if (line[i + k] != pat[k]) f = false;
            if (line[i + k] != pat[10 - k]) r = false;
          }
          if (f) score += 40;
          if (r) score += 40;
        }
      }
    }
    // Kural 2: 2x2 aynı renk blokları.
    var dark = 0;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        if (m[y][x]) dark++;
        if (x + 1 < size && y + 1 < size) {
          final c = m[y][x];
          if (c == m[y][x + 1] && c == m[y + 1][x] && c == m[y + 1][x + 1]) score += 3;
        }
      }
    }
    // Kural 4: koyu oranı.
    final total = size * size;
    final k = ((dark * 20 - total * 10).abs() + total - 1) ~/ total - 1;
    return score + (k < 0 ? 0 : k) * 10;
  }
}

/// QR'ı açık zemin üzerine koyu modüllerle çizer (tarayıcıların beklediği karşıtlık, tema bağımsız).
/// Renkler verilmezse belirteçlerdeki sabit yüksek karşıtlık çifti (`qrInk` siyah / `qrPaper` beyaz) kullanılır.
/// Modüller tek `Path` olarak çizilir (tek çizim çağrısı).
class QrPainter extends CustomPainter {
  QrPainter(this.qr, {Color? ink, Color? paper})
      : ink = ink ?? BuTokens.light.qrInk,
        paper = paper ?? BuTokens.light.qrPaper;

  final QrCode qr;
  final Color ink;
  final Color paper;
  static const _quiet = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final cells = qr.size + _quiet * 2;
    final cell = size.shortestSide / cells;
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    final path = Path();
    for (var y = 0; y < qr.size; y++) {
      for (var x = 0; x < qr.size; x++) {
        if (qr.isDark(x, y)) {
          path.addRect(Rect.fromLTWH((x + _quiet) * cell, (y + _quiet) * cell, cell + .5, cell + .5));
        }
      }
    }
    canvas.drawPath(path, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(QrPainter old) => old.qr != qr || old.ink != ink || old.paper != paper;
}

/// [data] QR olarak çizilir; üretilemezse (çok uzun) [fallback] gösterilir.
/// [radius] köşe yuvarlaklığı (varsayılan 12); renkler isteğe bağlıdır (varsayılan belirteçler).
class QrView extends StatefulWidget {
  const QrView({super.key, required this.data, this.size = 220, this.fallback, this.radius = 12});

  final String data;
  final double size;
  final Widget? fallback;
  final double radius;

  @override
  State<QrView> createState() => _QrViewState();
}

class _QrViewState extends State<QrView> {
  QrCode? _qr;

  @override
  void initState() {
    super.initState();
    _qr = QrCode.tryEncode(widget.data);
  }

  @override
  void didUpdateWidget(QrView old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) _qr = QrCode.tryEncode(widget.data);
  }

  @override
  Widget build(BuildContext context) {
    final qr = _qr;
    if (qr == null) return widget.fallback ?? const SizedBox.shrink();
    final t = Theme.of(context).extension<BuTokens>(); // yoksa varsayılan yüksek karşıtlık
    return Semantics(
      label: context.l10n.eventListQrLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: RepaintBoundary(
          child: CustomPaint(size: Size.square(widget.size), painter: QrPainter(qr, ink: t?.qrInk, paper: t?.qrPaper)),
        ),
      ),
    );
  }
}

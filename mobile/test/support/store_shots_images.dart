import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as im;

/// Mağaza görselleri için SAHTE içerik görselleri (gerçek kişi fotoğrafı yok): kampüs temalı soyut sahneler.
/// `Image.network` istekleri [StoreImageHttpClient] ile bu üretilmiş PNG'lere yönlendirilir; ağ kullanılmaz.

const _w = 600, _h = 750;

im.ColorRgb8 _c(int hex) => im.ColorRgb8((hex >> 16) & 255, (hex >> 8) & 255, hex & 255);

int _lerp(int a, int b, double t) => (a + (b - a) * t).round();

void _grad(im.Image g, int y0, int y1, int c0, int c1) {
  for (var y = y0; y < y1; y++) {
    final t = (y - y0) / (y1 - y0 <= 1 ? 1 : (y1 - y0 - 1));
    final r = _lerp((c0 >> 16) & 255, (c1 >> 16) & 255, t);
    final gg = _lerp((c0 >> 8) & 255, (c1 >> 8) & 255, t);
    final b = _lerp(c0 & 255, c1 & 255, t);
    im.fillRect(g, x1: 0, y1: y, x2: _w, y2: y + 1, color: im.ColorRgb8(r, gg, b));
  }
}

void _rect(im.Image g, int x, int y, int w, int h, int c) =>
    im.fillRect(g, x1: x, y1: y, x2: x + w, y2: y + h, color: _c(c));

void _circle(im.Image g, int x, int y, int r, int c) => im.fillCircle(g, x: x, y: y, radius: r, color: _c(c));

void _tri(im.Image g, int x1, int y1, int x2, int y2, int x3, int y3, int c) =>
    im.fillPolygon(g, vertices: [im.Point(x1, y1), im.Point(x2, y2), im.Point(x3, y3)], color: _c(c));

void _tree(im.Image g, int x, int base, int s, int leaf, int trunk) {
  _rect(g, x - s ~/ 8, base - s ~/ 2, s ~/ 4, s ~/ 2, trunk);
  _circle(g, x, base - s ~/ 2 - s ~/ 3, s ~/ 2, leaf);
  _circle(g, x - s ~/ 3, base - s ~/ 2, s ~/ 3, leaf);
  _circle(g, x + s ~/ 3, base - s ~/ 2, s ~/ 3, leaf);
}

/// Sütunlu klasik bina (genel, logo/arma yok).
void _hall(im.Image g, int x, int y, int w, int h, int wall, int roof, int win) {
  _rect(g, x, y, w, h, wall);
  _tri(g, x - 14, y, x + w + 14, y, x + w ~/ 2, y - h ~/ 3, roof);
  final cols = 6;
  for (var i = 0; i < cols; i++) {
    _rect(g, x + 14 + i * ((w - 40) ~/ (cols - 1)), y + 10, 12, h - 24, 0xFFFFFF);
  }
  for (var i = 0; i < 3; i++) {
    _rect(g, x + w ~/ 2 - 17 + (i - 1) * 36 + 12, y + h - 70, 22, 56, win);
  }
  _rect(g, x - 10, y + h, w + 20, 10, 0xD9D2C6);
  _rect(g, x - 20, y + h + 10, w + 40, 10, 0xCFC7B8);
}

im.Image _scene(int v) {
  final g = im.Image(width: _w, height: _h, numChannels: 3);
  switch (v % 8) {
    case 0: // gün doğumu, klasik bina
      _grad(g, 0, 420, 0x5B6FD8, 0xFFB36B);
      _circle(g, 410, 380, 70, 0xFFE3A3);
      _tri(g, -60, 480, 220, 300, 520, 480, 0x7D5CA8);
      _tri(g, 200, 480, 480, 330, 700, 480, 0x6A4E98);
      _grad(g, 450, _h, 0x3F8A62, 0x1F5A40);
      _hall(g, 150, 390, 300, 190, 0xF4ECE0, 0xB8433A, 0x6C7A9E);
      _tree(g, 70, 640, 110, 0x2D7A4B, 0x4A3322);
      _tree(g, 530, 650, 120, 0x378A57, 0x4A3322);
    case 1: // açık hava, cam bina
      _grad(g, 0, 460, 0x7CC1FF, 0xE3F3FF);
      _circle(g, 110, 130, 40, 0xFFFFFF);
      _circle(g, 150, 140, 46, 0xFFFFFF);
      _circle(g, 450, 90, 36, 0xFFFFFF);
      _circle(g, 490, 100, 44, 0xFFFFFF);
      _grad(g, 460, _h, 0x62B26B, 0x2F7A48);
      _rect(g, 90, 250, 420, 250, 0xD7DEE9);
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 7; c++) {
          _rect(g, 108 + c * 56, 268 + r * 56, 46, 46, (r + c) % 3 == 0 ? 0x9CCBF2 : 0x6FA8DC);
        }
      }
      _rect(g, 250, 440, 100, 60, 0x3E5C80);
      im.fillPolygon(g,
          vertices: [im.Point(250, 750), im.Point(350, 750), im.Point(330, 500), im.Point(270, 500)], color: _c(0xE8DFCB));
      _tree(g, 60, 560, 120, 0x2F8F54, 0x4A3322);
      _tree(g, 550, 580, 130, 0x2A7F4A, 0x4A3322);
    case 2: // alacakaranlık, aydınlatma direkleri
      _grad(g, 0, 520, 0x1E2A5A, 0xC2527A);
      _rect(g, 0, 520, _w, 230, 0x1B1F33);
      _rect(g, 100, 300, 400, 230, 0x23283F);
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 7; c++) {
          _rect(g, 128 + c * 52, 322 + r * 52, 30, 34, (r * 3 + c) % 4 == 0 ? 0x4A5170 : 0xFFD479);
        }
      }
      for (final x in [60, 300, 540]) {
        _rect(g, x - 3, 430, 6, 230, 0x0E111F);
        _circle(g, x, 424, 34, 0xFFE6A8);
        _circle(g, x, 424, 16, 0xFFF6DB);
      }
      _tri(g, 0, 750, 0, 600, 200, 750, 0x14172A);
    case 3: // kütüphane
      _grad(g, 0, _h, 0xE8D8BE, 0xC9AC83);
      for (var s = 0; s < 3; s++) {
        final y = 70 + s * 190;
        _rect(g, 40, y, 520, 12, 0x6B4423);
        var x = 52;
        var i = 0;
        const cols = [0xB8433A, 0x2F4FA8, 0x1F7A4A, 0xD9A441, 0x6A4E98, 0x2A8C9E, 0xC96B3C];
        while (x < 540) {
          final bw = 18 + (i * 7) % 14;
          final bh = 90 + (i * 13) % 60;
          _rect(g, x, y - bh, bw, bh, cols[(i + s) % cols.length]);
          x += bw + 3;
          i++;
        }
        _rect(g, 40, y + 12, 520, 100, 0x8A5A32);
      }
      _circle(g, 300, 690, 36, 0xFFE9A8);
    case 4: // yemek tepsisi
      _grad(g, 0, _h, 0x9C6B3C, 0x7C522B);
      _rect(g, 60, 110, 480, 530, 0xD7D9DE);
      _circle(g, 190, 260, 105, 0xFFFFFF);
      _circle(g, 190, 260, 78, 0xE9A23B);
      _circle(g, 190, 260, 40, 0xC8472B);
      _circle(g, 410, 230, 85, 0xFFFFFF);
      _circle(g, 410, 230, 60, 0xF4EDD8);
      _circle(g, 390, 220, 14, 0x2F8F54);
      _circle(g, 430, 245, 14, 0xB8433A);
      _circle(g, 300, 490, 105, 0xFFFFFF);
      _circle(g, 300, 490, 78, 0x8DBF5A);
      _circle(g, 290, 480, 20, 0xE7D27A);
      _rect(g, 80, 600, 160, 20, 0xA9ADB5);
    case 5: // halı saha
      _grad(g, 0, 160, 0x8CC8FF, 0xDFF1FF);
      _grad(g, 160, _h, 0x3F9A58, 0x2B7A42);
      for (var i = 0; i < 8; i++) {
        if (i.isEven) _rect(g, 0, 160 + i * 74, _w, 74, 0x358B4D);
      }
      _rect(g, 40, 200, 520, 6, 0xFFFFFF);
      _rect(g, 40, 200, 6, 500, 0xFFFFFF);
      _rect(g, 554, 200, 6, 500, 0xFFFFFF);
      _rect(g, 40, 694, 520, 6, 0xFFFFFF);
      _rect(g, 40, 446, 520, 6, 0xFFFFFF);
      _circle(g, 300, 449, 70, 0xFFFFFF);
      _circle(g, 300, 449, 64, 0x358B4D);
      _circle(g, 300, 449, 10, 0xFFFFFF);
      _rect(g, 230, 150, 140, 60, 0xF0F0F0);
      _rect(g, 238, 158, 124, 52, 0x4C6B52);
      _circle(g, 400, 560, 22, 0xFFFFFF);
      _circle(g, 400, 560, 8, 0x222222);
    case 6: // satranç
      _grad(g, 0, _h, 0x3A3F55, 0x20233A);
      const s = 62;
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          _rect(g, 52 + c * s, 150 + r * s, s, s, (r + c).isEven ? 0xF0D9B5 : 0xB58863);
        }
      }
      for (final p in [
        [1, 2, 0xFFFFFF],
        [3, 3, 0xFFFFFF],
        [5, 4, 0xFFFFFF],
        [2, 5, 0x1A1A1A],
        [4, 1, 0x1A1A1A],
        [6, 6, 0x1A1A1A],
        [0, 4, 0xFFFFFF],
        [7, 3, 0x1A1A1A]
      ]) {
        final cx = 52 + p[0] * s + s ~/ 2, cy = 150 + p[1] * s + s ~/ 2;
        _circle(g, cx, cy + 10, 20, p[2]);
        _circle(g, cx, cy - 12, 12, p[2]);
        _rect(g, cx - 14, cy + 22, 28, 6, p[2]);
      }
      _rect(g, 52, 660, 496, 8, 0xD9A441);
    default: // etkinlik sahnesi
      _grad(g, 0, _h, 0x181B3F, 0x3A1F5C);
      _tri(g, 120, 0, 40, 520, 260, 520, 0x2E3470);
      _tri(g, 300, 0, 230, 520, 400, 520, 0x3B3E86);
      _tri(g, 480, 0, 380, 520, 570, 520, 0x2E3470);
      _rect(g, 0, 520, _w, 40, 0x6B4423);
      _rect(g, 0, 560, _w, 190, 0x1B1230);
      for (var i = 0; i < 26; i++) {
        _circle(g, 20 + (i * 53) % 560, 60 + (i * 97) % 400, 4 + i % 4,
            [0xFFD479, 0xFF6A5F, 0x6FC7FF, 0xB48CFF][i % 4]);
      }
      _rect(g, 200, 440, 200, 80, 0xC62A20);
  }
  return g;
}

final Map<int, Uint8List> _cache = {};

Uint8List storeImageBytes(int variant) =>
    _cache[variant % 8] ??= Uint8List.fromList(im.encodePng(_scene(variant), level: 1));

/// URL'den sahne seçer: yoldaki son sayı % 8 (yoksa sabit 0). `thumb=true` aynı sahneyi döner.
int storeVariantFor(Uri uri) {
  final m = RegExp(r'(\d+)(?!.*\d)').firstMatch(uri.path);
  final n = m == null ? 0 : int.parse(m.group(1)!);
  return n % 8;
}

class _FakeHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(this.bytes);
  final Uint8List bytes;

  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(bytes).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this.uri);
  final Uri uri;
  @override
  HttpHeaders get headers => _FakeHeaders();
  @override
  Future<HttpClientResponse> close() async => _FakeResponse(storeImageBytes(storeVariantFor(uri)));
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// `debugNetworkImageHttpClientProvider` için: her adrese üretilmiş sahne PNG'si döner.
class StoreImageHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _FakeRequest(url);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

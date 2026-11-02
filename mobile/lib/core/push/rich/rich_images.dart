import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../../api.dart' show allowInsecureApi, apiOrigin;

/// Zengin bildirim görselleri: avatar (yuvarlak kırp + sayaç/grup rozeti), baş harf yedeği, küçük/geniş görsel.
/// İndirme zaman aşımlı ve boyut sınırlıdır; HER hata sessizce null/yedek döner (bildirim görselsiz de çizilir).
/// Yalnız `image` paketi kullanılır (arka plan isolate'inde UI/`dart:ui` gerekmez).

/// Ağ aşaması bütçesi: FCM arka plan işleyicisinin süresi sınırlıdır.
const Duration kImageFetchTimeout = Duration(seconds: 4);

/// İndirilebilecek en büyük görsel (bayt).
const int kImageMaxBytes = 3 * 1024 * 1024;

/// Avatar kenarı (px). Android büyük simge ~64-128 dp; 128 px keskin ve hafiftir.
const int kAvatarSize = 128;

/// Görsel adresine güvenilir mi: `https` + API ile AYNI alan adı/kapı (yerel/elden test derlemesinde http de).
/// Başka alan adı, kullanıcı bilgisi içeren adres, `data:`/`file:` reddedilir (SSRF/izleme piksel koruması).
bool isTrustedMediaUrl(String? raw, {String? origin, bool? allowInsecure}) {
  if (raw == null || raw.isEmpty) return false;
  final u = Uri.tryParse(raw);
  final o = Uri.tryParse(origin ?? apiOrigin);
  if (u == null || o == null || !u.hasAuthority || u.host.isEmpty || o.host.isEmpty) return false;
  if (u.userInfo.isNotEmpty) return false;
  final insecureOk = (allowInsecure ?? allowInsecureApi) && o.scheme == 'http';
  if (u.scheme != 'https' && !(insecureOk && u.scheme == 'http')) return false;
  if (u.host.toLowerCase() != o.host.toLowerCase()) return false;
  return true;
}

/// Ad -> en çok iki baş harf (BÜYÜK). Boş ad '?' verir.
String initialsOf(String? name) {
  final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  String first(String s) => String.fromCharCodes(s.runes.take(1)).toUpperCase();
  final a = first(parts.first);
  final b = parts.length > 1 ? first(parts.last) : '';
  return '$a$b';
}

/// Bitmap yazı tipinde (yalnız ASCII) çizilebilsin diye Türkçe harfleri sadeleştirir; ASCII dışı kalan karakter atılır.
String foldAscii(String s) {
  const map = {
    'Ç': 'C', 'Ğ': 'G', 'İ': 'I', 'I': 'I', 'Ö': 'O', 'Ş': 'S', 'Ü': 'U', //
    'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u',
  };
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    final m = map[ch] ?? ch;
    if (m.runes.every((c) => c >= 0x20 && c < 0x7f)) b.write(m);
  }
  return b.toString();
}

/// Ada göre kararlı zemin rengi (kişi her yerde aynı rengi alır).
img.ColorRgb8 _colorFor(String name) {
  const palette = [
    [0xC6, 0x28, 0x28],
    [0x3A, 0x47, 0xB5],
    [0x1D, 0x7A, 0x47],
    [0xA8, 0x62, 0x0A],
    [0x6A, 0x3D, 0x9A],
    [0x00, 0x7C, 0x91],
    [0x8D, 0x3B, 0x72],
  ];
  var h = 0;
  for (final r in name.runes) {
    h = (h * 31 + r) & 0x7fffffff;
  }
  final c = palette[h % palette.length];
  return img.ColorRgb8(c[0], c[1], c[2]);
}

/// Yuvarlak kırpılmış PNG. Çözülemeyen/bozuk bayt için null.
Uint8List? circleAvatar(Uint8List src, {int size = kAvatarSize}) {
  try {
    final decoded = img.decodeImage(src);
    if (decoded == null || decoded.width < 2 || decoded.height < 2) return null;
    // Alfa kanalı şart: JPEG kaynak 3 kanallıdır, daire dışı şeffaf kalmaz.
    final sq = img.copyResizeCropSquare(decoded, size: size, interpolation: img.Interpolation.average).convert(numChannels: 4);
    final circ = img.copyCropCircle(sq);
    return Uint8List.fromList(img.encodePng(circ));
  } catch (_) {
    return null;
  }
}

/// Baş harf avatarı (yuvarlak, renkli zemin). Çizilebilir harf yoksa (örn. Arapça ad) sade kişi silueti.
Uint8List initialsAvatar(String? name, {int size = kAvatarSize}) {
  final base = (name ?? '').trim();
  final color = _colorFor(base.isEmpty ? '?' : base);
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  img.fillCircle(canvas, x: size ~/ 2, y: size ~/ 2, radius: size ~/ 2, color: color, antialias: true);
  final letters = foldAscii(initialsOf(base)).replaceAll('?', '');
  final white = img.ColorRgb8(255, 255, 255);
  if (letters.isNotEmpty) {
    final font = img.arial48;
    img.drawString(canvas, letters, font: font, color: white, y: (size * 0.5 - 24).round());
  } else {
    // Kişi silueti: baş + omuz.
    img.fillCircle(canvas, x: size ~/ 2, y: (size * 0.40).round(), radius: (size * 0.16).round(), color: white, antialias: true);
    img.fillCircle(canvas, x: size ~/ 2, y: (size * 0.86).round(), radius: (size * 0.30).round(), color: white, antialias: true);
    // Siluetin daire dışına taşan alt kısmı kırp.
    final cropped = img.copyCropCircle(canvas);
    return Uint8List.fromList(img.encodePng(cropped));
  }
  return Uint8List.fromList(img.encodePng(canvas));
}

/// Avatarın üstüne rozetler: sağ altta grup rozeti (koyu daire + iki kişi), sol üstte sayaç (kırmızı daire + sayı).
Uint8List badgeAvatar(Uint8List avatarPng, {int? count, bool group = false}) {
  if ((count == null || count < 2) && !group) return avatarPng;
  try {
    final base = img.decodePng(avatarPng);
    if (base == null) return avatarPng;
    final w = base.width;
    final canvas = img.Image(width: w, height: w, numChannels: 4);
    img.compositeImage(canvas, base);
    if (group) {
      final r = (w * 0.17).round();
      final cx = w - r - 2, cy = w - r - 2;
      img.fillCircle(canvas, x: cx, y: cy, radius: r + 3, color: img.ColorRgb8(255, 255, 255), antialias: true);
      img.fillCircle(canvas, x: cx, y: cy, radius: r, color: img.ColorRgb8(0x1B, 0x25, 0x40), antialias: true);
      final white = img.ColorRgb8(255, 255, 255);
      img.fillCircle(canvas, x: cx - (r * 0.35).round(), y: cy - (r * 0.25).round(), radius: (r * 0.28).round().clamp(1, 99), color: white, antialias: true);
      img.fillCircle(canvas, x: cx + (r * 0.35).round(), y: cy - (r * 0.25).round(), radius: (r * 0.28).round().clamp(1, 99), color: white, antialias: true);
      img.fillCircle(canvas, x: cx, y: cy + (r * 0.45).round(), radius: (r * 0.40).round().clamp(1, 99), color: white, antialias: true);
    }
    if (count != null && count > 1) {
      final r = (w * 0.19).round();
      final cx = r + 2, cy = r + 2;
      img.fillCircle(canvas, x: cx, y: cy, radius: r + 3, color: img.ColorRgb8(255, 255, 255), antialias: true);
      img.fillCircle(canvas, x: cx, y: cy, radius: r, color: img.ColorRgb8(0xC4, 0x28, 0x1C), antialias: true);
      final text = count > 9 ? '9+' : '$count';
      final font = img.arial24;
      final tw = text.length * 13;
      img.drawString(canvas, text, font: font, x: cx - tw ~/ 2, y: cy - 14, color: img.ColorRgb8(255, 255, 255));
    }
    return Uint8List.fromList(img.encodePng(canvas));
  } catch (_) {
    return avatarPng;
  }
}

/// Sağda küçük kare görsel: kare kırp + yuvarlatılmış köşe (PNG).
Uint8List? roundedThumb(Uint8List src, {int size = 192}) {
  try {
    final decoded = img.decodeImage(src);
    if (decoded == null || decoded.width < 2 || decoded.height < 2) return null;
    final sq = img.copyResizeCropSquare(decoded, size: size, interpolation: img.Interpolation.average).convert(numChannels: 4);
    final radius = size * 0.18;
    for (final p in sq) {
      final x = p.x + 0.5, y = p.y + 0.5;
      final dx = math.max(math.max(radius - x, x - (size - radius)), 0.0);
      final dy = math.max(math.max(radius - y, y - (size - radius)), 0.0);
      if (dx * dx + dy * dy > radius * radius) p.a = 0;
    }
    return Uint8List.fromList(img.encodePng(sq));
  } catch (_) {
    return null;
  }
}

/// Geniş görsel (BigPicture): en çok [maxWidth] px genişlik, JPEG. Çözülemezse null.
Uint8List? widePicture(Uint8List src, {int maxWidth = 1024}) {
  try {
    final decoded = img.decodeImage(src);
    if (decoded == null || decoded.width < 2 || decoded.height < 2) return null;
    final scaled = decoded.width > maxWidth ? img.copyResize(decoded, width: maxWidth, interpolation: img.Interpolation.average) : decoded;
    return Uint8List.fromList(img.encodeJpg(scaled, quality: 85));
  } catch (_) {
    return null;
  }
}

typedef MediaFetcher = Future<Uint8List?> Function(Uri uri);
typedef AuthTokenProvider = Future<String?> Function();

/// Güvenli indirme: 200 + `image/*`, [kImageMaxBytes] sınırı, [kImageFetchTimeout]. `/api/` yolları için (yetkili sohbet
/// görselleri) varsa Bearer eklenir; belirteç yalnız güvenilir alan adına gider ([isTrustedMediaUrl] çağıran tarafta).
Future<Uint8List?> defaultMediaFetch(Uri uri, {AuthTokenProvider? token, http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final req = http.Request('GET', uri)..headers['Accept'] = 'image/*';
    if (uri.path.startsWith('/api/') && token != null) {
      final t = await token();
      if (t != null && t.isNotEmpty) req.headers['Authorization'] = 'Bearer $t';
    }
    final res = await c.send(req).timeout(kImageFetchTimeout);
    if (res.statusCode != 200) return null;
    final type = res.headers['content-type'] ?? '';
    if (type.isNotEmpty && !type.toLowerCase().startsWith('image/')) return null;
    final len = res.contentLength;
    if (len != null && len > kImageMaxBytes) return null;
    final bytes = <int>[];
    await for (final chunk in res.stream.timeout(kImageFetchTimeout)) {
      bytes.addAll(chunk);
      if (bytes.length > kImageMaxBytes) return null;
    }
    return Uint8List.fromList(bytes);
  } catch (_) {
    return null;
  } finally {
    if (client == null) c.close();
  }
}

/// Önbellekli görsel üretici: bellek (son 30) + disk (kararlı SHA-1 adı, en çok 80 dosya).
class RichImages {
  RichImages({MediaFetcher? fetch, this.cacheDir, String? origin, bool? allowInsecure})
      : _fetch = fetch ?? ((u) => defaultMediaFetch(u)),
        _origin = origin,
        _allowInsecure = allowInsecure;

  final MediaFetcher _fetch;
  final Directory? cacheDir;
  final String? _origin;
  final bool? _allowInsecure;
  final _mem = <String, Uint8List>{};

  static const int _maxFiles = 80;

  /// Gönderen avatarı: indir -> yuvarlak -> (sayaç/grup rozeti). Başarısızlıkta baş harf avatarı. Asla null/atma yok.
  Future<Uint8List> avatar(String? url, String? name, {int? count, bool group = false}) async {
    Uint8List? circle;
    if (isTrustedMediaUrl(url, origin: _origin, allowInsecure: _allowInsecure)) {
      circle = await _cached('av128', url!, (bytes) => circleAvatar(bytes));
    }
    circle ??= initialsAvatar(name);
    return badgeAvatar(circle, count: count, group: group);
  }

  /// Sağda küçük görsel ([thumb]) ya da geniş görsel; olmazsa null.
  Future<Uint8List?> picture(String? url, {required bool wide}) async {
    if (!isTrustedMediaUrl(url, origin: _origin, allowInsecure: _allowInsecure)) return null;
    return _cached(wide ? 'wide' : 'thumb', url!, (bytes) => wide ? widePicture(bytes) : roundedThumb(bytes));
  }

  Future<Uint8List?> _cached(String kind, String url, Uint8List? Function(Uint8List) process) async {
    final key = '$kind|$url';
    final hit = _mem[key];
    if (hit != null) {
      _mem..remove(key)..[key] = hit; // LRU: en yeni sona
      return hit;
    }
    final file = _fileFor(key);
    try {
      if (file != null && await file.exists()) {
        final b = await file.readAsBytes();
        if (b.isNotEmpty) return _remember(key, b);
      }
    } catch (_) {}
    Uint8List? raw;
    try {
      raw = await _fetch(Uri.parse(url));
    } catch (_) {
      raw = null;
    }
    if (raw == null || raw.isEmpty) return null;
    final out = process(raw);
    if (out == null) return null;
    _remember(key, out);
    if (file != null) unawaited(_write(file, out));
    return out;
  }

  Uint8List _remember(String key, Uint8List b) {
    _mem[key] = b;
    while (_mem.length > 30) {
      _mem.remove(_mem.keys.first);
    }
    return b;
  }

  File? _fileFor(String key) {
    final d = cacheDir;
    if (d == null) return null;
    final name = sha1.convert(utf8.encode(key)).toString();
    return File('${d.path}${Platform.pathSeparator}$name.bin');
  }

  Future<void> _write(File f, Uint8List b) async {
    try {
      await f.parent.create(recursive: true);
      await f.writeAsBytes(b, flush: true);
      final all = f.parent.listSync().whereType<File>().toList();
      if (all.length > _maxFiles) {
        all.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
        for (final old in all.take(all.length - _maxFiles)) {
          try {
            old.deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}

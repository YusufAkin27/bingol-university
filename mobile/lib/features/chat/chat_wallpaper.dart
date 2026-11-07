import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../widgets/bu.dart';

/// Sohbet arka planı (konuşma ekranı duvar kağıdı; sohbet LİSTESİNE uygulanmaz).
///
/// Her zaman desenlidir (düz zemin seçeneği YOKTUR). Dört desen sunulur ([ChatBgStyle]): Ders (varsayılan), Sosyal, Bilim
/// (aynı çizgi-ikon dilinde, farklı ikon havuzları) ve Geometri (küçük çizgi şekiller). Yoğunluk ([ChatBgDensity]) Hafif |
/// Orta ayrı bir ayardır ve her desene uygulanır. Kırmızı/mavi vurgu YOK; desen yalnız `ink` jetonunun düşük alfa tonudur.
///
/// SABİT: desen mesaj alanının arkasında durur, kaydırmayla oynamaz; ayrıca katman ekran yüksekliğinde çizilip üstten
/// hizalanır, bu yüzden klavye açılıp mesaj alanı küçülünce desen ölçek değiştirmez / zıplamaz (yalnız kırpılır).
///
/// Performans: desen TEK SEFER küçük bir kare dokuya (480 × 480 dp) çizilir (`Picture.toImageSync`),
/// (desen, tema, yoğunluk, piksel oranı) anahtarıyla önbelleğe alınır ve `ImageShader` ile döşenir; kaydırırken
/// yeniden hesap/çizim yok (ayrı `RepaintBoundary`), blur/BackdropFilter yok.
enum ChatBgStyle {
  /// Ders / sınav / kütüphane ikonları — VARSAYILAN.
  study,

  /// Kulüp, yemekhane, spor, müzik, sosyal yaşam ikonları.
  social,

  /// Laboratuvar, yazılım, teknoloji ikonları.
  science,

  /// Küçük çizgi şekillerden (daire, eşkenar dörtgen, artı, üçgen, nokta) kaymalı ızgara.
  geometry,
}

/// Desen yoğunluğu: Hafif (varsayılan) | Orta (desen opaklığı).
enum ChatBgDensity { soft, strong }

/// Seçili arka plan tercihi: cihazda, kullanıcıya özel (güvenli depoda iki anahtar; sunucu ucu yok). Varsayılan
/// (Ders + Hafif) kayıt tutmaz. Çıkışta [clear] silinir (bkz. `registerUserDataCleaners`).
class ChatBackgroundPrefs extends ChangeNotifier {
  ChatBackgroundPrefs._();

  static final ChatBackgroundPrefs instance = ChatBackgroundPrefs._();
  static const key = 'chat_background';
  static const densityKey = 'chat_background_density';
  static const _storage = FlutterSecureStorage();

  ChatBgStyle _style = ChatBgStyle.study;
  ChatBgDensity _density = ChatBgDensity.soft;
  bool _loaded = false;
  Future<void>? _loading;

  /// Seçili desen; tercih okunana dek [loaded] false'tur (o kısa sürede desen çizilmez, okununca solarak gelir).
  ChatBgStyle get style => _style;
  ChatBgDensity get density => _density;
  bool get loaded => _loaded;

  /// Tercihi bir kez okur (eşzamanlı çağrılar aynı işi paylaşır). Okunamazsa varsayılan kalır.
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: key);
      final rawDensity = await _storage.read(key: densityKey);
      final found = ChatBgStyle.values.where((s) => s.name == raw);
      if (found.isNotEmpty) _style = found.first;
      // Eski sürüm değerleri: campus/pattern/soft/plain -> Ders Hafif; strong -> Ders Orta ("düz" ve "Kampüs" artık yok).
      if (raw == 'strong') _density = ChatBgDensity.strong;
      if (rawDensity == ChatBgDensity.strong.name) _density = ChatBgDensity.strong;
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
    _loaded = true;
    notifyListeners();
  }

  /// Seçimi uygular ve kaydeder (varsayılan = anahtarlar silinir).
  Future<void> set(ChatBgStyle s, {ChatBgDensity? density}) async {
    _loaded = true;
    final d = density ?? _density;
    if (_style != s || _density != d) {
      _style = s;
      _density = d;
      notifyListeners();
    }
    try {
      if (s == ChatBgStyle.study) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: s.name);
      }
      if (d == ChatBgDensity.soft) {
        await _storage.delete(key: densityKey);
      } else {
        await _storage.write(key: densityKey, value: d.name);
      }
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
  }

  /// Çıkış / hesap silme / oturum değişimi: tercih silinir, bellekteki değer varsayılana döner.
  static Future<void> clear() async {
    final p = instance;
    p._style = ChatBgStyle.study;
    p._density = ChatBgDensity.soft;
    p._loaded = true;
    p._loading = Future<void>.value();
    try {
      await _storage.delete(key: key);
      await _storage.delete(key: densityKey);
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
    p.notifyListeners();
  }

  /// Testler için: belleği başlangıç durumuna döndürür (depoya dokunmaz).
  @visibleForTesting
  static void debugReset() {
    final p = instance;
    p._style = ChatBgStyle.study;
    p._density = ChatBgDensity.soft;
    p._loaded = false;
    p._loading = null;
  }
}

class _Glyph {
  const _Glyph(this.icon, this.x, this.y, this.size, this.deg);
  final IconData icon;
  final double x;
  final double y;
  final double size;
  final double deg;
}

/// Duvar kağıdı çizimi: konuşma gövdesinin arkasında sabit durur (kaydırmayla oynamaz).
class ChatWallpaper extends StatefulWidget {
  const ChatWallpaper({super.key, required this.child, this.style, this.density});

  /// Üstte durur (mesaj listesi / boş durum).
  final Widget child;

  /// Verilirse tercih yerine bu desen çizilir (ayarlar önizlemesi).
  final ChatBgStyle? style;

  /// Verilirse tercih yerine bu yoğunluk kullanılır (ayarlar önizlemesi).
  final ChatBgDensity? density;

  /// Dokunun kenar uzunluğu (dp).
  static const tileSize = 480.0;

  /// İkon havuzları: aynı çizgi-ikon dili, farklı temalar.
  static const List<IconData> _studyPool = <IconData>[
    BuIcons.bookOpen, BuIcons.graduationCap, BuIcons.pencil, BuIcons.pencilLine, BuIcons.notebookPen,
    BuIcons.backpack, BuIcons.library, BuIcons.landmark, BuIcons.building2, BuIcons.lightbulb,
    BuIcons.calendar, BuIcons.calendarDays, BuIcons.calendarCheck, BuIcons.clock, BuIcons.alarmClock,
    BuIcons.hourglass, BuIcons.clipboardList, BuIcons.clipboardCheck, BuIcons.listChecks, BuIcons.fileText,
    BuIcons.idCard, BuIcons.bookmark, BuIcons.trophy, BuIcons.star, BuIcons.doorOpen,
  ];

  static const List<IconData> _socialPool = <IconData>[
    BuIcons.coffee, BuIcons.utensils, BuIcons.music, BuIcons.volleyball, BuIcons.dumbbell,
    BuIcons.flag, BuIcons.users, BuIcons.user, BuIcons.megaphone, BuIcons.newspaper,
    BuIcons.messageSquareText, BuIcons.thumbsUp, BuIcons.camera, BuIcons.palette, BuIcons.globe,
    BuIcons.compass, BuIcons.vote, BuIcons.headset, BuIcons.calendarClock, BuIcons.star,
    BuIcons.trophy, BuIcons.hash, BuIcons.building2,
  ];

  static const List<IconData> _sciencePool = <IconData>[
    BuIcons.atom, BuIcons.flaskConical, BuIcons.laptop, BuIcons.cpu, BuIcons.squareTerminal,
    BuIcons.lightbulb, BuIcons.chartPie, BuIcons.layers, BuIcons.wrench, BuIcons.qrCode,
    BuIcons.hash, BuIcons.globe, BuIcons.compass, BuIcons.camera, BuIcons.headset,
    BuIcons.fileText, BuIcons.clock, BuIcons.hourglass, BuIcons.library, BuIcons.bookOpen,
  ];

  /// Kampüs PNG'si dışındaki ikon desenleri için havuz + sabit tohum.
  static (List<IconData>, int) _poolOf(ChatBgStyle s) => switch (s) {
        ChatBgStyle.social => (_socialPool, 20261106),
        ChatBgStyle.science => (_sciencePool, 20261107),
        _ => (_studyPool, 20261105),
      };

  /// Ikonlar arası hedef boşluk (dp): "dip dibe" ama birbirine değmez.
  static const double _gap = 5;

  /// Rastgele sıkı yerleşim: sabit tohumlu (desen her açılışta aynı, titremez) ama ızgarasız. Dokunun kenarları
  /// kesintisiz döşenecek biçimde sarmalanır (mesafe torus üzerinde ölçülür). Boyut ve eğim rastgele; ikonlar
  /// karıştırılmış torbalardan çekilir (art arda aynı ikon gelmez).
  static List<_Glyph> _layout(List<IconData> pool, double width, double height, {required int seed}) {
    final rnd = math.Random(seed);
    final bag = <IconData>[];
    IconData? last;
    IconData nextIcon() {
      if (bag.isEmpty) {
        bag.addAll(pool);
        bag.shuffle(rnd);
        // Torba sınırında aynı ikon art arda gelmesin.
        if (last != null && bag.last == last) {
          bag.insert(0, bag.removeLast());
        }
      }
      last = bag.removeLast();
      return last!;
    }

    final placed = <_Glyph>[];
    final radii = <double>[];
    var misses = 0;
    // Çok sayıda deneme: yer kalmayana kadar doldurur (ardışık 900 ıskadan sonra durur).
    while (misses < 900 && placed.length < 900) {
      final fontSize = 17.0 + rnd.nextDouble() * 13.0; // 17..30 dp
      final r = fontSize * 0.46; // simgenin görsel yarıçapı
      final x = rnd.nextDouble() * width;
      final y = rnd.nextDouble() * height;
      var ok = true;
      for (var i = 0; i < placed.length && ok; i++) {
        var dx = (placed[i].x - x).abs();
        var dy = (placed[i].y - y).abs();
        if (dx > width / 2) dx = width - dx;
        if (dy > height / 2) dy = height - dy;
        final min = r + radii[i] + _gap;
        if (dx * dx + dy * dy < min * min) ok = false;
      }
      if (!ok) {
        misses++;
        continue;
      }
      misses = 0;
      placed.add(_Glyph(nextIcon(), x, y, fontSize, (rnd.nextDouble() - .5) * 56));
      radii.add(r);
    }
    return placed;
  }

  /// Desen başına ikon yerleşimi (ilk kullanımda bir kez hesaplanır).
  static final Map<ChatBgStyle, List<_Glyph>> _glyphsByStyle = {};

  static List<_Glyph> _glyphsOf(ChatBgStyle s) => _glyphsByStyle.putIfAbsent(s, () {
        final (pool, seed) = _poolOf(s);
        return _layout(pool, tileSize, tileSize, seed: seed);
      });

  static void _paintGlyph(Canvas c, _Glyph g, Color color, double ox, double oy) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(g.icon.codePoint),
        style: TextStyle(
          inherit: false,
          fontSize: g.size,
          fontFamily: g.icon.fontFamily,
          package: g.icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    c.save();
    c.translate(g.x + ox, g.y + oy);
    c.rotate(g.deg * math.pi / 180);
    c.translate(-tp.width / 2, -tp.height / 2);
    tp.paint(c, Offset.zero);
    c.restore();
    tp.dispose();
  }

  /// Geometri deseni: 40 dp hücreli, tek sıralar 20 dp kaymış ızgarada 5 küçük çizgi şekil (kenara değmez: dikişsiz).
  static void _paintGeometry(Canvas c, Color color) {
    const cell = 40.0;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const rows = 12;
    const cols = 12;
    for (var j = 0; j < rows; j++) {
      for (var i = 0; i < cols; i++) {
        final cx = (j.isEven ? 10.0 : 30.0) + i * cell;
        final cy = 20.0 + j * cell;
        final kind = (i + 2 * j) % 5;
        final turn = ((i * 7 + j * 3) % 4) * 15 * math.pi / 180;
        c.save();
        c.translate(cx, cy);
        c.rotate(turn);
        switch (kind) {
          case 0:
            c.drawCircle(Offset.zero, 6, stroke);
          case 1:
            c.drawPath(
              Path()
                ..moveTo(0, -8)
                ..lineTo(8, 0)
                ..lineTo(0, 8)
                ..lineTo(-8, 0)
                ..close(),
              stroke,
            );
          case 2:
            c.drawLine(const Offset(-7, 0), const Offset(7, 0), stroke);
            c.drawLine(const Offset(0, -7), const Offset(0, 7), stroke);
          case 3:
            c.drawPath(
              Path()
                ..moveTo(0, -7)
                ..lineTo(7, 6)
                ..lineTo(-7, 6)
                ..close(),
              stroke,
            );
          default:
            c.drawCircle(Offset.zero, 2.2, fill);
        }
        c.restore();
      }
    }
  }

  /// Desen opaklığı (ink jetonu üstüne): çok düşük kontrast, mesajlar net ayrışır.
  static double alphaOf(ChatBgStyle s, ChatBgDensity d, bool dark) {
    return switch (d) {
      ChatBgDensity.soft => dark ? .06 : .07,
      ChatBgDensity.strong => dark ? .10 : .12,
    };
  }

  static final Map<String, ui.Image> _cache = {};

  /// Üretilen doku sayısı (testte: desen yalnız bir kez üretilir).
  @visibleForTesting
  static int debugTileBuilds = 0;

  @visibleForTesting
  static void debugResetCache() {
    _cache.clear();
    debugTileBuilds = 0;
  }

  @visibleForTesting
  static int get debugCacheSize => _cache.length;

  static String _keyOf(ChatBgStyle s, Color ink, double alpha, double dpr) => '${s.name}|${ink.toARGB32()}|$alpha|$dpr';

  /// Önbellekteki doku (varsa).
  static ui.Image? cached(ChatBgStyle s, Color ink, double alpha, double dpr) => _cache[_keyOf(s, ink, alpha, dpr)];

  /// Dokuyu üretir (önbellekte yoksa) ve döndürür; üretilemezse null (yalnız tema zemini kalır).
  static ui.Image? tile(ChatBgStyle s, Color ink, double alpha, double dpr) {
    if (alpha <= 0) return null;
    final key = _keyOf(s, ink, alpha, dpr);
    final hit = _cache[key];
    if (hit != null) return hit;
    try {
      final px = (tileSize * dpr).round();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.scale(dpr);
      final color = ink.withValues(alpha: alpha);

      if (s == ChatBgStyle.geometry) {
        _paintGeometry(c, color);
      } else {
        // Kenara yakın ikonlar karşı kenarda da çizilir: dokular yan yana gelince dikiş görünmez.
        for (final g in _glyphsOf(s)) {
          for (final ox in const [-tileSize, 0.0, tileSize]) {
            for (final oy in const [-tileSize, 0.0, tileSize]) {
              final cx = g.x + ox;
              final cy = g.y + oy;
              final reach = g.size;
              if (cx < -reach || cx > tileSize + reach || cy < -reach || cy > tileSize + reach) continue;
              _paintGlyph(c, g, color, ox, oy);
            }
          }
        }
      }

      final pic = rec.endRecording();
      final img = pic.toImageSync(px, px);
      pic.dispose();
      debugTileBuilds++;
      // Bellek sınırı: en çok 6 doku (desen/tema/yoğunluk değişimlerinde eskisi atılır).
      while (_cache.length >= 6) {
        _cache.remove(_cache.keys.first);
      }
      _cache[key] = img;
      return img;
    } catch (_) {
      return null;
    }
  }

  @override
  State<ChatWallpaper> createState() => _ChatWallpaperState();
}

class _ChatWallpaperState extends State<ChatWallpaper> {
  bool _shown = false;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    if (widget.style == null) ChatBackgroundPrefs.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final dpr = math.min(MediaQuery.devicePixelRatioOf(context), 2.5);
    final reduced = BuMotion.reduced(context);
    final screenH = MediaQuery.sizeOf(context).height;
    return ListenableBuilder(
      listenable: ChatBackgroundPrefs.instance,
      builder: (context, _) {
        final prefs = ChatBackgroundPrefs.instance;
        // Tercih okunana dek (birkaç ms) yalnız tema zemini: yanlış deseni sonradan değiştirmek "zıplama" olurdu.
        // Bu bir seçenek değildir; tercih okununca desen hemen gelir.
        if (widget.style == null && !prefs.loaded) {
          return Stack(fit: StackFit.expand, children: [Positioned.fill(child: ColoredBox(color: t.bg)), widget.child]);
        }
        final style = widget.style ?? prefs.style;
        final density = widget.density ?? prefs.density;
        return LayoutBuilder(builder: (context, c) {
          final w = c.hasBoundedWidth ? c.maxWidth : MediaQuery.sizeOf(context).width;
          // SABİT: katman her zaman en az ekran yüksekliğinde ve üstten hizalı; klavye alanı daraltınca ölçek değişmez.
          final h = math.max(c.hasBoundedHeight ? c.maxHeight : 0.0, screenH);
          final Widget layer = _tileLayer(t, style, density, dark, dpr, reduced);
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(child: ColoredBox(color: t.bg)),
              Positioned(left: 0, top: 0, width: w, height: h, child: layer),
              widget.child,
            ],
          );
        });
      },
    );
  }

  /// Yordamsal desen (ikon / geometri): döşenmiş doku; yeni üretilen doku 150 ms solarak gelir.
  Widget _tileLayer(BuTokens t, ChatBgStyle style, ChatBgDensity density, bool dark, double dpr, bool reduced) {
    final alpha = ChatWallpaper.alphaOf(style, density, dark);
    var img = ChatWallpaper.cached(style, t.ink, alpha, dpr);
    var fresh = false;
    if (img == null) {
      img = ChatWallpaper.tile(style, t.ink, alpha, dpr);
      fresh = img != null;
    }
    if (fresh && !_shown && !reduced && !_scheduled) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _shown = true);
      });
    }
    if (img == null) return const SizedBox.shrink();
    final opacity = (fresh && !_shown && !reduced) ? 0.0 : 1.0;
    return RepaintBoundary(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: AnimatedOpacity(
            key: const ValueKey('chatWallpaper'),
            opacity: opacity,
            duration: reduced ? Duration.zero : const Duration(milliseconds: 150),
            child: CustomPaint(painter: _TilePainter(img, dpr), size: Size.infinite),
          ),
        ),
      ),
    );
  }
}

class _TilePainter extends CustomPainter {
  _TilePainter(this.image, this.dpr);

  final ui.Image image;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = ImageShader(
      image,
      TileMode.repeated,
      TileMode.repeated,
      Float64List.fromList(<double>[1 / dpr, 0, 0, 0, 0, 1 / dpr, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
      filterQuality: FilterQuality.low,
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    shader.dispose();
  }

  @override
  bool shouldRepaint(_TilePainter old) => old.image != image || old.dpr != dpr;
}

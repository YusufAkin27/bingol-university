import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../widgets/bu.dart';

/// Sohbet arka planı (konuşma ekranı duvar kağıdı; sohbet LİSTESİNE uygulanmaz).
///
/// Tasarım: sıcak nötr zemin (tema `bg`) üstüne tek renkli, düşük opaklıklı kampüs/öğrenci temalı ince çizgi
/// ikon deseni (kitap, kep, kahve, defter, takvim, nota, top, ampul, kalem, mesaj...). Kırmızı/mavi vurgu YOK;
/// desen yalnız `ink` jetonunun düşük alfa tonudur (açık temada koyu tint, koyu temada açık tint).
///
/// Desen: 480 dp tile, rastgele sıkı yerleşimli ~50 üniversite çizgi ikonu havuzu; açık temada %7, koyu temada %6 opaklık (çok düşük kontrast).
///
/// Performans: desen TEK SEFER küçük bir kare dokuya (480 × 480 dp) çizilir (`Picture.toImageSync`),
/// (tema, stil, piksel oranı) anahtarıyla önbelleğe alınır ve `ImageShader` ile döşenir; kaydırırken
/// yeniden hesap/çizim yok (ayrı `RepaintBoundary`), blur/BackdropFilter yok. Tema, stil ya da piksel
/// oranı değişince yeniden üretilir.
enum ChatBgStyle {
  pattern,
  soft,
  strong,
  plain,

  /// Ek varlık duvar kağıtları (ileride): `assets/chat_wallpapers/<ad>_light.png|<ad>_dark.png`.
  wpB,
  wpC;

  /// Varlık dosyası adı; yordamsal stillerde (Hafif/Orta/Düz) null. VARSAYILAN "Desen" = Stitch v3 kampüs doodle
  /// duvar kağıdı (`wp_a_light.png` / `wp_a_dark.png`, 1170x2532).
  String? get assetName => switch (this) {
        ChatBgStyle.pattern => 'wp_a',
        ChatBgStyle.wpB => 'wp_b',
        ChatBgStyle.wpC => 'wp_c',
        _ => null,
      };

  bool get isAsset => assetName != null;
}

/// Ayarlar sayfasında seçenek olarak sunulan varlık duvar kağıtları. Tasarım teslim edilip PNG'ler
/// `assets/chat_wallpapers/` altına konunca ilgili stil bu listeye eklenir (altyapı hazır; liste boşken yalnız
/// yordamsal seçenekler görünür).
const List<ChatBgStyle> kChatWallpaperAssets = <ChatBgStyle>[];

/// Varlık dosya yolu (tema başına ayrı görsel).
String chatWallpaperAssetPath(ChatBgStyle s, {required bool dark}) =>
    'assets/chat_wallpapers/${s.assetName}_${dark ? 'dark' : 'light'}.png';

/// Varlık duvar kağıdının üstüne bindirilen tema zemini örtüsü (0..1): yüksek = desen daha silik. Monochrome
/// tasarımda desen yalnız belli belirsiz görünür (balonlar ve metin öne çıkar).
const double kChatWallpaperVeil = .62;

/// Renk -> gri (Rec.709 parlaklık) matrisi: varlıktaki kırmızı/lacivert/krem tonları nötrleşir.
const List<double> kChatWallpaperGray = <double>[
  .2126, .7152, .0722, 0, 0,
  .2126, .7152, .0722, 0, 0,
  .2126, .7152, .0722, 0, 0,
  0, 0, 0, 1, 0,
];

/// Seçili arka plan tercihi: cihazda, kullanıcıya özel (güvenli depoda tek anahtar; sunucu ucu yok). Varsayılan
/// (Desen) kayıt tutmaz. Çıkışta [clear] silinir (bkz. `registerUserDataCleaners`).
class ChatBackgroundPrefs extends ChangeNotifier {
  ChatBackgroundPrefs._();

  static final ChatBackgroundPrefs instance = ChatBackgroundPrefs._();
  static const key = 'chat_background';
  static const _storage = FlutterSecureStorage();

  ChatBgStyle _style = ChatBgStyle.pattern;
  bool _loaded = false;
  Future<void>? _loading;

  /// Seçili stil; tercih okunana dek [loaded] false'tur (o sürede yalnız düz zemin çizilir, desen sonradan solarak gelir).
  ChatBgStyle get style => _style;
  bool get loaded => _loaded;

  /// Tercihi bir kez okur (eşzamanlı çağrılar aynı işi paylaşır). Okunamazsa varsayılan kalır.
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: key);
      final found = ChatBgStyle.values.where((s) => s.name == raw);
      if (found.isNotEmpty) _style = found.first;
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  /// Seçimi uygular ve kaydeder (varsayılan = anahtar silinir).
  Future<void> set(ChatBgStyle s) async {
    _loaded = true;
    if (_style != s) {
      _style = s;
      notifyListeners();
    }
    try {
      if (s == ChatBgStyle.pattern) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: s.name);
      }
    } catch (_) {}
  }

  /// Çıkış / hesap silme / oturum değişimi: tercih silinir, bellekteki değer varsayılana döner.
  static Future<void> clear() async {
    final p = instance;
    p._style = ChatBgStyle.pattern;
    p._loaded = true;
    p._loading = Future<void>.value();
    try {
      await _storage.delete(key: key);
    } catch (_) {}
    p.notifyListeners();
  }

  /// Testler için: belleği başlangıç durumuna döndürür (depoya dokunmaz).
  @visibleForTesting
  static void debugReset() {
    final p = instance;
    p._style = ChatBgStyle.pattern;
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
  const ChatWallpaper({super.key, required this.child, this.style});

  /// Üstte durur (mesaj listesi / boş durum).
  final Widget child;

  /// Verilirse tercih yerine bu stil çizilir (ayarlar önizlemesi).
  final ChatBgStyle? style;

  /// Dokunun kenar uzunluğu (dp).
  static const tileSize = 480.0;

  /// Üniversite / kampüs yaşamı çizgi ikonları (ders, sınav, kütüphane, laboratuvar, kampüs, yemekhane, kulüp...).
  /// Havuz geniştir; desen her seferinde karışık sırayla dizilir, aynı ikon dizisi tekrarlanmaz.
  static const List<IconData> _pool = <IconData>[
    BuIcons.bookOpen, BuIcons.graduationCap, BuIcons.pencil, BuIcons.pencilLine, BuIcons.notebookPen,
    BuIcons.backpack, BuIcons.library, BuIcons.landmark, BuIcons.building2, BuIcons.atom,
    BuIcons.flaskConical, BuIcons.laptop, BuIcons.cpu, BuIcons.squareTerminal, BuIcons.lightbulb,
    BuIcons.calendar, BuIcons.calendarDays, BuIcons.calendarCheck, BuIcons.calendarClock, BuIcons.clock,
    BuIcons.alarmClock, BuIcons.hourglass, BuIcons.clipboardList, BuIcons.clipboardCheck, BuIcons.listChecks,
    BuIcons.fileText, BuIcons.idCard, BuIcons.bookmark, BuIcons.trophy, BuIcons.star,
    BuIcons.megaphone, BuIcons.newspaper, BuIcons.users, BuIcons.user, BuIcons.coffee,
    BuIcons.utensils, BuIcons.globe, BuIcons.compass, BuIcons.palette, BuIcons.music,
    BuIcons.volleyball, BuIcons.dumbbell, BuIcons.flag, BuIcons.doorOpen, BuIcons.headset,
    BuIcons.chartPie, BuIcons.layers, BuIcons.vote, BuIcons.messageSquareText, BuIcons.thumbsUp,
    BuIcons.camera, BuIcons.wrench, BuIcons.qrCode, BuIcons.hash,
  ];

  /// Ikonlar arası hedef boşluk (dp): "dip dibe" ama birbirine değmez.
  static const double _gap = 5;

  /// Rastgele sıkı yerleşim: sabit tohumlu (desen her açılışta aynı, titremez) ama ızgarasız. [wrap] true ise
  /// dokunun kenarları kesintisiz döşenecek biçimde sarmalanır (mesafe torus üzerinde ölçülür). Boyut ve eğim
  /// rastgele; ikonlar karıştırılmış torbalardan çekilir (art arda aynı ikon gelmez).
  static List<_Glyph> _layout(double width, double height, {required bool wrap, int seed = 20261105}) {
    final rnd = math.Random(seed);
    final bag = <IconData>[];
    IconData? last;
    IconData nextIcon() {
      if (bag.isEmpty) {
        bag.addAll(_pool);
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
        if (wrap) {
          if (dx > width / 2) dx = width - dx;
          if (dy > height / 2) dy = height - dy;
        }
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

  /// Sarmalanan döşeme dokusunun ikonları (yordamsal stiller: Hafif / Orta).
  static final List<_Glyph> _glyphs = _layout(tileSize, tileSize, wrap: true);

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

  /// Desen opaklığı (ink jetonu üstüne): çok düşük kontrast, mesajlar net ayrışır.
  static double alphaOf(ChatBgStyle s, bool dark) => switch (s) {
        ChatBgStyle.pattern => dark ? .06 : .07,
        ChatBgStyle.soft => dark ? .04 : .045,
        ChatBgStyle.strong => dark ? .10 : .12,
        _ => 0,
      };

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

  static String _keyOf(Color ink, double alpha, double dpr) => '${ink.toARGB32()}|$alpha|$dpr';

  /// Önbellekteki doku (varsa).
  static ui.Image? cached(Color ink, double alpha, double dpr) => _cache[_keyOf(ink, alpha, dpr)];

  /// Dokuyu üretir (önbellekte yoksa) ve döndürür; üretilemezse null (düz zemin kalır).
  static ui.Image? tile(Color ink, double alpha, double dpr) {
    if (alpha <= 0) return null;
    final key = _keyOf(ink, alpha, dpr);
    final hit = _cache[key];
    if (hit != null) return hit;
    try {
      final px = (tileSize * dpr).round();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.scale(dpr);
      final color = ink.withValues(alpha: alpha);

      // --- İkonları çiz ---
      // Kenara yakın ikonlar karşı kenarda da çizilir: dokular yan yana gelince dikiş görünmez.
      for (final g in _glyphs) {
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

      final pic = rec.endRecording();
      final img = pic.toImageSync(px, px);
      pic.dispose();
      debugTileBuilds++;
      // Bellek sınırı: en çok 4 doku (tema/stil/yoğunluk değişimlerinde eskisi atılır).
      while (_cache.length >= 4) {
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
    return ListenableBuilder(
      listenable: ChatBackgroundPrefs.instance,
      builder: (context, _) {
        final prefs = ChatBackgroundPrefs.instance;
        // Tercih okunana dek yalnız düz zemin: deseni sonradan kaldırmak "zıplama" olurdu.
        final style = widget.style ?? (prefs.loaded ? prefs.style : ChatBgStyle.plain);
        final alpha = ChatWallpaper.alphaOf(style, dark);
        if (style.isAsset) return _assetLayer(t, style, dark, reduced);
        ui.Image? img;
        var fresh = false;
        if (alpha > 0) {
          img = ChatWallpaper.cached(t.ink, alpha, dpr);
          if (img == null) {
            img = ChatWallpaper.tile(t.ink, alpha, dpr);
            fresh = img != null;
          }
        }
        // Yeni üretilen doku 150 ms solarak gelir; önbellekteyse ya da "azalt" açıksa anında.
        if (fresh && !_shown && !reduced && !_scheduled) {
          _scheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _shown = true);
          });
        }
        final opacity = (img == null || (fresh && !_shown && !reduced)) ? 0.0 : 1.0;
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: ColoredBox(color: t.bg)),
            if (img != null)
              Positioned.fill(
                child: RepaintBoundary(
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
                ),
              ),
            widget.child,
          ],
        );
      },
    );
  }

  /// Varlık duvar kağıdı: tam yüzey, `BoxFit.cover`, ekran genişliği x dpr kadar çözülür; yüklenemezse düz zemin kalır.
  Widget _assetLayer(BuTokens t, ChatBgStyle style, bool dark, bool reduced) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: ColoredBox(color: t.bg)),
        Positioned.fill(
          child: RepaintBoundary(
            key: const ValueKey('chatWallpaper'),
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: LayoutBuilder(builder: (context, c) {
                  final dpr = MediaQuery.devicePixelRatioOf(context);
                  final w = c.hasBoundedWidth ? c.maxWidth : MediaQuery.sizeOf(context).width;
                  // PNG kullanıcının kendi dosyası (değişmez); monochrome için çizimde gri tonlanır (kırmızı/lacivert
                  // vurgular nötrleşir) ve üstüne tema zemini bindirilir: desen çok düşük kontrastlı, mesajlar öne çıkar.
                  return ColorFiltered(
                    key: const ValueKey('chatWallpaperTone'),
                    colorFilter: const ColorFilter.matrix(kChatWallpaperGray),
                    child: Image.asset(
                      chatWallpaperAssetPath(style, dark: dark),
                      key: const ValueKey('chatWallpaperAsset'),
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      cacheWidth: (w * dpr).round(),
                      gaplessPlayback: true,
                      color: t.bg.withValues(alpha: kChatWallpaperVeil),
                      colorBlendMode: BlendMode.srcOver,
                      errorBuilder: (c, e, st) => const SizedBox.shrink(),
                      frameBuilder: (c, child, frame, sync) => sync
                          ? child
                          : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: reduced ? Duration.zero : const Duration(milliseconds: 150), child: child),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        widget.child,
      ],
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

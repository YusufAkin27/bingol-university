import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../widgets/bu.dart';

/// Sohbet arka planı (konuşma ekranı duvar kağıdı; sohbet LİSTESİNE uygulanmaz).
///
/// Tasarım: sıcak nötr zemin (tema `bg`) üstüne tek renkli, çok düşük opaklıklı kampüs/öğrenci temalı ince çizgi
/// ikon deseni (kitap, kep, kahve, defter, takvim, nota, top, ampul, kalem, mesaj...). Kırmızı/mavi vurgu YOK; desen
/// yalnız `ink` jetonunun düşük alfa tonudur (açık temada koyu tint, koyu temada açık tint).
///
/// Performans: desen TEK SEFER küçük bir kare dokuya (360 x 360 dp) çizilir (`Picture.toImageSync`), (tema, stil,
/// piksel oranı) anahtarıyla önbelleğe alınır ve `ImageShader` ile döşenir; kaydırırken yeniden hesap/çizim yok
/// (ayrı `RepaintBoundary`), blur/BackdropFilter yok. Tema, stil ya da piksel oranı değişince yeniden üretilir.
enum ChatBgStyle {
  pattern,
  soft,
  strong,
  plain,

  /// Varlık (asset) tabanlı duvar kağıtları: `assets/chat_wallpapers/<ad>_light.png|<ad>_dark.png`.
  wpA,
  wpB,
  wpC;

  /// Varlık dosyası adı (`wp_a`...); yordamsal stillerde null.
  String? get assetName => switch (this) {
        ChatBgStyle.wpA => 'wp_a',
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
String chatWallpaperAssetPath(ChatBgStyle s, {required bool dark}) => 'assets/chat_wallpapers/${s.assetName}_${dark ? 'dark' : 'light'}.png';

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
  static const tileSize = 360.0;

  /// Kare dokuda yer alan ikonlar: ızgara + hafif kayma, hiçbiri kenara taşmaz (kesintisiz döşenir).
  static final List<_Glyph> _glyphs = [
    const _Glyph(LucideIcons.bookOpen, 40, 34, 26, -12),
    const _Glyph(LucideIcons.coffee, 135, 52, 24, 10),
    const _Glyph(LucideIcons.lightbulb, 225, 30, 24, 14),
    const _Glyph(LucideIcons.music, 318, 56, 24, -8),
    const _Glyph(LucideIcons.graduationCap, 60, 128, 28, 8),
    const _Glyph(LucideIcons.messageCircle, 160, 140, 24, -14),
    const _Glyph(LucideIcons.pencil, 262, 118, 24, 22),
    const _Glyph(LucideIcons.calendar, 330, 150, 22, -10),
    const _Glyph(LucideIcons.notebookPen, 30, 222, 26, 12),
    const _Glyph(LucideIcons.volleyball, 118, 230, 26, -6),
    const _Glyph(LucideIcons.laptop, 210, 214, 26, 6),
    const _Glyph(LucideIcons.trophy, 302, 240, 24, -14),
    const _Glyph(LucideIcons.atom, 70, 318, 26, -8),
    const _Glyph(LucideIcons.backpack, 160, 326, 24, 12),
    const _Glyph(LucideIcons.palette, 250, 312, 24, -10),
    const _Glyph(LucideIcons.library, 335, 330, 22, 8),
  ];

  /// Desen opaklığı (ink jetonu üstüne): açık temada %4.5-11, koyu temada %4-9.
  static double alphaOf(ChatBgStyle s, bool dark) => switch (s) {
        ChatBgStyle.pattern => dark ? .06 : .07,
        ChatBgStyle.soft => dark ? .04 : .045,
        ChatBgStyle.strong => dark ? .09 : .11,
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
      for (final g in _glyphs) {
        final tp = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(g.icon.codePoint),
            style: TextStyle(inherit: false, fontSize: g.size, fontFamily: g.icon.fontFamily, package: g.icon.fontPackage, color: color),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        c.save();
        c.translate(g.x, g.y);
        c.rotate(g.deg * math.pi / 180);
        c.translate(-tp.width / 2, -tp.height / 2);
        tp.paint(c, Offset.zero);
        c.restore();
        tp.dispose();
      }
      final pic = rec.endRecording();
      final img = pic.toImageSync(px, px);
      pic.dispose();
      debugTileBuilds++;
      // Bellek sınırı: en çok 3 doku (tema/stil/yoğunluk değişimlerinde eskisi atılır).
      while (_cache.length >= 3) {
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
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: LayoutBuilder(builder: (context, c) {
                  final dpr = MediaQuery.devicePixelRatioOf(context);
                  final w = c.hasBoundedWidth ? c.maxWidth : MediaQuery.sizeOf(context).width;
                  return Image.asset(
                    chatWallpaperAssetPath(style, dark: dark),
                    key: const ValueKey('chatWallpaperAsset'),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    cacheWidth: (w * dpr).round(),
                    gaplessPlayback: true,
                    errorBuilder: (c, e, st) => const SizedBox.shrink(),
                    frameBuilder: (c, child, frame, sync) => sync
                        ? child
                        : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: reduced ? Duration.zero : const Duration(milliseconds: 150), child: child),
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

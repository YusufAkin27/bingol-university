import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

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
/// Desen yoğunluğu: 240 dp tile, 8×6 = 48 glyph, ~30-40 dp aralıklı ızgara.
/// Açık tema: belirgin, sıcak kahverengi/lacivert tint (%12-20 opaklık).
/// Koyu tema: parlak beyaz tint (%10-16 opaklık).
///
/// Performans: desen TEK SEFER küçük bir kare dokuya (240 × 240 dp) çizilir (`Picture.toImageSync`),
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

  /// Dokunun kenar uzunluğu (dp). 240 dp → ~30-40 dp aralıklı yoğun desen.
  static const tileSize = 240.0;

  /// Kampüs temalı sık desen: 8×6 = 48 glyph, 240 dp tile, ~30 dp aralıklı ızgara.
  /// Farklı satır/kolon offsetleri + rastgele eğimler düzenli ızgara hissini kırar.
  static final List<_Glyph> _glyphs = List.generate(48, (i) {
    // Zengin kampüs emoji seti (22 farklı ikon)
    const icons = [
      BuIcons.bookOpen,       // açık kitap
      BuIcons.coffee,         // kahve
      BuIcons.lightbulb,      // fikir ampülü
      BuIcons.music,          // nota
      BuIcons.graduationCap,  // mezuniyet
      BuIcons.messageCircle,  // sohbet balonu
      BuIcons.pencil,         // kalem
      BuIcons.calendar,       // takvim
      BuIcons.notebookPen,    // defter
      BuIcons.volleyball,     // top
      BuIcons.laptop,         // bilgisayar
      BuIcons.trophy,         // kupa
      BuIcons.atom,           // atom
      BuIcons.backpack,       // sırt çantası
      BuIcons.palette,        // palet
      BuIcons.mapPin,         // konum
      BuIcons.bookmark,       // yer imi
      BuIcons.alarmClock,     // çalar saat
      BuIcons.star,           // yıldız
      BuIcons.heart,          // kalp
      BuIcons.search,         // arama
      BuIcons.bell,           // zil
    ];
    final row = i ~/ 8;      // 6 satır
    final col = i % 8;       // 8 kolon
    // Çift/tek satır arası 15 dp yatay kaydırma: yarım-tuğla düzeni
    final rowShift = (row % 2 == 0) ? 0.0 : 15.0;
    // Küçük rastlantısal titreme (tekdüze ızgarayı kırar)
    final jx = ((i * 13 + row * 7 + col * 3) % 11) - 5.0;
    final jy = ((i * 11 + col * 5 + row * 2) % 11) - 5.0;
    return _Glyph(
      icons[(i * 7 + row * 5 + col * 3) % icons.length],
      12.0 + col * 30 + rowShift + jx,  // x: 30 dp aralıklı kolon
      14.0 + row * 40 + jy,             // y: 40 dp aralıklı satır
      18.0 + (i % 5) * 2.5,            // boyut: 18-28 dp arası değişken
      ((i * 13 + row * 7) % 42 - 21).toDouble(), // -21..+21 derece
    );
  });

  /// Desen opaklığı: açık temada %8-20, koyu temada %7-16 (WhatsApp/Telegram gibi belirgin).
  /// Light modda: ink (koyu lacivert) düşük opaklıkta → ılık, sıcak desen.
  /// Dark modda: ink (açık gri/beyaz) düşük opaklıkta → zarif, göze batmayan desen.
  static double alphaOf(ChatBgStyle s, bool dark) => switch (s) {
        ChatBgStyle.pattern => dark ? .10 : .12,
        ChatBgStyle.soft    => dark ? .07 : .08,
        ChatBgStyle.strong  => dark ? .16 : .20,
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
      for (final g in _glyphs) {
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
        c.translate(g.x, g.y);
        c.rotate(g.deg * math.pi / 180);
        c.translate(-tp.width / 2, -tp.height / 2);
        tp.paint(c, Offset.zero);
        c.restore();
        tp.dispose();
      }

      // --- İkonlar arası boşlukları dolduran dekoratif detaylar ---
      // Küçük yıldız kıvılcımlar, noktalı izler ve kıvrımlı tireler.
      final detailColor = color.withValues(alpha: alpha * .55);
      final detailThin = Paint()
        ..color = detailColor
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final detailNorm = Paint()
        ..color = detailColor
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      // 8 kolon × 6 satır detay noktaları (ikon merkezlerinin arasında)
      for (var dRow = 0; dRow < 6; dRow++) {
        for (var dCol = 0; dCol < 8; dCol++) {
          // İkon merkezlerinin arasındaki ara nokta
          final dx2 = 27.0 + dCol * 30 + (dRow % 2 == 0 ? 0 : 15);
          final dy2 = 34.0 + dRow * 40;
          final p = Offset(dx2, dy2);
          final seed = dRow * 8 + dCol;
          if (seed % 4 == 0) {
            // ✦ 4 kollu kıvılcım
            c.drawLine(p.translate(-3, 0), p.translate(3, 0), detailNorm);
            c.drawLine(p.translate(0, -3), p.translate(0, 3), detailNorm);
            c.drawLine(p.translate(-2, -2), p.translate(2, 2), detailThin);
            c.drawLine(p.translate(2, -2), p.translate(-2, 2), detailThin);
          } else if (seed % 4 == 1) {
            // Küçük kıvrımlı dal
            final curvePath = Path()
              ..moveTo(p.dx - 6, p.dy + 2)
              ..quadraticBezierTo(p.dx, p.dy - 5, p.dx + 6, p.dy - 1);
            c.drawPath(curvePath, detailNorm);
          } else if (seed % 4 == 2) {
            // 3 noktalı iz
            final dotPaint = Paint()
              ..color = color.withValues(alpha: alpha * .70);
            for (var dot = 0; dot < 3; dot++) {
              c.drawCircle(
                p.translate(-4.0 + dot * 4, dot.isOdd ? 1.5 : -1.5),
                0.85,
                dotPaint,
              );
            }
          } else {
            // Küçük daire (nokta)
            c.drawCircle(
              p,
              1.0,
              Paint()..color = color.withValues(alpha: alpha * .60),
            );
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

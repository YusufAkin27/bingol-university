import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';
import '../core/locale_controller.dart';
import '../core/theme.dart';
import '../core/theme/bu_elevation.dart';
import '../core/theme/bu_motion.dart';
import '../core/theme/bu_shape.dart';
import '../core/typography.dart';
import 'bu_default_avatar.dart';
import 'bu_pressable.dart';

export 'package:lucide_icons_flutter/lucide_icons.dart' show LucideIcons;

/// Türkçe büyük harf: i -> İ, ı -> I ("kasım" -> "KASIM", "bildirim" -> "BİLDİRİM").
/// Dart'ın toUpperCase'i yerel ayara bakmaz; i -> I yapar.
String trUpper(String s) => s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

/// "Ayşe Yılmaz" -> "AY"
String initialsOf(String? name) {
  final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).take(2);
  final s = parts.map((p) => trUpper(p.characters.first)).join();
  return s.isEmpty ? '?' : s;
}

/// Sunucunun göreli dosya yolunu (/files/...) tam adrese çevirir.
String? fileUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  return path.startsWith('http') ? path : '$apiOrigin$path';
}

bool _isArabic(BuildContext context) => Localizations.maybeLocaleOf(context)?.languageCode == 'ar';

/// Ekran üst başlığı: isteğe bağlı geri düğmesi + büyük başlık + sağda eylemler.
class BuHeader extends StatelessWidget {
  const BuHeader({super.key, required this.title, this.onBack, this.actions = const [], this.subtitle});

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(20, MediaQuery.of(context).padding.top + 12, 20, 0),
      child: Row(
        children: [
          if (onBack != null) ...[
            BuIconButton(icon: LucideIcons.arrowLeft, onTap: onBack, tooltip: context.l10n.commonBack),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2 satıra kadar: büyük yazı ölçeğinde/uzun başlıkta "Sözleşm…" gibi kırpılmaz.
                // Büyük başlık en çok 1.35 ölçeğe kadar büyür (ikon düğmeleriyle yan yana kelime bölünmesin).
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.35,
                  child: Semantics(
                    header: true,
                    child: LayoutBuilder(builder: (context, c) {
                      // Arapçada harf aralığı bitişik harfleri bozar: sıfır.
                      final style = BuType.display.copyWith(letterSpacing: _isArabic(context) ? 0 : -.4, color: t.ink);
                      // En uzun kelime satıra sığmıyorsa yazıyı küçült (kelime ortadan bölünmesin).
                      final scale = MediaQuery.textScalerOf(context).scale(1);
                      var longest = 0.0;
                      for (final w in title.split(RegExp(r'\s+'))) {
                        final tp = TextPainter(
                          text: TextSpan(text: w, style: style),
                          textDirection: Directionality.of(context),
                          textScaler: TextScaler.linear(scale),
                        )..layout();
                        if (tp.width > longest) longest = tp.width;
                      }
                      final fit = longest > c.maxWidth && c.maxWidth.isFinite ? (c.maxWidth / longest).clamp(.55, 1.0) : 1.0;
                      return Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textScaler: TextScaler.linear(scale * fit),
                          style: style);
                    }),
                  ),
                ),
                if (subtitle != null)
                  Text(subtitle!, style: BuType.caption.copyWith(color: t.mut)),
              ],
            ),
          ),
          for (final a in actions) ...[const SizedBox(width: 8), a],
        ],
      ),
    );
  }
}

/// Yön belirten simgeyi (ok/ayraç) sağdan sola düzende aynalar; diğer simgelere dokunmaz.
IconData buDirIcon(BuildContext context, IconData icon) {
  if (Directionality.of(context) != TextDirection.rtl) return icon;
  if (icon == LucideIcons.arrowLeft) return LucideIcons.arrowRight;
  if (icon == LucideIcons.arrowRight) return LucideIcons.arrowLeft;
  if (icon == LucideIcons.chevronLeft) return LucideIcons.chevronRight;
  if (icon == LucideIcons.chevronRight) return LucideIcons.chevronLeft;
  return icon;
}

/// Yuvarlak, çizgili ikon düğmesi (üst başlıkta). [filled] true ise kırmızı dolgulu.
/// Görsel boyut [size] (44); dokunma alanı en az 48x48 dp. Basılınca hafifçe küçülür.
class BuIconButton extends StatelessWidget {
  const BuIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.filled = false,
    this.badge = false,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool filled;
  final bool badge;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final hit = size < 48 ? 48.0 : size;
    final visual = Material(
      color: filled ? t.pr : t.sf,
      shape: CircleBorder(side: filled ? BorderSide.none : BorderSide(color: t.bd)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(buDirIcon(context, icon), size: size * .45, color: filled ? t.onPr : t.ink),
              if (badge)
                PositionedDirectional(
                  top: size * .2,
                  end: size * .22,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                        color: t.pr, shape: BoxShape.circle, border: Border.all(color: t.sf, width: 2)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    final child = Semantics(
      button: true,
      enabled: onTap != null,
      label: tooltip,
      child: SizedBox(
        width: hit,
        height: hit,
        child: Center(
          // Görsel 44 dp; çevresindeki boşluk da basılabilir (dış GestureDetector, anlamsal ikinci düğme yok).
          child: BuPressable(
            scale: .92,
            enabled: onTap != null,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (onTap != null)
                  ExcludeSemantics(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onTap,
                      child: SizedBox(width: hit, height: hit),
                    ),
                  ),
                visual,
              ],
            ),
          ),
        ),
      ),
    );
    // Etiket Semantics'te verilir; Tooltip yalnız görsel ipucu (çift okunmasın).
    return tooltip == null ? child : Tooltip(message: tooltip!, excludeFromSemantics: true, child: child);
  }
}

/// Kart görünümü.
enum BuCardStyle {
  /// Beyaz yüzey + ince çizgi (varsayılan).
  outlined,

  /// Çizgisiz beyaz yüzey.
  filled,

  /// Beyaz yüzey + yumuşak gölge (koyu temada tonal, gölgesiz).
  elevated,

  /// İkincil yüzey tonu (`sf2`): vurgusuz bilgi kutusu.
  tonal,
}

/// Çizgili beyaz kart. [onTap] verilirse dokunma efekti (dalga + hafif küçülme) olur.
/// [style] verilmezse eski davranış: `border` true → outlined, false → filled.
class BuCard extends StatelessWidget {
  const BuCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.color,
    this.radius = 20,
    this.border = true,
    this.style,
    this.onLongPress,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  final bool border;

  /// Yeni (P0): kart görünümü; null ise [border]'a göre belirlenir.
  final BuCardStyle? style;

  /// Yeni (P0): uzun basma.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final st = style ?? (border ? BuCardStyle.outlined : BuCardStyle.filled);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: st == BuCardStyle.outlined ? BorderSide(color: t.bd) : BorderSide.none,
    );
    final bg = color ?? (st == BuCardStyle.tonal ? t.sf2 : t.sf);
    Widget card = Material(
      color: bg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (st == BuCardStyle.elevated) {
      final shadows = BuElevation.of(context, 1);
      if (shadows.isNotEmpty) {
        card = DecoratedBox(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: shadows),
          child: card,
        );
      } else {
        // Koyu temada gölge yok: ince çizgiyle ayrışır.
        card = Material(
          color: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: t.bd)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, onLongPress: onLongPress, child: Padding(padding: padding, child: child)),
        );
      }
    }
    return onTap == null && onLongPress == null ? card : BuPressable(scale: .985, child: card);
  }
}

/// Yatay filtre çipi (seçili: marka tonu + kalın yazı). 44 dp dokunma alanı, hap şekli.
class BuChip extends StatelessWidget {
  const BuChip({super.key, required this.label, this.selected = false, this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Yeni (P0): etiketin başında küçük simge.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final fg = selected ? t.onSoft : t.mut;
    // Görünür çip 34 dp; dokunma alanı 48 dp (dış GestureDetector boşluğu da yakalar).
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                buHaptic(BuHaptic.selection);
                onTap!();
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: BuMotion.of(context, BuMotion.short),
              curve: BuMotion.standard,
              decoration: ShapeDecoration(
                color: selected ? t.soft : t.sf,
                shape: StadiumBorder(side: BorderSide(color: selected ? t.pr.withValues(alpha: .45) : t.bd)),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  excludeFromSemantics: true,
                  onTap: onTap == null
                      ? null
                      : () {
                          buHaptic(BuHaptic.selection);
                          onTap!();
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    // Çip yüksekliği sabit satır alanına sığsın: yazı ölçeği 1.5 ile sınırlı.
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.5,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: 6)],
                          Text(label,
                              style: BuType.label.copyWith(color: fg, fontWeight: selected ? FontWeight.w700 : FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Küçük rozet. [soft] true: kırmızı yumuşak zemin; false: koyu zemin.
class BuBadge extends StatelessWidget {
  const BuBadge(this.text, {super.key, this.soft = false, this.color, this.onColor});

  final String text;
  final bool soft;
  final Color? color;
  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final bg = color ?? (soft ? t.soft : t.ink);
    final fg = onColor ?? (soft ? t.onSoft : t.bg);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: BuType.micro.copyWith(color: fg)),
    );
  }
}

/// Görselli avatar. Fotoğraf yoksa / yüklenirken / yüklenemezse VARSAYILAN PROFİL GÖRSELİ ([BuDefaultAvatar]) görünür
/// (baş harf yok; renk ad/seed'den kararlı). [square] true: yuvarlatılmış kare (kulüp/grup).
/// [online] true ise sağ altta yeşil çevrimiçi noktası çizilir.
class BuAvatar extends StatelessWidget {
  const BuAvatar({
    super.key,
    this.name,
    this.url,
    this.size = 48,
    this.square = false,
    this.dark = false,
    this.headers,
    this.group = false,
    this.online = false,
  });

  /// Yalnız varsayılan görselin renk varyantı için (kişi her yerde aynı rengi alır).
  final String? name;
  final String? url;

  /// Yetkili uçlardan (`/api/...`) gelen görseller için istek başlıkları (genelde Bearer).
  final Map<String, String>? headers;
  final double size;
  final bool square;
  final bool dark; // eski parametre; varsayılan görsel temadan bağımsızdır

  /// Grup/kulüp/etkinlik avatarı: fotoğraf yoksa varsayılan grup görseli.
  final bool group;

  /// Çevrimiçi noktası.
  final bool online;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final radius = BorderRadius.circular(square ? size * .34 : size);
    // Varsayılan görsel HER ZAMAN altta durur: gerçek fotoğraf yüklenemezse (hata/yavaş ağ) o kalır.
    final fallback = BuDefaultAvatar(seed: name, size: size, group: group);
    final full = fileUrl(url);
    // Küçük avatar için tam çözünürlüklü görseli belleğe açma.
    final px = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    final img = ClipRRect(
      borderRadius: radius,
      child: full == null
          ? fallback
          : SizedBox(
              width: size,
              height: size,
              child: Stack(fit: StackFit.expand, children: [
                fallback,
                Image.network(full,
                    headers: headers,
                    width: size,
                    height: size,
                    cacheWidth: px,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    // Fotoğraf gelince varsayılan görselin üstüne yumuşakça belirir.
                    frameBuilder: (context, child, frame, sync) => sync
                        ? child
                        : AnimatedOpacity(
                            opacity: frame == null ? 0 : 1,
                            duration: BuMotion.of(context, BuMotion.medium),
                            curve: BuMotion.decelerate,
                            child: child,
                          ),
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ]),
            ),
    );
    if (!online) return img;
    final dot = (size * .26).clamp(10.0, 16.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        img,
        PositionedDirectional(
          end: -1,
          bottom: -1,
          child: Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(color: t.ok, shape: BoxShape.circle, border: Border.all(color: t.sf, width: 2)),
          ),
        ),
      ],
    );
  }
}

/// Düğme türü: [primary] dolu marka, [soft] tonal, [outline] çerçeveli, [text] düz metin, [danger] dolu kırmızı (silme/çıkış).
enum BuButtonKind { primary, outline, soft, text, danger }

/// Hap biçimli (compact) ya da tam genişlikli düğme. Basılınca hafifçe küçülür, dokununca titrer.
class BuButton extends StatelessWidget {
  const BuButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.kind = BuButtonKind.primary,
    this.busy = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final BuButtonKind kind;
  final bool busy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final cs = Theme.of(context).colorScheme;
    final (bg, fg, side) = switch (kind) {
      BuButtonKind.primary => (t.pr, t.onPr, BorderSide.none),
      BuButtonKind.soft => (t.soft, t.onSoft, BorderSide.none),
      BuButtonKind.outline => (Colors.transparent, t.ink, BorderSide(color: t.bd, width: 1.2)),
      BuButtonKind.text => (Colors.transparent, t.pr, BorderSide.none),
      BuButtonKind.danger => (cs.error, cs.onError, BorderSide.none),
    };
    final h = compact ? 36.0 : 54.0;
    final tx = Theme.of(context).textTheme;
    final content = busy
        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: compact ? 13.5 : 18, color: fg), const SizedBox(width: 6)],
              Flexible(
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: (compact ? tx.labelMedium! : tx.titleMedium!).copyWith(color: fg, fontWeight: FontWeight.w700)),
              ),
            ],
          );
    final shape = compact
        ? StadiumBorder(side: side)
        : RoundedRectangleBorder(borderRadius: BuRadius.bMd, side: side);
    final disabled = onPressed == null;
    final tap = busy || disabled
        ? null
        : () {
            buHaptic(BuHaptic.selection);
            onPressed!();
          };
    final btn = Material(
      color: disabled ? bg.withValues(alpha: .5) : bg,
      shape: shape,
      child: InkWell(
        customBorder: compact ? const StadiumBorder() : const RoundedRectangleBorder(borderRadius: BuRadius.bMd),
        onTap: tap,
        // Container(alignment) sınırlı yükseklikte (altta gezinme çubuğu, kaydırılabilir olmayan gövde)
        // tüm yüksekliği kaplar: ortalamayı heightFactor:1 ile yapıp yüksekliği içeriğe bağlıyoruz.
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: h),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 20, vertical: compact ? 0 : 6),
            child: Center(widthFactor: compact ? 1 : null, heightFactor: 1, child: content),
          ),
        ),
      ),
    );
    final pressable = BuPressable(scale: .98, enabled: tap != null, child: btn);
    Widget sem(Widget c) => Semantics(button: true, enabled: !disabled && !busy, label: busy ? label : null, child: c);
    if (!compact) return SizedBox(width: double.infinity, child: sem(pressable));
    // Görsel hap 36 dp kalır; dokunma hedefi 48 dp (kenar boşlukları da basılabilir, anlamsal ikinci düğme yok).
    return sem(
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: ExcludeSemantics(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: tap)),
            ),
            pressable,
          ],
        ),
      ),
    );
  }
}

/// Segment kontrolü (Keşfet | Kulüplerim, Sistem | Açık | Koyu). Seçili parça yumuşakça kayar.
class BuSegmented extends StatelessWidget {
  const BuSegmented({super.key, required this.items, required this.index, required this.onChanged});

  final List<String> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final n = items.length;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Koyu temada seçili parça zeminden AÇIK olsun (sf, sf2'den koyu kalıp seçimi gizliyordu).
    final thumb = dark ? Color.alphaBlend(t.ink.withValues(alpha: .16), t.sf2) : t.sf;
    final x = n < 2 ? 0.0 : -1 + 2 * index.clamp(0, n - 1) / (n - 1);
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(26)),
      child: Stack(
        children: [
          if (n > 0)
            Positioned.fill(
              child: AnimatedAlign(
                duration: BuMotion.of(context, BuMotion.medium),
                curve: BuMotion.emphasized,
                alignment: AlignmentDirectional(x, 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: thumb,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: dark ? null : [BoxShadow(color: t.shadow.withValues(alpha: .12), blurRadius: 3, offset: const Offset(0, 1))],
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (i != index) buHaptic(BuHaptic.selection);
                        onChanged(i);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        // Tek satır; dar/büyük yazıda küçülür (kelime ortadan bölünmez).
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: AnimatedDefaultTextStyle(
                            duration: BuMotion.of(context, BuMotion.short),
                            style: BuType.bodyStrong.copyWith(color: i == index ? t.ink : t.mut),
                            child: Text(items[i], maxLines: 1, textAlign: TextAlign.center),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Yuvarlak arama kutusu. [readOnly]+[onTap]: ana sayfadaki "arama sayfasına git" kutusu.
/// Odakta marka halkası belirir; yazı varsa sağda "temizle" düğmesi çıkar.
class BuSearchField extends StatefulWidget {
  const BuSearchField({
    super.key,
    this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.autofocus = false,
  });

  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool autofocus;

  @override
  State<BuSearchField> createState() => _BuSearchFieldState();
}

class _BuSearchFieldState extends State<BuSearchField> {
  final _focus = FocusNode();
  TextEditingController? _own;

  TextEditingController get _c => widget.controller ?? (_own ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final focused = _focus.hasFocus && !widget.readOnly;
    return AnimatedContainer(
      duration: BuMotion.of(context, BuMotion.short),
      height: 50,
      padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: focused ? t.pr : t.bd, width: focused ? 2 : 1),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 18, color: focused ? t.pr : t.mut),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _c,
              focusNode: _focus,
              readOnly: widget.readOnly,
              autofocus: widget.autofocus,
              onTap: widget.onTap,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              textInputAction: TextInputAction.search,
              style: BuType.body.copyWith(color: t.ink),
              decoration: InputDecoration(
                hintText: widget.hint ?? context.l10n.commonSearchHint,
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (!widget.readOnly)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _c,
              builder: (context, v, _) => v.text.isEmpty
                  ? const SizedBox(width: 12)
                  : IconButton(
                      tooltip: context.l10n.searchClear,
                      onPressed: () {
                        _c.clear();
                        widget.onChanged?.call('');
                      },
                      icon: Icon(LucideIcons.circleX, size: 18, color: t.mut),
                    ),
            ),
        ],
      ),
    );
  }
}

/// Bölüm başlığı + sağda "Tümü" gibi bağlantı.
class BuSectionTitle extends StatelessWidget {
  const BuSectionTitle(this.title, {super.key, this.action, this.onAction, this.padding});

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: padding ?? const EdgeInsetsDirectional.fromSTEB(20, 22, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Semantics(header: true, child: Text(title, style: BuType.heading.copyWith(color: t.ink))),
          ),
          if (action != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  widthFactor: 1,
                  child: Text(action!, style: BuType.label.copyWith(color: t.pr)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kırmızı gradyanlı büyük kart (hero). Süs daireleri tasarımdakiyle aynı; RTL'de aynalanır.
class BuHeroCard extends StatelessWidget {
  const BuHeroCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.radius = 26});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          decoration: BoxDecoration(gradient: t.hero),
          child: Stack(
            children: [
              PositionedDirectional(
                end: -40,
                top: -50,
                child: Container(
                    width: 170, height: 170, decoration: BoxDecoration(color: t.onMedia.withValues(alpha: .14), shape: BoxShape.circle)),
              ),
              PositionedDirectional(
                end: 46,
                bottom: -60,
                child: Container(
                    width: 120, height: 120, decoration: BoxDecoration(color: t.onMedia.withValues(alpha: .10), shape: BoxShape.circle)),
              ),
              Padding(padding: padding, child: DefaultTextStyle.merge(style: TextStyle(color: t.onMedia), child: child)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ayarlar/Profil'deki gruplanmış satır listesi için satır. Simge yumuşak zeminli karoda durur.
class BuMenuRow extends StatelessWidget {
  const BuMenuRow({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.danger = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final cs = Theme.of(context).colorScheme;
    final c = danger ? t.danger : t.ink;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: danger ? cs.errorContainer : t.soft, borderRadius: BuRadius.bSm),
                child: Icon(icon, size: 18, color: danger ? t.danger : t.pr),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Text(label,
                    maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis,
                    style: BuType.bodyStrong.copyWith(color: c))),
            if (trailing != null) trailing!,
            // Ok alanı sabit: ok her satırda aynı konumda.
            const SizedBox(width: 8),
            SizedBox(
              width: 16,
              child: (showChevron && !danger)
                  ? ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 16, color: t.mut))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Satırları ince çizgiyle ayıran kart grubu. [dividerIndent]: çizginin başlangıç boşluğu
/// (simgeli satırlarda 64 verirseniz çizgi metinle hizalanır).
class BuGroup extends StatelessWidget {
  const BuGroup({super.key, required this.children, this.dividerIndent = 0});

  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return BuCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: dividerIndent, color: t.bd),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Tema renkli, tasarımdaki gibi büyük "BÜ" yer tutucusu yerine kullanılan marka işareti.
class BuMark extends StatelessWidget {
  const BuMark({super.key, this.height = 52});

  final double height;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/branding/mark_white.svg', height: height, width: height, semanticsLabel: 'BÜ Kampüs');
}

/// Kaydırılabilir sayfa gövdesi altına yüzen gezinme payı (88 px) bırakmak için.
const double kNavInset = 100;

/// Kırmızı hero rengi (tema bağımsız logo vb. için).
const Color kBrandRed = BuColors.red600;

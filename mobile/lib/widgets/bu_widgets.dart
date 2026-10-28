import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';
import '../core/locale_controller.dart';
import '../core/theme.dart';
import '../core/typography.dart';

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
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 0),
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
                      final style = BuType.display.copyWith(letterSpacing: -.4, color: t.ink);
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
    final child = Semantics(
      button: true,
      enabled: onTap != null,
      label: tooltip,
      child: Material(
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
    ));
    // Etiket Semantics'te verilir; Tooltip yalnız görsel ipucu (çift okunmasın).
    return tooltip == null ? child : Tooltip(message: tooltip!, excludeFromSemantics: true, child: child);
  }
}

/// Çizgili beyaz kart. [onTap] verilirse dokunma efekti olur.
class BuCard extends StatelessWidget {
  const BuCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.color,
    this.radius = 20,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: border ? BorderSide(color: t.bd) : BorderSide.none,
    );
    return Material(
      color: color ?? t.sf,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// Yatay filtre çipi (seçili: koyu zemin).
class BuChip extends StatelessWidget {
  const BuChip({super.key, required this.label, this.selected = false, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    // Görünür çip 34 dp; dokunma alanı 44 dp (dış GestureDetector boşluğu da yakalar).
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: Material(
              color: selected ? t.ink : t.sf,
              shape: StadiumBorder(side: BorderSide(color: selected ? t.ink : t.bd)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                excludeFromSemantics: true,
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  // Çip yüksekliği sabit satır alanına sığsın: yazı ölçeği 1.5 ile sınırlı.
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.5,
                    child: Text(label, style: BuType.label.copyWith(color: selected ? t.bg : t.mut)),
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

/// Baş harfli ya da görselli avatar. [square] true: yuvarlatılmış kare (kulüp/grup).
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
  });

  final String? name;
  final String? url;

  /// Yetkili uçlardan (`/api/...`) gelen görseller için istek başlıkları (genelde Bearer).
  final Map<String, String>? headers;
  final double size;
  final bool square;
  final bool dark; // eski parametre; varsayılan görsel temadan bağımsızdır

  /// Grup/kulüp/etkinlik avatarı: fotoğraf yoksa varsayılan grup görseli.
  final bool group;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(square ? size * .34 : size);
    final fallback = Image.asset(
      group ? 'assets/branding/default_group.png' : 'assets/branding/default_avatar.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
    final full = fileUrl(url);
    // Küçük avatar için tam çözünürlüklü görseli belleğe açma.
    final px = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return ClipRRect(
      borderRadius: radius,
      child: full == null
          ? fallback
          : Image.network(full,
              headers: headers,
              width: size,
              height: size,
              cacheWidth: px,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback),
    );
  }
}

enum BuButtonKind { primary, outline, soft }

/// Hap biçimli (compact) ya da tam genişlikli düğme.
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
    final (bg, fg, side) = switch (kind) {
      BuButtonKind.primary => (t.pr, t.onPr, BorderSide.none),
      BuButtonKind.soft => (t.soft, t.onSoft, BorderSide.none),
      BuButtonKind.outline => (Colors.transparent, t.ink, BorderSide(color: t.bd)),
    };
    final h = compact ? 36.0 : 54.0;
    final content = busy
        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: compact ? 13.5 : 18, color: fg), const SizedBox(width: 6)],
              Flexible(
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: (compact ? BuType.label : BuType.heading).copyWith(color: fg)),
              ),
            ],
          );
    final btn = Material(
      color: onPressed == null ? bg.withValues(alpha: .5) : bg,
      shape: compact
          ? StadiumBorder(side: side)
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: side),
      child: InkWell(
        customBorder: compact ? const StadiumBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: busy ? null : onPressed,
        // Container(alignment) sınırlı yükseklikte (altta gezinme çubuğu, kaydırılabilir olmayan gövde)
        // tüm yüksekliği kaplar: ortalamayı heightFactor:1 ile yapıp yüksekliği içeriğe bağlıyoruz.
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: h),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 20, vertical: compact ? 0 : 6),
            child: Center(heightFactor: 1, child: content),
          ),
        ),
      ),
    );
    return compact ? btn : SizedBox(width: double.infinity, child: btn);
  }
}

/// Segment kontrolü (Keşfet | Kulüplerim, Sistem | Açık | Koyu).
class BuSegmented extends StatelessWidget {
  const BuSegmented({super.key, required this.items, required this.index, required this.onChanged});

  final List<String> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(26)),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.center,
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    // Koyu temada seçili parça zeminden AÇIK olsun (sf, sf2'den koyu kalıp seçimi gizliyordu).
                    color: i == index
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? Color.alphaBlend(t.ink.withValues(alpha: .16), t.sf2)
                            : t.sf)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: i == index
                        ? [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 3, offset: const Offset(0, 1))]
                        : null,
                  ),
                  // Tek satır; dar/büyük yazıda küçülür (kelime ortadan bölünmez).
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(items[i],
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: BuType.bodyStrong.copyWith(color: i == index ? t.ink : t.mut)),
                  ),
                ),
              )),
            ),
        ],
      ),
    );
  }
}

/// Yuvarlak arama kutusu. [readOnly]+[onTap]: ana sayfadaki "arama sayfasına git" kutusu.
class BuSearchField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: t.bd),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 18, color: t.mut),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              autofocus: autofocus,
              onTap: onTap,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: BuType.body.copyWith(color: t.ink),
              decoration: InputDecoration(
                hintText: hint ?? context.l10n.commonSearchHint,
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
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
      padding: padding ?? const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: BuType.heading.copyWith(color: t.ink))),
          if (action != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
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

/// Kırmızı gradyanlı büyük kart (hero). Süs daireleri tasarımdakiyle aynı.
class BuHeroCard extends StatelessWidget {
  const BuHeroCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.radius = 26});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        decoration: BoxDecoration(gradient: t.hero),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -50,
              child: Container(
                  width: 170, height: 170, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), shape: BoxShape.circle)),
            ),
            Positioned(
              right: 46,
              bottom: -60,
              child: Container(
                  width: 120, height: 120, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .10), shape: BoxShape.circle)),
            ),
            Padding(padding: padding, child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: child)),
          ],
        ),
      ),
    );
  }
}

/// Ayarlar/Profil'deki gruplanmış satır listesi için satır.
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
    final c = danger ? t.danger : t.ink;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: danger ? t.danger : t.pr),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: BuType.bodyStrong.copyWith(color: c))),
            if (trailing != null) trailing!,
            if (showChevron && !danger) Icon(buDirIcon(context, LucideIcons.chevronRight), size: 16, color: t.mut),
          ],
        ),
      ),
    );
  }
}

/// Satırları ince çizgiyle ayıran kart grubu.
class BuGroup extends StatelessWidget {
  const BuGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return BuCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: t.bd),
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

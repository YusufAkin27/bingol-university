import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';

/// Etkinlik sayfaları (detay, form, istekler, ayarlar, yoklama) için ortak bileşenler.
/// Tasarım: Et1-Et7 panoları. Renkler yalnız `context.bu`; ton renkleri sabit.

/// Alt eylem çubuğu: kremden saydama geçişli zemin üstünde sabit düğmeler.
class Et2BottomBar extends StatelessWidget {
  const Et2BottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.bg.withValues(alpha: 0), t.bg],
          stops: const [0, .28],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 12), child: child),
      ),
    );
  }
}

/// İki (ya da daha çok) seçenekli segment: "Herkes katılabilir | İstek ile".
class Et2Segment<T> extends StatelessWidget {
  const Et2Segment({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.bd, width: 1.5),
      ),
      child: Row(children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              button: true,
              selected: options[i].$1 == value,
              label: options[i].$2,
              excludeSemantics: true,
              onTap: enabled ? () => onChanged(options[i].$1) : null,
              child: Material(
                color: options[i].$1 == value ? t.pr : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: enabled ? () => onChanged(options[i].$1) : null,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Text(
                      options[i].$2,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: BuType.label.copyWith(
                        fontWeight: FontWeight.w700,
                        color: options[i].$1 == value ? t.onPr : t.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Açma/kapama anahtarı (52x32). [label] erişilebilirlik adıdır.
class Et2Toggle extends StatelessWidget {
  const Et2Toggle({super.key, required this.value, required this.onChanged, required this.label});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final off = dark ? const Color(0xFF5A6075) : const Color(0xFF8A8F9E);
    return Semantics(
      toggled: value,
      label: label,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: SizedBox(
          width: 56,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 52,
              height: 32,
              padding: const EdgeInsets.all(3),
              alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
              decoration: BoxDecoration(color: value ? t.pr : off, borderRadius: BorderRadius.circular(999)),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 4, offset: const Offset(0, 2))],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Yatay ilerleme çubuğu (kontenjan / yoklama / yenilenme sayacı).
class Et2Progress extends StatelessWidget {
  const Et2Progress({super.key, required this.fraction, this.height = 8});

  final double fraction;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final f = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    return ExcludeSemantics(
      child: Container(
        height: height,
        decoration: BoxDecoration(color: t.bd, borderRadius: BorderRadius.circular(999)),
        clipBehavior: Clip.antiAlias,
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: f,
          child: DecoratedBox(decoration: BoxDecoration(color: t.pr, borderRadius: BorderRadius.circular(999))),
        ),
      ),
    );
  }
}

/// Yumuşak vurgulu uyarı/bilgi bandı (simge + metin).
class Et2Banner extends StatelessWidget {
  const Et2Banner({super.key, required this.icon, required this.text, this.title});

  final IconData icon;
  final String text;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(icon, size: 20, color: t.pr),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (title != null) Text(title!, style: BuType.label.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
              Text(text, style: BuType.caption.copyWith(height: 1.35, color: t.ink)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Satır başı simge kutusu (36x36, 12 köşe, yumuşak zemin).
class Et2IconBox extends StatelessWidget {
  const Et2IconBox(this.icon, {super.key, this.size = 36});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 20, color: t.pr),
      ),
    );
  }
}

/// Bilgi satırı: simge kutusu + başlık + alt metin. Satırlar arasında çizgi için [top].
class Et2InfoRow extends StatelessWidget {
  const Et2InfoRow({super.key, required this.icon, required this.title, this.sub, this.top = false});

  final IconData icon;
  final String title;
  final String? sub;
  final bool top;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(border: top ? Border(top: BorderSide(color: t.bd)) : null),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Et2IconBox(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: BuType.bodyStrong.copyWith(color: t.ink)),
            if (sub != null) Text(sub!, style: BuType.caption.copyWith(color: t.mut)),
          ]),
        ),
      ]),
    );
  }
}

/// Yumuşak zeminli küçük etiket hapı ("Herkes katılabilir").
class Et2Tag extends StatelessWidget {
  const Et2Tag(this.label, {super.key, this.dark = false, this.muted = false});

  final String label;

  /// Koyu dolgulu (Onaylandı).
  final bool dark;

  /// Sönük (Reddedildi).
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final (bg, fg) = dark
        ? (t.ink, t.bg)
        : muted
            ? (t.sf2, t.mut)
            : (t.soft, t.pr);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: BuType.caption.copyWith(fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

/// Bölüm başlığı: küçük, büyük harfli olmayan, soluk.
class Et2Label extends StatelessWidget {
  const Et2Label(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 2, top: 16, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(text, style: BuType.caption.copyWith(fontWeight: FontWeight.w700, color: t.mut)),
      ),
    );
  }
}

/// Form alanı etiketi (13 px, kalın).
class Et2FieldLabel extends StatelessWidget {
  const Et2FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 2, bottom: 6),
      child: Text(text, style: BuType.label.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
    );
  }
}

/// Yönetim listesi satırı: simge kutusu + başlık + alt metin + rozet + ok.
class Et2NavRow extends StatelessWidget {
  const Et2NavRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.sub,
    this.badge,
    this.top = false,
  });

  final IconData icon;
  final String title;
  final String? sub;
  final String? badge;
  final VoidCallback onTap;
  final bool top;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: [title, if (sub != null) sub!].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          decoration: BoxDecoration(border: top ? Border(top: BorderSide(color: t.bd)) : null),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Et2IconBox(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: BuType.bodyStrong.copyWith(color: t.ink)),
                if (sub != null) Text(sub!, style: BuType.caption.copyWith(color: t.mut)),
              ]),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 24),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: t.pr, borderRadius: BorderRadius.circular(999)),
                child: Text(badge!,
                    textAlign: TextAlign.center,
                    style: BuType.caption.copyWith(fontWeight: FontWeight.w700, color: t.onPr)),
              ),
            ],
            const SizedBox(width: 6),
            Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? LucideIcons.chevronLeft
                    : LucideIcons.chevronRight,
                size: 18,
                color: t.mut),
          ]),
        ),
      ),
    );
  }
}

/// Alt çubuktaki ikincil düğme: 48 yükseklik, beyaz, 1.5 çizgili.
class Et2GhostButton extends StatelessWidget {
  const Et2GhostButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.busy = false,
    this.locked = false,
    this.danger = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  final bool locked;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final fg = locked ? t.mut : (danger ? t.danger : t.ink);
    return Semantics(
      button: true,
      enabled: onPressed != null && !locked,
      label: label,
      excludeSemantics: true,
      onTap: locked ? null : onPressed,
      child: Material(
        color: locked ? t.sf2 : t.sf,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: locked || busy ? null : onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: danger ? t.danger : t.bd, width: 1.5),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              if (busy)
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              else if (icon != null)
                Icon(icon, size: 20, color: locked ? t.mut : (danger ? t.danger : t.pr)),
              if (busy || icon != null) const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: BuType.label.copyWith(fontWeight: FontWeight.w700, color: fg)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// "KAS 13" biçimli tarih kutusu (kapak üstü, beyaz).
class Et2DateChip extends StatelessWidget {
  const Et2DateChip({super.key, required this.month, required this.day});

  final String month;
  final String day;

  @override
  Widget build(BuildContext context) {
    const fg = Color(0xFF8E1B13);
    return ExcludeSemantics(
      child: Container(
        width: 56,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color(0xFF171E33).withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 8), spreadRadius: -8)],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(month, maxLines: 1, style: BuType.micro.copyWith(color: fg, fontWeight: FontWeight.w700)),
            Text(day, maxLines: 1, style: BuType.title.copyWith(color: fg, height: 1.1, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

/// Kapak üstündeki yuvarlak beyaz düğme (geri / şikâyet / menü).
class Et2CircleButton extends StatelessWidget {
  const Et2CircleButton({super.key, required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: t.sf,
            shape: BoxShape.circle,
            border: Border.all(color: t.bd),
            boxShadow: [BoxShadow(color: const Color(0xFF171E33).withValues(alpha: .3), blurRadius: 16, offset: const Offset(0, 6), spreadRadius: -10)],
          ),
          child: Icon(icon, size: 20, color: t.ink),
        ),
      ),
    );
  }
}

/// "Ad Soyad" -> yoksa boş: görünen ad (yedek).
String et2Name(Object? v) {
  final s = '${v ?? ''}'.trim();
  return s;
}

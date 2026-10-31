import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

/// Etkinlik sayfaları (detay, form, istekler, ayarlar, yoklama) için ortak bileşenler.
/// Material 3 + marka: renkler yalnız `context.bu`, yazı `textTheme`; dış imzalar tüketen paketler (P15) için sabittir.

/// Alt eylem çubuğu: sayfa zemininde, üstte ince çizgi ve yumuşak gölgeyle ayrılan sabit düğme alanı.
class Et2BottomBar extends StatelessWidget {
  const Et2BottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(top: BorderSide(color: t.bd.withValues(alpha: .7))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 12), child: child),
      ),
    );
  }
}

/// İki (ya da daha çok) seçenekli segment: "Herkes katılabilir | İstek ile". Seçili parça kayarak yer değiştirir
/// (marka tonu), yazı seçiliyken `onSoft`.
class Et2Segment<T> extends StatelessWidget {
  const Et2Segment({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    this.icons,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final bool enabled;

  /// Seçeneklerle aynı sırada isteğe bağlı simgeler (seçiliyken marka renginde).
  final List<IconData>? icons;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final n = options.length;
    final sel = options.indexWhere((o) => o.$1 == value);
    final x = n < 2 || sel < 0 ? -1.0 : -1 + 2 * sel / (n - 1);
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.sf2,
        borderRadius: BorderRadius.circular(BuRadius.md),
      ),
      child: Stack(children: [
        if (n > 0 && sel >= 0)
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
                    color: t.sf,
                    borderRadius: BorderRadius.circular(BuRadius.md - 4),
                    boxShadow: [BoxShadow(color: t.shadow.withValues(alpha: .12), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                ),
              ),
            ),
          ),
        Row(children: [
          for (var i = 0; i < n; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == sel,
                enabled: enabled,
                label: options[i].$2,
                excludeSemantics: true,
                onTap: enabled ? () => onChanged(options[i].$1) : null,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: enabled
                      ? () {
                          if (i != sel) buHaptic(BuHaptic.selection);
                          onChanged(options[i].$1);
                        }
                      : null,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (icons != null && i < icons!.length) ...[
                        ExcludeSemantics(child: Icon(icons![i], size: 16, color: i == sel ? t.pr : t.mut)),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: AnimatedDefaultTextStyle(
                          duration: BuMotion.of(context, BuMotion.short),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tx.labelLarge!.copyWith(
                            fontWeight: FontWeight.w700,
                            color: i == sel ? t.ink : (enabled ? t.mut : t.mut.withValues(alpha: .6)),
                          ),
                          child: Text(options[i].$2, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

/// Açma/kapama anahtarı (Material 3 Switch, 56x48 dokunma alanı). [label] erişilebilirlik adıdır.
class Et2Toggle extends StatelessWidget {
  const Et2Toggle({super.key, required this.value, required this.onChanged, required this.label, this.thumbCheck = false});

  /// true: açıkken başparmakta küçük onay işareti (yoklama listesi).
  final bool thumbCheck;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    void flip(bool v) {
      buHaptic(BuHaptic.selection);
      onChanged?.call(v);
    }

    return Semantics(
      toggled: value,
      label: label,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => flip(!value),
      excludeSemantics: true,
      child: SizedBox(
        width: 56,
        height: 48,
        child: Center(
          child: Switch(
            value: value,
            onChanged: onChanged == null ? null : flip,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            thumbIcon: thumbCheck
                ? WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? Icon(LucideIcons.check, color: context.bu.pr) : null)
                : null,
          ),
        ),
      ),
    );
  }
}

/// Yatay ilerleme çubuğu (kontenjan / yoklama / yenilenme sayacı). Değer değişince yumuşakça dolar.
/// [color] verilmezse marka rengi; [duration] sayaçlarda doğrusal akış için uzatılır.
class Et2Progress extends StatelessWidget {
  const Et2Progress({super.key, required this.fraction, this.height = 8, this.color, this.duration});

  final double fraction;
  final double height;
  final Color? color;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final f = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    final fill = color ?? t.pr;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: f),
          duration: BuMotion.of(context, duration ?? BuMotion.long),
          curve: duration == null ? BuMotion.emphasizedDecelerate : Curves.linear,
          builder: (context, v, _) => ClipRRect(
            borderRadius: BorderRadius.circular(BuRadius.pill),
            child: SizedBox(
              height: height,
              child: Stack(children: [
                Positioned.fill(child: ColoredBox(color: t.bd)),
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: v,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(BuRadius.pill)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Yumuşak vurgulu uyarı/bilgi bandı (simge + metin). [warn] true: uyarı tonu (sarı); varsayılan marka tonu.
class Et2Banner extends StatelessWidget {
  const Et2Banner({super.key, required this.icon, required this.text, this.title, this.warn = false});

  final IconData icon;
  final String text;
  final String? title;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final bg = warn ? t.warnSoft : t.soft;
    final fg = warn ? t.onWarnSoft : t.onSoft;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 14, 12),
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(BuRadius.md)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ExcludeSemantics(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: fg.withValues(alpha: .12), shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: fg),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                if (title != null) Text(title!, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: fg)),
                Text(text, style: tx.bodySmall!.copyWith(height: 1.4, color: fg)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Satır başı simge kutusu (varsayılan 36x36, 12 köşe). [tint] verilirse kategori rengi, yoksa marka tonu.
class Et2IconBox extends StatelessWidget {
  const Et2IconBox(this.icon, {super.key, this.size = 36, this.tint});

  final IconData icon;
  final double size;
  final BuTint? tint;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: tint?.bg ?? t.soft, borderRadius: BorderRadius.circular(BuRadius.xs + 4)),
        child: Icon(icon, size: size * .55, color: tint?.fg ?? t.pr),
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
    final tx = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(border: top ? Border(top: BorderSide(color: t.bd)) : null),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Et2IconBox(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: tx.titleSmall!.copyWith(color: t.ink)),
            if (sub != null) Text(sub!, style: tx.bodySmall!.copyWith(color: t.mut)),
          ]),
        ),
      ]),
    );
  }
}

/// Küçük etiket hapı ("Herkes katılabilir"). [dark] = olumlu/onaylı (yeşil ton), [muted] = sönük (reddedildi),
/// varsayılan marka tonu. [icon] verilirse başa küçük simge.
class Et2Tag extends StatelessWidget {
  const Et2Tag(this.label, {super.key, this.dark = false, this.muted = false, this.icon, this.danger = false});

  final String label;

  /// Olumsuz (Reddedildi: kırmızı ton).
  final bool danger;

  /// Olumlu (Onaylandı).
  final bool dark;

  /// Sönük (Reddedildi).
  final bool muted;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final (bg, fg) = dark
        ? (t.okSoft, t.ok)
        : danger
            ? (t.danger.withValues(alpha: .12), t.danger)
            : muted
            ? (t.sf2, t.mut)
            : (t.soft, t.onSoft);
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(BuRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[ExcludeSemantics(child: Icon(icon, size: 14, color: fg)), const SizedBox(width: 6)],
        Flexible(
          child: Text(label,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: fg)),
        ),
      ]),
    );
  }
}

/// Bölüm başlığı: küçük, soluk, ekran okuyucuda başlık.
class Et2Label extends StatelessWidget {
  const Et2Label(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 2, top: 20, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(text, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.mut)),
      ),
    );
  }
}

/// Form alanı etiketi (kalın).
class Et2FieldLabel extends StatelessWidget {
  const Et2FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 2, bottom: 6),
      child: Text(text, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
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
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: [title, if (sub != null) sub!].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            decoration: BoxDecoration(border: top ? Border(top: BorderSide(color: t.bd)) : null),
            padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
            child: Row(children: [
              Et2IconBox(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: tx.titleSmall!.copyWith(color: t.ink)),
                  if (sub != null) Text(sub!, style: tx.bodySmall!.copyWith(color: t.mut)),
                ]),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(minWidth: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: t.pr, borderRadius: BorderRadius.circular(BuRadius.pill)),
                  child: Text(badge!,
                      textAlign: TextAlign.center, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.onPr)),
                ),
              ],
              const SizedBox(width: 6),
              Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut),
            ]),
          ),
        ),
      ),
    );
  }
}

/// İkincil düğme (outline): 48 dp, basınca hafif küçülür. [danger] kırmızı çerçeve/yazı, [locked] kilitli (soluk).
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
    final tx = Theme.of(context).textTheme;
    final fg = locked ? t.mut : (danger ? t.danger : t.ink);
    final enabled = onPressed != null && !locked && !busy;
    final radius = BorderRadius.circular(BuRadius.md);
    return Semantics(
      button: true,
      enabled: onPressed != null && !locked,
      label: label,
      excludeSemantics: true,
      onTap: locked ? null : onPressed,
      child: BuPressable(
        scale: .98,
        enabled: enabled,
        child: Material(
          color: locked ? t.sf2 : (danger ? t.danger.withValues(alpha: .06) : t.sf),
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: danger ? t.danger.withValues(alpha: .55) : t.bd, width: 1.2),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: !enabled
                ? null
                : () {
                    buHaptic(danger ? BuHaptic.light : BuHaptic.selection);
                    onPressed!();
                  },
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: fg)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Takvim yaprağı biçimli tarih kutusu (kapak üstü): üstte marka şeridinde ay, altta gün.
class Et2DateChip extends StatelessWidget {
  const Et2DateChip({super.key, required this.month, required this.day});

  final String month;
  final String day;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return ExcludeSemantics(
      child: Container(
        width: 56,
        height: 64,
        decoration: BoxDecoration(
          color: t.sf,
          borderRadius: BorderRadius.circular(BuRadius.md),
          boxShadow: [BoxShadow(color: t.shadow.withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 8), spreadRadius: -8)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            height: 22,
            width: double.infinity,
            color: t.pr,
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(month, maxLines: 1, style: tx.labelSmall!.copyWith(color: t.onPr, fontWeight: FontWeight.w800, letterSpacing: .6)),
            ),
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(day, maxLines: 1, style: tx.titleLarge!.copyWith(color: t.ink, height: 1.1, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Kapak üstündeki yuvarlak düğme (geri / şikâyet / menü): 48 dp hedef, 44 dp daire.
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
      child: BuPressable(
        scale: .92,
        haptic: BuHaptic.selection,
        onTap: onTap,
        enabled: onTap != null,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: t.sf,
                shape: BoxShape.circle,
                border: Border.all(color: t.bd),
                boxShadow: [BoxShadow(color: t.shadow.withValues(alpha: .3), blurRadius: 16, offset: const Offset(0, 6), spreadRadius: -10)],
              ),
              child: Icon(icon, size: 20, color: t.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sayfa başında hangi etkinlik üzerinde çalışıldığını gösteren şerit: simge kutusu + başlık + tarih · yer.
/// [event] etkinlik JSON'u (`title`, `startsAt`, `location`).
class Et2EventStrip extends StatelessWidget {
  const Et2EventStrip({super.key, required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final starts = DateTime.tryParse('${event['startsAt']}')?.toLocal();
    final loc = event['location'] as String?;
    final sub = [
      if (starts != null) et2DateTimeShort(starts),
      if (loc != null && loc.isNotEmpty) loc,
    ].join(' · ');
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 14, 10),
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(BuRadius.md),
        border: Border.all(color: t.bd),
      ),
      child: Row(children: [
        const Et2IconBox(LucideIcons.calendarDays, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('${event['title'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(color: t.ink)),
            if (sub.isNotEmpty)
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
          ]),
        ),
      ]),
    );
  }
}

/// "29.10 · 19:30" biçimi.
String et2DateTimeShort(DateTime d) =>
    '${d.day}.${d.month.toString().padLeft(2, '0')} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// "Ad Soyad" -> yoksa boş: görünen ad (yedek).
String et2Name(Object? v) {
  final s = '${v ?? ''}'.trim();
  return s;
}


/// Yuvarlatılmış kare kişi avatarı: [url] varsa fotoğraf, yoksa varsayılan profil görseli (N4: baş harf kalktı).
class Et2Initials extends StatelessWidget {
  const Et2Initials({super.key, required this.name, this.size = 48, this.seed = 0, this.url, this.tint, this.radius});

  final String name;
  final double size;
  final int seed;
  final String? url;
  final BuTint? tint;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? size * .33;
    // Fotoğraf yoksa/yüklenemezse varsayılan profil görseli (baş harf yok); [tint]/[seed] eski imza için kalır.
    return ClipRRect(borderRadius: BorderRadius.circular(r), child: BuAvatar(name: name, url: url, size: size, square: true));
  }
}

/// Kırmızı yumuşak hata satırı: simge + metin (+ alt metin) + isteğe bağlı "Yeniden dene" düğmesi.
class Et2ErrorRow extends StatelessWidget {
  const Et2ErrorRow({super.key, required this.title, this.sub, this.onRetry, this.retryLabel});

  final String title;
  final String? sub;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(color: t.danger.withValues(alpha: .12), borderRadius: BorderRadius.circular(BuRadius.md)),
        // Yeniden dene düğmesi satırın en çok %60'ını alır: uzun etiket/büyük yazıda başlık sütunu 0'a ezilip taşmasın.
        child: LayoutBuilder(builder: (context, box) => Row(children: [
          ExcludeSemantics(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: t.danger.withValues(alpha: .14), shape: BoxShape.circle),
              child: Icon(LucideIcons.circleAlert, size: 20, color: t.danger),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: t.danger)),
              if (sub != null)
                Text(sub!, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.danger.withValues(alpha: .85))),
            ]),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * .6),
              child: Semantics(
              button: true,
              label: retryLabel,
              excludeSemantics: true,
              onTap: onRetry,
              child: BuPressable(
                onTap: onRetry,
                haptic: BuHaptic.selection,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.pill)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.refreshCw, size: 14, color: t.danger),
                      const SizedBox(width: 6),
                      Flexible(child: Text(retryLabel ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.danger))),
                    ]),
                  ),
                ),
              ),
            ),
            ),
          ],
        ])),
      ),
    );
  }
}

/// Bölüm başlığı + isteğe bağlı sayı rozeti ("Bekleyen istekler  3").
class Et2SectionTitle extends StatelessWidget {
  const Et2SectionTitle(this.title, {super.key, this.count, this.soft = true});

  final String title;
  final int? count;

  /// true: kırmızı yumuşak rozet; false: sönük gri sayı.
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, top: 22, bottom: 10),
      child: Semantics(
        header: true,
        child: Row(children: [
          Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink))),
          if (count != null) ...[
            const SizedBox(width: 8),
            if (soft)
              Container(
                constraints: const BoxConstraints(minWidth: 24),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(BuRadius.pill)),
                child: Text('$count', textAlign: TextAlign.center, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.onSoft)),
              )
            else
              Text('($count)', style: tx.labelLarge!.copyWith(color: t.mut)),
          ],
        ]),
      ),
    );
  }
}


/// Nötr gri dolgulu düğme (Vazgeç / geri dön): pembe tonal yerine soğuk gri zemin, koyu yazı. 48 dp.
class Et2GreyButton extends StatelessWidget {
  const Et2GreyButton({super.key, required this.label, required this.onPressed, this.icon, this.compact = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// true: içeriği kadar genişler (hap).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: BuPressable(
        onTap: onPressed,
        enabled: onPressed != null,
        haptic: BuHaptic.selection,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: t.mut.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(compact ? BuRadius.pill : BuRadius.md),
          ),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 18, color: t.ink), const SizedBox(width: 8)],
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink))),
            ],
          ),
        ),
      ),
    );
  }
}

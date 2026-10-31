import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';

/// Arama / haber / favori / kullanıcı profili ekranlarının ortak tasarım parçaları (Material 3 + marka):
/// kart, yuvarlak ikon düğmesi, görsel kutusu, tür rozeti, sekme şeridi, bakım bandı, iskelet.
/// Dış imzalar P18/P20 tarafından kullanılır: yalnız isteğe bağlı parametre eklenir.

bool icerikDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

/// Kart: yüzey rengi, ince çizgi, 20 köşe. Dokunulabilirse basınca hafifçe küçülür.
/// [shadow] kapatılırsa (uzun listeler) gölge çizilmez.
class IcerikCard extends StatelessWidget {
  const IcerikCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.radius = 20,
    this.clip = true,
    this.shadow = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool clip;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final r = BorderRadius.circular(radius);
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: r,
        border: Border.all(color: t.bd),
        boxShadow: shadow ? BuElevation.of(context, 1) : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: r,
        clipBehavior: clip ? Clip.antiAlias : Clip.none,
        child: InkWell(onTap: onTap, borderRadius: r, child: Padding(padding: padding, child: child)),
      ),
    );
    return onTap == null ? card : BuPressable(scale: .98, child: card);
  }
}

/// 44 dp yuvarlak ikon düğmesi (geri / favori / ara / diğer), 48 dp dokunma alanı.
/// [on] true: marka tonu (seçili). [overlay] true: fotoğraf üstünde yarı saydam koyu yüzey.
class IcerikIconButton extends StatelessWidget {
  const IcerikIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.on = false,
    this.toggled,
    this.shadow = false,
    this.overlay = false,
    this.plain = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool on;
  final bool? toggled;
  final bool shadow;
  final bool overlay;

  /// true: zemin ve çerçeve yok (yalnız simge, 48 dp dokunma alanı); seçili durum yalnız marka renkli simgedir.
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final Color bg;
    final Color fg;
    final Color border;
    if (overlay) {
      bg = on ? t.sf : t.scrim.withValues(alpha: .42);
      fg = on ? t.pr : t.onMedia;
      border = Colors.transparent;
    } else if (plain) {
      bg = Colors.transparent;
      fg = on ? t.pr : t.ink;
      border = Colors.transparent;
    } else {
      bg = on ? t.soft : t.sf;
      fg = on ? t.pr : t.ink;
      border = on ? t.pr.withValues(alpha: icerikDark(context) ? .5 : .28) : t.bd;
    }
    return Semantics(
      button: true,
      toggled: toggled,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: BuPressable(
              scale: .92,
              child: AnimatedContainer(
                duration: BuMotion.of(context, BuMotion.short),
                curve: BuMotion.standard,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bg,
                  border: Border.all(color: border),
                  boxShadow: shadow ? BuElevation.of(context, 2) : null,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onTap == null
                        ? null
                        : () {
                            buHaptic(BuHaptic.selection);
                            onTap!();
                          },
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: AnimatedSwitcher(
                        duration: BuMotion.of(context, BuMotion.medium),
                        switchInCurve: BuMotion.emphasizedDecelerate,
                        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
                        child: Icon(icon, key: ValueKey(icon.codePoint), size: 20, color: fg),
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

/// Görsel kutusu: ağdan yüklenir (`BuImage`, çözümleme boyutu düzene göre). Adres yoksa ya da yüklenemezse
/// [tint] (verilmişse) tonunda simge karosu gösterilir.
class IcerikThumb extends StatelessWidget {
  const IcerikThumb({
    super.key,
    required this.url,
    required this.size,
    this.radius = 16,
    this.headers,
    this.fallbackIcon = LucideIcons.image,
    this.tint,
  });

  final String? url;
  final double size;
  final double radius;
  final Map<String, String>? headers;

  /// Görsel yokken karoda gösterilen simge.
  final IconData fallbackIcon;

  /// Görsel yokken karo tonu (null: nötr yüzey).
  final BuTint? tint;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final u = url;
    if (u == null || u.isEmpty) {
      return ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: tint?.bg ?? t.sf2, borderRadius: BorderRadius.circular(radius)),
          child: Icon(fallbackIcon, size: size * .36, color: tint?.fg ?? t.mut),
        ),
      );
    }
    return BuImage(u, width: size, height: size, radius: radius, headers: headers, placeholderIcon: fallbackIcon);
  }
}

/// Tür rozeti: [tint] verilirse o ton, [soft] true ise marka tonu, aksi halde dolu kırmızı.
class IcerikBadge extends StatelessWidget {
  const IcerikBadge(this.text, {super.key, this.soft = false, this.tint});

  final String text;
  final bool soft;
  final BuTint? tint;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final bg = tint?.bg ?? (soft ? t.soft : t.pr);
    final fg = tint?.fg ?? (soft ? t.onSoft : t.onPr);
    // Genişlik içeriğe göre (Wrap/Column içinde şeritlenmez); yükseklik yazı ölçeğiyle büyür.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w700, height: 1.1, color: fg)),
    );
  }
}

/// Bölüm başlığı (büyük harf, geniş harf aralığı, soluk). Arapçada harf aralığı 0 (bağlantılı harfler bozulmasın).
TextStyle icerikSectionStyle(BuTokens t) {
  final ar = LocaleController.current?.locale.languageCode == 'ar';
  return BuType.label.copyWith(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: ar ? 0 : .6, color: t.mut);
}

/// Bakım bandı renkleri (açık/koyu): uyarı belirteçleri.
({Color bg, Color border, Color fg}) icerikWarnColors(BuildContext context) {
  final t = context.bu;
  return (bg: t.warnSoft, border: t.warn.withValues(alpha: .35), fg: t.onWarnSoft);
}

/// Alt sayfa başlığı: geri düğmesi + kalın başlık (+ isteğe bağlı sağ eylemler).
class IcerikHeader extends StatelessWidget {
  const IcerikHeader({super.key, required this.title, required this.backLabel, this.actions = const []});

  final String title;
  final String backLabel;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(20, MediaQuery.paddingOf(context).top + 8, 20, 0),
      child: Row(children: [
        IcerikIconButton(
            icon: buDirIcon(context, LucideIcons.arrowLeft),
            label: backLabel,
            shadow: true,
            onTap: () => Navigator.maybePop(context)),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge!.copyWith(color: t.ink)),
          ),
        ),
        for (final a in actions) ...[const SizedBox(width: 10), a],
      ]),
    );
  }
}

/// Sekme şeridi (M3 segmentli düğme düzeni): kayan marka tonlu gösterge; her parça 48 dp. Parçalara
/// `ValueKey('<keyPrefix><i>')` verilir (testler/kısayollar için).
class IcerikTabs extends StatelessWidget {
  const IcerikTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.icons,
    this.keyPrefix,
    this.semanticLabel,
    this.raised = false,
  });

  /// true: seçili parça beyaz yüzey + marka rengi yazı (referans 13); false: marka tonlu gösterge.
  final bool raised;
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final List<IconData>? icons;
  final String? keyPrefix;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final n = labels.length;
    final x = n < 2 ? 0.0 : -1 + 2 * index.clamp(0, n - 1) / (n - 1);
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.pill)),
        child: SizedBox(
          height: 48,
          child: Stack(children: [
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
                        color: raised ? t.sf : t.soft,
                        borderRadius: BorderRadius.circular(BuRadius.pill),
                        border: Border.all(color: raised ? t.bd : t.pr.withValues(alpha: .22)),
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
                    selected: i == index,
                    label: labels[i],
                    excludeSemantics: true,
                    onTap: () => onChanged(i),
                    child: GestureDetector(
                      key: keyPrefix == null ? null : ValueKey('$keyPrefix$i'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (i != index) buHaptic(BuHaptic.selection);
                        onChanged(i);
                      },
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              if (icons != null && i < icons!.length) ...[
                                Icon(icons![i], size: 16, color: i == index ? (raised ? t.pr : t.onSoft) : t.mut),
                                const SizedBox(width: 6),
                              ],
                              AnimatedDefaultTextStyle(
                                duration: BuMotion.of(context, BuMotion.short),
                                style: tx.labelLarge!.copyWith(
                                    fontWeight: FontWeight.w700, color: i == index ? (raised ? t.pr : t.onSoft) : t.mut),
                                child: Text(labels[i], maxLines: 1),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Bakım / bilgi bandı (haber kaynağı ulaşılamıyor vb.): uyarı tonlu, canlı bölge.
class IcerikNotice extends StatelessWidget {
  const IcerikNotice({super.key, required this.text, this.icon = LucideIcons.circleAlert});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = icerikWarnColors(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: c.bg, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 18, color: c.fg)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall!.copyWith(height: 1.4, color: c.fg))),
        ]),
      ),
    );
  }
}

/// Haber listesi iskeleti: çerçevesiz satırlar (görsel + iki satır + kısa meta), tek ticker.
class IcerikListSkeleton extends StatelessWidget {
  const IcerikListSkeleton({super.key, this.featured = true, this.count = 4, this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24)});

  final bool featured;
  final int count;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    Widget row() => const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            BuSkeleton(width: 72, height: 72, radius: BuRadius.sm),
            SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                BuSkeleton.line(),
                SizedBox(height: 8),
                BuSkeleton.line(width: 110),
                SizedBox(height: 12),
                BuSkeleton.line(width: 80, height: 10),
              ]),
            ),
          ]),
        );
    return Semantics(
      container: true,
      liveRegion: true,
      label: context.l10n.commonLoading,
      child: ExcludeSemantics(
        child: BuSkeletonScope(
          child: Padding(
            padding: padding,
            child: Column(children: [
              if (featured) ...[
                const BuSkeleton(height: 210, radius: 24),
                const SizedBox(height: 12),
              ],
              for (var i = 0; i < count; i++) ...[row(), if (i < count - 1) const SizedBox(height: 12)],
            ]),
          ),
        ),
      ),
    );
  }
}

/// "Daha fazla yükleniyor": yalnız küçük çember (sayfalama), ekran okuyucuya metin etiketiyle bildirilir.
class IcerikLoadMore extends StatelessWidget {
  const IcerikLoadMore({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Semantics(
        liveRegion: true,
        label: text,
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: t.pr))),
      ),
    );
  }
}

/// Liste hata durumu: sakin simge, tek cümle ([title]), tek eylem ("Yeniden dene"). [body] verilirse ikinci satır
/// olarak eklenir (varsayılan boş: tek cümle).
class IcerikErrorCard extends StatelessWidget {
  const IcerikErrorCard({super.key, required this.title, this.body = '', required this.retryLabel, required this.onRetry});

  final String title;
  final String body;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 40, 0, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        ExcludeSemantics(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
            child: Icon(LucideIcons.cloudOff, size: 24, color: t.mut),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(title, textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w600, color: t.ink)),
        ),
        if (body.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.45)),
        ],
        const SizedBox(height: 20),
        BuButton(label: retryLabel, kind: BuButtonKind.outline, compact: true, onPressed: onRetry),
      ]),
    );
  }
}

/// Haber görseli Hero'su: liste/kart görseli kapak fotoğrafına uçarken köşe yarıçapı [radius]'tan 0'a (geri dönüşte
/// tersi) yumuşakça geçer; uçuş sırasında keskin köşe sıçraması olmaz. Etiket her haberde benzersiz (`news-img-<id>`).
/// "Animasyonları azalt" açıkken geçişin kendisi sayfa rotası tarafından zaten kısalır.
Widget newsHero({required int id, required Widget child, double radius = 20}) {
  return Hero(
    tag: 'news-img-$id',
    flightShuttleBuilder: (flightContext, animation, direction, fromContext, toContext) {
      final from = fromContext.widget as Hero;
      final to = toContext.widget as Hero;
      final shuttle = direction == HeroFlightDirection.push ? to.child : from.child;
      return AnimatedBuilder(
        animation: animation,
        child: shuttle,
        builder: (context, c) {
          final a = animation.value.clamp(0.0, 1.0);
          // Rota animasyonu itişte 0 -> 1, dönüşte 1 -> 0 gider; iki yönde de kart köşesi 1 - a ile kapakta 0 olur.
          final r = radius * (1 - a);
          return ClipRRect(borderRadius: BorderRadius.circular(r), child: c);
        },
      );
    },
    child: child,
  );
}

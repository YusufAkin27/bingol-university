import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';

/// Yuvarlak (16) arama kutusu; dokununca arama sayfasına gider.
class HomeSearchBox extends StatelessWidget {
  const HomeSearchBox({super.key, required this.hint, required this.onTap});

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: hint,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: t.sf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: t.bd)),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Icon(LucideIcons.search, size: 18, color: t.mut),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.body.copyWith(fontSize: 14, color: t.mut)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hızlı erişim karosu tonları: tema belirteçlerinden (açık/koyu kendiliğinden).
enum HomeTone {
  red,
  green,
  blue,
  amber,
  aqua;

  /// Ad = ailenin adı (kırmızı marka, yeşil, mavi, amber, su mavisi); değerler `BuTintId` tablosundan gelir.
  BuTint tint(BuTokens t) => switch (this) {
        HomeTone.red => t.tint(BuTintId.brand),
        HomeTone.green => t.tint(BuTintId.green),
        HomeTone.blue => t.tint(BuTintId.blue),
        HomeTone.amber => t.tint(BuTintId.amber),
        HomeTone.aqua => t.tint(BuTintId.aqua),
      };
}

/// Hızlı erişim karosu: beyaz kart, tonlu ikon karosu + etiket (referans 00).
class HomeQuickTile extends StatelessWidget {
  const HomeQuickTile({super.key, required this.icon, required this.label, required this.tone, required this.onTap});

  final IconData icon;
  final String label;
  final HomeTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tn = tone.tint(t);
    // Etiket kutusu en az 30 dp; iki satırın (sıkıştırılmış 1,3x ölçekte) yüksekliğinden küçük olamaz, yoksa taşar.
    final labelStyle = Theme.of(context).textTheme.labelSmall!;
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    final labelBoxH = math.max(30.0, 2 * scaler.scale(labelStyle.fontSize ?? 11) * 1.15 + 1);
    // Sabit boyutlu kutu: çok büyük yazı ölçeğinde taşmasın.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: BuPressable(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
            decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.bd)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: tn.bg, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, size: 22, color: tn.fg),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: labelBoxH,
                child: Center(
                  // Çok sözcüklü etiket iki satıra sarar; tek sözcük asla ortadan bölünmez (küçülür).
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final w in label.split(' '))
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(w,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.labelSmall!.copyWith(fontWeight: FontWeight.w600, height: 1.15, color: t.ink)),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// "Bugünün yemeği · Öğle" kartı. [photo] verilirse fotoğraf arka plan + koyu degrade + beyaz metin;
/// yoksa kırmızı kart.
class HomeMealCard extends StatelessWidget {
  const HomeMealCard({
    super.key,
    required this.title,
    required this.time,
    required this.text,
    required this.onTap,
    this.photo,
    this.photoLabel,
  });

  final String title;
  final String time;
  final String text;
  final VoidCallback onTap;
  final Widget? photo;
  final String? photoLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final onPhoto = photo != null;
    final fg = onPhoto ? t.onMedia : t.onPr;
    final head = Row(children: [
      Expanded(
        child: Text(title,
            maxLines: 2,
            style: BuType.label.copyWith(fontSize: 12, fontWeight: onPhoto ? FontWeight.w700 : FontWeight.w600, color: fg.withValues(alpha: onPhoto ? 1 : .9))),
      ),
      const SizedBox(width: 8),
      Text(time,
          style: BuType.label.copyWith(fontSize: 12, fontWeight: onPhoto ? FontWeight.w600 : FontWeight.w400, color: fg.withValues(alpha: onPhoto ? 1 : .9))),
    ]);
    final body = Text(text,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: BuType.title.copyWith(fontSize: 18, height: 1.3, color: fg));
    final content = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(16, onPhoto ? 14 : 16, 16, onPhoto ? 14 : 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [head, SizedBox(height: onPhoto ? 6 : 8), body],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: t.pr.withValues(alpha: onPhoto ? .55 : .7), blurRadius: 26, spreadRadius: -14, offset: const Offset(0, 14))],
      ),
      child: Material(
        color: t.pr,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: t.pr)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: !onPhoto
              ? content
              : Stack(children: [
                  Positioned.fill(child: Semantics(image: true, label: photoLabel, child: photo)),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0, .4, .75, 1],
                          colors: [t.scrim.withValues(alpha: 0), t.scrim.withValues(alpha: .4), t.scrim.withValues(alpha: .8), t.scrim.withValues(alpha: .95)],
                        ),
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 176),
                    child: Align(alignment: AlignmentDirectional.bottomStart, child: content),
                  ),
                ]),
        ),
      ),
    );
  }
}

/// "Duyurular" gibi bölüm başlığı (17/800) + sağda "Tümü".
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({super.key, required this.title, required this.action, required this.onAction});

  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Row(children: [
      Expanded(
        child: Semantics(header: true, child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.title.copyWith(fontSize: 17, color: t.ink))),
      ),
      InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onAction,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Center(
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(action, style: BuType.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: t.pr)),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Duyuru satırı: küçük üst satır (tür · tarih) + kalın başlık.
class HomeAnnouncementCard extends StatelessWidget {
  const HomeAnnouncementCard({super.key, required this.meta, required this.title, required this.onTap});

  final String meta;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: BuElevation.of(context, 1)),
      child: Material(
        color: t.sf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: t.bd)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(fontSize: 12, color: t.mut)),
                ),
                const SizedBox(height: 4),
                Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: BuType.heading.copyWith(fontSize: 15, fontWeight: FontWeight.w700, height: 1.35, color: t.ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ana Sayfa yükleniyor iskeleti: marka çubuğu, selamlama, arama, vitrin kartı, hızlı erişim, haber, etkinlik.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final top = MediaQuery.paddingOf(context).top;
    Widget card({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) => Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.bd)),
          child: child,
        );
    return Semantics(
      container: true,
      liveRegion: true,
      label: context.l10n.commonLoading,
      child: ExcludeSemantics(
        child: BuSkeletonScope(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, top + 12, 20, kNavInset),
            children: [
              const Row(children: [
                BuSkeleton(width: 44, height: 44, radius: 14),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    BuSkeleton(width: 90, height: 10),
                    SizedBox(height: 8),
                    BuSkeleton(width: 170, height: 12),
                  ]),
                ),
                BuSkeleton.circle(44),
                SizedBox(width: 6),
                BuSkeleton.circle(40),
              ]),
              const SizedBox(height: 18),
              const BuSkeleton(width: 80, height: 12),
              const SizedBox(height: 8),
              const BuSkeleton(width: 190, height: 24, radius: 12),
              const SizedBox(height: 14),
              card(
                child: const Row(children: [BuSkeleton.circle(20), SizedBox(width: 12), Expanded(child: BuSkeleton(height: 12))]),
              ),
              const SizedBox(height: 18),
              const BuSkeleton(height: 270, radius: 28),
              const SizedBox(height: 22),
              const BuSkeleton(width: 100, height: 14),
              const SizedBox(height: 12),
              Row(children: [
                for (var i = 0; i < 5; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  const Expanded(child: BuSkeleton(height: 92, radius: 20)),
                ],
              ]),
              const SizedBox(height: 24),
              const Row(children: [BuSkeleton(width: 150, height: 16), Spacer(), BuSkeleton(width: 40, height: 12)]),
              const SizedBox(height: 12),
              const BuSkeleton(height: 240, radius: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ana Sayfa boş durum kartı: başlık (+ isteğe bağlı alt başlık), içeride açık zeminli kutuda simge + metin (+ düğme).
class HomeEmptyCard extends StatelessWidget {
  const HomeEmptyCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.headline,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.trailingIcon,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String headline;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return BuCard(
      radius: 20,
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Semantics(header: true, child: Text(title, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
                if (subtitle != null) Text(subtitle!, style: tx.bodySmall!.copyWith(color: t.mut)),
              ]),
            ),
            if (trailingIcon != null) ExcludeSemantics(child: Icon(trailingIcon, size: 20, color: t.mut)),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
            decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.md)),
            child: Column(children: [
              ExcludeSemantics(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: t.bd.withValues(alpha: .7), shape: BoxShape.circle),
                  child: Icon(icon, size: 26, color: t.mut),
                ),
              ),
              const SizedBox(height: 12),
              Text(headline, textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
              const SizedBox(height: 4),
              Text(body, textAlign: TextAlign.center, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.4)),
              if (actionLabel != null) ...[
                const SizedBox(height: 14),
                BuButton(label: actionLabel!, kind: BuButtonKind.soft, compact: true, icon: LucideIcons.arrowRight, onPressed: onAction),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Duyurular alanı durum kartı: "Henüz içerik yok." satırı ve (hata varsa) kırmızı "yeniden dene" satırı.
class HomeNewsStateCard extends StatelessWidget {
  const HomeNewsStateCard({super.key, required this.emptyText, this.errorText, this.retryLabel, this.onRetry});

  final String emptyText;
  final String? errorText;
  final String? retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return BuCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          ExcludeSemantics(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.sm)),
              child: Icon(LucideIcons.inbox, size: 22, color: t.mut),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(emptyText, style: tx.bodyLarge!.copyWith(color: t.mut))),
        ]),
        if (errorText != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 8),
            decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(BuRadius.md)),
            child: Row(children: [
              ExcludeSemantics(child: Icon(LucideIcons.cloudOff, size: 18, color: t.onSoft)),
              const SizedBox(width: 10),
              Expanded(child: Semantics(liveRegion: true, child: Text(errorText!, style: tx.bodyMedium!.copyWith(color: t.onSoft)))),
              const SizedBox(width: 8),
              BuButton(label: retryLabel ?? '', kind: BuButtonKind.outline, compact: true, icon: LucideIcons.refreshCw, onPressed: onRetry),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// Üst marka çubuğu (referans 00): açık kırmızı logo karosu + "BU KAMPÜS" + alt başlık; sağda zil ve profil avatarı.
class HomeBrandHeader extends StatelessWidget {
  const HomeBrandHeader({super.key, required this.bell, required this.displayName, required this.onProfile, required this.profileLabel});

  final Widget bell;
  final String? displayName;
  final VoidCallback onProfile;
  final String profileLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Row(children: [
      ExcludeSemantics(
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(BuRadius.sm), border: Border.all(color: t.pr.withValues(alpha: .25))),
          child: Icon(LucideIcons.graduationCap, size: 22, color: t.pr),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('BU KAMPÜS', maxLines: 1, style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2, color: t.pr)),
          Text(l.p03HomeBrandSub, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
        ]),
      ),
      bell,
      const SizedBox(width: 4),
      Semantics(
        button: true,
        label: profileLabel,
        excludeSemantics: true,
        onTap: onProfile,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onProfile,
          child: SizedBox(width: 48, height: 48, child: Center(child: BuAvatar(name: displayName, size: 40))),
        ),
      ),
    ]);
  }
}

/// "Günün Yemek Menüsü" vitrin kartı: kırmızı gradyan (ya da menü fotoğrafı), çeşit rozeti, saat hapı,
/// yemek adları (kalori yok), "Menü Detayı". Dokunma menü sayfasını açar.
class HomeMealHero extends StatelessWidget {
  const HomeMealHero({
    super.key,
    required this.chip,
    required this.title,
    required this.time,
    required this.dishes,
    required this.detailLabel,
    required this.onTap,
    this.photo,
    this.photoLabel,
  });

  final String chip;
  final String title;
  final String time;
  final List<String> dishes;
  final String detailLabel;
  final VoidCallback onTap;
  final Widget? photo;
  final String? photoLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final fg = t.onMedia;
    final shown = dishes.take(3).toList();
    final extra = dishes.length - shown.length;
    return Semantics(
      button: true,
      label: [if (photo != null && photoLabel != null) photoLabel!, title, chip, dishes.join(', ')].join('. '),
      onTap: onTap,
      excludeSemantics: true,
      child: BuPressable(
        scale: .98,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(children: [
            Positioned.fill(
              child: photo != null
                  ? Semantics(image: true, label: photoLabel, child: photo)
                  : DecoratedBox(decoration: BoxDecoration(gradient: t.hero)),
            ),
            if (photo != null)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [t.scrim.withValues(alpha: .35), t.scrim.withValues(alpha: .8)],
                    ),
                  ),
                ),
              ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: fg.withValues(alpha: .2), borderRadius: BorderRadius.circular(BuRadius.pill)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 7, height: 7, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Flexible(child: Text(chip, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w800, color: fg))),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      Expanded(
                        child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.headlineSmall!.copyWith(fontWeight: FontWeight.w800, color: fg)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: fg.withValues(alpha: .2), borderRadius: BorderRadius.circular(BuRadius.pill)),
                        child: Text(time, maxLines: 1, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: fg)),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: fg.withValues(alpha: .14), borderRadius: BorderRadius.circular(BuRadius.md)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        for (var i = 0; i < shown.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          Row(children: [
                            Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(shown[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: fg))),
                          ]),
                        ],
                        if (extra > 0) ...[
                          const SizedBox(height: 8),
                          Text('+$extra', style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: fg.withValues(alpha: .85))),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 12, 8),
                        decoration: BoxDecoration(color: fg.withValues(alpha: .2), borderRadius: BorderRadius.circular(BuRadius.pill)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(detailLabel, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w800, color: fg)),
                          const SizedBox(width: 6),
                          Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: fg),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Öne çıkan haber kartı (yatay kaydırma): üstte görsel + tür etiketi, altta başlık ve tarih + ok.
class HomeNewsCard extends StatelessWidget {
  const HomeNewsCard({super.key, required this.title, required this.tag, required this.dateText, required this.imageUrl, required this.onTap, this.width = 280});

  final String title;
  final String tag;
  final String dateText;
  final String? imageUrl;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final hasImg = imageUrl != null && imageUrl!.isNotEmpty;
    return SizedBox(
      width: width,
      child: BuCard(
        radius: 24,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: 150,
              child: Stack(fit: StackFit.expand, children: [
                if (hasImg)
                  BuImage(imageUrl, width: double.infinity, height: 150, maxDecodeWidth: 700)
                else
                  DecoratedBox(
                    decoration: BoxDecoration(gradient: t.hero),
                    child: Icon(LucideIcons.newspaper, size: 56, color: t.onMedia.withValues(alpha: .3)),
                  ),
                PositionedDirectional(
                  start: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: t.sf.withValues(alpha: .92), borderRadius: BorderRadius.circular(BuRadius.pill)),
                    child: Text(tag, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.pr)),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  height: 52,
                  child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, height: 1.25, color: t.ink)),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: Text(dateText, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut))),
                  Icon(buDirIcon(context, LucideIcons.arrowRight), size: 18, color: t.pr),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Katılımcı avatar yığını (en çok 3) + sayı metni.
class HomeAvatarStack extends StatelessWidget {
  const HomeAvatarStack({super.key, required this.avatars, this.total = 0});

  final List<Map<String, dynamic>> avatars;

  /// Kullanılmıyor (ref: yalnız avatarlar + yanında toplam metni); eski çağrılar için duruyor.
  final int total;

  static const _d = 30.0;
  static const _step = 20.0;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final shown = avatars.take(3).toList();
    final count = shown.length;
    if (count == 0) return Icon(LucideIcons.users, size: 18, color: t.mut);
    return SizedBox(
      width: _d + _step * (count - 1),
      height: _d,
      child: Stack(children: [
        for (var i = 0; i < shown.length; i++)
          PositionedDirectional(
            start: i * _step,
            child: Container(
              width: _d,
              height: _d,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, color: t.sf),
              child: BuAvatar(name: shown[i]['displayName'] as String?, url: shown[i]['avatarUrl'] as String?, size: _d - 4),
            ),
          ),
      ]),
    );
  }
}

/// "Yaklaşan Etkinlik" kartı: düzenleyen şeridi, tarih karosu, başlık, konum, katılımcılar + eylem düğmesi.
class HomeEventCard extends StatelessWidget {
  const HomeEventCard({
    super.key,
    required this.title,
    required this.onTap,
    this.host,
    this.month,
    this.day,
    this.whenLine,
    this.location,
    this.footer,
  });

  final String title;
  final VoidCallback? onTap;
  final String? host;
  final String? month;
  final String? day;
  final String? whenLine;
  final String? location;

  /// Alt satır (avatarlar + katılımcı sayısı + düğme).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return BuCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (host != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: t.soft.withValues(alpha: .6), borderRadius: BorderRadius.circular(BuRadius.sm)),
            child: Row(children: [
              Icon(LucideIcons.users, size: 16, color: t.pr),
              const SizedBox(width: 8),
              Expanded(child: Text(host!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.onSoft))),
            ]),
          ),
        if (host != null) const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (month != null && day != null) ...[
            Container(
              width: 76,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(BuRadius.md)),
              child: Column(children: [
                Text(month!, maxLines: 1, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w800, color: t.onSoft)),
                Text(day!, maxLines: 1, style: tx.headlineMedium!.copyWith(fontWeight: FontWeight.w800, height: 1.1, color: t.pr)),
                if (whenLine != null) Text(whenLine!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelSmall!.copyWith(color: t.onSoft)),
              ]),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, height: 1.2, color: t.ink)),
              if (location != null && location!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(LucideIcons.mapPin, size: 15, color: t.pr),
                  const SizedBox(width: 6),
                  Expanded(child: Text(location!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut))),
                ]),
              ],
            ]),
          ),
        ]),
        if (footer != null) ...[const SizedBox(height: 16), footer!],
      ]),
    );
  }
}

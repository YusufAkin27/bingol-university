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
  amber;

  BuTint tint(BuTokens t) => switch (this) {
        HomeTone.red => BuTint(t.soft, t.onSoft),
        HomeTone.green => t.tint(1),
        HomeTone.blue => t.tint(0),
        HomeTone.amber => t.tint(2),
      };
}

/// 56x56 yuvarlak-kare ikon + etiket.
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
    final bg = tn.bg;
    final fg = tn.fg;
    // Sabit boyutlu kutu: çok büyük yazı ölçeğinde taşmasın.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
              child: Icon(icon, size: 24, color: fg),
            ),
            const SizedBox(height: 7),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: BuType.label.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: t.ink)),
          ]),
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

/// Ana Sayfa yükleniyor iskeleti: selamlama, arama, hızlı erişim, yemek kartı, etkinlik kartı, duyuru satırları.
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
    Widget row(double w, double kw) => Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Row(children: [
            const BuSkeleton.circle(8),
            const SizedBox(width: 12),
            Expanded(child: Align(alignment: AlignmentDirectional.centerStart, child: BuSkeleton(width: w, height: 12))),
            const SizedBox(width: 12),
            BuSkeleton(width: kw, height: 12),
          ]),
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
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    BuSkeleton(width: 150, height: 22, radius: 12),
                    SizedBox(height: 10),
                    BuSkeleton(width: 220, height: 12),
                  ]),
                ),
                BuSkeleton.circle(44),
              ]),
              const SizedBox(height: 16),
              card(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: const Row(children: [BuSkeleton.circle(20), SizedBox(width: 12), Expanded(child: BuSkeleton(height: 12))]),
              ),
              const SizedBox(height: 18),
              Row(children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  const Expanded(
                    child: Column(children: [
                      BuSkeleton(width: 56, height: 56, radius: 18),
                      SizedBox(height: 8),
                      BuSkeleton(width: 40, height: 10),
                    ]),
                  ),
                ],
              ]),
              const SizedBox(height: 20),
              card(
                child: Column(children: [
                  const Row(children: [BuSkeleton(width: 20, height: 20, radius: 6), SizedBox(width: 10), BuSkeleton(width: 110, height: 14), Spacer(), BuSkeleton(width: 70, height: 22, radius: 11)]),
                  row(150, 40),
                  row(190, 40),
                  row(130, 40),
                ]),
              ),
              const SizedBox(height: 16),
              card(
                padding: EdgeInsets.zero,
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  BuSkeleton(height: 112, radius: 20),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      BuSkeleton(width: 240, height: 14),
                      SizedBox(height: 10),
                      Row(children: [BuSkeleton(width: 70, height: 10), SizedBox(width: 10), BuSkeleton(width: 90, height: 10)]),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 22),
              const Row(children: [BuSkeleton(width: 90, height: 14), Spacer(), BuSkeleton(width: 50, height: 12)]),
              const SizedBox(height: 12),
              for (var i = 0; i < 2; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                card(
                  child: const Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        BuSkeleton(width: 80, height: 10),
                        SizedBox(height: 8),
                        BuSkeleton(height: 12),
                      ]),
                    ),
                    SizedBox(width: 16),
                    BuSkeleton(width: 40, height: 40, radius: 12),
                  ]),
                ),
              ],
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

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../core/typography.dart';

// Tasarım (P1/P1b) sabit ton renkleri.
const _kRed = Color(0xFFC62A20);
const _kShadow = Color(0x40171E33); // rgba(23,30,51,.25)

/// Ana sayfa kart gölgesi: 0 6 18 -12.
const List<BoxShadow> homeCardShadow = [
  BoxShadow(color: _kShadow, blurRadius: 18, spreadRadius: -12, offset: Offset(0, 6)),
];

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

/// Hızlı erişim karosu tonları (açık zemin, ön plan).
enum HomeTone {
  red(Color(0xFFFDE7E4), Color(0xFFC62A20)),
  green(Color(0xFFE6F2EA), Color(0xFF1F7A4A)),
  blue(Color(0xFFE8EDF8), Color(0xFF2F4FA8)),
  amber(Color(0xFFFBEFD9), Color(0xFF8A5200));

  const HomeTone(this.bg, this.fg);
  final Color bg;
  final Color fg;
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Koyu temada ton zemini ön planın saydam hali; ön plan aydınlatılır (okunurluk).
    final bg = dark ? tone.fg.withValues(alpha: .22) : tone.bg;
    final fg = dark ? Color.lerp(tone.fg, Colors.white, .45)! : tone.fg;
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
    final onPhoto = photo != null;
    final head = Row(children: [
      Expanded(
        child: Text(title,
            maxLines: 2,
            style: BuType.label.copyWith(fontSize: 12, fontWeight: onPhoto ? FontWeight.w700 : FontWeight.w600, color: Colors.white.withValues(alpha: onPhoto ? 1 : .9))),
      ),
      const SizedBox(width: 8),
      Text(time,
          style: BuType.label.copyWith(fontSize: 12, fontWeight: onPhoto ? FontWeight.w600 : FontWeight.w400, color: Colors.white.withValues(alpha: onPhoto ? 1 : .9))),
    ]);
    final body = Text(text,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: BuType.title.copyWith(fontSize: 18, height: 1.3, color: Colors.white));
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
        boxShadow: [BoxShadow(color: _kRed.withValues(alpha: onPhoto ? .55 : .7), blurRadius: 26, spreadRadius: -14, offset: const Offset(0, 14))],
      ),
      child: Material(
        color: _kRed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _kRed)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: !onPhoto
              ? content
              : Stack(children: [
                  Positioned.fill(child: Semantics(image: true, label: photoLabel, child: photo)),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0, .4, .75, 1],
                          colors: [Color(0x00171E33), Color(0x66171E33), Color(0xCC171E33), Color(0xF2171E33)],
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
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: homeCardShadow),
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

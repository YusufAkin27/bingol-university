import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';

/// Ana Sayfa "Kampüs Haritası" kartı: STATİK önizleme (ağ isteği YOK; kart yalnız harita ekranına giden kapıdır),
/// "Kampüste ara" şeridi ve 3 hızlı kategori çipi. Önizleme çizimi belirteçlerle yapılır (açık/koyu tema uyumlu).
class CampusHomeCard extends StatelessWidget {
  const CampusHomeCard({super.key, required this.onOpen, required this.onSearch, required this.onChip});

  /// Haritayı aç (kartın gövdesi / "Haritayı aç").
  final VoidCallback onOpen;

  /// "Kampüste ara" şeridi: doğrudan arama ekranı.
  final VoidCallback onSearch;

  /// Çip: etiket (ör. "Yemekhane") kategori ipucu olarak verilir.
  final ValueChanged<String> onChip;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final chips = <({String label, IconData icon})>[
      (label: l.campusChipFood, icon: BuIcons.utensils),
      (label: l.campusChipLibrary, icon: BuIcons.library),
      (label: l.campusChipFaculties, icon: BuIcons.graduationCap),
    ];
    return Container(
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.bd),
        boxShadow: BuElevation.of(context, 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BuPressable(
          onTap: onOpen,
          semanticLabel: '${l.campusCardTitle}. ${l.campusCardSub}',
          child: Stack(children: [
            ExcludeSemantics(
              child: SizedBox(
                height: 156,
                child: CustomPaint(painter: CampusPreviewPainter(t), size: Size.infinite),
              ),
            ),
            PositionedDirectional(
              start: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 5, 12, 5),
                decoration: BoxDecoration(color: t.sf.withValues(alpha: .94), borderRadius: BuRadius.bPill),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(BuIcons.map, size: 16, color: t.pr),
                  const SizedBox(width: 6),
                  Text(l.campusCardTitle, style: tx.labelMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
            PositionedDirectional(
              end: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 8, 6),
                decoration: BoxDecoration(color: t.prPressed, borderRadius: BuRadius.bPill),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(l.campusCardOpen, style: tx.labelMedium!.copyWith(color: t.onPr, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 2),
                  Icon(buDirIcon(context, BuIcons.chevronRight), size: 16, color: t.onPr),
                ]),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Semantics(
            button: true,
            label: l.campusSearchHint,
            excludeSemantics: true,
            onTap: onSearch,
            child: Material(
              color: t.sf2,
              shape: StadiumBorder(side: BorderSide(color: t.bd)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onSearch,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
                  child: Row(children: [
                    Icon(BuIcons.search, size: 20, color: t.mut),
                    const SizedBox(width: 10),
                    Expanded(child: Text(l.campusSearchHint, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(color: t.mut))),
                  ]),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          // Üç kategori çipi tek satırda (Stitch v5): eşit genişlik, sığmazsa etiket küçülür.
          child: Row(children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _CampusChip(label: chips[i].label, icon: chips[i].icon, onTap: () => onChip(chips[i].label))),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Kategori çipi: 48 dp yüksek, beyaz zemin + 1 dp çerçeve, `prPressed` ikon + 13/600 etiket.
class _CampusChip extends StatelessWidget {
  const _CampusChip({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: BuPressable(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: t.sf, borderRadius: BuRadius.bPill, border: Border.all(color: t.bd)),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 16, color: t.prPressed),
                const SizedBox(width: 6),
                Text(label, maxLines: 1, style: BuType.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: t.ink)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kampüs önizleme çizimi (sabit): parklar, yollar, bina kutuları, kırmızı kesikli sınır, üç iğne. Ağdan harita çekmez.
class CampusPreviewPainter extends CustomPainter {
  CampusPreviewPainter(this.t);

  final BuTokens t;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    canvas.drawRect(Offset.zero & s, Paint()..color = t.sf2);
    // Parklar
    final park = Paint()..color = t.okSoft;
    canvas.drawOval(Rect.fromLTWH(w * .02, h * .52, w * .34, h * .62), park);
    canvas.drawOval(Rect.fromLTWH(w * .62, -h * .22, w * .46, h * .62), park);
    // Yollar
    final road = Paint()
      ..color = t.sf
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(Path()..moveTo(-8, h * .66)..quadraticBezierTo(w * .38, h * .46, w * .62, h * .56)..quadraticBezierTo(w * .82, h * .64, w + 8, h * .36), road);
    canvas.drawPath(Path()..moveTo(w * .46, -8)..quadraticBezierTo(w * .4, h * .5, w * .52, h + 8), road);
    // Binalar
    final b = Paint()..color = t.bd;
    for (final r in [
      Rect.fromLTWH(w * .18, h * .2, w * .12, h * .24),
      Rect.fromLTWH(w * .56, h * .16, w * .14, h * .22),
      Rect.fromLTWH(w * .66, h * .64, w * .15, h * .2),
      Rect.fromLTWH(w * .3, h * .66, w * .1, h * .18),
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), b);
    }
    // Kampüs sınırı (kesikli)
    final poly = Path()
      ..moveTo(w * .12, h * .3)
      ..lineTo(w * .34, h * .1)
      ..lineTo(w * .78, h * .14)
      ..lineTo(w * .9, h * .58)
      ..lineTo(w * .62, h * .92)
      ..lineTo(w * .2, h * .84)
      ..close();
    final dash = Paint()
      ..color = t.pr
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    for (final m in poly.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, (d + 8).clamp(0, m.length)), dash);
        d += 14;
      }
    }
    // İğneler
    void pin(Offset c, Color color) {
      canvas.drawCircle(c + const Offset(0, 2), 12, Paint()..color = t.shadow.withValues(alpha: .25));
      canvas.drawCircle(c, 12, Paint()..color = t.onMedia);
      canvas.drawCircle(c, 9.5, Paint()..color = color);
      canvas.drawCircle(c, 3.2, Paint()..color = t.onMedia);
    }

    // Stitch v5: üç etiketsiz kırmızı iğne (uydurma konum/mavi nokta yok).
    pin(Offset(w * .26, h * .3), t.pr);
    pin(Offset(w * .62, h * .28), t.pr);
    pin(Offset(w * .7, h * .7), t.pr);
  }

  @override
  bool shouldRepaint(CampusPreviewPainter old) => old.t != t;
}

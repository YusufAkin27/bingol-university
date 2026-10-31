import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

// Anket ekranları (An1-An4) ortak görsel parçaları. Renkler yalnız belirteçlerden (context.bu), yazı TextTheme'den.

/// Kapsam tonu (zemin + yazı): Genel mavi, Kulüp su mavisi, Yemek yeşil (`BuTokens.tint`).
class AnketTone {
  const AnketTone(this.bg, this.fg);
  final Color bg;
  final Color fg;

  // Kapsam (Genel / Kulüp / Yemek) rengi artık ayrışmaz: hepsi nötr; tür simgeyle ve etiketle anlatılır
  // (ekranda tek vurgu rengi: marka).
  static AnketTone _neutral(BuildContext c) {
    final t = c.bu;
    return AnketTone(t.sf2, t.mut);
  }

  static AnketTone general(BuildContext c) => _neutral(c);
  static AnketTone club(BuildContext c) => _neutral(c);
  static AnketTone meal(BuildContext c) => _neutral(c);
}

/// Yıldız ve puan dağılımı rengi: marka rengi (amber yalnız uyarıdır; ekranda tek vurgu).
Color anketGoldOf(BuildContext c) => c.bu.pr;

/// Hap rozet (24 dp; [small] 20 dp). Yazı `labelMedium/labelSmall`.
class AnketPill extends StatelessWidget {
  const AnketPill(this.label, {super.key, required this.bg, required this.fg, this.icon, this.small = false});

  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final tx = Theme.of(context).textTheme;
    final h = small ? 20.0 : 26.0;
    final style = (small ? tx.labelSmall! : tx.labelMedium!).copyWith(color: fg, fontWeight: FontWeight.w700, height: 1.2);
    return Container(
      constraints: BoxConstraints(minHeight: h),
      padding: EdgeInsetsDirectional.symmetric(horizontal: small ? 8 : 10, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BuRadius.bPill),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[ExcludeSemantics(child: Icon(icon, size: small ? 11 : 13, color: fg)), const SizedBox(width: 4)],
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
      ]),
    );
  }
}


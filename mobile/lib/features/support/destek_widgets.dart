import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/typography.dart';

/// Destek tasarımı (Ds1-Ds5) ortak bileşenleri. Renkler `context.bu`; sabit ton yok.

/// Tasarımdaki .card: 20 px köşe, 1 px çizgi, yumuşak gölge.
class DestekCard extends StatelessWidget {
  const DestekCard({super.key, required this.child, this.padding, this.clip = false});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: t.sf,
        border: Border.all(color: t.bd),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14171E33), blurRadius: 18, spreadRadius: -12, offset: Offset(0, 6))],
      ),
      child: child,
    );
  }
}

/// Tasarımdaki .chip: 44 px yükseklik, 22 px köşe; seçiliyken yumuşak kırmızı zemin + kırmızı çizgi.
class DestekChip extends StatelessWidget {
  const DestekChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? t.soft : t.sf,
        shape: StadiumBorder(side: BorderSide(color: selected ? t.pr : t.bd, width: 1.5)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          excludeFromSemantics: true,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              child: Center(
                widthFactor: 1,
                child: Text(label, style: BuType.label.copyWith(color: selected ? t.onSoft : t.ink)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Yatay kayan çip sırası (taşmaz; RTL'de doğru yönde başlar).
class DestekChipRow extends StatelessWidget {
  const DestekChipRow({super.key, required this.children, this.padding = const EdgeInsets.symmetric(horizontal: 20)});

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            children[i],
          ],
        ]),
      );
}

/// Alta sabit eylem çubuğu: zemin rengine doğru solan geçiş (tasarımdaki .fadeb).
class DestekBottomBar extends StatelessWidget {
  const DestekBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: const [.7, 1],
          colors: [t.bg, t.bg.withValues(alpha: 0)],
        ),
      ),
      child: child,
    );
  }
}

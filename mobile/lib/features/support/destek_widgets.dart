import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

/// Destek tasarımı (Ds1-Ds5) ortak bileşenleri. Renkler `context.bu`; sabit ton yok.

/// Çizgili beyaz kart: 20 dp köşe, ince çizgi. Üzerindeki `InkWell` dalgaları görünsün diye `Material` üzerindedir.
class DestekCard extends StatelessWidget {
  const DestekCard({super.key, required this.child, this.padding, this.clip = false});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Material(
      color: t.sf,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      shape: RoundedRectangleBorder(borderRadius: BuRadius.bLg, side: BorderSide(color: t.bd)),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

/// Süzgeç çipi (kategori, sözleşme türü): hap, seçiliyken marka tonu; `BuChip` ile aynı görünüm.
class DestekChip extends StatelessWidget {
  const DestekChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => BuChip(label: label, selected: selected, onTap: onTap);
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
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: const [.7, 1],
          colors: [t.bg, t.bg.withValues(alpha: 0)],
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16 + MediaQuery.paddingOf(context).bottom),
        child: child,
      ),
    );
  }
}

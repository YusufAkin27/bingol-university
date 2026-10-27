import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart' show LucideIcons;

/// Yüzen hap gezinme: yalnızca ikonlar; seçili sekmenin arkasında kayan marka renkli vurgu.
/// Etiket metni görünmez; erişilebilirlik için Semantics + Tooltip korunur.
class FloatingNav extends StatelessWidget {
  const FloatingNav({super.key, required this.index, required this.onChanged, required this.chatBadge});

  final int index;
  final ValueChanged<int> onChanged;
  final ValueNotifier<int> chatBadge;

  static const double height = 62;
  static const _items = [
    (LucideIcons.house, 'Ana Sayfa'),
    (LucideIcons.compass, 'Keşfet'),
    (LucideIcons.messageCircle, 'Sohbet'),
    (LucideIcons.users, 'Kulüpler'),
    (LucideIcons.user, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final bottom = MediaQuery.of(context).padding.bottom;
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final side = narrow ? 14.0 : 20.0;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final dark = t.bg == BuTokens.dark.bg;
    final n = _items.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(side, 0, side, bottom > 0 ? bottom : 16),
      child: RepaintBoundary(
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: t.nav.withValues(alpha: .94),
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: dark ? t.bd : t.bd.withValues(alpha: .5)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: dark ? .30 : .10), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: LayoutBuilder(builder: (context, c) {
            final slot = c.maxWidth / n;
            final pillW = (slot - 6).clamp(44.0, 56.0);
            final visual = rtl ? n - 1 - index : index;
            return Stack(
              alignment: Alignment.center,
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: visual * slot + (slot - pillW) / 2,
                  top: (height - 2 - 44) / 2,
                  width: pillW,
                  height: 44,
                  child: DecoratedBox(
                    key: const ValueKey('nav-pill'),
                    decoration: BoxDecoration(
                      color: t.pr,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [BoxShadow(color: t.pr.withValues(alpha: .35), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < n; i++)
                      Expanded(
                        child: _NavItem(
                          icon: _items[i].$1,
                          label: _items[i].$2,
                          selected: i == index,
                          badge: i == _chatIndex ? chatBadge : null,
                          onTap: () {
                            if (i != index) HapticFeedback.selectionClick();
                            onChanged(i);
                          },
                        ),
                      ),
                  ],
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

const _chatIndex = 2; // AppTab.chat (döngüsel içe aktarmayı önlemek için)

class _NavItem extends StatefulWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap, this.badge});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ValueNotifier<int>? badge;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
    TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 50),
  ]).animate(_c);

  @override
  void didUpdateWidget(_NavItem old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final color = widget.selected ? t.onPr : t.onNav.withValues(alpha: .7);
    Widget icon = ScaleTransition(
      scale: _scale,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration: const Duration(milliseconds: 220),
        builder: (_, v, __) => Icon(widget.icon, size: 24, color: v ?? color),
      ),
    );
    final badge = widget.badge;
    if (badge != null) {
      icon = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          icon,
          PositionedDirectional(
            end: -10,
            top: -8,
            child: ValueListenableBuilder<int>(
              valueListenable: badge,
              builder: (_, n, __) {
                final show = n > 0 && !widget.selected;
                return AnimatedScale(
                  scale: show ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: show || n > 0
                      ? Container(
                          key: const ValueKey('nav-badge'),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: t.pr,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: t.nav, width: 1.5),
                          ),
                          child: Text(n > 99 ? '99+' : '$n',
                              style: BuType.caption.copyWith(color: t.onPr, fontWeight: FontWeight.w700, height: 1.1)),
                        )
                      : const SizedBox.shrink(),
                );
              },
            ),
          ),
        ],
      );
    }
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: Tooltip(
        message: widget.label,
        excludeFromSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox(height: FloatingNav.height, child: Center(child: icon)),
        ),
      ),
    );
  }
}

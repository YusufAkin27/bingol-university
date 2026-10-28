import '../../core/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart' show LucideIcons;

/// Yüzen gezinme kartı: ikon + etiket; seçili sekmenin arkasında kayan yumuşak kırmızı hap.
class FloatingNav extends StatelessWidget {
  const FloatingNav({super.key, required this.index, required this.onChanged, required this.chatBadge});

  final int index;
  final ValueChanged<int> onChanged;
  final ValueNotifier<int> chatBadge;

  static const double height = 68;

  static List<String> _labels(BuildContext context) {
    final l = context.l10n;
    return [l.navHome, l.navDiscover, l.navChat, l.navClubs, l.navProfile];
  }
  static const _items = [
    LucideIcons.house,
    LucideIcons.compass,
    LucideIcons.messageCircle,
    LucideIcons.users,
    LucideIcons.user,
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final bottom = MediaQuery.of(context).padding.bottom;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final dark = t.bg == BuTokens.dark.bg;
    final n = _items.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom > 0 ? bottom : 16),
      child: RepaintBoundary(
        // Düz, yüzen kart: yüzey rengi, 1 px kenarlık, 24 px köşe, yumuşak gölge.
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: t.sf,
            border: Border.all(color: t.bd),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: (dark ? Colors.black : const Color(0xFF171E33)).withValues(alpha: dark ? .45 : .35),
                blurRadius: 30,
                spreadRadius: -14,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: LayoutBuilder(builder: (context, c) {
            final slot = c.maxWidth / n;
            final pillW = (slot - 2).clamp(44.0, 64.0);
            final visual = rtl ? n - 1 - index : index;
            return Stack(
              alignment: Alignment.center,
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: visual * slot + (slot - pillW) / 2,
                  top: (height - 2 - 52) / 2,
                  width: pillW,
                  height: 52,
                  child: DecoratedBox(
                    key: const ValueKey('nav-pill'),
                    decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < n; i++)
                      Expanded(
                        child: _NavItem(
                          icon: _items[i],
                          label: _labels(context)[i],
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
    final color = widget.selected ? t.onSoft : t.mut;
    Widget icon = ScaleTransition(
      scale: _scale,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration: const Duration(milliseconds: 220),
        builder: (_, v, __) => Icon(widget.icon, size: 22, color: v ?? color),
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
                            border: Border.all(color: t.sf, width: 1.5),
                          ),
                          // Rozet sabit boyutlu: yazı ölçeği büyüyünce simgeyi örtmesin.
                          child: MediaQuery.withClampedTextScaling(
                            maxScaleFactor: 1.15,
                            child: Text(n > 99 ? '99+' : '$n',
                                style: BuType.caption.copyWith(color: t.onPr, fontWeight: FontWeight.w700, height: 1.1)),
                          ),
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
          child: SizedBox(
            height: FloatingNav.height,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(height: 3),
                  MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(widget.label,
                            maxLines: 1,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, height: 1.2, color: color)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

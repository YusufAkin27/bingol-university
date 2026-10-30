import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/theme.dart';
import '../../core/theme/bu_motion.dart';
import '../../core/theme/bu_elevation.dart' show BuElevation;
import '../../widgets/bu_list.dart' show BuCountBadge;
import '../../widgets/bu_pressable.dart' show BuHaptic, buHaptic;
import '../../widgets/bu_widgets.dart' show LucideIcons;

/// Yüzen hap alt gezinme (Stitch referansı): kenarlardan ve alttan boşluklu, beyaz, yuvarlak köşeli kart; 5 sekme,
/// her zaman görünür etiket, seçili sekme marka renginde (dolgulu gösterge yok) + sohbet rozeti.
/// Sınıf adı ve imza eski yüzen kartla aynıdır (kabuk ve testler değişmeden kullanır); gövde M3 [NavigationBar]'dır.
///
/// Seçili sekmenin simgesi hafifçe büyür (yalnız `transform`), dokunuşta hafif titreşim verilir;
/// "animasyonları azalt" açıkken ölçek anlıktır. Rozet 0 iken görünmez, 99'u aşınca "99+".
class FloatingNav extends StatelessWidget {
  const FloatingNav(
      {super.key,
      required this.index,
      required this.onChanged,
      required this.chatBadge});

  final int index;
  final ValueChanged<int> onChanged;
  final ValueNotifier<int> chatBadge;

  /// Hapın içerik yüksekliği.
  static const double height = 68;

  /// Hapın kenarlardan ve alttan dış boşluğu.
  static const double gap = 16;

  static const _icons = [
    LucideIcons.house,
    LucideIcons.compass,
    LucideIcons.messageCircle,
    LucideIcons.users,
    LucideIcons.user,
  ];

  static List<String> _labels(BuildContext context) {
    final l = context.l10n;
    return [l.navHome, l.navDiscover, l.navChat, l.navClubs, l.navProfile];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final labels = _labels(context);
    // Büyük yazı ölçeğinde etiket bölünmesin/kırpılmasın: ölçek 1.15 ile sınırlanır, hap yüksekliği ölçekle büyür.
    final scale =
        MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15).scale(1);
    final barHeight = height + 20 * (scale - 1);
    final navTheme = Theme.of(context).navigationBarTheme.copyWith(
          height: barHeight,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          indicatorColor: Colors.transparent,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              size: 24,
              color: s.contains(WidgetState.selected) ? t.pr : t.mut)),
          labelTextStyle: WidgetStateProperty.resolveWith((s) {
            final sel = s.contains(WidgetState.selected);
            return tx.labelSmall!.copyWith(
                fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                color: sel ? t.pr : t.mut);
          }),
        );
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: gap),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(gap, 0, gap, 0),
        child: RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: t.sf,
              borderRadius: BorderRadius.circular(barHeight / 2),
              border: Border.all(color: t.bd),
              boxShadow: BuElevation.of(context, 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(barHeight / 2),
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.15,
                child: NavigationBarTheme(
                  data: navTheme,
                  child: NavigationBar(
                    selectedIndex: index,
                    onDestinationSelected: (i) {
                      if (i != index) buHaptic(BuHaptic.selection);
                      onChanged(i);
                    },
                    destinations: [
                      for (var i = 0; i < _icons.length; i++)
                        NavigationDestination(
                          key: ValueKey('nav-$i'),
                          tooltip: labels[i],
                          label: labels[i],
                          icon: _NavIcon(
                              icon: _icons[i],
                              selected: false,
                              badge: i == _chatIndex ? chatBadge : null),
                          selectedIcon: _NavIcon(
                              icon: _icons[i],
                              selected: true,
                              badge: i == _chatIndex ? chatBadge : null),
                        ),
                    ],
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

const _chatIndex = 2; // AppTab.chat (döngüsel içe aktarmayı önlemek için)

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, required this.selected, this.badge});

  final IconData icon;
  final bool selected;
  final ValueNotifier<int>? badge;

  @override
  Widget build(BuildContext context) {
    // Simge rengi NavigationBar temasından (IconTheme) gelir; yalnız boyut vurgusu burada.
    Widget w = AnimatedScale(
      scale: selected ? 1.1 : 1,
      duration: BuMotion.of(context, BuMotion.medium),
      curve: BuMotion.emphasizedDecelerate,
      child: Icon(icon),
    );
    final badge = this.badge;
    if (badge == null) return w;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        w,
        PositionedDirectional(
          end: -12,
          top: -8,
          child: ValueListenableBuilder<int>(
            valueListenable: badge,
            builder: (_, n, __) {
              final show = n > 0 && !selected;
              // Ekran okuyucu: "Sohbet, 3 okunmamış" (rozet metni sekme etiketiyle birleşir).
              return Semantics(
                label: show
                    ? context.l10n.p18NavUnread(n > 99 ? '99+' : '$n')
                    : null,
                child: ExcludeSemantics(
                  child: AnimatedScale(
                    scale: show ? 1 : 0,
                    duration: BuMotion.of(context, BuMotion.medium),
                    curve: Curves.easeOutBack,
                    child: n > 0
                        ? BuCountBadge(n, key: const ValueKey('nav-badge'))
                        : const SizedBox.shrink(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

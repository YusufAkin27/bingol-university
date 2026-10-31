import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'home_layout.dart';
import 'home_parts.dart';

/// Bölüm adı (düzenleme sayfası satırı). Başlıklar Ana Sayfa'daki bölüm başlıklarıyla aynı metinlerdir.
String homeSectionLabel(AppLocalizations l, HomeSection s) => switch (s) {
      HomeSection.menu => l.p03HomeMealTitle,
      HomeSection.quickAccess => l.p03HomeQuickTitle,
      HomeSection.featuredNews => l.p03HomeFeaturedNews,
      HomeSection.upcomingEvents => l.p03HomeUpcoming,
      HomeSection.announcements => l.anasayfaAnnouncements,
      HomeSection.todayClasses => l.p60SectionClasses,
    };

/// Kısayol adı (Hızlı Erişim karosu etiketi ve seçici satırı).
String homeShortcutLabel(AppLocalizations l, HomeShortcut s, {bool picker = false}) => switch (s) {
      HomeShortcut.news => l.icerikNewsTitle,
      HomeShortcut.menu => l.homeQuickFood,
      HomeShortcut.events => l.p03HomeQuickEvents,
      HomeShortcut.polls => l.discoverPolls,
      HomeShortcut.schedule => picker ? l.p60ShortScheduleFull : l.p03HomeQuickSchedule,
      HomeShortcut.clubs => l.navClubs,
      HomeShortcut.chat => l.navChat,
      HomeShortcut.support => l.supportTitle,
      HomeShortcut.search => l.p60ShortSearch,
      HomeShortcut.notifications => l.notifTitle,
      HomeShortcut.bookmarks => l.icerikSavedList,
    };

IconData homeShortcutIcon(HomeShortcut s) => switch (s) {
      HomeShortcut.news => LucideIcons.newspaper,
      HomeShortcut.menu => LucideIcons.utensils,
      HomeShortcut.events => LucideIcons.calendar,
      HomeShortcut.polls => LucideIcons.vote,
      HomeShortcut.schedule => LucideIcons.graduationCap,
      HomeShortcut.clubs => LucideIcons.users,
      HomeShortcut.chat => LucideIcons.messageCircle,
      HomeShortcut.support => LucideIcons.headset,
      HomeShortcut.search => LucideIcons.search,
      HomeShortcut.notifications => LucideIcons.bell,
      HomeShortcut.bookmarks => LucideIcons.bookmark,
    };

/// "Ana sayfayı düzenle" tam sayfası (alt gezinme yok): bölümleri tutamaçtan sürükleyerek ya da yukarı/aşağı
/// düğmeleriyle sıralar, anahtarla gizler/gösterir, Hızlı Erişim kısayol seçicisini açar; "Varsayılana dön", "Bitti".
/// Her değişiklik anında uygulanır ve kaydedilir (arkadaki Ana Sayfa canlı değişir).
Future<void> openHomeLayoutPage(BuildContext context, HomeLayoutController c) =>
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => HomeLayoutPage(controller: c)));

class HomeLayoutPage extends StatelessWidget {
  const HomeLayoutPage({super.key, required this.controller});

  final HomeLayoutController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BuHeader(
          title: l.p60EditHome,
          onBack: () => Navigator.of(context).maybePop(),
          actions: [
            Semantics(
              button: true,
              label: l.p60Done,
              excludeSemantics: true,
              onTap: () => Navigator.of(context).maybePop(),
              child: InkWell(
                borderRadius: BorderRadius.circular(BuRadius.xs),
                onTap: () => Navigator.of(context).maybePop(),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: BuSize.touch, minWidth: BuSize.touch),
                  child: Center(widthFactor: 1, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(l.p60Done, style: BuType.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: t.pr)))),
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
            Text(l.p60EditHint, style: BuType.body.copyWith(fontSize: 13.5, color: t.mut)),
            const SizedBox(height: 16),
            _SectionEditor(controller: controller),
            const SizedBox(height: 8),
            Center(
              child: ListenableBuilder(
                listenable: controller,
                builder: (_, __) => Semantics(
                  button: true,
                  excludeSemantics: true,
                  label: l.p60ResetDefault,
                  onTap: controller.reset,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(BuRadius.xs),
                    onTap: controller.reset,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: BuSize.touch, minWidth: BuSize.touch),
                      child: Center(widthFactor: 1, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(l.p60ResetDefault, style: BuType.body.copyWith(fontSize: 15, color: t.mut)))),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Hızlı Erişim kısayol seçici (alt sayfa): üstte seçilenler (5 slot, sıralı), altta 11 kısayolluk havuz; en çok 5.
Future<void> showHomeShortcutsSheet(BuildContext context, HomeLayoutController c) {
  final l = context.l10n;
  return BuSheet.show<void>(
    context,
    maxHeightFactor: .94,
    builder: (_) => _ShortcutEditor(controller: c),
    actions: [Builder(builder: (ctx) => BuButton(label: l.p60Done, onPressed: () => Navigator.of(ctx).pop()))],
  );
}

/// Sürüklenen satır: yüzeyden ayrık kart (1.02 ölçek, `pr` %40 çerçeve, tek gölge blur 16 y 4 %12).
Widget _lifted(BuildContext context, Widget child, int index, Animation<double> animation) {
  final t = context.bu;
  return AnimatedBuilder(
    animation: animation,
    builder: (context, c) {
      final a = Curves.easeOut.transform(animation.value);
      return Transform.scale(
        scale: 1 + .02 * a,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.sf,
            borderRadius: BorderRadius.circular(BuRadius.md),
            border: Border.all(color: t.pr.withValues(alpha: .4)),
            boxShadow: [BoxShadow(color: t.shadow.withValues(alpha: .12 * a), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Material(type: MaterialType.transparency, child: c),
        ),
      );
    },
    child: child,
  );
}

class _SectionEditor extends StatefulWidget {
  const _SectionEditor({required this.controller});

  final HomeLayoutController controller;

  @override
  State<_SectionEditor> createState() => _SectionEditorState();
}

class _SectionEditorState extends State<_SectionEditor> {
  int? _drag; // sürüklenen satırın dizini (diğerleri %55 opaklık)

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final v = c.value;
        return DecoratedBox(
          decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.md), border: Border.all(color: t.bd)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BuRadius.md - 1),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: v.order.length,
              proxyDecorator: (child, i, a) => _lifted(context, child, i, a),
              onReorderStart: (i) {
                BuHaptics.selection();
                setState(() => _drag = i);
              },
              onReorderEnd: (_) => setState(() => _drag = null),
              onReorderItem: (a, b) {
                BuHaptics.selection();
                c.update((x) => x.reorderSection(a, b));
              },
              itemBuilder: (context, i) {
                final s = v.order[i];
                return _SectionRow(
                  key: ValueKey(s.id),
                  index: i,
                  section: s,
                  visible: v.isVisible(s),
                  last: i == v.order.length - 1,
                  dimmed: _drag != null && _drag != i,
                  dragging: _drag == i,
                  canUp: i > 0,
                  canDown: i < v.order.length - 1,
                  onVisible: (on) {
                    BuHaptics.selection();
                    c.update((x) => x.setVisible(s, on));
                  },
                  onMove: (d) {
                    BuHaptics.selection();
                    c.update((x) => x.moveSection(s, d));
                  },
                  onShortcuts: () => showHomeShortcutsSheet(context, c),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Hayalet yukarı/aşağı düğmesi (Stitch: çerçevesiz soluk ok, 16 dp): dokunma alanı 44 x 48 (pasifken soluk).
class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: SizedBox(
            width: 44,
            height: BuSize.touch,
            child: Center(child: Icon(icon, size: 16, color: onTap == null ? t.mut.withValues(alpha: .35) : t.mut)),
          ),
        ),
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    super.key,
    required this.index,
    required this.section,
    required this.visible,
    required this.last,
    required this.dimmed,
    required this.dragging,
    required this.canUp,
    required this.canDown,
    required this.onVisible,
    required this.onMove,
    required this.onShortcuts,
  });

  final int index;
  final HomeSection section;
  final bool visible;
  final bool last;
  final bool dimmed;
  final bool dragging;
  final bool canUp;
  final bool canDown;
  final ValueChanged<bool> onVisible;
  final ValueChanged<int> onMove;
  final VoidCallback onShortcuts;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final name = homeSectionLabel(l, section);
    final quick = section == HomeSection.quickAccess;
    final label = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(name, maxLines: 3, overflow: TextOverflow.ellipsis, style: BuType.body.copyWith(fontSize: 15, fontWeight: FontWeight.w500, color: t.ink)),
      if (quick)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(l.p60Shortcuts, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.label.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: t.mut))),
            const SizedBox(width: 2),
            Icon(buDirIcon(context, LucideIcons.chevronRight), size: 14, color: t.mut),
          ]),
        ),
    ]);
    return AnimatedOpacity(
      key: ValueKey('row-${section.id}'),
      duration: BuMotion.of(context, BuMotion.short),
      opacity: dimmed ? .55 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(border: last || dragging ? null : Border(bottom: BorderSide(color: t.bd))),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60), // Stitch: p-4 + 28 dp düğme = 60
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, end: 16, top: 6, bottom: 6),
            child: Row(children: [
              ReorderableDragStartListener(
                index: index,
                child: Semantics(
                  label: name,
                  child: SizedBox(width: 40, height: BuSize.touch, child: Center(child: Icon(LucideIcons.gripVertical, size: 16, color: dragging ? t.pr : t.mut))),
                ),
              ),
              Expanded(
                child: Opacity(
                  opacity: visible ? 1 : .45,
                  child: quick
                      ? Semantics(
                          button: true,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(BuRadius.xs),
                            onTap: onShortcuts,
                            child: ConstrainedBox(constraints: const BoxConstraints(minHeight: BuSize.touch), child: Align(alignment: AlignmentDirectional.centerStart, child: label)),
                          ),
                        )
                      : label,
                ),
              ),
              _GhostButton(icon: LucideIcons.chevronUp, tooltip: l.p60MoveUp(name), onTap: canUp ? () => onMove(-1) : null),
              _GhostButton(icon: LucideIcons.chevronDown, tooltip: l.p60MoveDown(name), onTap: canDown ? () => onMove(1) : null),
              const SizedBox(width: 4),
              // Stitch: 44 x 24 anahtar (Flutter anahtarı 52 x 32; .85 ölçekle 44 x 27).
              Semantics(label: name, child: Transform.scale(scale: .85, child: Switch(value: visible, onChanged: onVisible))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ShortcutEditor extends StatelessWidget {
  const _ShortcutEditor({required this.controller});

  final HomeLayoutController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    Widget small(String s) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(trUpper(s), style: BuType.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: .6, color: t.mut)),
        );
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final v = controller.value;
        final full = v.shortcutOn.length >= HomeLayout.maxShortcuts;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: Semantics(header: true, child: Text(l.p03HomeQuickTitle, style: BuType.display.copyWith(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.4, color: t.ink)))),
            const SizedBox(width: 12),
            DecoratedBox(
              decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(BuRadius.pill)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: Text('${v.shortcutOn.length}/${HomeLayout.maxShortcuts}', style: BuType.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: t.pr, fontFeatures: const [FontFeature.tabularFigures()])),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(l.p60ShortcutsHint, style: BuType.body.copyWith(fontSize: 13, color: t.mut)),
          small(l.p60Selected),
          HomeSurface(
            color: t.bg,
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: v.shortcutOn.length,
              proxyDecorator: (child, i, a) => _lifted(context, child, i, a),
              onReorderStart: (_) => BuHaptics.selection(),
              onReorderItem: (a, b) {
                BuHaptics.selection();
                controller.update((x) => x.reorderShortcut(a, b));
              },
              itemBuilder: (context, i) {
                final s = v.shortcutOn[i];
                final name = homeShortcutLabel(l, s, picker: true);
                return DecoratedBox(
                  key: ValueKey('sel-${s.id}'),
                  decoration: BoxDecoration(border: i == v.shortcutOn.length - 1 ? null : Border(bottom: BorderSide(color: t.bd))),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: BuSize.touch),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
                      child: Row(children: [
                        ReorderableDragStartListener(
                          index: i,
                          child: Semantics(label: name, child: SizedBox(width: 44, height: BuSize.touch, child: Center(child: Icon(LucideIcons.gripVertical, size: 20, color: t.mut)))),
                        ),
                        SizedBox(width: 24, child: Text('${i + 1}', style: BuType.body.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: t.mut, fontFeatures: const [FontFeature.tabularFigures()]))),
                        const SizedBox(width: 8),
                        Expanded(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.body.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: t.ink))),
                        _GhostRemove(
                          tooltip: l.p60Remove(name),
                          onTap: v.shortcutOn.length > 1
                              ? () {
                                  BuHaptics.selection();
                                  controller.update((x) => x.setShortcut(s, false));
                                }
                              : null,
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
          small(l.p60AllShortcuts),
          HomeSurface(
            child: Column(children: [
              for (final s in HomeShortcut.values)
                Builder(builder: (context) {
                  final on = v.shortcutOn.contains(s);
                  final canToggle = on ? v.shortcutOn.length > 1 : !full;
                  final name = homeShortcutLabel(l, s, picker: true);
                  final last = s == HomeShortcut.values.last;
                  return Semantics(
                    checked: on,
                    enabled: canToggle,
                    inMutuallyExclusiveGroup: false,
                    label: name,
                    excludeSemantics: true,
                    onTap: canToggle ? () => controller.update((x) => x.setShortcut(s, !on)) : null,
                    child: Opacity(
                      opacity: !on && full ? .4 : 1,
                      child: InkWell(
                        onTap: canToggle
                            ? () {
                                BuHaptics.selection();
                                controller.update((x) => x.setShortcut(s, !on));
                              }
                            : null,
                        child: DecoratedBox(
                          decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: t.bd))),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: BuSize.touch),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(children: [
                                Expanded(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.body.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: t.ink))),
                                const SizedBox(width: 12),
                                AnimatedContainer(
                                  duration: BuMotion.of(context, BuMotion.short),
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: on ? t.pr : t.sf,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: on ? t.pr : t.bdStrong, width: 1.5),
                                  ),
                                  child: on ? Icon(LucideIcons.check, size: 14, color: t.onPr) : null,
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ]),
          ),
          const SizedBox(height: 8),
        ]);
      },
    );
  }
}

/// Seçili kısayolu kaldıran "x" düğmesi (20 dp ikon, dokunma alanı 48).
class _GhostRemove extends StatelessWidget {
  const _GhostRemove({required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: SizedBox(width: BuSize.touch, height: BuSize.touch, child: Center(child: Icon(LucideIcons.x, size: 20, color: onTap == null ? t.mut.withValues(alpha: .4) : t.mut))),
        ),
      ),
    );
  }
}

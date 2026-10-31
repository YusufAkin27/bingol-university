import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'home_layout.dart';

/// Bölüm adı (düzenleme ekranı satırı). Başlıklar Ana Sayfa'daki bölüm başlıklarıyla aynı metinlerdir.
String homeSectionLabel(AppLocalizations l, HomeSection s) => switch (s) {
      HomeSection.menu => l.p03HomeMealTitle,
      HomeSection.quickAccess => l.p03HomeQuickTitle,
      HomeSection.featuredNews => l.p03HomeFeaturedNews,
      HomeSection.upcomingEvents => l.p03HomeUpcoming,
      HomeSection.announcements => l.anasayfaAnnouncements,
      HomeSection.todayClasses => l.p60SectionClasses,
    };

/// Kısayol adı (Hızlı Erişim karosu etiketi ve seçici satırı).
String homeShortcutLabel(AppLocalizations l, HomeShortcut s) => switch (s) {
      HomeShortcut.news => l.icerikNewsTitle,
      HomeShortcut.menu => l.homeQuickFood,
      HomeShortcut.events => l.p03HomeQuickEvents,
      HomeShortcut.polls => l.discoverPolls,
      HomeShortcut.schedule => l.p03HomeQuickSchedule,
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

/// "Ana Sayfayı düzenle" alt sayfası: bölümleri sürükleyerek (uzun bas) ya da yukarı/aşağı düğmeleriyle sıralar,
/// anahtarla gizler/gösterir, Hızlı Erişim kısayol seçicisini açar; "Varsayılana dön" + "Bitti".
/// Her değişiklik anında uygulanır ve kaydedilir (arkadaki Ana Sayfa canlı değişir).
Future<void> showHomeLayoutSheet(BuildContext context, HomeLayoutController c) {
  final l = context.l10n;
  return BuSheet.show<void>(
    context,
    title: l.p60EditHome,
    subtitle: l.p60EditHint,
    maxHeightFactor: .94,
    builder: (_) => _SectionEditor(controller: c),
    actions: [
      Builder(builder: (ctx) => BuButton(label: l.p60Done, onPressed: () => Navigator.of(ctx).pop())),
      ListenableBuilder(
        listenable: c,
        builder: (_, __) => BuButton(label: l.p60ResetDefault, kind: BuButtonKind.text, onPressed: c.value.isDefault ? null : c.reset),
      ),
    ],
  );
}

/// Hızlı Erişim kısayol seçici: havuzdan en çok 5 kısayol aç/kapat ve sırala.
Future<void> showHomeShortcutsSheet(BuildContext context, HomeLayoutController c) {
  final l = context.l10n;
  return BuSheet.show<void>(
    context,
    title: l.p60Shortcuts,
    subtitle: l.p60ShortcutsHint,
    maxHeightFactor: .94,
    builder: (_) => _ShortcutEditor(controller: c),
    actions: [Builder(builder: (ctx) => BuButton(label: l.p60Done, onPressed: () => Navigator.of(ctx).pop()))],
  );
}

/// Sürüklenen (kaldırılmış) satır: hafif gölge + yüzey; yalnız gölge geçişi.
Widget _lifted(BuildContext context, Widget child, int index, Animation<double> animation) {
  final t = context.bu;
  return AnimatedBuilder(
    animation: animation,
    builder: (context, c) => Material(
      elevation: 6 * Curves.easeOut.transform(animation.value),
      shadowColor: t.shadow,
      color: t.sf3,
      borderRadius: BorderRadius.circular(BuRadius.md),
      child: c,
    ),
    child: child,
  );
}

class _SectionEditor extends StatelessWidget {
  const _SectionEditor({required this.controller});

  final HomeLayoutController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final v = controller.value;
        return ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: v.order.length,
          proxyDecorator: (child, i, a) => _lifted(context, child, i, a),
          onReorderStart: (_) => BuHaptics.selection(),
          onReorderItem: (a, b) {
            BuHaptics.light();
            controller.update((x) => x.reorderSection(a, b));
          },
          itemBuilder: (context, i) {
            final s = v.order[i];
            return _SectionRow(
              key: ValueKey(s.id),
              section: s,
              visible: v.isVisible(s),
              canUp: i > 0,
              canDown: i < v.order.length - 1,
              shortcutCount: s == HomeSection.quickAccess ? v.shortcuts.length : null,
              onVisible: (on) {
                BuHaptics.selection();
                controller.update((x) => x.setVisible(s, on));
              },
              onMove: (d) {
                BuHaptics.selection();
                controller.update((x) => x.moveSection(s, d));
              },
              onShortcuts: () => showHomeShortcutsSheet(context, controller),
            );
          },
        );
      },
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    super.key,
    required this.section,
    required this.visible,
    required this.canUp,
    required this.canDown,
    required this.onVisible,
    required this.onMove,
    required this.onShortcuts,
    this.shortcutCount,
  });

  final HomeSection section;
  final bool visible;
  final bool canUp;
  final bool canDown;
  final ValueChanged<bool> onVisible;
  final ValueChanged<int> onMove;
  final VoidCallback onShortcuts;

  /// Yalnız Hızlı Erişim satırı: seçili kısayol sayısı (satır, seçiciyi açar).
  final int? shortcutCount;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final name = homeSectionLabel(l, section);
    final label = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.heading.copyWith(fontSize: 15, color: visible ? t.ink : t.mut)),
      if (shortcutCount != null)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(l.p60ShortcutsCount('$shortcutCount'), maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.label.copyWith(color: t.pr))),
            const SizedBox(width: 2),
            Icon(buDirIcon(context, LucideIcons.chevronRight), size: 16, color: t.pr),
          ]),
        ),
    ]);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.md)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
            child: Row(children: [
              ExcludeSemantics(child: Icon(LucideIcons.gripVertical, size: 20, color: t.mut)),
              const SizedBox(width: 8),
              Expanded(
                child: shortcutCount == null
                    ? label
                    : Semantics(
                        button: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(BuRadius.xs),
                          onTap: onShortcuts,
                          child: ConstrainedBox(constraints: const BoxConstraints(minHeight: BuSize.touch), child: Align(alignment: AlignmentDirectional.centerStart, child: label)),
                        ),
                      ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.chevronUp),
                tooltip: l.p60MoveUp(name),
                onPressed: canUp ? () => onMove(-1) : null,
              ),
              IconButton(
                icon: const Icon(LucideIcons.chevronDown),
                tooltip: l.p60MoveDown(name),
                onPressed: canDown ? () => onMove(1) : null,
              ),
              Semantics(label: name, child: Switch(value: visible, onChanged: onVisible)),
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
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final v = controller.value;
        final l = context.l10n;
        final full = v.shortcutOn.length >= HomeLayout.maxShortcuts;
        return ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: v.shortcutOrder.length,
          proxyDecorator: (child, i, a) => _lifted(context, child, i, a),
          onReorderStart: (_) => BuHaptics.selection(),
          onReorderItem: (a, b) {
            BuHaptics.light();
            controller.update((x) => x.reorderShortcut(a, b));
          },
          itemBuilder: (context, i) {
            final s = v.shortcutOrder[i];
            final on = v.shortcutOn.contains(s);
            final t = context.bu;
            final name = homeShortcutLabel(l, s);
            // Son açık kısayol kapatılamaz; 5 doluyken kapalılar açılamaz.
            final canToggle = on ? v.shortcutOn.length > 1 : !full;
            return Padding(
              key: ValueKey(s.id),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: DecoratedBox(
                decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.md)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
                    child: Row(children: [
                      ExcludeSemantics(child: Icon(LucideIcons.gripVertical, size: 20, color: t.mut)),
                      const SizedBox(width: 8),
                      ExcludeSemantics(child: Icon(homeShortcutIcon(s), size: 20, color: on ? t.info : t.mut)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.heading.copyWith(fontSize: 15, color: on ? t.ink : t.mut))),
                      Semantics(
                        label: name,
                        child: Switch(
                          value: on,
                          onChanged: canToggle
                              ? (v2) {
                                  BuHaptics.selection();
                                  controller.update((x) => x.setShortcut(s, v2));
                                }
                              : null,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

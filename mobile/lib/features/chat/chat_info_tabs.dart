import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/typography.dart';

/// Sohbet bilgisi bölümleri.
enum InfoSection { members, media, settings }

String infoSectionLabel(InfoSection s) => switch (s) {
      InfoSection.members => 'Üyeler',
      InfoSection.media => 'Medya',
      InfoSection.settings => 'Ayarlar',
    };

/// Eşit genişlikli, animasyonlu göstergeli segment çubuğu.
class InfoSegmentBar extends StatelessWidget {
  const InfoSegmentBar(
      {super.key,
      required this.sections,
      required this.active,
      required this.onSelect});

  final List<InfoSection> sections;
  final InfoSection active;
  final ValueChanged<InfoSection> onSelect;

  static const height = 56.0;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final n = sections.length;
    final idx = sections.indexOf(active).clamp(0, n - 1);
    return Container(
      height: height,
      color: t.bg,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
            color: t.sf2, borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(3),
        child: Stack(children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment(n == 1 ? 0 : -1 + 2 * idx / (n - 1), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.sf,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.bd),
                ),
              ),
            ),
          ),
          Row(children: [
            for (final s in sections)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: s == active,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelect(s),
                    child: Center(
                      child: Text(infoSectionLabel(s),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BuType.label
                              .copyWith(color: s == active ? t.ink : t.mut)),
                    ),
                  ),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

/// Kaydırırken üstte sabit kalan segment çubuğu.
class InfoSegmentDelegate extends SliverPersistentHeaderDelegate {
  InfoSegmentDelegate(
      {required this.barKey,
      required this.sections,
      required this.active,
      required this.onSelect});

  final Key barKey;
  final List<InfoSection> sections;
  final InfoSection active;
  final ValueChanged<InfoSection> onSelect;

  @override
  double get minExtent => InfoSegmentBar.height;
  @override
  double get maxExtent => InfoSegmentBar.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      KeyedSubtree(
        key: barKey,
        child: InfoSegmentBar(
            sections: sections, active: active, onSelect: onSelect),
      );

  @override
  bool shouldRebuild(covariant InfoSegmentDelegate old) =>
      old.active != active ||
      old.sections.length != sections.length ||
      old.barKey != barKey;
}

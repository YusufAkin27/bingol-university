import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import 'sohbety_widgets.dart';

/// Sohbet bilgisi sekmeleri.
enum InfoSection { members, media, settings }

String infoSectionLabel(BuildContext context, InfoSection s) => switch (s) {
      InfoSection.members => context.l10n.chatDetailMembers,
      InfoSection.media => context.l10n.chatDetailMedia,
      InfoSection.settings => context.l10n.chatDetailSettings,
    };

/// Eşit genişlikli sekme çubuğu (tasarım: beyaz zemin, seçili sekme kırmızı).
class InfoSegmentBar extends StatelessWidget {
  const InfoSegmentBar(
      {super.key,
      required this.sections,
      required this.active,
      required this.onSelect});

  final List<InfoSection> sections;
  final InfoSection active;
  final ValueChanged<InfoSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return SohbetyTabs(
      labels: [for (final s in sections) infoSectionLabel(context, s)],
      selected: sections.indexOf(active).clamp(0, sections.length - 1),
      onSelect: (i) => onSelect(sections[i]),
    );
  }
}

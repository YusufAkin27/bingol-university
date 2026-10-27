import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'message_actions.dart';

/// Sohbet listesi satırına uzun basınca açılan menü (mesaj menüsüyle aynı tasarım dili).
/// Dönüş: `mute` | `unmute` | `archive` | `unarchive` | `delete`; kapatılırsa null.
/// [canDelete] false ise (kulüp/etkinlik odaları) "Sil" satırı hiç gösterilmez.
Future<String?> showConversationMenu(
  BuildContext context, {
  required Rect anchor,
  required Widget preview,
  required bool muted,
  required bool archived,
  required bool canDelete,
}) {
  return showMessageActions(
    context,
    anchor: anchor,
    preview: preview,
    mine: false,
    actions: [
      if (muted)
        const MessageAction('unmute', 'Sesi aç', LucideIcons.bell)
      else
        const MessageAction('mute', 'Sessize al', LucideIcons.bellOff),
      if (archived)
        const MessageAction('unarchive', 'Arşivden çıkar', LucideIcons.archive)
      else
        const MessageAction('archive', 'Arşivle', LucideIcons.archive),
      if (canDelete)
        const MessageAction('delete', 'Sil', LucideIcons.trash2, danger: true),
    ],
  );
}

/// Sessize alma süresi: '480' (8 saat), '10080' (1 hafta), 'forever'; vazgeçilirse null.
Future<String?> pickMuteDuration(BuildContext context) {
  final t = context.bu;
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: t.sf,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        BuMenuRow(
            icon: LucideIcons.bellOff,
            label: '8 saat',
            showChevron: false,
            onTap: () => Navigator.pop(c, '480')),
        BuMenuRow(
            icon: LucideIcons.bellOff,
            label: '1 hafta',
            showChevron: false,
            onTap: () => Navigator.pop(c, '10080')),
        BuMenuRow(
            icon: LucideIcons.bellOff,
            label: 'Her zaman',
            showChevron: false,
            onTap: () => Navigator.pop(c, 'forever')),
        const SizedBox(height: 8),
      ]),
    ),
  );
}

/// Silme onayı (yanlışlıkla silmeyi önler). Yalnızca "Sil" true döndürür.
Future<bool> confirmDeleteConversation(BuildContext context,
    {required bool group}) async {
  final t = context.bu;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: t.sf,
      title: Text('Sohbet silinsin mi?',
          style: BuType.heading.copyWith(color: t.ink)),
      content: Text(
          group
              ? 'Gruptan çıkıp bu sohbeti sileceksin.'
              : 'Bu sohbet yalnızca senin için silinecek. Karşı taraf etkilenmez.',
          style: BuType.body.copyWith(color: t.mut)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text('Vazgeç', style: BuType.bodyStrong.copyWith(color: t.ink)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text('Sil', style: BuType.bodyStrong.copyWith(color: t.danger)),
        ),
      ],
    ),
  );
  return ok == true;
}

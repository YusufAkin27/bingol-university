import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
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
        MessageAction('unmute', context.l10n.chatInfoUnmute, LucideIcons.bell)
      else
        MessageAction('mute', context.l10n.chatInfoMute, LucideIcons.bellOff),
      if (archived)
        MessageAction('unarchive', context.l10n.chatInfoUnarchive, LucideIcons.archive)
      else
        MessageAction('archive', context.l10n.chatInfoArchive, LucideIcons.archive),
      if (canDelete)
        MessageAction('delete', context.l10n.chatInfoDelete, LucideIcons.trash2, danger: true),
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
            label: context.l10n.chatInfoMute8h,
            showChevron: false,
            onTap: () => Navigator.pop(c, '480')),
        BuMenuRow(
            icon: LucideIcons.bellOff,
            label: context.l10n.chatInfoMute1w,
            showChevron: false,
            onTap: () => Navigator.pop(c, '10080')),
        BuMenuRow(
            icon: LucideIcons.bellOff,
            label: context.l10n.chatInfoMuteForever,
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
      title: Text(context.l10n.chatInfoDeleteConvTitle,
          style: BuType.heading.copyWith(color: t.ink)),
      content: Text(
          group
              ? context.l10n.chatInfoDeleteConvGroup
              : context.l10n.chatInfoDeleteConvDirect,
          style: BuType.body.copyWith(color: t.mut)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text(context.l10n.chatInfoCancel, style: BuType.bodyStrong.copyWith(color: t.ink)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(context.l10n.chatInfoDelete, style: BuType.bodyStrong.copyWith(color: t.danger)),
        ),
      ],
    ),
  );
  return ok == true;
}

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'club_actions.dart';
import 'club_ref_widgets.dart';

/// Kulüp detayının alt sayfaları ve diyalogları (P11): seçenekler, gönderi işlemleri, kulüp silme son onayı.

/// Kulüp seçenekleri (⋯) açılır menüsü (referans 28-05): yönetim (yalnız yetkili), ayrılma (üye), şikâyet (sahip değilse).
/// Seçilen eylemin kodunu döner (`event|edit|requests|members|cover|delete|leave|report`); kapatılırsa null.
Future<String?> showClubMenu(
  BuildContext anchor, {
  required bool isManager,
  required bool isOwner,
  required bool isMember,
  required int pendingCount,
}) {
  final l = anchor.l10n;
  return showClubDropdown(anchor, [
    if (isManager) ...[
      ClubMenuEntry('edit', LucideIcons.pencilLine, l.clubEdit),
      ClubMenuEntry('requests', LucideIcons.userPlus, l.clubRequests, count: pendingCount),
      ClubMenuEntry('members', LucideIcons.userCog, l.clubManageMembers),
      ClubMenuEntry('event', LucideIcons.calendarPlus, l.eventListCreate),
      ClubMenuEntry('cover', LucideIcons.imagePlus, l.clubChangeCover),
    ],
    if (isOwner) ClubMenuEntry('delete', LucideIcons.trash2, l.clubDeleteClub, danger: true, dividerBefore: true),
    if (!isOwner) ClubMenuEntry('report', LucideIcons.flag, l.clubReportClub, danger: true, dividerBefore: isManager),
    if (isMember) ClubMenuEntry('leave', LucideIcons.logOut, l.clubLeave, danger: true),
  ]);
}

/// Gönderi işlemleri (referans 29-05): sabitle / sil / şikâyet. Seçilen eylem (`pin|delete|report`) ya da null.
Future<String?> showPostMenuSheet(
  BuildContext context, {
  required bool canPin,
  required bool pinned,
  required bool canDelete,
  required bool canReport,
}) {
  final l = context.l10n;
  return BuSheet.show<String>(
    context,
    title: l.clubPostActions,
    builder: (c) {
      void pick(String v) => Navigator.of(c).pop(v);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canPin)
            ClubSheetRow(
              icon: pinned ? LucideIcons.pinOff : LucideIcons.pin,
              title: pinned ? l.clubUnpin : l.clubPin,
              subtitle: pinned ? l.p11PostUnpinSub : l.p11PostPinSub,
              circle: true,
              showChevron: false,
              onTap: () => pick('pin'),
            ),
          if (canDelete)
            ClubSheetRow(
              icon: LucideIcons.trash2,
              title: l.clubDelete,
              subtitle: l.p11PostDeleteSub,
              circle: true,
              danger: true,
              showChevron: false,
              onTap: () => pick('delete'),
            ),
          if (canReport)
            ClubSheetRow(
              icon: LucideIcons.flag,
              title: l.clubReport,
              subtitle: l.p11PostReportSub,
              circle: true,
              showChevron: false,
              onTap: () => pick('report'),
            ),
          const SizedBox(height: 12),
          ClubBtn(label: l.clubCancel, onPressed: () => Navigator.of(c).pop()),
          const SizedBox(height: 8),
        ],
      );
    },
  );
}

/// Gönderi silme onayı (A29).
Future<bool> confirmDeletePost(BuildContext context) => confirmDialog(
      context,
      title: context.l10n.clubDeletePostTitle,
      message: context.l10n.clubDeletePostMessage,
      confirmLabel: context.l10n.clubDelete,
      danger: true,
      icon: LucideIcons.trash2,
      confirmIcon: LucideIcons.trash2,
    );

/// Kulübü silmeden önce son onay (A28): uyarı + kulüp adını yazma. `true` = silinsin.
class ClubDeleteDialog extends StatefulWidget {
  const ClubDeleteDialog({super.key, required this.name});

  final String name;

  static Future<bool> show(BuildContext context, String name) async =>
      await BuDialog.show<bool>(context, builder: (_) => ClubDeleteDialog(name: name)) == true;

  @override
  State<ClubDeleteDialog> createState() => _ClubDeleteDialogState();
}

class _ClubDeleteDialogState extends State<ClubDeleteDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final match = _c.text.trim() == widget.name.trim();
    final prompt = l.clubDeleteTypeName(widget.name);
    final promptStyle = tx.bodyMedium!.copyWith(color: t.ink, height: 1.4);
    final at = prompt.lastIndexOf(widget.name);
    return ClubDialogCard(
      icon: LucideIcons.trash2,
      title: l.clubDeleteClub,
      message: l.clubDeleteBody,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.md)),
            child: at < 0
                ? Text(prompt, textAlign: TextAlign.center, style: promptStyle)
                : Text.rich(
                    TextSpan(children: [
                      TextSpan(text: prompt.substring(0, at)),
                      TextSpan(text: widget.name, style: TextStyle(color: t.pr, fontWeight: FontWeight.w800)),
                      TextSpan(text: prompt.substring(at + widget.name.length)),
                    ]),
                    textAlign: TextAlign.center,
                    style: promptStyle,
                  ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: l.clubNameHint),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
            child: Text(l.p11CaseSensitive, style: tx.labelSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      actions: [
        ClubBtn(label: l.clubCancel, onPressed: () => Navigator.pop(context, false)),
        ClubBtn(
          label: l.clubDelete,
          icon: LucideIcons.trash2,
          kind: ClubBtnKind.danger,
          onPressed: match ? () => Navigator.pop(context, true) : null,
        ),
      ],
    );
  }
}

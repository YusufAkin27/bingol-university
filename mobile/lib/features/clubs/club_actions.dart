import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'club_ref_widgets.dart';

/// Kulüp rolü yönetici mi (sahip / yönetici / moderatör)?
bool isClubManagerRole(String? role) => role == 'OWNER' || role == 'ADMIN' || role == 'MODERATOR';

/// Onay diyaloğu (A26, referans 29-02 / 27-02): simgeli kart; [danger] true ise onay düğmesi kırmızıdır.
/// [leading] true: simge solda (üye çıkar/yasakla); [boldName] metnin başındaki adı kalın yazar.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
  IconData? icon,
  IconData? confirmIcon,
  bool leading = false,
  String? boldName,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => ClubDialogCard(
      icon: icon ?? (danger ? LucideIcons.logOut : LucideIcons.circleHelp),
      title: title,
      message: message,
      boldName: boldName,
      leading: leading,
      danger: danger,
      actions: [
        ClubBtn(label: context.l10n.clubCancel, onPressed: () => Navigator.of(ctx).pop(false)),
        ClubBtn(
          label: confirmLabel,
          icon: confirmIcon,
          kind: danger ? ClubBtnKind.danger : ClubBtnKind.primary,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Kulüpten ayrılma akışı: onay -> `DELETE /communities/{id}/membership`.
/// Başarıda sohbet listesi yenilensin diye [AppBadges.conversationsDirty] artırılır. Dönüş: ayrıldı mı.
/// Sahip için ayrılma yerine açıklama gösterilir (A27; sunucu `OWNER_CANNOT_LEAVE` dönerse de aynı mesaj).
Future<bool> leaveClubFlow(
  BuildContext context,
  Session session, {
  required int communityId,
  required String clubName,
  bool isOwner = false,
}) async {
  final l10n = context.l10n;
  final ownerInfo = l10n.clubOwnerCannotLeave;
  if (isOwner) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => ClubDialogCard(
        icon: LucideIcons.shieldAlert,
        title: l10n.clubCannotLeaveTitle,
        message: ownerInfo,
        badge: LucideIcons.info,
        actions: [ClubBtn(label: l10n.clubOk, kind: ClubBtnKind.ink, onPressed: () => Navigator.of(ctx).pop())],
      ),
    );
    return false;
  }
  final ok = await confirmDialog(
    context,
    title: l10n.clubLeave,
    message: l10n.clubLeaveMessage(clubName.isEmpty ? l10n.clubThisClub : clubName),
    confirmLabel: l10n.clubLeaveConfirm,
    danger: true,
    icon: LucideIcons.logOut,
  );
  if (!ok || !context.mounted) return false;
  void toast(String m) {
    if (context.mounted) BuToast.show(context, m, kind: BuToastKind.error);
  }

  try {
    await session.api.delete('/communities/$communityId/membership');
    session.badges.conversationsDirty.value++;
    return true;
  } on ApiError catch (e) {
    toast(e.code == 'OWNER_CANNOT_LEAVE' ? ownerInfo : errorText(e));
  } catch (e) {
    toast(errorText(e));
  }
  return false;
}

/// Soluk kırmızı menü satırı yazısı.
TextStyle dangerItemStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodyLarge!.copyWith(color: context.bu.danger);

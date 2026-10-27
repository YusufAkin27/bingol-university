import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';

/// Kulüp rolü yönetici mi (sahip / yönetici / moderatör)?
bool isClubManagerRole(String? role) => role == 'OWNER' || role == 'ADMIN' || role == 'MODERATOR';

/// Basit onay diyaloğu; [danger] true ise onay düğmesi soluk kırmızıdır.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  final t = context.bu;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirmLabel, style: danger ? TextStyle(color: t.pr) : null),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Kulüpten ayrılma akışı: onay -> `DELETE /communities/{id}/membership`.
/// Başarıda sohbet listesi yenilensin diye [AppBadges.conversationsDirty] artırılır. Dönüş: ayrıldı mı.
/// Sahip için ayrılma yerine açıklama gösterilir (sunucu `OWNER_CANNOT_LEAVE` dönerse de aynı mesaj).
Future<bool> leaveClubFlow(
  BuildContext context,
  Session session, {
  required int communityId,
  required String clubName,
  bool isOwner = false,
}) async {
  const ownerInfo = 'Kulüp sahibi ayrılamaz. Önce sahipliği devret ya da kulübü sil.';
  if (isOwner) {
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kulüpten ayrılamazsın'),
        content: const Text(ownerInfo),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tamam'))],
      ),
    );
    return false;
  }
  final ok = await confirmDialog(
    context,
    title: 'Kulüpten ayrıl',
    message: '${clubName.isEmpty ? 'Bu kulüp' : clubName} kulübünden ayrılmak istiyor musun? '
        'Kulüp sohbetinden de çıkarılacaksın ve sohbet listenden silinecek.',
    confirmLabel: 'Ayrıl',
    danger: true,
  );
  if (!ok || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await session.api.delete('/communities/$communityId/membership');
    session.badges.conversationsDirty.value++;
    return true;
  } on ApiError catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.code == 'OWNER_CANNOT_LEAVE' ? ownerInfo : errorText(e))));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
  }
  return false;
}

/// Soluk kırmızı menü satırı yazısı.
TextStyle dangerItemStyle(BuildContext context) => BuType.body.copyWith(color: context.bu.pr);

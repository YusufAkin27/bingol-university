import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';

/// Çıkış öncesi: gönderilmemiş (bekleyen/başarısız) mesaj varsa silineceğini söyleyip onay ister.
/// Normal çıkışta bekleyen mesaj kuyruğu ve ek kopyaları silinir ([Session.signOut]); kullanıcı sürpriz yaşamasın.
/// Kuyruk boşsa hiçbir şey sormaz ve true döner.
Future<bool> confirmUnsentLoss(BuildContext context, Session session) async {
  final n = session.api.outbox?.items.length ?? 0;
  if (n <= 0) return true;
  final l = context.l10n;
  return BuDialog.confirm(
    context,
    title: l.signOutPendingTitle,
    message: l.signOutPendingBody('$n'),
    confirmLabel: l.profileSignOut,
    cancelLabel: l.profileCancel,
    destructive: true,
    icon: BuIcons.logOut,
  );
}

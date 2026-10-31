import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';

/// Takip akışının onay sayfaları (ortak [BuConfirmSheet]). Hepsi onaylanırsa true, vazgeçilirse false döner.

/// Takibi bırak. GİZLİ hesapta yeniden istek gerektiği uyarılır.
Future<bool> confirmUnfollow(BuildContext context, {required bool isPrivate}) {
  final l = context.l10n;
  return BuConfirmSheet.show(
    context,
    title: l.frqUnfollowTitle,
    message: isPrivate ? l.frqUnfollowBodyPrivate : l.frqUnfollowBody,
    confirmLabel: l.frqUnfollowConfirm,
    destructive: true,
    icon: LucideIcons.userMinus,
  );
}

/// Gönderilmiş takip isteğini geri çek.
Future<bool> confirmCancelRequest(BuildContext context) {
  final l = context.l10n;
  return BuConfirmSheet.show(
    context,
    title: l.frqCancelReqTitle,
    message: l.frqCancelReqBody,
    confirmLabel: l.frqCancelReqConfirm,
    icon: LucideIcons.clock,
  );
}

/// Gizli hesabı kapatırken bilgi: bekleyen istekler otomatik kabul edilir (açarken onay yok).
Future<bool> confirmPrivateOff(BuildContext context) {
  final l = context.l10n;
  return BuConfirmSheet.show(
    context,
    title: l.frqPrivateOffTitle,
    message: l.frqPrivateOffBody,
    confirmLabel: l.frqPrivateOffConfirm,
    icon: LucideIcons.lockOpen,
  );
}

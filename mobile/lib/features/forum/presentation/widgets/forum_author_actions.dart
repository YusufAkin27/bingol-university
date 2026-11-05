import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../core/session.dart';
import '../../../../widgets/bu.dart';
import '../../data/forum_api.dart';
import '../../data/forum_models.dart';

/// Forum yazarı engelleme / sessize alma akışları (onay + sonuç bildirimi). Kimlik HİÇBİR adımda gösterilmez:
/// engelleme içerik üzerinden sunucuda çözülür (anonim yazar dahil), sessize alma yalnız kimliği bilinen yazar içindir.
abstract final class ForumAuthorActions {
  /// Konu ya da yorum yazarını engeller (onay penceresi + sonuç). Engellendiyse `true`.
  /// [targetType] `FORUM_TOPIC` | `FORUM_COMMENT`.
  static Future<bool> blockAuthor(
    BuildContext context,
    Session session, {
    required String targetType,
    required int targetId,
  }) async {
    final l = context.l10n;
    final ok = await BuConfirmSheet.show(
      context,
      title: l.forumReportBlockTitle,
      message: l.forumReportBlockBody,
      confirmLabel: l.forumReportBlockConfirm,
      destructive: true,
      icon: BuIcons.ban,
    );
    if (!ok || !context.mounted) return false;
    final api = ForumApi(session);
    try {
      if (targetType == kForumReportTopic) {
        await api.blockTopicAuthor(targetId);
      } else {
        await api.blockCommentAuthor(targetId);
      }
    } catch (e) {
      if (context.mounted) BuToast.show(context, errorText(e), kind: BuToastKind.error);
      return false;
    }
    if (context.mounted) BuToast.show(context, l.forumReportBlocked, kind: BuToastKind.success);
    return true;
  }

  /// Kimliği bilinen (anonim olmayan) kullanıcıyı sessize alır; [name] onay metnindedir.
  static Future<bool> muteUser(
    BuildContext context,
    Session session, {
    required int userId,
    required String name,
  }) async {
    final l = context.l10n;
    final ok = await BuConfirmSheet.show(
      context,
      title: l.forumReportMuteTitle,
      message: l.forumReportMuteBody(name),
      confirmLabel: l.forumReportMuteConfirm,
      icon: BuIcons.bellOff,
    );
    if (!ok || !context.mounted) return false;
    try {
      await ForumApi(session).muteUser(userId, true);
    } catch (e) {
      if (context.mounted) BuToast.show(context, errorText(e), kind: BuToastKind.error);
      return false;
    }
    if (context.mounted) BuToast.show(context, l.forumReportMuted, kind: BuToastKind.success);
    return true;
  }
}

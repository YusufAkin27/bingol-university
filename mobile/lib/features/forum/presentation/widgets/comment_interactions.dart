import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/api.dart' show ApiError;
import '../../../../core/icons/bu_icons.dart';
import '../../../../core/locale_controller.dart';
import '../../../../core/session.dart';
import '../../../../widgets/bu_overlays.dart';
import '../../../profile/user_profile_page.dart';
import '../../data/forum_api.dart';
import '../../data/forum_models.dart';
import '../../forum_routes.dart' show openReportSheet;
import 'comment_actions_sheet.dart';
import 'comment_card.dart';
import 'comment_controller.dart';
import 'comment_tree.dart';
import 'mod_remove_sheet.dart';
import 'topic_detail_share.dart';

/// Konu ekranı ile "yanıt zinciri" ekranının ORTAK yorum etkileşimleri: yanıtla / düzenle / sil / beğen / kaydet /
/// kopyala / paylaş / şikâyet / engelle ve yazma çubuğu bağlantıları. Ekran yalnız durumu ve yenileme kancalarını verir.
///
/// Yetki yalnız gösterimde (`mine`); sunucu reddederse çevrilmiş hata gösterilir. Eşzamanlı silme/düzenleme (404/409)
/// kısa bir mesajla listeyi yeniler.
mixin CommentInteractions<T extends StatefulWidget> on State<T> {
  Session get session;
  CommentsController get cc;
  ForumApi get api;

  /// Konu açık mı (kilitli/kaldırılmış değil).
  bool get canComment;

  /// Sunucu konunun kilitlendiğini söylerse konuyu yeniden çekmek için.
  Future<void> refreshTopic();

  /// Yorum ağacını sessizce yeniler (eşzamanlı değişiklik sonrası).
  Future<void> refreshComments() => cc.load(silent: true);

  CommentNode? replyTo;
  CommentNode? editing;

  /// Yeni yorum yazılınca (ekran kaydırıp vurgulayabilir).
  void onCommentCreated(CommentNode n) {}

  void toast(String msg, {BuToastKind kind = BuToastKind.info}) {
    if (mounted) BuToast.show(context, msg, kind: kind);
  }

  late final CommentCardActions cardActions = CommentCardActions(
    onReply: startReply,
    onMore: openActions,
    onLike: like,
    onOpenProfile: openProfile,
  );

  void startReply(CommentNode n) {
    if (!canComment || n.deleted) return;
    setState(() {
      replyTo = n;
      editing = null;
    });
  }

  void startEdit(CommentNode n) {
    setState(() {
      editing = n;
      replyTo = null;
    });
  }

  void cancelTarget() => setState(() {
        replyTo = null;
        editing = null;
      });

  void openProfile(CommentNode n) {
    final id = n.author?.userId;
    if (id == null) return;
    openUserProfile(context, session, userId: id, name: n.author?.displayName, avatarUrl: n.author?.avatarUrl);
  }

  /// Hata → kısa Türkçe mesaj. 404/409 için listeyi yeniler.
  Future<void> handleError(Object e, {bool refresh = true}) async {
    final l = context.l10n;
    if (e is ApiError) {
      if (e.status == 404 || e.status == 410) {
        toast(l.forumCommentGone, kind: BuToastKind.warning);
        if (refresh) await refreshComments();
        return;
      }
      if (e.status == 409) {
        if (e.code == 'FORUM_TOPIC_LOCKED') {
          toast(errorText(e), kind: BuToastKind.warning);
          await refreshTopic();
          return;
        }
        toast(l.forumCommentConflict, kind: BuToastKind.warning);
        if (refresh) await refreshComments();
        return;
      }
    }
    toast(errorText(e), kind: BuToastKind.error);
  }

  Future<void> like(CommentNode n) async {
    try {
      await cc.toggleLike(n);
    } catch (e) {
      if (mounted) await handleError(e);
    }
  }

  Future<void> openActions(CommentNode n) async {
    final action = await showCommentActionsSheet(context, node: n, canReply: canComment);
    if (action == null || !mounted) return;
    final l = context.l10n;
    switch (action) {
      case CommentAction.reply:
        startReply(n);
      case CommentAction.edit:
        startEdit(n);
      case CommentAction.delete:
        await _confirmDelete(n);
      case CommentAction.copy:
        await Clipboard.setData(ClipboardData(text: n.body ?? ''));
        toast(l.forumCommentCopied);
      case CommentAction.share:
        await shareForumLink(forumCommentLink(n.id));
      case CommentAction.like:
        await like(n);
      case CommentAction.save:
        try {
          await cc.toggleSave(n);
          toast(n.savedByMe ? l.forumCommentSaved : l.forumCommentUnsaved);
        } catch (e) {
          if (mounted) await handleError(e, refresh: false);
        }
      case CommentAction.report:
        await openReportSheet(context, session,
            targetType: kForumReportComment, targetId: n.id, anonymousAuthor: n.anonymous || (n.author?.anonymous ?? false));
      case CommentAction.block:
        await _confirmBlock(n);
      case CommentAction.modRemove:
        await _modRemove(n);
    }
  }

  Future<void> _confirmDelete(CommentNode n) async {
    final l = context.l10n;
    final ok = await BuConfirmSheet.show(
      context,
      title: l.forumCommentDeleteTitle,
      message: l.forumCommentDeleteBody,
      confirmLabel: l.forumCommentDeleteConfirm,
      destructive: true,
      icon: BuIcons.trash2,
    );
    if (!ok || !mounted) return;
    try {
      await cc.remove(n);
      if (editing?.id == n.id || replyTo?.id == n.id) cancelTarget();
      toast(l.forumCommentDeleted, kind: BuToastKind.success);
    } catch (e) {
      if (mounted) await handleError(e);
    }
  }

  Future<void> _modRemove(CommentNode n) async {
    final l = context.l10n;
    final reason = await showForumModRemoveSheet(context, title: l.forumModReasonTitle);
    if (reason == null || !mounted) return;
    try {
      await api.moderateComment(n.id, 'REMOVE', reason: reason);
      toast(l.forumModRemovedDone, kind: BuToastKind.success);
      await refreshComments();
    } catch (e) {
      if (mounted) await handleError(e, refresh: false);
    }
  }

  Future<void> _confirmBlock(CommentNode n) async {
    final l = context.l10n;
    final ok = await BuConfirmSheet.show(
      context,
      title: l.forumCommentBlockTitle,
      message: l.forumCommentBlockBody,
      confirmLabel: l.forumCommentBlockConfirm,
      destructive: true,
      icon: BuIcons.ban,
    );
    if (!ok || !mounted) return;
    try {
      await api.blockCommentAuthor(n.id);
      toast(l.forumCommentBlocked, kind: BuToastKind.success);
      await refreshComments();
    } catch (e) {
      if (mounted) await handleError(e, refresh: false);
    }
  }

  // ---- Yazma çubuğu bağlantıları ---------------------------------------------------------------------------

  /// Yorum gönderimi; [defaultParent] zincir ekranında kök yorumdur. Hata fırlatır (yazma çubuğu metni korur).
  Future<void> sendComment(String body, bool anonymous, String key, {CommentNode? defaultParent}) async {
    final l = context.l10n;
    final parent = replyTo ?? defaultParent;
    final n = await cc.create(body: body, parent: parent, anonymous: anonymous, key: key);
    if (!mounted) return;
    setState(() => replyTo = null);
    toast(parent == null ? l.forumCommentSent : l.forumCommentReplySent, kind: BuToastKind.success);
    onCommentCreated(n);
  }

  Future<void> saveEdit(String body) async {
    final target = editing;
    if (target == null) return;
    await cc.edit(target, body);
    if (!mounted) return;
    setState(() => editing = null);
    toast(context.l10n.forumCommentEditDone, kind: BuToastKind.success);
  }

  /// Yazma çubuğunun hata kancası: düzenleme hedefi kaybolduysa (404) düzenlemeyi bırakır.
  void composerError(Object e) {
    if (e is ApiError && (e.status == 404 || e.status == 410) && editing != null) {
      setState(() => editing = null);
    }
    handleError(e);
  }
}

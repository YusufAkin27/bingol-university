import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/locale_controller.dart';
import '../../../../core/session.dart';
import '../../../../widgets/bu.dart';
import '../../data/forum_api.dart';
import '../../data/forum_models.dart';
import '../../forum_routes.dart' show openReportSheet;
import 'forum_state_views.dart';

/// Konu bağlantısını paylaşır. `features/share` tarafında FORUM türü gelene kadar bağlantı panoya kopyalanır
/// (MB-D paylaşım sayfasını bağlayınca yalnız bu fonksiyon değişir).
Future<void> shareForumTopic(BuildContext context, Session session, TopicSummary topic) async {
  final l = context.l10n;
  await Clipboard.setData(ClipboardData(text: forumTopicLink(topic.id)));
  if (context.mounted) BuToast.show(context, l.forumHomeLinkCopied, kind: BuToastKind.success);
}

/// Kaydet / kaydı kaldır (iyimser değil: çağıran iyimser durumu zaten gösterir). Başarısızlıkta hata fırlatır.
Future<bool> setTopicSaved(ForumApi api, TopicSummary topic, bool saved) => api.bookmarkTopic(topic.id, saved);

/// Üç nokta menüsü eylemi sonucu: yazarın içeriği listeden düşürülsün mü.
enum TopicMenuResult { none, hideTopic, hideAuthor }

/// Konu üç nokta menüsü (alt sayfa): bağlantıyı kopyala, kaydet/kaldır, şikâyet et, sessize al (kimliği bilinen), yazarı
/// engelle (anonim de olsa; kimlik sızmaz). Kendi konusunda şikâyet/engelleme gösterilmez.
/// Dönen değer: listeden düşürülecekse [TopicMenuResult.hideAuthor]/[TopicMenuResult.hideTopic].
Future<TopicMenuResult> showTopicMenu(
  BuildContext context, {
  required Session session,
  required ForumApi api,
  required TopicSummary topic,
  required void Function(TopicSummary updated) onChanged,
}) async {
  final choice = await BuSheet.show<_Choice>(
    context,
    builder: (ctx) => _MenuBody(topic: topic),
  );
  if (choice == null || !context.mounted) return TopicMenuResult.none;
  final l = context.l10n;
  switch (choice) {
    case _Choice.copy:
      await shareForumTopic(context, session, topic);
    case _Choice.save:
      final want = !topic.savedByMe;
      onChanged(topic.copyWith(savedByMe: want));
      try {
        final ok = await setTopicSaved(api, topic, want);
        onChanged(topic.copyWith(savedByMe: ok));
      } catch (_) {
        onChanged(topic);
        if (context.mounted) BuToast.show(context, l.forumHomeSaveFailed, kind: BuToastKind.warning);
      }
    case _Choice.report:
      await openReportSheet(context, session,
          targetType: kForumReportTopic, targetId: topic.id, anonymousAuthor: topic.author.anonymous);
    case _Choice.mute:
      final ok = await BuDialog.confirm(context,
          title: l.forumHomeMuteTitle, message: l.forumHomeMuteBody, confirmLabel: l.forumHomeMuteConfirm);
      if (!ok || !context.mounted) return TopicMenuResult.none;
      try {
        await api.muteUser(topic.author.userId!, true);
        if (context.mounted) BuToast.show(context, l.forumHomeMuted, kind: BuToastKind.success);
        return TopicMenuResult.hideAuthor;
      } catch (e) {
        if (context.mounted) BuToast.show(context, forumErrorText(e, l), kind: BuToastKind.error);
      }
    case _Choice.block:
      final ok = await BuDialog.confirm(context,
          title: l.forumHomeBlockTitle,
          message: l.forumHomeBlockBody,
          confirmLabel: l.forumHomeBlockConfirm,
          destructive: true,
          icon: BuIcons.ban);
      if (!ok || !context.mounted) return TopicMenuResult.none;
      try {
        await api.blockTopicAuthor(topic.id);
        if (context.mounted) BuToast.show(context, l.forumHomeBlocked, kind: BuToastKind.success);
        // Anonim yazarın kimliği bilinmez: yalnız bu konu düşer; kimliği bilinen yazarın tüm konuları düşer.
        return topic.author.userId == null ? TopicMenuResult.hideTopic : TopicMenuResult.hideAuthor;
      } catch (e) {
        if (context.mounted) BuToast.show(context, forumErrorText(e, l), kind: BuToastKind.error);
      }
  }
  return TopicMenuResult.none;
}

enum _Choice { copy, save, report, mute, block }

class _MenuBody extends StatelessWidget {
  const _MenuBody({required this.topic});

  final TopicSummary topic;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    Widget row(_Choice c, IconData icon, String label, {bool danger = false}) => BuListTile(
          key: ValueKey('forum-menu-${c.name}'),
          title: label,
          danger: danger,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 4, vertical: 6),
          leading: Icon(icon, size: 22, color: danger ? t.danger : t.ink),
          onTap: () => Navigator.of(context).pop(c),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      row(_Choice.copy, BuIcons.copy, l.forumHomeMenuCopyLink),
      row(_Choice.save, topic.savedByMe ? BuIcons.bookmarkFilled : BuIcons.bookmark,
          topic.savedByMe ? l.forumHomeUnsave : l.forumHomeSave),
      if (!topic.mine) ...[
        row(_Choice.report, BuIcons.flag, l.forumHomeMenuReport, danger: true),
        if (!topic.author.anonymous && topic.author.userId != null) row(_Choice.mute, BuIcons.eyeOff, l.forumHomeMenuMute),
        row(_Choice.block, BuIcons.ban, l.forumHomeMenuBlock, danger: true),
      ],
    ]);
  }
}

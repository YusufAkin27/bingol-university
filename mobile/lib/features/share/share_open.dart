import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../events/event_detail_page.dart';
import '../forum/forum_routes.dart' show ForumApi, openTopicDetail;
import '../news/news_detail_page.dart';
import '../posts/post_routes.dart';
import 'share_models.dart';

/// Paylaşılan içeriğin ilgili sayfasını açar: sohbet kartına dokunuş ve derin bağlantı (gelen link) BU TEK yoldan
/// geçer. Hedef sayfalar bulunamayan/erişilemeyen içeriği kendi "bulunamadı" durumuyla gösterir; burada beklenmeyen
/// bir hata olursa anlaşılır bir bildirim çıkar (çökme yok).
///
/// p/r -> gönderi detayı (Reels de videolu gönderi olarak oynar), n -> haber/duyuru detayı, e -> etkinlik detayı,
/// f -> forum konusu, fc -> forum yorumu (konuya gidip yoruma kaydırır).
Future<void> openShared(BuildContext context, Session session, ShareTarget target, {ShareInfo? info}) async {
  try {
    switch (target.type) {
      case ShareType.post:
      case ShareType.reel:
        await openPostDetail(context, session, target.id);
      case ShareType.news:
        await Navigator.of(context).push<void>(MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'news_detail'),
          builder: (_) => NewsDetailPage(
            session: session,
            item: <String, dynamic>{
              'id': target.id,
              if (info?.title != null) 'title': info!.title,
              'type': (info?.isAnnouncement ?? false) ? 'DUYURU' : 'HABER',
            },
          ),
        ));
      case ShareType.forumTopic:
        await openTopicDetail(context, session, target.id);
      case ShareType.forumComment:
        // Bağlantıdaki kimlik yorumun kimliğidir: konu `GET /forum/comments/{id}` ile çözülür.
        final c = await ForumApi(session).comment(target.id);
        if (!context.mounted) return;
        await openTopicDetail(context, session, c.topicId, commentId: target.id);
      case ShareType.event:
        await showModalBottomSheet<void>(
          context: context,
          useRootNavigator: true,
          useSafeArea: true,
          isScrollControlled: true,
          showDragHandle: true,
          clipBehavior: Clip.antiAlias,
          builder: (_) => FractionallySizedBox(
            heightFactor: .94,
            child: EventDetailPage(session: session, eventId: target.id),
          ),
        );
    }
  } catch (_) {
    if (context.mounted) {
      BuToast.show(context, context.l10n.shareNotFoundTitle, kind: BuToastKind.error);
    }
  }
}

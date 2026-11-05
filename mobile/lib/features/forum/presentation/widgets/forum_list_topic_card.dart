import 'package:flutter/material.dart';

import '../../../../core/session.dart';
import '../../data/forum_api.dart';
import '../../data/forum_models.dart';
import '../../forum_routes.dart' show openTopicDetail;
import 'forum_result_tiles.dart';
import 'topic_actions.dart' show TopicMenuResult;
import 'topic_card.dart';

/// Arama / kaydedilenler / faaliyet listelerinde Forum ana sayfasıyla AYNI konu kartı ([TopicCard]) + altında isteğe
/// bağlı şerit ([footer]: eşleşme şeridi, kendi anonim konum rozeti). Kart içi beğeni/kaydet/menü ana sayfadakiyle
/// aynı çalışır; sonuçlar liste durumuna şu üç geri çağrıyla yansır:
/// * [onChanged]: güncel özet (beğeni/kaydet/yorum sayısı),
/// * [onRemoveTopic]: konu listeden düşsün (kaldırılmış / yazar engeli anonim),
/// * [onRemoveAuthor]: kimliği bilinen yazarın tüm konuları düşsün (sessize alma / engel).
class ForumListTopicCard extends StatelessWidget {
  const ForumListTopicCard({
    super.key,
    required this.session,
    required this.api,
    required this.topic,
    required this.onChanged,
    required this.onRemoveTopic,
    required this.onRemoveAuthor,
    this.onOpened,
    this.footer,
  });

  final Session session;
  final ForumApi api;
  final TopicSummary topic;
  final ValueChanged<TopicSummary> onChanged;
  final VoidCallback onRemoveTopic;
  final void Function(int authorId) onRemoveAuthor;

  /// Karta dokunulunca (detay açılmadan önce); arama geçmişine yazmak için.
  final VoidCallback? onOpened;
  final Widget? footer;

  Future<void> _open(BuildContext context) async {
    onOpened?.call();
    final updated = await openTopicDetail(context, session, topic.id, initial: topic);
    if (updated == null) return;
    if (updated.removed) {
      onRemoveTopic();
    } else {
      onChanged(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final extra = footer ?? (topic.mine && topic.author.anonymous ? const ForumOwnAnonBadge() : null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        TopicCard(
          session: session,
          api: api,
          topic: topic,
          onOpen: () => _open(context),
          onChanged: onChanged,
          onMenuResult: (t, r) {
            switch (r) {
              case TopicMenuResult.hideTopic:
                onRemoveTopic();
              case TopicMenuResult.hideAuthor:
                final id = t.author.userId;
                // Anonim yazar kimliği bilinmez: tüm anonimleri düşürmeyiz, yalnız bu konuyu.
                id == null ? onRemoveTopic() : onRemoveAuthor(id);
              case TopicMenuResult.none:
                break;
            }
          },
        ),
        if (extra != null) extra,
      ]),
    );
  }
}

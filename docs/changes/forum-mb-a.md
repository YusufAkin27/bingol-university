# Kampüs Forum - mobil A (temel katman, ana sayfa, giriş noktaları)

Sözleşme: `FORUM_API.md` (§3). Bu not yalnız sözleşmeden küçük sapmaları ve ortak parçaları kaydeder.

## Ortak parçalar (diğer mobil alanlar kullanır)
- `features/forum/data/forum_models.dart`, `forum_api.dart` (`ForumApi(Session)`), `forum_routes.dart`.
- `ApiClient.post(path, body, auth, headers)`: opsiyonel dördüncü parametre `headers` (forumda `Idempotency-Key`).
  `ForumApi.newIdempotencyKey()` bir "gönderme niyeti" için BİR kez üretilip yeniden denemelerde aynen verilmelidir.
- `presentation/widgets/`: `forum_state_views.dart` (`forumErrorText(e, l10n)`, `ForumEmptyView`, `ForumErrorView`,
  `ForumNoticeBar`), `author_line.dart` (`ForumAuthorLine`, `ForumAvatar`, `ForumAnonAvatar`, `ForumCategoryTag`),
  `forum_like_button.dart` (`ForumLikeButton`: iyimser, 250 ms birleştirme, hatada geri alma), `topic_card.dart`
  (`TopicCard`, `ForumActionButton`, `ForumTopicImage`, `ForumStatusChip`, `TopicCardSkeleton`), `topic_actions.dart`
  (`shareForumTopic`, `showTopicMenu`), `category_chips.dart`, `forum_entry_strip.dart`, `home_forum_talked.dart`.
- Test: `test/support/fake_forum.dart` (`fakeForum(b)`, `sampleForumTopic`, `FakeForum`).
- ARB önekleri: `forumHome*`, `forumState*`.

## Sapmalar / eklemeler
- `openTopicDetail(..., {commentId, TopicSummary? initial}) -> Future<TopicSummary?>`: sayfa kapanırken güncel özeti
  `Navigator.pop` ile döndürür (silindiyse `status: 'REMOVED'` özeti); liste kartı buna göre güncellenir/kaldırılır.
- `openCreateTopic(..., {categoryId}) -> Future<TopicSummary?>`, `openEditTopic(..., TopicView) -> Future<TopicView?>`,
  `openReportSheet(..., {targetType, targetId, anonymousAuthor}) -> Future<bool>`.
- Ana Sayfa'da "Kampüste konuşulanlar" `HomeSection.forum` (kimlik `forum`, Önerilen kişilerin ardında, düzenleme
  sayfasından gizlenebilir); forum boş/ulaşılamazsa bölüm çizilmez.
- Keşfet başlık satırının altında `ForumEntryStrip` (yükseklik 64 + 12 dp); `kesfet2_birebir_test` referansı buna göre 30 -> 106.
- Paylaşım: `features/share` FORUM türü gelene kadar bağlantı panoya kopyalanır (`shareForumTopic`).
- Kartın üç nokta menüsünde "Kullanıcıyı sessize al" / "Yazarı engelle" doğrudan `ForumApi` ile yapılır (onay penceresi);
  şikâyet `openReportSheet`.

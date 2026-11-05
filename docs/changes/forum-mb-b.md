# Forum MB-B: konu detayı + yorum sistemi (mobil)

Kapsam: `mobile/lib/features/forum/presentation/pages/topic_detail_page.dart`, `comment_thread_page.dart` ve
`presentation/widgets/comment_*.dart`, `topic_detail_*.dart`, `forum_sheet_row.dart`. Sözleşme: `FORUM_API.md` §2-B, §3.

## Davranış özeti
- Yorum ağacı `CommentsController` (ChangeNotifier) + saf Dart `comment_tree.dart` ([flattenComments]): düz satır listesi
  tembel çizilir (`SliverList.builder`), girinti en çok 2 seviye (`kCommentMaxLevel`), daha derini "Yanıt zincirini aç"
  ile AYNI denetleyiciyi paylaşan `CommentThreadPage`de açılır. Yanıtlar `replyPreview` (ilk 2) + `GET /comments/{id}/replies`
  (imleç, 15'lik sayfalar). Üst düzey yorumlar imleçle sayfalanır, sıralama BEST/NEWEST/OLDEST.
- Beğeni iyimser ve tek uçuş: art arda dokunuşlar birleşir, sunucuya son istenen durum gider; hatada onaylı duruma döner.
- Yazma çubuğu `Scaffold.bottomNavigationBar`dır (klavye payını kendisi verir): SnackBar bildirimleri çubuğun ÜSTÜNDE
  çıkar, gönder düğmesini örtmez. Anonim yazma ayrı anahtardır (varsayılan kapalı, gönderimden sonra kapanır).
  Aynı gönderme niyeti tek `Idempotency-Key` kullanır; metin değişince yeni anahtar üretilir. Üst sınır 4000 (sessiz).
- Bağlantıdan açma: `GET /comments/{id}` `path` ile ata zinciri açılır; girinti sınırından derin hedef için zincir
  ekranı otomatik açılır. Üst düzey yorum henüz yüklenmediyse listenin başına eklenir.

## Sözleşmeden sapmalar / kararlar
- **Düzenleme ayrı sheet değil, yazma çubuğunda** (metin editöre gelir, "Yorumunu düzenliyorsun" bandı, Kaydet/İptal).
- **Paylaşım** `share_plus` sistem paylaşım sayfasıyla (`topic_detail_share.dart`, test kancası `debugForumShare`);
  bağlantılar `forumTopicLink` / `forumCommentLink`. MB-D `ShareType.forum` hazır olunca `shareForumLink` o akışa
  yönlendirilebilir.
- **Moderasyonla kaldırılmış yorum** ayrı bir alanla gelmez (`deleted:true` hem silmeyi hem kaldırmayı kapsar):
  ikisi de "Bu yorum silindi" yer tutucusudur. Sunucu ileride `removed` alanı eklerse `CommentNode.deleted` yanına
  ayrı metin eklenir.
- Yorum moderasyonu (REMOVE/RESTORE) bu ekranda YOK (yalnız konu sabitle/kilitle; yorum kaldırma yönetim panelindedir).
- Rota: `openTopicDetail` kapanırken güncel `TopicSummary` döner (silindi/engellendiyse null); kapanışı `PopScope` yönetir.
- Anket: `PollView` (MB-C) varsayılan; `TopicDetailPage.pollBuilder` yalnız test/özelleştirme içindir.
- Şikâyet: `openReportSheet` (MB-D) çağrılır; engelleme `block-author` ucunu kendi onay sayfasıyla kullanır.

## Test
`mobile/test/forum_topic_detail_test.dart` (davranış), `forum_topic_detail_visual_test.dart` (görsel duman matrisi),
sahte uçlar `mobile/test/support/fake_forum_comments.dart` (+ `fake_forum.dart` MB-A tabanı).

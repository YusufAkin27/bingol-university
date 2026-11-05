# Kampüs Forum - mobil D (arama, kaydedilenler/faaliyet, tercihler, şikâyet/engel, bildirim yönlendirme, paylaşım)

Sözleşme: `FORUM_API.md` (§3). Bu not yalnız sözleşmeden küçük sapmaları, varsayımları ve ortak parçaları kaydeder.

## Ekranlar ve rotalar (`features/forum/forum_routes.dart`)
- `openForumSearch` -> `ForumSearchPage`: 350 ms bekleme, en az 2 karakter, kategori çipleri, sıralama (İlgili/En yeni/Popüler),
  eşleşme etiketi (Başlıkta/Açıklamada/Yorumda/Kategoride) + vurgulu kesit (`t.prText`, kalın değil), imleçli sayfalama,
  kutu boşken cihazdaki son aramalar (`ForumRecentSearches`, en çok 10, çıkışta silinir) ve popüler konular.
- `openForumSaved` -> `ForumSavedPage` (konu + yorum kayıtları, kaldırma iyimser/geri alınır).
- `openMyForumActivity(..., {initialTab})` (EK: isteğe bağlı sekme) -> `ForumActivityPage`: Açtığım konular | Yorumlarım |
  Kaydedilenler | Takip ettiklerim. Anonim içeriklerim yalnız bende "Anonim" rozetiyle görünür.
- `openUserForumActivity(context, session, userId, {name, initialTab})` (EK) -> başkasının herkese açık faaliyeti.
- `openForumPrefs` -> `ForumPrefsPage`: ana anahtar + 4 alt anahtar (iyimser, sıralı kaydetme, hatada geri alma),
  moderasyon bildirimi kapatılamaz notu, "Sessize aldıkların" listesi (`GET /forum/mutes`).
- `openReportSheet(..., anonymousAuthor)` -> `showForumReportSheet` (5 neden + not; 409 `ALREADY_REPORTED` kısa bilgi;
  "Bu yazarı da engelle" anahtarı: şikâyetten sonra `block-author`).
- EK: `openBlockAuthor(context, session, {targetType, targetId})` (onay + `block-author`, anonim dahil, kimlik gösterilmez),
  `openMuteUser(context, session, {userId, name})`, `openTopicShare(context, session, TopicSummary)`,
  `openCommentShare(context, session, ForumComment, {topicTitle})`.

## Giriş noktaları
- Profil menüsü: "Forum" bölümü (4 satır, her biri ilgili sekmeyi açar). Başkasının profili: `ForumProfileSection`
  (`GET /forum/users/{id}/summary`; sayılar 0 ya da alınamazsa bölüm çizilmez; gizli/engelli profilde zaten kurulmaz).
- Bildirim ayarları sayfası: "Forum bildirimleri" satırı -> `ForumPrefsPage`.

## Bildirim yönlendirme (`core/push/*`)
- `PushDest.forumTopic` (`id`=konu, `commentId`) ve `PushDest.forumComment` (yalnız yorum kimliği; konu `GET /forum/comments/{id}` ile
  çözülür). `targetType=FORUM_TOPIC|FORUM_COMMENT` (+ `topicId`); `topicId` tek başına da konuya gider. Bilinmeyen `FORUM_*`
  türü bildirim listesine düşer, çökmez.
- Kart stili: forum bildirimi her zaman `FORUM` (forum karosu, kişi avatarı YOK; anonim yazar sızmasın), `FORUM_MODERATION`
  `MODERATION`. Sunucunun `style=social|system` değeri forumda yok sayılır. Kaynak etiketi: `sourceName` (kategori adı).
- Android yerel kart (`RichPushNotifications.kt`/`PushSpec.kt`) DEĞİŞMEDİ: tüm `data` yükü Flutter'a aynen geçer ve hedef eşlemesi
  Dart'ta yapılır; `style=social` Android'de "Sosyal" kartıdır. iOS kategorileri sunucu yüküyle gelir, istemci kodu gerekmedi.

## Paylaşım (`features/share`)
- `ShareType.forumTopic` (`FORUM_TOPIC`, `/s/f/{id}`) ve `ShareType.forumComment` (`FORUM_COMMENT`, `/s/fc/{id}`; kimlik yorumun
  kimliğidir). Açma (`openShared`): konu doğrudan, yorum `GET /forum/comments/{id}` ile konu çözülüp o yoruma gider.
- `ShareInfo.category` (EK, sunucu `categoryName` ya da `category` verirse): forum kartının üst satırı kategori adıdır; başlık konu
  başlığı; alt satır `subtitle` (yazar - sunucu anonimde göndermemelidir). `shareContentForTopic` anonim konuda yazar adını ASLA eklemez.

## Varsayımlar (sözleşmede kesin olmayanlar)
- `GET /api/forum/mutes`: düz liste ya da `{items:[...]}`; öğe `{userId|id, displayName, avatarUrl}` (iç içe `user` da kabul).
- `GET /api/forum/search` yorum eşleşmesinde yorum kimliği vermez: sonuç konuyu açar (yoruma kaydırma yok).
- Mesajdaki forum `share` yükü: `{type:'FORUM_TOPIC'|'FORUM_COMMENT', id, title, subtitle?, categoryName?, available}`.

## Test altyapısı
- `test/support/fake_forum_extras.dart` (`fakeForumExtras(fakeForum(b))`): arama, popüler, kaydedilenler, faaliyet, profil özeti,
  tercihler, sessize alınanlar, şikâyet (409), block-author, tek yorum. `test/support/forum_d_harness.dart`: `forumDApp`, `RouteLog`.
- Testler: `test/forum_d/*`.

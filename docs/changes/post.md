# post modülü değişiklik notları (genel gönderiler / Keşfet akışı)

Tasarım ve API sözleşmesi: [../POSTS_DESIGN.md](../POSTS_DESIGN.md). Bu dosya çekirdek (ajan A) kısmını anlatır; medya, beğeni,
yorum ve moderasyon alt paketleri (`post/media`, `post/like`, `post/comment`, `post/admin`) kendi notlarını ekler.

## Veri (V310__posts.sql)
Tablolar `post`, `post_media`, `post_like`, `post_comment`; indeksler `post310_*` (akış `created_at,id` kısmi indeks, yazar, puan,
medya, yetim medya, yorum). Tek migration'ı çekirdek yazar; diğer paketler migration yazmaz.

## Kod haritası (`edu.bingol.backend.post`)
- `Post` (entity, `@DynamicUpdate`: sayaçlar atomik SQL ile değiştiği için yalnız değişen sütun yazılır), `PostRepository` (JPQL; görünürlük süzgeci
  `VISIBLE`: silinmemiş + gizlenmemiş + yazar ACTIVE + iki yönlü `UserBlock` yok).
- `PostService`: `create/get/update/delete/feed/byAuthor/requireVisible`. `requireVisible(id, viewer)` beğeni/yorum/rapor modüllerinin ortak kapısıdır (görünmezse `POST_NOT_FOUND`).
- `PostViewAssembler`: toplu `PostView` (yazar profilleri `PublicProfileMapper` ile; medya ve beğeni SPI'larla).
- `PostCounters`: `incrementLikes/incrementComments(postId, delta)` atomik, negatife düşmez.
- `PostCursor`: opak Base64url imleç (`L|createdAt|id`, `P|score|id`).
- `PostScoreJob` (saat başı `app.post.score-cron`, `SchedulerLock`), `PostCounterRepairJob` (03:30 `app.post.counter-repair-cron`).
- Olay: `PostDeletedEvent(postId, mediaIds)` silmede yayınlanır; medya paketi dinleyip dosyaları zamanlar.

## SPI (post/spi)
- `PostMediaLookup.viewsFor(Collection<Long> postIds, Long viewerId)` -> `Map<Long, List<MediaView>>`
- `PostMediaBinder.attach(postId, ownerId, mediaIds)` (geçersizse 400 `POST_MEDIA_INVALID`), `mediaIdsOf(postId)`
- `PostLikeLookup.likedPostIds(Long viewerId, Collection<Long> postIds)` -> `Set<Long>`
Hiçbiri yoksa medya boş, `likedByMe=false` döner (derleme/çalışma güvenli).

## Kurallar
- Küfür/argo: `ContentGuard.assertClean` (create), `assertChanged` (PATCH) -> 422 `CONTENT_PROFANITY`.
- Hız sınırı: gönderi saatte 20, düzenleme/silme dakikada 30, okuma dakikada 120.
- Popülerlik: `score = (likes + 2*comments) / (yaşSaat + 2)^1.2`; akış son 7 günü kapsar, eski gönderilerin puanı işte 0'lanır.

## Doğrulama
`PostServiceTest` (H2) ve `scripts/smoke-posts.sh` (PostgreSQL; sayaç onarım işi ve kısmi indeks burada doğrulanır).

## Beğeni ve bildirimler (`post/like`, `post/notify`)
- `PostLike` (`post_like`, bileşik PK `PostLikeId(postId,userId)`), `PostLikeRepository`, `PostLikeService` (aynı zamanda `PostLikeLookup` SPI), `PostLikeController`.
- `PUT /api/posts/{id}/like` -> 200 `{liked:true, likeCount}` (idempotent), `DELETE` -> `{liked:false, likeCount}`, `GET /api/posts/{id}/likes?cursor&size<=30` -> `{items:[{id,displayName,avatarUrl,likedAt}], nextCursor:string|null, total}`. Hız: dakikada 120. Gönderi gizli/silinmiş/engelli/yazarı pasif -> 404 `POST_NOT_FOUND`. Bozuk imleç -> 400 `POST_CURSOR_INVALID` (imleç opak: `<mikrosaniye>_<userId>`, sıra: yeniden eskiye).
- Satır + `PostCounters.incrementLikes` aynı transaction'da; eş zamanlı çift PUT'ta unique ihlali transaction dışında yutulur (sayaç bir kez artar). Beğenenler listesi engel ilişkisindekileri saklar, `total` da bunları saymaz; avatar `PublicProfileMapper` kuralına uyar.
- KVKK: `PostLikeService.purgeUser(userId)` beğenileri siler ve ilgili `like_count` değerlerini düşürür (hesap silme akışından çağrılır).
- Bildirim türleri `NotificationType.POST_LIKE/POST_COMMENT/COMMENT_REPLY` + aynı adlı `NotificationSubtype`. Migration gerektirmemesi için üçü de `notification_pref.communities` bayrağına bağlıdır; ince ayar alt tür tercihiyle (`subtypes.POST_LIKE=false`). Sessiz saat ve push kuralı `NotificationService.send` içinde mevcut kalıpla.
- `PostNotifier` (alıcı dilinde metin, `i18n/post*.properties` `notif.post.like.*`, `notif.post.comment.*`, `notif.comment.reply.*`): `onLike(actor,post,postAuthor)`, `onComment(actor,post,postAuthor,commentId)`, `onReply(actor,post,commentId,parentAuthor,replyToUser)`. Kendi eylemi ve (iki yönlü) engel ilişkisinde bildirim yok; hatalar yutulur. Yük: `targetType:"POST"`, `targetId:<postId>`, `postId`, `commentId`.
- Beğeni birleştirme: toplama anahtarı `postlike:<postId>:<epoch sn / 600>` (sabit 10 dk dilim). Aynı anahtarlı okunmamış bildirim varsa satır güncellenir ("{ad} ve {n} kişi gönderini beğendi", `groupCount` artar); yoksa yeni satır. Redis/gecikmeli iş yok.

## Yorumlar ve yanıtlar (`post/comment`, D)
- `PostComment` (`post_comment`), `PostCommentRepository` (kök listeleri `LISTED` koşuluyla: gizli değil, silinmemiş ya da yanıtı olan; engelliler `NOT IN`), `PostCommentService`, `PostCommentController`, `CommentDtos`. Uçlar: `GET/POST /api/posts/{id}/comments`, `GET /api/comments/{id}/replies`, `PATCH/DELETE /api/comments/{id}`.
- Derinlik 0..3; ebeveyn derinliği 3 ise yeni yorum ebeveynin kardeşi olur (`replyToUser` = yanıtlanan yazar). `root_id` kök için kendi id'si (insert sonrası güncellenir).
- Sayaçlar aynı transaction'da atomik: gönderi `comment_count` (`PostCounters.incrementComments`), yorum `reply_count` (`PostCommentRepository.addReplies`). Silme: yanıtı olan yorum `deleted_at` ile "silindi" kaydı kalır (gövde ve yazar API'de null); yanıtsız yorum listeden kalkar ve ebeveynin `reply_count`u düşer; yanıtsız kalan "silindi" ebeveynler zincir halinde yukarı çözülür. `comment_count` her silmede 1 düşer (yalnız canlı yorumlar sayılır).
- İmleç opak string: `new` = `n|createdAt|id`, `top` = `t|replyCount|createdAt|id`; bozuk imleç `400 POST_CURSOR_INVALID`. `previewReplies`: tek native sorgu (`ROW_NUMBER`), N+1 yok.
- Bildirim `post/spi/PostNotifierPort` üzerinden (`PostNotifier` uygular); transaction commit sonrası çağrılır, hata yutulur.
- `purgeUser(userId)` (hesap silme, `PostAccountPurger` çağırır): yazarın canlı yorumları derin olandan başlayarak silinir (yanıtlısı "silindi" kalır), sayaçlar düşer. Yönetici silmesi `delete(adminId, id, true)`.
- Test: `PostCommentServiceTest` (SpringBootTest + H2; `ContentGuard` ve `PostNotifierPort` mock). Duman: `scripts/smoke-posts.sh` "yorum" bölümü.

## Moderasyon, yönetici, KVKK, arama, saklama (`post/admin`, E)
- **Rapor hedefleri:** `ReportTargetType.FEED_POST` / `FEED_COMMENT` (`report.target_type` ≤16 karakter). `PostReportHandlers.FeedPostHandler` / `FeedCommentHandler` (duz SQL, geri alınabilir): `hide` = `hidden_at` (+ gönderi medyası `PostMediaService.hide`), `unhide` geri alır; `exists` = silinmemiş (gizli de "var": itiraz için); `preview` = ilk medya (`/api/admin/posts/media/{id}`) ya da metin. `AdminReportContextService` bağlamı `Content` kaydına `postId` ve `media` ekledi.
- **Yönetici uçları:** `AdminPostController` + `AdminPostService` (`/api/admin/posts*`, `/api/admin/comments*`; ayrıntı `ADMIN_API.md`). Silme `PostService.delete(admin)` / `PostCommentService.delete(admin)` üzerinden (aynı sayaç/olay semantiği). Gizli yorum `hidden_at` ile listelerden kalkar (`PostCommentRepository.LISTED`); yorumda gerekçe alanı yoktur.
- **KVKK:** `PostExporters`: `posts` (kendi gönderileri + `mediaMeta` yalnız meta), `postComments`, `postLikes` (en çok 5000 satır). Hesap silme: `AccountDataPurger.purge` önce `PostAccountPurger.purge` çağırır → `PostMediaService.purgeUser`, `PostLikeService.purgeUser`, `PostCommentService.purgeUser`, sonra kullanıcının gönderileri yumuşak silinir ve her biri için `PostDeletedEvent` yayınlanır.
- **Arama:** `SearchType.POSTS`, `PostSearchProvider` (`GET /api/search?q=&type=POSTS`): `to_tsvector('turkish', body)` + `ILIKE` yedeği, yalnız görünür gönderiler, silinmiş hesap ve iki yönlü engel hariç; sonuç `title` = yazar adı, `snippet` = metin (160), `imageUrl` = ilk medya küçük resmi. PostgreSQL'e özel: `scripts/smoke-posts.sh` doğrular. Not: `body` için GIN indeksi yoktur (V310'a eklenmedi); gönderi sayısı büyürse yeni bir migration ile `to_tsvector('turkish', coalesce(body,''))` indeksi eklenmeli (ifade aynı olmalı).
- **Saklama:** `PostRetentionJob` (her gece 05:10, `app.post.retention.cron`; `SchedulerLock`): `app.post.retention.hidden-days` (30; 0 = kapalı) gündür gizli kalan gönderiler yumuşak silinir; `app.post.retention.deleted-days` (30) gündür silinmiş ve medya satırı kalmamış gönderiler satırlarıyla (yorum/beğeni `ON DELETE CASCADE`) kalıcı silinir. Medya baytları `PostMediaJanitor` (04:40) tarafından önce temizlenir.
- **Web:** `/admin/posts` (`PostsAdminPage`; menü Moderasyon → Gönderiler); şikâyet detayında Keşfet içeriği için medya önizlemesi ve "Gönderide aç" bağlantısı.
- **Test:** `PostAdminTest` (SpringBootTest + H2: gizle→akıştan kalkar→geri aç, süzgeç/imleç, yorum moderasyonu, handler'lar, dışa aktarım, hesap silme, saklama işi), `PostAdminSecurityTest` (401/403), `AuditPostPathsTest`. Arama SQL'i ve rapor kuyruğu uçtan uca `scripts/smoke-posts.sh` "moderasyon / yönetici / arama" bölümünde.

## Gönderi sosyal özellikleri (`post/social`, `post/follow`, `post/story`; V340, önek `soc340_`)
- **Migration `V340__post_social.sql`:** `post_save`, `post_mention`, `hashtag` + `post_hashtag`, `user_follow` + `user_follow_stats`, `story` + `story_view`; `post_media.story_id` (hikâye medyası "bağlanmamış yükleme" sayılmaz; `PostMediaRepository.stale/deleteIfUnattached/bind` ve bekleyen sayacı `storyId IS NULL` ile genişledi, `accessible` hikâye dalı eklendi). Tüm tablolar JPA varlığıdır (H2 testleri için) ama yazma/sayma çoğunlukla taşınabilir SQL (`INSERT .. SELECT .. WHERE NOT EXISTS`) ile atomiktir.
- **Çekirdeğe küçük, geriye uyumlu değişiklikler:** `PostView` (+`savedByMe`, `mentions`, `hashtags`; eski 12 alanlı kurucu korunur), `CommentView` (+`mentions`), `FeedPage` (+`hint`), `PublicProfile` (+`followerCount/followingCount/followedByMe`, 8 alanlı kurucu korunur; `ProfileService.publicProfile` doldurur), `PostService.feed` kapsamları `following|department` (+`FEED_SCOPE_INVALID`), `PostViewAssembler` ve `PostCommentService` sosyal ekleri `PostExtrasLookup` SPI ile alır (setter enjeksiyonu; kurucu imzaları değişmedi), `PostNotifier.onMention/onFollow`, `NotificationType/Subtype` `POST_MENTION`, `USER_FOLLOW` (tercih sütunu: `communities` bayrağı), `ReportTargetType.STORY`, `PostAccountPurger` → `SocialAccountPurger`.
- **Metin olayı:** `PostService`/`PostCommentService` oluşturma ve düzenlemede `SocialTextEvent` yayınlar; `SocialTextHandler` (aynı işlem) `#etiket` (yasaklı etiket `ContentGuard` 422 → işlem geri alınır) ve `@etiket` (en çok 10; engel/pasif düşer; yeni etiketlenene commit sonrası bildirim) eşitler.
- **#Etiket anahtarı:** Türkçe küçük harf (`I→ı`, `İ→i`) sonra aksansız katlama (`ı→i ş→s ğ→g ü→u ö→o ç→c`); `hashtag.tag` bu anahtardır (benzersiz), `display` ilk görülen Türkçe küçük biçimdir. Gündem saatlik bellek önbelleğidir (çok örnekte her örnek kendi önbelleğini tutar; kabul edilmiş).
- **Takip:** sayaçlar `user_follow_stats` tablosunda atomik; engelleme takip satırlarını silmez ama listelerden ve akıştan gizler. Gizlilik: mevcut `ProfilePrivacy` takipçi listesi için ayar sunmaz; listeler engel dışında tüm doğrulanmış kullanıcılara açıktır.
- **Hikâyeler:** `app.story.video-max-seconds` (30), `app.story.ttl-hours` (24), `app.story.retention-hours` (24; süre bitişinden sonra kalıcı silme), `app.story.cleanup-cron` (her saat :35). `StoryCleanupJob` `SchedulerLock` kullanır. Kullanıcı/yönetici silme yumuşaktır; medya erişimi hemen kapanır, baytlar temizlikte kalkar.
- **KVKK:** `DataExporter` bölümleri `savedPosts`, `follows`, `stories`; hesap silmede kaydedilenler, etiketlenmeler, takipler (karşı sayaçlar düşer), hikâyeler ve görüntüleme kayıtları silinir.
- **Rate limit:** takip 60/dk, kaydet 120/dk, hikâye oluşturma 20/saat, mention önerisi 60/dk, etiket uçları 60/dk.
- **Test:** `SocialTextTest` (ayrıştırıcılar), `PostSocialIntegrationTest` (SpringBootTest + H2: takip, akış kapsamları, kaydet, etiketler, hikâyeler, KVKK). PostgreSQL'e özel yollar: `scripts/smoke-post-social.sh`.

## Sade Keşfet: tek fotoğraf, kısa metin, yorum/hikâye/etiket yok (2026-10-28)
Ayrıntılı sözleşme: [../POSTS_DESIGN.md](../POSTS_DESIGN.md) başındaki "GÜNCEL SÖZLEŞME" kutusu. Veri silinmedi, migration yok (tablolar/kolonlar duruyor).
- **Kural (PostService):** `create` tam 1 `mediaId` ister (`POST_PHOTO_REQUIRED`/`POST_SINGLE_PHOTO_ONLY`), `PostMediaBinder.requireImage` video/yabancı/kullanılmış medyayı gönderi yazılmadan reddeder (`POST_VIDEO_NOT_ALLOWED`/`POST_MEDIA_INVALID`). Metin: `PostService.checkText` (tek satır, ≤7 kelime `[\s\p{Z}]+`, ≤60 kod noktası; 422 `POST_TEXT_INVALID`/`POST_TEXT_TOO_LONG`), `create` ve `update` için. `SocialTextEvent` yayınlanmaz.
- **Medya yükleme:** `PostMediaController.upload` video girdisini `400 POST_VIDEO_NOT_ALLOWED` ile reddeder; `PostMediaService` video yolu (eski kayıtların sunumu, Range, testler) korunur.
- **410:** `RemovedFeatureController` (yorum, hikâye, etiket, bahsetme önerisi, kaydet, beğenenler listesi). Eski controller sınıfları (`PostCommentController`, `StoryController`, `HashtagController`, `MentionSuggestController`, `PostSaveController`) `@RestController`ı kaldırılarak devre dışı bırakıldı (geri alma: ek açıklamayı geri koy + 410 eşlemesini sil); `PostLikeController.GET /likes` kaldırıldı. Servisler/varlıklar/yönetici uçları yerinde.
- **Okuma:** `PostRepository.FEED_VISIBLE` (= `VISIBLE` + görünür `IMAGE` medyası var) akış, popüler, yazar ve takip/bölüm sorgularında; `VISIBLE` beğeni/kaydet için aynen. `PostViewAssembler`: `media` yalnız ilk `IMAGE`, `commentCount=0`, `savedByMe=false`, `mentions/hashtags=[]` (extras SPI artık çağrılmıyor).
- **Testler:** `PostServiceTest` (tek fotoğraf, metin kuralı, akış filtresi), `RemovedFeatureControllerTest` (410 + video yükleme), `PostFixtures` (test yardımcısı); `PostSocialIntegrationTest`ten kaydet/#etiket/@etiket testleri çıkarıldı.

## Keşfet puanlama (`GET /api/feed?scope=top`)

**Kapsamlar:** `top` (puanlı; Keşfet'in önerilen varsayılanı), `latest`, `popular`, `following`, `department`. API'nin kapsamsız varsayılanı `latest` olarak KALDI (geriye uyum); mobil `scope=top` ister. `popular` (eski `score` kolonu, 7 gün penceresi) ve `latest` değişmedi.

**Formül** (`PostRank`, saf fonksiyon; puan istemciye dönmez):
```
engagement = wL*ln(1+beğeni) + wC*ln(1+yorum) + wF*ln(1+yazarTakipçi) + wV*ln(1+son24saatBeğeni)
sönüm      = 0.5 ^ (yaşSaat / yarıÖmür)
soğuk      = yaş < coldStartHours ? coldStartBonus*(1 - yaş/coldStartHours) : 0
puan       = (engagement*sönüm + soğuk) * reportPenalty ^ min(açıkŞikâyet, maxReportsCounted)
```
Gerekçe: log ölçek ilk beğenileri değerli kılar, viral gönderinin tek başına akışı kaplamasını önler; yarı ömür 60 sa (2,5 gün) taze gönderiyi öne çıkarır; son 24 saat beğeni terimi ivmeyi ödüllendirir; soğuk başlangıç beğenisiz yeni gönderinin ilk 6 saatte görünmesini sağlar (6. saatte sıfıra iner); açık `FEED_POST` şikâyetleri puanı yarıya böler (en çok 5 şikâyet sayılır); gizlenen/silinen gönderi ve engelli/askıdaki yazar zaten `FEED_VISIBLE` süzgecinde dışarıda; engel ilişkisi görüntüleyene göre süzülür. 14 günden eski gönderilerin puanı 0'dır (listenin sonunda `id DESC` sırasıyla kalır, akış tükenmez).

**Ayarlar** (`PostRankProperties`, `app.post.rank.*`; hepsi varsayılanlıdır): `like-weight=1.0`, `comment-weight=1.5`, `follower-weight=0.6`, `velocity-weight=1.2`, `half-life-hours=60`, `cold-start-hours=6`, `cold-start-bonus=2.0`, `report-penalty=0.5`, `max-reports-counted=5`, `window-days=14`, `max-author-run=2`, `default-page-size=12`, `max-page-size=30`, `recompute-ms=300000`; ayrıca `app.post.rank.initial-delay-ms` (30000).

**Hesaplama (hibrit):** (1) yeni gönderide `PostService.create` `PostRankService.initialScore` ile soğuk başlangıç puanını anında yazar; (2) `PostRankService.scheduled` her 5 dk `SchedulerLock("post-rank")` ile son 14 gündeki gönderileri 500'lük partilerle yeniden hesaplar (takipçi `user_follow_stats`, 24 sa beğeni `post_like`, açık şikâyet `report` — hepsi partiye tek sorgu, N+1 yok) ve 14 günden eskileri sıfırlar. Beğeni/takip başına artımlı yazma YAPILMAZ (yazma yolunu yavaşlatmamak için): beğeni etkisi en geç ~5 dk gecikir.

**Migration:** `V410__post_rank_score.sql` — `post.rank_score DOUBLE PRECISION NOT NULL DEFAULT 0` + kısmi indeks `post410_rank_idx (rank_score DESC, id DESC) WHERE deleted_at IS NULL AND hidden_at IS NULL`. (Önceki iş: V390 menü, V400 etkinlik için ayrıldı; etkinlik işi migration kullanmadı.)

**Sayfalama:** keyset, `ORDER BY rank_score DESC, id DESC`. `size` varsayılan 12, üst sınır 30 (`size` verilmezse veya ≤0 ise kapsam varsayılanı; diğer kapsamlar 10, üst sınır 20). İmleç opak Base64url: `T|<rank_score>|<id>|<hesapSürümü>`; bozuk veya başka kapsamın imleci 400 `POST_CURSOR_INVALID`. Sayfa içi yazar çeşitliliği: ardışık aynı yazardan en çok 2 gönderi; yeniden sıralama kayıpsızdır (yalnız sayfa içi sıra değişir, imleç veritabanı sırasındaki son kayıttan kurulur → kopya/atlama oluşmaz).

**Bilinen ödünleşme:** puan 5 dk'da bir değiştiği için kullanıcı kaydırırken yeniden hesap olursa nadiren bir gönderi tekrar görünebilir (skoru imlecin altına düşen daha önce gösterilmiş gönderi) ya da atlanabilir (skoru yükselen henüz gösterilmemiş). Hesap sürümü imleçte taşınır; sürüm değişmişse yanıt `hint: "RANK_REFRESHED"` döner. İstemci `id`'ye göre tekilleştirir. Sürüm örneğe özeldir (çok örnekli çalışmada her örnek kendi son hesap anını bilir; en kötü durum fazladan `hint`). Tam anlık görüntü (snapshot) bilerek yapılmadı: sayfa başına sunucu durumu gerektirir.

**API:**
```
GET /api/feed?scope=top&size=12
-> 200 {"items":[{PostView...}], "nextCursor":"VHwxLjg3fDQyfDE3NjE2...", "hint":null}
GET /api/feed?scope=top&cursor=VHwx...&size=12   (son sayfada nextCursor=null)
```
`items` biçimi mevcut `PostView`; puan/`rankScore` hiçbir yanıtta yoktur. Engelleme, gizlilik ve video-only/metin-only gizleme (`FEED_VISIBLE`) `top`'ta da geçerlidir.

**Testler:** `PostRankTest` (formül: beğeni artınca puan artar, log ölçek, takipçi/ivme, yarı ömür sönümü, soğuk başlangıç, şikâyet cezası, çeşitlilik), `PostTopFeedTest` (3+ sayfa gezme kopya/atlama yok, imleç sonu, boyut 12/30, engel + video-only süzgeci, soğuk başlangıç, bozuk imleç, puan sızmaması, `latest`/`popular` sürüyor).

## Takipleşme: `followsMe` (2026-10-28)
- **Alan:** `GET /api/users/{id}` (`PublicProfile`) ve `GET /api/users/{id}/followers|following` liste öğeleri (`FollowService.UserItem`) `followsMe: boolean` taşır (= o kullanıcı beni takip ediyor). Liste öğelerinde `followedByMe` zaten vardı. "Karşılıklı" alanı yok: istemci `followedByMe && followsMe`.
- **Maliyet:** N+1 yok. Sayfa başına tek ek sorgu `UserFollowRepository.followingMeAmong(viewer, ids)` (`followedAmong` ile aynı biçim); profilde tek `existsById`. Kendi satırı/profili: `false`. Engel/pasif kullanıcı gizleme kuralları değişmedi (gizli profilde alanlar `null`).
- **Geriye uyum:** `PublicProfile` 8 ve 11 alanlı eski kurucular, `Stats`/`UserItem` eski kurucuları korunur (`followsMe=false`).
- **Örnek:** `GET /api/users/42/followers` -> `{"items":[{"id":7,"displayName":"Ayse K.","avatarUrl":null,"department":"Bilgisayar","followedByMe":false,"followsMe":true}],"nextCursor":null}`; `GET /api/users/42` -> `{...,"followerCount":3,"followingCount":5,"followedByMe":true,"followsMe":false}`.
- **Testler:** `PostSocialIntegrationTest.followsMeFlagsInStatsAndLists`.

## Arama ve beğeni düzeltmeleri (2026-10-28)
- **Arama:** `PostSearchProvider` (type=POSTS) artık akışla aynı görünürlüğü kullanır: silinmemiş, gizlenmemiş, aktif yazar ve en az bir görünür `IMAGE` medyası (`VISIBLE_SQL`); video-only/fotoğrafsız eski gönderiler aramada çıkmaz; küçük resim yalnız görünür `IMAGE`'dan. Test: `PostAdminTest.searchVisibilityMatchesFeed` (H2'de standart SQL parçası); tam metin sorgusu `scripts/smoke-posts.sh` ile.
- **Beğeni yarışı:** `PostLikeService.like` artık atomik `INSERT ... WHERE NOT EXISTS` ile eklenir ve sayaç yalnız satır eklendiyse artar (önceden `saveAndFlush` = `merge`; eşzamanlı ikinci istek var olan satırı UPDATE sayıp istisna atmadığından sayaç çift artabilirdi).
- **Duman betikleri:** `smoke-posts.sh`, `smoke-post-social.sh` yeni sözleşmeye göre yeniden yazıldı (tek fotoğraf + ≤7 kelime, `scope=top` + imleç, kaldırılan uçlar için 410, `followsMe`).

## Kaldırılan özelliklerin temizliği ve yönetici moderasyonu (V470, 2026-10-28)

**Karar: ilk gönderi onayı yok.** Gönderi (1 fotoğraf + en çok 7 kelime/60 karakter metin + beğeni) anında yayınlanır; yönetici hepsini görür, sonradan düzenler/gizler/siler.

- **Kod silindi:** `post/comment/*`, `post/story/*` (`StoryCleanupJob` dahil), `post/social` içinden `Hashtag*`, `PostHashtag*`, `PostMention*`, `PostSave*`, `MentionSuggest*`, `PostExtrasService`, `SocialText*`; `post/SocialTextEvent`, `post/spi/PostExtrasLookup`, `post/spi/PostNotifierPort`, `RemovedFeatureController` (410 `FEATURE_REMOVED` uçları; mobil bu uçları çağırmıyor — `mobile/lib` içinde `/comments`, `/stories`, `/hashtags`, `mention-suggest`, `posts/saved`, `/save`, `/likes` isteği yok, doğrulandı). Artık bu yollar **404** döner. Kalanlar: `post/social/{SocialFeedRepository (takip/bölüm akışı), SocialAccountPurger (yalnız takip), SocialExporters (yalnız `follows`), PairId}`, `post/follow/*`, `post/like/*`, `post/media/*`, `post/notify/PostNotifier` (yalnız beğeni + takip).
- **Şema (`V470__drop_removed_post_features.sql`, yalnız `DROP IF EXISTS`/`DELETE`):** `story_view`, `story`, `post_mention`, `post_hashtag`, `hashtag`, `post_save`, `post_comment` tabloları; `post.comment_count`, `post_media.story_id` kolonları. `ReportTargetType.STORY`/`FEED_COMMENT` enum'dan kalktığı için bu türlere ait `moderation_appeal`, `moderation_strike`, `moderation_target_state`, `report` satırları silinir (kalsalar JPA enum çözümlemesi hata verirdi; ihlal sayacı bu türler için sıfırlanır). Hikâye medyası (`post_media.story_id` dolu) kolon düşünce "bağlanmamış yükleme" olur ve `PostMediaJanitor` tarafından satır + baytlarıyla süpürülür. Yeni indeks oluşturulmadığından `pdr470_` öneki kullanılmadı.
- **API/DTO:** `PostView` artık `{id, author, text, media, likeCount, likedByMe, mine, canEdit, canDelete, createdAt, editedAt}` (`commentCount`, `savedByMe`, `mentions`, `hashtags` kalktı). Admin `PostRow.commentCount` kalktı, `openReportCount` eklendi.
- **Ayar/i18n:** `app.story.*` ayarları, `error.COMMENT_*`, `STORY_*`, `MENTION_TOO_MANY`, `HASHTAG_INVALID`, `FEATURE_REMOVED`, `notif.post.comment|mention`, `notif.comment.*` anahtarları (tr/en/ar) silindi; `notif.post.adminedit.title|body` eklendi. Geriye kalan `NotificationType/Subtype` değerleri (`POST_COMMENT`, `COMMENT_REPLY`, `POST_MENTION`) mevcut bildirim satırları okunabilsin diye bilerek duruyor (notification paketi bu görevin kapsamı dışında).
- **Skor:** `PostScore`/`PostRank` imzaları korunur; yorum bileşeni 0 geçilir.
- **Yönetici (docs/ADMIN_API.md "Keşfet gönderileri moderasyonu"):** süzgeçler `status`, `authorId`, `minReports`, metin araması; `PATCH /api/admin/posts/{id}` metin düzenleme (ContentGuard yönetici için atlanır, biçim kuralı geçerli, denetim kaydı + yazara bildirim); gerekçeli `DELETE` (açık şikâyetleri `ReportService.resolve(HIDE)` ile sonuçlandırır ya da doğrudan yazara bildirim). Web: `/admin/posts` (düzenle/gizle/sil, onay diyaloğu, süzgeçler, tr/en/ar); yorum/hikâye/etiket sekmeleri kalktı.
- **Sınırlama:** gönderi **videosu** altyapısı (`PostMediaService.uploadVideo`, `PostVideoCipher`, transcode) bu temizliğe alınmadı: yükleme ucu ve bağlayıcı videoyu zaten reddediyor (`POST_VIDEO_NOT_ALLOWED`) ama sohbet videoları aynı `PrivateMediaStore`/transcode hattını paylaştığı için ayrı, ölçülü bir iş olarak bırakıldı.
- **Test:** `PostAdminTest` (düzenleme, gerekçeli silme + bildirim, süzgeçler), `PostAdminSecurityTest` (PATCH/DELETE 403), `PostSocialIntegrationTest` (takip/akış/KVKK), web `PostsAdminPage.test.tsx`. Rapor-silme entegrasyonu PostgreSQL'e özel SQL (`ON CONFLICT`) kullandığından H2'de değil `scripts/smoke-posts.sh` ile doğrulanır.


## FOLLOWREQ: gizli hesap + takip isteği (V1020)

- **Şema (`V1020__frq_follow_request.sql`):** `profile_privacy.private_account BOOLEAN NOT NULL DEFAULT FALSE`; `follow_request(id, requester_id, target_id, created_at)` tekil `(requester_id, target_id)` (`frq_pair_uq`), indeksler `frq_target_idx (target_id, id DESC)`, `frq_created_idx`. Varlık `FollowRequest` (yalnız şema tanımı; okuma/yazma düz SQL).
- **Kod (`post.follow`):** `FollowService.follow/unfollow` yanıtına `followState`; `FollowRequestService` (istek oluştur/geri çek/kabul/ret/liste/say, gizli->açık otomatik kabul `onBecamePublic` parçalı 200'lük + `FollowRequestJob` her 5 dk'da kalanı tamamlar, `purgeUser`), `FollowRequestController` (`/api/users/me/follow-requests*`), `PrivateAccountGate` (içerik kapısı: gizli ve sahibi/KABUL EDİLMİŞ takipçisi değilse kilitli; toplu `relations`), `FollowWriter` (takip satırı + sayaç tek yazıcı).
- **Görünürlük:** `PostRepository.VISIBLE` (tüm Keşfet/akış/rank/beğeni sorguları) gizli yazar için `p.authorId = :viewer OR NOT EXISTS(gizli) OR EXISTS(user_follow)` koşulunu içerir; `PostService.requireVisible` (tek gönderi, beğeni), `byAuthor` (kilitli: boş + `locked:true`), `PostMediaService.accessible` (fotoğraf), `PostSearchProvider` ve `FeedPostHandler.exists` aynı kuralı uygular. Bu veriler `CacheService` önbelleğinde DEĞİL (post paketi önbellek kullanmıyor), kullanıcıya özel sorgulardır.
- **Bildirim:** `NotificationType`/`Subtype` `FOLLOW_REQUEST`, `FOLLOW_ACCEPTED` (`communities` bayrağı); `PostNotifier.onFollowRequest/onFollowAccepted`; metinler `post*.properties` (`notif.follow.request|accepted.*`).
- **KVKK/temizlik:** `AccountDataPurger.DELETES` iki sütun için (`requester_id`, `target_id`); `DataExporter` `followRequests.sentPending` (yalnız gönderdiğim bekleyenler); `DbMaintenanceJob` görevi `follow_request` (90 gün); askıya alınca `UserModerationService.suspend` istekleri siler.
- **Testler:** `FollowRequestFlowTest` (H2, uçtan uca), `PrivateAccountSettingTest`. Duman: `scripts/smoke-follow-requests.sh`. PostgreSQL'de doğrulanmayanlar: `PostSearchProvider` yeni koşulu (tsvector sorgusu H2'de koşmaz), `VISIBLE` yeni alt sorgusunun Keşfet `top` planına etkisi (EXPLAIN önerilir), V1020 migration'ı.

## FOLLOWREQ-NOTIF: sonuçlanan takip isteği bildirimi okundu olur

- **Sorun:** hedefin kutusundaki `FOLLOW_REQUEST` bildirimi (collapseKey `followreq:<istekçiId>`) istek kabul/red/geri çekme sonrası okunmamış kalıyor, zil rozeti gerçek bekleyen sayıdan fazla gösteriyordu.
- **Karar: silme değil, okundu işaretle.** `FollowRequestService` istek sonuçlandığında hedefin ilgili okunmamış satırını `read_at = now` yapar: `accept`, `decline`, `withdraw` (`DELETE /users/{id}/follow` ve takip yazılırken eski istek kalıntısı), `dropBetween` (engelleme, iki yön), `purgeUser` (askı/silme: gönderilen isteklerin hedefleri + kendi kutusu). Gizli -> açık geçişte (`acceptAllPending`, 200'lük parçalar bittikten sonra, `FollowRequestJob` iyileştirmesi dahil) hedefin tüm okunmamış `followreq:%` bildirimleri TEK sorguyla okundu yapılır (LIKE kaçışı `\`, `%`, `_`).
- **Depo:** `NotificationRepository.markReadByTypeAndCollapseKey` ve `markReadByTypeAndCollapseKeyLike` (düz parametreli JPQL, yalnız `FOLLOW_REQUEST` türü, başka kullanıcının/türün satırına dokunmaz). `unread-count` ve liste `countUnreadInbox` ile aynı kaynaktan okunduğundan rozet otomatik düşer. Yeniden istek (red sonrası) yeni okunmamış satır üretir. İş en iyi çabadır: işaretleme hatası kabul/red akışını bozmaz (log uyarısı).
- **Test:** `FollowRequestNotificationReadTest` (H2). Migration yok.


## KS-BE (V1220): Keşfet tek sıralama + puanlama, video, Reels, tekrar göstermeme (2026-11-04)

**Kararlar (kullanıcı, 2026-11-04):** Keşfet'te seçenek yok, tek "popülerlik" sıralaması; gönderi paylaşırken **video** da paylaşılabilir
(V470 "video kaldırıldı" kararı **geçersiz**); yenilemede aynı gönderiler gelmez; Reels (dikey video akışı); mobilde puanlama göstergesi.
Bu bölüm mobil ajanların (KS-MB) sözleşmesidir. `docs/MOBILE_API_GUIDE.md` içindeki eski "SADE KEŞFET" kutusu ve "Keşfet puanlı akış" bölümü bununla çelişirse **bu bölüm geçerlidir**.

### 1. Gönderi = 1 fotoğraf VEYA 1 video
- `POST /api/posts/media` (multipart `file`, video için isteğe bağlı `poster`): fotoğraf (jpg/png/webp, eski kurallar) **ya da video**:
  MP4 / MOV (QuickTime, iPhone) / M4V / WebM, **en çok 60 sn (+0,5 sn tolerans), en çok 50 MB** (`app.post.media.video-max-*`; Spring multipart
  52/54 MB, Caddy `CADDY_MAX_BODY` >= 55 MB olmalı). Doğrulama gerçek içeriktedir (Content-Type'a/uzantıya güvenilmez): ISO-BMFF `ftyp` + `moov/mvhd`
  süresi (HEIC/AVIF/M4A markaları reddedilir) ya da EBML + DocType `webm` + Segment/Info süresi (süresi okunamayan canlı WebM reddedilir). Codec
  (H.264/HEVC/VP9) denetlenmez; oynatma istemcide. Hatalar: `400 VIDEO_INVALID`, `400 VIDEO_TOO_LONG` (arg: saniye), `413 VIDEO_TOO_LARGE` (arg: MB),
  `422 MEDIA_BLOCKED`, `429 POST_MEDIA_PENDING_LIMIT`. Yanıt (201): `{id, kind:"IMAGE"|"VIDEO", url, thumbUrl, width, height, durationMs, bytes}`.
  `poster` (JPEG/PNG kare, <= 720 px'e küçültülür) yoksa ffmpeg açıksa sunucu üretir; yoksa `thumbUrl` `null`. Mobil poster yüklemelidir.
- Sunucu videoyu (ffmpeg varsa) arka planda 720p/H.264 MP4'e çevirir; bitene dek orijinal sunulur. Dönüşünce `contentType` `video/mp4` olur, süre/boyut güncellenir.
- Sunum: `GET /api/posts/media/{id}` (Bearer; **HTTP Range** `206/416`), poster `?thumb=true`. Dosya diskte dosya-başına DEK ile şifrelidir.
- `POST /api/posts` `{text?, mediaIds:[tek id]}` -> 201 `PostView`. `mediaIds` tam 1 öğe (fotoğraf VEYA video; ikisi bir arada `400 POST_SINGLE_PHOTO_ONLY`,
  boş `400 POST_PHOTO_REQUIRED`; kod adları geriye uyum için aynı, metinleri "fotoğraf ya da video"). Metin kuralı aynı (7 kelime/60 karakter/tek satır).
  Eski `POST_VIDEO_NOT_ALLOWED` artık hiçbir uçta dönmez (anahtar çeviri dosyalarında kalır).
- Video gönderi beğeni/şikâyet/yönetici denetimini fotoğrafla aynı alır. Yüklenen medya 24 sa içinde gönderiye bağlanmazsa `PostMediaJanitor` siler.

### 2. `PostView` (tüm gönderi listeleri ve `GET /api/posts/{id}`)
```json
{"id":91,"author":{"id":7,"displayName":"Ayşe Y.","avatarUrl":"/files/avatars/x.jpg","department":"Bilgisayar Müh.","followerCount":42,"popularityScore":63},
 "text":"kampüste akşam","media":[{"id":12,"kind":"VIDEO","url":"/api/posts/media/12","thumbUrl":"/api/posts/media/12?thumb=true","width":720,"height":1280,"durationMs":18400}],
 "likeCount":5,"likedByMe":false,"mine":false,"canEdit":false,"canDelete":false,"createdAt":"…","editedAt":null,
 "type":"VIDEO","video":{"id":12,"url":"/api/posts/media/12","posterUrl":"/api/posts/media/12?thumb=true","durationMs":18400,"width":720,"height":1280},
 "viewCount":130,"popularityScore":71}
```
- `type`: `PHOTO` | `VIDEO`. `video` ve `viewCount` yalnız `VIDEO`'da bulunur (fotoğrafta alan hiç gelmez). `media[0]` her zaman aynı medyadır (fotoğrafta `kind:"IMAGE"`).
  Eski çok medyalı gönderilerde yalnız **ilk** medya (position) gösterilir.
- `popularityScore` **0..100, gönderi puanı** (yaştan bağımsız saf etkileşim; sunucu hesaplar, mobil yalnız gösterir): `100*(1-e^(-e/popularityScale))`,
  `e = likeW*ln(1+beğeni) + followerW*ln(1+yazarTakipçi) + viewW*ln(1+izlenme) + completionW*ortTamamlanma*ln(1+izlenme)` (son iki terim yalnız video). Etkileşim yoksa 0.
- `author.followerCount` (takipçi) ve `author.popularityScore` (**kullanıcı** puanı 0..100, bkz. 4) gerçek sayılardan türetilir; uydurma rozet/ödül yoktur.
  Eski alanlar (`likeCount`, `likedByMe`, ...) değişmedi.
- **Geriye uyum riski:** eski mobil sürümler (<= 2.0.6) `media[0].kind:"VIDEO"` görünce görsel olarak yükleyemez (kırık kare); video yükleme arayüzü yalnız yeni mobilde
  açılacağından risk, yeni sürümü kullananların yüklediği videolarla sınırlıdır.

### 3. Kapsamlar: `GET /api/feed?scope=`  (genişletme: 2. istek)
Keşfet filtreleri **Senin İçin | Popüler | Reels | En Yeni | Takip Ettiklerim** şu kapsamlara bağlanır (`scope` verilmezse `foryou`):

| Filtre | Çağrı | Davranış |
|---|---|---|
| Senin İçin | `GET /api/feed?scope=foryou` | Kişiselleştirilmiş tek akış: ortak popülerlik puanı havuzundan (görülmüş hariç) **takip önceliği + yazar ilgisi (beğendiğin yazarlar) + kontrollü rastgelelik** ile yeniden sıralanır. Sayfalar aynı oturumda kararlıdır (imleç yalnız oturum tohumunu taşır); yenileme (imleçsiz) yeni tohum alır. Görülmüş kümesi (bölüm 5) ve `exhausted` geçerlidir. |
| Popüler | `GET /api/feed?scope=popular` (eski ad `top` aynı) | Genel popülerlik puanı sırası (`rank_score DESC`), görülmüş hariç, `exhausted` tekrar modu. |
| En Yeni | `GET /api/feed?scope=latest` | Kronolojik (yeniden eskiye), foto + video; görülmüş kümesi UYGULANMAZ, `exhausted` alanı yok. |
| Takip Ettiklerim | `GET /api/feed?scope=following` | Takip ettiklerin (+ kendi) gönderileri, kronolojik (değişmedi; `department` de aynen). |
| Reels | `GET /api/feed/reels` | Ayrı uç, öneri algoritması: bölüm 6. |

- Yanıt `{items:[PostView], nextCursor, hint, exhausted}`; `size` varsayılan 12, üst sınır 30 (`latest`/`following`: 10/20); `nextCursor` opak, `null` = son sayfa; `hint:"RANK_REFRESHED"` (yalnız popular) nadiren
  aynı gönderi tekrarı olabilir (id ile tekilleştirin). Bilinmeyen kapsam `400 FEED_SCOPE_INVALID`, bozuk imleç `400 POST_CURSOR_INVALID`. İmleçler kapsama özeldir: kapsam değişince imleci atın.
- Fotoğraf ve video aynı akışlarda karışık gelir. Sayfa içi aynı yazar ardışık en çok `maxAuthorRun` (2).
- **Puan formülü** (`PostRank`, ağırlıklar `app.post.rank.*`, 5 dk'da bir `PostRankService` yeniden hesaplar; yeni gönderi anında soğuk-başlangıç puanı alır):
  `engagement = likeW*ln(1+beğeni) + followerW*ln(1+yazarTakipçi) + velocityW*ln(1+son24saatBeğeni) + viewW*ln(1+izlenme) + completionW*ortTamamlanma*ln(1+izlenme)`;
  `puan = (engagement * 0.5^(yaşSaat/halfLifeHours) + soğukBonus) * reportPenalty^min(açıkŞikâyet, 5)`. Yeni anahtarlar: `viewWeight` 0,8, `completionWeight` 1,5,
  `popularityScale` 8. Ham puan istemciye dönmez (yalnız 0..100 gösterim puanı döner).
- **Senin İçin puanı** (`ReelsRanker.forYou`, `app.post.reels.forYou*`): `2,0*r/(r+3) + (takip ? 1,5 : 0) + 0,8*min(1, ln(1+yazarBeğenin)/ln 4) + 0,6*rastgele(tohum, gönderi)`; aday havuzu `forYouPoolSize` (150).

### 4. Kullanıcı "Popülerlik puanı"
- **Profilim** `GET /api/users/me` (`ProfileView`) ve **başkasının profili** `GET /api/users/{id}` (`PublicProfile`) yanıtına eklendi (alanlar yalnız doluysa gelir):
  `popularityScore` (0..100), `likesReceived` (aldığı toplam beğeni; görünür gönderiler), `postCount` (görünür gönderi sayısı), `followerCount`
  (`PublicProfile`'da zaten vardı; `ProfileView`'a eklendi). Gizli (kilitli) hesapta başkasına sayaçlar gibi bu alanlar da gelmez; engel gölge profilinde yoktur.
- Formül (`UserPopularityService.score`, `app.post.popularity.*`): her bileşen log ölçekli ve tavanlı `c = min(1, ln(1+x)/ln(1+tavan))` (takipçi tavanı 500, beğeni 2000,
  gönderi 60); `puan = round(100 * (0,45*c_takipçi + 0,40*c_beğeni + 0,15*c_gönderi))`. Saatlik iş (`recomputeMs`, `SchedulerLock`) `user_popularity` tablosunu günceller
  (yalnız değişen satır yazılır); satırı olmayan yeni kullanıcı için anında hesaplanır. Gecikme en çok ~1 saat; `followerCount` (profilde) canlıdır.
- Hesap silinince satır silinir (`PostAccountPurger`).

### 5. Tekrar göstermeme (görülmüş kümesi): `GET /api/feed` `foryou` ve `popular` kapsamları (Reels kendi geçmişini kullanır, bölüm 6)
- Redis `feedseen:<uid>` (ZSET, skor = görülme damgası, **TTL 48 sa, en çok 2000 öğe**; `FeedSeenService`). Sunucu bu akışlarda **döndürdüğü her sayfayı otomatik
  görülmüş sayar**; istemci ayrıca `POST /api/feed/seen {"ids":[91,92,...]}` (en çok **100** kimlik, dakikada 60) ile ekranda gerçekten görünenleri bildirir (yedek). Yanıt 204.
  Geçersiz kimlikler yok sayılır. Video kimlikleri ayrıca izleme geçmişine gösterim olarak yazılır (bölüm 6). `latest`/`following`/`department` ve Reels bu Redis kümesini kullanmaz.
- `cursor` yok (yenileme/ilk açılış): görülmüşler **hariç** akış döner (`foryou`, `popular`). Aynı oturumda sayfalama imleci tekrar üretmez.
- **Havuz tükenirse** (ilk sayfada görülmemiş gönderi kalmadı): en eski görülmüşlerden başlayarak tekrar eder, yanıtta **`exhausted:true`** (boş akış yok);
  tekrar sayfaları da kendi `nextCursor`'ı (`R|…` imleci) ile sonuna kadar gezilir ve aynı gezintide tekrar yoktur; tekrar gösterilenler yeni damga alır
  (sonraki yenileme farklı gönderilerle başlar). Normal sayfalarda `exhausted:false`. Sınır: son normal sayfa dolu değilse (az görülmemiş kaldı) o sayfa kısa
  döner, doldurma yapılmaz; sonraki yenileme tekrar moduna geçer. `latest`/`following`/`department` kapsamlarında `exhausted` alanı hiç gelmez.
- Depo hatasında (Redis yok) küme boş sayılır: akış çalışır, tekrar göstermeme geçici olarak uygulanmaz.
- KVKK: kısa ömürlü teknik veri (48 sa), kimliklerden başka bir şey içermez; hesap silinince `feedseen:<uid>` silinir; `GET /api/users/me/export`'a **girmez**.

### 6. Reels: `GET /api/feed/reels?cursor&size&replay` (öneri algoritması, genişletme: 2. istek)
- Yalnız **video** gönderiler; yanıt `FeedPage` (`items, nextCursor, hint, exhausted`). `size` varsayılan **8**, üst sınır **20**; dakikada 120 okuma. İlk sayfa `cursor` boş (pull-to-refresh = yeni oturum);
  imleç opak (oturum kimliği + tohum + tekrar modu + önceki sayfanın son yazarı taşır). Tam ekran dikey oynatma istemcidedir (`video.url` Bearer + Range).
- **Oturum** = imleçsiz çağrıdan sonraki imleç zinciri. Sunucu döndürdüğü videoları oturum kümesine yazar (Redis `reelsess:<uid>:<sid>`, 6 sa): **aynı video aynı oturumda tekrar gelmez**.
  Pull-to-refresh yeni oturum + yeni rastgelelik tohumu başlatır: sıra kontrollü yeniden üretilir (aynı video hep ilk gelmez), yeni yüklenen videolar katılır.
- **Aday havuzu (normal mod):** görünür videolar − "ilgilenmiyorum" dediklerin − son `resurfaceAfterDays` (14) günde **ekranda gördüklerin** (izleme geçmişi) − oturumda gösterilenler. Yani **izlenmemişler öncelikli**:
  önce hiç görmediğin videolar gelir; 14 günden eski izleme kaydı olanlar yeniden aday olur (cezalı).
- **Puan** (kural tabanlı, ML yok; `ReelsRanker.score`, ağırlıklar `app.post.reels.*`, aday havuzu rank_score sırasında ilk `poolSize` (200) video):
  `puan = freshWeight*0,5^(yaşSaat/freshHalfLifeHours) + (izlenmemişse unseenBonus) + interestWeight*min(1, ln(1+yazarBeğenin)/ln 4) + (takip ? followBonus : 0) + qualityWeight*gönderiPuanı/100 + randomWeight*rastgele(tohum, video)`
  `− recentSeenPenalty*max(0, 1 − sonİzlenmedenSaat/recentSeenHours) − repeatPenalty*ln(1+gösterim) − quickSkipPenalty*min(hızlıGeçme, 3)`.
  Varsayılanlar: fresh 2,0 (yarı ömür 72 sa), unseen 1,5, interest 1,0, follow 1,2 (ölçülü), quality 2,0, random 1,0, recentSeen 2,5 (24 sa), repeat 0,8, quickSkip 1,0 (hızlı geçme = < 1500 ms ya da süresi ≥ 5 sn videoda < %15).
  Tek yazarın videoları ardışık gelmez (`maxAuthorRun` 1; sayfa sınırında da önceki sayfanın son yazarı bir sonrakinin ilki olmaz).
- **İçerik tükenince (sonsuz döngü YOK):** aday kalmadıysa sayfa `items:[]` (ya da son kısmi sayfa) + `nextCursor:null` + **`exhausted:true`** döner (`exhausted = nextCursor == null`). İstemci
  "Şimdilik tüm videoları gördün" bilgi alanını + **Tekrar izle** + alternatif (Keşfet gönderileri / takip önerileri) gösterir. **Tekrar izle:** `GET /api/feed/reels?replay=true` (imleçsiz, ilk çağrı) =
  geçmişi yok sayan yeni oturum: tüm görünür videolar aday (yalnız "ilgilenmiyorum" hariç), sıralama cezalarla yapılır (en az yakın zamanda izlenen, hızlı geçilmemiş önce); imleçle sonuna kadar gezilir (`replay` imleçte taşınır), biterse yine `exhausted:true`.
  Geçmiş silinmez (`replay` yalnız bu oturum için yok sayar); 45 günden eskisi zaten düşer.
- **İzleme geçmişi** (tablo `post_watch`, V1221; kullanıcı + video: ilk/son görülme, gösterim sayısı, toplam izleme süresi, en yüksek tamamlanma %, hızlı geçme sayısı, ilgilenmiyorum; beğeni/yorum/kaydetme durumu kendi tablolarından okunur):
  - **Gösterim:** istemci ekranda görünen video kimliklerini `POST /api/feed/seen` ile bildirir (sunucu Reels sayfası döndürmekle gösterim YAZMAZ; istemci önden yüklediği ama göstermediği videolar "görülmüş" sayılmaz).
  - **İzleme olayı:** `POST /api/posts/{id}/view {watchedMs, durationMs}` (bölüm aşağıda) aynı zamanda geçmişe yazar: toplam süre, tamamlanma, hızlı geçme. Geçmiş yazımı Redis 6 saatlik sayaç tekilleştirmesinden bağımsızdır (her olay geçmişe işlenir).
  - **Saklama:** 45 gün (`PostWatchRetentionJob`, 05:20; `app.post.reels.retention-days`). KVKK: hesap silinince satırlar silinir (`PostAccountPurger` → `ReelsService.purge`), `GET /api/users/me/export` içinde `reelWatchHistory` bölümü vardır; Redis oturum kümeleri 6 saat TTL ile düşer.
- **"İlgilenmiyorum":** `POST /api/posts/{id}/not-interested` → **204** (gönderi görünürse; yoksa 404 `POST_NOT_FOUND`; dakikada 30). Gönderi bu kullanıcının Reels ve "Senin İçin" önerilerinden kalkar (45 gün). Geri alma: `DELETE /api/posts/{id}/not-interested` → 204. Üç nokta menüsünde kullanın.
- **İzlenme olayı:** `POST /api/posts/{id}/view` `{"watchedMs":12000,"durationMs":18400}` -> **204** (sayılmayan olaylar sessizce yok sayılır).
  Gönderi sayacı: yalnız başkasının görünür **video** gönderisi; kullanıcı başına gönderi başına **6 saatte bir kez** (Redis `pview:<postId>:<uid>`); en az `min(1 sn, süre)` izlenmiş olmalı;
  süre olarak sunucudaki video süresi (istemcinin `durationMs`'i yalnız yedek); tamamlanma yüzdesi `min(100, watchedMs*100/süre)`. İstemci videodan çıkınca/bitince **bir kez** göndermelidir (erken olay pencereyi tüketir).
  Dakikada 240. `404 POST_NOT_FOUND` yalnız gönderi yoksa/görünmezse. Etki: `post.view_count`, `post.completion_pct_sum` -> puan `viewWeight`/`completionWeight`. Analytics `kind` listesine yeni eylem EKLENMEDİ.

### 7. Yönetici
- `GET /api/admin/posts` yeni süzgeç `type=PHOTO|VIDEO`; satırda `type`, `viewCount`, `avgCompletionPct` (ortalama tamamlanma %) ve `media[]` (video için `kind:"VIDEO"`,
  `durationMs`, önizleme `GET /api/admin/posts/media/{id}` Range destekli, `thumbUrl` poster). Gizle/sil/düzenle uçları aynı; yeni admin ucu yok, `AdminPermissionPolicy` değişmedi.
- Web yönetim paneli (`PostsAdminPage`) video satırını `kind` ile ayırt edip oynatıcı göstermelidir (bu görevin kapsamı dışında: backend ajanı).

### 8. Şema (`V1220__kesfet_video_popularity.sql`) ve kod haritası
- `post.kind` (`PHOTO|VIDEO`, eski veri ilk medyasına göre doldurulur), `post.view_count`, `post.completion_pct_sum`; indeks `pv_post_kind_rank_idx` (reels); tablo `user_popularity`
  (`user_id` PK, `score`, `follower_count`, `likes_received`, `post_count`, `computed_at`).
- V1221 (`post_watch`): kullanıcı bazlı izleme geçmişi (bölüm 6); indeks `pv_post_watch_*`. Yeni paket `post.reels` (`ReelsService`, `ReelsRanker`, `ReelsProperties` = `app.post.reels.*`, `PostWatch*`, `PostWatchRetentionJob`); `PostCursor` `E|` (Reels) ve `F|` (Senin İçin) imleçleri; `FeedSeenStore.sessionAdd/sessionIds`.
- Yeni: `post.feed` (`FeedSeenService`, `FeedSeenStore` = `RedisFeedSeenStore` | `InMemoryFeedSeenStore` (test, `app.feed.seen-store=memory`)), `post.popularity`
  (`UserPopularityService`, `PopularityProperties`, `UserPopularity*`), `WebmInfo`/`Mp4Info.isVideoBrand` (`media`), `PostMediaBinder.requireMedia`, `PostCounters.addView`,
  `PostRankRepository.{topFirst,topAfter,reelsFirst,reelsAfter,visibleByIds,visibleVideosByIds}` (görülmüş hariç tutma `NOT IN`).
- `PostRepository.FEED_VISIBLE` artık "görünür **herhangi bir** medya" ister (önceden yalnız fotoğraf); medyasız eski metin gönderileri hâlâ listelerde/aramada yok.
  `PostSearchProvider` aynı kuralı izler (video gönderisi aramada da çıkar).
- Testler: `PostFeedSeenTest` (foryou, reels, geçmiş, ilgilenmiyorum), `ReelsRankerTest`, `UserPopularityTest`, `PostRankTest`, `WebmInfoTest`, `PostMediaServiceTest` (MOV/WebM/HEIC), `PostServiceTest`/`PostTopFeedTest` güncel.
  PostgreSQL'e özgü kısımlar (V1220 migration, `NOT IN` + kısmi indeks planı, Redis ZSET işlemleri) H2'de değil `scripts/smoke-kesfet-video.sh` ile doğrulanır.
- Dağıtım notu (koordinatör): `MULTIPART_MAX_FILE=52MB`, `MULTIPART_MAX_REQUEST=54MB` (compose/.env.prod.example güncellendi), Caddy `CADDY_MAX_BODY` >= 55 MB; V1220 yalnız
  ALTER ADD COLUMN (varsayılanlı) + UPDATE + CREATE; Flyway V1240 (davranış analizi) ile çakışmaz.
## KS-BE2 (V1230): Keşfet yorumları + yanıtlar + yorum beğenisi, gönderi kaydetme, kullanıcı arama, REELS arama, profil sayaçları (2026-11-04)

**Kararlar (kullanıcı, 2026-11-04):** V470'te kaldırılan **yorum** ve **kaydet** özellikleri geri geliyor (gönderi + reel için), iç içe yanıtlar ve yorum beğenisi eklendi; genel kullanıcı arama iyileşti (Türkçe harf duyarsız, kısmi eşleşme); Reels arama türü; profil sayaçları. Bu bölüm mobil ajanların (KS-MB, SR-MB, CI-MB) sözleşmesidir. `docs/MOBILE_API_GUIDE.md` içindeki eski "SADE KEŞFET" kutusunun "yorum/kaydet kaldırıldı (410)" satırı bununla çelişirse **bu bölüm geçerlidir** (etiket `#`, bahsetme `@`, hikâye, video-dışı kaldırılanlar aynen kaldırıdır). Aşağıdaki kod haritası KS-BE (V1220) ile birleşmeye hazırdır (bkz. "Birleşme notları").

### 1. `PostView` ek alanları (tüm gönderi listeleri ve `GET /api/posts/{id}`)
- `commentCount` (int): gönderideki **görünür** yorum + yanıt sayısı (silinmiş/gizlenmiş yorum ve onların yanıtları sayılmaz). Atomik sayaç (`post.comment_count`); gece onarımı (`CommentCounterRepairJob`, 03:40).
- `savedByMe` (bool): bakan bu gönderiyi kaydetmiş mi (yalnız kendi görünümünüzde; başkasının kaydettiği hiçbir yerde görünmez).
- Diğer alanlar değişmedi. (Video/Reels alanları — `type`, `video`, `viewCount`, `popularityScore` — KS-BE sözleşmesindedir.)

### 2. Yorumlar ve yanıtlar (`post.comment`)
Tüm uçlar Bearer ister. Yorum **görünürlüğü gönderinin görünürlüğünü izler**: gönderi bakana görünür değilse (silinmiş, gizli, yazar pasif, iki yönlü engel, gizli hesap + takipçi değil) `404 COMMENT_NOT_FOUND` (gönderi varlığı sızdırılmaz). Yorum yazarı pasifse ya da bakanla arada engel varsa o yorum listede/uçlarda **yoktur** (iki yönlü). Silinmiş ya da yönetici/rapor ile gizlenmiş yorum listelerde yoktur.

**Modelin kuralları**
- En çok **iki seviye**: ust düzey yorum + yanıtlar. Bir yanıta verilen yanıt **ust düzey yoruma yassılanır**: sunucu `parentId`'yi ust yorum yapar, asıl muhatabı `replyTo` ile döner (UI "@ad" gösterir). İstemci yanıtlanan yorumun `id`'sini `parentId` alanında göndermeye devam eder (ust yorum ya da yanıt).
- Metin: **1-300 karakter** (Unicode kod noktası), baş/son boşluk ve 3+ ardışık satır sonu temizlenir, kontrol karakterleri atılır; satır sonu serbest. `ContentGuard` (uygunsuz ifade filtresi) uygulanır: `422 CONTENT_PROFANITY` + `field:"text"` (kelime yankılanmaz).
- Düzenleme **yok** (silip yeniden yazılır).

**Uçlar**

| Uç | Açıklama |
|---|---|
| `GET /api/posts/{id}/comments?sort=top\|new&cursor=&size=` | `CommentPage`. `sort` varsayılan `top` (beğeni çok olan önce, sonra yeni), `new` (yeniden eskiye). `size` varsayılan 20, üst sınır 50. `nextCursor` opak (`null` = son); sort değişince imleç atılır. |
| `POST /api/posts/{id}/comments` `{text, parentId?}` | **201** `CommentView`. `parentId` aynı gönderideki görünür bir yorum olmalı (başka gönderinin yorumu → 404 `COMMENT_NOT_FOUND`). Dakikada 20 / saatte 200. |
| `GET /api/post-comments/{cid}` | Tek yorum (`CommentView`); bildirimden yorumu açmak için. |
| `GET /api/post-comments/{cid}/replies?cursor=&size=` | Bir ust yorumun yanıtları **eskiden yeniye**, `CommentPage` (`total` = yanıt sayısı). `size` varsayılan 10, üst sınır 50. Yanıtın yanıtı yoktur: yanıt id'si verilirse 404. |
| `DELETE /api/post-comments/{cid}` | **204**. Yorumun yazarı, **gönderinin sahibi** ya da (content.hide izinli) yönetici. Ust yorum silinince yanıtları da gider; yetkisiz ama görünür → `403 COMMENT_FORBIDDEN`, görünmez → 404. Metin temizlenir (KVKK). |
| `PUT /api/post-comments/{cid}/like` | `{liked:true, likeCount}`; idempotent (çift PUT sayacı bozmaz). Dakikada 120. |
| `DELETE /api/post-comments/{cid}/like` | `{liked:false, likeCount}`; idempotent. |
| Şikâyet: `POST /api/reports` `{targetType:"COMMENT", targetId:<yorum id>, reason, note?}` | Mevcut rapor akışı (bkz. MOBILE_API_GUIDE moderasyon). Görünmeyen yorum 404; eşik aşılırsa **otomatik gizlenir** (geri alınabilir, itiraz edilebilir). |

Okuma uçları dakikada 240; yazma 60. Aşımda `429` + `Retry-After`.

**`CommentView`**
```json
{"id":55,"postId":91,"parentId":null,
 "author":{"id":7,"displayName":"Ayşe Y.","avatarUrl":"/files/avatars/x.jpg","department":"Bilgisayar Müh."},
 "text":"harika kare","likeCount":3,"likedByMe":false,"replyCount":2,"createdAt":"2026-11-04T10:00:00Z",
 "mine":false,"byPostAuthor":false,"canDelete":false}
```
Yanıtta ek: `"parentId":55` ve (yanıta verilen yanıtta) `"replyTo":{"commentId":56,"authorId":9,"displayName":"Veli K."}`; ust yoruma doğrudan yanıtta `replyTo` **yok** (asıl muhatap `parentId`'nin yazarıdır).
- `author.avatarUrl`/`department` yazarın gizlilik ayarına göre `null` olabilir (profil gizliliği). Avatara uzun basma/profil için `author.id` kullanılır.
- `byPostAuthor`: yorumu gönderi sahibi yazdı ("Yazar" rozeti). `canDelete`: kendi yorumunuz, gönderi sahibisiniz ya da yetkili yönetici.
- `replyCount`: görünür yanıt sayısı (yalnız ust yorumda anlamlı); yanıtlar ayrı uçla çekilir (satırda önizleme yok).

**`CommentPage`:** `{items:[CommentView], nextCursor:string|null, total:int}`. Ust yorum listesinde `total` = gönderi `commentCount`'u (yorum + yanıt); yanıt listesinde `total` = o yorumun `replyCount`'u.

**Bildirimler** (alıcının dilinde; tercih/sessiz saat uygulanır; kendine ve engelliye gitmez): `POST_COMMENT` ("{ad} gönderine yorum yaptı", gönderi sahibine) ve `COMMENT_REPLY` ("{ad} yorumuna yanıt verdi", yanıtlanan yorumun yazarına; gönderi sahibi başka biriyse ona da "yorum yaptı" gider). Push `data`: `target=POST`, `targetType=POST`, `targetId=<gönderi id>`, `postId`, `commentId` (mobil gönderi/reel yorum panelini açar, `commentId` vurgulanır). Beğeni bildirimi **yok** (spam).

**Hata kodları (tr/en/ar `i18n/comment*.properties`):** `COMMENT_NOT_FOUND` 404, `COMMENT_EMPTY` 400, `COMMENT_TOO_LONG` 422 (arg: 300), `COMMENT_FORBIDDEN` 403; mevcut: `POST_CURSOR_INVALID` 400, `VALIDATION_ERROR` 400 (geçersiz `sort`), `CONTENT_PROFANITY` 422.

### 3. Gönderi / reel kaydetme (`post.save`)
| Uç | Açıklama |
|---|---|
| `PUT /api/posts/{id}/save` | `{saved:true, saveCount}`; idempotent. Gönderi bakana görünür değilse `404 POST_NOT_FOUND`. Kendi gönderiniz de kaydedilebilir. Dakikada 120. |
| `DELETE /api/posts/{id}/save` | `{saved:false, saveCount}`; idempotent; gönderi sonradan gizlense/silinse de kaydı kaldırabilirsiniz. |
| `GET /api/posts/saved?cursor=&size=` | Kaydedilenler, **yeni kaydedilen önce**, `FeedPage` (`{items:[PostView], nextCursor, hint, locked}`; `savedByMe` hep true). `size` varsayılan 20, üst sınır 30. Sonradan silinen/gizlenen/engellenen yazarın/gizli hesabın gönderisi **sessizce listelenmez** (kayıt satırı kalır; görünür olunca geri gelir). |
- `saveCount` yalnız bilgi (kim kaydetti **hiçbir yerde** gösterilmez). Reel de bir gönderidir: aynı uçlar.
- Hesap silinince kayıtlar silinir; KVKK dışa aktarım `postSaves`.

### 4. Kullanıcı arama: `GET /api/users/search` (geriye uyumlu genişletme)
`GET /api/users/search?q=&size=20&cursor=` yolu, parametreleri ve yanıt biçimi (`{items:[PublicProfile], nextCursor:number|null}`) **aynı**; davranış iyileşti:
- **Türkçe harf ve büyük/küçük harf duyarsız:** `ŞİRİN`, `sirin`, `Şirin`, `ısık`/`ISIK`/`Işık` hepsi eşleşir (İ I ı i, Ş ş, Ğ ğ, Ü ü, Ö ö, Ç ç ve â î û katlanır).
- **Kısmi eşleşme (adın herhangi bir yerinde):** her boşlukla ayrılmış parça (en çok 3; fazlası son parçaya eklenir) adda geçmeli: `yıl` → "Şirin **Yıl**dız", `sirin yil` → "Şirin Yıldız". Sıralama: tam ad > ad/soyad **önek** eşleşmesi > diğerleri; sonra alfabetik.
- **Dışlananlar:** kendiniz, iki yönlü engel ilişkisi olanlar, askıdaki/silinmiş/e-postası doğrulanmamış hesaplar. Gizli (private) hesaplar **aranabilir** (satırda `isPrivate`/`followState`/`locked`; takipçi/takip sayıları gizli hesapta da dolu gelir, bkz. "Gizli hesapta herkese açık sayılar").
- **Yeni satır alanları:** `followedByMe` (bakan o kişiyi takip ediyor; gizli hesapta yalnız kabul edilmiş takip), `followsMe` (o kişi bakanı takip ediyor), gerçek `followerCount`/`followingCount`. Eskiden bu alanlar arama satırında `null`'dı.
- **İmleç:** `cursor`/`nextCursor` **sayısal** (atlanacak kayıt sayısı; mobil `int` okumaya devam eder), arama başına en çok 200 sonuç (kullanıcı dizini taramayı zorlaştırır); sonda `nextCursor:null`. `q` en az 2 karakter (`400 QUERY_TOO_SHORT`). Dakikada 60, günde 500.
- Arama yalnız **görünen ad** üzerindedir; **kullanıcı adı (@handle) yoktur** (modelde alan yok — ürün kararı gerekir); bölüm/fakülte araması yoktur (gizlilik ayarına tabi alan; sızdırmamak için eklenmedi).
- Performans: `usr1230_name_fold_trgm` (pg_trgm GIN, katlanmış ad). Sorgu ifadesi `TrFold.SQL_FROM/SQL_TO` ile indeksle **birebir** aynıdır (değişirse ikisi birlikte).

### 5. Genel arama: `GET /api/search` yeni tür `REELS`
`GET /api/search?q=&type=REELS&limit=&cursor=` (ve `type` verilmezse gruplu özette yeni `REELS` grubu). Reels = **görünür VIDEO medyalı gönderiler**, **açıklaması** (gönderi metni) aranır (PostgreSQL Türkçe tam metin + ILIKE yedeği; `POSTS` türüyle aynı görünürlük: silinmemiş, gizli değil, aktif yazar, iki yönlü engel yok, gizli hesap kapısı).
- `SearchHit` (REELS): `{type:"REELS", targetId:<gönderi id>, title:<yazar adı>, snippet:<açıklama ≤160>, imageUrl:<poster ya da null>, date, likeCount, durationMs}`; sonuca dokunulunca `GET /api/posts/{targetId}` (`PostView`) ile Reels oynatıcı açılır. `imageUrl` poster yoksa `null`.
- `type=POSTS` değişmedi. **Not:** KS-BE birleşince `POSTS` sonuçları video gönderileri de içerir (aynı gönderi `POSTS` ve `REELS`'te çıkar); mobil `Tümü` sekmesinde `REELS` grubunu ayrı çizmeli ya da `POSTS` içinde `REELS`'e giren id'leri ayıklamalıdır (Gönderiler sekmesi `PostView.type==PHOTO` ile süzülebilir).
- Sayfalama aynı: `nextCursor` sayısal, en çok 1000 sonuç.

### 6. Profil sayaçları ve `GET /api/users/{id}/reels`
- **`GET /api/users/me`** (`ProfileView`) ve **`GET /api/users/{id}`** (`PublicProfile`) yanıtlarına `postCount` ve `reelCount` eklendi (alan yoksa hiç gelmez): `postCount` = bakandan bağımsız **görünür gönderi sayısı** (silinmemiş, gizlenmemiş, en az bir görünür medya; **Reels dahil**), `reelCount` = bunlardan **video** olanlar. Gizli (kilitli) hesapta başkasına **gelmez** (sayaçlar gibi gizlenir); engel gölge profilinde sabit `0/0`; kendi profilinizde hep gelir.
- **`GET /api/users/{id}/reels?cursor=&size=`**: o kullanıcının video gönderileri, **yeni önce**, `FeedPage` (`{items:[PostView], nextCursor, hint, locked}`); `size` varsayılan 12, üst sınır 20. Gizli hesap + takipçi değil → boş liste + `locked:true` (403 değil; `/users/{id}/posts` ile aynı). Engel/pasif yazar → boş. Dakikada 120. Profilde sekme: **Gönderiler** = `GET /api/users/{id}/posts` (KS-BE birleşince foto + video), **Reels** = bu uç. Reel kapağında görüntülenme için `PostView.viewCount` (KS-BE; video gönderide).

### 7. Yönetici (RBAC)
| Uç | İzin |
|---|---|
| `GET /api/admin/posts/{id}/comments?cursor=&size=&status=ALL\|VISIBLE\|HIDDEN\|DELETED` | `content.read`. Yorum + yanıt satırı: `{id, postId, parentId, replyToId, author{id,displayName,email(maskeli),avatarUrl}, text, likeCount, replyCount, hidden, deleted, hiddenReason, createdAt, hiddenAt, deletedAt, deletedBy, openReportCount}`; imleç = yorum id (yeni önce), `{items, nextCursor}`. |
| `POST /api/admin/post-comments/{id}/hide` `{reason?}` · `POST .../unhide` | `content.hide`; satır döner; sayaçlar yeniden hesaplanır. |
| `DELETE /api/admin/post-comments/{id}` `{reason?}` | `content.hide`; 204. Açık COMMENT raporu varsa `ReportService.resolve(HIDE)` ile sonuçlandırılır (yazara + raporlayanlara bildirim, ihlal kaydı), yoksa yazara "kaldırıldı" bildirimi. Yazma işlemleri `AuditInterceptor` ile denetlenir. |
- `AdminPermissionPolicy` kuralları eklendi (`RbacCoverageTest` yeşil). Kullanıcı ucu `DELETE /api/post-comments/{cid}` içerik-kaldırma izni (`content.hide`) olan yöneticide başkasının yorumunu siler ve `admin_audit`'e düşer (`SystemAdminAudit`, `POST_COMMENT`).
- Moderasyon kuyruğu: `ReportTargetType.COMMENT` (`CommentReportHandler`: görünürlük, gizle/geri al, önizleme metni). Web yönetim paneli arayüzü bu görevin kapsamı dışındadır (`PostsAdminPage`'de yorum listesi için yukarıdaki uçlar kullanılır).

### 8. KVKK
- Hesap silme (`AccountDataPurger` → `PostAccountPurger` → `CommentAccountPurger`): yorum beğenileri ve kaydedilenler silinir (sayaçlar düşer); yazılan yorum/yanıtların metni temizlenip yumuşak silinir, etkilenen gönderi/yorum sayaçları yeniden hesaplanır. `AccountDataPurgerCoverageTest` listeleri: `post_comment.author_id`, `post_comment_like.user_id`, `post_save.user_id` (HANDLED_ELSEWHERE), `post_comment.deleted_by` (RETAINED).
- Dışa aktarım (`GET /api/users/me/export`): `postComments`, `postCommentLikes`, `postSaves` bölümleri (yalnız kendi verisi).

### 9. Şema (`V1230__kesfet_comments_saves.sql`) ve kod haritası
- `post.comment_count`; tablolar `post_comment` (`parent_id` ust yorum, `reply_to_id` asıl muhatap, `like_count`, `reply_count`, `deleted_at/by`, `hidden_at/reason`), `post_comment_like`, `post_save`; indeksler `pcm1230_*`, `pcl1230_*`, `psv1230_*`, `usr1230_name_fold_trgm` (V470'te düşen eski tablolarla çakışmaz; indeks adları benzersiz).
- Yeni kod: `post.comment` (`PostCommentService/Controller`, `CommentCounters`, `CommentNotifier`, `CommentReportHandler`, `AdminPostComment*`, `CommentAccountPurger`, `CommentExporters`, `CommentCounterRepairJob`), `post.save` (`PostSaveService/Controller`; `post.spi.PostSaveLookup`), `post.reel` (`UserReelsService/Controller`, `ReelRepository`, `ReelSearchProvider`, `ProfilePostCounts`), `search.TrFold`, `UserRepository.searchByNameFolded`, `FollowService.statsFor`.
- Testler (H2): `PostCommentServiceTest`, `PostSaveServiceTest`, `UserReelsTest`, `TrFoldTest`, `UserSearchTest`; PostgreSQL'e özgü kısımlar (V1230, kullanıcı arama sorgusu + trigram, REELS arama) H2'de değil `scripts/smoke-kesfet-social.sh` ile doğrulanır (geçici `postgres:16` konteynerinde sınandı).

### 10. Birleşme (KS-BE V1220/V1221 ile birleştirildi; çözüm)
- `PostView` alan sırası: `..., editedAt, type, video, viewCount, popularityScore, commentCount, savedByMe` (KS-BE alanları + bu dalın alanları).
- Profil: `postCount` **tek** (KS-BE `UserPopularityService` kaynaklı, `Integer`), bu dal yalnız `reelCount` (`Long`, video gönderi sayısı) ekler: `ProfileView`/`PublicProfile` sonunda; `withReelCount(...)`. Gizli/kilitli hesapta ikisi de gelmez; engel gölge profilinde `reelCount=0`.
- `post.reel` (bu dal: profil Reels listesi, REELS arama, `ProfilePostCounts`) ile `post.reels` (KS-BE: Reels önerisi/izleme geçmişi) farklı paketlerdir.
- `PostService.byAuthor` KS-BE sonrası video gönderileri de içerir (Gönderiler sekmesi = foto + video); Reels sekmesi `GET /api/users/{id}/reels`. `POSTS` aramasında da video gönderiler çıkar; `REELS` arama onların alt kümesidir.
- **Önerilen kişiler sayfalama (2026-11-05):** `GET /api/users/me/follow-suggestions?page=0&size=10`. `page` 0 tabanlı (varsayılan 0, negatif 0 sayılır), `size` varsayılan 10, en çok 50. Gövde **hâlâ düz dizi** (eski istemciler bozulmaz); devam bilgisi yanıt başlığı `X-Has-More: true|false` (CORS'ta açık). Sıra kullanıcı başına 15 dk önbellekli anlık görüntüden gelir: CLUB, GRADE, DEPARTMENT; sonra takipçi sayısı ↓, id ↓ (sabit tie-break, sayfalar arasında tekrar/atlama yok). Toplam en çok 200 öneri; `page*size >= 200` ya da son sayfadan sonrası **400 değil boş dizi** (`X-Has-More: false`). Takip/engel/askı/doğrulanmamış/kendisi hariç ve gizlilik (`reasonVisible`) kuralları aynen; takip/engel her okumada süzülür, bu yüzden sayfalar arasında biri takip edilirse listeden düşer ve sonraki sayfa bir kayar (istemci `id` ile tekilleyin). Sayfa başına sorgu sınırlıdır (önbellek + 2 kısa süzme sorgusu + 50'lik parçalarla profil eşleme). Kullanıcıya özel yanıt; herkese açık önbelleğe girmez. `FollowService.suggestionsPage`; testler `FollowSuggestionsTest`.

### 11. Metin sınırı kalktı + gönderi etiketleme (2026-11-05, V1310)
Kullanıcı kararı: "7 kelime zorunluluğu kalksın, istediği uzunlukta paylaşsın (sınır olsun ama kullanıcıya gösterme); birini etiketleyebilir ama TAKİP ediyor olmalı; etiketlenene bildirim gitsin." **Bu bölüm 74. satırdaki ve "ilk gönderi onayı yok" notundaki 7 kelime/60 karakter/tek satır kuralının YERİNE geçer.**

**Metin (gizli üst sınır).** `PostDtos.POST_TEXT_MAX_CHARS = 2200` (Unicode kod noktası) ve `POST_TEXT_MAX_LINES = 40`; çok satırlı metin serbest, boş metin serbest. Aşımda `422 POST_TEXT_TOO_LONG` (artık argümansız genel mesaj: "Gönderi metni çok uzun."; sayı kullanıcıya gösterilmez). `POST_TEXT_INVALID` (tek satır) **kaldırıldı** (i18n anahtarı da silindi). Temizlik (`PostService.normalize`): satır sonları `\n`e indirgenir (CRLF, CR, NEL, U+2028/2029), kontrol karakterleri + sıfır genişlikli (U+200B/FEFF) atılır, sekme boşluk olur, kenar boşlukları kırpılır; `@Ad Soyad` metni **aynen** saklanır (sunucu metne dokunmaz). `ContentGuard` (küfür) ve yönetici düzenlemesindeki muafiyet aynen. Ham istek üst sınırı (`RAW_TEXT_LIMIT`, 8000) yalnız aşırı yükü keser. Eski istemci (60 karakter altı) etkilenmez.

**Etiket (mention).**
- `POST /api/posts` gövdesine `mentionUserIds: number[]` (isteğe bağlı), `PATCH /api/posts/{id}` gövdesine aynı alan. **PATCH'te alan YOK (null) = etiketler değişmez** (eski istemci); **var (boş dizi dahil) = liste yeniden yazılır**.
- Kurallar (`PostMentionService.validate`): en çok 10 **farklı** kişi (tekrarlı kimlik tekilleştirilir; 11. farklı kişi hata); her kişi `ACTIVE`, **yazar onu kabul edilmiş takip ediyor (`user_follow`)**, aralarında engel yok (iki yön), kendini etiketleyemez. Herhangi biri geçersizse **tüm istek** `422 POST_MENTION_INVALID` (genel mesaj, hangi kimliğin neden geçersiz olduğu sızdırılmaz; hiçbir gönderi/etiket/bildirim yazılmaz). DTO sınırı: `mentionUserIds` ≤ 50 (aşırı yük; aşarsa 400 doğrulama).
- Düzenlemede gönderide **zaten etiketli** kişiler yeniden doğrulanmaz (sonradan takipten çıkma/engel düzenlemeyi bozmasın; görünüm süzgeci zaten gizler); yeni eklenenler tam doğrulanır.
- `PostView.mentions: [{userId, displayName}]` (en sonda; yoksa `[]`). Bakana göre süzülür: pasif/silinmiş hesap herkesten, bakanla arasında engel olan kişi yalnız o bakandan gizlenir. Mobil, metindeki `@Ad Soyad` düz metnini `displayName` ile eşleştirir.
- Tablo `post_mention (post_id, user_id, created_at, PK(post_id,user_id))` + `pm1310_user_time_idx (user_id, created_at DESC)` (`V1310__post_mention_tag.sql`; yalnız ekleme; V340'ın V470'te düşen eski tablosundan bağımsız, hashtag/yorum-bahsetme GERİ GELMEDİ). Kod: `post.mention` (`PostMention`, `PostMentionId`, `PostMentionRepository`, `PostMentionService`), `PostService.create/update(+mentionUserIds)`, `PostViewAssembler`.
- Etiket önerisi için yeni uç yok: mobil `GET /api/users/{id}/following` + arama.

**Bildirim.** `PostNotifier.onMention` → `NotificationType.POST_MENTION` / alt tür `POST_MENTION` (zaten tanımlıydı; sosyal kategori, "communities" bayrağı, kanal `social`, push `style=SOCIAL`, kategori `BU_SOCIAL`). Başlık "Yeni etiket", gövde `{ad} seni bir gönderide etiketledi` / `{name} tagged you in a post` / ar (alıcının dilinde). `data`: `target=POST`, `value`/`postId`=gönderi, `userId`=etiketleyen (gelen kutusu avatar projeksiyonu için `ACTOR_TYPES`'a eklendi), `senderName`. Yalnız push yükü (kalıcı `data`ya yazılmaz): `senderAvatarUrl` (alıcı için `AvatarVisibility` süzgeci), `imageUrl` (gönderi küçük resmi/video posteri: CDN imzalı bağlantı açıksa o, değilse `PostView.thumbUrl` ile aynı oturumlu yol `/api/posts/media/{id}?thumb=true`; küçük resmi olmayan videoda yok). `collapseKey=postmention:<postId>`: aynı (gönderi, kişi) için **bir kez** (okunmuş/silinmiş olsa da ikinci bildirim yok; etiketi kaldırıp yeniden eklemek yeniden bildirmez). Gitmez: kendi kendine, engel ilişkisi, **alıcı yazarın gizli hesabının içeriğini göremiyorsa** (bildirim 404'e açılırdı), kullanıcı sosyal bildirimi kapattıysa. Düzenlemede yalnız YENİ eklenenlere gider.

**KVKK.** `AccountDataPurger.DELETES`: `DELETE FROM post_mention WHERE user_id = ?` (başkasının gönderisinde etiketlendiğim satırlar); `PostAccountPurger`: hesabı silinen yazarın gönderilerindeki etiketler silinir. Dışa aktarım bölümü `postMentions` (`taggedIn`: etiketlendiğim gönderi + yazar kimliği + zaman; `tagged`: kendi gönderilerimde etiketlediğim kimlikler; ad/metin yok).

**Video sınırları (değişmedi, mobil kırpma ekranı için):** süre ≤ 60 sn (+500 ms tolerans; aşımda `400 VIDEO_TOO_LONG`, arg 60), dosya ≤ 50 MB = 52 428 800 bayt (`413 VIDEO_TOO_LARGE`, arg 50), biçim MP4/MOV(QuickTime)/M4V/WebM gerçek içerik doğrulamalı (`400 VIDEO_INVALID`), çözünürlük sınırı **yok** (sunucu ffmpeg varsa arka planda 720p/H.264'e dönüştürür, o zamana dek orijinal sunulur), saatte 30 yükleme (`app.post.media.uploads-per-hour`), bağlanmamış medya ≤ 30 (`POST_MEDIA_PENDING_LIMIT`); multipart tavanı 52 MB/54 MB (`MULTIPART_MAX_FILE/REQUEST`), önündeki proxy ≥ 55 MB olmalı. Gönderi = tam 1 medya.

**Hukuki not.** Yayındaki sözleşme/gizlilik metni (V820, `V620` ailesi) "en çok 7 kelimelik kısa metin" der; sınır kalktığı için metin yeni hukuki sürümde güncellenmelidir (uygulanmış migration'a dokunulmadı; `LegalMigrationV820FileTest` artık yalnız `POST_TEXT_MAX_CHARS=2200`yi sabitler).

## Gizli hesapta herkese açık sayılar (2026-11-07)

- `GET /api/users/{id}` ve arama satırı: gizli (kilitli) hesapta `followerCount`, `followingCount` ve `postCount` (görünür gönderi sayısı) artık bakan takipçi olmasa da gelir; takip isteği/bırakma yanıtlarındaki `followerCount` da gerçek sayıdır. Listeler (`/followers`, `/following` -> `locked:true`), gönderi içeriği/ızgarası, medya dosyaları, `popularityScore`, `likesReceived` ve `reelCount` kilitliyken KAPALI kalır. Engel/askı kuralları aynı (engelli çift: sabit 0).
- Sohbet paylaşım kartı, gönderi detayı ve gönderi medyası zaten `PrivateAccountGate` ile bakana göre doğrulanır (kart `available:false`, detay/medya 404); değişmedi.

## Cok fotografli gonderi (2026-11-07)

- Bir gonderi 1..10 SIRALI fotograf VEYA tek video tasir. `POST /api/posts` govdesi `mediaIds: [..]` (sira = gosterim sirasi; tek elemanli liste eski davranisla aynidir). Asim: 422 `POST_MEDIA_LIMIT`; video + baska medya ya da birden cok video: 422 `POST_MEDIA_MIX`; tekrarli/yabanci/baglanmis/gizli medya: 400 `POST_MEDIA_INVALID` (hicbiri baglanmaz). `POST_SINGLE_PHOTO_ONLY` artik uretilmez (cevirisi birakildi).
- `PostView.media[]` tum fotograflari `position` sirasiyla doner (`{id,kind,url,thumbUrl,width,height,durationMs,position}`); `media[0]` eski istemcilerin gordugu ilk fotografla aynidir, yeni alan eski istemciyi bozmaz. Eski karisik veri (video + fotograf): ilk medya video ise yalniz o, degilse yalniz fotograflar gosterilir.
- Sema degisikligi YOK: `post_media (post_id, position)` ve `post.media_count` zaten coklu medyayi tasiyordu. Liste/akis yanitinda medya tek sorguyla (`findByPostIdIn`) toplu yuklenir; `requireMedia` tek `findAllById`. Silme/gizleme/admin/DataExporter/hesap silme zaten `post_id`/`owner_id` uzerinden tum satirlari kapsar. Medya erisimi (`PostMediaService.accessible`) her medya icin gizli hesap kuralini ayri uygular.
- Idempotency-Key ayni gonderiyi (tum medyasiyla) doner.

## Yorum sözleşmesi (2026-11-07, V1230 sistemi üzerine; yorum/yanıt/beğeni GERİ GELDİ)

**Karar (kullanıcı, WhatsApp 2026-11-07):** "Gönderilerin ve reels'lerin altına yorum ekleme, yorumu yanıtlama, beğenme olsun." Eski "yorum kaldırıldı" (V470) notları geçersizdir; sistem V1230'dan beri `post/comment` altındadır (yeni tablo/migration YOK, forum yorumlarından ayrıdır). Bu bölüm mobilin sözleşmesidir ve yukarıdaki KS-BE2 tablosundan farklı yerleri **geçersiz kılar**:

- **İki seviye, yanıta yanıt yok:** `parentId` yalnız aynı gönderideki görünür ÜST DÜZEY yorum olabilir; yanıt/başka gönderi/yok/silinmiş/gizli → `400 COMMENT_PARENT_INVALID` (eski "yassılama" ve `replyTo` kalktı; `replyTo` hep yok).
- **Uçlar (yeni takma yollar, eskiler çalışmaya devam eder):** `GET /api/posts/{id}/comments?sort=top|new&cursor=&size=20` (yalnız üst düzey; `{items,nextCursor,total}`), `GET /api/comments/{id}/replies?cursor=&size=` (eskiden yeniye, varsayılan 10 / en çok 50), `POST /api/posts/{id}/comments` `{body, parentId?}` (`text` de kabul) → 201 `CommentView`, `DELETE /api/comments/{id}` → 204, `PUT|DELETE /api/comments/{id}/like` → **204** idempotent. (Eski `/api/post-comments/{id}[/replies|/like]` yolları aynen durur; eski `like` yolları `{liked,likeCount}` gövdesi döndürür.)
- **Metin:** kırpılır, 1..500 kod noktası (`400 COMMENT_EMPTY`, `422 COMMENT_TOO_LONG`), uygunsuz ifade `422 CONTENT_PROFANITY`. `Idempotency-Key` başlığı `POST /api/posts/{id}/comments` için `IdempotencyFilter` ile desteklenir (aynı anahtar aynı yanıtı tekrar eder, anahtar kullanıcıya bağlıdır, Redis yoksa korumasız). Hız sınırı: dakikada 20 / saatte 200 yorum.
- **`CommentView`:** `{id, postId, parentId, author{id,userId,displayName,avatarUrl,department,username}, body, text, createdAt, likeCount, likedByMe, replyCount, mine, canDelete, byPostAuthor, deleted}` (`body`=`text`; `username` atanmamışsa `null`).
- **Silme + tombstone:** yorum sahibi, gönderi sahibi ya da yönetici siler (yumuşak, metin temizlenir). Yanıtı olan üst düzey yorum silinince YANITLARI KALIR ve listede `deleted:true`, `author/body/text:null`, `likeCount:0`, `mine/canDelete:false` olarak durur (tombstone; yanıtları `replies` ucundan okunur, tombstone'a yeni yanıt `400 COMMENT_PARENT_INVALID`); son yanıt silinince tombstone listeden kalkar. Gönderi `commentCount` yalnız canlı yorumları sayar (silinmiş tombstone sayılmaz). Eski davranış (üst yorum silinince yanıtların da gitmesi) kalktı. Engellenen/askıdaki yazarın yorumları listelenmez.
- **`commentCount`:** `PostView` (akış, reels, profil) zaten taşır; sayaçlar atomik `UPDATE`. `PostRankService` yorum sinyali bu iş kapsamında değişmedi.
- **Bildirim (SOCIAL, `communities` bayrağı + alt tür tercihi):** `POST_COMMENT` (gönderi sahibine), `COMMENT_REPLY` (üst yorum sahibine; gönderi sahibi farklıysa ona da `POST_COMMENT`), **yeni `COMMENT_LIKE`** (yorum sahibine, `NotificationType/Subtype.COMMENT_LIKE`, Hareketler "LIKES" sekmesi, `notif.comment.like.*`). Toplama anahtarı `pclk:<yorum>:<beğenen>`: aynı kişi geri alıp tekrar beğense ikinci bildirim yok; kendi içeriğine bildirim yok; engel ilişkisinde yok. Yük: `target:"POST"`, `value`/`targetId`=postId, `targetType:"POST"`, `postId`, `commentId`. Sessize alma (`notification_mute`) alıcı tercihi `NotificationService` içinde uygulanır.
- **Moderasyon/KVKK (değişmedi):** rapor `targetType:"COMMENT"` (`CommentReportHandler`), yönetici `/api/admin/posts` yorum uçları, `postComments`/`postCommentLikes` dışa aktarımı, hesap silmede `CommentAccountPurger` (yorumlar silinir/tombstone, beğeniler silinir).
- **Hatalar:** yeni `COMMENT_PARENT_INVALID` (tr/en/ar `comment*.properties`). Test: `PostCommentServiceTest` (tombstone, parent doğrulama, `body` takma adı, beğeni bildirimi), `IdempotencyFilterTest.postCommentCreateIsCovered`.

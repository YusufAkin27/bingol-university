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
- **Dışlananlar:** kendiniz, iki yönlü engel ilişkisi olanlar, askıdaki/silinmiş/e-postası doğrulanmamış hesaplar. Gizli (private) hesaplar **aranabilir** (satırda `isPrivate`/`followState`/`locked`; takipçi/takip sayıları kilitliyse `null`).
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

### 10. Birleşme notları (KS-BE V1220 ile)
- `PostDtos.PostView` (KS-BE `type`, `video`, `viewCount`, `popularityScore` ekliyor; bu dal `commentCount`, `savedByMe` ekliyor) → iki dalın alanlarını **sırayla** tutun: `..., editedAt, type, video, viewCount, popularityScore, commentCount, savedByMe`; `PostViewAssembler`'da tek `new PostView(...)` çağrısı iki taraftan güncellenir.
- `ProfileDtos.ProfileView/PublicProfile`: KS-BE `popularityScore`, `likesReceived`, `postCount`, `followerCount` ekliyor; bu dal `postCount` + `reelCount` ekliyor → **tek** `postCount` bırakın (anlam aynı: görünür gönderi sayısı), `reelCount` ek kalır; `withCounts(...)` yardımcıları tek imzada birleştirilir.
- `Post.java` (KS-BE `kind`, `viewCount`, `completionPctSum`; bu dal `commentCount`), `PostAccountPurger`, `AccountDataPurger` listeleri, `docs/changes/post.md` ve `MOBILE_API_GUIDE.md` sonları: metin birleşimi (iki taraf da ekleme).
- `ReelRepository.VIDEO` (EXISTS gorunur VIDEO medyası) KS-BE `post.kind='VIDEO'` ile eşdeğerdir; birleşince `kind` sütununa geçirilebilir (şart değil).
- KS-BE'nin `FEED_VISIBLE` değişikliği (foto-dışı medya da görünür) `ReelRepository` ve `ProfilePostCounts`'ı etkilemez (kendi `VISIBLE` + video koşulunu kullanırlar).

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

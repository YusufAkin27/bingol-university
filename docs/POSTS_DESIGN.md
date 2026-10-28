# Gönderiler (Keşfet akışı) — Tasarım ve API Sözleşmesi

> **GÜNCEL SÖZLEŞME (sade Keşfet, 2026-10-28) — aşağıdaki eski bölümlerle çelişirse BU kutu geçerlidir.**
>
> - Gönderi = **tam 1 fotoğraf (zorunlu) + isteğe bağlı çok kısa metin**. Video yok, galeri yok, yorum yok, hikâye yok.
> - **Kalan:** gönderi oluştur/oku/düzenle(yalnız metin)/sil, akış (`latest|popular|following|department`), **beğeni** (`PUT|DELETE /api/posts/{id}/like`), takip, rapor (`FEED_POST`; geçmiş `FEED_COMMENT`/`STORY` raporları da çözülebilir), yönetici moderasyonu.
> - **Oluşturma (iki adım, değişmedi):** 1) `POST /api/posts/media` (multipart `file`, **yalnız görsel**; video yüklemesi → `400 POST_VIDEO_NOT_ALLOWED`) → `{id,…}`; 2) `POST /api/posts` `{ "text": "…"?, "mediaIds": [12] }` → 201 `PostView`.
>   - `mediaIds` **tam 1 eleman**: boş/yok → `400 POST_PHOTO_REQUIRED`; 2+ (ya da aynı id tekrarı) → `400 POST_SINGLE_PHOTO_ONLY`; video medya → `400 POST_VIDEO_NOT_ALLOWED`; başkasının/kullanılmış/olmayan medya → `400 POST_MEDIA_INVALID`.
>   - `text` isteğe bağlı (boş/yalnız boşluk = `null`). Kural (sunucuda, PATCH dahil): **tek satır** (`\n`, `\r`, U+2028/2029… varsa `422 POST_TEXT_INVALID`), **en çok 7 kelime** (kelime ayırıcı = Unicode boşluk/ayırıcı `[\s\p{Z}]+`, NBSP dahil) ve **en çok 60 karakter** (kod noktası); aşımda `422 POST_TEXT_TOO_LONG` (mesaj argümanları `{0}`=7, `{1}`=60). Küfür filtresi (`422 CONTENT_PROFANITY`) aynen sürer. "Tek cümle" sunucuda ayrıca denetlenmez (7 kelime sınırı fiilen sağlar). Eski `POST_TOO_LONG` (2000) artık üretilmez; `POST_EMPTY` yalnız fotoğrafsız eski gönderiyi PATCH ile boşaltmada kalır.
> - **Kaldırılan uçlar — kalıcı `410 Gone` `{"code":"FEATURE_REMOVED","message":"Bu özellik kaldırıldı. Lütfen uygulamayı güncelleyin."}`** (kimliksiz istek yine 401): `GET|POST /api/posts/{id}/comments`, `GET /api/comments/{id}/replies`, `PATCH|DELETE /api/comments/{id}`; `POST /api/stories`, `GET /api/stories/tray`, `GET /api/users/{id}/stories`, `POST /api/stories/{id}/view`, `GET /api/stories/{id}/viewers`, `DELETE /api/stories/{id}`; `GET /api/hashtags/trending|suggest|{tag}/posts`; `GET /api/users/mention-suggest`; `PUT|DELETE /api/posts/{id}/save`, `GET /api/posts/saved`; `GET /api/posts/{id}/likes` (beğenenler listesi). Gerekçe: eski mobil sürümler bu yolları çağırmaya devam eder; 404 "hata/bilinmeyen" izlenimi verir, 410 "bilerek kaldırıldı, yeniden deneme" anlamındadır ve istemci güncelleme uyarısı gösterebilir. Tek yer: `post/RemovedFeatureController`.
> - **`PostView` alanları geriye uyumlu:** `commentCount` her zaman `0`; `savedByMe` `false`; `mentions` ve `hashtags` `[]`; `media` en çok **1** eleman (gönderideki ilk `IMAGE`; eski video/çoklu görsel gizlenir). Yeni istemci bu dört alanı okumamalıdır; alanlar gelecekte kaldırılabilir.
> - **Eski gönderiler (veri silinmez):** akış/profil listeleri (`/api/feed`, `/api/users/{id}/posts`, `/api/posts/mine`, takip/bölüm akışları) yalnız **görünür bir fotoğrafı olan** gönderileri verir; video-only ve fotoğrafsız (yalnız metin) eski gönderiler listelerden gizlenir, tabloda durur. `GET /api/posts/{id}` doğrudan erişimi bunları 404'e çevirmez (yalnız listeler süzülür). Yorum/hikâye/kaydet/etiket tabloları ve verileri korunur.
> - **Yönetici/KVKK:** `/api/admin/posts*`, `/api/admin/comments*`, `/api/admin/stories*` aynen çalışır (geçmiş içerik moderasyonu). `DataExporter` bölümleri (`posts`, `postComments`, `postLikes`, `savedPosts`, `follows`, `stories`) ve hesap silme anonimleştirmesi (`PostAccountPurger`, `SocialAccountPurger`) değişmedi: geçmiş yorum/hikâye verisi dışa aktarılır ve hesap silinince temizlenir.
> - **Zamanlayıcılar:** `StoryCleanupJob` (saat :35) çalışmaya devam eder — yalnız süresi dolmuş/silinmiş **eski** hikâyeleri mevcut saklama kuralıyla (bitişten 24 sa sonra) kalıcı siler; yeni hikâye oluşmadığından zamanla boşa çıkar. Diğer işler (`PostScoreJob`, `PostCounterRepairJob`, `PostRetentionJob`, `PostMediaJanitor`) değişmedi.
> - Etiket/bahsetme: oluşturma ve düzenlemede `SocialTextEvent` artık yayınlanmaz (hashtag indeksi ve `POST_MENTION` bildirimi üretilmez).
> - Yeni hata kodları (tr/en/ar `i18n/post*.properties`): `POST_PHOTO_REQUIRED`, `POST_SINGLE_PHOTO_ONLY`, `POST_VIDEO_NOT_ALLOWED`, `POST_TEXT_TOO_LONG` (422, 2 argüman), `POST_TEXT_INVALID` (422), `FEATURE_REMOVED` (410).

Kayıtlı ve e-postası doğrulanmış HER kullanıcı gönderi paylaşabilir (metin, çoklu görsel, video), gönderileri beğenebilir,
yorum yapabilir; yorumların altına yanıt yazılabilir (iç içe). Gönderiler mobilde **Keşfet** sekmesinde akış olarak gösterilir.
Bu belge backend, web (yönetici) ve mobil ajanları için TEK sözleşmedir; değiştirmeden önce raporlayın.

Mevcut "topluluk gönderileri" (`community` paketi, kulüp içi) AYRI bir özelliktir ve değişmez. Burada genel (kampüs geneli) gönderiler
anlatılır. Paket: `backend/.../post` (alt paketler: `media`, `comment`, `like`, `admin`). Rapor hedef türleri: `FEED_POST`, `FEED_COMMENT`.

## 1. Veri modeli (Flyway `V310__posts.sql`, TEK migration; tabloları agent A yazar, diğerleri yazmaz)

| Tablo | Alanlar |
|---|---|
| `post` | `id` BIGINT PK identity, `author_id` FK app_user, `body` TEXT (null olabilir; ≤2000), `like_count` INT, `comment_count` INT (silinmemiş TÜM yorum+yanıtlar), `media_count` SMALLINT, `created_at` TIMESTAMPTZ, `edited_at`, `deleted_at`, `deleted_by`, `hidden_at` (moderasyon), `hidden_reason`, `score` DOUBLE (popülerlik, işle güncellenir) |
| `post_media` | `id`, `post_id` FK null (yükleme sonrası bağlanır), `owner_id`, `kind` (`IMAGE`/`VIDEO`), `position` SMALLINT, `storage_key`, `thumb_key`, `content_type`, `width`, `height`, `duration_ms`, `bytes`, `sha256`, `created_at`, `hidden_at` |
| `post_like` | PK (`post_id`,`user_id`), `created_at` |
| `post_comment` | `id`, `post_id`, `parent_id` null, `root_id` null (kök yorumun id'si), `depth` SMALLINT (0 kök, 1 yanıt, 2, 3 en çok), `author_id`, `reply_to_user_id` null, `body` TEXT (≤1000), `reply_count` INT (doğrudan alt yanıt sayısı), `created_at`, `edited_at`, `deleted_at`, `deleted_by`, `hidden_at` |

İndeksler (önek `post310_`): `post(created_at DESC, id DESC) WHERE deleted_at IS NULL AND hidden_at IS NULL`, `post(author_id, created_at DESC)`, `post(score DESC, id DESC)`, `post_media(post_id, position)`, `post_media(owner_id) WHERE post_id IS NULL`, `post_comment(post_id, parent_id, created_at, id)`, `post_comment(root_id, created_at, id)`, `post_like(user_id, created_at DESC)`.
Sayaçlar atomik SQL (`UPDATE ... SET like_count = like_count + 1`) ile güncellenir; saatlik iş sayaçları gerçek sayımla onarır.

## 2. API (hepsi JWT ister; kullanıcı e-postası doğrulanmıştır; tarihler ISO UTC)

### Gönderi
- `POST /api/posts` `{ "text": "…"?, "mediaIds": [12,13]? }` → **201 PostView**. En az metin veya medya; metin ≤2000; en çok **10 medya** (foto+video karışık, en çok 10 video); medya yalnız kendi yüklediği ve henüz bağlanmamış olmalı (aksi 400 `POST_MEDIA_INVALID`). Küfür/argo filtresi (`ContentGuard`, herkese açık içerik) uygulanır → 422 `CONTENT_PROFANITY` (+ alan). Hız sınırı: saatte 20 gönderi.
- `GET /api/posts/{id}` → PostView (silinmiş/gizli/engelli → 404 `POST_NOT_FOUND`).
- `PATCH /api/posts/{id}` `{ "text": "…" }` → PostView (yalnız yazar, medya değişmez, `editedAt` dolar).
- `DELETE /api/posts/{id}` → 204 (yazar ya da ADMIN; yumuşak silme; medya dosyaları 30 gün sonra temizlenir).
- `GET /api/feed?scope=latest|popular&cursor=&size=` (size ≤20, varsayılan 10) → `{ "items": [PostView], "nextCursor": "…"|null }`. `latest` = yeniden eskiye; `popular` = son 7 günün skoruna göre (`score = (likes*1 + comments*2) / (yaşSaat+2)^1.2`, saatlik güncellenir; eşitlikte yenisi). Engelli kullanıcılar (iki yönlü) gizlenir; gizlenmiş/silinmiş gönderiler yok.
- `GET /api/users/{id}/posts?cursor=&size=` ve `GET /api/posts/mine?cursor=&size=` → aynı biçim (başkasının profili için engel ilişkisinde boş liste).

**PostView**
```json
{ "id": 91, "author": {"id": 12, "displayName": "Ayşe Yılmaz", "avatarUrl": "/files/avatars/…"|null, "department": "Bilgisayar Mühendisliği"|null},
  "text": "…"|null, "media": [ {"id": 5, "kind": "IMAGE"|"VIDEO", "url": "/api/posts/media/5", "thumbUrl": "/api/posts/media/5?thumb=true", "width": 1080, "height": 1350, "durationMs": null|12000} ],
  "likeCount": 4, "commentCount": 2, "likedByMe": false, "mine": false, "canEdit": false, "canDelete": false,
  "createdAt": "…", "editedAt": null }
```
Yazarın avatar/bölümü gizlilik ayarına (PublicProfileMapper) ve engel ilişkisine uyar (engelde `avatarUrl:null`).

### Medya
- `POST /api/posts/media` (multipart: `file`, video için isteğe bağlı `poster`) → **201** `{ "id", "kind", "url", "thumbUrl", "width", "height", "durationMs", "bytes" }`. Görsel: yeniden kodlama + EXIF temizliği (MediaService `ImageKind` yeni `POST`: en uzun kenar 1600 px, thumb 480 px). Video: mp4 (ftyp), ≤60 sn, ≤40 MB (`app.post.media.video-max-*`), poster zorunlu değil; Hata kodları sohbet video kalıbıyla: `VIDEO_TOO_LARGE` 413, `VIDEO_TOO_LONG` 400, `VIDEO_INVALID` 400, görsel için mevcut `IMAGE_*`; yasaklı özet (`ContentBlocklist`) → 422 `MEDIA_BLOCKED`. Kota: saatte 30 yükleme; bağlanmamış medya 24 saat sonra temizlenir (yetim süpürücü).
- `GET /api/posts/media/{id}[?thumb=true]` (yetkili; görsel/video akıtır; video **HTTP Range (206)**; `Cache-Control: private, max-age=86400`; ETag). Gizli/silinmiş gönderinin medyası 404 (ADMIN hariç: `GET /api/admin/posts/media/{id}`).

### Beğeni
- `PUT /api/posts/{id}/like` → **200** `{ "liked": true, "likeCount": 5 }` (idempotent). `DELETE /api/posts/{id}/like` → 200 `{ "liked": false, "likeCount": 4 }`. Hız: dakikada 120. Kendi gönderisini beğenebilir (bildirim gitmez).
- `GET /api/posts/{id}/likes?cursor=&size=` (≤30) → `{ "items": [ {"id","displayName","avatarUrl","likedAt"} ], "nextCursor", "total" }` (engelliler gizli).

### Yorum ve yanıt (iç içe)
- `GET /api/posts/{id}/comments?sort=top|new&cursor=&size=` (size ≤20; yalnız KÖK yorumlar; `top` = yanıt sayısı+yenilik; varsayılan `new`) → `{ "items": [CommentView], "nextCursor", "total" }`; her kök yorumda `previewReplies` (en eski 2 yanıt) ve `replyCount`.
- `GET /api/comments/{id}/replies?cursor=&size=` (≤20; eskiden yeniye) → `{ "items": [CommentView], "nextCursor" }`.
- `POST /api/posts/{id}/comments` `{ "text": "…", "parentId": 77? }` → **201 CommentView**. `parentId` verilirse yanıt: ebeveyn aynı gönderide olmalı; derinlik en çok 3: ebeveyn derinliği ≥3 ise yanıt, ebeveynin kardeşi olarak (`parentId` = ebeveynin ebeveyni, `replyToUser` = ebeveynin yazarı) eklenir. Metin ≤1000, küfür filtresi 422, hız: 10 dakikada 30.
- `PATCH /api/comments/{id}` `{ "text" }` → CommentView (yazar). `DELETE /api/comments/{id}` → 204 (yazar, gönderi sahibi ya da ADMIN). Yanıtı olan yorum silinirse `deleted:true` ve gövde `null` olarak kalır (başlık "Bu yorum silindi"), yanıtlar görünür kalır; yanıtı olmayan yorum listeden kalkar. `comment_count` ve `reply_count` buna göre azalır.

**CommentView**
```json
{ "id": 77, "postId": 91, "parentId": null|70, "rootId": 70|77, "depth": 0, "author": {"id","displayName","avatarUrl"},
  "replyToUser": {"id","displayName"}|null, "text": "…"|null, "deleted": false, "replyCount": 3,
  "mine": false, "canEdit": false, "canDelete": false, "createdAt": "…", "editedAt": null, "previewReplies": [CommentView]|null }
```

### Bildirimler (mevcut `NotificationService`; üç dilde şablon; aynı gönderi için beğeniler 10 dk içinde tek bildirimde birleşir)
`POST_LIKE` ("{ad} gönderini beğendi" / çoklu: "{ad} ve {n} kişi gönderini beğendi"), `POST_COMMENT` ("{ad} gönderine yorum yaptı"), `COMMENT_REPLY` ("{ad} yorumuna yanıt verdi"). Yük: `targetType: "POST"`, `targetId: <postId>`, `data.commentId`. Kendi eylemi için bildirim yok; tercih ve sessiz saat kuralları mevcut kalıpla.

### Moderasyon / yönetici
- Kullanıcı şikâyeti: mevcut `POST /api/reports` ile `targetType: "FEED_POST" | "FEED_COMMENT"` (sebepler mevcut: SPAM, HARASSMENT, INAPPROPRIATE, IMPERSONATION, OTHER). Handler: içerik özeti + medya bağlamı; gizleme geri alınabilir.
- ADMIN: `GET /api/admin/posts?cursor&size&q(yazar)&hidden=&deleted=&hasMedia=`, `GET /api/admin/posts/{id}` (yorumlarla), `POST /api/admin/posts/{id}/hide|unhide` `{reason}`, `DELETE /api/admin/posts/{id}`, `GET /api/admin/posts/{id}/comments`, `POST /api/admin/comments/{id}/hide|unhide`, `DELETE /api/admin/comments/{id}`, `GET /api/admin/posts/media/{id}`, `GET /api/admin/posts/stats`. Hepsi denetim kaydı (AuditInterceptor) ve sayfalı.
- Hesap silme/KVKK: kullanıcının gönderileri, yorumları, beğenileri hesap silinince silinir/anonimleştirilir (gönderi silinir, medya temizlenir; başkasının gönderisindeki yorumu "silindi" olur); `DataExporter` bölümü `posts`, `postComments`, `postLikes`.
- Arama (`SearchProvider`): gönderi metni (`type=posts`).

## 3. Mobil (Flutter)
- **Keşfet** sekmesi: üstte iki parçalı segment **Gönderiler | Haberler** (Gönderiler varsayılan; Haberler mevcut keşfet içeriği); Gönderiler = akış (Yeni | Popüler çipleri), imleçle sonsuz kaydırma, pull-to-refresh, iskelet, boş/hata durumları.
- Gönderi kartı: avatar+ad+bölüm+zaman, ⋯ menü (Sil / Düzenle / Şikâyet et), metin ("devamını oku" 6 satır), medya düzeni (1: tam genişlik oran korunur; 2: yan yana; 3–4: ızgara; 5–10: kaydırmalı sayfa göstergesi veya 3 sütun +N), video: poster + oynat rozeti, ekran içinde sessiz otomatik oynatma (yalnız görünür ve Wi-Fi/ayar açıksa; aynı anda tek video), dokununca tam ekran galeri; alt çubuk: beğen (kalp animasyonu, iyimser), yorum sayısı (detaya gider), (paylaş yok).
- "+" Gönderi oluştur (Keşfet üstünde): metin + galeri seçici (mevcut `media_picker_page`, 10 öğe karışık) + ilerleme + yeniden dene + taslak koruma.
- Gönderi detayı: gönderi + yorum listesi (Yeni/Üst sıralama), yorum yazma çubuğu, yanıt (@ad ile), "N yanıtı göster" kademeli yükleme, yorum silme/düzenleme/şikâyet, beğenenler listesi.
- Bildirime dokununca `targetType: POST` → gönderi detayı (yorum için ilgili yoruma kaydır).
- Profil: kullanıcı profil sayfasında "Gönderiler" ızgarası; kendi profilimde "Gönderilerim".

## 4. Test ve doğrulama
Backend: birim + H2 (PostgreSQL'e özel SQL için `scripts/smoke-posts.sh`, ASCII, BASE ile, cygpath/dosya gövde kuralları). Mobil: widget testleri `test/support/fake_app.dart` FakeBackend ile (320/390/430 dp, açık/koyu). Web (yönetici): Vitest.

## Ajan notları
- A: migration+Post hazır — `V310__posts.sql` (4 tablo, `post310_*` indeksler), `post/Post`, `PostRepository`, `PostCounters` (`incrementLikes/incrementComments(long postId,int delta)`, `likeCount(postId)`), `PostDtos.MediaView(id, kind, url, thumbUrl, width, height, durationMs)`, `PostDeletedEvent(postId, mediaIds)`; SPI: `post/spi/PostMediaLookup` (`Map<Long,List<MediaView>> viewsFor(Collection<Long>, Long)`), `PostMediaBinder` (`attach(postId, ownerId, mediaIds)`, `mediaIdsOf(postId)`) — B uygular; `PostLikeLookup` (`Set<Long> likedPostIds(Long, Collection<Long>)`) — C uygular. i18n: `i18n/post*.properties` oluşturuldu ve basename'e eklendi (diğer ajanlar anahtarlarını SONA ekler).

M1: post_models/post_api hazir (lib/features/posts/post_models.dart, post_api.dart). PostApi(session); Post/PostMedia/PostComment/PostPage<T>/LikeResult; postMediaUrl(), postAuthHeaders(session).
- M5: fakePosts hazir - `test/support/fake_app.dart`: `final f = fakePosts(backend, count: 12, pageSize: 10, withMedia: true, empty: false)` (FakePosts: posts, comments, seedComments(postId), emptyFeed, failFeed, uploadError, likedIds); `FakeBackend.handlers` (yonteme duyarli), `FakeResult`; `samplePost/sampleComment/samplePostMedia/samplePostAuthor`, `kFakePng/kFakeMp4`. Imlec p2,p3...

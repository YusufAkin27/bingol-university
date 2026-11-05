# Kampüs Forum: sürüm entegrasyonu (A+B+C+D+E + web) notları

Tarih: 2026-11-05. Dal: `deploy/release2-20261105` (taban `deploy/liked-20261105`; üstüne sırayla arşiv, composer,
anymail, forum-base, forum-a, forum-b, forum-c, forum-d, forum-e, forum-web birleştirildi). Bu dosya dallar arası
**bağlantıları** ve birleşimde alınan kararları anlatır; alan ayrıntıları `forum-a|b|c|d|e|w.md`.

## 1. Migration sırası (prod `out-of-order=false`; canlıda uygulanmış en yüksek V1260)

| Sürüm | Dosya | Kaynak |
|---|---|---|
| V1270 | `native_notification_renderer` | canlı hat |
| V1271 | `meal_menu_pref` | canlı hat |
| V1280 | `message_share` | canlı hat |
| V1290 | `direct_message_info` | canlı hat |
| (arşiv) | migration yok | `deploy/archive` |
| V1310 | `post_mention_tag` | `deploy/composer` |
| V1400 | `forum_topic` (kategori, konu, medya, beğeni, kayıt, takip, takma ad) | A |
| V1410 | `forum_comments` | B |
| V1420 | `forum_poll` | C |
| V1430 | `forum_moderation` (`forum_moderation_action`, `forum_user_mute`) | D |
| V1440 | `forum_notify_prefs` | E |
| V1441 | `forum_share_type_width` (`message.share_type` 8 -> 16) | E |
| V1442 | `forum_search_vec` (V1400/V1410 sonrası) | E |

Sürüm numarası çakışması ve aynı indeks adı YOK (taranmıştır). Gerçek PostgreSQL 16'da önce `target=1260` ile (canlı
durum), sonra tam küme uygulanarak doğrulanmıştır (bkz. sürüm raporu).

## 2. Eklenen bağlantı kodları

| Konu | Çözüm |
|---|---|
| D `ForumSpamGuard` A/B tarafından çağrılmıyordu | `ForumTopicService.create` (`ObjectProvider<ForumSpamGuard>`; gövde `başlık + "\n" + açıklama`) ve B'nin `ForumCommentCreateGuard` kancası için `forum.moderation.ForumCommentSpamGuard`. Kayıt başarısız olursa işaret geri alınır (`forget` / `onCreateFailed`). Aynı `Idempotency-Key` ile yarışan kardes istek (cift dokunma) spam engeline takılırsa en çok ~1 sn beklenir ve ilk isteğin satırı döndürülür (429 değil). |
| E `ForumProfileComments` B tarafı | `forum.comment.ForumProfileCommentsAdapter` -> `ForumCommentService.viewsFor(ids, viewer)`: yalnız CANLI, konusu bakana görünür, yazarı gizli olmayan yorumlar (`/me/comments`, `/users/{id}/comments`, `/me/saved` yorum öğeleri). |
| D yorum moderasyonu -> B durum servisi | D'nin `ForumCommentStatesImpl` köprüsü (reflection) B'nin `ForumCommentStateService` bean'ini bulur; `ForumReleaseIntegrationTest` gerçek bileşenlerle kaldır/geri al + sayaç doğrular. |
| A SPI'ları (`ForumTopicSummaries`, `ForumTopicFollowLookup`, `ForumAuthorResolver`) | Hepsi bean olarak vardır (`ForumReleaseIntegrationTest.crossModuleSpiBeansAreAllWired`). |
| Push `imageUrl` (`/s/f/{id}/img`) kova adı | `ForumShareImages.BUCKET` = A'nın `ForumMediaService.BUCKET` = `forum` (uyumlu). |
| `ForumPermissions` (A) -> `PermissionMatrix` (D) | Anahtarlar aynı (`forum.moderate`); MODERATOR/FULL için `canModerate=true`, EDITOR/VIEWER/kullanıcı için false (test). |
| `MessagingDtos.ShareRequest.type` `@Size(max = 8)` | `FORUM_TOPIC` (11) / `FORUM_COMMENT` (13) reddediliyordu: 16'ya çıkarıldı (E yalnız DB sütununu genişletmişti). |

## 3. Karar: sessize alma anonim içerikte UYGULANMAZ (engel uygulanır)

`forum-d.md` §3'teki risk (sessize alma/engel anonim içerikte de uygulandığından kimlik sınanabilir) kapatıldı:

- **Engel** (iki yönlü, `BlockService`) anonim içerikte de uygulanır (karşılıklı; kimlik açılmaz).
- **Sessize alma** (`forum_user_mute`, tek yönlü) YALNIZ yazar adıyla görünen (anonim olmayan) içeriğe uygulanır: konu akışı/detay,
  yorum listeleri, arama, popüler konular ve bildirim alıcı süzgeci (`ForumNotifier.eligible`, takipçiler).
- Kodlama: görünürlük kümesi tek `Set<Long>`; engelliler POZİTİF kimlik, sessize alınanlar NEGATİF kimlik (`-id`,
  `ForumViewerFilter.mutedKey`). SQL kalıbı `user_id NOT IN :h AND (anonymous = TRUE OR (0 - user_id) NOT IN :h)`;
  Java karşılığı `ForumViewerFilter.hides(hidden, authorId, anonymous)`. Bekçi değer `Long.MIN_VALUE` (eskiden -1;
  negatif kodlamayla kimlik 1 ile çakışırdı).
- Anonim yorum/konu yazarının bildirimi sessize alan alıcıya da gider (aksi halde "bildirim gelmedi" kimlik sınaması olurdu).

## 4. Sözleşme uyumu (mobil/web)

- `GET /api/forum/me/saved` öğesi `{type, savedAt, topic, comment}`; mobil `ForumSavedItem` ile uyumlu.
- `GET /api/forum/mutes` -> `{items:[{userId,displayName,avatarUrl,mutedAt}], nextCursor}`; mobil `fetchForumMutes` hem düz liste hem `{items}` okur.
- Paylaşım kartı `{type:'FORUM_TOPIC'|'FORUM_COMMENT', id, title, subtitle, available, url}`; kategori adı ayrı alan DEĞİL, `subtitle`
  "Yazar · Kategori" içindedir (mobil `categoryName` alanı gelirse kullanır, yoksa "Konu" etiketi). İsteğe bağlı iyileştirme: `ShareCard`'a `categoryName`.
- Web `api/adminForum.ts` normalleştiricileri D'nin şekilleriyle uyumludur (`actor.userId` yerine üst düzey `actorId/actorName` okunur; değişiklik gerekmedi).

## 5. Dağıtım öncesi dikkat

- Forum görseli en çok 10 MB (`POST /api/forum/media`, `multipart/form-data`): mevcut limitler yeterlidir (Spring `MULTIPART_MAX_FILE` 52 MB, canlıda Caddy `CADDY_MAX_BODY` 55 MB, yerel `web/nginx.conf` `client_max_body_size 12m`). Yeni proxy ayarı GEREKMEZ.
- Yeni isteğe bağlı ayarlar: `app.forum.spam-window-seconds` (varsayılan 600), `app.forum.notify-async|notify-threads|notify-queue` (true/2/2000).
  Zorunlu yeni ortam değişkeni YOK.
- Prod `out-of-order=false`: V1270..V1442 canlıdaki V1260'tan sonra gelir; araya sonradan numara eklemeyin.
- `PostgreSQL'e özel` yollar H2'de koşmaz: arama (`search_vec`), `ReportService.markHidden` otomatik gizleme eşiği; duman: `scripts/smoke-forum.sh`, `scripts/smoke-forum-search.sh`.
- E-posta alan adı kısıtı kalktığı için kayıt/doğrulama uçlarında kötüye kullanım izlenmeli (hız sınırı ve e-posta kodu aynen sürer).

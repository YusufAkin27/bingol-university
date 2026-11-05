# Kampüs Forum: E alanı (bildirim, arama, profil, paylaşım, KVKK) değişiklik notları

Sözleşme: [../FORUM_API.md](../FORUM_API.md) (E bölümleri). Paketler: `forum.notify`, `forum.search`, `forum.profile`,
`forum.share`; çekirdek `notification` ve `share` modüllerine küçük eklemeler. Migration: V1440–V1442. i18n: `i18n/forumn*.properties`.
İstemci için BAĞLAYICI yanıt şekilleri bu dosyanın sonundaki "İstemci sözleşmesi" bölümündedir.

## 1. Bildirim

### Tür modeli (sözleşmeden sapma/ayrıntı)
Sözleşmedeki altı tür `forumKind` adıyla gider. Çekirdek bildirim türü olarak **tek yeni ana tür** eklendi:
`NotificationType.FORUM` (tercih bayrağı `communities`; push kanalı `social`; TTL 1 gün; iOS thread `forum-<topicId>`).
Beş tür alt tür olarak da vardır (`NotificationSubtype.FORUM_TOPIC_COMMENT`, `FORUM_COMMENT_REPLY`, `FORUM_COMMENT_LIKE`,
`FORUM_TOPIC_LIKE`, `FORUM_FOLLOWED_TOPIC_COMMENT`; genel `GET/PUT /api/notifications/preferences` `subtypes` haritasında da görünür).
**`FORUM_MODERATION` alt tür DEĞİLDİR** (`NotificationTemplatesTest`: SYSTEM alt tür alamaz): moderasyon `type=SYSTEM`,
alt tür yok, `moderation=1` (stil `MODERATION`), tercihle ve sessiz saatle susturulamaz.
Neden yeni ana tür: `notification.type` VARCHAR(24) ve `FORUM_FOLLOWED_TOPIC_COMMENT` 28 karakter; ayrıca mevcut `POST_*` kalıbı.

| `forumKind` | `type` | `subtype` | `target`/`targetType` | alıcı |
|---|---|---|---|---|
| FORUM_TOPIC_COMMENT | FORUM | FORUM_TOPIC_COMMENT | FORUM_COMMENT (yeni yorum) | konu sahibi (ust yorumun sahibi de oyse yalniz YANIT gider) |
| FORUM_COMMENT_REPLY | FORUM | FORUM_COMMENT_REPLY | FORUM_COMMENT (yeni yanıt) | üst yorumun sahibi |
| FORUM_COMMENT_LIKE | FORUM | FORUM_COMMENT_LIKE | FORUM_COMMENT | yorum sahibi |
| FORUM_TOPIC_LIKE | FORUM | FORUM_TOPIC_LIKE | FORUM_TOPIC | konu sahibi |
| FORUM_FOLLOWED_TOPIC_COMMENT | FORUM | FORUM_FOLLOWED_TOPIC_COMMENT | FORUM_COMMENT | konuyu takip edip bildirimi açık olanlar (en çok 2000) |
| FORUM_MODERATION | SYSTEM | yok | FORUM_TOPIC veya FORUM_COMMENT | içerik sahibi (`action`: PIN UNPIN LOCK UNLOCK REMOVE RESTORE) |

Yük anahtarları (`data`): `target`/`value` (PushPayload `targetType`/`targetId` üretir), `topicId`, `commentId` (yorum hedeflerinde),
`forumKind`, `senderName`, `action`+`moderation=1` (moderasyon). Yalnız-push (kalıcı `data`ya yazılmaz): `sourceName` = kategori adı
(alıcının dilinde), `imageUrl` = konunun ilk görseli varsa `<PUBLIC_WEB_URL>/s/f/<konuId>/img` (herkese açık küçük resim; yetkili medya
ucu push için kullanılamaz). `style`: `SOCIAL` (moderasyonda `MODERATION`). **Kullanıcı kimliği (`userId`/`actorId`) ve avatar
HİÇBİR zaman yüke girmez.** `senderName` anonimse "Anonim #N" (alıcı dilinde); anonim konunun yazarı o konuya adıyla yorum/beğeni
yapsa bile takma adıyla gösterilir (konu yazarlığı ifşa olmasın). Takma ad satırı yoksa kimliksiz "Anonim".

### Kurallar (`ForumNotifier`)
- Kendine bildirim yok; engel (iki yönlü) ve forum sessize alma (alıcı gönderen kişiyi sessize almışsa) uygulanır.
- Alıcı tercihi `forum_notification_pref` (satır yoksa hepsi açık; `all=false` moderasyon dışındakileri susturur) + konu bazlı kapatma
  (`forum_topic_follow.notify=false`) + pasif/askıda/silinmiş hesap atlanır (`RecipientGuard.canReceive`).
- Tekrar yok: kalıcı defter `forum_notify_seen` (tür, hedef, eden, alıcı) PK; beğeni al-ver-al ya da tekrar gelen olay ikinci bildirim üretmez.
- Yoğunlaştırma: aynı hedef için 10 dakikalık sabit pencerede okunmamış bildirim tek satırda birleşir (`collapseKey`
  `fotc:<konu>:<pencere>`, `focr:<ust yorum>:...`, `focl:<yorum>:...`, `fotl:<konu>:...`, `foft:<konu>:...`; metin "A ve N kişi ...");
  ilk bildirimden sonra o pencerede push gitmez (`NotificationService`: `POST_LIKE` kuralı `FORUM` için de geçerli).
- Olay kaynağı: A'nın `forum.notify.spi.ForumEventPublisher` arayüzünü `ForumEventPublisherImpl` uygular; işlem COMMIT'inden sonra
  ayrı sınırlı yürütücüde çalışır (`app.forum.notify-async` varsayılan true; `notify-threads` 2, `notify-queue` 2000), hata ana işlemi bozmaz.

### Tercih uçları
`GET|PUT /api/forum/notification-prefs` gövde/yanıt `{all, topicComments, commentReplies, likes, followedTopics}` (PUT'ta eksik alan değişmez).
Moderasyon kapatılamaz (alan yok; tabloda `moderation` hep true). Hız sınırı: GET 120/dk, PUT 60/dk.

## 2. Arama
`GET /api/forum/search`, `GET /api/forum/search/popular` (giriş gerekli; 60/dk). `forum_topic.search_vec` (başlık A, gövde B ağırlıklı)
ve `forum_comment.search_vec` saklı tsvector (turkish) + GIN (`V1442`), başlıkta trigram GIN (kısmi kelime). Sorgu `plainto_tsquery('turkish', q)`
+ başlık/kategori adı `ILIKE` (kaçışlı); yorum eşleşmesi YALNIZ anonim olmayan ACTIVE yorumlar; silinmiş/kaldırılmış konu-yorum, pasif yazar,
engelli/sessize alınan yazar sonuçta yok. Her konu bir kez döner (öncelik TITLE > BODY > COMMENT > CATEGORY). Sayfalama OFFSET imleci
(opak) ve 300 satır tavanlı; `sort` beyaz liste (RELEVANCE|NEWEST|POPULAR). Kartlar A'nın `ForumTopicSummaries` SPI'sından (görünmeyen sessizce düşer).
**Genel `SearchProvider`/`GET /api/search` bilinçli olarak EKLENMEDİ**: yanıt `type` anahtarlı gruplu ve mobil `SearchType` enum'u
bilinmeyen türde kırılabilir; kırıcı olmayan bir ekleme için mobil tarafla `FORUM` türü önce kabul edilmelidir.
PostgreSQL'e özel: H2 testi yok, `scripts/smoke-forum-search.sh`.

## 3. Profil / etkinlik
`/api/forum/me/topics|comments|saved|following` ve `/api/forum/users/{id}/topics|comments|summary`. Kendi: anonim dahil. Başkası: yalnız anonim
olmayan; anonim konunun yazarının kendi konusuna adıyla yazdığı yorum listelenmez/sayılmaz. Kapılar: kullanıcı yok/pasif, engel, sessize alma =
BOŞ liste (`post` modülündeki `byAuthor` ile aynı; var/yok ayrımı yok); gizli hesap ve takipçi değil = boş liste + `locked:true`
(`PrivateAccountGate`). Yorum satırları B'nin `CommentView`'ini `ForumProfileComments` adaptöründen alır, düz haritaya çevrilip `topicTitle` eklenir (B yoksa yorum listeleri boş).
Mobil A'nın `ForumSavedItem`/`ForumComment` ayrıştırıcılarına (`type`, düz yorum) uyumludur.

## 4. Paylaşım
`ShareType.FORUM_TOPIC("f")`, `FORUM_COMMENT("fc")`: `https://bukampus.com.tr/s/f/{id}`, `/s/fc/{id}` (+ `/img`). Web nginx/Caddy `/s/*` kuralı genel;
AASA/assetlinks yolu `/s/*` olduğu için değişmedi. OG sayfası: başlık = konu başlığı / yorum metni, açıklama = gövdenin ilk 140 karakteri,
alt başlık "Yazar · Kategori" (anonimse yazar "Anonim"), görsel = ilk görselin küçük resmi (`/s/f/{id}/img`). Gizli/silinmiş/kaldırılmış/
engelli içerik "içerik kullanılamıyor" (nötr sayfa / `available=false` kart). Herkese açık sayfada gizli hesabın ADIYLA görünen içeriği önizlenmez.
`message.share_type` VARCHAR(8) → VARCHAR(16) (`V1441`; `FORUM_TOPIC` 11 karakter). Sohbet listesi önizlemesi: `share.preview.FORUM_TOPIC|FORUM_COMMENT`.
Kod: `ShareService` yalnız `ForumShareResolver` arayüzünü bilir (uygulama `forum.share.JdbcForumShareResolver`).

## 5. KVKK
- `DataExporter` bölümü `forum` (`ForumDataExporter`): konular, yorumlar (anonimler dahil, kendi verisi), konu/yorum beğenileri, kayıtlar, takipler, anket
  oyları, sessize alınanlar, anonim takma ad numaraları, forum bildirim tercihleri.
- `AccountDataPurger.DELETES`: `forum_notification_pref`, `forum_notify_seen` (eden + alıcı). Diğer forum tabloları A/B/C/D'nin kayıtlarıdır;
  `AccountDataPurgerCoverageTest` (migration taraması) bütün forum tablolarının karar listesinde olmasını zorunlu kılar.

## Testler
`ForumNotifierTest`, `ForumNotificationPrefServiceTest`, `ForumNotifyI18nTest`, `ForumPushPayloadTest`, `ForumSearchServiceTest`, `ForumShareTypeTest`
(+ mevcut `NotificationTemplatesTest`, `NotifDesignContractTest`, `I18nMessagesIntegrityTest`, `AccountDataPurgerCoverageTest`, `ExtraExportersTest`,
`RateLimitCoverageTest`, `QueryRulesTest`, `RbacCoverageTest`).

## İstemci sözleşmesi (BAĞLAYICI sekiller; ayrıntılı kopya `C:\bu_dsg\_tmp\FORUM_E_SHAPES.md`)
Sayfalama: `?cursor=&size=` (size ≤ 30, varsayılan 15), yanıt `{items, nextCursor}`.
- `GET /api/forum/search` → `items[]` = TopicSummary alanları DÜZ + `matchedIn` (`TITLE|BODY|COMMENT|CATEGORY`) + `snippet` (düz metin ≤160 | null). q < 2 karakter 400 `FORUM_SEARCH_QUERY_TOO_SHORT`.
- `GET /api/forum/search/popular` → `TopicSummary[]` (düz dizi ≤10, son 7 gün).
- `GET /api/forum/me/topics`, `/me/following` → `{items: TopicSummary[], nextCursor}`.
- `GET /api/forum/me/comments`, `/users/{id}/comments` → `{items: CommentView[] (alanlar DÜZ) + her birine topicTitle, nextCursor}`.
- `GET /api/forum/me/saved` → `{items: [{type: "TOPIC"|"COMMENT", savedAt, topic: TopicSummary, comment: CommentView-düz+topicTitle|null}], nextCursor}` (COMMENT'te `topic` yorumun konusunun kartıdır).
- `GET /api/forum/users/{id}/topics` → `{items: TopicSummary[], nextCursor, locked?: true}`; `/users/{id}/summary` → `{topicCount, commentCount, locked?: true}`.
- `GET|PUT /api/forum/notification-prefs` → `{all, topicComments, commentReplies, likes, followedTopics}`.

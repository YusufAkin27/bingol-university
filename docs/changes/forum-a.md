# Kampus Forum, A alani: kategori, konu, medya, begeni/kaydet/takip, anonim takma ad, akis

Sozlesme: `docs/FORUM_API.md`. Paketler: `edu.bingol.backend.forum.topic|category|media` + SPI paketleri
(`forum.topic.spi`, `forum.notify.spi`, `forum.poll.spi`). Migration: `V1400__forum_topic.sql`.
i18n: `i18n/forum*.properties`.

## Uclar

| Uc | Not |
|---|---|
| `GET /api/forum/categories` | aktif kategoriler, `name` istek diline gore, `topicCount` (silinmis/kaldirilmis haric), onbellek yok |
| `GET /api/forum/topics?sort=&categoryId=&cursor=&size=` | `sort` = FOR_YOU (varsayilan), NEWEST, POPULAR, MOST_COMMENTED, FOLLOWING; `size` 1..30 (varsayilan 15) |
| `POST /api/forum/topics` | `Idempotency-Key` basligi, 5/saat; konu + gorseller + anket TEK transaction |
| `GET/PATCH/DELETE /api/forum/topics/{id}` | PATCH/DELETE yalniz sahip; kilitli konuda PATCH 409 `FORUM_TOPIC_LOCKED` |
| `PUT/DELETE .../like`, `.../bookmark`, `.../follow` | idempotent; yanit `{liked,likeCount}`, `{saved}`, `{following}` |
| `PUT .../notifications` `{enabled}` | takip etmeyen (konu sahibi dahil) icin de calisir |
| `POST /api/forum/media`, `GET /api/forum/media/{id}[?thumb=true]`, `DELETE /api/forum/media/{id}` | 20/saat, jpeg/png/webp en cok 10 MB, yeniden kodlama + EXIF temizligi (`PrivateMediaStore`, kova `forum`) |

Hata kodlari (hepsi 3 dilde, `i18n/forum*.properties`): `FORUM_TOPIC_NOT_FOUND`, `FORUM_CATEGORY_NOT_FOUND`,
`FORUM_CATEGORY_ARCHIVED`, `FORUM_CATEGORY_SLUG_TAKEN`, `FORUM_CATEGORY_INVALID`, `FORUM_TITLE_REQUIRED`,
`FORUM_TITLE_TOO_LONG`, `FORUM_BODY_REQUIRED`, `FORUM_BODY_TOO_LONG`, `FORUM_TOO_MANY_IMAGES`, `FORUM_MEDIA_INVALID`,
`FORUM_MEDIA_NOT_FOUND`, `FORUM_MEDIA_PENDING_LIMIT`, `FORUM_NOT_OWNER`, `FORUM_TOPIC_LOCKED`, `FORUM_POLL_UNAVAILABLE`,
`FORUM_CURSOR_INVALID`, `FORUM_SORT_INVALID`. **`FORUM_NOT_OWNER`, `FORUM_TOPIC_LOCKED`, `FORUM_TOPIC_NOT_FOUND`
ve `FORUM_CURSOR_INVALID` A'da tanimlidir; B/C/D/E ayni anahtari kendi dosyasinda TEKRAR TANIMLAMAZ**
(`I18nMessagesIntegrityTest.noDuplicateKeysAcrossFiles`). Ayrica `forum.anon.name` ("Anonim #{0}") ve
`forum.author.deleted`. Uygunsuz ifade: `ContentGuard` (`CONTENT_PROFANITY` 422, alan `title`/`body`).

## Yayinlanan SPI'lar (hepsi `forum.*.spi`)

- `ForumTopicLookup` (A uygular): `visibleTopic(topicId, viewerId)`, `topic(topicId)`; `TopicRef{id, authorId, anonymous,
  locked, categoryId, status}`. Gorunmez = silinmis, `REMOVED`, yazari ACTIVE olmayan (kendisi hariç), bakanla yazar arasinda
  engel (iki yonlu) ya da bakanin sessize almasi. `topic()` REMOVED'i de doner (moderasyon/bildirim icin).
- `ForumTopicStateService` (A uygular): `pin/unpin/lock/unlock/remove(topicId, reason)/restore`, `TopicRef` doner; yetki ve
  denetim kaydi cagirandadir (D).
- `ForumAuthorResolver` (A uygular): yazar gorunumunun TEK uretim yeri. `resolve(viewerId, List<Key(topicId,userId,anonymous)>)`.
  B yorum yazarini, E arama/profil yazarini buradan alir; eksik takma ad tembel tahsis edilir.
- `ForumTopicSummaries` (A uygular): `summaries(topicIds, viewerId)` -> `TopicSummary` listesi (sira korunur, gorunmeyenler atlanir).
- `ForumTopicFollowLookup` (A uygular): `notifyFollowers(topicId, limit)`, `notificationsEnabled(topicId, userId)` (E bildirim hedefi).
- `ForumBookmarkService` (A, concrete): `save/unsave(userId, "TOPIC"|"COMMENT", targetId)`, `savedAmong`. Konu sayaci yalniz TOPIC.
- `ForumMuteLookup` (D uygular): `mutedBy(viewerId)`. Bean yoksa sessize alma uygulanmaz.
- `ForumEventPublisher` (E uygular): `topicLiked(topicId, actorId)`, `commentCreated(commentId, actorId)`,
  `commentLiked(commentId, actorId)`, `moderationAction(TargetType, targetId, action, reason)`. A yalniz `topicLiked` cagirir
  (yeni begeni ve begenen != yazar). Bean yoksa atlanir.
- `ForumPollService` (C uygular): `createForTopic(topicId, CreatePollRequest)`, `pollFor`, `topicIdsWithPoll`. Anketli istek ve
  bean yoksa 400 `FORUM_POLL_UNAVAILABLE`; anket hatasi konuyu da geri alir.

`ForumPermissions` (string anahtarlar `forum.read|moderate|categories`) `PermissionMatrix`'e DOKUNMAZ; matriste `forum.moderate`
yoksa `canModerate` hep false (kapali basarisiz). D matrise baglayinca kendiliginden calisir.

## Akis siralamalari ve imlec

Imlec opak (base64url). Hepsi KARARLI: `(anahtar, id)` cifti; tekrar/atlama yok (sayaclar sayfalar arasinda degismedikce).
Sabitlenmisler (en cok 5) yalniz NEWEST ve FOR_YOU'nun ILK sayfasinda basta gelir, sayfa boyutundan sayilir ve akistan
cikarilir. Engelli/sessize alinmis yazarlar (anonim konular dahil) tum listelerde gizlidir.

- **NEWEST**: `id` azalan.
- **MOST_COMMENTED**: `(comment_count, id)` azalan.
- **POPULAR**: `puan = like_count + 2 * comment_count` (son 30 gunde acilanlar), `(puan, id)` azalan (tam sayi: kayan nokta yok).
- **FOLLOWING**: takip ettigim konular (`forum_topic_follow.follow = true`) + takip ettigim kullanicilarin ANONIM OLMAYAN konulari.
- **FOR_YOU** (acik formul, rastgelelik yok):
  `base = 1 + ln(1 + begeni) + 1.5 * ln(1 + yorum) + yazarBonusu + kategoriBonusu`,
  `skor = base * 0.5^(yasSaat / 36)` (yas = son etkinlikten bu yana, yari omur 36 saat).
  Yazar bonusu +1.0: takip ettigim, anonim OLMAYAN yazar (anonim konuda uygulanmaz: siralama kimlik sizdirmasin).
  Kategori bonusu +0.5: son 90 gunde konu actigim/begendigim/takip ettigim kategori.
  Ustel sonum siralamayi degistirmeden `anahtar = ln(base) + son_etkinlik_saat * ln2 / 36` ile karsilastirilir; anahtar "simdi"ye
  bagli olmadigindan imlec kararli kalir (imlec = anahtarin bit deseni + id). Aday penceresi: son 60 gunde etkinligi olan
  en cok 600 konu (Java'da puanlanir; PostgreSQL/H2 farki ve sorgu sinirlari icin).

## Anonim yazar

DB'de gercek `user_id`; API baska kullaniciya `userId/avatarUrl/department` vermez, `displayName` = "Anonim #N" (istek dili).
`#N`: `forum_anon_alias(topic_id, user_id, n)`, konu icinde 1'den, `INSERT .. SELECT MAX(n)+1` + `UNIQUE(topic_id,n)`; yarisan
tahsiste kaybeden kendi islemi (REQUIRES_NEW) icinde yeniden dener (yaris testli). Konu olusturmada tahsis ayni transaction'dadir.
Yazar kendi icerigini `mine:true` gorur. Yorumda anonimlik ayri secimdir (`ForumAuthorResolver.Key.anonymous`).

## Veri notlari

- `forum_topic_follow(follow, notify)`: `follow=true` takipci; `follow=false + notify=false` takip etmeyenin (konu sahibi vb.)
  "bildirimleri kapat" tercihi. E bildirim hedefini `ForumTopicFollowLookup` ile secer, tabloya dogrudan bakmaz.
- `forum_topic.idem_key` + `UNIQUE(user_id, idem_key)`: cift gonderim ayni konuyu doner (es zamanli yaris testli).
- Sayaclar (`like_count`, `bookmark_count`) yalniz atomik `UPDATE ... SET x = x + :d` ile degisir; satir ve sayac ayni transaction'da,
  cift PUT/DELETE idempotent. `comment_count` ve `last_activity_at` guncellemesi B'nindir (atomik UPDATE); A'nin FOR_YOU'su
  `last_activity_at`i okur.
- Gorsel temizligi: baglanmamis yukleme 24 sa sonra, silinmis konunun gorseli 30 gun sonra (`ForumMediaJanitor`, `SchedulerLock`);
  `app.forum.media.*` ayarlari.
- KVKK: `ForumTopicAccountPurger` (`AccountDataPurger.purge` cagirir; `HANDLED_ELSEWHERE` kayitlari eklendi): konular yumusak silinir
  ve basligi/govdesi `[silindi]` yapilir, gorseller + baytlar, begeniler (sayac duser), kayitlar, takipler, takma adlar silinir.
- Metin temizligi (`ForumText`): HTML etiketleri, kontrol/bidi/sifir genislik karakterleri atilir, baslik tek satir.

## Sapmalar / acik noktalar

- Tekrarlayan ayni metin engeli (`FORUM_DUPLICATE_CONTENT`, 429) sozlesmede D'nin guvenlik maddesidir; A uygulamaz
  (hiz siniri + Idempotency-Key var). D bir `ForumSpamGuard` yayinlarsa konu servisine tek satirla baglanir.
- `PermissionMatrix` A tarafindan degistirilmedi (bkz. yukari).

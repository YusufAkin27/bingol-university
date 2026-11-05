# Kampüs Forum — B alanı: Yorum sistemi (V1410)

Paket `edu.bingol.backend.forum.comment`, migration `V1410__forum_comments.sql`, i18n `forumc*.properties`. Sözleşme: `docs/FORUM_API.md` §1-B, §2-B (BAĞLAYICI). Bu belge sözleşmeyi **tamamlayan** ayrıntıları ve **sapmaları** içerir.

## Uçlar (`/api/forum`)

| Uç | Not |
|---|---|
| `GET /topics/{id}/comments?sort=BEST\|NEWEST\|OLDEST&cursor=&size=` | Üst düzey yorumlar + her birinde `replyPreview` (ilk ≤2 yanıt, eskiden yeniye) + `replyCount`. Varsayılan `BEST`, `size` 15 (en çok 30). |
| `GET /comments/{id}/replies?cursor=&size=` | Doğrudan çocuklar, eskiden yeniye. **Her yanıtta da** kendi `replyPreview`'u gelir (istemci 3 seviyeyi ek istek atmadan çizebilir). |
| `GET /comments/{id}` | `CommentView` + `path` (kökten doğrudan ebeveyne ata kimlikleri; üst düzeyde `[]`). Yer tutucu da dönebilir (`deleted:true`); listelenmeyen mezar taşı 404. |
| `POST /topics/{id}/comments` | `{body, parentCommentId?, anonymous?}` → 201. `Idempotency-Key` başlığı (8–100 karakter `[A-Za-z0-9._:-]`). 20/dk. |
| `PATCH /comments/{id}` | `{body}`; yalnız sahip. 60/dk (yazma). |
| `DELETE /comments/{id}` | 204. Sahibi; zaten silinmişse yine 204 (çift dokunma). |
| `PUT\|DELETE /comments/{id}/like` | `{liked, likeCount}`, 120/dk. |
| `PUT\|DELETE /comments/{id}/bookmark` | `{saved}` (A'nın `ForumBookmarkService`'i). |

## Hata kodları (hepsi `forumc*.properties`'te üç dilde)

`FORUM_COMMENT_NOT_FOUND` 404, `FORUM_NOT_OWNER` 403, `FORUM_TOPIC_LOCKED` 409, `FORUM_COMMENT_EMPTY` 400, `FORUM_COMMENT_TOO_LONG` 422, `FORUM_COMMENT_PARENT_UNAVAILABLE` 409 (silinmiş/kaldırılmış yoruma yanıt), `FORUM_COMMENT_DELETED` 409 (sahibi silmiş yorumu moderatör geri getiremez), `FORUM_COMMENT_CURSOR_INVALID` 400. Görünmez konu: `FORUM_TOPIC_NOT_FOUND` (A'nın anahtarı). Küfür filtresi: `ContentGuard` (422 `CONTENT_PROFANITY`, alan `body`).

## Sayaç anlamları (tümü atomik `UPDATE`, okuma-değiştir-yaz yok)

- `forum_topic.comment_count` = konudaki **canlı** yorum sayısı (yanıtlar dahil; yer tutucular ve kaldırılanlar sayılmaz). Yeni yorumda `last_activity_at` ilerler; silmede ilerlemez.
- `forum_comment.reply_count` = doğrudan **listelenen** çocuk sayısı. Listelenen = canlı, ya da altında listelenen yanıtı olan yer tutucu.
- `forum_comment.like_count` = beğeni sayısı; PK `(comment_id,user_id)` ikinci beğeniyi engeller, çift/eşzamanlı PUT tek artış.

Mezar taşı (`deleted_at` dolu ya da `status=REMOVED`): altında listelenen yanıt varsa `deleted:true` yer tutucu (author/body null, sayaçlar 0), yoksa listeden çıkar; üst yorum da yer tutucuysa ve boşaldıysa zincir yukarı doğru çıkar. Geri alma (restore) tersini yapar. Kilit sırası: yorum satırı (alttan uca) → en son `forum_topic` (kilitlenme olmaz). Yanıt oluşturma ebeveyn satırını `FOR UPDATE` kilitler; eşzamanlı silme ile sıralanır.

## BEST sıralaması

`puan = floor(1_000_000 × (2×beğeni + yanıt + 1) / (yaş_saat + 2)^1.5)` (tam sayı; imleç eşitliği kayan noktaya düşmesin diye). Yaş, imlecin taşıdığı `asOf` anına göre hesaplanır (ilk sayfada sunucu saati): sayfalar arası sıra sabittir, **tekrar/atlama yok** (sayaçlar sayfalar arasında değişirse bir yorum yer değiştirebilir; bu kaçınılmaz). Eşit puanda `id` azalan. İmleçler: `N|id`, `O|id`, `B|asOf|puan|id`, `R|id` (base64url, opak).

## Anonimlik

Anonim yorumda `author = {userId:null, displayName:"Anonim #N" (tr) / "Anonymous #N" (en) / "مجهول #N" (ar), avatarUrl:null, department:null, anonymous:true}`; `#N` A'nın `forum_anon_alias`'ından (konu başına kararlı; yazma sırasında `ForumAnonAliasService` ile oluşturulur, okuma toplu SQL). Yorumda anonimlik **ayrı** seçimdir. `mine:true` yalnız yazarın kendisine.
`topicAuthor`: konu sahibinin yorumunda `true`; **anonim konuda** yalnız yorum da anonimse `true` (kimlikli yorumda "Yazar" etiketi anonim konuyu açığa çıkarırdı). Engel/sessize alma süzgeci yazarı kimlik sızdırmadan sunucuda uygular (anonim yorum dahil).

## Sözleşmeye eklenenler / sapmalar

1. **Yardımcı SPI'lar** (`forum.comment.spi`): `ForumCommentStateService.remove(commentId, reason)` / `restore(commentId)` (D çağırır; idempotent; yetki çağıranda), `ForumCommentLookup.find(commentId)` (D/E: kayıt + GERÇEK yazar/ebeveyn yazarı, yalnız sunucu içi), `ForumCommentCreateGuard.beforeCreate(userId, topicId, body)` (D'nin `FORUM_DUPLICATE_CONTENT` spam sınırı gibi kontroller için istege bağlı kanca; **B kendisi tekrar-metin sınırı uygulamaz**, bu D'nin alanıdır).
2. `Idempotency-Key`: mevcut `IdempotencyFilter` yalnız `/api/admin/**` içindir; kullanıcı ucu için **DB düzeyinde** çözülür (`forum_comment.idempotency_key` + benzersiz `(user_id, key)`): aynı anahtar aynı yorumu döner (başka konuda kullanılırsa 422 `IDEMPOTENCY_KEY_REUSED`). Redis'e bağımlı değil.
3. `replyPreview` yalnız liste uçlarında (ve `/replies` öğelerinde); `path` yalnız `GET /comments/{id}`. İkisi de `null` iken JSON'a yazılmaz.
4. `author`/`body`/`editedAt`/`parentCommentId` null iken de JSON'da `null` olarak bulunur.
5. Moderatör kaldırması gövdeyi DB'de **saklar** (denetim için), API'de asla göstermez; sahibi silince DB gövdesi `[silindi]` olur.
6. Metin temizliği: kontrol karakterleri, yön-ters (bidi) ve sıfır genişlik karakterleri atılır, `<tag>`/`<!-- -->` parçaları silinir (düz metin `a < b` bozulmaz), baş/son boşluk kırpılır, 3+ satır sonu 2'ye iner. Üst sınır 4000 **kod noktası**.
7. Hesap silme: `ForumCommentAccountPurger` (AccountDataPurger'a kayıtlı): beğeniler silinir (sayaç düşer), yorumlar mezar taşı olur (`[silindi]`), konu/ebeveyn sayaçları düzelir. Kaydedilenler (`forum_bookmark`) **A'nın** temizliğidir (A'nın purger'ı `forum_bookmark WHERE user_id = ?` silmelidir).
8. Engel/sessize alma yalnız **listelerde** yazar bazında süzer; `replyCount` evrenseldir (engelli yazarın yanıtı sayılır ama gösterilmez).

## Bilinen sınırlamalar

- PostgreSQL'e özel parçalar (kısmi indeksler, `BEST` puanındaki `EXTRACT(EPOCH ...)`/`POWER`, `ROW_NUMBER`) H2 testlerinde de çalışır; ancak gerçek PG üzerinde çalıştırma bu görevde yapılmadı (bkz. nihai rapor).
- Askıya alınmış (SUSPENDED) kullanıcının yorumları kendiliğinden gizlenmez; moderasyon `remove` ile yapılır.

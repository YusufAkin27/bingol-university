# Kampüs Forum — D alanı: moderasyon, güvenlik, yönetim uçları

Sözleşme: `docs/FORUM_API.md` (§1-D, §2-D). Paket: `edu.bingol.backend.forum.moderation`, `edu.bingol.backend.forum.admin`.
Migration: **V1430** (`forum_moderation_action`, `forum_user_mute`; indeks öneki `fd14_`). Çeviri: `i18n/forummod*.properties` (tr/en/ar).

## 1. Şikâyet (mevcut `moderation` modülü)

- `ReportTargetType` + `FORUM_TOPIC`, `FORUM_COMMENT` (en çok 16 karakter; `report.target_type` sütunu değişmedi).
- `ReportReason` + `PERSONAL_INFO` (`EnumType.STRING`; `report.reason` VARCHAR(32), CHECK yok: migration gerekmedi). Mobil/web rapor ekranı `POST /api/reports` ile `reason=PERSONAL_INFO` gönderebilir; karar nedeni şablonu olarak mevcut `PRIVACY` kullanılır.
- Handler'lar `ForumReportHandlers.TopicHandler/CommentHandler` (SPI `ReportTargetHandler`): `exists(viewer, id)` = aktif konu/yorum, yazar aktif hesap, yazar şikâyet edeni engellememiş (aksi 404 `TARGET_NOT_FOUND`); **anonim içerik de şikâyet edilir** (`ownerId` yalnız sunucu içi karar için). `reversible()=true`: `hide` = içeriği `REMOVED` yapar (A/B servisleri), `unhide` geri açar. Yönetici kuyruğunda otomatik gizleme eşiği (mevcut kural) forum için de geçerlidir.
- Aynı kullanıcı aynı hedefi tekrar şikâyet edemez (mevcut kural: `409 ALREADY_REPORTED`); kendi içeriği `400 CANNOT_REPORT_SELF`.
- Rapor kuyruğunda yazar kimliği ANONİM içerikte gösterilmez (`AdminReportContextService` ve `/api/admin/forum/reports` anonim içeriğin sahibini çözmez).
- Rapor kararı (`POST /api/admin/reports/{id}/resolve`): `HIDE` → içerik kaldırılır, `DISMISS` → otomatik gizlenmişse geri açılır. Doğrudan moderatör kaldırması bekleyen şikâyetleri `HIDE` ile kapatır (strike/raporlayan bildirimi üretmez).

## 2. Moderatör eylemleri

Yetki: `ROLE_ADMIN` + izin `forum.moderate` (MODERATOR, FULL). Sahiplik bu uçlarda yetki sayılmaz.

| Uç | Gövde | Yanıt |
|---|---|---|
| `POST /api/forum/topics/{id}/moderate` | `{action: PIN\|UNPIN\|LOCK\|UNLOCK\|REMOVE\|RESTORE, reason?}` | `{targetType:"TOPIC",targetId,action,status,pinned,locked}` |
| `POST /api/forum/comments/{id}/moderate` | `{action: REMOVE\|RESTORE, reason}` | `{targetType:"COMMENT",targetId,action,status,pinned:false,locked:false}` |
| `POST /api/admin/forum/topics/{id}/moderate` | aynı | aynı (yönetim paneli; `AdminPermissionInterceptor` + `AuditInterceptor`) |
| `POST /api/admin/forum/comments/{id}/moderate` | aynı | aynı |

- `REMOVE`/`RESTORE` için `reason` ZORUNLU (`400 FORUM_MOD_REASON_REQUIRED`), en çok 300 karakter (`400 FORUM_MOD_REASON_TOO_LONG`; A `removed_reason` VARCHAR(300)). Gerekçe `ForumTextSanitizer.singleLine` ile temizlenir.
- Geçiş kuralları (sunucuda, `409 FORUM_MOD_INVALID_STATE`): PIN yalnız aktif ve sabit olmayan; UNPIN yalnız sabit; LOCK yalnız aktif ve kilitli olmayan; UNLOCK yalnız kilitli; REMOVE yalnız aktif; RESTORE yalnız kaldırılmış. Sahibi silmiş konu/yorum 404 `FORUM_MOD_TARGET_NOT_FOUND`. Yorumda PIN/LOCK vb. `400 FORUM_MOD_ACTION_INVALID`.
- Yetkisiz: `403 FORUM_MOD_FORBIDDEN` (kullanıcı API'si), `403 ADMIN_PERMISSION_DENIED` (`/api/admin`).
- Her eylem: `forum_moderation_action` satırı (`source` MODERATOR; rapor akışından `REPORT` / eşik `REPORT_AUTO`) + `admin_audit` (kullanıcı API'sinde `SystemAdminAudit`, yönetim API'sinde `AuditInterceptor` + `AuditContext`) + içerik sahibine `ForumEventPublisher.moderationAction` (E; sağlayıcı yoksa atlanır). Anonim içerikte moderatör işlem alır, yazarı görmez; yanıtlarda `userId` yoktur.
- Durum değişikliği A `ForumTopicStateService` / B yorum durum servisi üzerinden (`ForumStatePort` → `ForumStateAdapter`).

## 3. Sessize alma ve yazarı engelleme

- `PUT|DELETE /api/forum/mutes/{userId}` → `{muted:true|false}` (idempotent; kendini `400 FORUM_CANNOT_MUTE_SELF`; olmayan/pasif `404 FORUM_MUTE_USER_NOT_FOUND`; en çok 500 kişi `409 FORUM_MUTE_LIMIT`). `GET /api/forum/mutes?cursor=&size=` → `{items:[{userId,displayName,avatarUrl:null,mutedAt}], nextCursor}`.
- `ForumMuteLookup` (A'nın SPI'ı) `ForumMuteLookupImpl` ile uygulanır (`mutedBy(viewerId)` → sessize aldıklarım).
- `POST /api/forum/topics/{id}/block-author` ve `POST /api/forum/comments/{id}/block-author` → yalnız `{blocked:true}`. Yazar anonim olsa da mevcut `BlockService` engeli eklenir; kimlik hiçbir alanda dönmez. Kendi içeriği `400 FORUM_CANNOT_BLOCK_SELF`; görünmeyen içerik (silinmiş/kaldırılmış, yazar pasif ya da yazar bizi engellemiş) olmayanla aynı `404`.
- **Bilinen risk (sözleşmeden gelen):** sessize alma/engel anonim içerikte de uygulandığından, bir kullanıcı kimliğini tahmin ettiği biri için sessize alma/engel deneyip anonim içeriğin kaybolup kaybolmadığına bakarak anonimliği sınayabilir. Hız sınırı (saatte 60) yalnız yavaşlatır. Kalıcı çözüm istenirse A/B sessize almayı (engeli değil) YALNIZ anonim olmayan içeriğe uygulamalı; karar A/B/sözleşme sahibinde.

## 4. Güvenlik yardımcıları (A/B/C çağırır)

- `forum.moderation.spi.ForumSpamGuard` (bean `RedisForumSpamGuard`): `assertNotDuplicate(userId, scope, contextId, body)` aynı kullanıcı + normalize edilmiş birebir aynı gövdeyi 10 dk içinde (`app.forum.spam-window-seconds`, 600) ikinci kez görürse `429 FORUM_DUPLICATE_CONTENT` (+ `Retry-After`). Redis `SET NX PX` (`fspam:<uid>:<scope>[:<ctx>]:<özet>`); Redis yoksa/hata verirse bellek tablosu (fail-open). Normalize: sanitize + NFKC + küçük harf + harf/rakam dışını at. 20 karakterden KISA gövdelerde anahtara `contextId` (yorumda konu) eklenir ("Katılıyorum" farklı konulara yazılabilir). Kullanım: doğrulama ve `Idempotency-Key` tekrar oynatmasından SONRA, kayıttan hemen ÖNCE çağır; kayıt başarısız olursa `forget(...)`. Konu için gövde = `başlık + "\n" + açıklama`.
- `forum.moderation.spi.ForumTextSanitizer` (statik): `singleLine` (başlık, seçenek, gerekçe), `multiLine` (açıklama, yorum), `isBlank`, `compareKey`. NFC; kontrol karakterleri/NUL; sıfır genişlik + çift yönlü metin değiştirme karakterleri (RLO vb.); ZWJ/ZWNJ yalnız iki yanı ASCII ise silinir (emoji/Arapça bozulmaz); `<script>/<style>` blokları içeriğiyle, yorumlar, `<etiket ...>` kalıbı (olay öznitelikleri dahil) silinir (iç içe hile için çok geçişli); tek başına `<`/`>` ve `javascript:` gibi bağlantı metni düz metin kalır; boşluk daraltma, boş satır en çok 1. Sonuç boşsa `""` (çağıran kendi kodu ile reddeder).

## 5. Yönetim uçları (`/api/admin/forum/**`)

İzinler: okuma `forum.read` (FULL, MODERATOR, EDITOR, VIEWER), moderasyon `forum.moderate` (FULL, MODERATOR), kategori yazma `forum.categories` (FULL, EDITOR). Listeler sayfa tabanlıdır: yanıt `{items, nextCursor, page, size, hasNext, total}`; `page` (0 tabanlı) ya da `cursor` (= sonraki sayfa numarası, metin); `size` 1..50 (varsayılan 20). Zaman damgaları ISO-8601.

- `GET /api/admin/forum/reports?status=OPEN|RESOLVED|ALL&type=FORUM_TOPIC|FORUM_COMMENT&page=|cursor=&size=` → HEDEF başına satır (en çok açık şikâyet önce):
  `{targetType, targetId, topicId, preview, title, category:{id,name}|null, anonymous, author:{userId,displayName}|null, contentStatus: ACTIVE|REMOVED|DELETED|MISSING, pinned, locked, openReports, totalReports, reasons:{SPAM:2,PERSONAL_INFO:1}, resolveReportId|null, firstReportedAt, lastReportedAt, status: OPEN|RESOLVED}`.
  `anonymous=true` iken `author=null` (kimlik hiçbir alanda yok). Karar: `POST /api/admin/reports/{resolveReportId}/resolve` (`{action: DISMISS|WARN|HIDE|SUSPEND_USER, message?, reasonCode?}`; hedefin TÜM açık şikâyetlerini kapatır) ya da doğrudan `.../moderate`.
- `GET /api/admin/forum/actions?targetType=TOPIC|COMMENT&action=&page=|cursor=&size=` → `{id, targetType, targetId, topicId, action, reason, source: MODERATOR|REPORT|REPORT_AUTO, actor:{userId,displayName}|null, createdAt}` (yeniden eskiye).
- `GET /api/admin/forum/topics?q=&status=DEFAULT|ACTIVE|REMOVED|DELETED|PINNED|LOCKED|ALL&categoryId=&page=&size=` → `{id, title, bodyPreview, category, status: ACTIVE|REMOVED|DELETED, pinned, locked, anonymous, author|null, commentCount, likeCount, openReports, removedReason, createdAt, lastActivityAt}`; `total` dolu. Varsayılan (`status` yok): sahibinin silmedikleri.
- `POST /api/admin/forum/topics/{id}/moderate`, `POST /api/admin/forum/comments/{id}/moderate` (bkz. bölüm 2).
- Kategori yönetimi: bkz. bölüm 7 (A'nın `ForumCategoryService`'ine bağlı).

## 6. Hız sınırı tablosu (merkezî)

| Uç | Sınır | Uygulayan |
|---|---|---|
| Konu açma | 5 / saat / kullanıcı | A |
| Yorum yazma | 20 / dk | B |
| Beğeni (konu/yorum) | 120 / dk | A / B |
| Şikâyet (`POST /api/reports`) | 20 / gün + 5 / dk (mevcut kural; sözleşmedeki 20/saat'ten gevşek) | `ReportController` |
| Anket oyu | 60 / dk | C |
| Medya yükleme | 20 / saat | A |
| Sessize alma yaz/oku | 60 / saat yazma, 120 / dk okuma | D `ForumMuteController` |
| Yazarı engelle | 60 / saat | D `ForumBlockAuthorController` |
| Moderatör eylemi (kullanıcı API'si) | 120 / dk | D `ForumModerationController` |
| Tekrarlı içerik | 10 dk pencere, 429 `FORUM_DUPLICATE_CONTENT` | D `ForumSpamGuard` |

`RateLimitCoverageTest`: D'nin üç kullanıcı controller'ı `limiter.check` çağırır, baseline'a eklenmedi.

## 7. Test

`ForumTextSanitizerTest`, `RedisForumSpamGuardTest`, `ForumPermissionPolicyTest`, `ForumModerationMvcTest` (moderasyon, yetki, geçişler, denetim, yönetim listeleri, sessize alma, engelleme), `ForumReportHandlersTest`; mevcut `RbacCoverageTest`, `RateLimitCoverageTest`, `I18nMessagesIntegrityTest`, `AccountDataPurgerCoverageTest`, `QueryRulesTest`, `OpenApiExportTest` yeşil kalmalı.

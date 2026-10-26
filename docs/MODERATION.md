# Moderasyon altyapısı (T12)

Tür-bağımsız altyapı `edu.bingol.backend.moderation` paketindedir. Medya türleri (görsel mesaj, avatar, kulüp/etkinlik kapağı) kendi `ReportTargetHandler` bean'lerini ekleyerek bağlanır; moderasyon kodu değişmez.

## Yeni bir hedef türü eklemek (T8 / T10 / T11 için)

`ReportTargetType` içinde hazır türler: `MESSAGE_IMAGE`, `USER_AVATAR`, `COMMUNITY_COVER`, `EVENT_COVER` (sütun 16 karakter; ad uzunluğunu aşmayın). Kendi paketinizde `@Component` bir `ReportTargetHandler` yazın:

| Metot | Zorunlu | Anlamı |
|---|---|---|
| `type()`, `exists(id)`, `ownerId(id)`, `hide(id)` | evet | Mevcut sözleşme. `hide` idempotent yumuşak silme olmalı. |
| `preview(id)` → `Optional<MediaPreview>` | hayır | Yönetici kuyruğunda gösterilir. Görsellerde `MediaPreview.image(url, thumbUrl, mime)`: URL **yöneticiye özel yetkili uçtan** servis edilmeli (özel medya herkese açık `/files/**` altında olmaz). Silinmiş içerik için boş dönün. |
| `reversible()` + `unhide(id)` | hayır | `true` ise: (1) **otomatik gizleme eşiği** uygulanır, (2) sahibi **itiraz** edebilir, (3) itiraz kabulünde/rapor reddinde `unhide` çağrılır. Varsayılan `false` → yalnız yönetici kararıyla gizlenir. `unhide` gizlemeyi tam geri almalı. |

Sahibi bilinen her türde `ownerId` doldurun: ihlal sayacı, bildirim ve "kendi içeriğini raporlayamaz" kuralı buna dayanır. Gizlenen içeriği kendi API'nizde yok sayın (`hidden_at`/durum alanı).

Yasaklı görsel özeti: T1 medya hattı yüklemede `ContentBlocklist.isBlocked(sha256Hex)` çağırır (büyük/küçük harf fark etmez; geçersiz biçim `false`); `true` ise yükleme reddedilir. Tablo `blocked_content_hash`.

## Akışlar

- **Rapor oluşturma** (`POST /api/reports`): günlük 20 + dakikada 5 limit; bekleyen rapor veya son `re-report-block-days` gün içinde aynı hedefe rapor varsa `409 ALREADY_REPORTED`; rapor kısıtlıysa `403 REPORTING_RESTRICTED`.
- **Öncelik**: `priority = açık farklı raporlayıcı sayısı × 10 (+100 gizliyse)`; kuyruk `order=priority` ile yüksekten düşüğe.
- **Otomatik gizleme**: `reversible()` türde, en az `new-account-min-age-hours` yaşında hesaplardan gelen **farklı** raporlayıcı sayısı `auto-hide-threshold` olunca `hide` çağrılır, `moderation_target_state(hidden_by=AUTO)` yazılır, sahibine bildirim gider. Kararda `DISMISS`/`WARN` → `unhide`; `HIDE` → yönetici gizlemesi (`ADMIN`) olur.
- **İhlal takibi**: `HIDE/WARN/SUSPEND_USER` kararı sahibine ihlal yazar (`moderation_strike`); `strike-window-days` içinde `strike-suspend-threshold` aşılınca yöneticilere bildirim + `suspend_recommendation` (kullanıcı başına tek açık kayıt). İtiraz kabul edilirse o hedefin ihlalleri iptal edilir.
- **Rapor spamı**: `reject-window-days` içinde `reject-restrict-threshold` reddedilen (`DISMISS`) rapor → `restrict-days` gün rapor kısıtı (Redis `modrestrict:<uid>`) + bildirim.
- **Karar sonrası bildirim** (alıcının dilinde): sahibe (kaldırıldı/uyarı/yeniden görünür), raporlayanlara (işlem yapıldı / ihlal bulunmadı). Neden şablonları `DecisionReason` + `mod.reason.*` çevirileri.
- **İtiraz**: yalnız `reversible()` türlerde, yalnız gizli ve kendi içeriği için (aksi 404); bir gizleme olayı için bir itiraz; günde 5.
- **Denetim**: tüm yönetici yazma uçları mevcut `AuditInterceptor` ile `audit_log`'a düşer; karar veren id'si `report.resolved_by` / `moderation_appeal.decided_by` / `suspend_recommendation.decided_by` alanlarındadır.

## Ayarlar (`application.properties`, hepsi isteğe bağlı)

```
app.moderation.auto-hide-threshold=3        # 0 = kapalı
app.moderation.new-account-min-age-hours=24
app.moderation.strike-suspend-threshold=3   # 0 = kapalı
app.moderation.strike-window-days=180
app.moderation.reject-restrict-threshold=5  # 0 = kapalı
app.moderation.reject-window-days=30
app.moderation.restrict-days=7
app.moderation.re-report-block-days=30
app.moderation.smoke-handler=false          # YALNIZ duman betiği: sahte EVENT_COVER handler'ı
```

## Uçlar (yönetici, `ROLE_ADMIN`; ayrıntı `docs/ADMIN_API.md` sonundaki T12 bölümü)

`GET /api/admin/reports?status&order=asc|desc|priority&targetType&cursor&size` · `POST /api/admin/reports/{id}/resolve {action,message,reasonCode}` · `POST /api/admin/reports/bulk-resolve` · `GET /api/admin/reports/reason-templates` · `GET /api/admin/moderation/appeals`, `POST …/appeals/{id}/decide` · `GET /api/admin/moderation/suspend-recommendations`, `POST …/{id}/accept|dismiss` · `GET|POST /api/admin/moderation/blocklist`, `DELETE …/blocklist/{sha256}`.
Kullanıcı: `POST /api/appeals {targetType,targetId,message}`, `GET /api/appeals/mine`.

## Bilinen sınırlar

- Askıya alınmış kullanıcı kimlik doğrulayamadığı için **hesap askısına itiraz** bu sürümde yok (yalnız içerik itirazı); destek talebi (`/api/support`) kullanılır. Anonim itiraz ucu ayrı bir tasarım ve kötüye kullanım koruması ister.
- "Aynı kişinin çoklu hesabı" yalnız hesap yaşı ve farklı kullanıcı kimliği ile sınırlanır; cihaz/IP korelasyonu yoktur.
- Otomatik gizleme yalnız `reversible()` türlerde çalışır; mevcut MESSAGE/POST/COMMUNITY/EVENT handler'ları geri alınamaz olduğundan davranışları değişmedi.

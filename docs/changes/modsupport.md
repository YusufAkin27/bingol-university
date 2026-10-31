# Yönetici moderasyon ve destek tamamlama (P11 + P12)

Hedef: yönetici moderasyon ve destek akışına eksiksiz müdahale edebilsin, yanlış bir işlem yapmasın. Tüm uçlar `/api/admin/**`
altındadır (yalnız ADMIN), yazma uçları hız sınırlıdır (`AdminGuardInterceptor`) ve `AuditContext.target(...)` ile denetlenir.
Yıkıcı uçlar **sebep ister** (`X-Admin-Reason` başlığı ya da gövdede `reason`; en az 5 karakter) ve saatlik sıkı hız sınırına tabidir
(`AdminGuardPolicy.modSupportDestructive`).

Migration: **V730** (`moderation_reason_template` + `moderation_strike.forgiven_*`), **V740** (`support_ticket.priority/assignee_id`,
`support_ticket_note`). İndeks öneki `p11_` / `p12_`. Ceviri dosyaları: `i18n/modadmin*.properties`, `i18n/supportadmin*.properties`.

## P11 — moderasyon (`moderation/admin/**`)

| Uç | Not |
|---|---|
| `GET /api/admin/moderation/strikes?userId=&targetType=&resolution=&status=ACTIVE\|REVOKED\|ALL&from=&to=&page=&size=` | Sayfalı (`items,page,size,total,totalPages`); `from/to` gün (yyyy-MM-dd, Europe/Istanbul, `to` dahil) |
| `GET /api/admin/users/{id}/strikes` | `{userId, activeCount, items}` (son 200) |
| `POST /api/admin/moderation/strikes/{id}/forgive` `{reason}` | **Sebep zorunlu.** `revokedAt/forgivenBy/forgivenReason` yazılır → sayılan ihlal sayısı düşer, kullanıcıya bildirim (`notif.mod.strike.forgiven`). `{id,userId,remaining}`. 409 `STRIKE_ALREADY_REVOKED`, 404 `STRIKE_NOT_FOUND` |
| `GET /api/admin/moderation/hidden?targetType=&hiddenBy=AUTO\|ADMIN&from=&to=&page=&size=` | `ModerationTargetState` birleşik liste; satır: `reversible`, `exists`, `ownerId/ownerName`, `preview` |
| `POST /api/admin/moderation/hidden/{type}/{id}/restore` `{reason}` | **Sebep zorunlu.** Yalnız `ReportTargetHandler.reversible()` türler; olmayan tür 409 `TARGET_NOT_REVERSIBLE`, gizli değilse 404 `HIDDEN_CONTENT_NOT_FOUND`. Gizleme işareti silinir, hedefe bağlı ihlaller sayılmaz, sahibine bildirim gider |
| `GET /api/admin/moderation/reason-templates` | `{items:[{id,kind,code,textTr,textEn,textAr,active,sortOrder,updatedAt}], max:50}` (pasifler dahil) |
| `POST/PUT/DELETE .../reason-templates[/{id}]` | `code` (`^[A-Za-z][A-Za-z0-9_]{1,31}$`, büyük harfe çevrilir, sonradan değişmez), `textTr` zorunlu, boş en/ar Türkçeye düşer. En çok 50 (409 `REASON_TEMPLATE_LIMIT`). **DELETE sebep ister** |
| `GET /api/admin/reports/export.csv?status=OPEN\|RESOLVED\|ALL&targetType=&resolution=&reasonCode=&from=&to=` | UTF-8 BOM, formül kaçışı, en çok 50.000 satır; istek denetlenir |
| `GET /api/admin/appeals/export.csv?status=OPEN\|ACCEPTED\|REJECTED\|ALL&targetType=&from=&to=` | aynı |

Geriye uyum: `GET /api/admin/reports/reason-templates` aynı biçimde (`[{code,text,texts}]`) döner; tablo boşsa sabit `DecisionReason`
listesi, doluysa yalnız **etkin** şablonlar. Karar (`resolve`) geçerli kod olarak etkin şablon kodlarını kabul eder
(`ReasonTemplateService.validCode`); pasif/silinmiş kod 400 `REASON_CODE_INVALID`. Eski kararlardaki kod aynen kalır.

## P12 — destek (`support/admin/**`)

| Uç | Not |
|---|---|
| `GET /api/admin/support/tickets/{id}` | (mevcut uç) artık `messages` içinde **iç notları** `internal:true` ile, `priority`, `assigneeId/assigneeName` döner. Kuyruk satırlarına `priority`, `assigneeId` eklendi |
| `POST .../tickets/{id}/reopen` | Yalnız kapalı talep (409 `TICKET_NOT_CLOSED`); kullanıcıya bildirim |
| `PATCH .../tickets/{id}` `{priority?, assigneeId?, unassign?, category?}` | Atanan etkin yönetici olmalı (400 `ASSIGNEE_NOT_ADMIN`); boş/çelişkili istek 400 `TICKET_PATCH_EMPTY` |
| `POST .../tickets/{id}/notes` `{text}` | İç not: **müşteriye görünmez**, bildirim/e-posta gitmez. Ayrı tablo `support_ticket_note`; kullanıcı uçları (`/api/support/**`), herkese açık durum sorgusu ve CSV bu tabloyu hiç okumaz |
| `DELETE .../tickets/{id}` | **Sebep zorunlu, geri alınamaz.** Mesajlar, iç notlar ve `support_track_token` (herkese açık talep bağlantısı) silinir |
| `DELETE .../support/feedback/{id}` | **Sebep zorunlu.** Geri bildirim ve oyları silinir |
| `POST .../support/feedback/merge` `{sourceId,targetId,reason}` | Oylar hedefe taşınır (çift oy sayılmaz), kaynak silinir, kaynak yazarına bildirim. 400 `FEEDBACK_MERGE_SAME`; oyu olan kaynak herkese açık olmayan hedefe birleşmez (409 `FEEDBACK_MERGE_TARGET_NOT_PUBLIC`) |
| `PUT /api/admin/faq/order` `{ids:[...]}` | Kimlikler tekil ve aynı dil + kategoride olmalı (400 `FAQ_ORDER_INVALID`); `sortOrder` 10, 20, 30... atanır |
| `GET .../support/tickets/export.csv`, `.../support/feedback/export.csv` | Süzgeçli CSV; yalnız üst bilgi (mesaj gövdesi ve iç not YOK) |

## Doğrulama

Backend: `ModerationAdminHttpTest`, `HiddenAndTemplateServiceTest`, `SupportAdminHttpTest`, `ModSupportGuardPolicyTest` (H2).
Önemli güvenlik testi: iç not, müşteri ayrıntı/yanıt/liste uçlarında ve herkese açık durum bağlantısında görünmez
(`SupportAdminHttpTest.internalNote*`). PostgreSQL'e özgü yollar (oy taşıma SQL'i H2'de elle oluşturulan tabloyla denenir; V730/V740
şeması) duman betikleriyle doğrulanır: `scripts/smoke-admin-moderation.sh`, `scripts/smoke-admin-support.sh`.

Web: `StrikesPage`, `HiddenContentPage`, `ReasonTemplatesPage` (`/admin/moderation/{strikes,hidden,reason-templates}`);
`TicketDetailPage` (yeniden aç, öncelik/atama, iç not sekmesi, silme), `FeedbackPage` (silme/birleştirme), `FaqAdminPage` (sıralama),
CSV düğmeleri. Metinler `i18n/tr/admin-p11.ts` (yalnız Türkçe). Sözleşme betiği düzeltmesi: `api/system.ts` ölü kayıt çağrıları
sabit yollarla (`dead-letters/{mail|push}/{retry|delete}`) yazıldı.

## W1-C: yonetici PII maskeleme, destek temizligi, icerik filtresi, takip onerisi (T-018..T-024)

- **PII maskeleme (T-018/T-019):** `users.pii` olmayan profiller (SUPPORT, EDITOR, VIEWER) tum admin uclarinda maskeli e-posta/IP gorur (ayrinti: docs/ADMIN_API.md "Maskeleme"). Yeni `admin/pii/AdminPiiResponseAdvice` + `PiiScrubber` ikinci savunma hatti. `q=` aramalari maskeli profilde e-posta sutununa bakmaz (arama kehaneti kapandi); kullanici listesinde `q` en az 3 karakter (maskeli profil), aksi 400 `VALIDATION_ERROR`. API sekli DEGISMEZ (yalniz deger maskeli); FULL/MODERATOR ayni.
- **Destek temizligi (T-020):** `TicketRepository.deleteUnverifiedBefore/deletePublicUpdatedBefore` kendi `@Transactional`'ini tasir (sinif ici cagri proxy'yi dolandigindan gecelik temizlik hep basarisiz oluyordu: dogrulanmamis 24 sa ve 365 gunu dolan herkese acik talepler silinmiyordu). `scheduledCleanup` artik hatayi yutmaz (log + yeniden firlatir; `JobMonitor` `bu.scheduler.errors`).
- **ownTicket (T-021):** herkese acik talep kimligi kullanici uclarinda (`GET/messages/close`) 404 `TICKET_NOT_FOUND` (eskiden NPE 500 + varlik oracle'i).
- **Icerik filtresi (T-022/T-023):** baglanti/e-posta bicimli parca artik ATLANMAZ: `@ / : ? & = #` uzerinden bolunup parcalar esleyiciden gecer. Izin listesinin gevsek (i-noktasiz -> i) bicimi yalniz >=7 harfli sozcuklere tam eslesme (sikis/siki artik engelli; sikinti muaf). "amina koy*" kalibi (iki sozcuk + ek, kok ilk sozcugu asarsa), ek confusables (Kiril/Yunan: s j d f v q w u b x), `fvck/phuck/=phuk`. Kararlar: Sikkim izin listesine eklendi (kalkti); "Pornografi Semineri" ENGELLI KALIR (yonetici izin kaydi gerekir); ASCII "sikici" (sikici/can sikici ile cakisir) engellenmez; Kiril "u" y olarak kalir (u ile belirsiz). Admin "metni dene" kutusu (ProfanityAdminController, W3-F) bu bicimleri denemek icin kullanilabilir.
- **Takip onerileri (T-024):** `FollowService.suggestions` aday havuzunu "kulup arkadaslarim" + "ayni bolum" (her biri en cok 300) ile CTE'lerle daraltir, takip/engel dislamasi anti-join, sonuc kullanici basina 15 dk bellek ici onbellekte (okuma aninda takip/engel suzulur). `V920`: `prv9_user_dept_class_idx`, `prv9_user_block_blocked_blocker_idx`. Yanit sekli ayni.

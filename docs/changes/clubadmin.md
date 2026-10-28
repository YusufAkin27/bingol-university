# Yönetici kulüp derin yönetimi + kulüp içeriği moderasyonu (P06/P10)

Kapsam: `/api/admin/communities/**` (genişletildi) ve `/api/admin/community-posts/**` (yeni). Tüm uçlar yalnız ADMIN.
Backend paketi: `community/admin` (`ClubAdminController`, `ClubAdminService`, `ClubAdminQueryService`,
`ClubContentAdminController`, `ClubContentAdminService`, `ClubAdminDtos`). Migration: `V670__club_admin.sql`
(`community_post.hidden_at/hidden_reason/hidden_by/edited_at`, indeksler `p06_*`). Metinler: `i18n/clubadmin*.properties` (tr/en/ar).
Web: `web/src/pages/admin/ClubsManagePage.tsx` (`/admin/communities`), `ContentReviewPage.tsx` (`/admin/content-review`),
`clubs/**`, `api/adminCommunities.ts`, metinler yalnız Türkçe `i18n/tr/admin-p06.ts`.

## Zorla işlemlerin gerçek davranışı (koddan doğrulandı)
Sistem ADMIN'i `ClubPermissions.standing` içinde **OWNER rolü + sıra 100** (kulüp sahibinden yüksek) ile tüm yetkilere sahiptir.
Bu yüzden yönetici uçları var olan servisleri (`CommunityService`, `ClubRoleService`, `ClubInviteService`) `Actor(adminId, true)`
ile çağırır ve oradaki kurallar yöneticiye de aynen işler:
- Sahip çıkarılamaz (`403 OWNER_PROTECTED`), sahibin rolü/yetkisi değişmez, kimse kendi rolünü değiştiremez
  (`SELF_PERMISSION_CHANGE`), `OWNER` rolü rol uçlarından verilmez.
- Basic auth yöneticisinde kullanıcı kimliği yoktur: `club_audit.actor_id` `null` yazılır (kayıt aktörsüz).
- `ADMIN` rolünün ek kuralı yoktur: yönetici, kulüp `ADMIN`/`MODERATOR`ını da değiştirebilir/çıkarabilir (sıra 100).

## Uçlar
| Uç | Not |
|---|---|
| `GET /api/admin/communities?page=` | **`page` verilirse** sayfa tabanlı liste: `{items,page,size,total,totalPages}`. Süzgeç: `status` (boş = silinmişler hariç; `ALL` = hepsi; `PENDING_REVIEW/ACTIVE/REJECTED/HIDDEN/DELETED`), `category`, `q` (ad, adres, sahip adı/e-postası), `visibility`, `joinPolicy`, `ownerId`, `minReports`; `sort` = `createdAt|name|memberCount|openReports|id`, `dir` = `asc|desc`; `size` ≤ 100. Bilinmeyen değer `400 VALIDATION_ERROR`. **`page` yoksa** eski imeçli onay kuyruğu ucu (`status`, `cursor`, `size`) aynen çalışır. |
| `GET .../export.csv` | Aynı süzgeçler; UTF-8 BOM, CRLF, formül kaçışı (`'`), en çok 50.000 satır; kendisi denetlenir (`summary="csv satir=N"`). |
| `GET .../{id}` | Satır + `description`, `reviewNote`, `staff` (sahip/yönetici/moderatör), `bannedCount`, `statusHistory` (kapat/aç/devir/sil kayıtları), `openReports`, `recentAudit` (son 15 `club_audit`), `capabilities` (arayüzün göstereceği eylemler). Silinmiş kulüp de görüntülenir. |
| `PATCH .../{id}` | Kısmi: `name, description, category, joinPolicy, visibility`. **Küfür süzgeci atlanır** (yönetici ihlalli metni temizler; gönderi kararıyla aynı); kategori kuralı (etkin kategori) ve oda başlığı senkronu geçerli. Boş gövde `400`. |
| `POST/DELETE .../{id}/cover` | Kapak yükle (T1 görsel hattı) / kaldır. |
| `POST .../{id}/close` | **Sebep zorunlu.** `ACTIVE → HIDDEN` (keşif/arama/ayrıntıdan kalkar; rapor "gizle" kararıyla aynı durum), sohbet odası kapanır, üyelere yerelleştirilmiş bildirim. Etkinlikler iptal EDİLMEZ (etkinlik sorguları yalnız ACTIVE kulüpleri listeler; yeniden açılınca döner). Başka durumda `409 CLUB_ADMIN_STATE_INVALID`. Geri alınabilir. |
| `POST .../{id}/reopen` | **Sebep zorunlu.** `HIDDEN → ACTIVE`, oda yeniden açılır ve aktif üyeler geri eklenir, üyelere bildirim. |
| `DELETE .../{id}` | **Sebep zorunlu.** `CommunityService.deleteByAdmin`: yumuşak silme (`DELETED`), oda kapanır, gelecek etkinlikler iptal, kapak/logo + gönderi görselleri silinir, üyelere bildirim. Cevap `irreversible:true`. Silinmiş kulüp `404`. |
| `GET .../{id}/members` | Sayfalı; `status` (ACTIVE/PENDING/BANNED), `role`, `q`. Sıra: OWNER, ADMIN, MODERATOR, MEMBER. E-posta içerdiği için **okuma denetlenir (`@AuditRead`)**. |
| `DELETE .../{id}/members/{userId}?ban=` | **Sebep zorunlu.** Çıkar (`ban=true` yasaklar; yasaklı üyede `ban=false` yasağı kaldırır). Üyeye bildirim. |
| `PATCH .../{id}/members/{userId}/role` | **Sebep zorunlu.** Gövde `{role}`: `ADMIN/MODERATOR/MEMBER`. `OWNER` → `400 CLUB_ADMIN_USE_TRANSFER`; hedef sahipse `409 CLUB_LAST_OWNER` (son sahip korunur). |
| `POST .../{id}/transfer-ownership` | **Sebep zorunlu.** `{targetUserId, keepAsAdmin=true}`. İki aşamalı kabul gerekmez (yönetici kararı, **geri alınamaz**). Hedef kulübün aktif, hesabı ACTIVE üyesi olmalı (`400 TRANSFER_TARGET_INVALID`), 3 canlı kulüp sahipliği sınırı (`409 COMMUNITY_LIMIT`), kulüp ACTIVE/HIDDEN (`409 CLUB_ADMIN_STATE_INVALID`). Bekleyen devir teklifi iptal edilir; her iki tarafa bildirim. |
| `GET .../{id}/join-requests`, `POST .../join-requests/{userId}/approve\|reject` | Bekleyen katılma istekleri ve zorla karar (`MANAGE_MEMBERS` yönetici için doğal). |
| `GET .../{id}/invites`, `DELETE .../{id}/invites/{inviteId}` | Davet listesi / iptal (iptal sebep ister). |
| `GET .../{id}/club-audit` | Kulüp içi denetim kaydı (imeçli); yönetici işlemleri `ADMIN_*` eylemleriyle yazılır. |
| `GET /api/admin/community-posts` | Sayfa tabanlı: `communityId`, `kind` (POST/ANNOUNCEMENT/ALL), `status` (VISIBLE/HIDDEN/DELETED/ALL), `minReports`, `q` (metin/yazar/kulüp), `authorId`, `from`/`to` (`YYYY-AA-GG`, Europe/Istanbul), `sort` (`createdAt|reports`). |
| `GET .../community-posts/{id}` | Gönderi + şikâyetleri (POST hedefli). |
| `PATCH .../community-posts/{id}` | `{text}` 1–2000; silinmişte `404`; küfür süzgeci atlanır; yazara bildirim; `edited_at`. |
| `POST .../community-posts/{id}/hide\|unhide` | Gizle (sabitlemeyi de kaldırır; idempotent; yazara bildirim) / geri al. Gizli içerik kulüp akışı, sabitliler ve duyuru listesinden düşer (`hidden_at IS NULL` süzgeci), yönetici listesinde görünür. |
| `DELETE .../community-posts/{id}` | **Sebep zorunlu.** Yumuşak silme + görsel dosyası silinir (`CommunityPostMedia`). Açık `POST` şikâyeti varsa `ReportService.resolve(HIDE)` ile sonuçlandırılır (yazar + raporlayanlar bildirilir); yoksa yazara "kaldırıldı" bildirimi. Cevap `irreversible:true`. |

## Güvenlik
- `AdminGuardPolicy`: close/reopen/transfer-ownership (POST), kulüp/üye/davet/kulüp-içeriği silme (DELETE), üye rolü (PATCH) → sebep (≥5) + yıkıcı saatlik hız sınırı (20). Diğer yazmalar dakikada 60.
- Denetim hedefi: kulüp uçları `COMMUNITY/{id}`, içerik uçları `COMMUNITY_POST/{id}` (`AuditContext.target`), özet kısa metin.
- Sebep: `X-Admin-Reason` başlığı (web her zaman başlıkla yollar) ya da gövdede `reason`.
- Okuma uçları yönetici başına dakikada 120.

## Yeni hata kodları (tr/en/ar `clubadmin*.properties`)
`CLUB_ADMIN_STATE_INVALID` (409), `CLUB_ADMIN_USE_TRANSFER` (400), `CLUB_LAST_OWNER` (409). Diğerleri mevcut kodlardır
(`OWNER_PROTECTED`, `ESCALATION_DENIED`, `TRANSFER_TARGET_INVALID`, `COMMUNITY_LIMIT`, `NOT_MEMBER`, `POST_NOT_FOUND`...).
Yeni bildirimler: `notif.community.adminClosed|adminReopened|adminDeleted|adminRemoved|adminBanned|adminOwnerAssigned|adminOwnerRemoved|postAdminEdited|postAdminHidden`.

## Test ve duman
`ClubAdminControllerTest`, `ClubAdminReasonTest`, `AdminUpdateGuardTest` (backend, H2); `web/src/pages/admin/clubs/clubs.test.tsx`;
`scripts/smoke-admin-communities.sh` (curl; PostgreSQL'e özel yollar için çalışan yığın ister).

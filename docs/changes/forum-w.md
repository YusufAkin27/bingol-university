# Kampüs Forum: web yönetim alanı (W)

Tarih: 2026-11-05. Dal: `deploy/forum-web-20261105`. Sözleşme: `docs/FORUM_API.md` §2-D ve §4. Yönetim paneli yalnız Türkçedir.

## Sayfalar (`web/src/pages/admin/forum/`)

| Yol | Sayfa | Menü izni | Uçlar |
|---|---|---|---|
| `/admin/forum/reports` | Şikâyet kuyruğu (`FORUM_TOPIC` / `FORUM_COMMENT`) | `forum.read` (eylem: `forum.moderate`) | `GET /api/admin/forum/reports?status=&type=&reason=&cursor=`, `POST /api/admin/forum/topics/{id}/moderate`, `POST /api/admin/forum/comments/{id}/moderate`, `POST /api/admin/forum/reports/{id}/resolve` |
| `/admin/forum/topics` | Konular (arama, durum, kategori, sayfa tabanlı, ayrıntı çekmecesi) | `forum.read` (eylem: `forum.moderate`) | `GET /api/admin/forum/topics?q=&status=&categoryId=&page=&size=`, `POST .../topics/{id}/moderate` |
| `/admin/forum/actions` | İşlem kayıtları (`forum_moderation_action`) | `forum.read` | `GET /api/admin/forum/actions?action=&targetType=&cursor=` |
| `/admin/forum/categories` | Kategoriler (ekle, düzenle tr/en/ar, sırala, arşivle) | `forum.categories` | `GET\|POST /api/admin/forum/categories`, `PATCH\|DELETE .../categories/{id}`, `POST .../categories/reorder {ids}` |

- Her moderatör eylemi (sabitle, kilitle, kaldır, geri al, yoksay) gerekçe ister: `GuardedDialog`, en az 5 karakter, `X-Admin-Reason` başlığı (yüzde kodlu) + gövdede `reason` + `Idempotency-Key`.
- İzin yoksa eylem düğmeleri hiç çizilmez ("salt okunur" notu görünür); izin bilgisi yüklenirken de çizilmez (titreme yok). Asıl denetim sunucudadır.
- Anonim içerikte yazar adı istemcide hiç taşınmaz, "Anonim" yazılır (sunucu zaten kimlik vermez; ikinci emniyet: `api/adminForum.ts` normalleştiricileri).
- Yanıt şekilleri tek dosyada (`web/src/api/adminForum.ts`) toplanır; normalleştiriciler hem düz dizi hem `{items}` ve `nameTr` ile `names:{tr,en,ar}` biçimlerini kabul eder.

## Tümleşik dosyalar

`layouts/adminNav.ts` (Forum grubu, 4 öğe), `routes.admin.tsx` (4 tembel rota), `paths.ts`, `api/rbac.ts` (`forum.read|moderate|categories`), `search/index/forum.ts` + `search/pageInfo.ts` + `search/registry.ts` (panel araması), `i18n/tr/admin-forum.ts` (sayfa metinleri, tembel parça), `i18n/bundles/admin-tr-only.ts` (yalnız 5 menü etiketi, ana parça), `i18n/tr/admin-sys2.ts` (rol matrisi alan adı), `scripts/check-i18n.mjs` (tr-only listesi), `layouts/navPolicy.test.ts` (menü uç tablosu).

## Backend ile birleşirken

- `AdminPermissionPolicy` kuralları: `GET /api/admin/forum/{reports,topics,actions}` -> `forum.read`, `GET /api/admin/forum/categories` -> `forum.categories`; aksi halde `navPolicy.test.ts` menü izni ile politikanın ayrıştığını bildirir.
- Yanıt alan adları belgeden ayrışırsa yalnız `web/src/api/adminForum.ts` içindeki `normalize*` işlevleri uyarlanır.

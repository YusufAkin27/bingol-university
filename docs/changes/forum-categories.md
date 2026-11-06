# Forum: kategori genişletme ve kategori araması (V1480)

Kullanıcı isteği: "kampüs forum kısmında kategorileri arttır, çok fazla olsun, aratma ekle aratabilsin".

## Veri (V1480__forum_categories_more.sql)

- **79 kategori** (eski 8 + 71 yeni), 8 grupta: Genel, Akademik, Kampüs Yaşamı, Kariyer & Gelişim, Fakülte & Alanlar, Bingöl, Hobi & Eğlence, Yaşam. Her kategori ve grup tr/en/ar adlıdır.
- Yeni tablo `forum_category_group(group_key PK, name_tr, name_en, name_ar, sort_order)`; `forum_category.group_key` (FK, boş = grupsuz). Kısıt/indeks öneki `fc148_`.
- **Eski 8 kategorinin kimliği, slug'ı, adı ve `sort_order`'ı (10-80) değişmez**; yalnız `group_key` atanır. Yeni kategoriler `sort_order` 100'den başlar (grup sırasıyla, 10'arlı). Böylece "ilk N kategori" (mobil yatay çip satırı) eski sekizli olarak kalır.
- Eklemeler `ON CONFLICT (slug) DO NOTHING` ile idempotenttir. Moderasyon notu/açıklama alanı eklenmedi.

## API

- `GET /api/forum/categories` yanıt öğesine **`groupKey`, `groupName` (istek dilinde), `groupOrder`** eklendi (grupsuz: `null`, `null`, `2147483647`). Eski alanlar aynen.
- **`GET /api/forum/categories?q=`**: kategori adı (tr/en/ar), adres (slug) ve grup adında arama. Türkçe karakter ve büyük/küçük harf duyarsız (İ/I/ı/i, ç ğ ö ş ü; Arapça hareke/elif biçimleri), boşlukla ayrılan her sözcük eşleşmeli (VE). Boş `q` = tüm liste. Eşleşme Java'da yapılır (`ForumCategorySearchText`; veritabanında `unaccent` eklentisi yok), LIKE kullanılmadığından `%`/`_` literaldir. Sonuç sayıları anlıktır: önbelleklenmez. Hız sınırı: normal okuma 120/dk + `q` varken ek 90/dk.
- Kategori listesinin üst sınırı 200 (`MAX_CATEGORIES`), 79 kategoriye yeter.
- **Konu araması** (`GET /api/forum/search`): sorgu bir kategori adıyla (Türkçe karakter duyarsız) eşleşiyorsa o kategorideki konular da `matchedIn=CATEGORY` ile gelir ("muzik" yazan "Müzik" kategorisini bulur). Grup adı bu eşleşmeye katılmaz. Başlık/açıklama/yorum arama (V1442 `search_vec`), engel/sessize alma ve silinmiş içerik kuralları değişmedi.
- Yönetici `GET|POST|PATCH /api/admin/forum/categories` görünümü `groupKey` taşır; `POST/PATCH` gövdesinde isteğe bağlı `groupKey` (var olan grup; PATCH'te boş metin grubu kaldırır; yoksa 400 `FORUM_CATEGORY_INVALID`). Yeni uç yok, `AdminPermissionPolicy` değişmedi.

## Test / duman

- `ForumCategorySearchTextTest`, `ForumCategoryServiceTest` (grup, arama, `matchingActiveIds`), `ForumTopicControllerTest` (q + grup alanları), `ForumSearchServiceTest`.
- PostgreSQL duman: `scripts/smoke-forum-categories.sh` (>= 50 kategori, gruplar, `q=` araması, kategoride konu, kategori adıyla konu araması).

## Dağıtım

V1480, V1470/V1471+ dallarından sonra uygulanır (`out-of-order=false`); başka bağımlılığı yoktur. Eski mobil sürümler yeni alanları yok sayar (geriye uyumlu).

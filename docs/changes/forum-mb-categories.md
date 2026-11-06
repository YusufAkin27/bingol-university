# Forum mobil: çok sayıda kategori + aramalı kategori seçici

Sunucu tarafı (V1480, 79 kategori, `GET /api/forum/categories?q=`): `docs/changes/forum-categories.md` (dal `deploy/forumcat-20261106`).

## Ekranlar

- **Forum ana sayfa**: üst çubuktaki arama ikonu kalktı; yerine ipucu satırının altında **görünür arama kutusu** (`forum-search`, salt okunur alan) var. Dokununca forum arama sayfası açılır (yazma orada: 350 ms bekleme, en az 2 karakter, son aramalar, popüler konular, boş sonuç ekranı, kategori süzgeci, sıralama).
- **Kategori çipleri** (`ForumCategoryChips`): "Tümü" + sunucu sırasıyla ilk **8** kategori + sonda **"Tüm kategoriler"** çipi (`forum-chip-more`; kategori sayısı 8'i aşıyorsa). Seçili kategori ilk 8'in dışındaysa (seçiciden seçildi) "Tümü"den hemen sonra görünür. Eski anahtarlar korunur (`forum-chip-all`, `forum-chip-<id>`).
- **Kategori seçici** (`ForumCategoryPickerPage`, `openForumCategoryPicker`): tam sayfa; üstte arama kutusu (`forum-cat-search`), altta grup başlıklı bölümler (Genel, Akademik, Kampüs Yaşamı, ...). Her satır: ad + (varsa) "N konu" + seçiliyse onay işareti, 48 dp hedef. Kutu boş değilken "Tümü" satırı gizlenir. Sayfa başlığı metni yoktur (ekran okuyucu etiketi vardır).
  - **Arama**: anlık yerel süzme; büyük/küçük harf, Türkçe karakter (İ/I/ı/i, ç ğ ö ş ü) ve Arapça hareke/elif farkı yok sayılır (`foldForumSearch`); sözcükler VE ile eşleşir; ad + slug + grup adında aranır. **Yerelde sonuç yoksa** (liste eskimiş olabilir) 350 ms sonra sunucu `?q=` sorulur.
  - Durumlar: yükleniyor (iskelet), hata/çevrimdışı (yeniden dene), sonuç yok (boş durum), seçim/vazgeçme sonucu (`ForumCategoryChoice`, kategori `null` = Tümü).
- **Forum araması** (`ForumSearchPage`): kategori süzgeci aynı çip satırı + seçici (anahtar `forum-search-categories`); seçim `categoryId` olarak isteğe gider.
- **Yeni konu / düzenle**: kategori alanı (`CategoryPickerRow`, `forumCategoryField`) artık aynı aramalı seçiciyi açar ("Tümü" satırı yok); satır anahtarları `forumCategory<id>`.

## Veri

`ForumCategory`: `groupKey`, `groupName`, `groupOrder` (eski sunucu: boş/0, bölümsüz tek liste). `ForumApi.categories({force, q})`. Saf mantık: `lib/features/forum/data/forum_category_filter.dart` (`foldForumSearch`, `filterForumCategories`, `groupForumCategories`, `forumChipCategories`).

## Metinler

Yeni ARB anahtarları (tr/en/ar): `forumCatAll`, `forumCatPickerA11y`, `forumCatSearchHint`, `forumCatEmptyTitle`, `forumCatEmptyBody`, `forumCatTopicCount`, `forumCatLoadFailed`.

## Test

`test/forum_category_picker_test.dart` (saf mantık, seçici sayfası, ana sayfa çipleri, arama sayfası, yeni konu alanı; 320/390 dp, yazı x1.3, açık/koyu, tr/ar).

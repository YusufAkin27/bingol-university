# Kampüs Haritası (`campus` paketi)

Bingöl Üniversitesi kampüsünün gerçek OpenStreetMap altlığı üzerinde haritası (yerler üniversitenin kendi haritasından): kampüs sınırı poligonu, yalnızca **kampüs içi** arama, kategoriler, yer detayı. Mobil (Flutter) ve web yönetim paneli bu sözleşmeye göre yazılır.

- Kod: `backend/src/main/java/edu/bingol/backend/campus/`
- Şema: `V1200__campus_map.sql` (`campus_place`, `campus_config`); tohum: `V1201__campus_seed.sql` (OpenStreetMap). Migration aralığı V1200-V1219 bu modüle ayrılmıştır.
- Çeviriler: `i18n/campus*.properties` (kategori etiketleri `campus.cat.*`, hata kodları `error.CAMPUS_*`).
- Kişisel veri **tutulmaz**: favoriler istemcide yerel saklanır (sunucuda kullanıcıya bağlı kayıt yok, `DataExporter`/`AccountDataPurger` gerekmez). Yeni bir sunucu tarafı favori eklenirse önce o karar verilmelidir.

## 1. Kullanıcı uçları (giriş gerekli, rate limit kullanıcı başına 120/dk)

Yanıtlar `Accept-Language` diline göre (`tr` varsayılan, `en`, `ar`) etiketlenir; `ETag` + `Cache-Control: private, max-age=N` döner (harita 300 sn, liste 60 sn, yer 300 sn); sunucuda `campus` ad alanında önbelleklenir ve yönetici yazmasında anında geçersiz kılınır.

### `GET /api/campus/map`

```json
{
  "version": 3,
  "center": {"lat": 38.900891, "lng": 40.485254},
  "zoom": {"initial": 16, "min": 14, "max": 19},
  "bounds": {"south": 38.894282, "west": 40.47139, "north": 38.907499, "east": 40.499119},
  "boundary": [[38.901199, 40.473759], [38.901329, 40.473701], "... 54 nokta [lat,lng]"],
  "tiles": {
    "urlTemplate": "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
    "attribution": "© OpenStreetMap katkıda bulunanları",
    "maxNativeZoom": 19,
    "userAgentHint": "BUKampus/{version}"
  },
  "categories": [
    {"key": "faculty", "label": "Fakülteler", "icon": "school", "color": "#1E5AA8"}
  ]
}
```

- `version`: her yer veya ayar yazmasında artan tam sayı. İstemci önbelleğini bununla tazeler.
- `boundary`: kampüs sınırı, `[lat, lng]` çiftleri, halka açıktır (son nokta ilkine eşit tekrar edilmez; poligon kapalı kabul edilir). Boş dizi = sınır henüz girilmedi (istemci çizmez).
- `bounds`: kaydırma sınırı (kamera bu kutudan çıkmamalı). `zoom.min/max` kullanıcı yakınlaştırma aralığı; `tiles.maxNativeZoom` üstünde karo büyütülür (overzoom).
- `userAgentHint`: karo isteklerinde gönderilecek `User-Agent` kalıbı; istemci `{version}` yerine kendi sürümünü koyar (`BUKampus/2.0.6`). OSM politikası açık `User-Agent` ister.
- `tiles.attribution` haritanın köşesinde **her zaman** görünmelidir (ODbL).
- `categories` sırası sekme sırasıdır. Anahtarlar sabittir (beyaz liste):

| key | Türkçe etiket | icon (mobil anahtarı) | color |
|---|---|---|---|
| `faculty` | Fakülteler | `school` | `#1E5AA8` |
| `institute` | Enstitüler | `science` | `#4A7FC1` |
| `school` | Yüksekokullar | `account_balance` | `#2F6DB0` |
| `vocational` | Meslek Yüksekokulları | `construction` | `#8A6BC2` |
| `dining` | Yemekhane | `restaurant` | `#E07B39` |
| `library` | Kütüphane | `local_library` | `#7B4FB8` |
| `sports` | Spor | `sports_soccer` | `#2E9B5B` |
| `health` | Sağlık | `local_hospital` | `#D64545` |
| `admin` | İdari | `business` | `#5B6B7C` |
| `service` | Uygulama ve Hizmet Birimleri | `miscellaneous_services` | `#6B8E23` |
| `dorm` | Yurt | `hotel` | `#A0714F` |
| `gate` | Giriş kapıları ve otopark | `local_parking` | `#3C8DAD` |
| `social` | Sosyal alanlar | `park` | `#C2398A` |

Karar: üniversitenin kendi haritasındaki grup başlıkları (Fakülteler, Enstitüler, Yüksekokullar, Meslek Yüksekokulları, Merkezi Birimler, Sağlık Tesisleri, Sosyal Yaşam Alanları, Uygulama ve Hizmet Birimleri, Konaklama ve Organizasyon) kategori anahtarlarına şöyle eşlenir: Fakülteler→`faculty`, Enstitüler→`institute`, Yüksekokullar→`school`, Meslek Yüksekokulları→`vocational` (ayrı kategoriler seçildi: kullanıcı sitedeki gruplamayı tanır, 8 MYO tek bir "Birimler" yığınında liste okunurluğunu bozardı; istemci isterse bu dört sekmeyi tek "Akademik birimler" sekmesinde birleştirebilir); Merkezi Birimler→`admin` (Rektörlük, İdari Birimler, Merkezi Laboratuvar) ve `library` (Kütüphane); Sağlık Tesisleri→`health`; Sosyal Yaşam Alanları→`dining` (Merkezi Kafeterya), `sports` (Spor Salonu, Halı Saha), `social` (Cami, Yaşam Merkezi); Uygulama ve Hizmet Birimleri→`service`; Konaklama→`dorm` (yurtlar, Konuk Evi; anahtar `dorm`, `dormitory` DEĞİL) ve Kongre Merkezi→`social`. `gate` için sitede kayıt yok (boş kategori; istemci boş kategoriyi gizleyebilir).

### `GET /api/campus/places?category=&q=&limit=`

```json
{"items": [{
  "id": 12, "name": "Mühendislik Fakültesi", "category": "faculty",
  "lat": 38.899945, "lng": 40.484455,
  "summary": null, "photoUrl": null, "units": [],
  "footprint": [[38.8999, 40.4844], [38.9, 40.4845], [38.9001, 40.4843]],
  "sortKey": 70,
  "webUrl": "https://mmf.bingol.edu.tr", "remote": false,
  "unitSourceCode": "mmf", "departments": null
}]}
```

- `category`: boşsa hepsi; bilinmeyen anahtar `400 CAMPUS_CATEGORY_INVALID`.
- `q`: **Türkçe-duyarsız** ad ve birim araması (`mü` = `MÜ` = `mu` → "Mühendislik Fakültesi"; `kutup` → "Kütüphane"). İstek ve kayıt `i/ı/İ→i, ş→s, ğ→g, ü→u, ö→o, ç→c` ile sadeleşir. Sıralama: ad öneki, kelime öneki, içerik; sonra `sortKey`, ad. `%` ve `_` joker değil, düz karakterdir. En çok 60 karakter. Arama sonuçları sunucuda önbelleklenmez.
- `limit`: varsayılan 100, en çok 200 (üstü 200'e çekilir, hata vermez).
- **Yalnızca `campus_place` kayıtları** döner (aktif ve silinmemiş): kampüs dışı arama yoktur. İstemci de dışarıdan (ör. Nominatim) hiçbir yer aramamalıdır.
- `webUrl`: birimin resmi sayfası (yalnız `https` + `bingol.edu.tr` alt alanı; yoksa `null`).
- `remote`: **ana yerleşke dışı** birim (Ilıcalar Termal Tesis, Hayvan Hastanesi, Modern Arıcılık Kompleksi, Genç MYO, Solhan Sağlık Hizmetleri MYO). `remote=true` kayıtlar ana harita sınırlarında/kampüs poligonunda gösterilmez; kamera `bounds` bu birimleri kapsamaz. Aramada ve listede "Diğer yerleşkeler" grubu olarak sunulur; haritada isteğe bağlı ayrı küçük "uzak birimler" listesi olarak (kamera sınırı bozulmadan) gösterilebilir.
- `unitSourceCode` / `departments`: akademik kategorilerde (`faculty|institute|school|vocational`) `webUrl` konağı projedeki birim haber kaynağıyla (`unit_source`, `/api/news/unit`) aynıysa kaynak kodu (`mmf`, `fbe`, `btmyo`...), değilse `null`. `departments` o kaynağın bölüm adlarıdır (`unit_department`, salt okuma; kaynak siteye istek atılmaz) ve **yalnız `GET /places/{id}` yanıtında** dolu gelir (kod yoksa `null`); liste öğesinde her zaman `null`. Detayda "Birimler" satırı önce `departments`, boşsa elle girilen `units` gösterir. `unit_department` boş olabilir (gece senkronundan önce): `[]` normaldir.
- `photoUrl`: göreli `/files/covers/<özet>.jpg` (istemci API tabanına ekler) ya da `null`. `units`: yerde bulunan birimler (boş olabilir). `footprint`: bina/alan dış hattı `[lat,lng]` (yoksa `null`; nokta işaretçisi çizilir). Yürüme süresi istemcide hesaplanır.

### `GET /api/campus/places/{id}`
Tek kayıt (yukarıdaki öğe). Yok, pasif ya da silinmişse `404 CAMPUS_PLACE_NOT_FOUND`.

### Hata kodları
`CAMPUS_PLACE_NOT_FOUND` (404), `CAMPUS_CATEGORY_INVALID` (400); yönetici uçları ek olarak `CAMPUS_COORD_INVALID`, `CAMPUS_OUT_OF_BOUNDS`, `CAMPUS_POLYGON_INVALID`, `CAMPUS_TILE_URL_INVALID`, `CAMPUS_ZOOM_INVALID`, `CAMPUS_BOUNDS_INVALID`, `CAMPUS_WEB_URL_INVALID`, `CAMPUS_PLACE_LIMIT` (hepsi 400, üç dilde).

## 2. Yönetici uçları (`/api/admin/campus/**`)

İzinler: `campus.read` (FULL, MODERATOR, SUPPORT, EDITOR, VIEWER) ve `campus.write` (FULL, EDITOR). Yazmalar `AuditInterceptor` ile denetim kaydına düşer (hedef `CAMPUS_PLACE` / `CAMPUS_CONFIG`); yazma başına saatte 120 limit.

| Uç | Açıklama |
|---|---|
| `GET /places?category=&q=&page=0&size=50` | Pasifler dahil, silinmişler hariç. `{items, page, size, total}`; öğe: kullanıcı öğesi + `active, sourceRef, createdAt, updatedAt` |
| `GET /places/{id}` | Tek kayıt |
| `POST /places` | 201; gövde aşağıda |
| `PUT /places/{id}` | Tam değiştirme (`active` boşsa mevcut korunur) |
| `DELETE /places/{id}` | **Gerekçeli** (`X-Admin-Reason` ya da gövdede `reason`) yumuşak silme; `{id, deleted:true}`. Tohum satırı silinse de yeniden eklenmez (`source_ref` satırı durur) |
| `POST /places/{id}/photo` | `multipart` `file`; mevcut medya hattı (tür/boyut doğrulama, yeniden kodlama, EXIF temizliği; `ImageKind.COVER`). `DELETE .../photo` kaldırır |
| `GET /config` | `/api/campus/map` ile aynı şekil (Türkçe etiketlerle) |
| `PUT /config` | Merkez, zoom, sınır poligonu, karo adresi/atıf; tam değiştirme |

`PlaceRequest`:
```json
{"name": "Mühendislik Fakültesi", "category": "faculty", "lat": 38.899945, "lng": 40.484455,
 "summary": "Kısa tanım", "units": ["Bilgisayar Mühendisliği"], "footprint": [[38.9,40.48],[38.9,40.49],[38.91,40.49]],
 "sortKey": 10, "active": true, "webUrl": "https://mmf.bingol.edu.tr", "remote": false}
```
Sınırlar: `webUrl` boş ya da `https://` + `bingol.edu.tr` (alt alanı) (`CAMPUS_WEB_URL_INVALID`), `remote=true` ise koordinat harita sınırı denetimi yapılmaz (yalnız aralık), `name` 1-120, `summary` ≤ 300, en çok 20 birim (her biri ≤ 80), `footprint` ≥ 3 en çok 200 nokta, `category` yukarıdaki beyaz liste, koordinat `config.bounds` içinde olmalı (`CAMPUS_OUT_OF_BOUNDS`), toplam en çok 2000 yer.

`PUT /config` gövdesi:
```json
{"center": {"lat": 38.9009, "lng": 40.4853}, "zoom": {"initial": 16, "min": 14, "max": 19},
 "bounds": {"south": 38.89, "west": 40.47, "north": 38.91, "east": 40.50},
 "boundary": [[38.8958, 40.4737], [38.8958, 40.4968], [38.9060, 40.4968], [38.9060, 40.4737]],
 "tiles": {"urlTemplate": "https://tiles.example.com/{z}/{x}/{y}.png", "attribution": "© Example", "maxNativeZoom": 18, "userAgentHint": "BUKampus/{version}"}}
```
Sunucu doğrulaması: enlem -90..90, boylam -180..180; `boundary` 3-500 farklı nokta ve sıfırdan büyük alan; `1 ≤ min ≤ initial ≤ max ≤ 22`; `bounds` verilmezse poligon kutusundan kenar payıyla hesaplanır, verilirse merkezi ve poligonu kapsamalı ve her yönde en çok 2 derece olmalı; karo adresi yalnızca `https://`, `{z}`, `{x}`, `{y}` (+ isteğe bağlı `{s}`, `{r}`) içermeli, kullanıcı bilgisi/boşluk/başka yer tutucu olmamalı, ≤ 300 karakter; atıf düz metin (`<`, `>` yok).

## 3. Veri kaynağı ve lisans

**Yerler (ad, konum, web adresi): üniversitenin kendi kampüs haritası** (https://harita.bingol.edu.tr/), 2026-11-02'de tarayıcıda **tek seferlik** okundu (44 birim; koordinatlar sitenin kendi WGS84 işaretçi değerleridir). Sitedeki Google Maps API anahtarı **kullanılmadı ve hiçbir yere yazılmadı**; karo altlığı OpenStreetMap'tir. Sitedeki "grup" başlıkları DOM'da yüklenmediğinden kategori eşlemesi **ada göre** yapılmıştır (bölüm 1 karar notu); yanlış eşleşen kayıt yönetici panelinden düzeltilir. Tohum satırları `source_ref = 'harita:<site birim no>'` taşır.

**Kampüs sınırı poligonu:** üniversite sitesinde yoktur; OpenStreetMap'te vardır ve kullanılmıştır: `way/370957632` (`amenity=university`, "Bingöl Üniversitesi", 54 düğüm, © OpenStreetMap katkıda bulunanları, **ODbL 1.0**, https://www.openstreetmap.org/copyright). Ana yerleşkedeki 39 birimin tamamı bu poligonun içinde kalır (doğrulandı), bu yüzden tahmini dışbükey zarf üretilmedi. Poligon yönetici panelinden düzeltilebilir (`PUT /config`). `bounds` (kamera sınırı) poligonun kutusu + kenar payıdır ve ana yerleşkeyi kapsar; `remote` birimler kapsam dışıdır.

Uygulamada atıf zorunludur (haritada `tiles.attribution`; ayrıca hakkında/lisans ekranında "Harita verisi © OpenStreetMap katkıda bulunanları, ODbL"). Sınır verisi ODbL kapsamındaki türetilmiş veri tabanımızın parçasıdır.

Tohumdaki 44 kayıt: `faculty` 10 (Diş Hekimliği, Fen Edebiyat, Fizik Tedavi ve Rehabilitasyon, İktisadi ve İdari Bilimler, İlahiyat, Mühendislik, Sağlık Bilimleri, Spor Bilimleri, Veteriner, Ziraat), `institute` 5 (Fen Bilimleri, Kur'an-ı Kerim Araştırmaları ve Kıraat İlmi, Sağlık Bilimleri, Sosyal Bilimler, Yaşayan Diller), `school` 1 (Yabancı Diller YO), `vocational` 7 (Bilişim Teknolojileri, Genç*, Gıda Tarım ve Hayvancılık, Sağlık Hizmetleri, Solhan Sağlık Hizmetleri*, Sosyal Bilimler, Teknik Bilimler), `dining` 1 (Merkezi Kafeterya), `library` 1, `sports` 2 (Spor Salonu, Halı Saha), `health` 3 (Diş Hekimliği Fakültesi Hastanesi, Aile Sağlığı Merkezi, Hayvan Hastanesi*), `admin` 3 (Rektörlük, İdari Birimler, Merkezi Laboratuvar), `service` 5 (PİKOM, Arı Ürünleri Tanıtım Ofisi, Teknoloji Transfer Ofisi, Ilıcalar Termal Tesis*, Modern Arıcılık Kompleksi*), `dorm` 3 (Erkek ve Kız Öğrenci Yurdu, Konuk Evi), `social` 3 (Kongre Merkezi, Cami, Yaşam Merkezi). `*` = `remote=true` (5 kayıt). `summary`, `units`, `photoUrl`, `footprint` tohumda boştur (uydurma metin yazılmadı); yöneticiler doldurur.

**Birim haber kaynağı eşleşmesi (unitnews, V1050):** 23 `unit_source` kaynağının 23'ü de haritadaki web adresleriyle konak adına göre eşleşir (10 fakülte, 5 enstitü, 7 MYO, YDYO). Eşleşmeyen web adresleri (birim haber kaynağı değil): `kutuphane`, `bumlab`, `sks` (Merkezi Kafeterya, Konuk Evi), `ilicalar`, `hayvanhastanesi`, `pikom` (2 kayıt), `ariurunleritanitimofisi`, `tto`, `www.bingol.edu.tr` (Rektörlük, İdari Birimler, Aile Sağlığı Merkezi). Diş Hekimliği Fakültesi Hastanesi `dis.bingol.edu.tr` taşıyor ama kategorisi `health` olduğundan fakülteyle eşleştirilmez. Eşleşme kayıtlı değildir, **okuma anında** hesaplanır; yeni bir `unit_source` eklenince ek iş gerekmez.

Tohum idempotenttir: yerler `source_ref` benzersiz indeksiyle `ON CONFLICT DO NOTHING`, kampüs sınırı yalnız `boundary_json = '[]'` iken yazılır; yöneticinin sonraki düzenlemeleri ezilmez. Üniversite haritası değişirse tohum yeniden çalıştırılmaz; yönetici panelinden güncellenir. Kaynak siteye (harita dâhil) ek istek atılmaz.

## 4. Karo (harita altlığı) politikası notu

Varsayılan karo sunucusu `https://tile.openstreetmap.org/{z}/{x}/{y}.png` OSM Vakfı'nın **gönüllü işlettiği** ortak sunucudur ve [Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/) **yoğun/ticari kullanımı, toplu indirmeyi ve açık bir `User-Agent`/atıf olmayan kullanımı yasaklar** (hizmet haber vermeden kesilebilir). Üretimde kampüs uygulaması binlerce kullanıcıya ulaşacağından:

1. Mobil istemci `userAgentHint` ile açık bir `User-Agent` göndermeli, karoları cihazda önbelleklemeli, `bounds` dışına ve `zoom.max` üstüne karo istememeli.
2. Gerçek yük başladığında karo adresi **yönetici panelinden** (`PUT /api/admin/campus/config`, `tiles.urlTemplate`) bir ticari sağlayıcıya (ör. MapTiler, Stadia, Thunderforest: anahtar URL'de olur) ya da kendi barındırdığımız karo sunucusuna çevrilmelidir; sunucu değişikliği uygulama güncellemesi gerektirmez.
3. Sağlayıcı anahtarı URL'de geçiyorsa bu adres istemciye gider (gizli değildir); sağlayıcıda alan adı/uygulama kısıtı tanımlayın. Sırlar koda yazılmaz.
4. Atıf sağlayıcının şartına göre güncellenmelidir (`tiles.attribution`; OSM verisi için "© OpenStreetMap katkıda bulunanları" her zaman kalır).

## 5. Yönetici kılavuzu

1. **Yer ekleme/düzenleme:** panelde Kampüs Haritası → Yerler. Konum haritadan seçilir (enlem/boylam 6 ondalık yeterli). `category` listesi sabittir; yeni kategori kod değişikliği ister.
2. **Birimler** (`units`) aramada da bulunur ("Bilgisayar Mühendisliği" yazınca bulunduğu bina çıkar); yürüme süresi/mesafe istemcide hesaplanır.
3. **Fotoğraf** ayrı uçtan yüklenir (JPEG/PNG; sunucuda yeniden kodlanır, EXIF silinir).
4. **Gizleme/silme:** `active=false` yeri gizler (geri alınır); silme gerekçelidir ve geri alınamaz (kayıt denetim için durur).
5. **Kampüs sınırı:** `PUT /config` içinde `boundary` değiştirilir; sınır kutusu boş bırakılırsa otomatik hesaplanır. Sınır veya karo değişince `version` artar, istemciler en geç 5 dk içinde (HTTP önbelleği) yeni ayarı alır.
6. **Veri kaynağı yenileme:** OSM'den yeni bina gerekiyorsa tek seferlik, nazik bir okuma yapın (tek sorgu); kampüs web sitesine istek atılmaz.

## 6. Doğrulama

- Birim/entegrasyon: `CampusTextTest`, `CampusMapMvcTest` (H2). RBAC kapsamı `RbacCoverageTest`, çeviri bütünlüğü `I18nMessagesIntegrityTest`, sorgu kuralları `QueryRulesTest`.
- Duman (PostgreSQL gerçek `LIKE ... ESCAPE` ve tohum): `BASE=http://localhost:8080 ADMIN_PASSWORD=... ./scripts/smoke-campus.sh`.

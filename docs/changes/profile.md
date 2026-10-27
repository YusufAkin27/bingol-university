# profile modulu: API degisiklikleri

Tum degisiklikler geriye uyumludur (yalnizca ekleme).

## GET /api/search (giris gerekli)
Yeni parametreler: `type`, `cursor`, `limit`.

- `type` yok: onceki gruplu ozet (`limit` 1-20, varsayilan 5). `nextCursor` her zaman `null`.
- `type` var: tek tur sayfali liste (`limit` 1-50, varsayilan 5). Devam icin yanittaki `nextCursor` degeri `cursor` olarak gonderilir.
  `cursor` atlanacak sonuc sayisidir (0-1000); disindaki deger 400 `VALIDATION_ERROR`.

```
GET /api/search?q=kampus&type=NEWS&limit=20
{ "q":"kampus", "groups":[{"type":"NEWS","items":[ ... ]}], "nextCursor": 20 }
GET /api/search?q=kampus&type=NEWS&limit=20&cursor=20   // son sayfada nextCursor = null
```
Hata kodlari: 400 `VALIDATION_ERROR` (kisa sorgu / gecersiz imlec), 429 `RATE_LIMITED` (60/dk).

## GET /api/users/search (giris gerekli)
`?q=&size=&cursor=` — yanit `{ "items":[PublicProfile...], "nextCursor": 20|null }`.

- `q` en az 2 karakter (400 `QUERY_TOO_SHORT`), `size` 1-20, `cursor` 0-200 (400 `VALIDATION_ERROR`).
- Siralama (ad, id) deterministik. Kendisi, engel iliskisi olanlar, askidaki/silinmis hesaplar donmez.
- Alanlar profil gizlilik ayarina gore dolar; e-posta yalnizca `showEmail=true` ise.
- Limitler: dakikada 60 istek ve gunluk 500 istek/kullanici (429 `RATE_LIMITED`).

## GET /api/me/summary (yeni, giris gerekli)
```
{ "communities": 3, "events": 1, "bookmarks": 12, "unreadNotifications": 4, "unreadMessages": 7 }
```
- `communities`: aktif uyelik sayisi; `events`: katilacagim (GOING) ve bitmemis etkinlikler;
  `bookmarks`: kayitli haberler; `unreadNotifications`, `unreadMessages`: okunmamis toplamlari.
- Rate limit: dakikada 120.

## GET /api/users/{id}
Kendi id'niz icin `email` alani `showEmail` ayarindan bagimsiz doner.

## Hesap silme (DELETE /api/users/me, yonetici silmesi)
Anonimlestirmeye ek olarak: cihazlar (FCM token), bildirim kutusu, bildirim tercihleri (genel + alt tur),
kayitli haberler, kulup basvuru yanitlari ve topluluk uyelikleri (sahip ve BANNED kayitlari haric) silinir;
sohbet odalarindan cikis yapilir (mesaj gecmisi baskalarina ait oldugundan korunur).

## POST /api/users/me/avatar
Degisiklik yok. Medya hatti (`MediaService`) zaten tur/boyut dogrulamasi, yeniden kodlama (EXIF temizligi),
sunucuda uretilen icerik-ozeti dosya adi ve saatte 10 yukleme limiti uygular.

## Migration
`V160__profile_search_perf.sql`: `prf160_news_title_trgm` (haber basligi ILIKE icin pg_trgm GIN),
`prf160_notification_unread` (okunmamis bildirim sayimi icin kismi indeks). Yeni extension gerekmez.
Kullanici adi aramasi mevcut `idx_perf_user_name_trgm` indeksini kullanir (sorgu `ILIKE`'a cevrildi).

## Akademik katalog ve sinif (V200)
`catalog` paketi: `GET /api/catalog/academic` (tum katalog, ETag + 1 gun onbellek) ve `GET /api/catalog/departments?q=&limit=` (bolum arama, en cok 30). Kaynak: `resources/catalog/academic.json`.
`app_user.grade` (V200, VARCHAR 8: PREP, 1..6, MASTER, PHD). `ProfileView` ve `PATCH /api/users/me` `grade` icerir; `faculty`/`department`/`grade` yazilirken katalogla dogrulanir (400 `ACADEMIC_INVALID`), bos metin temizler. Mevcut serbest metin degerlere dokunulmaz. `POST /api/auth/register` ayni alanlari opsiyonel alir (bekleyen kayit `reg:<email>` icinde tasinir, hesap olusurken yazilir).

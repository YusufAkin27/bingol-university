# 13 - Haber listesi ve favori haberler

## Kapsam
- Envanter 41 `NewsListPage` (3 sekme, bakım/bayat, sayfalama), 43 `SavedNewsPage`

## Istem
```text
Design 6 separate mobile screens (no bottom nav on these pushed pages, header with back arrow).

1) News list, tab "Haber". Header "Haberler" with two icon buttons on the right: bookmark (favorites) and search. Segmented tab strip with icons: "Haber" (selected), "Duyuru", "Etkinlik". List of 5 news rows: 72px rounded thumbnail (or tinted newspaper icon tile when no image), small soft-red badge "Haber", 2-line title, date "26 Ekim 2026" and source "bingol.edu.tr", bookmark icon (one row filled/saved).

2) Same page, tab "Duyuru". Amber badge "Duyuru"; most rows have no image so show an amber tile with a megaphone icon. Example titles: "2026-2027 Güz Dönemi Ders Kayıt Duyurusu".

3) Same page, tab "Etkinlik". Green badge "Etkinlik" and date line "Etkinlik: 14 Kasım 2026" (event date instead of publish date), calendar icon tile for rows without image.

4) News list with maintenance and pagination. Amber band under the tabs: "Haber kaynağına şu an ulaşılamıyor. Son kaydedilen haberler gösteriliyor." Small grey label "Son güncelleme: 14:32". Last list item followed by a loading spinner row (loading more).

5) Favorite news ("Favori haberler"). Header with count "3 kayıtlı haber". Three rows with filled bookmark icons. Below, dashed hint card: bold "Daha fazla haberi kaydet", text "Haber detayındaki işaretle haberleri buraya ekleyebilirsin."

6) Empty and error variants. Top block: favorites empty state with bookmark illustration, text "Henüz kaydettiğiniz bir haber yok." Second block: category-empty text "Bu kategoride henüz içerik yok." Third block: error row "Yüklenemedi, tekrar dene" with button "Yeniden dene".
```

## Özellik kontrol listesi
- [ ] 3 sekme (Haber / Duyuru / Etkinlik) ve sekme simgeleri
- [ ] Satır: küçük görsel ya da tür simgeli karo, tür rozeti (renkli), başlık, tarih, kaynak
- [ ] Etkinlik sekmesinde "Etkinlik: tarih"
- [ ] Favori simgesi (kayıtlı/kayıtsız), üstte favoriler ve arama kısayolu
- [ ] Bakım bandı + son güncelleme etiketi
- [ ] Sayfalama (daha fazla yükleniyor)
- [ ] Favoriler: sayaç, ipucu kartı, boş durum
- [ ] Kategori boş ve hata + Yeniden dene

## Dikkat
- Haber kaynağı yalnız bingol.edu.tr; başka site/yorum/beğeni/paylaşım sayacı yok.
- Haberde yorum, beğeni, okunma sayısı gösterilmez.

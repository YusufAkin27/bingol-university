# 14 - Genel arama

## Kapsam
- Envanter 44 `SearchPage` (6 sekme, son aramalar, sonuç yok, hata, hız sınırı)

## Istem
```text
Design 6 separate mobile screens of the global search (no bottom nav). Top: back arrow, search field with clear "x" button, below a horizontal chip row in this order: "Tümü", "Haber", "Etkinlik", "Kulüp", "Kişi", "Gönderi".

1) Empty query. Focused search field with placeholder "Haber, kulüp, etkinlik, gönderi, kişi ara". Hint text "Haber, duyuru, kulüp, etkinlik veya kişi aramak için en az 2 karakter yazın." Section "SON ARAMALAR" with a text button "Temizle" and 4 recent-query rows with clock icon: "ders kayıt", "robotik", "yemek", "Elif".

2) "Tümü" results for "kulüp". Count label "14 SONUÇ". Grouped sections with small caps headers and a few rows each: "HABER", "DUYURU", "ETKİNLİK", "KULÜP", "KİŞİ", "GÖNDERİ". Row types: news row (thumbnail, title, date), club row (logo, name, "128 üye"), person row (avatar, name, department), post row (small photo, caption).

3) "Kulüp" tab results for "robot". Club cards: logo, "Robotik Kulübü", category chip, "86 üye", membership state pill "Üyesin" / "Katıl".

4) "Kişi" tab results for "elif". Person rows: avatar, "Elif Yıldız", "Bilgisayar Mühendisliği · 2. sınıf", chevron.

5) "Gönderi" tab results. Two-column photo grid of post cards with a heart count and short caption.

6) Feedback states. First block: skeleton rows while loading. Second block: no results card with search illustration "Sonuç bulunamadı." Third block: error row "Yüklenemedi" with "Yeniden dene". Fourth: warning toast "Çok fazla istek gönderildi, birkaç saniye bekleyin."
```

## Özellik kontrol listesi
- [ ] 6 sekme, doğru sıra: Tümü, Haber, Etkinlik, Kulüp, Kişi, Gönderi
- [ ] Boş sorgu: ipucu (en az 2 karakter), SON ARAMALAR + Temizle
- [ ] Gruplu "Tümü" sonuçları + "N SONUÇ" sayacı
- [ ] Sonuç satırı türleri: haber, duyuru, etkinlik, kulüp, kişi, gönderi
- [ ] Temizle (x) düğmesi
- [ ] İskelet / sonuç yok / hata / hız sınırı uyarısı

## Dikkat
- #etiket sekmesi, hikâye/yorum sonuçları, "Videolar" sekmesi yok.
- Kişi satırında e-posta gösterilmez (gizlilik); yalnız ad, bölüm, sınıf.

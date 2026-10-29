# RAPOR op4 (Stitch istemleri 40-45)

Stitch projesi: **BU Kampus Mobile D** - https://stitch.withgoogle.com/projects/9490781610355998080
Aktarma klasoru: `C:\bu_design\stitch\<NN>-<ad>\` (export.zip + x/ icinde HTML + screen.png; 40'ta ek olarak render.png).
Durum: 40-45 uretildi ve export edildi; 46-51 ve 45'in duzeltme turu **Stitch "Generation limited, check your credits" kotasi nedeniyle yapilamadi** (OPERATOR.md: DUR).

## 40 - Etkinlik olustur/duzenle (6 + 1 ekstra ekran, `C:\bu_design\stitch\40-etkinlik-olustur\`)
- Uretilen: form ust/alt, dogrulama, yetki/bos durum, kulup secici sheet, duzenle + kapak sheet; ekstra "Kulup Secici - Bos Durum" (istenen 5. istem metni).
- Duzeltilen: baslik "Student Petition Form" -> Turkce, uydurma "Adim 1/3", "Hizli Yayin", GMT+3, alt bilgi/v2.4, "450 Katilimci", "Canli Taslak", universite karti silindi; kapak sheet'i duzenle ekranina eklendi; kontenjan bos/ipucu; amber "Admin onayindan sonra" cipi; 1 fazladan tasarim-sistemi ekrani silindi.
- Halusinasyonlar: ekran basligi ingilizce, avatar/bilgi ikonu, "Zorunlu/Gerekli/Opsiyonel" etiketleri, universite adini duzenleyen gosterme.
- Kalan eksik: tuval goruntusunden denetlendi; "42/1000" sayaci aciklama metniyle birebir tutarli degil, kucuk ek etiketler ("Isteğe Bagli", 2/80 sayac) kaldi.

## 41 - Organizator ayar/istek (6 ekran, `...\41-etkinlik-organizator-ayar-istek\`)
- Uretilen: detay+⋯ menu, ayarlar, tehlikeli bolge+iptal diyalogu, istekler (kontenjan doldu / bekleyen / bos+hata).
- Duzeltilen: ingilizce basliklar (Event Overview/Edit Event/Participant Roster) Turkce; avatar, "ORGANIZATOR PANELI", "Canli Takip", SMS duyuru karti, universite etiketi kaldirildi; ⋯ menusu acik gosterildi.
- Kalan eksik: yalniz tuval goruntusunden denetlendi; 4. ekranda ust banner kesik gorunuyor, kucuk etiketler tek tek dogrulanmadi.

## 42 - QR yoklama + liste (5 ekran, `...\42-etkinlik-qr-yoklama-listesi\`)
- Uretilen: yoklama kodu (QR + geri sayim + K7M4QX), suresi doldu/hata, katilimci listesi, filtreli bos/hata/iskelet, elle isaretleme+toast.
- Duzeltilen: basliklar "Yoklama kodu" / "Katilimcilar ve yoklama"; "Ders Kodu BLM-302", "Baglanti Kesildi", %43, CANLI, SENKRONIZE, "Son islem" silindi.
- Kalan eksik: yalniz tuval goruntusunden denetlendi; kucuk ek metinler (ornegin "Ogrenci listesi") dogrulanmadi.

## 43 - Akademik hub + ders programi (6 ekran, `...\43-akademik-hub-ders-programi\`)
- Uretilen: hub (dolu/bos/bakim), haftalik program, bos durumlar, hata/uyari, donem sheet'i.
- Duzeltilen: basliklar "Akademik" / "Ders programi" (tum ekranlarda "Ders Detayi" idi); "Sistem Guncelleniyor", "Durum Gorunumleri", "Canli Onizleme", "Resmi donem" kirmizi etiket, kutuphane karti silindi.
- Kalan eksik: yalniz tuval goruntusunden denetlendi; kucuk etiketler ve avatar tek tek dogrulanmadi.

## 44 - Ders/sinav formlari (6 ekran, `...\44-akademik-ders-sinav-formlari\`)
- Uretilen: yeni ders formu, ders cakismasi diyalogu, sinavlar (Sinavlarim / Resmi program), yeni sinav formu, bos durumlar.
- Duzeltilen: avatar, "Donem Degerlendirme", "Sinav Takvimi Guncel mi?", Ogrenci Isleri metni, "Haftalik Program Uyarisi", Gerekli/Zorunlu etiketleri; cakisma ekrani basligi "Yeni ders".
- Kalan eksik: yalniz tuval goruntusunden denetlendi; ders cakismasi ekraninda ek kartlar var, kucuk etiketler dogrulanmadi.

## 45 - Akademik takvim/duyuru/hatirlatma (6 ekran, `...\45-akademik-takvim-duyuru-hatirlatma\`)
- Uretilen: ay gorunumu, bos/bakim, bolum duyurulari listesi, duyuru detayi, hatirlatma ayarlari, bildirim izni uyarisi.
- Duzeltme turu GONDERILEMEDI (kota). Acik kalan hatalar: bazi basliklar ("Akademik Takvim Durum", "Hatirlatma Ayarlari", "Bildirim Izni Uyarisi", "Duyuru Detayi" - brifte "Akademik takvim"/"Hatirlatmalar"/"Duyuru" olmali), kirmizi avatar, "Guncel Akis", "Cihaz Ici Bildirim", "Test Gonder", gorunum sayilari, begeni/paylasim ikonlari, "Ogrenci Isleri Daire Baskanligi" gorseli, "Resmi Fakulte Duyurusu".
- Sonraki operator icin: ayni 6 ekrani sec (shift+tikla), "Fix on ALL selected screens..." duzeltme istemini gonder (basliklari Turkce/dogru yap, avatar ve uydurma ogeleri kaldir).

## Genel notlar
- Tekrarlayan Stitch halusinasyonlari: Ingilizce/yanlis ekran basligi (ozellikle "X Detayi" kalibi), saga kirmizi profil avatari, "Universite adi" etiketleri, "Canli/Resmi/Aktif" gibi rozetler, "Gerekli/Zorunlu" mikro etiketleri, uydurma Adim X/Y, alt bilgi metinleri.
- Yontem: her istemin sonuna "Global rules" (ust cubuk = geri ok + Turkce baslik, avatar/bilgi yok, uydurma etiket yok) eklemek 41-45'te halusinasyonu azalttı ama tamamen onlemedi; her grup icin 1-2 duzeltme turu gerekti.
- Kota: 45 duzeltmesinden sonra "Generation limited" hatasi; 46-51 yapilamadi.

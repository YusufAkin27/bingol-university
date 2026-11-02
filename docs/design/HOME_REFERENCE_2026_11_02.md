# Yeni ana sayfa referansı — 2 Kasım 2026

Önceki HOME_2026_11.md üzerine kullanıcının gönderdiği yeni görsel uygulanır.

## Yapılanlar

- Mevcut BÜ logo görseli, uygulama adı, üç dilde alt açıklama; bildirim ve düzenleme eylemleri.
- Kısa selamlama, yerelleştirilmiş tarih, fonttan bağımsız el ikonu ve dekoratif vektör kampüs çizimi.
- Oval arama kutusu; filtre simgesi mevcut filtre seçeneklerini içeren arama ekranını açar.
- Dört sabit hedef: Ders Programı, Yemek Menüsü, Kütüphane, Kulüpler. Kütüphane https://kutuphane.bingol.edu.tr/ adresini dış tarayıcıda açar. Kulüpler mevcut sekme kimliğini (3) korur.
- Bugün kampüste kartında ders/yemek/sınav satırları; Tümünü gör akademik merkeze gider.
- Varsayılan hızlı erişim: haberler, etkinlikler, anketler, program, Diğer. Eski kişisel kayıtlar değiştirilmez. Diğer menüsünde destek, bildirim, kaydedilen haberler ve ana sayfa düzenleme vardır.
- Ortadaki kırmızı + yeni gönderi oluşturur; bir sekme değildir. İptal mevcut sekmeyi korur; başarı Keşfet'e döner ve akışı yeniler. Art arda açma koruması vardır.
- Paylaşım varyantında alt bar: Ana Sayfa, Keşfet, +, Sohbet, Profil. Eski onPublish vermeyen bileşen çağrıları geriye uyumlu kalır.
- İstenen açık zemin #FAF6F3, eylem kırmızısı #C62A20. Kulüpler için açık/koyu lavanta belirteçleri ve AA kontrast testi.

Yeni paket eklenmedi: mevcut BuIcons, yerel Inter, animasyonlar, Navigator ve görsel önbelleği kullanılır. API ve backend sözleşmeleri değişmez.

## Doğrulama

Hedefli ana sayfa, kişisel düzen, alt navigasyon, geri davranışı ve palet testleri; açık/koyu/büyük yazı görüntüleri. Tüm mobil testlerin sonucu test-results/mobile-refresh-full-tests.log dosyasına yazılır (yerel, commitlenmez). Gerçek telefon ve mağaza yayını ayrı doğrulamadır.

Android sürümü: 2.0.8+20008. Kaynak: HOME_2026_11.md ve MOBILE_REFRESH_TRACKER.md.
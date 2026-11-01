# Site görsel kaynakları

Bu klasördeki `app-*.webp` dosyaları uygulamanın kendi ekran çıktılarıdır (600 px genişlik, WebP). Aşağıdaki not yalnızca fotoğraf içerenler içindir.

## app-discover.webp (Keşfet ekranı)

Ekran, uygulamanın gerçek Keşfet düzenidir (2 sütun masonry; başlık, arama + paylaş düğmeleri, Tümü/Popüler çipleri, kutuda yazar ve beğeni; `mobile/lib/features/discover`, tasarım `docs/design/STITCH_V3_KESFET2.md`). Ekran, `mobile/assets/fonts` içindeki Inter yazı tipi ve RENK-1 token'larıyla bir HTML sayfası olarak kurulup Playwright ile 390x844 @2x ekran görüntüsü alınarak 600x1298 WebP'ye çevrilmiştir. Gönderi yazar adları kişi değildir (kulüp/etiket adı).

Kutulardaki manzara fotoğrafları Stitch (Google) tasarım çıktılarından alınmıştır: Keşfet tasarım çalışmasının kendi görselleri (`C:\bu_design\stitch\v3_kesfet2\_render\img\`, kaynak adresleri aynı klasördeki `urls.txt`). Bunlar Stitch'in yapay zekâyla ürettiği tasarım içeriğidir; üçüncü taraf fotoğrafçıya ait stok fotoğraf değildir, projenin kendi tasarım varlığıdır. Ham fotoğraf dosyaları depoya ALINMAZ; yalnızca ekran görüntüsünün içinde (küçültülmüş) bulunur.

| Fotoğraf (Stitch dosyası) | Konu | Kaynak | Lisans |
|---|---|---|---|
| p34 | Bahar çiçekli kampüs yolu | Stitch v3 kesfet2 çıktısı | Proje tasarım varlığı (Stitch çıktısı) |
| p42 | Sonbahar dağ ve göl yansıması | Stitch v3 kesfet2 çıktısı | aynı |
| p62 | Sonbahar kampüs kütüphanesi | Stitch v3 kesfet2 çıktısı | aynı |
| p07 | Gölet kenarı yürüyüş yolu | Stitch v3 kesfet2 çıktısı | aynı |
| p45 | Gün batımında kampüs binası ve havuz | Stitch v3 kesfet2 çıktısı | aynı |
| p41 | Orman, göl ve dağ manzarası | Stitch v3 kesfet2 çıktısı | aynı |
| p28 | Göl kenarı yürüyüş yolu | Stitch v3 kesfet2 çıktısı | aynı |
| p06 | Dağ ve sis manzaralı teras | Stitch v3 kesfet2 çıktısı | aynı |

Yeniden üretim: komut dizisi depoda tutulmaz (tek seferlik); gerekirse yukarıdaki fotoğraflar ve `mobile/design/P-Discover.dc.html` token'larıyla aynı düzen yeniden kurulabilir.

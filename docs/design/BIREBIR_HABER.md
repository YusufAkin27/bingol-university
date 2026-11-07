# BIREBIR_HABER: Haber + Arama Stitch v3 birebir uygulaması (NEWS)

Kaynak (kanun): `C:\bu_design\stitch\v3_home\4_haber\16-21_*.png`, `5_arama\22-26_*.png`; ölçü: `_kaynak_html\D_haber`, `_kaynak_html\E_arama\*_2`; şartname: `v3_home\SARTNAME.md` bölüm 4 ve 5.
Hedef: `mobile/lib/features/news/**` (liste, satır, detay, `icerik_parts`), `mobile/lib/features/search/**`, favoriler sayfası `features/profile/saved_news_page.dart` (kategori listesinde "favoriler" var; aynı bileşenleri kullanır).
Yöntem: 390 dp çerçeve; Flutter ekran görüntüsü `test/redesign/p05_shots_test.dart` (390x844, dpr 2, sahte veri) ile üretilir, referansla yan yana `C:\bu_qa\shots\tasarim\p3\news\birebir\yan_yana\NN_*.png` (sol referans, sağ uygulama). Karşılaştırmada uygulama görüntüsündeki 28 dp durum çubuğu payı (test görünümü) düşülmüştür. İçerik (başlık, görsel) farklı olduğundan yalnız düzen ölçüleri kıyaslanır.
Renkler yalnız `context.bu` (yeni renk yok); koyu tema aynı jetonlardan (RENK-1 koyu sütunu) türer. Önceki tur (P3-NEWS minimal) kararlarından şartnameyle çelişenler geri alındı: satır başına kaynak adı, büyük harf bölüm başlıkları, "N sonuç", "Tümünü gör (n)" (tek sonuçta bile), kulüp "Katıl/Üyesin" hapı, tür etiketi, "İçeriğin tamamı..." notu.

## Haber listesi (16, 17)

| Öğe | Referans dp | Uygulama dp | Fark / not |
|---|---|---|---|
| Başlık satırı: geri 40 + "Haberler" 28/700 + ara/favori daireleri 40 | üst 16, yan 20, daire 40, ikon 20 | aynı (dokunma kutusu 48, görünür 40) | 0; geri düğmesi yalnız itişle açıldığında (`canPop`) |
| Daire düğme gölgesi | shadow-sm (çok hafif) | siyah %6, blur 3, y 1 | ince fark, çerçeve yok |
| Sekme şeridi | metin sekme, aralık 24, seçili koyu + 2 dp marka çizgisi, altta 1 dp çizgi; çizgi y 104, metin merkezi y 86 | aralık 24, çizgi y 106, metin merkezi y 84 | +2 / -2 (dokunma hedefi 44 dp; 48 kuralı için referanstan 4 dp yüksek) |
| Kapsül segment | yok | kaldırıldı | 0 |
| Satır: görsel 72x72, köşe 12; görselsizde görsel yok | ilk görsel üstü çizgiden 33 | 32 | -1 |
| Satır aralığı (görselli) | 105 (16+72+16+1) | 105 | 0 (testle doğrulanır, `p63`) |
| Başlık | 16/600, en çok 2 satır, satır yüksekliği 1.375 | aynı | 0 (test yazı tipinde 600 ağırlık daha ince görünür) |
| Meta | 13 muted, tek satır "21 Ekim 2026 · bingol.edu.tr"; sığmazsa kaynak adı düşer | aynı (`_MetaLine`, TextPainter ölçümü) | 0 |
| Yer imi | ikon 20, merkez sağ kenardan 28 (36 dp düğme); kayıtlı = marka dolu, değil = ink çizgi | ikon 20, merkez sağdan 18+20 kenar = 28; dokunma 48 | 0 |
| Satır arası çizgi | 1 dp `bd` | `NewsRowDivider` 1 dp `bd` | 0 |
| Bakım bandı | `warnSoft`, 12 köşe, iç 14, ikon 20, metin 13/500, "Son güncelleme: 14:32" 12 | aynı (`IcerikNotice`; saat `GET /status` `lastSuccessAt`, bugünse HH:mm) | 0 |
| Sayfalama | spinner 16 + "Yükleniyor" 13 muted | aynı | 0 (metin "Yükleniyor") |
| Boş / hata | muted tek cümle 16; hata: "Yüklenemedi, tekrar dene" + marka "Yeniden dene" metin düğmesi, simge/illüstrasyon yok | aynı | 0 |

## Favoriler (20, 21)

| Öğe | Referans dp | Uygulama dp | Fark / not |
|---|---|---|---|
| Geri düğmesi üstü | 28 | 28 | 0 |
| Başlık "Favori haberler" 28/700, "3 kayıtlı haber" 14 muted | başlık merkezi y 101, sayı y 134 | y 101, y 132 | 0 / -2 |
| Satırlar | liste ile aynı, kayıtlı yer imi dolu | `NewsTile` (aynı), 1 dp çizgi | 0 |
| "Çevrimdışı erişilebilir", "Temizle" | şartname: uygulanmaz | yok | UYARILAR |
| Boş | "Henüz kaydettiğiniz bir haber yok." 16 + 14 ipucu "Haber detayındaki işaretle haberleri buraya ekleyebilirsiniz." | aynı, illüstrasyon/eylem yok | 0 |

## Haber detayı (18, 19)

| Öğe | Referans dp | Uygulama dp | Fark / not |
|---|---|---|---|
| Kapak | tam genişlik, yükseklik 240 (durum çubuğu dahil), köşe 0 | 240 (`expandedHeight = 240 - üst boşluk`), paralaks/uzatma korunur | 0 (testle) |
| Kapak düğmeleri | 40 daire, üst 16+güvenli alan, yan 20, %88 beyaz; kayıtlı yer imi marka rengi | aynı (`toolbarHeight 72`), düğme kutusu 48 | 0 |
| Tür etiketi | "HABER" 12/600 muted büyük harf, harf aralığı .6 (Arapçada 0) | aynı | 0 |
| Başlık | 26/700, satır 1.25 | aynı; etiket-başlık aralığı 8 | 0 |
| Tarih satırı | 13 muted "26 Ekim 2026 · bingol.edu.tr" | aynı | 0 |
| Gövde | 16, satır aralığı 24 (1.5), paragraf arası 16 | 16 / 1.5 / 16 | 0 (PNG'den ölçüldü: şartname 1.6 yazıyor, görüntü 24 dp adım gösteriyor) |
| Not | 13 muted "İçeriğin tamamı için kaynak sayfayı açın." | aynı, gövdeden 32 sonra | 0 |
| "Kaynak sayfada aç" | 48 yük, 16 köşe, beyaz yüzey, ink metin 14/600 | aynı + 1 dp `bdStrong` çerçeve (şartname) | PNG çerçevesiz, şartname çerçeveli: şartname izlendi |
| Kapaksız / etkinlik (19) | üstte geri solda, yer imi + paylaş sağda daire 40; kart/nokta/takvim ikonu yok; "Etkinlik tarihi: 14 Kasım 2026"; "Bağlantı açılamadı." danger 13 (ikon yok) | aynı; etkinlik etiketi "ETKİNLİK" | PNG 19'daki kart, serif yazı, nokta, takvim ikonu ve "Ücretsiz..." içerikleri UYGULANMAZ |
| Gövde genişliği | 20 yan | 20 yan, geniş ekranda en çok 640 dp (okunabilirlik) | geniş ekran eki |
| Hata | soluk cümle + marka "Yeniden dene" | aynı | 0 |

## Arama (22-26)

Not: arama PNG'leri 706 px (1.81x); sayfa kenarı 16 dp'dir (haber ekranları 20 dp).

| Öğe | Referans dp | Uygulama dp | Fark / not |
|---|---|---|---|
| Üst satır | geri daire 40 (sol 16), alan 48 (üst 12, sağ 16), aralık ~6, alan köşe 16, odakta 1,5 dp marka çerçeve, sağda 24 dp temizle | aynı (`_SearchBox`) | 0 |
| Çipler | yükseklik 28, yatay iç 14, aralık 8, yazı 13, seçili `soft`+marka, diğerleri beyaz çerçevesiz; ilk çip üstü 76 | aynı; dokunma kutusu 48 | 0 |
| İpucu | 13 muted, 2 satır | 13, 1.5 | 0 |
| "Son aramalar" 17/600 + "Temizle" 13/500 marka | y 207 | y 205 | -2 |
| Son arama satırı | 56 yük, alt 1 dp çizgi, saat 18 + 12 + metin 15, sağ x 16 (merkez sağdan 34) | aynı | 0 |
| "6 sonuç" | 13 muted, y 129,5 | y 131 | +1,5 |
| Bölümler | divide-y; başlık 13/600 muted büyük harf, sağda "Tümünü gör (n)" 13 marka; başlık merkezi çizgiden 22 | başlık satırı 48 dp (dokunma), satırlar 8 yukarı alınır | başlık merkezi 24 (+2) |
| Haber satırı | görsel 64x56 köşe 8, başlık 16 (2 satır), tarih 12-13 muted | aynı; vurgu marka + 600 | 0 |
| Duyuru satırı | şartname: simge karosu yok, metin + tarih | aynı | PNG'deki 32 dp megafon dairesi uygulanmaz |
| Etkinlik satırı | 48 kutu (çerçeve, KAS 11,5/700 marka, gün 20/600), başlık, muted kulüp, sağda chevron | aynı | 0 |
| Kulüp satırı | 44 daire kısaltma ("KFK"), ad, "48 üye", sağda hap (Katıl = `soft`+marka; Üyesin = çerçeveli, tik) | aynı (hap yalnız `myStatus` varsa; sunucu göndermiyorsa gizli) | veri sınırı: `myStatus` zorunlu değil |
| Kişi satırı | 44 daire baş harf, ad, "bölüm · N. sınıf", chevron; e-posta yok | aynı | 0 |
| Gönderi satırı | 56 kare foto, altyazı, kalp 16 + sayı, chevron; yorum yok | aynı | 0 |
| Sonuç yok | ortada "Sonuç bulunamadı." 16/600 + "Farklı bir kelime deneyin." 14 muted | aynı | 0 |
| Hata + hız sınırı | "Yüklenemedi" 15 muted solda, sağda yenile simgeli marka "Yeniden dene"; 429'da `warnSoft` bant + 3 satır iskelet | aynı (`_errorBlock`) | satır merkezi çiplerden 20 dp (48 dp hedef çip kutusunun boş alt bölgesine taşar) |

## Doğrulama
- Yan yana görüntüler: `C:\bu_qa\shots\tasarim\p3\news\birebir\yan_yana\` (16-26), tek tek `birebir\*_tr.png`, koyu `*_koyu_tr.png`, 320 dp x1.3 `*_x1.3_tr.png`, Arapça `*_ar.png` (test ortamında Arapça yazı tipi yok: harfler kutu görünür, yalnız RTL yerleşim geçerli).
- Testler: `mobile/test/p63_news_search_test.dart` (ölçü testleri: görsel 72, satır adımı 105, çizgi 1 dp, kapak 240, başlık 26, gövde 16/1.5, kaynak düğmesi 48x350, alan 48; durumlar; 429; 320 dp x1.3 açık/koyu/RTL taşma), `icerik_test.dart` (güncel metinler).
- Gerçek cihazda/emülatörde ölçülmedi (emülatör kilidi alınmadı); ekran görüntüleri sahte veriyle.

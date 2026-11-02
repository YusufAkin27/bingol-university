# İçerik ekranları tasarım yenilemesi

Referans: HOME_REFERENCE_2026_11_02.md. API, rota, oturum ve gönderim davranışları değiştirilmedi; yeni paket ve çeviri anahtarı eklenmedi.

| Sayfa | Uygulanan / korunan tasarım |
|---|---|
| NewsListPage | Yuvarlatılmış beyaz haber kartları, 14 dp iç boşluk, fotoğraf yoksa bilgi tonlu ikon; gereksiz satır ayraçları kaldırıldı. |
| NewsDetailPage | Mevcut 26 sp başlık, 16 sp/1.5 satır aralıklı seçilebilir metin, kapak/Hero ve kaynak düğmesi zaten uyumlu: incelendi ve korundu. İçerik ailesindeki alt sayfa başlıkları ortak responsive BuHeader'a bağlandı. |
| MenuPage | 22 dp köşeli hafif gölgeli öğle yemeği kartı; yeşil ikon karosu ve vurgulu toplam enerji kutusu. Tarih seçimi, fotoğrafın isteğe bağlı olması ve eksik kalori anlamı korunur. |
| NotificationsPage | Okunmamışta marka çerçeveli, okunduğunda nötr beyaz kart; tonal bildirim ikonu. Okunmamış nokta animasyonu, semantik, kaydırarak silme ve filtreler korunur. |
| PushHelpPage | Ana sayfayla tutarlı 20 dp yatay boşluk, durum renkli ikon karoları. Ölçülen izin/cihaz/kanal bilgileri ve ayarlara gitme davranışı korunur. |
| SearchPage | Oval odak çerçeveli arama alanı; kategori sonuçları beyaz, yuvarlatılmış kartlar. Arama vurgusu, geçmiş, kategori sayfalaması ve hedef rotalar korunur. |

## Doğrulama

- `dart analyze lib/features/news lib/features/menu lib/features/notifications lib/features/search`: temiz.
- `icerik_test`, `p63_news_search_test`, `menu_photo_test`, `notif_design_test`, `push_notify_test`, `push_help_test`: toplam 151 test geçti.
- Haber/arama/menü/bildirimler için açık-koyu ve büyük yazı görüntüleri: 36 mevcut sahne kontrolü geçti. Son haber/arama ve yeni push yardım sahneleri: 16 kontrol geçti.
- Yeni `content_push_help_shots_test.dart`: iyi/sorunlu cihazın açık/koyu görüntüsü; yalnız `CONTENT_SHOTS_OUT` verildiğinde çalışır.
- Temsili haber, arama, menü, bildirim ve push yardım çıktıları gözle incelendi. Görseller test verileri kullanır; fiziksel cihaz/gerçek FCM teslimi bu paketin kapsamında değildir.

Yerel kanıt dizinleri (commitlenmez): `C:/bu_refresh_content/shots/content-final`, `shots/menu-notifications`, `shots/push-help`. Haber detayı kapaklı/kapaksız ve aramanın boş/sonuç varyantları aynı sahne paketindedir. 320 dp, 1.3x yazı ve RTL taşma kontrolleri hedefli davranış testlerinde çalışır.
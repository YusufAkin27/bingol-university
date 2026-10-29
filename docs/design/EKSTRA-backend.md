# EKSTRA - Tasarımın gösterdiği, kodda bulunan/bulunmayan özellikler

Kaynak: 2026-10-29 çalışma ağacı (`mobile/lib`, `backend/src/main`). Amaç: Stitch tasarımı bir özelliği gösterdiğinde, mobilde ve backend'de ne olduğunu hızlıca görmek. "Mobil: yeni" = tasarım bunu gösteriyor ama uygulamada ekranı/kodu yok (sonradan geliştirilecek).

## A. Tasarımın gösterdiği, kodda eksik veya yeni olanlar

| Özellik (istem) | Mobil | Backend | Not |
|---|---|---|---|
| Yemek satırında kcal + toplam kcal (15) | YOK (menü ve ana sayfa kodunda `kcal` geçmiyor) | VAR: `MenuResponse.dishes[{name,kcal}]`, `totalKcal`, `kcalComplete`; yönetici girişi `PUT /api/admin/menu/{date}/calories` (V870, `MenuCalorieService`) | Tek iş mobil gösterim. `kcalComplete=false` ise "En az N kcal" yazılır. `GET /api/menu` yanıtında alanlar zaten dönüyor; `docs/MOBILE_API_GUIDE.md` bu alanları anlatmıyor, güncellenmeli. |
| Fotoğraf kırpma: profil 1:1, gönderi 4:5, kulüp logosu 1:1, kapak 16:9, sohbet serbest/orijinal (09) | YENİ. `mobile/pubspec.yaml` ve `lib` içinde kırpma kütüphanesi/ekranı yok; seçim `image_picker` + `ImageService` (en çok 1600 px genişlik, kalite) ile yapılıyor | GEREKMİYOR. `MediaService`/`ImageProcessor` yüklenen görseli yeniden kodluyor (EXIF yönü uygulanır, uzun kenar sınırı: avatar 512, kapak ve gönderi 1600 px, yükleme üst sınırı avatar 2 MB, kapak 3 MB), en-boy oranını zorlamıyor, kırpmıyor | Kırpma istemcide yapılır, sunucuya kırpılmış dosya gider. İsteğe bağlı sunucu tarafı doğrulama (ör. gönderi 4:5) yok; gerekirse `ImageProcessor` içine eklenebilir ama şart değil. Mevcut gönderi/kapak akışları oran varsaymıyor, kırpma sonrası görünüm düzenleri (4:5 kart, 16:9 kapak) mobilde ayrıca doğrulanmalı. |
| Kulüp logosu yükleme (09 ekran 3, 27 ekran 5) | YOK: logo yalnız gösteriliyor (`logoUrl`); `club_form_page.dart` içinde logo seçimi yok | VAR: `POST /api/communities/{id}/logo` (multipart `file`) ve `DELETE .../logo`, kullanıcı başına saatte 10 (`ClubExtrasController`, `CommunityService.setLogo`) | Mobil form + kırpma eklenecek. Kulüp oluşturma sırasında logo için önce kulüp yaratılıp sonra logo yüklenir (id gerekir), kapakla aynı iki adımlı akış. |
| Sohbet görselinde kırpma/döndürme düzenleyicisi (09 ekran 5, 25) | YENİ. Önizleme ekranında yalnız açıklama ve "Tek gönderimlik" var | Gerekmez (`ImageKind.CHAT` yeniden kodlar) | "Orijinal" varsayılan; kırpma isteğe bağlı. |
| Fotoğraf kırpma sonucu profil önizlemesi (daire 96 px + 40 px avatar) | YENİ | Gerekmez | Tamamen istemci. |
| Etkinlik oluştururken kapak 16:9 kırpma | Kapak yükleme VAR (galeri/kamera), kırpma YENİ | Kapak yükleme VAR (`COVER`, 1600 px) | |

## B. Tasarımın gösterdiği ve kodda zaten bulunanlar

| Özellik | Mobil | Backend |
|---|---|---|
| Beğeni animasyonu: kalp ölçek animasyonu, çevresinde nokta patlaması, sayaç artışı, titreşim, iyimser güncelleme + hata olursa geri alma (17) | VAR (`posts/like_button.dart`: `LikeButton`, `_BurstPainter`; 250 ms birleştirme) | `PUT/DELETE /api/posts/{id}/like` |
| Fotoğrafa çift dokunma = beğeni, ortada büyük beyaz kalp (17, 10) | VAR (`DoubleTapLike`, 88 px beyaz kalp, ölçek+solma 700 ms; `post_card.dart` kullanıyor; tek-gönderi sayfası ve profil ızgarası detayı aynı `PostCard`'ı kullanıyor) | aynı uç |
| Gönderi "düzenlendi" etiketi, kendi gönderi düzenle/sil, başkasına şikâyet/engelle | VAR (`post_actions.dart`, `Post.editedAt/canEdit/canDelete`) | `/api/admin/posts` yönetimi, gönderi PATCH/DELETE |
| Sohbet: yanıt önizleme, düzenlendi, herkes için silindi, yönetici kaldırdı, tepki çipleri, tek gösterimlik, video süresi, durum tikleri, gönderilemedi/yeniden gönder, çevrimdışı kuyruk, yazıyor göstergesi | VAR (`message_bubble.dart`, `message_actions.dart`, `chat_detail_page.dart`) | VAR |
| Etkinlik: istekli katılım, kontenjan, kayıt kapat/aç, iptal, QR + elle yoklama, organizatör araçları | VAR | VAR |
| Anket türleri SINGLE/MULTI/RATING/RANKED, gizli oy, sonuç görünürlüğü | VAR | VAR |

## C. Tasarım BİLEREK göstermiyor (kodda yok ya da kaldırıldı)

| Konu | Durum |
|---|---|
| Gönderi yorumu, hikâye, #etiket, @bahsetme, video gönderi, gönderi kaydetme | Kaldırıldı (V470; uçlar yok/404). Eski l10n anahtarları (`postView*`, `story*`) ARB'de duruyor ama ekranlarda kullanılmıyor; bildirim tercihleri sayfası sunucu yanıtında varsa `POST_LIKE`, `POST_COMMENT` vb. satırları çizebilir, tasarım bunları göstermez. |
| "Beğenenler" listesi | YOK: `GET /api/posts/{id}/likes` sade Keşfet sözleşmesiyle kaldırıldı (`PostLikeController` notu). Tasarım yalnız sayaç gösterir. |
| Sabitlenmiş (pinned) sohbet | YOK: ne mobilde ne `ConversationController`'da sabitleme var. Sohbet listesi tasarımı bunu göstermez. |
| Etkinlik sertifikası / yoklama sertifikası | Backend VAR (`CertificateService`, yönetici iptali), mobilde ekran YOK; tasarım göstermez. |
| Sesli mesaj, GIF, konum paylaşımı, arama/görüntülü görüşme | Hiçbir yerde yok. |
| Ödeme, bakiye, cüzdan, QR ile ödeme | Hiçbir yerde yok. |
| Hava durumu, e-Devlet, eduroam | Hiçbir yerde yok. |
| "Resmi" etiketi | Mobilde BAZI yerlerde var: `eventListOfficial` ("Resmi", haber kaynaklı etkinlik), `homeOfficialEvent` ("Resmi etkinlik"), Sınavlar'da "Resmi program" sekmesi, `akademik2OfficialTag`. Kullanıcı kuralı gereği tasarım marka alanında "Resmi" kullanmaz; yalnız "Resmi program" (sınav) sekme adı 44. istemde korunmuştur. Sonradan karar verilmeli: kod etiketleri yeniden adlandırılacak mı. |
| Profil fotoğrafı / kapak için filtre, çıkartma, metin ekleme | Yok; kırpma ekranları yalnız kırp + döndür. |

## D. Küçük belirsizlikler (tasarım istemlerinde örnek olarak yazıldı)

- Hatırlatma ayarlarında dakika seçenekleri (10/15/30 dk, 1 saat) örnektir; gerçek seçenek kümesi `reminder_settings_page.dart` içindedir.
- Kulüp katılım sorusu üst sınırı 3 (`_maxQuestions`), anket seçenek sayısı 2-12; istemler bu değerlerle yazıldı.
- Kırpma ekranlarındaki yeni metinler ("Fotoğrafı kırp", "Döndür", "Sıfırla", "Kırp", "Akışta böyle görünecek", "Logo ekle") kodda yoktur; uygulanırken yeni l10n anahtarı (tr/en/ar) gerekir.

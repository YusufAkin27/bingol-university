# 40 - Etkinlik oluştur / düzenle

## Kapsam
- Envanter 75 `EventFormPage`, A38 kapak kaynağı, A39-A41 tarih/saat seçici, A43 kulüp seçici sheet'i; kapak 16:9 kırpma akışı `09-fotograf-kirpma.md`

## Istem
```text
Design 6 separate mobile screens (pushed page, header with back arrow, no bottom nav). An event is ALWAYS created on behalf of one club.

1) New event form, top. Header "Yeni etkinlik". Label "Kulüp" with a tappable field showing club logo and "Müzik Kulübü" and chevron. Info chip under it: "Admin onayından sonra yayınlanır." (for a member with permission) or "Hemen yayınlanır." (for club managers). Cover area "Kapak fotoğrafı ekle" (16:9). Field "Başlık" (hint "Etkinlik başlığı"). Multiline "Açıklama" (hint "Etkinlik hakkında kısaca") with counter "42/1000".

2) New event form, bottom. Section "Tarih" quick chips "Bugün | Yarın | Bu hafta sonu | Gelecek hafta | Tarih seç". Section "Başlangıç saati" chips with preset times plus "Özel saat". Section "Süre" chips "1 saat | 2 saat | Yarım gün | Bitiş tarihi seç". Field "Mekân" (hint "Örn. Konferans Salonu"). Field "Kontenjan" (hint "Boş bırakırsan sınırsız"). Segmented "Katılım": "Herkes katılabilir | İstek ile" with hint "İstek ile seçersen katılımcıları sen onaylarsın." Info card: "Etkinlik sohbeti otomatik açılır" with body "Katılanlar ve sen sohbete girersiniz. İstek ile katılımda yalnızca onaylananlar girer." Button "Etkinliği oluştur".

3) Validation states. Red helper texts: "Başlık en az 3 karakter olmalı.", "Önce bir kulüp seç.", "Başlangıç geçmişte olamaz.", "Bitiş, başlangıçtan sonra olmalı.", "Kontenjan 1 veya daha büyük bir sayı olmalı.", "Açıklama en fazla 1000 karakter olabilir.", amber note "Bitiş, başlangıçtan 1 saat sonrasına otomatik ayarlandı."

4) No club available. Illustration, title "Etkinlik oluşturmak için bir kulübün yöneticisi olmalısın", body "Etkinlikler kulüpler adına açılır. Bir kulübün yöneticisi olduğunda burada etkinlik oluşturabilirsin.", button "Kulüplere göz at". Server errors as banner: "Bu kulüp adına etkinlik oluşturma yetkin yok." and "Bu kulüp şu anda etkin değil."

5) Club picker bottom sheet. Title "Kulüp seç". List of clubs the user can organize for: logo, name, role tag ("Yönetici", "Moderatör"), selected check. Empty text "Etkinlik açabileceğin kulüp yok."

6) Edit event with cover options. Header "Etkinliği düzenle", cover filled with bottom sheet "Kapak fotoğrafı": "Galeriden seç", "Fotoğraf çek", "Kapağı kaldır" (red). Error toasts: "Kapak yüklenemedi.", "Etkinlik oluşturuldu, kapak yüklenemedi." with "Tekrar dene". Button "Kaydet".
```

## Özellik kontrol listesi
- [ ] Kulüp seçimi zorunlu (kulüp alanı + seçici sheet), yayın bilgisi (hemen / onay sonrası)
- [ ] Kapak ekle/değiştir/kaldır (kırpma akışı)
- [ ] Başlık, açıklama (sayaç), tarih çipleri, saat, süre çipleri, mekân, kontenjan, katılım türü, sohbet bilgi kartı
- [ ] Doğrulama hataları ve otomatik bitiş uyarısı
- [ ] Kulüp yöneticisi değilsen boş durum; yetki/etkin değil hataları
- [ ] Düzenleme modu (Kaydet), kapak yükleme hataları

## Dikkat
- "Kulüp adına değil / bireysel" seçeneği YOK. Kulüp zorunlu.
- Bilet fiyatı, ödeme, sponsor alanı yok.
- Konum seçici/harita alanı yok (yalnız metin mekân).

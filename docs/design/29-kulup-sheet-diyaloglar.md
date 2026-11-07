# 29 - Kulüp alt sayfaları ve diyaloglar

## Kapsam
- Envanter A26 kulüpten ayrılma, A27 sahip ayrılamaz, A28 kulüp silme (ad yazdırma), A29 kulüp gönderisi silme, A32 kulüp incelemede, A33 katılım soruları sheet'i; kulüp gönderisi işlemleri (Sabitle/Sil/Şikâyet)

## Istem
```text
Design 6 separate mobile screens, each an overlay on a dimmed Robotik Kulübü club page (no bottom nav).

1) Join request bottom sheet. Title "Katılma isteği", subtitle "Robotik Kulübü yöneticileri cevaplarını görecek." Two questions with text fields: "Neden katılmak istiyorsun?" (answer hint "Cevabın") and "Hangi bölümdesin?" with the second one in error "Bu soru zorunlu". Buttons "Vazgeç" and "İstek gönder".

2) Leave club dialog. Title "Kulüpten ayrıl", body "Robotik Kulübü kulübünden ayrılmak istiyor musun? Kulüp sohbetinden de çıkarılacaksın ve sohbet listenden silinecek.", buttons "Vazgeç", "Ayrıl" (red).

3) Owner cannot leave dialog. Title "Kulüpten ayrılamazsın", body "Kulüp sahibi ayrılamaz. Önce sahipliği devret ya da kulübü sil.", single button "Tamam".

4) Delete club final confirmation. Title "Kulübü sil", body "Üyeler, etkinlikler ve sohbet silinir. Bu işlem geri alınamaz.", instruction "Onaylamak için kulüp adını yaz: Robotik Kulübü", text field "Kulüp adı", buttons "Vazgeç" and red "Sil" (disabled until the name matches).

5) Club post actions. Gönderiler tab visible under a bottom sheet "Gönderi işlemleri" with rows "Sabitle" (or "Sabitlemeyi kaldır"), "Sil" (red), "Şikâyet et". Small toast text under: "Gönderi silindi".

6) Club pending-review dialog after creating a club. Check-clock illustration, title "Kulübün onaya gönderildi", body "Yöneticiler incelediğinde kulüp yayına girecek. Durumu Kulüplerim bölümünden izleyebilirsin.", button "Tamam".
```

## Özellik kontrol listesi
- [ ] Katılma isteği sheet: soru/cevap alanları, zorunlu soru hatası, İstek gönder
- [ ] Kulüpten ayrılma onayı
- [ ] Sahip ayrılamaz uyarısı
- [ ] Kulüp silme: ad yazdırma, pasif/aktif Sil
- [ ] Kulüp gönderisi işlemleri: Sabitle / Sabitlemeyi kaldır, Sil, Şikâyet et
- [ ] Kulüp onaya gönderildi diyaloğu

## Dikkat
- Silme diyaloğunda "Arşivle" alternatifi uydurmasın.
- Katılma isteği formu telefon, öğrenci belgesi yükleme istemez.

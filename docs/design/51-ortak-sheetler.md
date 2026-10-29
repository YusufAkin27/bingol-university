# 51 - Ortak alt sayfalar ve diyaloglar: şikâyet, çıkış, engelleme, tema

## Kapsam
- Envanter A5 `ReportSheet` (kullanıcı/gönderi/kulüp/etkinlik + mesaj), A51 çıkış onayı, A55/A57 tüm cihazlardan çıkış onayı, A60/A10 engelleme onayı, A52 tema seçenek sheet'i, A25 ortak sheet çerçevesi

## Istem
```text
Design 6 separate mobile screens, each an overlay on a dimmed app screen (no bottom nav). Sheets: 28px top radius, grab handle. Dialogs: centered, 28px radius, tonal buttons.

1) Report sheet for a user. Title "Kullanıcıyı şikâyet et", prompt "Sebep seçin. Şikâyetiniz yöneticilere iletilir." Radio rows "Spam veya reklam", "Taciz veya zorbalık", "Uygunsuz içerik", "Başkasını taklit", "Diğer" (Taciz veya zorbalık selected). Field "Ek açıklama (isteğe bağlı)". Button "Gönder".

2) Report sheet for a message plus success. Title "Mesajı şikâyet et", the quoted message in a small grey card, same reasons. After sending a success toast "Şikâyetiniz alındı. Teşekkürler."

3) Sign out dialog. Title "Çıkış yapılsın mı?", body "Bu cihazdaki oturumunuz kapatılacak.", buttons "Vazgeç" and "Çıkış yap" (red).

4) Sign out of all devices dialog. Title "Tüm cihazlardan çıkış", body "Hesabınız tüm cihazlarda kapatılacak ve yeniden giriş yapmanız gerekecek.", buttons "Vazgeç" and "Çıkış yap" (red).

5) Block user dialog. Title "Kullanıcı engellensin mi?", body "Engellediğiniz kişiyle mesajlaşamazsınız.", buttons "Vazgeç" and "Engelle" (red). Post variant body: "Engellediğiniz kişinin gönderilerini görmezsiniz ve onunla mesajlaşamazsınız." Toast "Kullanıcı engellendi".

6) Theme choice bottom sheet. Title "Tema". Radio rows with icons: "Sistem", "Açık", "Koyu" (Açık selected, check). Subtle preview swatches of light and dark cards beside the rows.
```

## Özellik kontrol listesi
- [ ] Şikâyet sheet'i (kullanıcı) ve mesaj varyantı, 5 neden, ek açıklama, Gönder, teşekkür bildirimi
- [ ] Çıkış onayı; tüm cihazlardan çıkış onayı
- [ ] Engelleme onayı (kullanıcı / gönderi metni), engellendi bildirimi
- [ ] Tema sheet'i (Sistem, Açık, Koyu)

## Dikkat
- Şikâyet nedenleri yalnız bu 5 madde.
- Tema seçeneklerinde "Otomatik/Gece" gibi ek adlar yok.

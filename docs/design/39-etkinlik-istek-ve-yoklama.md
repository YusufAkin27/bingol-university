# 39 - Etkinlik: katılma isteği ve katılımcı yoklaması (QR / kod)

## Kapsam
- Envanter 74 `EventDetailPage` (istekli katılım ve yoklama bölümleri), A37 katılma isteği formu, 19 QR okuma sonucu

## Istem
```text
Design 6 separate mobile screens of the event detail page for an event that requires organizer approval ("İstek ile katılım"). Same header/cover as the reference event page, no bottom nav.

1) Join request bottom sheet over the event page. Title "Katılma isteği gönder". Organizer questions: "Neden katılmak istiyorsun?" text field; optional note field labelled "Organizatöre not (isteğe bağlı)"; error "Tüm soruları yanıtlamalısın." Buttons "Vazgeç" and "Katılma isteği gönder". Hint "Organizatör onaylayınca etkinlik sohbetine girersin."

2) Request pending. Tag "İstek ile katılım". Amber card with hourglass: "İstek gönderildi" / "Yanıt bekleniyor", button "Geri çek". Locked chat row "Etkinlik sohbeti · Onaylanınca açılır". Withdraw dialog example: title "İsteği geri çek", body "Katılma isteğin geri çekilecek."

3) Request rejected. Red card: title "İsteğin reddedildi", body "Organizatör bu etkinlik için isteğini kabul etmedi." Button to try again "Katılma isteği gönder" disabled or text "Etkinliklere göz at".

4) Approved, attendance not open yet. Green pill "Onaylandı", chat row open. Attendance box with clock text "Yoklama etkinlik saatinde açılır." Info under capacity "Katılımı organizatör onaylar".

5) Attendance open. Box title "Yoklama" with primary button "QR kodu tara" (scan icon), secondary "Kodu elle gir". Tapped state: text "Organizatörün gösterdiği kodu gir", field "Yoklama kodu" (hint K7M4QX), button "Yoklamayı gönder".

6) Attendance result states. Green card with check: "Yoklaman alındı". Error examples in red under the field: "Bu kod başka bir etkinliğe ait.", "Bu bir yoklama kodu değil."
```

## Özellik kontrol listesi
- [ ] Katılma isteği sheet (organizatör soruları, isteğe bağlı not, zorunlu hata)
- [ ] Bekliyor: Yanıt bekleniyor + Geri çek + onay diyaloğu, kilitli sohbet satırı
- [ ] Reddedildi kartı
- [ ] Onaylandı; sohbet açık; yoklama saatten önce kilitli
- [ ] Yoklama açık: QR kodu tara, Kodu elle gir, Yoklamayı gönder
- [ ] Başarı ve hata sonuçları

## Dikkat
- QR yalnızca yoklama içindir; giriş bileti/ödeme QR'ı değildir.
- Yoklama sertifikası ekranı mobilde yok; sertifika, rozet, puan uydurmasın.
- İstek formunda dosya yükleme yok.

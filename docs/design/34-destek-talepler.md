# 34 - Destek: SSS, taleplerim, yeni talep ve talep konuşması

## Kapsam
- Envanter 67 `SupportPage`, 68 `NewTicketPage`, 69 `SupportTicketPage`, A35 talebi kapatma onayı

## Istem
```text
Design 6 separate mobile screens (no bottom nav, header with back arrow).

1) Support home. Header "Destek". Section "SIK SORULAN SORULAR": search field "Sorunuzu arayın", category chips "Tümü | Hesap | Teknik | İçerik | Diğer", accordion list with one expanded item ("Şifremi unuttum, ne yapmalıyım?" with 2-line answer). Section "TALEPLERİM": ticket rows with subject, date and status pill ("Açık", "Yanıtlandı", "Kapalı"). Primary button "Destek talebi oluştur". Section "GÖRÜŞÜNÜZÜ PAYLAŞIN" with two rows "Geri bildirim" and "Öneri panosu".

2) Support home empty and error states. FAQ empty "Henüz sık sorulan soru yok." with filtered empty "Eşleşen soru bulunamadı."; tickets empty "Henüz destek talebiniz yok."; error row "Yüklenemedi" with "Yeniden dene"; amber note "Çok fazla istek gönderdiniz. Lütfen biraz bekleyip tekrar deneyin."

3) New ticket form. Header "Yeni talep". Label "KATEGORİ" with chips "Hesap | Teknik | İçerik | Diğer", label "KONU" field "Kısaca konu", label "MESAJ" multiline "Sorununuzu anlatın". Validation "Konu ve mesaj alanlarını doldurun." Button "Gönder" and success toast "Destek talebiniz alındı."

4) Ticket conversation, open. Header "Talep" with status pill "Açık" and menu with "Talebi kapat". Chat-style messages: my message (right, red) and staff reply (left, white, label "Destek ekibi", time). Composer "Yanıt yazın" with send button.

5) Ticket conversation, closed. Same thread, composer replaced by grey note "Bu talep kapatıldı." Status pill "Kapalı".

6) Close ticket dialog. Title "Talebi kapat", body "Bu talep kapatılacak ve yeni yanıt yazamayacaksınız. Devam edilsin mi?", buttons "Vazgeç" and "Kapat" (red).
```

## Özellik kontrol listesi
- [ ] SSS: arama, kategori çipleri, akordeon; boş / eşleşme yok
- [ ] Taleplerim listesi + durum hapları (Açık, Yanıtlandı, Kapalı), boş, hata, hız sınırı
- [ ] Destek talebi oluştur düğmesi; Geri bildirim ve Öneri panosu girişleri
- [ ] Yeni talep: kategori, konu, mesaj, doğrulama, Gönder
- [ ] Talep konuşması: kendi/destek ekibi mesajları, yanıt yazma, kapat menüsü
- [ ] Kapalı talep notu; kapatma onayı

## Dikkat
- Canlı destek hattı, telefon numarası, WhatsApp bağlantısı, dosya eki yok.
- Kategori adları yalnız Hesap, Teknik, İçerik, Diğer.

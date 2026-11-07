# 35 - Geri bildirim ve öneri panosu

## Kapsam
- Envanter 70 `FeedbackPage`, 71 `SuggestionsPage`

## Istem
```text
Design 5 separate mobile screens (no bottom nav, header with back arrow).

1) Feedback form. Header "Geri bildirim". Intro "Uygulamayı geliştirmemize yardım et. Önerini, karşılaştığın hatayı ya da düşüncelerini yaz." Label "Tür" with four chips "Hata | Öneri | Şikâyet | Teşekkür", field "Başlık" (hint "Kısaca özetle"), multiline "Mesaj" (hint "Ayrıntıları yaz") with counter "42 / 1000", button "Gönder".

2) Feedback submitted list. Top toast "Geri bildiriminiz için teşekkürler." Section "GÖNDERDİKLERİM": cards with type chip, title, date, status pill ("Yeni", "İnceleniyor", "Planlandı", "Tamamlandı", "Reddedildi"). Button "Daha fazla". Empty variant text: "Henüz geri bildirim göndermediniz."

3) Suggestions board. Header "Öneri panosu". Sort segmented control "En çok oy | En yeni". Cards: title, short text, status pill (e.g., "Planlandı"), vote button with up arrow and count "128" (voted state filled red, unvoted outlined). Button "Öneri ekle" at top right.

4) Suggestions empty and error. Illustration with text "Henüz yayımlanmış öneri yok. İlk öneriyi siz ekleyin." and button "Öneri ekle". Error row "Yüklenemedi, tekrar dene" with "Yeniden dene".

5) Suggestion voted detail state: a single suggestion card enlarged with a status pill, vote count "129" and my vote highlighted (filled red up-arrow), plus a small info line "Öneriler yönetici onayından sonra yayımlanır."
```

## Özellik kontrol listesi
- [ ] Geri bildirim formu: tür (4), başlık, mesaj, sayaç, Gönder
- [ ] Gönderdiklerim: tür çipi, durum hapları (5), Daha fazla, boş
- [ ] Öneri panosu: sıralama (En çok oy / En yeni), oy düğmesi (oylanmış/oylanmamış), Öneri ekle
- [ ] Boş / hata durumları
- [ ] "Öneriler yönetici onayından sonra yayımlanır." bilgisi

## Dikkat
- Öneriye yorum yazma alanı yok; yalnız oy.
- Oy veren kişi listesi yok.

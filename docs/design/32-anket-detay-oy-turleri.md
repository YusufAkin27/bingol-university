# 32 - Anket detayı: oy türleri

## Kapsam
- Envanter 66 `PollDetailPage` oy verme biçimleri (referans: standart görünüm), kulüp anket bölümü (58 içinde), oy değiştirme

## Istem
```text
Design 6 separate mobile screens of the poll detail page, voting mode (header "Anket" with back arrow, no bottom nav). Common top: poll title, small chips for scope and type, "Gizli oy" lock chip, time left "2 gün kaldı", note "Oyunuz gizlidir". Bottom: primary button "Oy ver".

1) Single choice ("Tek seçim"): four options as round radio rows with option text, one selected (soft-red tint and filled radio). Question: "Yeni dönem yemek menüsünde hangisi olsun?"

2) Multiple choice ("Çoklu seçim"): square checkbox rows, two selected. Hint "En fazla 2 seçenek işaretleyin." and a snackbar example "En fazla 2 seçenek işaretleyebilirsiniz."

3) Rating ("Puanlama"): large row of 5 stars with 4 filled, text under "4 yıldız", hint "Yıldıza dokunarak puanla".

4) Ranked choice ("Sıralı seçim"): option rows with rank number badges (1, 2, 3 on tapped ones, empty for the rest), hint "Tercih sırasına göre dokunun: ilk dokunduğunuz en çok tercih ettiğinizdir."

5) Club polls section inside the club page "Anketler" tab (with club header collapsed): poll cards list, manager button "Anket oluştur", empty text "Bu kulübün anketi yok.", link "Tüm anketleri gör".

6) Change vote mode. Poll already voted, user taps "Oyu değiştir": options editable with my previous choice preselected, button "Oyu güncelle", text button "Vazgeç". A green snackbar example: "Oyunuz kaydedildi."
```

## Özellik kontrol listesi
- [ ] SINGLE (radyo), MULTI (onay kutusu + en fazla N uyarısı), RATING (5 yıldız), RANKED (sıra rozetleri + ipucu)
- [ ] Gizli oy etiketi/notu
- [ ] Kalan süre, kapsam/tür çipleri
- [ ] Kulüp Anketler sekmesi (liste, Anket oluştur, boş, tümünü gör)
- [ ] Oyu değiştir / Oyu güncelle; "Oyunuz kaydedildi."

## Dikkat
- Anket seçeneklerinde görsel/video seçeneği yok; yalnız metin.
- 5'ten fazla yıldız, emoji tepki skalası yok.

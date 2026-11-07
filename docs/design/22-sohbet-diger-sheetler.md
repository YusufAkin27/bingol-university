# 22 - Sohbet: sessize alma, silme/ayrılma, üye ekleme, grup adı ve fotoğrafı

## Kapsam
- Envanter A11/A21 sessize alma, A12/A20 sohbeti sil / gruptan ayrıl onayı, A19 üye ekleme, A22 grup adı değiştirme, A23 grup fotoğrafı kaynağı, A13 video hazırlanıyor penceresi

## Istem
```text
Design 6 separate mobile screens, each a bottom sheet or dialog over a dimmed chat screen (no bottom nav).

1) Mute duration bottom sheet. Title "Bildirimleri sessize al" with chat name subtitle. Three radio rows: "8 saat", "1 hafta", "Her zaman". Button "Sessize al" and text "Vazgeç". Also show the unmute variant as a small row "Sesi aç".

2) Delete conversation dialog (direct chat version). Title "Sohbet silinsin mi?", body "Bu sohbet yalnızca senin için silinecek. Karşı taraf etkilenmez." Buttons "Vazgeç", "Sil" (red). At the bottom a snackbar example "Sohbet arşivlendi".

3) Leave group dialog. Title "Sohbetten ayrılınsın mı?", body "Bu sohbetten ayrılırsınız.", buttons "Vazgeç", "Ayrıl" (red).

4) Add members bottom sheet. Title "Üye ekle", search field "Ad veya e-posta ile ara", people list with circular checkboxes (2 selected), selected people as removable chips on top, hint "Gruba en çok 50 kişi eklenebilir.", sticky button "Ekle (2)".

5) Rename group dialog. Title "Grup adı", text field with "Kampüs Fotoğrafçıları", counter, error line "Grup adı girin." Buttons "Vazgeç" and "Kaydet".

6) Group photo source bottom sheet: title "Fotoğrafı değiştir", rows "Galeriden seç", "Fotoğraf çek", "Fotoğrafı kaldır" (red), error text "Yalnızca JPEG, PNG veya WebP görseller kullanılabilir."
```

## Özellik kontrol listesi
- [ ] Sessize alma süreleri: 8 saat / 1 hafta / Her zaman; Sesi aç
- [ ] Sohbeti sil onayı (birebir "yalnızca senin için"; grup "Gruptan çıkıp bu sohbeti sileceksin.")
- [ ] Gruptan ayrıl onayı
- [ ] Üye ekle sheet (arama, seçili çipler, 50 kişi sınırı, Ekle (N))
- [ ] Grup adı diyaloğu (hata)
- [ ] Grup fotoğrafı kaynağı + biçim hatası
- [ ] "Video hazırlanıyor… %45" iptal edilebilir penceresi: `25-sohbet-medya-secici.md` içinde

## Dikkat
- Sessize alma, "bildirimleri özelleştir", "ses seç" gibi seçenek içermez.
- Bu istemde 6. ekran yalnız grup fotoğrafı sheet'i; video hazırlama penceresi `25-sohbet-medya-secici.md` içindedir.

# 41 - Etkinlik organizatör: yönetim, ayarlar ve katılım istekleri

## Kapsam
- Envanter 74 (organizatör bölümü), 76 `Etkinlik2SettingsPage`, 77 `Etkinlik2RequestsPage`

## Istem
```text
Design 6 separate mobile screens for event organizers (pushed pages, header with back arrow, no bottom nav).

1) Event detail as organizer. Management card "Yönetim" with three rows and chevrons: "Katılım istekleri" with badge "3 bekleyen istek", "Katılımcılar ve yoklama", "Etkinlik ayarları". The "⋯" menu opened: "Düzenle", "Etkinlik ayarları", "Kayıtları kapat" (or "Kayıtları yeniden aç"), "İptal et" (red). Attendance summary line "Yoklama: 18 / 42 kişi geldi".

2) Event settings. Header "Etkinlik ayarları". Section "Katılım türü": two option cards "Herkes katılabilir" and "İstek ile katılım" (selected). Field "Kontenjan" with hint "Şu an 12 kişi onaylı. Kontenjanı bundan aşağı çekemezsin." and error "Kontenjan onaylı kişi sayısından (12) az olamaz." Section "Kayıt ve sohbet": toggle "Kayıtlar açık" with hint "Kapatırsan yeni istek ve katılım alınmaz.", toggle "Etkinlik sohbeti açık" with hint "Kapatırsan mesajlar durur, geçmiş saklanır." Button "Kaydet"; toast "Ayarlar kaydedildi."

3) Settings danger zone and dialog. Red-bordered card "Tehlikeli bölge" with text "Katılan 12 kişiye bildirim gider ve sohbet kapanır. Bu işlem geri alınamaz." and button "Etkinliği iptal et". Dialog over it: title "Etkinliği iptal et", body "Bu etkinlik tüm katılımcılar için iptal edilecek.", buttons "Vazgeç", "İptal et".

4) Join requests. Header "Katılım istekleri". Quota card "Kontenjan" with "38 yer kaldı" (or "Kontenjan sınırı yok"). Section "Bekleyen · 3": request cards with avatar, name, department, applicant note and answers, buttons "Reddet" and "Onayla". Toast "İstek onaylandı."

5) Join requests when full. Red banner "Kontenjan doldu; yeni istekler onaylanamaz. Yer açmak için kontenjanı artır." Approve buttons disabled. Section "Yanıtlananlar" with rows and tags "Onaylandı" (green) and "Reddedildi" (red).

6) Join requests empty and error. Illustration "Bekleyen istek yok." and a red error row with "Yeniden dene".
```

## Özellik kontrol listesi
- [ ] Yönetim kartı (3 satır, bekleyen sayacı), organizatör ⋯ menüsü
- [ ] Ayarlar: katılım türü, kontenjan (alt sınır uyarısı), Kayıtlar açık, Etkinlik sohbeti açık, Kaydet
- [ ] Tehlikeli bölge + iptal diyaloğu
- [ ] İstekler: kontenjan sayacı, bekleyen kartları (not, cevaplar), Onayla/Reddet
- [ ] Kontenjan dolu uyarısı ve pasif onay
- [ ] Yanıtlananlar (Onaylandı/Reddedildi), boş ve hata durumu

## Dikkat
- Organizatör ücret/gelir raporu, katılımcıya e-posta gönderme, CSV indirme yok (yönetici panelinde).
- Reddederken gerekçe yazma alanı yok.

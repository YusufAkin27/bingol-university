# 49 - Ayarlar, hesap güvenliği, gizlilik ve engellenenler

## Kapsam
- Envanter 95 `SettingsPage`, 96 `AccountSecurityPage`, 97 `PrivacyDataPage`, 101 `BlockedUsersPage`, A56 dil seçici

## Istem
```text
Design 6 separate mobile screens (pushed pages, header with back arrow, no bottom nav). Settings use grouped white cards with icon tiles in tinted squares.

1) Settings. Header "Ayarlar". Section "GÖRÜNÜM": row "Dil" with sub "Arayüz, bildirim ve e-posta dili" and value "Türkçe". Section "BİLDİRİMLER": row "Bildirim tercihleri" and row "Bildirim izni (push)" with value pill "Açık" (alternatives "Kapalı (sistem ayarlarından açın)", "İzin verilmedi"). Section "GİZLİLİK VE HESAP": toggle "E-postamı diğerlerine göster", row "Rehberden kişi bul", row "Gizlilik ve veriler", row "Destek ve SSS", toggle "Hata raporu gönder" with small description "Uygulama hata verdiğinde anonim bir hata raporu gönderilir.", red row "Tüm cihazlardan çıkış yap". Footer "BÜ Kampüs · Sürüm 2.0.3".

2) Account and security. Header "Hesap ve güvenlik". Email row with value "ad.soyad@bingol.edu.tr", tags "Doğrulandı" (green) and "Değiştirilemez". Section "Şifreyi güncelle": fields "Mevcut şifre" (hint "Mevcut şifreniz"), "Yeni şifre" (hint "En az 8 karakter"), "Yeni şifre (tekrar)", rule text "8 ile 72 karakter. Harf ve rakam karıştırırsanız güçlenir." Errors: "Şifreler eşleşmiyor.", "Yeni şifre mevcut şifreyle aynı olamaz.", "Mevcut şifre hatalı." Success toast "Şifren güncellendi." Button "Şifreyi güncelle". Section "Oturumlar": red row "Tüm cihazlardan çıkış yap".

3) Privacy and blocked. Header "Gizlilik ve engellenenler". Intro "Profilini kimlerin görebileceğini alan alan seç. Kendi profilini her zaman tam görürsün." Section "Profil görünürlüğü": five rows "Profil fotoğrafı", "Hakkımda", "Fakülte", "Bölüm", "Sınıf", each with a 3-way segmented control "Herkes | Ortak bağlam | Yalnızca ben". Help text "Ortak bağlam: ortak kulüp, sohbet veya etkinliğin olduğu kişiler." Toggle "E-postamı profilimde göster" with sub "Kapalıyken yalnızca sen görürsün". Section "Engellenenler" row with count, row "Verilerim ve hesap". Error toast "Değişiklik kaydedilemedi."

4) Blocked users list. Header "Engellenenler". Note "Engellediğin kişiler profilini göremez, sana mesaj yazamaz ve seni takip edemez." Rows: avatar, name, department, outlined button "Engeli kaldır".

5) Blocked users empty. Illustration, title "Kimseyi engellemedin", body "Rahatsız edici bir kullanıcıyı profilinden engelleyebilirsin." Loading skeleton and error row "Yeniden dene".

6) Language bottom sheet. Title "Dil". Radio rows: "Sistem", "Türkçe", "English", "العربية" (selected Türkçe with check). Subtitle "Arayüz, bildirim ve e-posta dili".
```

## Özellik kontrol listesi
- [ ] Ayarlar bölümleri (GÖRÜNÜM, BİLDİRİMLER, GİZLİLİK VE HESAP), dil değeri, push durum hapı
- [ ] E-postamı göster anahtarı, Rehberden kişi bul, Gizlilik ve veriler, Destek ve SSS, hata raporu anahtarı + açıklama, Tüm cihazlardan çıkış, sürüm satırı
- [ ] Hesap: kilitli e-posta (Doğrulandı/Değiştirilemez), 3 şifre alanı, kural metni, hata ve başarı
- [ ] Gizlilik: 5 alan x 3 görünürlük, ortak bağlam açıklaması, e-posta anahtarı, kaydetme hatası
- [ ] Engellenenler listesi, not, Engeli kaldır; boş durum, hata
- [ ] Dil sheet'i (Sistem, Türkçe, English, العربية)

## Dikkat
- İki faktörlü doğrulama, cihaz listesi, "hesabı dondur", abonelik/ödeme yok.
- E-posta değiştirme yok (alan kilitli).
- Dil seçicide yalnız 4 seçenek.

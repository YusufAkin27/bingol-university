# 02 - Kayıt adımları ve e-posta doğrulama

## Kapsam
- Envanter 22 `RegisterPage` (3 adım), 23 `VerifyCodePage`, 28 Bölüm seçici, 29 Sınıf seçici (A3, A4)

## Istem
```text
Design 6 separate mobile screens of the sign-up flow (no bottom nav). Top of every step: back arrow and a 3-part progress bar with text "Adım 1/3".

1) Register step 1. Title "Hangi bölümdesiniz?", hint "Bölümünüzü ve sınıfınızı seçin.", section label "Akademik bilgiler". Two tappable select fields with chevron: "Bölüm" showing "Bilgisayar Mühendisliği", "Sınıf" showing "2. sınıf". Info note: "Bölümünüz, size uygun duyuru ve kulüpleri göstermek için kullanılır." Primary button "Devam". Footer "Zaten hesabınız var mı? Giriş yap".

2) Register step 2 ("Adım 2/3"). Title "Sizi tanıyalım", hint "Adınızı ve okul e-postanızı girin.", section "Kişisel bilgiler". Field "Ad soyad" = "Elif Yıldız". Email/school-number field with suffix "@bingol.edu.tr", helper "226051015 ya da ad.soyad@bingol.edu.tr", shown in error state: "E-posta adresinde + etiketi kullanılamaz." Info note: "Adınız profilinizde ve sohbetlerde diğer öğrencilere görünür." Button "Devam".

3) Register step 3 ("Adım 3/3"). Title "Şifre belirleyin", hint "En az 8 karakterli bir şifre seçin.", field "Şifre (en az 8 karakter)" with eye icon, 3-segment strength bar with label "Orta" (states Zayıf / Orta / Güçlü), two rule rows with check icons "En az 8 karakter", "Harf ve rakam içerir". Note: "Şifreniz yalnızca özeti alınarak saklanır; kimse göremez." Small text: "Kayıt olarak Kullanım koşulları ve gizlilik politikasını kabul etmiş sayılırsınız." (two underlined links). Primary button "Kayıt ol".

4) Verify code. Title "E-postanızı doğrulayın", subtitle "Kod ad.soyad@bingol.edu.tr adresine gönderildi. 10 dakika geçerlidir." Six separate OTP boxes (4 filled, one focused), text button "Yapıştır". Error line under boxes: "Kod hatalı veya süresi dolmuş." Disabled text "Yeniden gönder (42 sn)" (after countdown becomes active "Kodu yeniden gönder"). Tip: "E-posta gelmediyse gereksiz (spam) klasörünü de kontrol edin." Text button "E-postayı değiştir". Primary button "Doğrula".

5) Department picker, full screen list. Title "Bölüm", search field "Ara". Faculty group headers ("Mühendislik-Mimarlık Fakültesi", "Fen-Edebiyat Fakültesi", "Sağlık Bilimleri Fakültesi") with department rows; one row selected with check. Search field contains "mat" and the list is filtered; at the bottom show a small grey hint row "Sonuç bulunamadı." as the empty-search example, and a retry row "Bölüm listesi yüklenemedi." with a "Yeniden dene" text button as the load-failure example.

6) Grade picker, bottom-sheet style list, title "Sınıf". Rows: "Hazırlık", "1. sınıf", "2. sınıf" (selected, check), "3. sınıf", "4. sınıf", "5. sınıf", "6. sınıf", "Yüksek lisans", "Doktora".
```

## Özellik kontrol listesi
- [ ] 3 adımlı ilerleme + "Adım n/3" metni
- [ ] Adım 1: Bölüm ve Sınıf seçiciler, güven notu
- [ ] Adım 2: Ad soyad, e-posta/okul no alanı (sonek + yardımcı metin), sunucu hatası alt metni
- [ ] Adım 3: şifre göz, güç ölçer (Zayıf/Orta/Güçlü), iki kural satırı, sözleşme metni + bağlantılar, "Kayıt ol"
- [ ] OTP: 6 kutu, Yapıştır, hata satırı, yeniden gönder sayacı, spam ipucu, E-postayı değiştir
- [ ] Bölüm seçici: arama, fakülte grupları, seçili işareti, boş sonuç, yükleme hatası + Yeniden dene
- [ ] Sınıf seçici: Hazırlık, 1-6. sınıf, Yüksek lisans, Doktora

## Dikkat
- Telefon numarası, doğum tarihi, TC kimlik no, profil fotoğrafı yükleme adımı yok.
- Sözleşme onayı ayrı bir onay kutusu değil, bilgi metnidir ("Kayıt olarak ... kabul etmiş sayılırsınız").
- E-posta alan adı yalnız bingol.edu.tr.

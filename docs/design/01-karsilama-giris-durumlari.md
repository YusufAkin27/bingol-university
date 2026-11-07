# 01 - Karşılama ve giriş durumları

## Kapsam
- Envanter 20 `WelcomePage`
- Envanter 21 `LoginPage` yalnızca durum varyantları (normal Giriş referans tasarımda var): doğrulama hatası, kilit/hız sınırı, doğrulama bekleyen kayıt bandı, başka cihaz oturum bildirimi

## Istem
```text
Design 5 separate mobile screens.

1) Welcome (first launch, no bottom nav). Navy-to-white soft hero. Small language pill top-right with 3 segments "TR | EN | AR" (TR selected). Headline in two lines: "Kampüs artık" / "cebinizde". Subtitle: "Duyurular, yemek listesi, kulüpler ve etkinlikler tek uygulamada." Three feature rows with icons: "Haberler ve duyurular", "Günün yemek listesi", "Kulüpler ve etkinlikler". Info note card with shield icon: "Yalnızca okul e-postası (bingol.edu.tr) ile kayıt olunabilir." Bottom: primary red button "Giriş yap", outlined button "Kayıt ol".

2) Login with field errors. Title "Hoş geldiniz", subtitle "Okul e-postanızla giriş yapın." Field "Okul e-postanız" with fixed suffix "@bingol.edu.tr" and helper "226051015 ya da ad.soyad@bingol.edu.tr". Email field in error state: "Yalnızca bingol.edu.tr uzantılı adres kullanılabilir." Password field "Şifre" with show/hide eye icon, error "Şifrenizi girin." Link "Şifremi unuttum", primary button "Giriş yap", footer "Hesabınız yok mu? Kayıt ol".

3) Login while submitting and rate limited. Same layout, filled valid values. Button in busy state (spinner inside, disabled). Below it a warning banner: "Çok fazla deneme. Lütfen biraz bekleyin." and small text "42 sn sonra tekrar deneyin."

4) Login with pending-verification banner on top (amber soft card with mail icon): "E-postanı doğrula. Giriş yapabilmek için hesabının doğrulanması gerekir." Banner button "Doğrulamayı tamamla" and text button "Başka hesapla giriş yap". Form below is filled with ad.soyad@bingol.edu.tr.

5) Login with session-replaced notice on top (info card with smartphone icon): "Hesabına başka bir cihazdan giriş yapıldı. Güvenliğin için bu cihazdaki oturum kapatıldı." Empty form below, plus a generic server error line under the button: "Sunucuya ulaşılamadı. Bağlantınızı kontrol edin."
```

## Özellik kontrol listesi
- [ ] Welcome: dil hapı (TR/EN/AR), iki satırlı başlık, alt metin, 3 özellik satırı, bingol.edu.tr notu, Giriş yap + Kayıt ol
- [ ] Giriş: e-posta alanı sonek `@bingol.edu.tr` + okul numarası yardımcı metni
- [ ] Alan hataları (alan alt metni): geçersiz alan adı, boş şifre
- [ ] Şifre göster/gizle gözü
- [ ] Meşgul düğme (iç çember) + hız sınırı uyarısı ve geri sayım
- [ ] Doğrulama bekleyen kayıt bandı: "Doğrulamayı tamamla" + "Başka hesapla giriş yap"
- [ ] Başka cihazdan giriş bildirimi
- [ ] Ağ hatası satırı
- [ ] "Şifremi unuttum" ve "Kayıt ol" bağlantıları

## Dikkat
- Giriş ekranında e-Devlet, Google/Apple ile giriş, "Beni hatırla" yok.
- Welcome ekranında sahte öğrenci sayısı, resmi logo, kampüs fotoğrafı iddiası eklemesin.
- Dil hapında yalnız TR/EN/AR; başka dil yok.

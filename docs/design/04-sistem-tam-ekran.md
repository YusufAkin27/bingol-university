# 04 - Sistem tam ekranları

## Kapsam
- Envanter 1 `SplashScreen`, 5 `UpdateRequiredScreen`, 6 `MaintenanceScreen`, 7 `OfflineScreen`, 8 `AccessBlockedScreen`

## Istem
```text
Design 5 separate full-screen system states for the mobile app (no bottom nav, no app bar).

1) Splash. Solid brand red (#F73A2E) background, a thin white animated progress ring around a white rounded-square logo tile containing a simple "BÜ" monogram, app name "BÜ Kampüs" in white below. Nothing else.

2) Update required (cannot be dismissed). Light background, large rounded icon tile with download-arrow, title "Güncelleme gerekli", body "Uygulamayı kullanmaya devam etmek için yeni sürüme güncellemeniz gerekiyor.", version line in a small grey pill "Yüklü sürüm 2.0.3 · Gerekli sürüm 2.1.0". Primary button "Güncelle", text button "Tekrar kontrol et".

3) Maintenance. Wrench/tools illustration, title "Sistem bakımda", body "Sizin için daha iyi hale getiriyoruz. Kısa süre sonra tekrar deneyin. Verileriniz güvende." Button "Yeniden dene". Above the content a thin amber strip: "Bazı özellikler geçici olarak kullanılamayabilir."

4) Offline. Cloud-off illustration, title "Bağlantı yok", body "İnternet bağlantınızı kontrol edip tekrar deneyin. Sunucuya şu an ulaşılamıyor olabilir." Button "Yeniden dene".

5) Access blocked. Shield-off illustration in danger-red tint, title "Erişim kapatıldı", body "Bu cihaza veya ağa erişim kapatıldı. Hatalı olduğunu düşünüyorsan destek ile iletişime geç.", small monospace grey pill "Hata kodu: ACCESS_BLOCKED", button "Yeniden dene".
```

## Özellik kontrol listesi
- [ ] Splash: kırmızı zemin, halka, logo karosu, ad
- [ ] Güncelleme: sürüm satırı (yüklü/gerekli), Güncelle, Tekrar kontrol et, kapatma yok
- [ ] Bakım: başlık, gövde, Yeniden dene, uyarı şeridi
- [ ] Çevrimdışı: başlık, gövde, Yeniden dene
- [ ] Erişim kapatıldı: hata kodu pili, Yeniden dene

## Dikkat
- Splash'ta resmi üniversite logosu yok; basit "BÜ" monogramı.
- Bakım/çevrimdışı ekranında sahte durum sayfası bağlantısı, e-posta adresi, telefon numarası yok.
- Güncelleme ekranında "Daha sonra" düğmesi yok (zorunlu güncelleme).

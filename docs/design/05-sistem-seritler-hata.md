# 05 - Sistem şeritleri, bildirim kartı ve hata ekranları

## Kapsam
- Envanter 2 `ConfigErrorApp`, 3 `ErrorWidget`, 4 `AppGate` (karar katmanı), 9 `TopStrip`, 10 `UpdateNotice`, 11 `OfflineBanner + StaleLabel`, 12 `PushBanner`

## Istem
```text
Design 6 separate mobile screens. Screens 1-4 reuse the Ana Sayfa (home) layout as background (greeting, search box, quick-access tiles, today's menu card) WITH the 5-tab floating bottom nav; screens 5-6 are standalone.

1) Offline state on Ana Sayfa. A slim top strip in neutral grey: cloud-off icon + "İnternet bağlantısı yok" and right text "Kayıtlı veriler gösteriliyor". Directly below the strip a thin sync strip: "3 mesaj bağlantı gelince gönderilecek". Content below is dimmed/stale.

2) Maintenance and announcement strips on Ana Sayfa. Stacked: amber strip with wrench icon "Bazı özellikler geçici olarak kullanılamayabilir."; below it a blue info strip with megaphone icon and a close "x": "Yarın 10.00-12.00 arası planlı bakım yapılacaktır." Under the page title a small grey label "Son güncelleme: 14:32".

3) Optional update notice. Ana Sayfa background; a floating card above the bottom nav with download icon: "Yeni sürüm mevcut (2.1.0)." Buttons "Güncelle" (primary, compact) and close "x".

4) Foreground push banner. Ana Sayfa background; a white rounded card sliding down from the top: avatar of Elif Yıldız, title "Elif Yıldız", body "Yarınki toplantıyı unutma", time "şimdi". Beneath it a smaller stacked card edge to suggest several messages from the same chat are merged into one.

5) Render error screen (replaces the red crash screen). Centered warning icon, title "Bir şeyler ters gitti", short body "Bir sorun oluştu. Lütfen tekrar deneyin.", button "Yeniden dene". Plain light background, no bottom nav.

6) Developer configuration error. Centered danger icon, title "Yapılandırma hatası", body "Sunucu adresi (API_BASE) güvenli (https) değil. Uygulamayı doğru adresle yeniden derleyin." Monospace grey box showing "API_BASE=http://..." No buttons.
```

## Özellik kontrol listesi
- [ ] Çevrimdışı şeridi + "Kayıtlı veriler gösteriliyor"
- [ ] Bekleyen çevrimdışı mesaj kuyruğu şeridi ("N mesaj bağlantı gelince gönderilecek")
- [ ] Bakım şeridi (amber)
- [ ] Yönetici duyuru şeridi (kapatılabilir)
- [ ] "Son güncelleme: SS:DD" bayat veri etiketi
- [ ] İsteğe bağlı güncelleme kartı (Güncelle + kapat)
- [ ] Ön plan push kartı (avatar, başlık, gövde, zaman, birleşmiş kart görünümü)
- [ ] Çizim hatası ekranı (Yeniden dene)
- [ ] Yapılandırma hatası ekranı (yalnız geliştirici)

## Dikkat
- Push kartında marka logosu olarak resmi üniversite armasını koymasın.
- Duyuru şeridi içeriği yönetici metnidir; uydurma kampanya/indirim duyurusu yazmasın.
- Hata ekranlarında telefon/e-posta destek numarası uydurmasın.

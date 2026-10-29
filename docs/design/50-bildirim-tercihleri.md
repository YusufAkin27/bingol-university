# 50 - Bildirim tercihleri

## Kapsam
- Envanter 100 `NotificationPrefsPage`, A59 sessiz saat saat seçici; anlık bildirim izin durumu

## Istem
```text
Design 5 separate mobile screens (pushed pages, header "Bildirim tercihleri" with back arrow, no bottom nav).

1) Main preferences, push enabled. Top card "Anlık bildirimler" with sub "Bu cihazda izin verildi" and a green toggle/pill "Açık". Section "Neler bildirilsin": toggle rows with subtitles - "Haberler" ("Üniversiteden yeni haberler"), "Duyurular" ("Önemli duyurular"), "Etkinlikler" ("Hatırlatma, değişiklik, kabul"), "Mesajlar" ("Kişi ve grup sohbetleri"), "Kulüpler" ("Gönderiler, rol ve katılım"), plus "Anketler" and "Akademik duyurular". Row "Ayrıntılı tercihler" with chevron.

2) Push disabled. Top card shows red-tinted pill "Kapalı" and text "Kapalı (sistem ayarlarından açın)" with button "Ayarlardan aç". Alternative states as small text: "İzin verilmedi", "Henüz yapılandırılmadı". Toggles below still usable but dimmed.

3) Detailed preferences expanded. Group rows with nested toggles: "Kişisel mesajlar", "Grup mesajları" (under Mesajlar); "Etkinlik hatırlatmaları", "Etkinlik değişiklikleri", "Etkinlik kabulleri" (under Etkinlikler); "Kulüp gönderileri", "Kulüp rol değişiklikleri", "Kulüp katılım istekleri" (under Kulüpler). Show one parent switched off so its children are greyed and disabled.

4) Quiet hours. Section "Sessiz saatler": toggle "Sessiz saatleri aç" with sub "Bu saatlerde bildirim sesi çalmaz". Two boxed time fields "Başlangıç 23:00" and "Bitiş 07:00". Below, the Material 3 time picker dial dialog open for "Başlangıç" with buttons "Vazgeç", "Seç".

5) Error and device section. Red-tinted row "Yüklenemedi. Yeniden denemek için dokunun." Section "Bu cihazda": row "Ders ve sınav hatırlatmaları" with chevron (opens reminder settings).
```

## Özellik kontrol listesi
- [ ] Anlık bildirim kartı (Açık / Kapalı / izin verilmedi / yapılandırılmadı) + Ayarlardan aç
- [ ] Ana anahtarlar: Haberler, Duyurular, Etkinlikler, Mesajlar, Kulüpler (+ Anketler, Akademik duyurular)
- [ ] Ayrıntılı tercihler (8 alt tür), üst kapalıyken pasif
- [ ] Sessiz saatler: anahtar + başlangıç/bitiş + saat seçici
- [ ] Hata satırı (dokun-yeniden dene)
- [ ] "Bu cihazda" bölümü: Ders ve sınav hatırlatmaları

## Dikkat
- Beğeni, yorum, bahsetme, hikâye, takipçi bildirimi anahtarı çizilmesin (kodda bu uç türleri kaldırıldı/gösterilmez).
- E-posta bildirimi ve SMS tercihleri yok.

# 47 - Başka kullanıcının profili: takip, gizlilik ve engel durumları

## Kapsam
- Envanter 89 `UserProfilePage`, 90 `_AvatarViewer`; A60 engelleme onayı (metin `51-ortak-sheetler.md` içinde)

## Istem
```text
Design 6 separate mobile screens of the user profile page opened from chat, search, club members or a post (pushed page, header with back arrow and a "⋯" button "Kullanıcı işlemleri", no bottom nav).

1) Someone else's profile, not followed. Large 96px avatar (tappable), name "Mehmet Kaya", green dot with "Çevrimiçi". Stats row: "24 gönderi", "128 takipçi", "94 takip". Buttons: primary "Takip et" and outlined "Mesaj gönder". Info card: "Hakkında" (short bio), "Fakülte: Mühendislik-Mimarlık Fakültesi", "Bölüm: Makine Mühendisliği", "Sınıf: 3. sınıf", "E-posta: mehmet.kaya@bingol.edu.tr" (only if the user chose to show it). Section "GÖNDERİLER": 3-column photo grid.

2) Follow states. Button "Takipte" (tonal, check) with pill "Takipleşiyorsunuz"; second small block shows pill "Seni takip ediyor" with the "Takip et" button. Status line "Son görülme bugün 14:20" instead of online.

3) Hidden fields and own view. Info rows where the owner limited visibility show a lock icon and the word "Gizli" for Fakülte, Bölüm, Sınıf; the avatar is a letter placeholder; bio missing. Second small block: viewing my OWN profile through this page: primary button "Profili düzenle" instead of Takip/Mesaj and the note "Profil fotoğrafın moderasyon nedeniyle gizlendi." as an info card.

4) Blocked user. Banner "Kullanıcı engellendi". The "Mesaj gönder" and "Takip et" buttons replaced by "Engeli kaldır" (outlined red). Opened "⋯" dropdown: "Kullanıcıyı şikâyet et", "Engelle" (or "Engeli kaldır" when blocked). Toasts: "Kullanıcı engellendi", "Engel kaldırıldı".

5) Avatar viewer. Full-screen black background, circular-cropped large avatar photo centered, close "x" top-left.

6) Loading and error. Skeleton: grey avatar circle, grey name bar, three grey stat bars, grey button bars. Below it an error variant "Kullanıcı bulunamadı" with a back button.
```

## Özellik kontrol listesi
- [ ] Avatar (dokununca tam ekran), ad, çevrimiçi / son görülme
- [ ] Sayaçlar: gönderi, takipçi, takip
- [ ] Takip et / Takipte / Takipleşiyorsunuz / Seni takip ediyor
- [ ] Mesaj gönder, "⋯" menü (şikâyet, engelle/engeli kaldır)
- [ ] Alanlar: Hakkında, Fakülte, Bölüm, Sınıf, E-posta (gizlilik ayarına bağlı); "Gizli" durumu
- [ ] Kendi profilimi görüntüleme: Profili düzenle
- [ ] Engellenmiş kullanıcı durumu + bildirimler
- [ ] Gönderiler ızgarası
- [ ] İskelet / Kullanıcı bulunamadı

## Dikkat
- Telefon numarası, doğum tarihi, kullanıcı adı (@handle), "ortak arkadaşlar" yok.
- E-posta yalnız kullanıcı göstermeyi seçtiyse gösterilir.
- Hikâye halkası, rozet/başarım, puan yok.

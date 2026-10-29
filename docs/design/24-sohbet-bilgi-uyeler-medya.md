# 24 - Sohbet bilgisi, üyeler ve ortak medya

## Kapsam
- Envanter 52 `ChatInfoPage` (birebir, grup, kulüp/etkinlik odası, kapalı), 53 `ChatMembersPage`, 54 `ChatMediaGridPage`, A20 onay diyalogları

## Istem
```text
Design 6 separate mobile screens (no bottom nav, header "Sohbet bilgisi" with back arrow).

1) Direct chat info. Large 96px avatar, name "Mehmet Kaya", subtitle department. Quick action row of three round buttons: "Ara", "Sessize al", "Arşivle". Row "Profili görüntüle". Media preview strip: section "Medya · 12" with 4 square thumbnails and link "Tüm medyayı gör". Row "Bildirimleri sessize al" with state "Açık" (or "Sessiz · 3 gün sonra açılır"). Red rows: "Engelle", "Kullanıcıyı şikâyet et".

2) Group chat info (I am admin). Avatar with camera badge "Fotoğrafı değiştir", name with pencil "Adı düzenle", "12 üye". Quick actions same. Section "Üyeler · 12" showing 4 member rows (avatar, name, small tag "Yönetici" on two, "Sen" on mine) and link "Tümü". Row "Üye ekle". Media preview "Medya · 8". Red row "Sohbetten çık".

3) Club room and closed room info. Top block: club logo, "Robotik Kulübü", chip "Kulüp odası", "86 üye", row "Kulüp sayfasını aç". No rename or photo buttons. Lower block (another room, event): chip "Etkinlik odası", row "Etkinlik sayfasını aç", and a grey notice card "Bu sohbet kapalı" with "Yeni mesaj gönderilemez".

4) Members page. Header "Üyeler (12)". Search "Üye ara". Rows: avatar, name, tag "Yönetici" / "Sen"; for admins a trailing "Gruptan çıkar" button on non-admin rows. Empty search "Sonuç yok." Error "Üye listesi alınamadı." with "Yeniden dene". Bottom button "Üye ekle".

5) Remove member confirmation dialog over the members page. Title "Üye çıkarılsın mı?", body "Zeynep Arslan gruptan çıkarılır.", buttons "Vazgeç" and "Çıkar" (red).

6) Shared media grid. Header "Medya". 3-column square grid of photos, videos have a play badge and duration. Empty variant: "Bu sohbette henüz görsel yok." Loading: grey squares. Error: "Yeniden dene".
```

## Özellik kontrol listesi
- [ ] Birebir bilgi: avatar, ad, hızlı eylemler (Ara, Sessize al, Arşivle), Profili görüntüle, medya önizleme, sessiz durumu, Engelle, Şikâyet
- [ ] Grup bilgi: fotoğrafı değiştir, adı düzenle, üye sayısı, üye önizlemesi (Yönetici/Sen etiketi), Üye ekle, Sohbetten çık
- [ ] Kulüp/etkinlik odası bilgisi (rol etiketi, sayfa bağlantısı), kapalı sohbet kartı
- [ ] Üyeler sayfası: arama, yönetici işlemleri, boş/hata
- [ ] Üye çıkarma onayı (engelle/ayrıl onayları: `51-ortak-sheetler.md` ve `22-sohbet-diger-sheetler.md`)
- [ ] Ortak medya ızgarası: video rozeti, boş, yükleniyor, hata

## Dikkat
- "Ortak gruplar", "Sohbeti dışa aktar", "Şifreleme doğrula", "Kaybolan mesajlar" gibi satırlar yok.
- Kulüp/etkinlik odalarında ad ve fotoğraf kullanıcı tarafından değiştirilemez.

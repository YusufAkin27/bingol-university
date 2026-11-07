# 30 - Kulüplerim

## Kapsam
- Envanter 63 `MyClubsPage`, 64 `Scaffold(ClubsTab)` (aynı Kulüpler sekmesinin tam ekran kopyası; ayrı tasarım gerekmez, referanstaki Kulüpler sekmesi geçerli)

## Istem
```text
Design 3 separate mobile screens (no bottom nav, header "Kulüplerim" with back arrow and a "+" button "Kulüp kur").

1) My clubs with data. Three sections with small-caps headers. "Kurduklarım" - club card with logo, name "Robotik Kulübü", role tag "Başkan", "86 üye", pill "Yayın onayı bekleniyor" on a second club, trailing "Yönet" button. "Üye olduklarım" - rows with logo, name, role tag ("Moderatör", "Üye"), member count. "Bekleyen başvurular" - row with "Onay bekliyor" amber pill and trailing "İsteği geri çek" text button.

2) Row options bottom sheet. Title is the club name. Rows: "Yönet: düzenle", "Yönet: başvurular", "Yönet: üyeler", "Aç", "Kulüpten ayrıl" (red).

3) Empty and error. Illustration with title "Henüz bir kulübün yok" and body "Kulüpleri keşfedip katılabilir ya da kendi kulübünü kurabilirsin." Buttons "Kulüpleri keşfet" (primary) and "Kulüp kur" (outline). Below an error row "Yüklenemedi, tekrar dene".
```

## Özellik kontrol listesi
- [ ] Üç bölüm: Kurduklarım / Üye olduklarım / Bekleyen başvurular
- [ ] Rol etiketleri (Başkan, Moderatör, Üye), üye sayısı, durum hapları (Onay bekliyor, Yayın onayı bekleniyor)
- [ ] Satır seçenekleri (Yönet: düzenle/başvurular/üyeler, Aç, Kulüpten ayrıl)
- [ ] İsteği geri çek
- [ ] Boş durum + Kulüpleri keşfet / Kulüp kur; hata

## Dikkat
- Bu sayfa "Kulüpler" sekmesinden farklıdır; alt gezinme yok.

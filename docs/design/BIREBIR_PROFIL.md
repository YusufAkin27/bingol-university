# BIREBIR_PROFIL: Stitch v3 Kategori 4 (Profil) ve 5 (Ayarlar) uygulama ölçü tablosu

Kaynak: `C:\bu_design\stitch\v3_feed\SARTNAME.md` KATEGORİ 4/5, PNG'ler `profil\` ve `ayarlar\` (780x1688 = 390x844 dp @2x, açık + koyu). Uygulama görüntüsü: `mobile/test/redesign/p3_profile_shots_test.dart` (`P3P_H=844`, dpr 2.5, tr), referansla yan yana: `C:\bu_qa\shots\tasarim\p3\profile\birebir\*_yanyana.png` (sol referans, sağ uygulama; 11 ekran x açık/koyu).

Ölçüm yöntemi ve dürüstlük notu: "Referans dp" şartnamedeki sayıdır (PNG'den px / 2). "Uygulama dp" kodda verilen/ilgili widget'ın ürettiği değerdir (`BoxConstraints`, `fontSize`, `BuRadius`); yan yana PNG'lerde gözle ±2 dp içinde olduğu doğrulandı, piksel piksel otomatik ölçüm yapılmadı. Harness üst boşluğu (tr: 28 dp simüle durum çubuğu) uygulama görüntülerinde başlık çubuğunu referanstan aşağıda gösterir; sapma sayılmaz.

## Ortak parçalar (profile/profil_widgets.dart)

| Öğe | Referans dp | Uygulama dp | Fark |
|---|---|---|---|
| Üst çubuk `ProfilTopBar` | 56, düz geri oku 24, başlık 18/600, çizgisiz | 56, ok 24 (48 dp dokunma), 18/600, çizgisiz | 0 |
| Bölüm etiketi `ProfilFlatSection` | 13/500 mut | 13/500 mut (alt sayfalarda büyük harf 13/600, referans PNG'de büyük) | 0 |
| Düz satır `ProfilFlatRow` | 56, yazı 16 ink, değer 15 mut, chevron 20 | 56, 16, 15, 20 | 0 |
| Anahtar satırı `ProfilFlatToggle` | 56+, M3 standart anahtar, açıklama 12 mut | 56+, M3, 12 | 0 |
| Segment `P2Segment3` | 36, sf2 yuva, seçili soft + onSoft + selectedBorder | yuva 36, parça 48 dp dokunma, 13 sp | 0 (seçili kenarlık referans PNG'de silik, uygulamada selectedBorder belirgin) |

## 01 Profil sekmesi

| Öğe | Referans dp | Uygulama dp | Fark |
|---|---|---|---|
| Başlık "Profilim" | 28/700 | 28/700 | 0 |
| "Düzenle" çipi | 36 yük., soft, 13/500 | 36 (48 dp dokunma), soft/onSoft, 13/500 | 0 (referans PNG nötr, şartname soft: şartname izlendi) |
| Avatar | 88, halkasız | 88 | 0 |
| Ad / bölüm · sınıf / bio | 22/700; 15 mut; 15 mut en çok 2 satır | 22/700; 15 mut; 15 mut, 2 satır | 0 |
| Sayaç kutusu | sf, köşe 16, 3 eşit sütun, dikey bd çizgisi, sayı 20/700, etiket 13 mut, vurgu YOK | `StatStrip`: BuCard r16, 3 sütun, 20/700, 13 mut, vurgu yok; 1 dp çerçeve | 0 (referanstaki ortadaki "Takip" vurgusu şartnameye göre uygulanmadı) |
| Listeler | bölüm etiketi + sf kutu r16, 56 dp ikonsuz satır, bd ayırıcı, chevron 20; kulüp/etkinlik/kayıtlı sayısı sağda mut | aynı (`ProfilCard` r16, `ProfilRow` 56) | referansta kutu çerçevesiz, uygulamada 1 dp bd çerçeveli |
| Gönderi sayısı | 12 | mevcut `/posts/mine` toplamı (yeni uç yok); alınamazsa "–" | veri kaynağı farkı |

## 02/03 Profili düzenle

| Öğe | Referans dp | Uygulama dp | Fark |
|---|---|---|---|
| Avatar | 96, rozetsiz; "Fotoğrafı değiştir" 13/600 pr metin | 96, rozetsiz; 13/600 pr | 0 |
| Alan etiketi | 13 mut üstte | 13/500 mut | 0 |
| Alan | sf, r16, 52; Hakkımda 96 | sf, r16, 52; Hakkımda 3 satır ≈ 95 | ≤ 2 |
| Bölüm/Sınıf seçici | sağda aşağı ok | aynı | 0 |
| Kurumsal e-posta | sf2, sağda kilit 18 | sf2, kilit 18 | 0 |
| Anahtar satırı | "E-postamı diğer kullanıcılara göster" | aynı, açıklama yok | 0 |
| Kaydet | pr dolu 48, 20 dp kenar, çizgisiz | 48, 20 dp, çizgisiz | 0 |
| Hata durumu | alan çerçevesi danger 1.5 (zemin sf), altta danger 12 mesaj; fotoğraf hatası danger 13 ortalı; avatarda "Yükleniyor…" + halka | aynı (`_TextBox`/`_SelectBox`/`P2PhotoError`) | 0 |
| Sayaç `40/300` | yok | yalnız sınırın %80'inde görünür (silinemeyen sınır geri bildirimi) | sapma: gerekçe: sessiz kesilme yerine uyarı |

## 04 Başkasının profili / 05 Takipçi-takip / 06 Önerilenler

| Öğe | Referans dp | Uygulama dp | Fark |
|---|---|---|---|
| Üst çubuk | geri + sağ "...", başlık YOK | aynı | 0 |
| Avatar | 96; "Çevrimiçi" 13 mut + 8 dp yeşil nokta | 96; 13 mut; 8 dp ok noktası | 0 |
| Düğmeler | Takip et pr dolu / Takipte tonal; Mesaj gönder outlined bdStrong | aynı | 0 |
| Takipçi sekmeleri | düz iki sekme, seçili ink 15/600 + 2 dp pr alt çizgi, sayı hap değil 13 mut | aynı (`FollowTabs`) | 0 |
| Kişi satırı | sf kutu r16, 64 dp, avatar 44, ad 15/600, bölüm 13 mut, durum 12 mut | aynı | 0 |
| Takip düğmesi | Takipte: tonal sf2+ink 36; Takip et: outlined bdStrong 1 dp | 36 dp görünür, 48 dp dokunma; aynı renkler | 0 |

## Ayarlar 01-06

| Ekran | Öğe | Referans | Uygulama | Fark |
|---|---|---|---|---|
| 01 Ayarlar | satırlar | tam genişlik 56, bölümler Görünüm, Bildirimler, Gizlilik ve hesap | + Tema (Görünüm), Sohbet bölümü (Sohbet arka planı, Rehberden kişi bul), Çıkış yap | sapma: Tema/Çıkış/Rehber ürün gereği korunur; Sohbet arka planı şartname metinsel |
| 02 Gizlilik | satırlar | alan etiketi 16 + 36 dp segment, yardım 12 mut, anahtar, Engellenenler, Verilerim ve hesap | aynı (+ galeriye kaydet anahtarı) | başlık "Gizlilik ve engellenenler" (referans "Gizlilik"); giriş metni 2. cümle ARB'de duruyor |
| 03 Hesap ve güvenlik | e-posta bloğu, şifre alanları, "Şifreyi güncelle" pr 48, Oturumlar | aynı; hata ikonsuz danger 12; "3 aktif oturum" yan metni uygulanmadı (şartname) | 0 |
| 04 Verilerim | giriş, "DOSYADA NELER VAR" + onay işaretli 5 satır, 12 mut not, indir pr 48, KVKK + Hesabımı sil (danger) | aynı | not iki satır (JSON bilgisi ve günlük sınır ayrı metin) |
| 05 Hesabı sil | dangerSoft not, "NELER OLUR" noktalı satırlar, mut ipucu, onay, Devam et (%40 opak) + Vazgeç | aynı | madde sayısı 6 (kulüp kapatma ve cihaz/IP kaydı maddeleri hukuki doğruluk için korundu), onay cümlesi daha uzun |
| 06 Engellenenler | mut 13 açıklama, sf satırlar 64, sağda outlined "Engeli kaldır" 36, boş: ortalı başlık 18/600 + 15 mut, illüstrasyonsuz | aynı | 0 |

## Metinsel şartname (PNG'siz)

- Hakkında: mevcut `AboutPage` (AUTH) kullanılıyor; satır düzeni onların kapsamında.
- Dil seçici: `showProfilChoiceSheet` (BuSheet, seçili satırda onay işareti); başlık "Dil".
- Sohbet arka planı sayfası: CHAT ajanının `ChatBackgroundSettingsPage`'i; Ayarlar'dan ve Profil tercihleri listesinden bağlı.
- Hesap silme şifre onayı (`DeleteConfirmSheet`) ve şikâyet sheet'i (`widgets/report_sheet.dart`): bu turda DEĞİŞTİRİLMEDİ (şifre onayı metni zaten şartnamedeki gibi; ortak dosya başka ajanın yarım değişikliği taşıyabilir).

## Doğrulama

`flutter analyze lib/features/profile lib/features/follow`: 0 sorun. Testler (320 dp x1.3, 3 dil, açık/koyu matrisi dahil): `test/redesign/p3_profile_test.dart`, `profil1/2/yard`, `user_profile`, `p18`, `pages_c`, `visual_c`, `l10n`, `crash_reporter`, `back_navigation`. Gerçek cihaz/emülatör gezisi yapılmadı.

# MIMAR_DB: Kabuk, Ana Sayfa, Yemek, Bildirimler, Profil ve hesap (mimar cilası)

Kapsam: docs/MOBILE_PAGES.md C (30-36), D (37-38), K (89-101) ve bu ekranların alt sayfa/diyalogları (A51-A60).
Yöntem: widget ekran görüntüsü testleri (`mobile/test/redesign/db_shots_test.dart`, sahte veri). Önce/sonra PNG:
`C:\bu_qa\shots\tasarim\db\onceki|sonra\` (tr390 açık + koyu, tr320 x1.3, ar390).
Renk, API, ağ katmanı ve ürün kuralları değişmedi; yalnız ortak BuMotion parçaları kullanıldı (yeni parça/renk/metin yok).

## Ana Sayfa (32)

| # | Bulgu | Öneri | Durum |
|---|---|---|---|
| H1 | İskelet -> içerik geçişi sertti (widget ağacı anında değişiyordu) | `BuSwapIn` (yalnız opaklık, boyut animasyonu yok) | Uygulandı |
| H2 | Kartlar bir anda beliriyordu | `BuStaggerScope` + `BuStaggerItem`: ilk 4 blok (başlık, arama, yemek, hızlı erişim) sırayla; yenilemede ve kaydırırken yeniden oynamaz, aşağıdaki bölümler hiç animasyonlanmaz | Uygulandı |
| H3 | Hızlı Erişim 320 dp / 360 dp ve büyük yazıda etiketler tek tek `FittedBox` ile küçülüyordu ("Etkinlikler" 9 sp, "Yemek" 12 sp: tutarsız ve 11.5 sp kuralını ihlal) | `HomeQuickGrid`: etiketler okunur boyutta sığıyorsa 5 karo tek satır, sığmıyorsa 3+2 iki satır (eşit genişlik); ölçüm `TextPainter` ile | Uygulandı |
| H4 | Yemek vitrininde saat hapı başlığı sıkıştırıyordu (320/x1.3'te "Günün Yemek..." kırpılıyordu) | Rozet + saat aynı satırda `Wrap`, başlık tam genişlikte | Uygulandı |
| H5 | Blok aralıkları tutarsız (14/18/22/18/18) ve "Hızlı Erişim" başlığı diğer bölüm başlıklarından farklı (gri, 4 dp içeride) | Ritim 16 (üst bloklar) / 24 (bölümler arası); Hızlı Erişim başlığı diğerleriyle aynı 17 sp ink stili ve hizası | Uygulandı |
| H6 | Selamlama adı tek satırda kırpılıyordu (büyük yazıda "Ayşe ...") | `maxLines: 2` | Uygulandı |
| H7 | Arama kutusu basma geri bildirimi yoktu | `BuPressable(scale .985)` | Uygulandı |
| H8 | Yemek vitrinindeki "+N" çeşit göstergesi etiketsiz | Yeni metin gerektirir | Uygulanmadı (yeni metin yasağı; öneri: "+N çeşit daha" ARB'si) |

D2'nin Hızlı Erişim kararı (Anketler karosu eklendi, Kulüpler kaldırıldı, commit 0fff613) korundu; `kNavInset` alt boşluğu aynı.

## Yemek (37)

| # | Bulgu | Öneri | Durum |
|---|---|---|---|
| M1 | İskelet -> içerik anlık değişim | `BuSwapIn` (gün şeridi dahil) | Uygulandı |
| M2 | Gün seçince etiket + kart zıplıyordu | `BuFadeThrough` (gün anahtarlı); puanlama kartı dışarıda kaldığı için yeniden kurulmaz | Uygulandı |
| M3 | Kalori satırları, toplam, fotoğrafsız yer tutucu, hata/boş durumlar | Gözden geçirildi, iyi | Değişmedi |

## Bildirimler (38)

| # | Bulgu | Öneri | Durum |
|---|---|---|---|
| N1 | "Tümünü okundu yap" 390 dp'de iki satıra sarıyor, başlık küçülüyordu | Tek satır; dar telefonlarda (< 430 dp) başlığın altında sağa hizalı satıra iner (başlık her ekranda aynı boyda) | Uygulandı |
| N2 | Gövdesiz bildirimin başlığı tek satırda kırpılıyordu (mesajın kendisi okunamıyor) | Gövde yoksa `maxLines: 2` | Uygulandı |
| N3 | Satırlarda basma geri bildirimi yok; liste bir anda beliriyor | `BuPressable(scale .985)` (`NotifRow`, Akademik ekranıyla ortak), ilk 8 satır kademeli giriş (`BuStaggerItem`), iskelet -> içerik `BuSwapIn` | Uygulandı |

## Profil ve hesap (36, 89-101)

| # | Bulgu | Öneri | Durum |
|---|---|---|---|
| P1 | Bildirim tercihleri ve Ayrıntılı tercihler sayfaları Akademik'in düz başlığını (yüzey çubuk, düz ok) kullanıyordu; Ayarlar/Gizlilik/Hesap sayfalarının `BuHeader`'ından farklıydı | `Scaffold + BuHeader` (daire geri düğmesi, aynı 20 dp kenar boşluğu) | Uygulandı |
| P2 | `ProfileTab` zaten `BuStaggerScope` + `BuSwapIn`-benzeri `AnimatedSwitcher` kullanıyor; Ayarlar/Gizlilik/Verilerim/Hesap silme taramaları taşma ve hiyerarşi açısından temiz | Gözden geçirildi | Değişmedi |
| P3 | Ayarlar'da "Bildirim izni (push)" etiketi durum hapının yanında iki satıra sarıyor | Hapı kısaltmak yeni metin ister | Uygulanmadı (öneri) |
| P4 | `privacy_data_page` `prefer_const_constructors` bilgisi | `const` eklendi | Uygulandı |

## Kabuk (30-31)

AppShell / FloatingNav incelendi (sekme geçişi fade-through, tembel kurulum, rozet pop, `kNavInset`); somut bir bulgu çıkmadı, değişiklik yok.

## Doğrulama

- `flutter analyze` (home, menu, notifications, profile, shell, yeni testler): 0 sorun.
- Yeni testler: `mobile/test/db_redesign_test.dart` (hızlı erişim 5 / 3+2, iskelet -> içerik, animasyonları azalt, bildirim satırı, tümünü okundu tek satır, yemek BuSwapIn, tercihler BuHeader).
- Ekran görüntüsü üretimi: `DB_OUT=... DB_W=390 DB_LANG=tr DB_MODES=light,dark,x13 flutter test test/redesign/db_shots_test.dart`.

---

# Tur 2: ince detay + animasyon (P2-DB)

Kurallar: yalnız `transform`/`opacity`, 150-400 ms, sürekli döngü yok, kaydırırken oynayan ağır animasyon yok, "animasyonları azalt" açıkken anında; en çok iki vurgu rengi (marka kırmızısı + mavi), yeni renk/metin/istek yok.

| # | Ekran | Bulgu | Uygulanan | Durum |
|---|---|---|---|---|
| T1 | Ana Sayfa haber şeridi | Yatay şerit kenarlarda sert kesiliyordu, kaydırma hissi düzdü | `HomeNewsStrip`: başlangıç/bitiş kenarında yumuşak solma (yalnız kaydırılabilirse görünür), başlangıç kenarından çıkan kart en çok %6 küçülür (tek `ScrollController`, kartlar yeniden kurulmaz) | Uygulandı |
| T2 | Haber kartı -> detay | Ana sayfa kartında Hero yoktu; liste Hero'sunun köşe yarıçapı uçuşta sıçrıyordu | `newsHero` (news/icerik_parts.dart): köşe yarıçapı kartta 14/23/24 dp -> kapakta 0 (geri dönüşte tersi); Ana Sayfa kartı, liste satırı/kapağı ve detay aynı etiketi (`news-img-<id>`) kullanır | Uygulandı |
| T3 | Haber detayı | Başlık çubuğu aniden beliriyordu; daralınca içerikle ayrışma yoktu | Başlık 0.25 satır yukarı kayarak + solarak belirir; daralınca ince alt çizgi (150 ms). Kapak parallax/stretch zaten vardı | Uygulandı |
| T4 | Hızlı Erişim | Karolar bir bütün olarak beliriyordu; 3 farklı ton (mavi/yeşil/aqua) | Karolar 30 ms arayla .9 -> 1 ölçek + solma (tek denetleyici, bir kez); beş karo tek vurgu tonu (mavi). Basma geri bildirimi (`BuPressable`) zaten vardı | Uygulandı |
| T5 | Etiket kısaltma | "Ders Programı"/"Timetable" dar ekranda 3+2 düzenine zorluyordu | ARB `p03HomeQuickSchedule`: tr "Program", en "Schedule", ar "الجدول" | Uygulandı |
| T6 | Yemek gün şeridi | Kapsül rengi geçiyordu ama gün/ad metni renkte sıçrıyordu; seçimde dokunsal ipucu yoktu | `AnimatedDefaultTextStyle` (150 ms), tabular rakam, seçimde `selectionClick` | Uygulandı |
| T7 | Yemek kalorisi | Toplam kalori anında yazılıyordu | `BuCountUp` ile 0'dan sayar (gün değişince), tüm kalori metinleri tabular rakam | Uygulandı |
| T8 | Yemek puanlama yıldızları | Kod `features/polls/poll_menu_card.dart` içinde (kapsam dışı) | Öneri: seçilen yıldıza `BuPop` + `selectionClick` | Uygulanmadı (kapsam dışı, raporda) |
| T9 | Bildirim satırı | Okundu olunca nokta ve kalın başlık bir anda değişiyordu | Nokta küçülerek solar (250 ms), başlık kalınlık+ton geçişi; kaydırarak silmede `lightImpact`; basma geri bildirimi zaten vardı | Uygulandı |
| T10 | Bildirim tonları | Dört renk (kırmızı/aqua/mavi/gri) | Aqua -> mavi (kırmızı yalnız beğeni, gri nötr) | Uygulandı |
| T11 | Profil | Sayaçlar anında yazılıyordu; satır simgeleri mavi + gri karışık | Sayaç `BuCountUp` + tabular rakam; 14 satır simgesi tek mavi ton; `PrefSwitch` geçişinde `selectionClick` (iz/topuz animasyonu zaten vardı) | Uygulandı |
| T12 | Arama | Öneriler <-> sonuçlar arasında sert geçiş; sonuç simgeleri 5 renk (amber dahil) | `BuFadeThrough` (anahtar: etkin mi); sonuç simge karoları tek mavi + nötr. Arama kutusu odak çerçevesi/animasyonu (`BuSearchField`) zaten vardı | Uygulandı |

Doğrulama: `mobile/test/p49_motion_test.dart` (şerit kenar solması/ölçek/azalt, karo girişi/tekrar oynamama/azalt/tek ton, Hero köşe yarıçapı gidiş-dönüş, detay çubuğu, gün şeridi renk geçişi, kalori sayacı, bildirim noktası). `home_redesign_test.dart` etiketi "Program".
Hero notu: uçuş animasyonu itişte 0 -> 1, dönüşte 1 -> 0 gider (testle doğrulandı); `newsHero` yarıçapı iki yönde `radius * (1 - a)` hesaplar. Haber Hero'su M0'ın `BuHero`'su (yeni, izlenmeyen dosya) yerine kendi küçük yardımcısını kullanır; M0 `BuHero`'yu kararlı hâle getirince geçilebilir.
Gerçek cihazda (Redmi 13C, iPhone) akıcılık ölçülemedi.

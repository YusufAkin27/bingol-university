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

---

# Tur 3 (minimal): PROFİL (P3-PROFILE)

Kapsam: `features/profile/**` (Profil sekmesi, başkasının profili, düzenleme, gizlilik, hesap, verilerim, hesap silme, engellenenler, kulüplerim) ve `features/follow/**` (takipçi/takip listeleri, öneriler). `legal_pages.dart` kapsam dışı (DA). Ölçüt: tek amaç, tek vurgu rengi, tek yüzey ailesi, tek nötr simge tonu, 20 dp yatay kenar, bol nefes.

| Ekran | Kaldırılan | Sadeleşen | Renk önce -> sonra |
|---|---|---|---|
| Profil sekmesi: kart | kırmızı avatar halkası, mavi bölüm satırı, @ simgesi | avatar + ad + bölüm/sınıf + fakülte + e-posta (soluk) + en çok 3 satır biyografi; kart köşesi 24 -> 20 (BuRadius ailesi) | kırmızı, mavi, nötr -> nötr (+ "Düzenle" soluk marka hapı) |
| Profil sekmesi: sayaçlar | 2 ayrı kart tipi (çizgili Takipçi/Takip karoları + dolgulu Kulüp/Etkinlik karoları), aqua/mavi simge dairesi, ilk sayının kırmızı vurgusu | `StatStrip` (follow_summary.dart): TEK yüzey, TEK satır, 4 hücre (Takipçi · Takip · Kulüp · Etkinlik), ince ayırıcı, sayılar `BuCountUp` + tabular, "–" yer tutucu (sayfa zıplamaz), büyük yazıda 2 x 2; etiketler "Kulüp Üyeliği" -> "Kulüp", "Etkinlik Katılımı" -> "Etkinlik" | kırmızı, aqua, mavi, nötr -> nötr |
| Profil sekmesi: listeler | 14 mavi simge karosu; "Hakkında" grubunda sürüm satırı (tıklanamaz, oksuz) | "Benim içeriğim" ve "Uygulama tercihleri" (ve Hesap, Hakkında) aynı `ProfilCard` ailesi, tek nötr simge tonu (sf2 zemin + mürekkep simge); grup başlıkları arası 24 | mavi + soluk -> nötr |
| Profil sekmesi: sonu | gri hapta simge; sürüm satırı listenin içinde | "Çıkış yap": simgesiz sakin hap (listenin en sonunda), altında soluk sürüm yazısı; onay penceresi aynı | - |
| Başkasının profili | 16 dp kenar; sayaçlar kart içinde gri kutu (kart içinde kart); Hakkında: simgeli başlık + 4 gri kutu + simge karosu; çevrimiçi için iki yeşil nokta (avatar + metin) | 20 dp kenar; sayaçlar kutusuz, ince çizgili tek satır; Hakkında: başlık + soluk etiket/değer çiftleri (kutu/simge yok); gizli alan satırı korunur; çevrimiçi yalnız avatardaki nokta | kırmızı, yeşil x2, nötr -> kırmızı (Takip et), yeşil x1, nötr |
| Profili düzenle | iki kart (kart içinde sf2 alanlar), etiket simgeleri (kullanıcı, belge, kalkan, posta), "Akademik Bilgiler" başlığı, e-posta satırında posta simgesi, kaydet düğmesinde disket simgesi | tek sütun, kartsız; alan başına tek etiket (Ad soyad, Hakkında, Bölüm, Sınıf, Kurumsal e-posta); e-posta soluk salt okunur; alt çubuk arka plan rengi | kırmızı, nötr -> kırmızı (yalnız Kaydet), nötr |
| Gizlilik ve engellenenler | 5 alan satırında mavi simge karosu | alan başına tek etiket + 3'lü seçici; tüm ayar satırları nötr ton | mavi, kırmızı, nötr -> nötr (+ kırmızı yalnız seçili hâller) |
| Hesap ve güvenlik / Ayarlar / Verilerim | mavi karolar; Verilerim'de "JSON dosyası" kartı + kırmızı onay daireleri | nötr karolar; JSON bilgisi tek soluk satır; onay işaretleri nötr | mavi, kırmızı -> nötr |
| Hesabı sil | mavi "yedek al" bilgi kutusu, düğmede simge | nötr bağlantı satırı; tehlikeli düğme simgesiz (listenin sonunda, iptal altında) | mavi, kırmızı -> nötr, kırmızı (yalnız tehlike) |
| Engellenenler | kalıcı "bilgi" kutusu (simge + gri zemin) | tek soluk açıklama satırı | nötr |
| Kulüplerim | kimliğe göre 3 renkli logo harfleri | tek nötr logo zemini | kırmızı, mavi, nötr -> nötr |
| Takipçi/takip listesi ve öneriler | satır başına dolgulu kırmızı "Takip et" yığını; kırmızı "Seni takip ediyor" noktası/metni; kırmızı öneri nedeni; seçili sekmede kırmızı sayaç rozeti | "Takip et" soluk marka zemini, "Takipte" çizgili sakin düğme (durum geçişi 150 ms); durum/öneri satırları soluk; sayaç rozeti soluk marka zemini | kırmızı yoğun -> tek soluk vurgu |

Ortak parçalar (dokunulmadı): `BuSettingsTile` nötr ton için çağıran tarafta `profilNeutralTint(context)` (profil2_widgets.dart) ile beslenir; `BuCard`, `BuPressable`, `BuCountUp` kullanıldı. Yeni animasyon eklenmedi; sayaç şeridi hücreleri `BuPressable` (ölçek .96 + hafif titreşim) ve `BuCountUp`.

Doğrulama: `mobile/test/redesign/p3_profile_test.dart` (tek şerit/tek satır/4 hücre, tek kart, büyük yazıda 2 x 2, hücre -> takipçi listesi, takip sayıları yoksa yalnız Kulüp/Etkinlik, çıkış simgesiz ve en sonda, simge tonu tek, düzenleme kartsız tek etiket, takip düğmesi stil geçişi, 9 ekran x 3 dil x açık/koyu x 1.0/1.3 x 320/390 taşma matrisi). Mevcut `profil1/profil2/profilyard/user_profile/p18/icerik` testleri değişmeden geçer.
Önce/sonra görüntüler: `C:\bu_qa\shots\tasarim\p3\profile\onceki|sonra\` (test_shots: `mobile/test/redesign/p3_profile_shots_test.dart`; `STORE_SHOTS_OUT=... P3P_LANG=tr|ar P3P_MODES=light,dark,x13`).
Gerçek cihazda (Redmi 13C, iPhone) akıcılık ve emülatörde gerçek veriyle gezi bu turda yapılamadı (emülatör kilidi/ağır makine); yalnızca widget testi + sahte veri ekran görüntüleri.

---

# Tur 3 (minimal): MENU (Yemek, Bildirimler, Bildirim tercihleri)

Ölçüt: tek amaç, az öğe, tek vurgu; yeni renk/istek yok. Önce/sonra PNG: `C:u_qa\shots	asarim\p3\menu\` ve `...\p3ildirim\` (`onceki|sonra`, tr390 açık/koyu, ar390, tr x1.3, `w320` = 320 dp x1.3).

| Ekran | Kaldırılanlar | Sadeleştirilenler | Renk (önce -> sonra) |
|---|---|---|---|
| Yemek (gün + öğle kartı) | Gün etiketi simgesi/noktası; saat simgesi; fotoğrafsız gradyanlı yer tutucu (116 dp); yemek başına gri kutu + kırmızı nokta (kart içinde kart); kalorisiz yemekte "-" rozeti; koyu (ink) toplam şeridi; "Bazı yemeklerin kalorisi..." bilgi satırı; fotoğraf üstü saat hapı | Başlık solda, saat sağda soluk; yemekler düz satır (ad solda, kcal sağda soluk/tabular); toplam: ince çizgi + "Toplam / En az N kcal" tek sakin satır (ink, kırmızı değil); kart köşesi `BuRadius.lg` | nötr + kırmızı + pembe zemin + koyu mürekkep + amber (5) -> nötr + kırmızı (yalnız seçili gün/bugün noktası) (2) |
| Yemek boş/bakım | 88 dp daire simge, kart, amber bakım hapı | Tek simge (mut) + tek cümle; bakımdaysa cümle "Sistem bakımda." + tek "Yeniden dene" | 4 -> 2 (bakım bandı üstte zaten amber, durum anlamı) |
| Bildirimler listesi | Tür etiketi hapı (renkli); koyu (ink) daire/simge ve 4 ton; "N yeni" grup sayacı; "Tümü" sayaç rozeti; "Tümünü okundu yap" simgesi + kırmızı renk; liste sonu çizgi + simge + koyu hap; "Daha fazla" gri kutu | Satır: tek mavi (bilgi) simge kutusu + başlık + gövde + sağ üstte zaman; tür etiketi yalnız ekran okuyucuda ("Okunmamış, Duyuru, 5 dk"); okunmamış = simge köşesinde tek kırmızı nokta + kalın başlık; "Tümünü okundu yap" simgesiz soluk metin; sonda iki sakin metin satırı; yüklenirken tek küçük çember | 5 (ink, kırmızı, 3 ton + zaman) -> 2 (mavi simge karosu + kırmızı nokta) |
| Bildirim boş/hata | Kart içinde kart, `wifiOff` karosu, ikinci açıklama paragrafı | Boş: kartsız illüstrasyon + tek cümle (kısaltılan ARB: "Bildirim yok", "Kulüp, etkinlik ve mesaj bildirimleri burada görünür.", "Hepsini okudun."); hata: tek cümle + "Yeniden dene" aynı satırda | 3 -> 1 |
| Bildirim tercihleri | 40 dp simge karoları (5 satır + sessiz saat + cihaz + ayrıntı); durum hapı ("Açık/Kapalı"), push kartında kırmızı kenar çubuğu ve simge, yardım bağlantısı simgesi/kırmızısı; ayrıntılı tercihler için ayrı kart; zaman kutularında 2 dp kırmızı çerçeve | Tüm satırlar tek `_row` (başlık + kısa açıklama + sağda kontrol; iç boşluk 16/12 -> anahtarlar tek sütunda hizalı, testle doğrulanır); ayrıntılı tercihler ana grubun son satırı; sessiz saat zaman kutuları nötr (kapalıyken soluk); yardım bağlantısı soluk metin; kart = nötr zemin + hafif gölge (çerçevesiz) | nötr + kırmızı (kenar/simge/bağlantı) + pembe zemin + koyu (5) -> nötr + kırmızı (yalnız açık anahtar/birincil düğme) (2) |
| Ayrıntılı tercihler | Bilgi kutusu (başlık + uzun açıklama), grup simgeleri, "Devre dışı" hapı, grup alt başlıkları, iç içe sol çizgi | Başlık "Ayrıntılı tercihler"; ana bayrak başına tek kart: üstte ana anahtar, altında ince çizgiyle alt anahtarlar (üst kapalıyken soluk) | 4 -> 2 |

Doğrulama: `mobile/test/redesign/p61_menu_notif_test.dart` (simgesiz/kalorisiz içerik, tek ton, anahtar hizası, 320 dp x1.3 x 3 dil x açık/koyu taşma matrisi: Yemek dolu/kalorisiz/boş, Bildirimler dolu/boş/hata, Tercihler + Ayrıntılı); güncellenenler: `yemek_page_test`, `notif_design_test`, `p49_motion_test`, `pages_c_test`. Ekran görüntüsü üretimi: `db_shots_test.dart` (DB_ONLY=yemek,33,bildirim) ve `p61_shots_test.dart` (Ayrıntılı tercihler).
Kapsam dışı öneri: `features/polls/poll_menu_card.dart` (yemek puanlama kartı) DD klasöründe; Yemek ekranının geri kalanıyla aynı sadelikte olması için kart çerçevesi `BuRadius.lg` ve yıldızlarda tek vurgu önerilir.
Emülatör gezisi ve gerçek cihazda akıcılık doğrulanamadı.

---

# Tur 3 (minimal): Ana Sayfa (P3-HOME)

Amaç: tek bakışta "bugün ne var"; bölüm ve başlık gürültüsü az, tek yüzey ailesi, tek vurgu. Davranış/API değişmedi (yeni uç yok). Dosyalar: `mobile/lib/features/home/*`. ARB öneki `p60`.

| Ekran / parça | Kaldırılan | Sadeleşen | Renk (vurgu kullanımı) önce -> sonra |
|---|---|---|---|
| Üst çubuk | Logo karosu, "Bağımsız öğrenci uygulaması" alt başlığı, ayrı selamlama bloğu (zaman selamı + ad) | "BÜ KAMPÜS" + "Merhaba, Ad" tek blok; zil, profil ve ana sayfa düzenleme düğmesi sağda (~104 dp -> ~48 dp yüksekliğinde) | kırmızı 3 nokta (logo, yazı, çizgi) -> 1 (yazı) |
| Günün menüsü (vitrin) | Rozet hapı, saat hapı, yemek iç paneli + madde noktaları, "Menü Detayı" hapı | Künye tek satır ("Öğle Yemeği • 4 çeşit · 11:30 – 14:00"), 3 yemek düz satır, "Menü Detayı" düz bağlantı; köşe 28 -> 20 (BuRadius.lg) | kırmızı gradyan + 4 saydam beyaz yüzey -> kırmızı gradyan (tek) |
| Menü boş hâli | 44 dp daire simge, ikinci metin satırı (açıklama) | Tek satır: simge + "Bugün için liste yok" + ok | nötr |
| Hızlı Erişim | "Hızlı Erişim" başlığı, her karoda çerçeveli kart (kart içinde kart), karo 3 ton ailesi (önceki tur) | Çerçevesiz karo: yumuşak mavi simge karosu + etiket; kısayollar kullanıcının seçimi (5 slot) | mavi (tek) -> mavi (tek) |
| Öne çıkan haberler | Görsel üstü tür rozeti, kart altı ok, gradyan yedek görsel | Görsel + başlık + tarih; görselsiz kartta nötr yüzey; kart köşesi 24 -> 20; şerit yüksekliği kart ölçüsüyle birebir | kırmızı 4 nokta (rozet, ok, gradyan, "Tümü") -> 0 |
| "Tümü" bağlantıları | Kırmızı kalın metin | Sakin metin düğmesi: soluk renk + küçük ok, 48 dp dokunma alanı | kırmızı -> nötr |
| Yaklaşan etkinlik | Düzenleyen için dolgulu şerit, kırmızı konum simgesi | Düzenleyen küçük soluk satır, konum simgesi nötr | kırmızı 4 -> 2 (tarih karosu, "Katıl") |
| Etkinlik boş / hata | Başlık satırı + iç kutu + 56 dp simge + açıklama + düğme (~230 dp) | Tek satır (simge + cümle + ok ya da "Tekrar dene" metin düğmesi) | nötr |
| Haber boş / hata | İç içe kart + kırmızı bant + dış çizgili düğme | Tek satır, aynı bileşen (`HomeEmptyCard`) | nötr |
| İskelet | Eski yerleşim | Yeni yerleşimle birebir (tek iskelet tipi) | nötr |

Metin: "Henüz içerik yok." -> "İçerik yok."; "Kaynak site şu an ulaşılamıyor; veriler güncel olmayabilir." -> "Kaynak siteye ulaşılamıyor; veriler eski olabilir." (en/ar karşılıkları da kısaltıldı).

## Özelleştirilebilir Ana Sayfa (P3-HOME-2)

- **Model** (`home_layout.dart`): kimlikli bölümler `menu, quickAccess, featuredNews, upcomingEvents, announcements, todayClasses`; her biri görünür/gizli + sıra. Varsayılan = önceki sabit düzen (duyurular ve bugünkü dersler kapalı gelir). Kısayol havuzu (11): Haberler, Yemek, Etkinlikler, Anketler, Program, Kulüpler, Sohbet, Destek, Arama, Bildirimler, Favoriler; 5 slot, son açık kısayol kapatılamaz.
- **Düzenleme** (`home_layout_sheet.dart`): başlıkta `slidersHorizontal` düğmesi ya da bölüm başlığına uzun basma -> alt sayfa: `ReorderableListView` (uzun basıp sürükle; kaldırılmış satır gölgesi), her satırda yukarı/aşağı düğmesi (adlı tooltip, sınırda pasif), anahtar, Hızlı Erişim satırı seçiciyi açar; "Varsayılana dön", "Bitti". Değişiklik anında uygulanır (arkadaki sayfa canlı değişir). Gizleme/gösterme `AnimatedSize` + `AnimatedSwitcher` (yazı ölçeği/animasyonları azalt: anında).
- **Kalıcılık**: yalnız yerel, güvenli depo anahtarı `home_layout`; kayıt kullanıcı kimliğini taşır (başka kullanıcıda varsayılan); varsayılan düzen kayıt tutmaz; bozuk/eski kayıt varsayılana düşer; bilinmeyen kimlikler atılır, yeni bölüm/kısayol sona eklenir. Çıkış/hesap silme/oturum iptalinde `registerUserDataCleaners` ile silinir (`core/user_data.dart`, KVKK).
- **Ağ**: gizli bölümün verisi hiç istenmez (menü, etkinlik, haber/duyuru, `GET /timetable`); bölüm sonradan açılınca o an istenir. Sıra değişimi veri yüklemesini bozmaz. Yeni uç yok.
- **Boş durum**: bütün bölümler gizliyse "Ana sayfan boş" + "Bölüm ekle".
- **Bekleyen**: Stitch tasarımı (ad0d7e6e0f4b592ff) gelince düzenleme sayfasının görünümü birebir uygulanacak; işlev hazır.

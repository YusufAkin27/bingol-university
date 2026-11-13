# Animasyon denetimi: campus-group

Kapsam: `mobile/lib/features/{academic,clubs,events,home,menu,news,notifications}`. Yöntem: kaynak taraması (Animated*/Tween/Hero/BuStagger*/BuPressable/BuSwapIn/BuCountUp sayımı + ana sayfaların elle incelenmesi). Ortak dosyalara (core/, widgets/) dokunulmadı.

## Genel bulgu
Kapsamdaki sayfaların çoğu ortak hareket sistemini zaten kullanıyor (liste girişleri `BuStaggerItem/BuStaggeredList`, iskelet geçişi `BuSwapIn/BuFadeThrough`, basma `BuPressable`). Boşluklar küçük ve belirli yerlerde.

| Sayfa | Dosya (yaklaşık satır) | Mevcut | Eksik/zayıf | Durum |
|---|---|---|---|---|
| Akademik hub | academic/academic_hub_page.dart:~100 | yok (düz ListView) | Giriş animasyonu yok | YAPILDI: blok + 3 gezinme satırı `BuStaggerItem` (kapsamlı) |
| Akademik satır (AcadRow, takvim/sınav/program/ayarlar satırları) | academic/acad_ref_widgets.dart:~167 | yalnız InkWell dalgası | Basma ölçek geri bildirimi yok | YAPILDI: `BuPressable(.985)` |
| Sıradaki sınav bloğu | academic/acadhub_widgets.dart:~27 | InkWell | Basma geri bildirimi | YAPILDI |
| Yoklama listesi | events/etkinlik2_attendance_page.dart:~349 | yok | Liste girişi, durum değişiminde rozet sıçraması yok, satır basma yok | YAPILDI: `BuStaggerItem` (ilk 8), rozet `AnimatedContainer` 150 ms + `BuPopIcon`, satır `BuPressable` |
| Ders programı / sınavlar / takvim | academic/timetable_page.dart, exams_page.dart, academic_calendar_page.dart | stagger, swap, press mevcut | - | Değişmedi |
| Kulüpler (sekme, detay, üyeler, istekler) | clubs/* | stagger + swap var | clubs_tab/club_detail/members/requests satırlarında `BuPressable` yok (InkWell dalgası var); detay sayfası bölümleri sırayla girmiyor | ÖNERİ (dokunulmadı) |
| Etkinlik detayı | events/event_detail_page.dart:~540 | swap + press | Bölümlerde (başlık, bilgi, katılımcılar) aşamalı giriş yok; 1300+ satır, yapı riskli | ÖNERİ |
| Etkinlik listesi | events/events_page.dart | stagger, swap, press, Animated var | - | Değişmedi |
| Ana sayfa | home/home_tab.dart | stagger + swap | kart basma (BuPressable) yok | ÖNERİ |
| Yemek | menu/menu_page.dart, menu_parts.dart | gün şeridi AnimatedContainer, gün değişiminde BuFadeThrough, toplam kcal BuCountUp, iskelet BuSwapIn | - | İyi durumda, değişmedi |
| Haberler | news/* | stagger, swap, press, Hero | - | Değişmedi |
| Bildirimler | notifications/* | stagger, press, swap | - | Değişmedi |

## Ortak dosyalar için öneriler (uygulanmadı)
- `BuPressable` yalnız ölçek istediğinde (`onTap == null`) `InkWell` ile birlikte kullanılabiliyor; çok sayıda satır için `BuInkPress` gibi tek sarmalayıcı (InkWell + ölçek) sadeleştirir.
- `BuStaggerItem` yatay kaydırmalı şeritler için ayrı bir `axis` parametresi alabilir.

## Performans notları
Eklenenler yalnız opacity/transform (BuStaggerItem, BuPressable, BuPopIcon) ve 150 ms renk/kenarlık geçişi; sonsuz döngü, blur, gölge, saveLayer yok. "Animasyonları azalt" açıkken hepsi anlık (`BuMotion.reduced/of`).

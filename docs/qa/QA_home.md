# QA alani 2: Ana sayfa, haberler, yemek, akademik, arama, bildirimler, anketler

Tarih: 2026-11-06. Dal: mobil `qa/home-20261106`, backend `qa/home-be-20261106` (backend degisikligi yok).
Kapsam bu turda KOD INCELEMESI ve hedefli regresyon testleriyle sinirli kalmistir; alan buyuk (yaklasik 20 bin satir, 60 dosya).
Tam envanter satir satir cikarilmadi: asagidaki tablo ekran duzeyindedir, ayrinti turu "sonraki tur" listesindedir.

## 1. Envanter (ekran duzeyi)

| Alan | Ekran / bilesen | Durumlar | Mevcut test | Bu turda |
|---|---|---|---|---|
| Ana sayfa | `HomeTab` (+ `home_parts`, `home_clubs`, `home_suggestions`, `HomeLayout` sheet) | yukleniyor/bos/hata/bakim, kisisellestirme | home_redesign, home_v5, home_layout, home_clubs, home_suggestions | selamlama saati duzeltildi |
| Haberler | `NewsListPage`, `NewsDetailPage` | sekme, sayfalama, yenile, bakim bandi, favori | icerik_test, p63_news_search_test | sayfalama/yenile/tekrar dene duzeltildi + 4 test |
| Birim haberleri | MOBILDE YOK | - | - | B-05 |
| Yemek | `MenuPage`, `MenuMealCard`, `MenuTopUpCard`, `PollMenuCard`, `HomeMenuRating` | gun secici, bos, hata, bakim, kalori | yemek_page, menu_photo, menu_topup | Istanbul gunu + gece yarisi duzeltildi + test |
| Akademik | hub, takvim, ders programi, sinavlar, hatirlatmalar, kutuphane | - | academic_*, akad_design | yalniz incelendi (`istanbulWall` kullaniliyor, tutarli) |
| Arama | `SearchPage`, `GlobalSearchScreen`, son aramalar | debounce, seq korumasi, sekmeler | global_search, p63 | incelendi: bayat yanit korumasi var |
| Favoriler | `SavedNewsPage` (profile), haber kaydet | cift dokunus, hata geri alma | icerik_test | cift dokunus korumasi eklendi |
| Bildirimler | `NotificationsPage`, `resolvePushTarget` | filtre, sayfalama, okundu, sil, yonlendirme | notif_*, push_* | yonlendirme duzeltildi + 4 test |
| Anketler | `poll_*`, `club` kilidi | - | anket_test, club_polls_lock | calistirildi, yesil |

## 2. Bulgular

| Id | Siddet | Tur | Ekran | Adim | Beklenen / gercek | Kok neden | Durum |
|---|---|---|---|---|---|---|---|
| B-01 | yuksek | HATA | Haber listesi | Alta kaydir, sayfa 2 hata ver, altbilgideki "Yeniden dene" | Tekrar dener / hicbir sey olmaz | `_loadMore` `_error != null` iken geri donuyor, altbilgi dugmesi de onu cagiriyor: olu dugme | DUZELTILDI (`_retryMore`) |
| B-02 | yuksek | YANLIS MANTIK | Haber listesi | Birkac sayfa yukle, cekerek yenile, yenileme hata versin, tekrar kaydir | Sonraki sayfa gelir / sayfa 0 yeniden cekilip ilk haberler KOPYALANIR | `_refresh` basari gelmeden `_page = 0` yapiyordu | DUZELTILDI (sayfa yerel hesap) + test |
| B-03 | orta | YANLIS MANTIK | Haber listesi | Sayfalar arasinda yeni haber girer (offset kaymasi) | Ayni haber iki kez cizilmez / kopya | kimlik tekillestirmesi yoktu | DUZELTILDI + test |
| B-04 | orta | HATA | Haber listesi | Sunucu `id`siz/bozuk oge dondurur | Oge atlanir / `as num` ile tum liste hata ekranina duser | tur donusumu | DUZELTILDI + test |
| B-05 | yuksek | EKSIK OZELLIK | Birim haberleri | - | Backend `GET /api/news/unit` var (V1050), mobilde hic cagrilmiyor | Mobil ekran yazilmamis | KARAR BEKLIYOR (yeni ekran; bolum eslesmesi bos ise hicbir sey cizmeme kurali uygulanmali) |
| B-06 | orta | HATA | Yemek | Cihaz saat dilimi Istanbul degil (yurt disi) | Menu gunu kampus gunu / cihaz gunu | `DateTime.now()` | DUZELTILDI (`menuToday`) + test |
| B-07 | orta | HATA | Yemek | Sayfa gece yarisini asarak acik kalir | Bugun yeni gune gecer / eski gun "Bugun" kalir, gun seridi bayat, puanlama karti yanlis gunde | gun listesi `initState`te bir kez | DUZELTILDI (`_rollOverIfNeeded`) |
| B-08 | orta | YANLIS MANTIK | Bildirim yonlendirme | `targetType=POLL/EVENT...` + `communityId`, `pollId/eventId` yok | Anket/etkinlik acilir / kulup acilir | `communityId` onceligi yalniz POST'u disliyordu | DUZELTILDI (yalniz COMMUNITY/bos tur) + test |
| B-09 | dusuk | HATA | Ana sayfa | Selamlama (gunaydin/iyi aksamlar) | Kampus saati / cihaz saati | `DateTime.now().hour` | DUZELTILDI |
| B-10 | dusuk | YANLIS MANTIK | Bildirimler | "Bugun/Dun" grup basliklari, "x saat once" | Kampus gunu / cihaz yerel saati | `.toLocal()` | ACIK (dusuk: yurt disi kullanici) |
| B-11 | dusuk | YANLIS MANTIK | Haber bakim bandi | "Son guncelleme" saati | Istanbul / cihaz yerel | `.toLocal()` | ACIK (dusuk) |
| B-12 | dusuk | YANLIS MANTIK | Bildirimler | "Tumunu okundu yap" okunmamis filtresi acikken | Liste bosalir / satirlar okunmus ama listede kalir | yalniz yerel bayrak | ACIK (dusuk) |
| B-13 | dusuk | OLU KOD | push_targets | `PushDest.signOut` | Uretilmiyor, yalnizca bildirim sayfasi bakiyor | belgelenmis | ACIK |
| B-14 | dusuk | KIRIK TEST | p63_news_search_test | "Haber detayi (18/19) kapakli" | Gecer / base dalda da KIRIK (bu turun degisikligi degil) | duzen sabiti degismis | ACIK (alan disi: haber detay tasarimi) |

## 3. Bu turda yazilan testler (`mobile/test/qa_home_test.dart`, 10 test)
Bozuk haber ogeleri, sayfalama kopyasi, yenileme hatasi sonrasi sayfa sayaci, son sayfada ek istek yok, `menuToday` (UTC/Istanbul sinirlari, ay sonu), 4 bildirim hedefi testi, yemek sayfasi sunucu hatasi + yeniden dene. Dogrulama: duzeltme olmadan 2 test kirilir (B-02, B-03), duzeltmeyle 10/10 gecer.

## 4. Sonraki tur (yapilmadi)
Satir satir dugme/sheet envanteri; 401/403/429/5xx, bakim modu ve guncelleme-zorunlu durumlarinin etkilesimli testleri; tr/en/ar + RTL + yazi olcegi 1.3 matrisi; akademik takvim/ders programi/sinav formu akislari; anket olusturma formu; arama sekme sayfalamasi; ETag/304 onbellek davranisi (`core/api.dart`); backend sozlesme taramasi (`academic`, `search`, `poll`, `status`).

# QA alani 2: Ana sayfa, haberler, yemek, akademik, arama, bildirimler, anketler

Tarih: 2026-11-06 (2 tur). Dal: mobil `qa/home-20261106`, backend `qa/home-be-20261106`.

## 1. Envanter (ekran duzeyi, her satir icin test kapsami)

| Alan | Ekran / bilesen | Durumlar | Test |
|---|---|---|---|
| Ana sayfa | `HomeTab` (+ `home_parts`, `home_clubs`, `home_suggestions`), selamlama | yukleniyor/bos/hata/bakim | home_redesign, home_v5, home_clubs, home_suggestions |
| Ana sayfa kisisellestirme | `HomeLayout` (sirala/gizle/kisayol), `HomeLayoutStore`, sheet | bozuk/eski/baska kullanici kaydi -> varsayilan, yeni bolum eklenir | home_layout_test (+ kod incelemesi: `fromJson` guvenli) |
| Haberler | `NewsListPage` (3 sekme, sayfalama, yenile, bakim bandi, favori, arama) | tum durum matrisi | icerik_test, p63, qa_home_test, qa_home_matrix_test |
| Haber detay | `NewsDetailPage` | kapakli/kapaksiz/etkinlik/hata | p63 |
| Birim haberleri (Bolumum) | `UnitNewsStrip` + `UnitNewsDetailPage` (YENI, Duyuru sekmesi) | bos/401/5xx/cevrimdisi/bozuk -> HICBIR SEY cizilmez | qa_home_matrix_test (9 test) |
| Yemek | `MenuPage`, kart, kalori, `MenuTopUpCard`, `PollMenuCard`, `HomeMenuRating` | gun gecisi, ay gecisi, bos, hata, bakim | yemek_page, menu_*, qa_home_test, matrix |
| Akademik | hub, takvim, ders programi (`TimetablePage` + `CourseFormPage`), sinavlar (`ExamFormPage`), hatirlatma, kutuphane, takvim eslestirme | - | academic_*, akad_design, calendar_alarm; zaman her yerde `istanbulWall` |
| Arama | `SearchPage`, `GlobalSearchScreen`, son aramalar, `searchFold` | debounce 300/350 ms, `_seq` ile bayat yanit korumasi, sekmeler | global_search, p63, matrix |
| Favoriler | haber kaydet/kaldir, `SavedNewsPage` | cift dokunus, hata geri alma | icerik_test, qa_home_test |
| Bildirimler | `NotificationsPage`, kategori/okunmamis filtre, okundu, sil, `resolvePushTarget` | tum matris | notif_*, push_*, qa_home_matrix_test |
| Anketler | `PollListPage`, `PollDetailPage`, `PollFormPage`, `PollSelection` (SINGLE/MULTI/RATING/RANKED), kulup anketi kilidi | kapanis (`isClosed`), gizli oy, sonuc gorunurlugu sunucuda | anket_test, club_polls_lock, matrix |
| API katmani | `core/api.dart` ETag/304 LRU, tek ucuslu refresh, 401 tekrar | cikista `clearCache` (bellek+disk) | api_cache_test, api_test |

Durum matrisi (`qa_home_matrix_test.dart`): 6 ekran x 7 senaryo (bos, 401, 403, 429, 5xx, cevrimdisi, bozuk govde) x (320, 390 dp) x (acik-LTR, koyu-RTL) x yazi olcegi 1.3 = 168 test. tr/en/ar metin matrisi mevcut `*_design`/`l10n_test` dosyalarinda.

## 2. Bulgular

| Id | Siddet | Tur | Ekran | Beklenen / gercek | Kok neden | Durum |
|---|---|---|---|---|---|---|
| B-01 | yuksek | HATA | Haber listesi | Altbilgi "Yeniden dene" calismiyordu | `_loadMore` hata varken donuyordu | DUZELTILDI + test |
| B-02 | yuksek | YANLIS MANTIK | Haber listesi | Yenileme hatasi sonrasi sayfa 0 yeniden cekilip kopya | `_page=0` basaridan once | DUZELTILDI + test |
| B-03 | orta | YANLIS MANTIK | Haber listesi | Sayfa kaymasinda kopya haber | id tekillestirmesi yok | DUZELTILDI + test |
| B-04 | orta | HATA | Haber listesi | Bozuk/idsiz oge tum listeyi dusuruyor | `as num` | DUZELTILDI + test |
| B-05 | yuksek | EKSIK OZELLIK | Birim haberleri | Backend var, mobil yok | ekran yazilmamis | DUZELTILDI: Duyuru sekmesinde "Bolumum" seridi + detay (`unit_news.dart`); eslesme/hata/bos -> hicbir sey cizilmez |
| B-06 | orta | HATA | Yemek | Menu gunu cihaz saatine gore | `DateTime.now()` | DUZELTILDI (`menuToday`, Istanbul) + test |
| B-07 | orta | HATA | Yemek | Gece yarisi asan sayfa eski gunde | gun listesi bir kez kuruluyordu | DUZELTILDI (`_rollOverIfNeeded`) |
| B-08 | orta | YANLIS MANTIK | Bildirim yonlendirme | `communityId` anket/etkinlik hedefini kulube cevirir | oncelik sirasi | DUZELTILDI + test |
| B-09 | dusuk | HATA | Ana sayfa | Selamlama cihaz saati | `DateTime.now().hour` | DUZELTILDI |
| B-10 | dusuk | YANLIS MANTIK | Bildirimler, haber tarihleri | "Bugun/Dun", gun farki ve `newsLocalDate` cihaz yerel saatiyle | `.toLocal()` | DUZELTILDI (`istanbulWall`; ofsetsiz yyyy-MM-dd aynen) + test |
| B-11 | dusuk | YANLIS MANTIK | Haber bakim bandi | "Son guncelleme" yerel saat | `.toLocal()` | DUZELTILDI |
| B-12 | dusuk | - | Bildirimler | Okunmamis filtresi + "Tumunu okundu yap" | Istemci suzgeci okunmus satirlari zaten dusuruyor | YANLIS ALARM: dogrulandi, regresyon testi eklendi |
| B-13 | dusuk | OLU KOD | push | `PushDest.signOut` | uretilmiyordu | TEMIZLENDI (enum, router, bildirim sayfasi) |
| B-14 | dusuk | KIRIK TEST | p63 haber detay | Beklenti eski tasarima gore | govde artik `LinkifiedText`; baslik Text'i coklu | TEST GUNCELLENDI (gercek hata degil) |
| B-15 | dusuk | IYILESTIRME | Anket/ana sayfa | Yil karsilastirmasi cihaz saatiyle | - | ACIK (etkisiz) |
| B-16 | dusuk | IYILESTIRME | Anket formu | Secenek tekrar denetimi `toLowerCase` (I/ı) | Turkce buyuk/kucuk | ACIK (cok dusuk) |
| B-17 | orta | IYILESTIRME | Ana sayfa | "Bolumum" Ana Sayfa bolumu (HomeLayout) olarak yok, yalniz Duyuru sekmesinde | yeni `HomeSection` kayit gocu/UI ister | KARAR BEKLIYOR |

## 3. Backend taramasi (`news`, `menu`, `unitnews`, `bookmark`, `search`, `notification`, `poll`, `academic`, `status`, `appinfo`)
Okuma duzeyinde tarandi (kontrolculer, hiz sinirlari, sayfa/limit sinirlari, zaman dilimi, siralama, yetki): kusur bulunmadi.
- Sayfa/limit sinirli (`MAX_PAGE`, `MAX_PAGE_SIZE`, arama `MAX_LIMIT 20`, `MAX_OFFSET 1000`), siralama kararli (`publishedDate DESC NULLS LAST, id DESC`).
- Aramada IP basina 30/dk; yer imi yazma 60/dk, okuma 120/dk; menu/haber manuel senkron saatte 3.
- Zamansiz `LocalDate.now()` / `systemDefault` yok; menu `Europe/Istanbul`.
- `/api/news/unit/**` guvenlik kuralinda `authenticated` (anonim 401, `UnitNewsControllerTest`).
- Backend kod degisikligi ve migration YOK; backend deploy gerekmez.

## 4. Kalan sinirlar
Dugme dugme sheet/dialog envanteri, akademik form akislarinin (ders ekle/duzenle/sil, sinav formu, takvim esleme) yeni etkilesimli testleri, en/ar metin dogrulamasi ve gercek cihaz/emulator denemesi yapilmadi; mevcut testler yesil kalmaya devam ediyor.

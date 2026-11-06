# QA alani 3: Gonderiler / Kesfet / Reels / Paylas / Begeni / Takip / Engel (2026-11-06)

Dallar: mobil `qa/posts-20261106`, backend `qa/posts-be-20261106` (taban `deploy/release4-20261106`).
Kapsam notu: bu tur kod incelemesi + etkilesimli widget testi + backend servis testi. Gercek cihaz/emulator turu YAPILMADI
(ana oturumun emulatoru kullanilmaz kurali). Alan cok genis oldugu icin inceleme DERINLIK ONCELIKLI yapildi: begeni, engel,
menu, takip duzu, yayin akisi, medya sinirlari, rate limit, yetki uclari. Kapsanmayan ogeler "Kalan is" bolumundedir.

## 1. Envanter (ozet; durum = bu turdaki kapsama)

| Ekran / oge | Dosya | Durum |
|---|---|---|
| Begeni kalbi + sayac (dokunus, sayac dokunusu, debounce 250 ms, iyimser, geri alma + tekrar dene) | posts/like_button.dart | TEST (qa_posts_test) |
| Cift dokunus begeni (DoubleTapLike, LikeController.like) | like_button.dart | TEST (idempotent) |
| Kesfet masonry (kutu, sayfalama, onyukleme, bayat/cevrimdisi notu) | discover/* | mevcut testler + BlockBus testi |
| Gonderi sayfasi (dikey akis, onceki/sonraki, silme/engel) | posts/post_detail_page.dart | mevcut testler + BlockBus |
| Reels (dikey video, ilgilenmiyorum, takip) | reels/reels_feed.dart | mevcut testler (qa_so_reels) + BlockBus |
| Gonderi menusu (Duzenle/Sil/Profil/Sikayet/Engelle/Paylas/Ilgilenmiyorum) | posts/post_actions.dart | INCELEME + duzeltme (404 silme) |
| Paylas (+): galeri secici, kamera, kirpma, video kirpma/kapak, metin, @bahsetme, yayin | posts/compose_post_page.dart + ilgili | INCELEME (testler mevcut: post_gallery_picker, post_mentions) |
| Takip dugmesi (NONE/REQUESTED/FOLLOWING, gizli hesap) | follow/follow_button.dart | INCELEME (followreq_test mevcut) |
| Takipci/takip listeleri, istekler, oneriler | follow/* | mevcut testler |
| Kaydet / Begendiklerim | posts/liked_posts_page.dart | mevcut test (liked_posts_test) |
| PinchZoomable | widgets/pinch_zoom.dart | mevcut test (pinch_zoom_test) |
| Alt cubuk "+" | shell/floating_nav.dart | KAPSAM DISI (kalan is) |

## 2. Bulgular

| id | siddet | tur | ekran | adim | beklenen / gercek | kok neden | duzeltme |
|---|---|---|---|---|---|---|---|
| QA-P-01 | yuksek | YANLIS MANTIK | Kesfet / Reels / Gonderi sayfasi | Gonderi menusu > "Bu kullaniciyi engelle" | Beklenen: engellenen yazarin TUM gonderileri akistan hemen kalkar. Gercek: yalniz tiklanan gonderi kalkar, ayni yazarin diger kutulari/reelleri yenilemeye kadar gorunur kalir | `onDeleted` tek gonderi kimligi tasir | DUZELTILDI: `block_bus.dart` (BlockBus); engel sonrasi 3 akis yazarin tum gonderilerini dusurur. Test: qa_posts_test "BlockBus" |
| QA-P-02 | orta | HATA | Begeni dugmesi | Dokun, istek ucustayken tekrar dokun, istek donmeden ekrandan cik | Son niyet (vazgec) sunucuya gitmeli. Gercek: ucus sonrasi `!mounted` donusu bekleyen niyeti atiyordu; begeni sunucuda yanlis kalir | `_flush` ucus sonrasi `if (!mounted) return` | DUZELTILDI: bekleyen fark fire-and-forget gonderilir. Test: "ucustayken ekrandan cikis" |
| QA-P-03 | orta | YANLIS MANTIK | Gonderi menusu > Sil | Gonderi baska yerden/yonetici tarafindan silinmisken Sil | Beklenen: sonuc ayni, akistan dussun. Gercek: 404 hata toast'i, hayalet gonderi kalir | `_confirmDelete` 404'u hata sayar | DUZELTILDI: 404 = silindi (idempotent), `onDeleted` + basari toast'i |
| QA-P-04 | orta | HATA (backend) | Begeni geri alma | Yazar engellenir/gonderi gizlenir/hesap gizli olur, kullanici eski begenisini geri almak ister | Beklenen: kendi begeni satiri silinir, sayac duser. Gercek: `DELETE /posts/{id}/like` 404, begeni kalici takilir, sayac sisik kalir | `unlike` gorunurluk kapisini once uyguluyordu | DUZELTILDI (backend): kendi satiri her zaman silinir; satir yoksa ve gorunmuyorsa 404. Test: `PostLikeServiceTest.unlikeStillWorksAfterAuthorBecomesInvisible` |
| QA-P-05 | orta | TEST HATASI | Gonderi sayfasi | `p3feed_test` "tam ekran" | Test, kaldirilan tek dokunusla tam ekran gorunumunu bekliyordu (kalici kural: tek dokunusta tam ekran YOK) | Eski test | DUZELTILDI: test kurala cevrildi (tek dokunus tam ekran acmaz) |
| QA-P-06 | dusuk | YANLIS MANTIK (belge) | CLAUDE.md `post` satiri | - | Belge "en cok 7 kelime/60 karakter" der; kod (mobil + sunucu) 2200 karakter/40 satir gizli ust sinir uygular, sayac/uyari yok | Belge eski | KARAR VERILDI + DUZELTILDI (tur 2): CLAUDE.md `post` satiri guncellendi (2200 karakter/40 satir); sunucu 7/60'a CEKILMEDI |
| QA-P-07 | dusuk | IYILESTIRME | Paylas yayini | `POST /posts` zaman asimi/5xx: sunucu gonderiyi olusturmus olabilir, kullanici tekrar dener | Tekrar denemede `POST_MEDIA_INVALID` (medya zaten bagli) gorunur; yazim aslinda basarili. Cift gonderi olusmaz (medya baglama korur) ama kullaniciya yanlis hata gosterilir | Idempotency-Key yok | DUZELTILDI (tur 2): backend V1540 `post.idempotency_key` + kismi benzersiz indeks, `POST /posts` `Idempotency-Key` (ayni anahtar ayni gonderi, yarista kazanan satir, silinmis gonderinin anahtari 422, bicim hatasi 400); mobil: paylasma niyeti basina tek anahtar. Testler: `PostIdempotencyTest`, `qa_posts2_test` |
| QA-P-08 | dusuk | IYILESTIRME | FollowStateButton | Istek suresince ust widget durumu degisirse | `didUpdateWidget` `_busy` iken esitlemez; bitince bayat durum kalabilir | `_busy` korumasi | DUZELTILDI (tur 2): ertelenen dis durum istek bitince uygulanir. Test: qa_posts2_test |
| QA-P-09 | dusuk | BELGE | docs/DEPLOY.md:51 | - | "MULTIPART_MAX_FILE=45MB" yazar; compose/prod ornek 52MB (gonderi videosu 50 MB sinirina uyar) | Belge eski | DUZELTILDI (tur 2): DEPLOY.md 52MB |
| QA-P-10 | dusuk | IYILESTIRME | Begeni dugmesi | 404/403 (silinmis/engelli gonderi) ile begeni | "Tekrar dene" toast'i sonsuz basarisiz olur | Hata kodu ayrimi yok | DUZELTILDI (tur 2): 404/403'te Tekrar dene eylemi yok. Test: qa_posts2_test |

Incelenip SORUN BULUNMAYANLAR (kanit: kod okuma + test): begeni PUT/DELETE idempotent ve atomik (INSERT ... WHERE NOT EXISTS, sayac ayni
transaction, yaris testi mevcut); sayac negatife dusmez (`GREATEST`, istemci `max(0)`); gonderi yazma/silme yetkisi (yalniz yazar, baskasininki
403/404, yonetici icin CONTENT_HIDE izni + denetim); rate limit tum yazma uclarinda var (create 20/sa, begeni 120/dk, takip 60/dk + 500/gun, yukleme 30/sa);
engel iliskisinde takip/istek dusurulur (`BlockService.dropFollowRelations`); gizli hesap: `PrivateAccountGate` gorunurlukte; video sinirlari
mobil/sunucu uyumlu (60 sn + 500 ms tolerans, 50 MB); EXIF temizligi `MediaService` hattinda.

## 3. Ikinci tur: ek bulgular ve olcumler

| id | siddet | tur | sonuc |
|---|---|---|---|
| QA-P-11 | bilgi | OLCUM | Kesfet masonry 240 gonderi / 28 derin kaydirma: ekrandaki kutu sayisi < 40 (tembel; liste boyutundan bagimsiz). Test: qa_posts2_test |
| QA-P-12 | bilgi | OLCUM | Reels 220 video / 40 kaydirma: canli oynatici <= 4 (aktif + onceki + sirada + gecis), widget kaldirilinca 0 (sizinti YOK). Not: oynatici dispose'u asenkron; testte `runAsync` ile beklenir |
| QA-P-13 | bilgi | INCELEME | PostRank formulu (log-olcekli beğeni/yorum/takipci/hiz/izlenme, yari omurlu sonum, soguk baslangic, rapor cezasi + ust sinir), yazar cesitliligi (kayipsiz), tekrar gostermeme (gorulmus kumesi + geri donusum), engelli/gizli/silinmis/askida/gizli hesap/kendi gonderisi filtreleri: mevcut `PostRankTest` + yeni `PostFeedVisibilityTest` ile kapsandi, hata bulunmadi |

## 4. Calistirilan testler

- Mobil yeni: `mobile/test/qa_posts_test.dart` (10), `mobile/test/qa_posts2_test.dart` (41: Idempotency-Key, begeni durum matrisi 401/403/404/429/500/503, 404'te tekrar dene yok, FollowStateButton ertelenmis durum, video 59/60/61 sn + 50 MB, metin 2200/40 kirpma, Kesfet 240 ve Reels 220 olcumleri, kullanici profili 6 durum x 2 boyut x 2 tema x yazi 1.3).
- Backend yeni: `PostLikeServiceTest.unlikeStillWorksAfterAuthorBecomesInvisible`, `PostIdempotencyTest` (3), `PostFeedVisibilityTest`.
- Mevcut testler (kapsam kaniti): liquid_glass_nav_test (cam/opak yedek, esneme, surukleme RTL, yetersiz surukleme, "+" esnetmez, 320/390, x1.3, reduce-motion/highContrast parametreleri), floating_nav_test, post_gallery_picker_test (izin reddi, sinirli erisim, kamera, album, sayfalama, RTL, 320/390 x1.3 x acik/koyu), followreq_test (gizli hesap: istek gonder/geri cek/onay/ret, kilit blogu, liste kilidi, bildirim), user_profile_test (404, hata, engel, sikayet), pinch_zoom_test, discover_*/kesfet2 (tr/en/ar, 320/390, x1.3), qa_so_reels_test, liked_posts_test, post_mentions_test.

## 5. Envanter (ekran / buton / jest: test edildi mi, sonuc)

| Ogeler | Test | Sonuc |
|---|---|---|
| Begeni kalbi, sayac dokunusu, debounce, iyimser, geri alma, hizli art arda | qa_posts_test, qa_posts2_test | gecti; QA-P-02/10 duzeltildi |
| Cift dokunus kirmizi kalp, tek dokunus tam ekran YOK | qa_posts_test (controller), p3feed_test | gecti |
| Kesfet masonry: yukleme/bos/hata/sayfalama/cevrimdisi notu | discover_masonry_test, discover_stream_test | gecti |
| Kesfet buyuk liste (240) | qa_posts2_test | gecti (bellek sabit) |
| Gonderi sayfasi (dikey akis, ust/alt, silme, engel) | discover_stream_test, p3feed_test, qa_posts_test | gecti; QA-P-01 duzeltildi |
| Reels (video, onyukleme, takip, ilgilenmiyorum), 220 video | qa_so_reels_test, qa_posts2_test | gecti; sizinti yok |
| Gonderi menusu (Duzenle/Sil/Profil/Sikayet/Engelle/Paylas/Ilgilenmiyorum) | p3feed_test, user_profile_test | gecti; QA-P-03 duzeltildi |
| Metin kurali (2200/40, bos, kufur 422) | qa_posts2_test, p3feed_test | gecti |
| Paylas: galeri (izin reddi, sinirli, kamera, album, sayfalama) | post_gallery_picker_test | gecti |
| Paylas: video sinirlari 59/60/61 sn, 50 MB | qa_posts2_test | gecti |
| Paylas: yayin (Idempotency-Key, zaman asimi tekrar) | qa_posts2_test, PostIdempotencyTest | gecti |
| Paylas: yayin sirasinda geri/arka plan | KOD INCELEMESI (`PopScope canPop: !_dirty && !_publishing`; yayinda kapat/geri engelli, yukleme arka planda surer, `_uploaded` yeniden yuklemeyi onler, `_idemKey` tekrarda cift gonderiyi onler) | widget testi YOK (platform yasam dongusu); sorun bulunmadi |
| @bahsetme secici | post_mentions_test | gecti |
| Takip dugmesi 3 durum + hata + self | followreq_test, qa_posts2_test | gecti; QA-P-08 duzeltildi |
| Gizli hesap: kilit blogu, istek gonder/geri cek, onay/ret, liste | followreq_test | gecti |
| Kullanici profili: yukleme/404/hata, engel, sikayet, durum matrisi | user_profile_test, qa_posts2_test | gecti |
| Takipci/takip listeleri, oneriler | followreq_test | gecti |
| Begendiklerim | liked_posts_test | gecti |
| PinchZoomable | pinch_zoom_test | gecti |
| Alt cubuk "+" ve Liquid Glass (esneme, surukleme, yetersiz surukleme, reduce-motion, yuksek kontrast yedegi) | liquid_glass_nav_test, floating_nav_test | gecti |
| Durum matrisi 401/403/404/429/5xx | qa_posts2_test (begeni, profil) | gecti |
| Kaydet | sunucu ucu var; mobil arayuzde kaldirildi (V470) | kapsam disi |
| Backend: begeni/geri alma, idempotency, akis filtreleri, siralama | PostLikeServiceTest, PostIdempotencyTest, PostFeedVisibilityTest, PostRankTest, PostTopFeedTest | bkz. rapor |

## 6. Kalan is (durust)

- Gercek cihaz/emulator turu yapilmadi (kural: ana emulator kullanilmaz); jest cakismasi (pinch vs scroll vs carousel) gercek dokunmatikte dogrulanmadi, yalniz pinch_zoom_test.
- 429/5xx durum matrisi yalniz begeni ve kullanici profili icin parametrik; diger ekranlar (Paylas, takip listeleri, Reels) mevcut tekil testlerle kapsanir.
- Yayin sirasinda uygulamanin arka plana alinmasi icin widget testi yok (kod incelendi).

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
| QA-P-06 | dusuk | YANLIS MANTIK (belge) | CLAUDE.md `post` satiri | - | Belge "en cok 7 kelime/60 karakter" der; kod (mobil + sunucu) 2200 karakter/40 satir gizli ust sinir uygular, sayac/uyari yok | Belge eski | KARAR BEKLIYOR: ya belge guncellenir (onerilir) ya sunucu kurali 7/60'a cekilir (eski istemci + yonetici duzenlemesi + mevcut gonderiler etkilenir) |
| QA-P-07 | dusuk | IYILESTIRME | Paylas yayini | `POST /posts` zaman asimi/5xx: sunucu gonderiyi olusturmus olabilir, kullanici tekrar dener | Tekrar denemede `POST_MEDIA_INVALID` (medya zaten bagli) gorunur; yazim aslinda basarili. Cift gonderi olusmaz (medya baglama korur) ama kullaniciya yanlis hata gosterilir | Idempotency-Key yok | KARAR BEKLIYOR: `POST /posts` icin `Idempotency-Key` (backend + mobil) |
| QA-P-08 | dusuk | IYILESTIRME | FollowStateButton | Istek suresince ust widget durumu degisirse | `didUpdateWidget` `_busy` iken esitlemez; bitince bayat durum kalabilir | `_busy` korumasi | Acik (cok dusuk etki) |
| QA-P-09 | dusuk | BELGE | docs/DEPLOY.md:51 | - | "MULTIPART_MAX_FILE=45MB" yazar; compose/prod ornek 52MB (gonderi videosu 50 MB sinirina uyar) | Belge eski | Acik (belge) |
| QA-P-10 | dusuk | IYILESTIRME | Begeni dugmesi | 404/403 (silinmis/engelli gonderi) ile begeni | "Tekrar dene" toast'i sonsuz basarisiz olur | Hata kodu ayrimi yok | Acik; QA-P-04 sonrasi unlike tarafi cozuldu |

Incelenip SORUN BULUNMAYANLAR (kanit: kod okuma + test): begeni PUT/DELETE idempotent ve atomik (INSERT ... WHERE NOT EXISTS, sayac ayni
transaction, yaris testi mevcut); sayac negatife dusmez (`GREATEST`, istemci `max(0)`); gonderi yazma/silme yetkisi (yalniz yazar, baskasininki
403/404, yonetici icin CONTENT_HIDE izni + denetim); rate limit tum yazma uclarinda var (create 20/sa, begeni 120/dk, takip 60/dk + 500/gun, yukleme 30/sa);
engel iliskisinde takip/istek dusurulur (`BlockService.dropFollowRelations`); gizli hesap: `PrivateAccountGate` gorunurlukte; video sinirlari
mobil/sunucu uyumlu (60 sn + 500 ms tolerans, 50 MB); EXIF temizligi `MediaService` hattinda.

## 3. Calistirilan testler

- Yeni: `mobile/test/qa_posts_test.dart` (10 test: iyimser sayac, hizli art arda dokunus, cift sayili dokunus, controller idempotent, sunucu hatasi geri alma,
  cevrimdisi, sayac 0, ucusta dispose, 320 dp + x1.3 yazi, BlockBus Kesfet).
- Yeni backend: `PostLikeServiceTest.unlikeStillWorksAfterAuthorBecomesInvisible`.
- Mevcut alan testleri tekrar kosuldu: discover_masonry, discover_stream, pinch_zoom, liked_posts, gonderi_sade, followreq, post_mentions, qa_so_reels,
  redesign/k4, redesign/p3feed (1 eski test kurala cevrildi), redesign/p2dc, kesfet2 (tr/en/ar, acik/koyu, 320/390, x1.0/x1.3).

## 4. Kalan is (bu turda KAPSANMADI)

Alt cubuk "+" (floating_nav) jestleri, galeri izni reddi / kamera akislari, video kirpma ekrani sinir durumlari, yayin sirasinda uygulama arka plana,
Reels video onbellek/bellek sizintisi (dispose denetimi), PostRankService siralama mantigi (puan agirliklari), kullanici profili (gizli hesap) ekranlari,
401/429 durum eslemeleri her ekranda, Kaydet/Takipci listelerinin sayfalama testleri, gercek cihazda pinch/scroll/carousel jest cakismasi.

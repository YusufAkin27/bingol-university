# QA alani 4: Sohbet / Mesajlasma (2026-11-06)

Dal: mobil `qa/chat-20261106`, backend `qa/chat-be-20261106` (taban: `deploy/release4-20261106`, CANLI backend).
Kapsam: `mobile/lib/features/chat/**`, `core/realtime/**`, `core/contacts/**`, `core/push/**` (sohbet bildirimleri), `features/share/**`; backend `messaging` (`ws`, `media`, `room`), `crypto`, `media`, `export`.

Dürüstlük notu: mesajlar UCTAN UCA SIFRELI DEGILDIR (sunucuda zarf sifreleme). `chat_security_page.dart` ve ARB metinleri bunu acikca soyler (`chatEncNotE2eeTitle/Body`); hicbir ekranda E2EE iddiasi bulunmadi.

Kapsam disi (uygulamada YOK): sesli mesaj, dosya/belge eki, ses kaydi. Sohbette yalniz metin, fotograf, video, tek gosterimlik fotograf ve paylasim karti vardir. Gorev tanimindaki "sesli mesaj / dosya" kalemleri bu nedenle test edilemedi (ozellik yok; eklenmesi urun karari).

## 1. Envanter (ekran / oge / jest / durum) ve test kapsami

Kapsam sutunu: V = mevcut test vardi, Y = bu turda yazilan test, K = kod incelemesi (etkilesimli test yok / gerekmedi).

### 1.1 Sohbet listesi (`chat_tab.dart`, `chatlist_widgets.dart`)
| Oge | Durum / kenar | Kapsam |
|---|---|---|
| Filtre cipleri Tumu/Kisiler/Kulupler/Etkinlikler | secili cip, bos filtre sonucu | V (chatlist_design, b4) |
| Arama alani | bos sonuc, temizle | V |
| Satir: avatar, ad, son mesaj, saat, okunmamis rozeti (99+), sessiz simgesi | uzun metin, RTL, 320 dp, yazi olcegi 1.3 | V |
| Satir kaydirma (Dismissible) arsivle / menu uzun basma: sessize al (sure + sonsuz), arsivle, sil | hata -> geri al | V (chat_archive_bar) |
| Arsiv cubugu + arsiv gorunumu | sayac sunucudan, iyimser ayar | V |
| Mesaj istekleri satiri + sayfa (`message_requests_page`) | kabul / reddet, bos | V (msg_requests) |
| Yeni sohbet dugmesi, yenile, sonsuz kaydirma (`_loadMore`) | cift kayit yok | V/K |
| Canli: WS mesaji satiri uste alir, sayac artar; kendi mesaj artirmaz; kendi okundu sifirlar | | Y (qa_chat_logic_test) |
| Cevrimdisi / sunucu hatasi: kayitli liste kalir, hata ekrani yalniz bos iken | | V (m1_*) |
| Rozet: `unread-count` (sessiz/arsiv haric) ve `me/summary` | iki kaynak | K -> QA-CHAT-03 |

### 1.2 Yeni sohbet / grup olusturma / rehber (`new_chat_page.dart`, `chat_new_parts.dart`, `contacts_match_page.dart`)
| Oge | Durum / kenar | Kapsam |
|---|---|---|
| Kisi arama, kisi secimi, birebir acma | engellenmis kullanici, kendine yazma (400) | V |
| Yeni grup: ad (1-100), uye secimi, olustur | bos ad, uye yok, gunluk limit 429 | V/K |
| Rehberden kisi bul: riza karti (Rehberden bulunabilirim) | KAPALI iken riza karti, rehber/izin istenmez | Y (QA-CHAT-01) |
| Riza ver (PUT enabled=true) -> izin gerekcesi -> esleme | | Y |
| Bulunabilirligi kapat (PUT enabled=false) | | Y |
| Izin reddi / gerekce / Ayarlar'a git | | V |
| 500'luk parcalar, saatlik 6 istek, gunluk 2000 aday tavani (429) | kismi sonuc | V + Y (QA-CHAT-02) |
| Sonuc satiri: profil, Mesaj dugmesi, arama, bos durum, gizlilik notu | 320/390/430, acik/koyu | V |

### 1.3 Sohbet detayi (`chat_detail_page.dart`, `chatd_parts.dart`, `sohbety_*.dart`, `message_bubble.dart`)
| Oge | Durum / kenar | Kapsam |
|---|---|---|
| Ust cubuk: ad, avatar, cevrimici / son gorulme, uye sayisi, yazıyor | 30 sn yoklama | V |
| Mesaj gonder (WS -> 8 sn ack -> Outbox REST) | art arda hizli, 2000 kod noktasi siniri, emoji, RTL karisik | V (p31_chat_ws, chat_offline) |
| Cevrimdisi kuyruk, kalici hata + Yeniden dene, sil (drop) | | V |
| Yinelenen mesaj (WS iki kez / WS+REST), sira (id'ye gore) | | V + Y |
| Baska konusma mesaji eklenmez | | Y |
| Mesaj menusu (uzun bas): yanıtla, kopyala, bilgi, ilet, düzenle, herkes icin sil, sikayet, tepki | yetkiye gore ogeler | V |
| Duzenleme: sure doldu / sinir / uygun degil -> kipten cik | | Y (QA-CHAT-04) |
| Herkes icin silme (gonderen / grup yoneticisi / oda moderatoru) | idempotent | V + backend testleri |
| Yanit alintisi, alintiya atla, kaydirarak yanit (jest) | | V |
| Tepkiler: son kullanilan, tam emoji secici, sayac | 20 cesit siniri | V |
| Iletme (en cok 5 sohbet) | kismi hata toast | V |
| Okundu/iletildi tikleri: SENT < DELIVERED < READ, asla geri gitmez | | V |
| Iletildi imleci yalniz ilerler | | Y |
| Tek gosterimlik fotograf: ac, 410, 2.2 sn yeniden deneme, ekran koruma, kayit/yansitma | | V (view_once_layout, p31) |
| Medya: galeri secici, kamera, onizleme, video sikistirma/iptal, video bolme, galeri goruntuleyici | izin reddi | V (media_picker, chat_media_compose) |
| Sohbet ici arama (sonraki/onceki) | | V |
| Yeni mesaj asagi oku + rozet | | K |
| Kapali sohbet seridi, kaldirildin/ayrildin | | V |
| Arka plan / on plan (poll yeniden baslar) | | K |

### 1.4 Sohbet bilgisi / grup yonetimi (`chat_info_page.dart`, `chat_info_members.dart`, `sohbety_add_members.dart`)
| Oge | Kapsam |
|---|---|
| Birebir: profil, medya galerisi, sessize al, arsivle, engelle, sikayet, sohbeti sil | V (chat_info_test) |
| Grup: ad degistir, foto degistir/kaldir, uye ekle/cikar, yoneticilik, gruptan ayril | V + backend |
| Kulup/etkinlik odasi: ad/foto/uye ekleme YOK (400 NOT_A_GROUP), ayrilma yok | V + backend |
| Sohbet arka plani (4 desen + yogunluk) | V (chat_wallpaper) |
| Sohbet guvenligi sayfasi (E2EE degil uyarisi dahil) | V (chat_encryption_test) |

### 1.5 Gercek zamanli (`core/realtime/**`)
STOMP baglanma / kalp atisi / ustel geri cekilme / token yenileme / SESSION_REPLACED / SUSPENDED: V (p31_stomp_backoff, stomp_frame). Kopma -> `resync` -> `_poll(force)` bosluk kapatma: K + V. Arka plana gecince kapanir, one gelince baglanir: K.

### 1.6 Push (`core/push/**`) ve paylasim (`features/share/**`)
Sohbet yuku -> `PushDest.conversation`, ayni sohbet acikken bastirma (`ActiveConversation.shouldSuppress`), yanitla / okundu eylemleri (headless), kaldirilma -> sohbet listesi: V (push_*_test). Sohbete gonder (share sheet): V (share_test, share_screens_test).

## 2. Bulgular

Siddet: kritik / yuksek / orta / dusuk. Tur: HATA / YANLIS MANTIK / IYILESTIRME. Durum: DUZELTILDI / KARAR BEKLIYOR / NOT.

| Id | Siddet | Tur | Ekran | Adim | Beklenen / Gercek | Kok neden | Durum |
|---|---|---|---|---|---|---|---|
| QA-CHAT-01 | YUKSEK | HATA + YANLIS MANTIK | Rehberden kisi bul | Yeni sohbet > Rehberden kisi bul | Beklenen: izin istenir, eslesme listelenir. Gercek: backend T-061 ile eslesmeyi karsilikli riza ister (`CONTACTS_DISCOVERABLE_REQUIRED`, varsayilan KAPALI) ama mobilde riza acan hicbir arayuz yoktu: her kullanici icin ozellik 403 ile hata ekrani veriyordu; hata metni de uygulamada olmayan bir ayara gonderme yapiyordu | Mobil T-061 sozlesmesine uyarlanmamisti (`/users/contacts/discoverable` hic cagrilmiyordu) | DUZELTILDI: once `GET /users/contacts/discoverable`, kapaliysa riza karti (3 dil) + `PUT {enabled:true}`; riza yokken rehber/OS izni istenmez; esleme 403 ise riza kartina doner; sonuc ekraninda "Bulunabilirligi kapat"; eski sunucuda 404 ise akis surer. 5 test |
| QA-CHAT-02 | ORTA | HATA | Rehberden kisi bul | 2000+ rehber e-postasi | Beklenen: bulunan kisiler gosterilir. Gercek: sunucu gunluk aday tavani 2000 = 4 parca; 5. parca 429 verince mobil TUM sonucu atip hata ekrani gosteriyordu (onceki 4 parcanin eslesmeleri kayip) | `ContactsMatcher.match` ara parca hatasini yutmuyordu | DUZELTILDI: ilk parca disindaki 429'da kismi sonuc + "limit" uyarisi; ilk parca hatasi hata ekrani. 2 test |
| QA-CHAT-03 | ORTA | YANLIS MANTIK | Ana sayfa / alt cubuk rozeti | Sohbeti oku, 12 sn icinde ana sayfaya don | Beklenen: rozet 0. Gercek: `GET /me/summary` `unreadMessages` Redis'te 12 sn onbellekli ve okuma/sessize alma/arsivleme bu anahtari atmiyordu; ana sayfa/uygulamaya donus bu eski sayiyi sohbet sekmesinin dogru degerinin USTUNE yaziyordu (hayalet rozet) | Onbellek geçersiz kılma yok | DUZELTILDI (backend): `UnreadBadgeCache.evict` okuma (`ReceiptService.onRead`), sessize alma/kaldirma, arsivleme/cikarma sonrasi. 3 test |
| QA-CHAT-04 | ORTA | YANLIS MANTIK | Sohbet detayi | 24 saatten eski kendi mesajini duzenle | Beklenen: surenin doldugu belirtilip duzenleme kipi kapanir. Gercek: "Duzenle" her kendi metin mesajinda gorunur, sunucu 403 `MESSAGE_EDIT_EXPIRED` (prod 1440 dk) / 409 `MESSAGE_EDIT_LIMIT` (10) verir; istemci toast gosterip duzenleme kipinde kalir, ayni hata tekrar tekrar alinir | `_saveEdit` kalici hatalari ayirt etmiyordu | DUZELTILDI: kalici duzenleme hatalarinda kipten cik + alan bosalir (gecici hatada metin korunur). 4 test |
| QA-CHAT-09 | DUSUK | YANLIS MANTIK | Gercek zamanli katman | Hesap A cikis, ayni surecte hesap B giris | `ChatRealtime` oturumla birlikte tek ornek; `_deliveredSent` (konusma -> iletildi imleci) cikista sifirlanmiyordu. Konusma kimlikleri ortaksa B'nin WS ile gelen mesajlari icin "iletildi" gonderilmez (gonderenin cift tiki gecikir) | `stop()` hesaba ozel durumu temizlemiyordu | DUZELTILDI: `stop()` `_deliveredSent`, `_lastTypingSent`, `_awaitingAck` temizler. 1 test |
| QA-CHAT-10 | ORTA | YANLIS MANTIK | Sohbet listesi | 30'dan fazla sohbet; Kulupler/Etkinlikler cipi ya da arama | Beklenen: 2. sayfadaki kulup/kisi bulunur. Gercek: suzgec/arama yalniz yuklu ilk 30 satiri suzer; liste kisaldigi icin kaydirma olmaz ve `_onScroll` sonraki sayfayi hic cekmez: bos sonuc ("bulunamadi") gosterilir | Sayfalama yalniz kaydirmaya bagliydi | DUZELTILDI: `_fillForFilter` suzgec/arama etkinken gorunen < 12 ise sonraki sayfalari kendiliginden ceker (hata olunca dongu yok). 2 test |
| QA-CHAT-05 | DUSUK | YANLIS MANTIK | Backend push birlestirme | Yuk altinda iki gonderenli ayni sohbet | `ChatNotifyFanout.Job.merged` yalniz son isin `candidates` ve `senderId` degerini tutar: ilk gonderenin alicilari (ornegin ikinci gonderen) ilk mesajin bildirimini almaz, ilk gonderen kendi mesajini sayan "N yeni mesaj" alabilir | Birlestirmede alici kumesi birlesmiyor | NOT (yalniz havuz doygunlugunda, dusuk etki; karar: alici kumesi birlestirilsin mi) |
| QA-CHAT-06 | DUSUK | IYILESTIRME | Backend | `addMembers` / `removeMember` | `requireGroupAdmin` kulup/etkinlik odalarini ayirmaz; odalarda hic kimse `Role.ADMIN` olmadigi icin su an istismar yok (RoomConversations aciklamasi), ama savunma derinligi yok (`requireUserGroupAdmin` kullanilmali) | Tek koruma "oda ADMIN uretmez" varsayimi | NOT (kod degisikligi riski dusuk, gerek gormedim) |
| QA-CHAT-07 | DUSUK | IYILESTIRME | Sohbet detayi | `_markRead` WS ile giderse | `sendRead` true doner ama yazma sessizce kaybolursa (yari-olu soket) `_lastRead` ilerlemis kalir; yeni mesaj gelene dek yeniden gonderilmez. `resync` sonrasi `_markRead` zaten yeni sayfa ile yeniden tetiklenir | Gonderim onayi yok | NOT |
| QA-CHAT-08 | DUSUK | IYILESTIRME | Urun | Sesli mesaj, dosya eki | Uygulamada ve backend'de yok | - | KARAR BEKLIYOR (urun) |

Incelenip SORUN BULUNMAYANLAR (kanit icin): mesaj duzenleme/silme/tepki yetkisi (`MessageActionService.access`: uye degil/katilim oncesi 404, sahip degil 403, golge engel sessiz); grup yonetimi yetkileri (`requireGroupAdmin`, oda 400); ek erisimi (`MessageAttachmentService.accessible`: uye, silinmis, gizli, katilim oncesi, engel, "sohbeti sil"); rehber esleme gizliligi (karsilikli riza, numara@ haric, gunluk tavan, hash'ler saklanmaz); push yuku -> hedef esleme (`push_targets` beyaz liste); yerel hatirlatma yuku temizligi; WS yeniden baglanma (gen sayaci, ustel geri cekilme, kararli baglanti sifirlamasi, yetki hatasi dongusu siniri); abonelik/zamanlayici sizintisi (`dispose` tum zamanlayici ve abonelikleri iptal ediyor); E2EE iddiasi yok.

## 3. Calistirilan testler
Bkz. rapor: mobil alan testleri ve backend hedefli testler (messaging, crypto).

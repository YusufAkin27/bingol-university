# Backend istekleri (mobil tasarim uygulamasindan)

Mobil alanlari bu uclar gelene dek opsiyonel okur.

- K8 / anket liste: Liste ogelerinde `results`/`average` yalniz `resultsVisible` iken dolu geliyor (yeterli); "Katildiklarim" ve "Kapanan" sekmelerinde toplam kayit sayisi (`total`) olmadigindan "N anket arsivde" sayisi yalniz tum sayfalar yuklendiginde gosteriliyor. Istek: `GET /api/polls?scope=` yanitina opsiyonel `totalCount` ve acik anket sayisi (sekme rozeti) eklenmesi.
- K8 / anket kulup: Kulup anket listesi bos kutusunda kulup adi cipi icin liste yanitinda `communityName` yeterli degil (bos liste); kulup detayindan gecirilecek (K7).
- K5 / sohbet listesi: `ConversationView.lastMessage.senderName` (grup/kulup/etkinlik onizlemesinde "Ahmet: Toplanti..." onegi icin gonderen adi; yoksa onek gosterilmez) ve `ConversationView.peer.online` (birebir avatarda yesil cevrimici noktasi; yoksa nokta cizilmez). Mobil ikisini de opsiyonel okur.
- K7 / kulup uyeler ve basvurular (27-01, 27-03): `GET /api/communities/{id}/members` ve `/requests` satirlarina `department` ve `classYear` (kullanici profilinden; "Bilgisayar Muhendisligi · 4. sinif" alt satiri) ile basvuru satirina `requestedAt` ("12 dk once" hapi). Mobil uc alani da opsiyonel okur (yoksa alt satir/hap cizilmez).
- K7 / kulup gonderileri (28-02, 28-04): `GET /api/communities/{id}/posts` ogelerine `likeCount`/`liked` ve `authorRole` (yazar rol etiketi); kulup gonderisi beyenme ucu yok. Mobil `likeCount` varsa yalniz okunur sayac cizer (etkilesim yok), `authorRole` varsa rol etiketi gosterir.
- K7 / Kuluplerim (30-01): `GET /api/me/communities` bekleyen satirlarina `requestedAt` ("3 gun once"); yoksa zaman yazilmaz.

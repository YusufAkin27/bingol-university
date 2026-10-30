# A10 - Mesajlaşma derin QA (backend messaging/ws/media + mobil sohbet)

Tarih: 2026-10-31 · Aşama: DENETİM (kod değiştirilmedi) · Ajan: A10
Kapsam: `docs/changes/messaging.md`, `docs/MESSAGING_DESIGN.md`, `docs/ENCRYPTION.md`; `backend/.../messaging/**`, `mobile/lib/features/chat/**`, `mobile/lib/core/{realtime,outbox,cache}`.
Yöntem: statik kod incelemesi + A7'nin QA yığınında (`http://localhost:18081`, HEAD b405782) canlı senaryolar (kullanıcılar `a10_*@bingol.edu.tr`, kimsenin verisine dokunulmadı, silme yapılmadı). Üretim sunucusuna erişilmedi. Flutter birim testleri çalıştırılmadı (yalnız statik inceleme).
Canlı betikler (yeniden üretim için): `%TEMP%\...\scratchpad\a10\t1.js ... t7.js` (Node 24, yerleşik WebSocket; commit edilmedi).

## Özet

| Şiddet | Adet |
|---|---|
| Kritik | 0 |
| Yüksek | 1 (A10-01) |
| Orta | 8 (A10-02 ... A10-09) |
| Düşük | 11 (A10-10 ... A10-20) |
| Bilgi | 6 (A10-21 ... A10-26) |

En kritik 5: A10-01 (WS ile gönderilen metin sayfadan çıkılınca/yarım açık soketle sessizce kaybolur), A10-02 (gruba sonradan katılan, katılmadan önceki mesajın DÜZENLENMİŞ metnini canlı olayla alır), A10-03 (aynı WS oturumundan gelen SEND'ler eşzamanlı işlenir, mesaj sırası bozulur), A10-04 (engellenen kullanıcı grup kurarken 403 BLOCKED alır: gölge engel sızar), A10-05 (mobil 2000 sınırı UTF-16 sayar, sunucu kod noktası; emoji ağırlıklı mesajlar sessizce gönderilmez).

Doğrulanan iyi davranışlar (canlı): eşzamanlı çift birebir sohbet oluşturma tek konuşma verir; aynı `clientId` ile 6 eşzamanlı istek 1x201 + 5x200 ve tek kayıt; WS+REST aynı `clientId` tek mesaj; gölge engel (engellenen 201 alır, engelleyen WS/geçmişte görmez, tepki 404); çıkarılan üye geçmiş/tepki/düzenleme/silme/gönderim/ek erişiminde 404 ve canlı mesaj almaz (abonelikler kullanıcı bazlı olduğundan "açık abonelik" sızıntısı yok); katılım öncesi geçmiş görünmez; silinen mesaja tepki 404; yetkisiz silme/düzenleme 403; 2000 emoji (kod noktası) kabul, 2001 reddedilir; HTML/script metni olduğu gibi saklanır (kaçış istemcide); bidi/sıfır genişlikli karakterler temizlenir; DB'de düz metin yok (`body_ciphertext` ve bildirim/push_outbox/log taraması temiz); sayfalama `before/after` tutarlı (84 mesaj/17 sayfa, tekrar yok, `size` 50'ye kırpılıyor); tek oturum kuralı (ikinci mobil giriş eskisinin token'ını 401 yapar, WS `session-replaced` + 1008 `SESSION_REPLACED` ile kapanır, eski WS ile mesaj gitmez); sohbeti sil/arşiv/sessize alma/mute forever; tek gösterimlik: 6 eşzamanlı açışta tam 1x200, gönderen 403, tekrar 410, thumb 404; ek erişimi üyelik, silinme, çıkarılma sonrası kapanır; sahte png/svg/video reddedilir; 11 ek `ATTACHMENT_LIMIT`.

---

## Bulgular

### A10-01 - Yüksek - WS ile gönderilen metin, sayfa kapanınca ya da yarım açık soketle sessizce kaybolabilir
- Yer: `mobile/lib/features/chat/chat_detail_page.dart:947-960` (WS gönderim + 8 sn `_ackTimers`), `:411` (dispose'ta zamanlayıcıları iptal), `mobile/lib/core/realtime/stomp_client.dart` (`send` yalnızca `isConnected` bayrağına bakar; ölü soket en fazla ~30 sn bağlı görünür).
- Adımlar: (1) Sohbette WS bağlıyken (`_rtOn`) metin gönderin. (2) Soket aslında ölüyse (mobil ağ değişimi, uçak modu, tünel) kare sunucuya ulaşmaz. (3) 8 sn dolmadan geri tuşuyla sohbetten çıkın.
- Beklenen: mesaj ya kalıcı Outbox kuyruğuna girip gönderilir ya da hata gösterilir. Gerçek: REST yedeği yalnızca sayfa canlıyken çalışan `Timer`'dadır; sayfa kapanınca iptal edilir, mesaj Outbox'a hiç girmemiştir (`captureRequest` yalnız REST ağ hatasında devreye girer) -> mesaj ne gider ne "başarısız" görünür. Sohbete dönülünce balon da yoktur (`_restoreOutboxBubbles` yalnız Outbox'tan çizer).
- Etki: kullanıcı yazdığı mesajın gittiğini sanır (M1 "sessiz kuyruk" sözünün ihlali; gerçek mesaj kaybı).
- Öneri: WS ile atılan her mesajı ack gelene kadar Outbox'a (veya oturum düzeyi bir "ack bekleyen" kayda) yazın; ack/`clientId` eşleşince silin. Zamanlayıcıyı sayfaya değil `ChatRealtime`/Outbox'a bağlayın; sayfa kapanınca iptal etmeyin.
- Test boşluğu: `chat_offline_test.dart` / `m1_silent_queue_test.dart` bu senaryoyu (WS ack gelmeden sayfadan çıkış) kapsamıyor.

### A10-02 - Orta - Gruba SONRADAN katılan üye, katılmadan önceki mesajın düzenlenmiş METNİNİ canlı olayla alır
- Yer: `backend/.../messaging/MessageActionService.java:272-282` (`publish`: tüm aktif üyelere, `joinedAt` süzgeci yok); karşılaştır `MessageService.deliver` (`late` listesi).
- Tekrar (canlı, doğrulandı): A grup kurar, eski bir mesaj gönderir; D gruba sonradan eklenir; A katılım öncesi mesajı düzenler -> D'nin `/user/queue/message-events` kuyruğuna `{"type":"edited","message":{"id":49,"text":"DUZENLENMIS-ESKI-MESAJ",...}}` düştü (geçmiş uçları 404/gizli iken). `reaction` olayı da (emoji + mesaj kimliği) katılım öncesi mesaj için ulaştı.
- Beklenen: katılım öncesi mesajlara ait olay gitmez (geçmiş, ek, yanıt önizlemesi aynı kuralı uyguluyor). Gerçek: tam metin sızıyor.
- Etki: grup gizlilik sözleşmesi ("sonradan katılan eski mesajı görmez") ihlali; büyük odalarda (500 üye) yeni üye düzenlenen eski içeriği okuyabilir.
- Öneri: `publish`te GRUP için `joinedAt <= message.createdAt` olmayan alıcıları çıkarın (`MessageEvent.messageId` üzerinden mesaj tarihi) veya `edited` olayını yalnız o kümeye gönderin.

### A10-03 - Orta - Aynı WS oturumundan gelen `chat.send` çerçeveleri eşzamanlı işleniyor; mesaj sırası gönderim sırasından sapıyor
- Yer: `backend/.../ws/WebSocketConfig.java:76-80` (yorum "ardışık SEND'ler yer değiştirmesin" diyor; `setPreservePublishOrder(true)` gelen çerçevelerin işlenmesini sıralamıyor), `ChatWsController.send`.
- Tekrar (canlı): tek soketten 10 SEND anında -> teslim sırası ve kimlikler `r0#66 r3#69 r2#68 r1#67 r4#70 r5#71 r6#72 r9#74 r7#73 r8#75`. 150 ms aralıkla gönderimde sıra doğru. (İlk denemede 20 çerçeve `w0,w3,w2,w1,w4` sırasıyla geldi.)
- Etki: hızlı art arda gönderilen mesajlar (yapıştırma + gönder, ileti çoklu gönderimi, kuyruk boşaltma WS yoluyla yapılırsa) karşı tarafta yer değiştirir; geçmişte kalıcı.
- Öneri: `clientInboundChannel` yürütücüsünü tek iş parçacıklı yapın (ör. `registration.taskExecutor().corePoolSize(1)`) veya `chat.send` işini kullanıcı başına sıralı kuyrukta çalıştırın; ya da istemci sırası (`clientSeq`) taşıyın. Yoruma güvenmeyen bir test ekleyin (ws-test.js "20 hızlı gönderim sırası").
- Not: kimlik atanan sıra, commit sırası ve `createdAt` (uygulama saati) üçü de birbirinden farklı olabilir (REST'te de: 20 eşzamanlı istekte id sırası != createdAt sırası). `after=<lastId>` ile boşluk doldurma, geç commit olan küçük kimliği (id alındı, commit sonra) kaçırabilir (A10-16).

### A10-04 - Orta - Grup kurma/üye ekleme, engellenen kullanıcıya `403 BLOCKED` döner: gölge engel sızıyor
- Yer: `ConversationService.java:153,284,386-391` (`requireNotBlocked` -> `blocks.hiddenFrom(me)` iki yönlüdür).
- Tekrar (canlı, doğrulandı): A, D'yi engeller. D, A'yı üye olarak içeren grup kurar -> `403 {"code":"BLOCKED","message":"Bu kullanıcıyla mesajlaşamazsınız."}`; engelsiz üyelerle 201. 
- Beklenen (docs/changes/messaging.md V260): engel ilişkisinde hata YOK; engellenen kişi engellendiğini öğrenmez. Gerçek: D, 403 ile A'nın onu engellediğini kesin öğrenir (tarama saldırısı: bir kullanıcıyı grup eklemeyi deneyerek engel durumu sorgulanabilir).
- Öneri: engellenen->engelleyen yönünde 404 `USER_NOT_FOUND` ile aynı genel hata ya da sessiz kabul (üyeyi eklemeden başarı); yalnız engelleyen->engellenen yönünde bilgilendirici hata.

### A10-05 - Orta - Mobil sınır kontrolü UTF-16 sayıyor, sunucu kod noktası; emoji ağırlıklı mesaj sessizce gönderilmiyor
- Yer: `chat_detail_page.dart:883` (`text.length > _maxLen` sessiz `return`), `:2948` (sayaç `characters.length` yani grapheme), `core/outbox/outbox.dart` (`text.length > maxTextLength`).
- Tekrar: 1001-2000 emoji (her biri 2 UTF-16 birimi) yazın: sayaç "<=2000", gönder düğmesi aktif ama dokununca hiçbir şey olmaz, geri bildirim yok. Tersine 2000'den çok kod noktasına rağmen grapheme sayısı <=2000 (birleşik işaretler/ZWJ) olan metin sunucuda 400 `MESSAGE_TOO_LONG` alır. Canlı: sunucu 2000 emoji kabul, 2001 reddediyor (doğru).
- Öneri: tek ölçü kullanın: `text.runes.length` (kod noktası) hem sayaçta hem `_submit`te hem Outbox'ta; sınır aşımında görünür uyarı. Düzenleme (`_saveEdit`) yolunda da sınır kontrolü yok (sunucu 400 verir, toast'a düşer).

### A10-06 - Orta - Gruptan çıkarılan/ayrılan üyenin açık sohbeti sessizce "ölü" kalır; yönetici çıkarmasında olay yok; önbellekli açılış 404'ü yutar
- Yer: `ConversationService.removeMember` (olay yok; yalnız oda yolu `RoomConversations.notifyRemoved` yayınlıyor), `EventChatMaintenance.java:52` (toplu JDBC `left_at`, olay yok), `chat_detail_page.dart:495-500` (`_boot`: önbellek varken her hata yutulur), `:622` (`_poll` tüm hataları yutar), `chat_realtime.dart` (`conversation-removed` yalnız liste yeniler).
- Tekrar (canlı): yönetici C'yi gruptan çıkardı; C'nin `message-events` kuyruğuna olay düşmedi (0). Mobilde C sohbet açıksa mesajlar durur, gönderim "Konuşma bulunamadı" ile başarısız olur; kapatıp önbellekten tekrar açınca eski mesajlar gösterilir (404 yutulur) ve poll sonsuza dek sessizce hata alır.
- Beklenen: çıkarılan üyeye `conversation-removed` olayı; istemci 404 `CONVERSATION_NOT_FOUND` alınca sayfayı kapatıp yerel kaydı (`MessageCache.removeConversation`) siler, kullanıcıya bildirir.
- Öneri: `removeMember`/`leave` (diğer cihazlar için) ve event odası toplu çıkarmasında olay yayınlayın; mobilde ağ dışı 404/403'te özel durum.

### A10-07 - Orta - Kulüp/etkinlik odası moderatörü mobilden başkasının mesajını silemez
- Yer: `chat_detail_page.dart:1691-1692` (`canDelete = mine || (!_direct && _conv['admin'] == true)`); sunucu `MessageActionService.delete` odada `RoomModeration` ile izin veriyor, ancak `ConversationView.admin` odalarda daima false (odada ADMIN rolü yok: `RoomConversations` açıklaması).
- Etki: sunucu özelliği (docs/changes/messaging.md "DELETE /api/messages/{id}") mobilden erişilemez; moderatör yalnızca API/yönetici panelinden silebilir.
- Öneri: `ConversationView`'a `canModerate` (kulüp/etkinlik odasında çağıranın moderasyon yetkisi) ekleyip mobilde kullanın.

### A10-08 - Orta - Tek gösterimlik görsel, baytlar teslim edilmeden "tüketiliyor"
- Yer: `MessageAttachmentService.openViewOnce` (görüntüleme kaydı `saveAndFlush` yanıt gövdesi yazılmadan önce), `mobile/lib/features/chat/view_once_viewer.dart:56-66` (`getBytes` tek deneme; ağ kopması/arka plana geçiş -> `_drop()` + pop).
- Senaryo: alıcı açar, indirme sırasında bağlantı kopar ya da uygulama arka plana gider -> sunucuda kayıt tüketilmiş, tekrar denemede 410; görsel kalıcı kaybolur, gönderen "Açıldı" görür. Ayrıca herhangi bir GET (HEAD dahil; Spring HEAD'i GET'e eşler) tüketir; ara katman ön-getirmesi/health-probe de tüketebilir.
- Öneri: iki aşamalı açış (kısa ömürlü açış jetonu + istemci "gösterildi" onayı), ya da tüketimi yanıt tamamen yazıldıktan sonra yapın; HEAD/Range'i reddedin; ağ kopmasında kısa süre (ör. 60 sn) aynı kullanıcıya yeniden verme penceresi.

### A10-09 - Orta - Fotoğraf otomatik galeriye kaydı varsayılan AÇIK ve her gönderen/oda türü için çalışıyor
- Yer: `mobile/lib/features/chat/photo_autosave.dart` (`considerReceived`, `enabled()` varsayılan true), `chat_detail_page.dart:836`.
- Risk: 500 kişilik kulüp/etkinlik odasındaki herhangi bir üye, gönderdiği her fotoğrafı diğer üyelerin galerisine (ve bulut yedeğine) otomatik yazdırır; rıza yok (taciz/uygunsuz içerik riski, depolama).
- Öneri: yalnız birebir sohbetlerde ve/veya kişi başına açık; oda/gruplarda varsayılan kapalı ya da sohbet bazlı anahtar; ilk açılışta rıza metni.

### A10-10 - Düşük - WS yolu, bekleyen Outbox öğelerini geçebilir (sıra)
- Yer: `chat_detail_page.dart:947-952` (`_rtOn` ise doğrudan WS; Outbox'ta bekleyen öğe kontrol edilmiyor).
- Senaryo: çevrimdışı gönderilen A Outbox'ta (geri çekilme 2 sn), WS yeniden bağlanır, kullanıcı B'yi yazar -> B WS ile hemen gider, A sonra -> sunucuda B < A. 
- Öneri: konuşmada bekleyen Outbox öğesi varsa yeni mesajı da Outbox'a ekleyin (sıra korunur).

### A10-11 - Düşük - İlet (ForwardSheet): çevrimdışıyken "başarısız" der ama mesajlar sessiz kuyruğa alınır (yinelenen ileti riski); liste ilk 50 sohbet
- Yer: `chat_detail_page.dart:1774-1802` (`catch (_) { failed++ }`; `ApiClient._sendFull` ağ hatasında `outbox.captureRequest` ile zaten kuyruğa alıyor), `forward_sheet.dart:60` (`size=50`, sayfalama yok), `:104` (kapalı oda yalnızca yerel durumdan eleniyor; `ConversationView`'da `closed` alanı yok).
- Etki: kullanıcı "başarısız" görüp yeniden iletir -> alıcıya iki kez gider; 50'den çok sohbeti olan kullanıcı eski sohbetlere ileteme.
- Öneri: ağ hatasında "kuyruğa alındı" sayın; listeyi imleçle sayfalayın; `closed` bilgisini sunucudan taşıyın.

### A10-12 - Düşük - Boşluk doldurma delikleri
- (a) `_poll(force)` `after=` ile en çok 5 sayfa (150 mesaj) çekip ardından en yeni 30'u birleştirir; kopukluk sırasında 180+ mesaj gelen odalarda arada kalan mesajlar bu oturumda hiç görünmez (`chat_detail_page.dart:599-648`). (b) `_polling` doluysa `force` çağrısı düşer (:600). (c) `StompClient._onConnected` durumu `connected` yapar ve SUBSCRIBE'ları ondan sonra gönderir (`stomp_client.dart:208-212`); `connected` -> `resync` -> GET, abonelik sunucuda etkinleşmeden dönebilir. Canlıda abonelik etkinleşmesi bir yükte >300 ms sürdü (CONNECT+SUBSCRIBE hemen ardından gelen mesajlar teslim edilmedi). Pencerede gelen mesaj ~20 sn sonraki turdaki "son sayfa" çekimine kadar görünmez; `ChatTab` listesinde periyodik tazeleme yok, yalnız olay/resync.
- Öneri: `after` döngüsünü `nextCursor == null` olana dek (üst sınırlı) sürdürün ve "en yeni 30" birleştirmesini yalnız döngü bittiyse yapın; resync'i SUBSCRIBE onayı (RECEIPT) sonrasına bağlayın ya da resync'i 1-2 sn gecikmeli iki kez çalıştırın.

### A10-13 - Düşük - Mobil, `edited`, `reaction`, `conversation-updated`, `access-blocked` olaylarını işlemiyor
- Yer: `mobile/lib/core/realtime/chat_realtime.dart:150-173` (`_onMessageEvent`: yalnız session-replaced, receipt, conversation-removed, deleted, viewed).
- Etki: başkasının düzenleme/tepkisi ancak ~20 sn'lik "son 30 mesaj" yoklamasıyla görünür (daha eski mesajdaki düzenleme/tepki hiç yenilenmez); grup adı/fotoğraf değişimi açık sohbette/listede canlı görünmez (`_loadDetail` yalnız açılışta); `access-blocked` olayı yok sayılır, soket her ≤30 sn yeniden bağlanmayı dener.
- Öneri: bu olayları ilgili mesaja uygulayın; `conversation-updated` için listeyi/başlığı güncelleyin.

### A10-14 - Düşük - Eşzamanlı yinelenen `clientId` istekleri her biri `msg:user` kotasını harcar
- Yer: `MessageService.send` satır 187-230 (yinelenen kontrolü kota öncesinde ama yarış penceresindeki istekler `limiter.check("msg:user")`e ulaşır).
- Canlı: aynı `clientId` ile 6 eşzamanlı istek 6 kota harcadı; ardından 20 WS gönderiminin 15'i 429 ile düştü (WS'de hata çerçevesi `clientId` ile döner, mobil "başarısız" gösterir). Aynı `clientId` + farklı metin sessizce eski mesajı 200 ile döner (istemci hatası tespit edilemez; mobil UUID kullandığı için pratik risk düşük).
- Öneri: kota artışını yalnız gerçek insert'e bağlayın (ya da yarışta kaybedenlere iade).

### A10-15 - Düşük - Gönderimde gönderenin okundu imleci örtük ilerliyor
- Yer: `MessageService.persist` (satır 276, 281: `advanceRead` + iletildi).
- Etki: kullanıcı başka cihazdan/bildirimden yanıt yazınca, görmediği önceki mesajlar karşı tarafta READ tiki alır ve rozet sayacı sıfırlanır; `conv:<id>` bildirim satırı da okundu işaretlenmez (`markConversationRead` çağrılmıyor).
- Öneri: örtük okundu kabul edilecekse `markConversationRead` da çağrılmalı; aksi halde yalnız gönderen mesajı kendi mesajı kadar ilerletin.

### A10-16 - Düşük - Kimlik/commit/`createdAt` sırası uyumsuz
- `saveAndFlush` kimliği alır, commit sonra olur; `createdAt` uygulama saatinden. Canlı: 20 eşzamanlı REST'te id sırası != createdAt sırası. Etkisi: (a) `after=<lastId>` geç commit olan daha küçük kimliği atlayabilir (milisaniyelik pencere); (b) grup `joinedAt` süzgeci `createdAt` ile yapılıyor, kimlikle değil (`MessageRepository.before/after`).
- Öneri: süzgeçleri kimlik tabanlı (`cm.first_visible_message_id`) yapın; `after` için kısa geri alma payı.

### A10-17 - Düşük - Yönetici kapatmış sohbette düzenleme/silme/tepki serbest
- Yer: `MessageActionService.access` (`conv.isClosed()` denetimi yok; yalnız `MessageService.send` denetliyor). Kapatılmış sohbette kullanıcı eski mesajlarını düzenleyip silebiliyor (moderasyon kanıtı bozulur; silme tombstone olarak saklanır ama düzenleme geçmişi de `message_revision`).
- Öneri: kapalı sohbette düzenleme/silme/tepki 409 `CONVERSATION_CLOSED`.

### A10-18 - Düşük - Push önizlemesi UTF-16 sınırında kesiliyor
- `MessageService.java:367`: `body.substring(0, 100)` vekil çifti ortadan bölebilir (emoji), push'ta bozuk karakter. `MessageViewAssembler.truncate` kod noktası kullanıyor; aynısını kullanın.

### A10-19 - Düşük - Outbox: `ATTACHMENT_*` 400'leri ağ hatası sayılıp kuyruğu kilitliyor
- Yer: `core/outbox/outbox.dart:640-645`. `ATTACHMENT_LIMIT` gibi KALICI hatalar da ek kimliğini sıfırlayıp `NETWORK` fırlatır: öğe 24 saat boyunca yeniden yüklenir (kota/yetim dosya) ve `stop=true` yüzünden diğer konuşmaların öğeleri de bekler.
- Öneri: yalnız `ATTACHMENT_INVALID` (ve 404/410) yeniden yükleme sayılsın, diğerleri kalıcı hata.

### A10-20 - Düşük - Etkinlik odası bakım işi toplu JDBC ile `left_at` yazıyor
- `EventChatMaintenance.java:52`: her 5 dk tüm aktif etkinlik odası üyeliklerini tarayan UPDATE; çıkarılan kullanıcılara `conversation-removed` olayı yok, bellek içi önbellekler/oda sayaçları güncellenmiyor. Ayrıca silme/çıkarma sonrası kullanıcı 5 dk içinde mesaj almaya devam edebilir (üyelik RSVP'den sonra bakımda düşüyor).

### Bilgi / gözlem
- A10-21: Yönetici atama/devretme ucu yok (`PUT /conversations/{id}/members/{uid}/role` -> 404); yalnız yönetici ayrılınca "en eski üye" otomatik yönetici olur. İki yönetici aynı anda ayrılırsa (ReadCommitted, `leave` kilitsiz) grup yöneticisiz kalabilir (teorik). Sabitleme (pin) yok (kapsam dışı olabilir).
- A10-22: Oturum iptali WS kapatma (`TokenExpiryGuard.closeUser`) yalnız yerel JVM oturum haritasına bakar; çok örnekli kurulumda diğer örnekteki WS açık kalır ve `SEND`te yalnız askı + token süresi denetlenir (iptal/`pwchg` yok) -> iptal edilmiş token en çok exp+60 sn mesaj atabilir. Tek örnekte canlı doğrulandı (iptal anında kapanıyor).
- A10-23: `message.body` (eski düz metin sütunu) şemada duruyor (`V69_1` varsayılan UYGULANMAZ, `docs/ENCRYPTION.md` 8.1). QA yığınında yeni mesajlarda NULL; üretimde sütunun boş ve `V69_1`'in uygulanmış olması kontrol edilmeli (`scripts/crypto-no-plaintext.sh`).
- A10-24: `MessageCache` (cihazda `msg_cache/c<id>.json`) mesaj metnini düz JSON saklıyor (Outbox ise Keychain/Keystore'da). Android `allowBackup=false` ile korunuyor; iOS `Application Support` yedekten dışlanmıyor (`NSURLIsExcludedFromBackupKey` yok).
- A10-25: `MessageText.clean` U+200E/200F (LRM/RLM) ve U+061C'yi siliyor; karışık yönlü Arapça/Türkçe metinde işaretleri kaybettirebilir (ar yerel ayarı destekleniyor).
- A10-26: WS çerçevesi >16 KB ise sunucu ERROR çerçevesi olmadan soketi 1009 ile kapatır (canlı: 20 KB). Mobil en çok ~8 KB üretebildiği için pratik risk yok; saldırgan istemci için yalnız gürültü.

Yan not (kapsam dışı, canlı yığın günlüğünden): `SupportTicket.getUserId()` null iken `NullPointerException` (herkese açık destek talepleri, `support.ticket` servisinde `Long.equals`); ayrıca bir istekte "Unable to rollback against JDBC Connection / Connection is closed" 500'ü görüldü. A7/destek ajanına iletilmeli.

---

## DOĞRULANAMADI

1. Redis pub/sub kopması (dinleyici düşmesi, `chat:events` yayını başarısızken yerel yedek teslim): paylaşılan yığına müdahale gerektireceği için denenmedi. Statik: `ChatEventBus.publish` Redis hatasında yalnız yerel teslim; dinleyici kapalıyken yayın başarılı olursa olay kaybolur (kayıt DB'de, istemci poll/`after` ile alır).
2. Çok örnekli senaryolar (iki backend, soket farklı düğümde): tek örnekli yığın.
3. FCM/APNs push teslimi, ön plan/arka plan bastırma (FCM kapalı); `viewing`/`foreground` anahtarlarının davranışı yalnız statik okundu.
4. Kulüp/etkinlik odası canlı senaryoları (kapanan/yasaklı üyenin düşürülmesi, kulüp silinince oda, moderatör silme): topluluk/etkinlik verisi kurulmadı; yalnız statik (`RoomConversations`, `ClubExtrasHooks`, `EventChatMaintenance`).
5. Gerçek video yükleme (geçerli mp4 + süre/boyut limitleri, `mvhd` süresi taklidi ile 60 sn sınırı aşma olasılığı, iOS `.mov` dönüştürme): geçerli test mp4 üretilemedi; yalnız sahte video ve `video/quicktime` (400 VIDEO_INVALID) denendi. Mobilin `.mov`'u mp4'e çevirip çevirmediği cihazda doğrulanmalı.
6. Mobil davranışlar (kaydırma konumu, klavye, yanıt/düzenleme şeritleri, sohbet içi arama vurgusu, kamera/galeri akışı, ücretsiz imzalı iOS derlemesi): Flutter arayüzü çalıştırılmadı; kod okuması ile sınırlı. Mevcut birim testleri koşturulmadı.
7. Uçak modu / uygulama öldürülüp açılma Outbox senaryoları: birim testlerin kapsadığı kısımlar okundu (kalıcı hata, sıra, 24 sa, çıkış temizliği); gerçek cihazda doğrulanmadı.
8. Eşzamanlı grup 50 üye sınırı yarışı, eşzamanlı iki yönetici ayrılması, eşzamanlı düzenleme/silme yarışı: kod okundu (kilitler var: `lockById`), canlı denenmedi.
9. Büyük dosya yükleme sırasında bağlantı kesilmesi sonrası yetim ek davranışı (24 sa temizlik `Janitor`) ve `pending-max` (30) doluluk senaryosu.

## Test boşlukları (öneri)
- `ws-test.js`: aynı oturumdan 20 hızlı `chat.send` -> sıra ve 429/hata çerçevesi doğrulaması.
- `smoke-messaging.sh`: gruba sonradan katılan + düzenleme/tepki olayı sızıntısı; engellenen kullanıcının grup oluşturma yanıtı.
- Mobil: WS-ack bekleyen mesajla sayfadan çıkış; çıkarılmış üye için önbellekli açılış (404); emoji ağırlıklı metin sınırı; Outbox bekleyen varken WS gönderimi; ForwardSheet çevrimdışı; `edited/reaction` olay işleme.

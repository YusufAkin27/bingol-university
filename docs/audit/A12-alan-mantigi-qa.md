# A12 - Alan mantığı QA (etkinlik, kulüp, anket, akademik, yemek/haber/destek)

Tarih: 2026-10-31. Denetim aşaması: kod DEĞİŞTİRİLMEDİ. Üretim sunucusuna erişilmedi.
Yöntem: önce statik kod okuması (backend: event, community, poll, academic, menu, support, notification; mobil: polls, events, academic), sonra A7 test yığınında (`BASE=http://localhost:18081`, `a12_*` kullanıcıları/kulüpleri) dinamik doğrulama. Dinamik doğrulananlar "DOĞRULANDI", yalnız koddan çıkarılanlar "STATİK" etiketlidir.

Test yığını HEAD b405782 temiz kopyasıdır (çalışma ağacındaki kaydedilmemiş değişiklikler dahil değil).

## Özet

| Şiddet | Adet |
|---|---|
| Yüksek | 1 |
| Orta | 8 |
| Düşük | 12 |
| Bilgi | 2 |

Olumlu bulgular (sorun bulunamadı):
- Gizli oy: oy-kimlik eşleşmesi hiçbir yanıtta, CSV'de, yönetici ekranında veya logda dönmüyor. `poll_vote.user_id` yalnız kullanıcının kendi KVKK dışa aktarımında (`PollExporters`) ve `PollAccess.voterIds` (bildirim ayıklama, dışarı verilmez) kullanılıyor. Hesap silmede oylar anonimleştiriliyor, seçmen kaydı siliniyor.
- Anket sayaç tutarlılığı: aynı kullanıcının 8 eşzamanlı oy değişikliği sonrası `totalVotes` ve RANKED Borda puanları doğru kaldı (DOĞRULANDI). Tekrar/yinelenen/fazla seçenek, 4 seçenekli geçersiz oy `POLL_INVALID_VOTE` ile reddediliyor.
- Etkinlik doğrulamaları (DOĞRULANDI): geçmiş `PAST_EVENT`, bitiş<=başlangıç `INVALID_DATES`, 30 günden uzun `EVENT_TOO_LONG`, kapasite 0 `VALIDATION_ERROR`, kulüpsüz `EVENT_CLUB_REQUIRED`, son kontenjan `EVENT_FULL`, kayıt kapatma/yeniden açma doğru çalışıyor. Sunucu takvimi gün sınırını Europe/Istanbul'a göre veriyor (`2026-11-30T21:30Z` etkinliği `2026-12-01` günü altında).
- QR/elle yoklama kodu: 30 sn pencere, güncel+önceki pencere, sabit zamanlı karşılaştırma, elle kod için dakikada 8 deneme sınırı; kaba kuvvet pratik değil.
- Hatırlatma: `claimDay/claimHour` koşullu UPDATE ile çift gönderim engelleniyor; iptal edilen etkinlik (ACTIVE dışı) taranmıyor.
- Android yerel hatırlatma `setAndAllowWhileIdle` kullanıyor (tam alarm izni gerekmiyor).
- Menü kalorisi: normalize anahtar (`İ/ı/I`, aksan), 0..5000 sınırı, senkron kaloriye dokunmuyor, önbellek geçersiz kılma kayıtlı.

---

## Bulgular

### A12-01 - Yüksek - Hedef kitle SQL eşlemesi büyük "İ" ile başlayan bölüm/fakültelerde çalışmıyor (duyuru + anket)
DOĞRULANDI.
- Yer: `academic/DepartmentAnnouncementService.java` `audienceSql` / `field` / `audienceIds` / `userField`; `poll/PollAccess.java` `eligibleCount`, `audienceUserIds`; `poll/PollRepository.java` `countOpen/countClosed` (parametreler `PollService.audNorm`).
- Neden: Java tarafı `value.strip().toLowerCase(Locale.ROOT)` ile "İşletme" -> "i̇şletme" (i + birleşik nokta, 2 karakter) üretir; PostgreSQL `LOWER(col)` aynı değeri "işletme" yapar. Karşılaştırma `LOWER(col) = ?` olduğundan hiç eşleşmez. (Java içi `AudienceMatch`/`equalsIgnoreCase` yolu doğru çalışır, bu yüzden tutarsızlık da doğar. Etkinlik yönetici araması ve `MenuItemKey` bu sorunu zaten özel olarak çözüyor, burada çözülmemiş.)
- Tekrar adımları: `a12_p1@bingol.edu.tr` bölüm "İşletme" (fakülte "İktisadi ve İdari Bilimler Fakültesi", sınıf 3). Admin ile `POST /api/admin/announcements {"title":..,"body":..,"department":"İşletme"}`.
  - `GET /api/announcements?scope=mine` (p1) -> `[]`; `scope=all` -> duyuru görünüyor.
  - `GET /api/admin/announcements/audience-count?department=İşletme` -> `{"count":0}`.
  - Aynı kitleyle `POST /api/polls` (GLOBAL, `audience.department="İşletme"`): p1 `GET /api/polls?scope=open` -> listede 1 anket ama `totalCount=0, openCount=0` (sekme rozeti 0).
- Beklenen/gerçek: kullanıcı kendi bölümüne yönelik duyuruyu "Benim" sekmesinde görmeli, okunmamış sayacı ve push/uygulama içi bildirim almalı; gerçek: görmüyor, sayaç 0, bildirim hedef listesi (audienceIds/audienceUserIds) bu kullanıcıları dışlıyor -> sessiz bildirim kaybı. Etkilenen adlar: İşletme, İktisat, İnşaat Mühendisliği, İlahiyat, İletişim, İngilizce..., "İktisadi ve İdari Bilimler Fakültesi", "İlahiyat Fakültesi" vb.
- Etki: bölüm duyuruları ve hedefli anketler/bildirimler için fakültelerin önemli bir kısmı kapsam dışı kalıyor; yönetici hedef kitle sayımı yanlış gösteriyor.
- Öneri: karşılaştırmayı tek yerde normalize edin: Java'da `MenuItemKey.of` benzeri (İ/ı/I -> i, NFD) ve SQL'de aynı fonksiyonu (ör. `translate(lower(col), 'İI', 'ii')` yerine kayıtta normalize edilmiş yan sütun/ifade indeksi) kullanın; ya da profil/duyuru değerlerini katalogdan kimlikle (id) eşleyin.

### A12-02 - Orta (yüksek olabilir) - `UserEvent.goingCount` tam-varlık UPDATE ile ezilebilir (kapasite aşımı / yanlış sayaç)
STATİK (eşzamanlılık deneyi yapılamadı, hız sınırı 5/dk nedeniyle tekrarlanamadı).
- Yer: `event/UserEvent.java` (`goingCount` `updatable=false` DEĞİL, `@DynamicUpdate`/`@Version` yok); yazanlar `EventService.update`, `setRegistrationClosed`, `setCover`, `removeCover`, `review`, `cancelInternal` (hepsi `events.save(e)` / `saveAndFlush(e)`); sayacı değiştiren koşullu UPDATE'ler `tryIncrementGoing/decrementGoing`.
- Neden: Hibernate varsayılanı tüm sütunları yazar. Organizatör "kayıtları kapat" / başlık düzenle işlemini okuduğu `goingCount` ile commit ederken arada bir RSVP commit olursa sayaç geri alınır. (Anket tarafında aynı risk `voterCount` için `updatable=false` ile çözülmüş.)
- Etki: en riskli an kayıt akını sırasında "Kayıtları kapat" (tam o anda yapılır): `goingCount` gerçek GOING sayısından düşük kalır, kontenjan aşılabilir, `CAPACITY_TOO_LOW` kontrolü ve öne çıkan sıralaması şaşar.
- Öneri: `goingCount` için `@Column(updatable = false)` (Poll gibi) ya da `@DynamicUpdate`; durum/alan güncellemeleri hedefli `@Modifying` sorgu ile.

### A12-03 - Orta - Kulüp silinince kulüp anketleri açık ve oylanabilir kalıyor
DOĞRULANDI.
- Yer: `community/extras/ClubExtrasHooks.onCommunityDeleted` (yalnız sohbet odası + `ClubDeletedEvent`); `ClubDeletedEvent` dinleyicileri yalnız `event` ve `community` paketlerinde; `poll` paketinde dinleyici yok. Silinen kulübün üyelik satırları ACTIVE kalıyor (`PollAccess.memberCommunityIds`).
- Adımlar: a12_p1 kulüp açar, kulüp anketi (`scope=COMMUNITY`, `notify=true`) oluşturur, a12_p2 katılır, kulüp `DELETE /api/communities/{id}` (204). Sonra p2: `GET /api/polls/{id}` -> `state=OPEN, canVote=true`; `POST /api/polls/{id}/vote` -> 200; `GET /api/polls?scope=open` anketi listeliyor. Etkinlik ise doğru şekilde iptal oldu.
- Etki: silinmiş kulübe ait anketler oy alıyor, listeleniyor; kapanış hatırlatması gibi bildirimler gitmeye devam eder. Kaskad eksik.
- Öneri: `ClubDeletedEvent` için poll dinleyicisi (OPEN/DRAFT anketleri CANCELLED/CLOSED yap, bildirimleri durdur); ayrıca `PollAccess.canView/eligible` kulübün ACTIVE olmasını da denetlesin.

### A12-04 - Orta - Anket CSV dışa aktarımı `showResults` kuralını (AFTER_CLOSE/AFTER_VOTE) deliyor
DOĞRULANDI.
- Yer: `poll/PollController.export` -> `PollAdminService.csvFor` -> `csv(p)` (görünürlük denetimi yok; yalnız `canManage`).
- Adımlar: `showResults=AFTER_CLOSE` anket açıkken oluşturan/kulüp yöneticisi `GET /api/polls/{id}/export.csv` -> canlı sayımlar (`1,Evet,1,100.0`); aynı kişinin `GET /api/polls/{id}` yanıtında `resultsVisible=false`.
- Etki: oluşturan, sonuç kapanana kadar gizli olması gereken anketi canlı izleyebilir (oylamayı yönlendirme/etkileme riski); küçük kulüplerde tek oy kimlik çıkarımına açık.
- Öneri: CSV'ye de `resultsVisible` mantığını uygulayın (kapanmadan 409 ya da boş); yönetici ucu (`/api/admin/polls`) ayrı kalabilir.

### A12-05 - Orta - Herkese açık destek talebi, kullanıcı uçlarında 500 (NPE) ve varlık sızıntısı üretiyor
DOĞRULANDI.
- Yer: `support/ticket/TicketService.ownTicket` -> `t.getUserId().equals(userId)`; herkese açık talepte `userId == null`.
- Adımlar: `POST /api/public/support/tickets` + `/verify` ile talep (id=1); giriş yapmış kullanıcı ile `GET /api/support/tickets/1`, `POST .../messages`, `POST .../close` -> üçü de 500 (`{"timestamp":..,"status":500,"error":"Internal Server Error"}`, standart `{code,message}` değil); olmayan id -> 404.
- Etki: kimliği doğrulanmış her kullanıcı herkese açık talep numaralarını 500/404 farkıyla tarayabilir; hata yanıtı sözleşme dışı; hata günlüğü gürültüsü.
- Öneri: `ownTicket` içinde `t.getUserId() == null || !t.getUserId().equals(userId)` -> 404.

### A12-06 - Orta - İptal edilen etkinlik, katılımcılara 404; bildirim derin bağlantısı ölü
DOĞRULANDI.
- Yer: `EventService.ensureVisible` (ACTIVE dışı durumlar yalnız `canManage`'e), `UserEventRepository.attending/mineUpcoming/minePast` (yalnız ACTIVE).
- Adımlar: p2 GOING; p1 `POST /api/events/{id}/cancel` -> 204; p2'ye "Etkinlik iptal edildi" bildirimi gelir (`eventId` veri alanı var) fakat `GET /api/events/{id}` (p2) -> 404 `EVENT_NOT_FOUND`; "Etkinliklerim"den de düşer. Oluşturan CANCELLED görüyor.
- Etki: kullanıcı iptal bildirimine dokununca "bulunamadı" görür, iptal nedenini/durumu göremez, kaydı kaybolur. (Not: `cancelReason` yalnız yönetici iptalinde dolu; organizatör iptali neden almıyor.)
- Öneri: RSVP'si olan (GOING/INTERESTED/başvuru) kullanıcıya CANCELLED etkinliği salt okunur göster (durum + iptal), liste modlarında "iptal edilenler" ayrımı.

### A12-07 - Orta - Yemek senkronunda `fit()` hiç çağrılmıyor; 1000 karakteri aşan gün tüm senkronu bozuyor
STATİK (kaynak siteyi çekmek yasak/uygun değil).
- Yer: `menu/MenuSyncService.sync` (`String items = String.join("\n", d.items())`); `fit()` tanımlı ve testli ama kullanılmıyor (`MenuServiceTest` yalnız fonksiyonu sınar). `MenuDay.items` `length=1000`.
- Etki: tek bir günün listesi 1000 karakteri geçerse INSERT/UPDATE hata verir, `catch (Exception)` tüm senkronu keser, kalan günler yazılmaz ve durum "bakımda" (`markMaintenance`) işaretlenir. Aylık tek senkron olduğu için ayın menüsü eksik kalır.
- Öneri: `String items = fit(String.join("\n", d.items()))` ve gün başına try/catch ile hatalı günü atlayıp devam etme.

### A12-08 - Orta - Kulüpten çıkarılan/yasaklanan/ayrılan etkinlik sahibi yönetimi ve RSVP'leri koruyor
STATİK.
- Yer: `EventService.canManage` (`a.id().equals(e.getCreatedBy())` koşulu kulüp üyeliğinden bağımsız), `EventRoomClubListener` ("Etkinliği kendisi oluşturduysa odada kalır"), `CommunityService.remove/leave` etkinlik RSVP'lerine dokunmaz.
- Etki: kulüpten yasaklanan kişi o kulübün etkinliğini düzenleyebilir/iptal edebilir, katılımcı listesini (bölüm bilgisiyle), QR/elle yoklama kodunu, sertifika akışını yönetmeye devam eder; yasaklı/ayrılan sade üyenin diğer kulüp etkinliklerindeki GOING koltukları ve yoklama hakkı kalır.
- Öneri: oluşturan istisnasını yalnız kulüp üyeliği ACTIVE (ve `MANAGE_EVENTS`) iken geçerli sayın; `ClubMemberLeftEvent` dinleyicisi kulüp etkinliklerindeki RSVP'leri temizlesin (özel kulüp için zorunlu).

### A12-09 - Orta - Toplu bildirimlerde sessiz 500/1000 kesmesi (büyük kulüp/etkinlik)
STATİK.
- Yer: `EventService.NOTIFY_LIMIT=500` (`notifyGoing`: güncelleme/iptal), `EventAdmissionService` (mod değişimi/iptal `NOTIFY_LIMIT`), `CommunityService.delete` (üye bildirimi `PageRequest.of(0, 500)`), `AnnouncementService.MAX_RECIPIENTS=1000` (organizatör duyurusu), `PollAccess.communityUserIds` (100.000).
- Etki: kapasitesi 500'ü aşan etkinliklerde iptal/saat değişikliği bildirimi yalnız ilk 500 kişiye gider (kalanlar etkinliğin iptal olduğunu öğrenmez); organizatör duyurusu 1000'inci kişiden sonrasına gitmez ve `recipients` bunu belirtmez; 500+ üyeli kulüp silindiğinde geri kalan üyeler bilgilendirilmez.
- Öneri: sayfalı döngü (`afterId` imleci) veya `sendBulk`; üst sınır gerekiyorsa yanıtta `truncated:true`.

### A12-10 - Düşük - Duyuru kapsamı erişim kontrolü değil: kapsam dışı kullanıcı kimlikle okuyabilir
DOĞRULANDI.
- Yer: `DepartmentAnnouncementService.get/markRead` yalnız `VISIBLE` (yayın/süre) ile süzülür; kapsam yalnız `feed(scope=mine)`/`unreadCount`'ta uygulanır. `scope=all` herkese açık listeliyor.
- Adım: "Bölüm=İşletme" duyurusu; Bilgisayar Mühendisliği kullanıcısı `GET /api/announcements/{id}` -> 200 ve tam gövde.
- Etki: "yalnız X bölümüne" duyurusu gizli bilgi taşıyorsa (ör. sınav yeri, not) sızar. `scope=all` mobilde açıkça sunulan bir sekme ise tasarım gereği olabilir; ancak kapsamın gizlilik değil ilgi filtresi olduğu belgelenmeli.
- Öneri: karar verin; gizlilik isteniyorsa `get`/`read-all` da kapsam denetlesin.

### A12-11 - Düşük - Dönem silme dersleri "dönemsiz" bırakıp güncel döneme karıştırıyor
STATİK.
- Yer: `TimetableService.deleteSemester` (`UPDATE tt_course SET semester_id = NULL`), `timetable()` / `activeOn()` (`semester_id IS NULL` dersler her tarihte ve güncel dönemde görünür).
- Etki: eski dönemi silmek o dönemin derslerini güncel haftaya ekler; çakışma denetimi ve yerel hatırlatmalar hayalet dersleri üretir. Kullanıcı onayı/uyarısı yok.
- Öneri: dönem silinirken dersleri de sil (onaylı) veya taşıma seçeneği sun.

### A12-12 - Düşük - `PollService.update` ile eşzamanlı oy yarışı: seçenek silme oyları CASCADE ile uçurabilir
STATİK (DOĞRULANAMADI, dar pencere).
- Yer: `PollService.update` (`hasVotes = voterCount > 0`; yapısal değişimde `options.deleteByPollId` + yeniden yazma), `V330` `poll_vote.option_id ... ON DELETE CASCADE`. Oy yolu sayaçları en sonda yazdığı için `voterCount` henüz 0 iken bekleyen bir oy satırı (ballot + poll_vote) varsa güncelleme seçenekleri siler, oy satırları CASCADE ile gider, oy yolu ise sayaç artırır -> `voterCount` > gerçek oy.
- Öneri: `update` içinde yapısal değişiklikte ballot sayısını (`COUNT(poll_ballot)`) da denetleyin veya oy yolunda anket satırı üzerinde `FOR SHARE`.

### A12-13 - Düşük - Etkinlik duyurusu günlük sınırı (3) yarışa açık
STATİK.
- Yer: `event/extras/AnnouncementService.send` (`@Transactional` yok; `countBy...` okuma -> kayıt yazma). Yorum "hak önce tüketilir" diyor ama sayım kayıttan önce yapıldığı için eşzamanlı istekler sınırı aşar.
- Öneri: sayacı atomik yapın (kayıt eklendikten sonra say, aşıldıysa sil) veya etkinlik satırı kilidi.

### A12-14 - Düşük - Mobil etkinlik ekranları cihaz saat dilimini kullanıyor (sunucu/akademik Istanbul)
STATİK (mobil çalıştırılmadı).
- Yer: `mobile/lib/features/events/events_page.dart` `_norm` (`DateTime.tryParse(..)?.toLocal()` ile gün gruplama; ay isteği `_ym(cihazAyı)`), `event_detail_page.dart`, `event_form_page.dart`; akademik taraf `istanbulWall` kullanıyor.
- Etki: Istanbul dışındaki bir cihazda (yurtdışı, emülatör UTC) gece yarısına yakın etkinlikler yanlış güne/aya düşer (ör. 01 Aralık 00:30 İstanbul, UTC cihazda 30 Kasım gösterilir ve Kasım takviminden hiç gelmez); etkinlik oluştururken seçilen saat cihaz yerel saati sayılır.
- Öneri: gün/saat gösterimi ve form dönüşümleri için akademikteki gibi sabit Europe/Istanbul duvar saati.

### A12-15 - Düşük - `cancelRsvp` bitmiş etkinlikte de çalışıyor
STATİK.
- Yer: `EventService.cancelRsvp` (bitiş/yoklama denetimi yok). Etki: bitmiş ve yoklaması alınmış etkinlikte RSVP silinince `goingCount` düşer (geçmiş istatistik/öne çıkan sıralaması), katılımcı listesi geçmişi değişir; sertifika `attended` yoklamaya bağlı olduğundan sürüyor.
- Öneri: `endsAt` geçtiyse 409 `EVENT_ENDED`.

### A12-16 - Düşük - Anket liste/sayaç tutarsızlıkları
STATİK + kısmen DOĞRULANDI.
- Yer: `PollService.list` (liste: `audienceMatches || canManage`; sayaçlar SQL: yalnız kitle), `community:` kapsamında taslak görünürlüğü yalnız kulüp yöneticisi (`canView` ise oluşturanı da kabul eder), "mine" listesi kulüpten ayrılınca da kapalı kulüp anketlerini gösterir.
- Etki: `totalCount`/`openCount` sayfadaki öğe sayısıyla uyuşmaz (yönetici/oluşturan için); A12-01 bunu daha da görünür kılıyor.

### A12-17 - Düşük - Anket kitlesi sınıf alanı doğrulanmıyor
STATİK.
- Yer: `PollService.applyAudience` yalnız uzunluk (<=8) denetler; duyuru/sınav tarafı `ExamService.grade` ile (PREP,1..6,MASTER,PHD) doğrular. "3. sınıf" gibi serbest metin kimseyle eşleşmez (anket kimseye gösterilmez/oylanamaz).
- Öneri: aynı `GRADES` kümesiyle doğrulayın.

### A12-18 - Düşük - Toplu (broadcast) bildirimler alt tür yazmıyor; belge/kod kayması
STATİK.
- Yer: `NotificationRepository.insertForAll/insertForLang` (`subtype` sütunu yazılmıyor, anket genel yayını `POLL` alt türsüz), `NotificationSubtype` üst yorumu "ana tur bayrağından bağımsızdır" der ama `doSend` ve SQL `p.polls AND p.announcements` ile ana bayrağı da şart koşuyor (V880 yorumu ile uyumlu, enum yorumu eski).
- Etki: genel anket bildirimi liste/filtre tarafında anket olarak tanınmaz; yorum yanıltıcı.

### A12-19 - Düşük - iOS'ta ders/sınav yerel hatırlatmaları çalışmıyor
STATİK.
- Yer: `mobile/lib/core/notify/local_reminders.dart` açıklaması ("iOS'ta native kod yoksa no-op"); `mobile/ios` altında `LocalReminders`/`bu_kampus/academic` kanalı yok.
- Etki: iOS kullanıcıları ders/sınav hatırlatma ayarlarını açık görür ama bildirim almaz (sessiz). Ayarlar ekranında iOS'ta uyarı/gizleme yok (kod incelemesi; ekran çalıştırılmadı).
- Öneri: iOS için `UNUserNotificationCenter` uygulaması veya ayarı iOS'ta pasif + açıklamalı göster.

### A12-20 - Düşük - Sınav hatırlatma/ICS: süren sınav listeden düşüyor
STATİK.
- Yer: `ExamService.upcoming` SQL `starts_at >= now - 1h`; uzun (3 saatlik) sınav başladıktan 1 saat sonra "yaklaşan"dan ve ICS/hatırlatma çıktısından çıkar. Düşük etki.

### A12-21 - Düşük - Kulüp katılım sorusu düzenlenince eski yanıtlar yeni soru metnine bağlanıyor
STATİK.
- Yer: `ClubJoinFormService.setQuestions` (aynı sıradaki satırı yerinde günceller, bekleyen yanıtları korur). Soru metni değişirse yöneticiye eski cevap yeni soru altında görünür.
- Öneri: metin değişince o sorunun yanıtlarını sil veya yeni soru kimliği.

### A12-22 - Bilgi - Kapak 16:9 / logo 1:1 oranı sunucuda zorlanmıyor
`CommunityService.setCover/setLogo`, `EventService.setCover` yalnız `MediaService` boyut/tür doğrular; kırpma yalnız mobil `media_crop`. Başka istemci (web, doğrudan API) herhangi bir oranı yükleyebilir; kartlarda bozuk kırpma olabilir. Öneri: sunucuda merkez kırpma veya oran denetimi.

### A12-23 - Bilgi - Sertifika yoklama alınır alınmaz (etkinlik bitmeden) verilebiliyor
`CertificateService.issue` yalnız `attended` ister; etkinlik bitişi beklenmez. Kasıtlı olabilir, ürün kararı.

---

## DOĞRULANAMADI / bakılamadı

Dinamik olarak çalıştırılamayanlar (statik inceleme sonucu belirtilmediyse hiç incelenmedi):
- Mobil ekran durum makineleri (36-39, 41, 42, etkinlik/anket/akademik/destek ekranları): yalnız statik göz atıldı (poll detay oy/geri çekme akışı, `_fail` ile durum tazeleme sağlam görünüyor); cihaz/emülatör testi yapılmadı. Boş/hata/yükleniyor durumları örneklem dışı.
- A12-02 eşzamanlı kayıt+düzenleme deneyi (RSVP hız sınırı 5/dk/etkinlik ve çok sayıda kullanıcı gerektirir).
- A12-12 (anket güncelle/oy yarışı) ve APPROVAL modunda bekleme listesi terfi yarışları.
- `PollCloseJob`/`PollNotifier` zamanlayıcıları gerçek zamanda (10 dk döngü) ve hatırlatma zamanlayıcısı çift gönderimi: kod okundu, çalıştırılmadı. FCM kapalı olduğundan push teslimi doğrulanamadı; uygulama içi bildirim kutusu doğrulandı.
- Haber/duyuru scraper, menü aylık senkron, kaynak site hata/bakım modu: kaynak siteye istek atılmadı (kural). Haber favorileri, arama, SSS ve geri bildirim panosu oyları yalnız statik okundu (oy ekleme/çıkarma koşullu SQL ile atomik görünüyor).
- Akademik takvim servisi (`AcademicCalendarService`, tam/yarım gün, tatil türü) ve resmi sınav programı `scope=all` kod yolu ayrıntılı okunmadı; ICS çıktısı bir takvim uygulamasına içe aktarılmadı (yalnız `IcsBuilder`/`IcsWriter` okundu: CRLF, 75 oktet katlama ve kaçış doğru; resmi tatiller EXDATE olarak çıkarılmıyor, düşük).
- Kulüp gönderileri (`authorRole`), kulüp sohbet odası bağlantısı, kulüp davet/sahiplik devri, "Kulüplerim" bölümleri, kategori kuralları: yalnız rol yönetimi (`ClubRoleService`: yükseltme koruması, sahip korunuyor) ve katılım formu okundu. Son-yönetici koruması: sahip ayrılamaz/çıkarılamaz (`OWNER_CANNOT_LEAVE`, `OWNER_PROTECTED`), hesap silmede otomatik devir var; ADMIN rolünün sayısı için ek denetim yok.
- Etkinlik kapak yükleme gerçek dosya, sertifika iptali (V690) ve yönetici etkinlik uçları (`event.admin`) dinamik olarak çalıştırılmadı.
- Test verisi: yığına eklenen kayıtlar `a12_p1..p3`, `a12_pub` kullanıcıları, "A12 Test Kulubu", "A12 Kulup Iki" kulüpleri, birkaç `A12 ...` etkinlik/anket/duyuru; yığın bozulmadı, silme yapılmadı.

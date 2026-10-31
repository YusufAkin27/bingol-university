# A15 — Mobil çevrimdışı / önbellek / kuyruk dayanıklılık denetimi

Tarih: 2026-10-31 · Denetçi: A15 · Aşama: DENETİM (üretim kodu değiştirilmedi) · Taban: `HEAD b405782` (`git archive` kopyası, ASCII yol `C:\bu_qa\a15\mobile`)

Kapsam: `mobile/lib/core/{cache,outbox,connectivity,realtime}`, `core/api.dart`, `core/session.dart`, `core/app_gate.dart`, `features/chat`. Sahte ağ (`MockClient`), sahte saat, `Directory.systemTemp` dosya sistemi, gerçek yerel `HttpServer`/`WebSocket` sunucusu ve widget testleri kullanıldı. Üretim sunucusuna erişilmedi. A7 test yığını (`http://localhost:18081`, READY) yalnızca sunucu davranışını (idempotency, attachmentIds) doğrulamak için kullanıldı.

## 1. Özet

| | |
|---|---|
| Senaryo grubu | 6 (kuyruk, mesaj önbelleği, ETag/disk önbelleği, görsel önbelleği, bağlantı, bellek/sızıntı) |
| Yazılıp çalıştırılan test | 66 (5 dosya) — 36 yeşil/bilgi amaçlı, 30 kırmızı (= bulgu kanıtı) |
| Bulgu | **KRİTİK 4 · YÜKSEK 5 · ORTA 11 · DÜŞÜK 5** (toplam 25) |
| Sunucu doğrulaması | Aynı `clientId` ile tekrar gönderim aynı mesajı döner (metin ve ekli); `precheck` tekrar-gönderim yolundan SONRA çalışır (yanıt-kayıp yeniden denemesi `ATTACHMENT_INVALID` üretmez) — doğrulandı |

Test dosyaları (repo dışı): `C:\bu_qa\a15\tests\` — `a15_outbox_test.dart`, `a15_cache_test.dart`, `a15_ui_test.dart`, `a15_conn_test.dart`, `a15_image_test.dart`.
Çalıştırma:
```bash
cd "<repo>" && git archive HEAD mobile | tar -x -C /c/bu_qa/a15      # temiz kopya
mkdir -p /c/bu_qa/a15/mobile/test/a15 && cp /c/bu_qa/a15/tests/*.dart /c/bu_qa/a15/mobile/test/a15/
cd /c/bu_qa/a15/mobile && export PUB_CACHE='C:\pubcache' PATH="/c/src/flutter/bin:$PATH"
flutter pub get --offline && flutter test test/a15/a15_outbox_test.dart -r expanded
```
Kırmızı test = bulgu (testler İSTENEN davranışı doğrular). Test adlarındaki `S1.x`, `S2.x`… bulgulardaki "Test" alanına karşılık gelir. Bazı testler (`S3.2` matris, `U2/U3`) bilgi amaçlıdır ve yeşil geçer.

### En kritik 5 (özet)
1. **A15-01** Bozuk/okunamayan kuyruk deposu açılışta TÜM bekleyen mesajları ve medya dosyalarını sessizce siler.
2. **A15-02** WebSocket ile gönderilen metin, sayfa 8 sn içinde kapanırsa hiçbir kayda alınmadan KAYBOLUR (kod okuma; test yok).
3. **A15-03** Uçuştaki GET, çıkış + başka hesapla giriş sonrası dönünce önceki kullanıcının yanıtı yeni kullanıcının önbelleğine yazılır (önbellek anahtarında kullanıcı yok).
4. **A15-05** Çıkış sırasında süren `refresh` bitince belirteçleri geri yazar: çıkış yapılmış oturum hortlar (secure storage'a yazılır).
5. **A15-06 / A15-07** Captive portal HTML 200 yanıtı "başarı" sayılıp önbelleğe `null` yazar; bozuk mesaj kaydı sohbeti kalıcı açılmaz bırakır.

## 2. Bulgular

Her bulgu: şiddet · konum · tekrar testi · beklenen / gerçek · etki · öneri (+ regresyon testi).

### KRİTİK

**A15-01 — Kuyruk deposu okunamazsa/bozuksa tüm kuyruk ve medya sessizce silinir** · KRİTİK
- Konum: `mobile/lib/core/outbox/outbox.dart:334-352` (`load`: `catch (_) { _items.clear(); }` sonra `await _save()` → `_store.write(null)`; ardından `_sweepOrphanFiles()` her medya dosyasını siler).
- Test: `a15_outbox_test.dart` → `S1.4a` (kesik JSON; kırmızı). Ek: `S1.4b` (tek kayıt bozuk → yalnız o düşer; yeşil).
- Beklenen: bozuk/okunamayan ham değer korunur (yedek anahtara taşınır), geçerli kayıtlar kurtarılır, medya dosyaları silinmez. Gerçek: 3 metin + 1 medya mesajı → `ob2.items.length == 0`, depo `NULL`, `outbox_media` boş.
- Etki: `flutter_secure_storage` okuması Android Keystore geçersizleşmesi / yedekten geri yükleme / OS güncellemesi sonrası geçici olarak istisna atabilir; tek bir okuma hatası kullanıcının gönderilmemiş tüm mesajlarını geri döndürülemez biçimde yok eder. Kullanıcıya hiçbir şey gösterilmez.
- Öneri: okuma istisnasında `_loaded=false` bırakıp sonra yeniden dene (silme yok); JSON bozuksa ham değeri `outbox_v1_corrupt` anahtarına yaz, kayıt kayıt kurtar (`jsonDecode` dizisini öğe öğe işle), `_sweepOrphanFiles`'ı yalnız başarılı yüklemeden sonra çalıştır.
- Regresyon: `S1.4a` beklentisi (`store.value != null`, `kept > 0`) + okuma istisnası atan sahte depo ile "kuyruk korunur, ikinci `load` kurtarır".

**A15-02 — WS ile gönderilen metin, sayfa kapanırsa kayıt altına alınmadan kaybolur** · KRİTİK (koşullu; yalnız kod okuma, otomatik test yazılmadı)
- Konum: `mobile/lib/features/chat/chat_detail_page.dart:945-960` (`_rt.sendMessage` true → yalnız 8 sn'lik `_ackTimers` kurulur), `:411-413` (`dispose` bu zamanlayıcıları iptal eder), `:693-722` (`errors` akışı yalnız açık sayfada işlenir).
- Beklenen: WS gönderimi de kalıcı kuyruğa (veya en azından bellek dışı bir kayda) alınır; ack gelmezse sayfadan bağımsız olarak REST ile yeniden denenir. Gerçek: ack gelmeden kullanıcı geri tuşuna basarsa (veya sunucu `/user/queue/errors` ile reddederse) `_sendRest` hiç çağrılmaz, `Outbox`'ta kayıt yoktur → mesaj gider gitmez izi kalmaz.
- Koşul: soket "bağlı" görünür ama ölüdür (Wi-Fi→LTE geçişi; `_recvWatch` ölü soketi 30 sn'ye kadar fark etmez) ya da sunucu mesajı reddeder, ve kullanıcı 8 sn içinde sohbetten çıkar. Tipik "yaz, çık" davranışında gerçekçi.
- Öneri: `_transmit` metin yolunda `outbox.enqueue(...)` ile önce kuyruğa al (kuyruk zaten clientId ile idempotent), WS ack/teslim gelince `outbox.remove`/`deliveries` ile temizle; ya da `dispose`'ta ack beklenen mesajları kuyruğa devret.
- Regresyon: widget testi — bağlı sahte `ChatRealtime`, ack gönderme, sayfayı kapat, `Outbox.items`'ın o clientId'yi içerdiğini ve bağlantı gelince REST'e gittiğini doğrula.

**A15-03 — Çıkışta temizlenmeyen kullanıcıya özel depolar (başka hesaba sızıntı)** · KRİTİK (kural gereği "sızıntı"; veri hassasiyeti düşük-orta)
- Konum: `mobile/lib/features/search/search_page.dart:175,214-232` (`recent_searches`, FlutterSecureStorage); `mobile/lib/features/chat/photo_autosave.dart:37-46` (`photo_autosave.json`: kaydedilen ek kimlikleri, ayar, `since`); `mobile/lib/main.dart:165-169` yalnız `MessageCache` + `ImageDiskCache` temizler, `ApiClient.setTokens(null)` (api.dart:516-530) disk/api/kuyruk temizler.
- Test: `a15_cache_test.dart` → `S2.9` (kırmızı): çıkış sonrası dosya listesi karşılaştırması `api_cache`, `msg_cache`, `img_cache`, `outbox_media`, kuyruk → **boş (iyi)**; fakat `recent_searches` = `["ali yilmaz"]` ve `photo_autosave.json` duruyor.
- Beklenen: çıkış/hesap silme/oturum iptalinde tüm kullanıcıya özel yerel veri silinir (`docs/MOBILE_UI.md` 4.2: "Çıkışta … silinir"). Gerçek: önceki kullanıcının son 8 arama terimi (kişi adı olabilir) sonraki kullanıcıya arama ekranında görünür; otomatik kaydetme tercihi ve kaydedilmiş fotoğraf kimlik listesi hesaplar arasında taşınır. `academic_reminders` (ders hatırlatıcı ayarı) de kullanıcıya özel ve temizlenmiyor.
- Öneri: `ApiClient.onUserDataCleared`'a arama geçmişi, `PhotoAutoSave.instance.reset()` (dosya + bellek) ve hatırlatıcı deposu ekle; kural: yeni kullanıcıya özel depo = temizleme kancası + testte "çıkış sonrası tüm depolar boş" envanter testi (secure storage anahtar listesi).
- Regresyon: `S2.9` olduğu gibi (anahtar envanteri genişletilerek).

**A15-04 — Uçuştaki GET, hesap değişiminden sonra dönerse önceki kullanıcının yanıtı yeni kullanıcıya servis edilir** · KRİTİK
- Konum: `mobile/lib/core/api.dart:216-221` ve `:402-412` — önbellek anahtarı `'$lang|u|$path'` (kullanıcı kimliği YOK); yanıt gelince `_putMemory` + `diskCache.write` kimlik/oturum kontrolü olmadan çalışır.
- Test: `a15_cache_test.dart` → `S2.11` (kırmızı): A'nın `/events` isteği havada → `signOut` → B girişi → yanıt geç döner → B `/events` açar → B'ye `{who: A, joined: true}` döner, ağ isteği sayısı 1.
- Beklenen: çıkış/giriş sonrası dönen eski oturum yanıtları atılır. Gerçek: A'nın yanıtı B'nin önbelleğine yazılır; taze pencerede (menü/haber/etkinlik/kulüp listeleri 20 dk; `freshFor`) ağa hiç gidilmeden, ağ yokken (bayat) ise günlerce sunulur. Kişiye özel alanlar (`joined`, `myRsvp` vb.) başka hesaba sızar.
- Öneri: `ApiClient`'a oturum "nesil" sayacı (`_gen`, `setTokens(null/ilk giriş)`'te artar); istek başında nesil yakala, yanıtta `gen != _gen` ise önbelleğe YAZMA ve `ApiError(0,'SESSION_CHANGED')` at. Alternatif: anahtara kullanıcı kimliği ekle.
- Regresyon: `S2.11` olduğu gibi.

### YÜKSEK

**A15-05 — Çıkışla yarışan `refresh`, çıkış yapılmış oturumu geri getirir** · YÜKSEK
- Konum: `mobile/lib/core/api.dart:496-511` (`_doRefresh` → `await setTokens(t)`), `:516-530` (`setTokens(non-null)` ve `tokens == null` → "ilk giriş" sayılır, cache temizler ve `onTokensChanged` → `Session._persist` belirteçleri yazar).
- Test: `a15_cache_test.dart` → `S5.x` (kırmızı): `signOut` sırasında `refresh` uçuşta → bitince `api.tokens` DOLU, `state=signedOut`, secure storage `refresh = r2`.
- Etki: kullanıcı "çıkış yaptım" der; uygulama yeniden açılınca `restore()` kayıtlı belirteçlerle otomatik girer (tetikleyiciler: STOMP `_proactiveRefresh`, 401 yenilemesi, `AppGate`). Güvenlik/gizlilik algısı ve paylaşılan cihaz riski.
- Öneri: `_doRefresh` başında oturum nesli yakala; `setTokens(t)` öncesi `tokens == null || gen değişmiş` ise sonucu at. Çıkışta `_inflight`'i iptal/yok say.
- Regresyon: `S5.x`.

**A15-06 — Captive portal / proxy 200 (JSON olmayan gövde) "başarı" sayılır; `null` gövde önbelleğe yazılır** · YÜKSEK
- Konum: `mobile/lib/core/api.dart:458-470` (`_decode`: `jsonDecode` hatası `json = null` olarak yutulur, 2xx'te `null` döner), `:402-412` (aynı yanıt bellek/diske yazılır), `core/connectivity/connectivity_service.dart:23` (her HTTP yanıtı `reportSuccess`).
- Test: `a15_cache_test.dart` → `S3.5` (kırmızı): portal HTML 200 → `api.get` `null` döner; portal gidince ikinci `get` AĞA GİTMEDEN `null` döner (ağ isteği = 1).
- Etki: otel/kafe Wi-Fi'ında listeler "boş/null" olarak 20 dk "taze" sunulur (`freshFor`), diske 1-7 gün yazıldığı için çevrimdışı moda da bu bozuk kayıt bayat veri olarak döner; ekranlar `as Map` dönüşümünde patlayabilir. Bağlantı durumu "çevrimiçi" görünür.
- Öneri: `Content-Type` JSON değilse veya gövde çözülemezse (2xx) `ApiError(0,'BAD_RESPONSE')` fırlat, `reportSuccess` ÇAĞIRMA ve önbelleğe YAZMA; 204 dışında `null` gövdeyi önbellekleme.
- Regresyon: `S3.5` (ikinci çağrı ağa gitmeli, ilk çağrı `ApiError`).

**A15-07 — Tip-bozuk / uyumsuz mesaj kaydı sohbeti kalıcı açılmaz bırakır; şema sürümü kontrol edilmez** · YÜKSEK
- Konum: `mobile/lib/core/cache/message_cache.dart:136-150` (`_loadConv` yalnızca `Map` olup olmadığına bakar; yazılan `'v': 1` (`:309`) hiç okunmaz), `mobile/lib/features/chat/chat_detail_page.dart:454-466` (`readMessages` + `_msgs.sort(_key…)` `try` DIŞINDA; `_key`/`_id` `(m['id'] as num?)` → `TypeError`), `message_cache.dart:177-186` (`upsertMessage` aynı `TypeError`; `main.dart:161` `unawaited`).
- Test: `a15_cache_test.dart` → `S2.4b` (kırmızı: tip-bozuk kayıt döner, `upsertMessage` `TypeError` atar); `a15_ui_test.dart` → `U1` (kırmızı): kaydı `{"v":99,"m":[{"id":"7"…}]}` olan sohbet açılır, sunucu mesajı (`SUNUCU MESAJI`) EKRANA GELMEZ (sohbet sürekli yükleniyor; ağ cevabı uygulanmaz).
- Etki: `_boot` hata verip çıkar, bozuk dosya yeniden yazılmadığı için ayrılıp dönünce de aynı; çözüm yalnız çıkış / 50 sohbet budaması. Uygulama güncellemesiyle mesaj şeması değişirse (eski sürüm kaydı) aynı çökme tüm sohbetlerde oluşur — sürüm yükseltme göçü yok.
- Öneri: `_loadConv`'da `v == 1` ve her öğede `id is num` doğrula, aksi halde dosyayı sil; `_boot`'ta önbellek bloğunu `try/catch` içine al (başarısızsa kaydı yok say ve devam et); `upsertMessage`/`markGone` içine `try/catch`.
- Regresyon: `S2.4b` ve `U1`.

**A15-08 — 5xx dalgası (502/503 deploy) kuyruktaki mesajları "Gönderilemedi"ye çevirir; ağ geçidi hatası "çevrimiçi" sayılır** · YÜKSEK
- Konum: `mobile/lib/core/outbox/outbox.dart:663-676` (`status >= 500` → `serverFails++`, `maxServerFails = 5`; geri çekilme 2/5/15/60 sn ⇒ ~84 sn'de kalıcı hata), `mobile/lib/core/connectivity/connectivity_service.dart:23` (502/503/504 de `reportSuccess`), `core/api.dart:345-360`.
- Test: `a15_outbox_test.dart` → `S1.6` (kırmızı): 180 sn boyunca 503 → baş öğe `failed` (diğerleri aynı konuşmada sırada bekliyor; sırayla aynı kader). `a15_conn_test.dart` → `C1` (kırmızı: 502 sonrası `online=true`, `reconnects=1`), `C2` (bilgi: 6 "bağlantı geri geldi" olayı = 5 boş gönderim denemesi).
- Etki: backend yeniden başlatması / Docker deploy (1-2 dk, nginx 502) sırasında çevrimdışı yazılan mesajlar kalıcı hataya düşer; kullanıcı elle "yeniden dene"ye mecbur kalır (sessiz kuyruk vaadi bozulur). 502/503 ile `reconnects` artar → gereksiz drain/`AppGate` kontrolü.
- Öneri: 502/503/504 ve `Retry-After`'lı yanıtları `isNetwork` gibi ele al (`serverFails` sayma) ya da 5xx kalıcı hata eşiğini süreye bağla (örn. ilk 5xx'ten itibaren ≥ 30 dk). `ConnectivityService.reportSuccess` yalnız `status < 500` ve JSON yanıtta.
- Regresyon: `S1.6`, `C1`.

**A15-09 — STOMP `TOKEN_EXPIRED/UNAUTHORIZED` döngüsünde geri çekilme yok (bağlanma fırtınası)** · YÜKSEK
- Konum: `mobile/lib/core/realtime/stomp_client.dart:265-272` (`await refreshToken(); if (_wanted) _open();` — gecikme yok, `_attempt` artmaz).
- Test: `a15_conn_test.dart` → `C4` (kırmızı), gerçek yerel WebSocket sunucusu her CONNECT'e `ERROR TOKEN_EXPIRED` döner: 3 sn'de **191 bağlantı + 190 `/auth/refresh`**.
- Etki: sunucu ne zaman olursa olsun yeni (taze) token'ı da reddederse (rol/şifre değişimi işareti, saat kayması, bakım) istemci saniyede ~60 refresh + bağlantı üretir; refresh rate limit'ine takılıp 429'a düşene dek sunucuya yük ve her turda refresh token döndürmesi. 20k kullanıcıda kendi kendine DoS.
- Öneri: bu dalda `_scheduleReconnect()` kullan (üstel), art arda N (örn. 3) UNAUTHORIZED sonrası `StompFatal.sessionExpired` bildir.
- Regresyon: `C4` (`connects.length < 10`).

### ORTA

**A15-10 — `maxItems` aşımında en eski bekleyen mesaj sessizce atılır, arayüz "gönderildi" gösterir** · ORTA
- Konum: `outbox.dart:371-376` (`_prune`: önce `failed`, yoksa `removeAt(0)`), `chat_detail_page.dart:309-316` (kuyrukta olmayan `pending` balon `_state = null` yapılır, yani gönderilmiş gibi görünür).
- Test: `S1.8` (kırmızı): 101. enqueue → `q0` kuyrukta değil, `failed` da değil, teslim olayı yok.
- Etki: 100'den fazla çevrimdışı mesaj olağan dışı ama bot/kalabalık grup senaryosunda mümkün; kayıp mesaj "gitmiş" görünür (yanıltıcı). Aynı kalıp `dropAfter` (7 gün) silmesi ve `BLOCKED` sessiz çıkarma için de geçerli (engel için bilinçli).
- Öneri: tavan dolunca yeni enqueue'yu reddet (balon `failed`), eskiyi atma; atılan her öğe için `failed` bildir.

**A15-11 — Cihaz saati değişimi kuyruğu bozar** · ORTA
- Konum: `outbox.dart:359-370` (`dropAfter/maxAge` duvar saatine göre), `:347` (yeniden açılışta `createdAt` ile sıralama).
- Test: `S1.7b` (kırmızı: saat yanlışlıkla +8 gün → bekleyen mesaj SİLİNİR, saat düzelse de geri gelmez), `S1.7c` (kırmızı: saat geri alınırsa 30 saatlik mesaj `EXPIRED` olmaz), `S1.1c` (kırmızı: gönderim sırası `[b0,b1,b2,a0…a4]`, yani saat geri alındıktan sonra yazılan mesajlar önce gider).
- Öneri: sıralamayı `createdAt` yerine artan yerel sıra numarası (persist edilen `seq`) ile yap; süre sınırlarında ileri sıçrama için `failed` yap (silme değil), saat geri alınmışsa (`createdAt > now`) `createdAt = now` düzelt.

**A15-12 — `List.sort` kararsız: aynı milisaniyedeki 50 mesaj yeniden açılışta karışır** · DÜŞÜK
- Konum: `outbox.dart:347`. Test: `S1.1b` (kırmızı: ilk giden `m16`, beklenen `m00`). Gerçek kullanımda çoğunlukla farklı ms olduğundan DÜŞÜK; öneri A15-11 ile aynı (`seq`).

**A15-13 — `ATTACHMENT_*` hatası için sınırsız yeniden yükleme** · ORTA
- Konum: `outbox.dart:640-648` (`attId` sıfırlanır, `ApiError(0,'NETWORK')` fırlatılır → `serverFails` artmaz, `maxServerFails` işlemez).
- Test: `S1.11` (kırmızı): kalıcı `ATTACHMENT_INVALID` ile 40 deneme (4 sa) = **40 yükleme**, durum hâlâ `pending`. 24 saatte backoff tavanı 5 dk ⇒ ≈290 yükleme; 50 MB video ⇒ ~14 GB mobil veri.
- Sunucu doğrulaması: aynı `clientId` ile yeniden deneme `precheck`'ten ÖNCE yakalanır (tekrar gönderimde `ATTACHMENT_INVALID` gelmez), dolayısıyla döngü yalnız gerçekten geçersiz ek (temizlenmiş/uygunsuz) içindir; yine de sınırsız.
- Öneri: ek yeniden yükleme sayacı (en çok 2) → sonra `failed`; mobil veri/video için yalnız Wi-Fi veya kullanıcı onayı.

**A15-14 — Kuyruk deposu yazma hatası sessiz: mesaj yalnız bellekte, uygulama ölürse kayıp** · ORTA
- Konum: `outbox.dart:502-506` (`_save` hataları yutar), `:440-447` (`enqueue`/`enqueueMedia` `unawaited(_save())`).
- Test: `S1.12` (kırmızı): yazma `FileSystemException(ENOSPC)` → `enqueue` true; yeniden açılışta 0 mesaj.
- Öneri: yazma hatasında yeniden dene (kısa backoff) ve `enqueue` sonucunu `false` yap (balon "Gönderilemedi"); en azından ikinci bir yerel dosyaya yaz.

**A15-15 — `failed` ögeler medya kotasını tutar; kota dolunca neden belirtilmeden reddedilir ve kalıcı değildir** · ORTA
- Konum: `outbox.dart:479` (`mediaBytes` tüm öğeleri sayar), `:482-484`; `chat_detail_page.dart` `_queueMedia` false → `local['_state']='failed', _error=null`.
- Test: `S1.9` (kırmızı): 900 B `failed` medya + 300 B yeni → reddedilir (tavan 1000).
- Etki: kalıcı hatalı birkaç video 200 MB kotayı doldurur, sonraki tüm çevrimdışı medya gönderimleri gerekçesiz "Gönderilemedi" olur; ekran terk edilirse reddedilen medya mesajı (yalnız bellekte) kaybolur.
- Öneri: kotayı yalnız `pending` öğelerle say, `failed` ögelere de süre sınırı (örn. 3 gün) ve kullanıcıya "yer yok" metni; reddedilen medya bayt/dosya için ekran terk edilirken uyarı.

**A15-16 — `clear()` sırasında süren `drain`, eski hesabın sonraki mesajlarını gönderir** · ORTA
- Konum: `outbox.dart:590` (`for (final it in List.of(_items))` anlık kopya; `clear()` sonrası öğe kümede yok ama döngü gönderir), `:560-575`.
- Test: `S1.13` (kırmızı): `x1` uçuşta iken `clear()` → `[x1, x2]` gönderildi.
- Etki: dar pencere (token `null` iken 401 gelir; B'nin girişi çok hızlıysa B'nin kimliğiyle A'nın mesajı aynı sohbete gidebilir). Her gönderimden önce `contains(it.clientId)` ve oturum nesli kontrolü eksik.
- Öneri: döngüde her adımda `byClientId(it.clientId) != null`; `Outbox.clear` bir "kuşak" sayacı artırır, drain başlangıcındaki kuşakla farklıysa çıkar.

**A15-17 — Oturum sonlanınca (SESSION_REPLACED, refresh reddi, çıkış) bekleyen mesajlar uyarısız silinir** · ORTA (tasarım kararı, bilgilendirme yok)
- Konum: `api.dart:516-523` (`outbox.clear()`), `session.dart` `forceSignOut`/`signOut`.
- Etki: başka cihazda giriş (tek oturum kuralı) veya kısa süreli çevrimdışı kalmış kullanıcının yazdığı ama gitmemiş mesajlar giriş ekranına dönüşte sessizce yok olur. Gizlilik gerekçesi geçerli; ama çıkış öncesi bekleyen varsa kullanıcı uyarılmalı (manuel çıkışta onay: "N mesaj gönderilmedi").
- Öneri: `signOut` UI akışında `outbox.pendingCount > 0` ise onay iste; zorla çıkışlarda hiç değilse giriş ekranında "gönderilmeyen mesajlar silindi" bilgisi.

**A15-18 — Yanıt boyutu tavanı `Content-Length` yokken uygulanmaz** · ORTA
- Konum: `api.dart:174-183` (`_fetch`: yalnız `streamed.contentLength` kontrolü; `http.Response.fromStream` sınırsız okur).
- Test: `a15_cache_test.dart` → `S3.8` (kırmızı): 25 MB `chunked` yanıt `RESPONSE_TOO_LARGE` vermeden alındı ve işlendi. (Büyük yanıt >256 KB izolat çözümü doğru: 8000 öğe, yeşil.)
- Etki: nginx/gzip/chunked yanıtlarda tavan etkisiz; bozuk/kötü niyetli proxy ile bellek şişmesi (OOM).
- Öneri: akışı `_fetch` içinde sayarak keserek oku (`await for` ile `maxResponseBytes` aşılınca iptal).

**A15-19 — Yazma/GET yarışları bayat veriyi "taze" damgalar; POST zaman aşımında geçersizleme yok** · ORTA
- Konum: `api.dart:219` (`cachedAt.isAfter(inv)`), `:395` (`_invalidatedAt` yalnız yanıt 2xx olunca), `:355-360`.
- Test: `S3.3` (kırmızı): `GET /events` havada iken `POST /events/1/rsvp` biter, GET eski veriyi getirir → sonraki GET ağa gitmeden `{v: old}`; `S3.3b` (kırmızı): POST zaman aşımına düşer (sunucu işlemiş olabilir) → liste 20 dk bayat.
- Geçersizleme matrisi (`S3.2`, bilgi): mobilin kullandığı yazma uçlarının hepsi ilgili taze listeyi sıfırlar (`/events/*`, `/communities/*`, `POST /events`, `/legal/accept`). Gelecekte `POST /communities/{id}/events`, `/bookmarks`, `/polls/.../vote` ile menü gibi FARKLI SEGMENTLİ yazmalar liste ile ilişkiliyse BAYAT kalır (şu an kullanılmıyor).
- Öneri: GET başlangıç anını yakala, `inv > startedAt` ise yanıtı "taze" damgalama (yalnız ETag olarak sakla); ağ hatasında yazma için de geçersizle (belirsiz sonuç).

**A15-20 — `MessageCache.clear()` bekleyen yüklemeyle yarışır, eski veri belleğe geri döner** · ORTA
- Konum: `message_cache.dart:125-134,177-186` (`await _run(_loadConv)` sonrası `_mem.putIfAbsent`), `:352-365` (`clear`).
- Test: `S2.8` (kırmızı): `readMessages` kuyruğa girmişken `clear()` → sonra `readMessages` A'nın mesajını döner. Aynı sohbet kimliği iki hesapta ortaksa (grup/kulüp odası) B'ye eski önbellek görünür.
- Öneri: `_cleared` yerine kuşak sayacı; `_loadConv` sonrası kuşak değiştiyse sonucu at.

**A15-21 — Ana Sayfa menü kartı sunucu 500'ünde "boş içerik" mesajı gösterir (yanıltıcı)** · ORTA
- Test: `a15_ui_test.dart` → `U2` / `U3` (bilgi). Önbellek YOK + sunucu 500: `HomeTab`'te menü kartı "Bugün için liste yok · Yemekhane menüsü sisteme henüz girilmedi." gösterir (hata değil, içerik-yok metni); diğer kartlar doğru ("İçerik yüklenemedi · Yeniden dene", "Etkinlik yüklenemedi · Tekrar dene"). `ChatTab` 500 ve ağ yok: "Yüklenemedi, tekrar dene" + "Yeniden dene" (iyi). `HomeTab` ağ yok: "Bağlantı yok · Sunucuya ulaşılamadı · Yeniden dene" (iyi). `MenuPage` 500/ağ yok: gün şeridi çizilir; hata/boş metin çıktısı yakalanamadı (ilk 12 metin yalnız tarih şeridi) — elle bakılmalı.
- Etki: M1 ile pasif şerit kaldırıldı; hata gösterimi tamamen sayfaların kendi durumuna bağlı. Menü kartında sunucu hatası "menü girilmedi" olarak görünür, kullanıcı yeniden deneme yerine beklemeye yönelir.
- Öneri: `HomeTab` menü kartında hata ile boş durumu ayır (`_menuError`), hata halinde "Yüklenemedi · Yeniden dene".

### DÜŞÜK

**A15-22 — Silinen/kaldırılan mesajın `text`'i diske yazılır** · DÜŞÜK (derinlemesine savunma)
- Konum: `message_cache.dart:85-95` (`sanitizeMessage`: `attachments/replyTo/reactions` siler, `text` korur). Test: `S2.7` (kırmızı): `deleted:true,text:'SILINENMETIN'` ve `removed:true,text:'KALDIRILAN'` diskte kalır (tek gösterimlik URL/metin, yanıt alıntısı, liste son mesajı temiz — yeşil kontroller). Sunucu normalde boş metin yollar; yerel silmede metin yerelleştirilmiş yer tutucu. Öneri: gone ise `out['text']=''` zorla.

**A15-23 — Görsel disk önbelleği tavanı yalnız her 40 yazmada uygulanır; silinen içeriğin görseli diskte kalır** · DÜŞÜK
- Konum: `image_disk_cache.dart:35,86`. Test: `I5` (kırmızı): tavan 10 000 B iken 39 yazma sonrası 117 000 B (11,7×); gerçek ayar 150 MB + 39×12 MB ≈ 618 MB'a kadar çıkabilir. Mesaj sonradan herkes için silinse de önceden yazılmış küçük resim baytları (URL özeti anahtarlı) diskte çıkış/prune'a kadar kalır (`message_bubble.dart:777-781` yalnız çizim anında bakar). Öneri: her yazmada artımlı toplam sayacı; silme olayında `ImageDiskCache.remove(url)`.

**A15-24 — Görsel önbelleği: portal HTML'i diske yazılır; bozuk dosyada aynı denemede yeniden indirme yok; URL anahtarlı** · DÜŞÜK
- Konum: `image_disk_cache.dart:148-196`. Testler: `I4` (kırmızı: 24 baytlık HTML diske yazıldı, decode hatası sonrası da duruyor; `fromNet` ise silinmez), `I3` (kırmızı: bozuk dosya silinir ama görsel o seferde hata verir, ağdan indirilmez), `I1` (yeşil: ikinci yükleme ağa gitmez; ikinci istek başka başlıkla da diskten servis edilir, yetki yeniden doğrulanmaz — URL'ler UUID olduğundan kabul edilebilir). `I2` (aynı URL farklı içerik ⇒ eski bayt süresiz) test düzeneği nedeniyle doğrulanamadı; kod okumasıyla kural böyle ("adres değişir" varsayımı). Öneri: decode başarısız olunca diske yazma/yok sayıp ağdan bir kez daha dene.

**A15-25 — Mesaj önbelleği LRU = yazma zamanı; 1,5 sn gecikmeli yazım** · DÜŞÜK
- Testler: `S2.5` (kırmızı: 60 sohbet ⇒ 50 kalır ve en yeni korunur, ama yalnız OKUNAN eski sohbet `c1001` ilk silinir), `S2.3` (bilgi: kayıt kuyruğu yazılmadan süreç ölürse son mesajlar yok — yalnız önbellek). `S2.6` (3 MB bayt tavanı doğru, yeşil). Ayrıca belge farkı: `docs/MOBILE_UI.md` 4.2 "kayıt ile ağ sayfası birleşir" der, kodda `_boot` ağ sayfası kaydın YERİNE geçer (`chat_detail_page.dart:476-484`).

## 3. Yeşil çıkanlar (doğrulanan sağlam davranış)

- 50 mesaj çevrimdışı → bağlantı gelince sıra korunur (farklı ms), flapping fırtınasında (40 olay, her 3. istek kopuk) çift teslim yok (`S1.1`, `S1.2`).
- Yanıt kaybı / süreç ölümü sonrası yeniden açılışta aynı `clientId` ile tekrar gönderilir; sunucu aynı mesajı döner, çift mesaj yok (`S1.3` + A7 yığını: aynı `clientId` ⇒ aynı `id`, ekli mesajda da).
- Kalıcı 4xx baş öğe konuşmayı TIKAMAZ (aynı turda bekletilir, sonraki turda diğerleri gider; ancak sıra tersine döner: `S1.5`). 200 mesajlık FUZZ (ağ/5xx/4xx/429 karışımı): kayıp 0, çift 0 (`S1.15`). 24 saat sınırı `EXPIRED` yapar (`S1.7`). Kayıp medya dosyası `MEDIA_LOST` ile görünür hata (`S1.10`). Çift `retry` çift teslim üretmez (`S1.14`).
- Mesaj önbelleği: 20 sınırı birleşim/düzenleme/silme/sıra doğru, 40 eşzamanlı upsert + flush kayıpsız, `.tmp` kalıntısı yok (`S2.1`, `S2.2`); tek gösterimlik URL/metin, yanıt alıntısı, liste son mesajı diske yazılmaz (`S2.7` temiz kısım); kesik JSON dosyası silinir (`S2.4a`); 3 MB/50 sohbet tavanı (`S2.5`, `S2.6`).
- ETag: taze pencere, `force`, yazma sonrası geçersizleme, 5xx'te bayat sunma (503'te 1 tekrar sonra), 304 gövdesiz + önbellek yok ⇒ `ApiError` (boş veri değil), disk tavanları 400/512 KB/16 MB, token yenilemede önbellek korunur, çıkışta temizlenir (`S3.1`, `S3.4`, `S3.6`, `S3.7`, `S3.9`).
- Çıkış temizliği: `api_cache`, `msg_cache`, `img_cache`, `outbox_media`, kuyruk (bellek + depo) boşalır; sıralı hesap değişimi (A çıkış → B giriş) A verisi sızdırmaz (`S2.9` dosya kısmı, `S2.10`).
- Görsel: `persist:false` hiçbir şey yazmaz (`I6`), `imageCache` 200/80 MB uygulanır ve `main.dart` çağırır (`I7`), ETag LRU 100 girdiyle sınırlı (`I8`).
- Sızıntı: `Outbox.dispose` zamanlayıcı/dinleyiciyi bırakır; sohbet sayfası `_deliverySub`/`removeListener`/ack zamanlayıcılarını `dispose`'ta iptal eder.

## 4. Neye bakılamadı / sınırlar

- Gerçek cihaz, uçak modu, Keychain/Keystore davranışı (gerçek `flutter_secure_storage`) ve gerçek ENOSPC yok; yazma hataları sahte depolarla simüle edildi.
- `A15-02` (WS ack zamanlayıcısı) yalnız kod okumasıyla; otomatik test için sahte `ChatRealtime` gerekir.
- `ChatDetailPage` ve diğer sayfaların `_error` dallarının tamamı denenmedi; `U2/U3` yalnız ChatTab, MenuPage, HomeTab.
- Büyük video (≥50 MB) kuyruk yükleme akışı ve gerçek yükleyiciler (`MultipartUploader/VideoUploader`) sahte; bellek ölçümü yapılmadı.
- `Isolate.run` eşiği (256 KB) doğru çalışıyor (8000 öğeli yanıt); eşik civarı zamanlama ölçülmedi (A5 kapsamı).
- STOMP testleri sahte sunucuyla; gerçek Spring STOMP/`SESSION_REPLACED` kapanış kodu sınanmadı. `AppGate` doğrudan test edilmedi (yalnız kod okuma: şerit kaldırılmış, bakım/güncelleme şeritleri ve `updateRequired` korunumu doğru).
- Üretim sunucusuna erişilmedi.

## Ek A — Bulgu/test eşlemesi

| Bulgu | Test | Sonuç |
|---|---|---|
| A15-01 | outbox `S1.4a` | kırmızı |
| A15-02 | — (kod okuma) | — |
| A15-03 | cache `S2.9` | kırmızı |
| A15-04 | cache `S2.11` | kırmızı |
| A15-05 | cache `S5.x` | kırmızı |
| A15-06 | cache `S3.5` | kırmızı |
| A15-07 | cache `S2.4b`, ui `U1` | kırmızı |
| A15-08 | outbox `S1.6`, conn `C1`/`C2` | kırmızı |
| A15-09 | conn `C4` | kırmızı |
| A15-10 | outbox `S1.8` | kırmızı |
| A15-11/12 | outbox `S1.7b`, `S1.7c`, `S1.1c`, `S1.1b` | kırmızı |
| A15-13 | outbox `S1.11` | kırmızı |
| A15-14 | outbox `S1.12` | kırmızı |
| A15-15 | outbox `S1.9` | kırmızı |
| A15-16 | outbox `S1.13` | kırmızı |
| A15-17 | cache `S2.9` (kuyruk boşalır) | bilgi |
| A15-18 | cache `S3.8` | kırmızı |
| A15-19 | cache `S3.3`, `S3.3b` | kırmızı |
| A15-20 | cache `S2.8` | kırmızı |
| A15-21 | ui `U2`/`U3` | bilgi |
| A15-22 | cache `S2.7` | kırmızı |
| A15-23/24 | image `I5`, `I3`, `I4` | kırmızı |
| A15-25 | cache `S2.5`, `S2.3` | kırmızı/bilgi |
| (ek) STOMP kararsız sunucu | conn `C6` | kırmızı (8 sn'de 6 bağlantı, ~1,3 sn aralık; `_attempt` her CONNECTED'da sıfırlanır — kararlılık süresi beklenmeli, stomp_client.dart:74,207) |

## Ek B — Sunucu 500 + önbellek yok ekran çıktıları (U2)

`U2 HomeTab` (500, önbellek yok): [BU KAMPÜS, …, Günün Menüsü, Öğle yemeği, **Bugün için liste yok, Yemekhane menüsü sisteme henüz girilmedi.**, Hızlı Erişim, …, Öne Çıkan Haberler, Tümü, Henüz içerik yok., **İçerik yüklenemedi., Yeniden dene**, Yaklaşan Etkinlikler, **Etkinlik yüklenemedi, Tekrar dene**]

`U2/U3 ChatTab`: [Sohbet, Sohbetlerde ara, Tümü, Kişiler, Kulüpler, Etkinlikler, **Yüklenemedi, tekrar dene**, Sohbet listesi güncellenirken bir bağlantı hatası oluştu. Lütfen bağlantınızı kontrol edin., **Yeniden dene**]

`U3 HomeTab` (ağ yok): [**Bağlantı yok**, Sunucuya ulaşılamadı. Bağlantınızı kontrol edin., **Yeniden dene**]

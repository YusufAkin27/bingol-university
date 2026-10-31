# A5 - Mobil performans denetimi (Flutter, `mobile/`)

Tarih: 2026-10-31 - Denetçi: A5 - Kapsam: başlangıç, render/jank, görsel/bellek, ağ/pil, APK/AAB boyutu.
Kural: kod DEĞİŞTİRİLMEDİ; üretim sunucusuna erişilmedi; gerçek cihaz (adb) yok.

## 0. Yöntem ve sınırlar

- Kod okuma (lib/ 256 dosya), `grep` ile sistematik tarama, mevcut `bu-kampus-2.0.3+20003.aab` içeriğinin (zip) salt-okunur dökümü, ASCII kopyada (`C:\bu_a5`) `flutter test` ile sentetik ölçüm ve `flutter build apk --release --analyze-size` (arm64, obfuscate).
- `test/support/frame_budget.dart` ve `ui_matrix` bu depoda YOK; kare bütçesi için kendi sentetik testimi yazdım (kopyada, depoya eklenmedi).
- `flutter test` ölçümleri HOST CPU + debug/JIT içindir: yalnız build+layout+paint-kaydı süresi, RASTER (GPU) YOK. Mutlak değerler cihaza taşınmaz; yalnız göreli/orantı verir. Cihazdaki karşılığı "TAHMIN" diye işaretlendi.
- A7 test yığını (`C:\bu_qa\QA-STACK.txt`) hazır değildi; dinamik API ölçümü yapılmadı (kod okumasıyla istek sayıları çıkarıldı).

## 1. Özet tablo

| Şiddet | Adet | ID'ler |
|---|---|---|
| KRİTİK | 0 | - |
| YÜKSEK | 4 | A5-01, A5-02, A5-03, A5-04 |
| ORTA | 10 | A5-05 ... A5-14 |
| DÜŞÜK | 9 | A5-15 ... A5-23 |

En kritik 5: A5-01 (3 eşzamanlı WebSocket), A5-02 (splash `/auth/me`'yi bekliyor, en kötü ~40 sn), A5-03 (Keşfet/etkinlik/menü görselleri disk önbelleksiz + her indirmede yeni HttpClient), A5-04 (sohbet detayı her yoklamada tam sayfa `setState`), A5-05 (açılışta mükerrer/gereksiz istekler).

## 2. AAB/APK boyut dökümü (özet; ayrıntı Bölüm 7)

"AAB 81.6 MB" (gerçek: 2.0.3 = 85.6 MB, 2.0.2 = 83.4 MB) kullanıcının indireceği boyut DEĞİLDİR. İçinde Play'in kullanıcıya vermediği ~39.4 MB var (debug sembolleri 34.8 MB + R8 `proguard.map` 4.6 MB). Tek bir arm64 cihaz için tahmini indirme: ~21.8 MB (sıkıştırılmış). Ayrıntı ve küçültme önerileri A5-12 ... A5-14, A5-20.

## 3. BULGULAR - Başlangıç

### A5-02 YÜKSEK - Splash, ağ yanıtı (`/auth/me`) gelene kadar bekliyor; kötü ağda ~40 sn
- Dosya: `mobile/lib/core/session.dart:92-133` (`restore` -> `_loadMe` -> `await _fetchMe()`), `mobile/lib/main.dart:215` (`SessionState.loading => SplashScreen`), `mobile/lib/core/api.dart:162,174-181,352-356`.
- Kanıt: `home:` yalnızca `signedIn` olunca kabuğa geçer; `signedIn`, `GET /auth/me` bitince set edilir. `/auth/me` yolu `_noStale` içinde (`auth/`), yani önbellekten sunulmaz; zaman aşımı 20 sn, GET'te ağ hatasında 400 ms sonra bir kez yeniden deneme => en kötü durum 20 + 0.4 + 20 = ~40.4 sn splash. Splash dosyasının yorumu "ağ beklemez" diyor ama davranış bunun tersi. Çevrimdışıysa ağ hatası hızlı döner (sorun yok); sorun "bağlı ama cevap yok" (zayıf/captive Wi-Fi, 2G, sunucu yavaş) durumunda.
- Etki: TAHMIN - normal 4G'de splash +150-400 ms (1 RTT + TLS), zayıf ağda 8-40 sn boş splash; kullanıcı uygulamayı donmuş sanır.
- Düzeltme: JWT `sub` zaten çözülüyor (`jwtSubjectId`). Token'lar varsa HEMEN `signedIn` yap (kabuk açılsın), `/auth/me`'yi arka planda çalıştır (ad `/users/me` disk önbelleğinden); yalnız kesin 401/yetki reddinde çıkış yap. Alternatif: splash'e 2-3 sn üst sınır (`timeout`) koy, sonra çevrimdışı modda aç (`_retryMe` zaten var).
- Kazanç: kötü ağda açılış 8-40 sn -> ~1 sn; iyi ağda ilk ekran ~200-400 ms daha erken.

### A5-05 ORTA - Soğuk açılışta mükerrer ve gereksiz istekler (≈12 istek, 4'ü gereksiz)
- Dosyalar: `main.dart:133-139`, `core/app_gate.dart:116-123`, `features/shell/app_shell.dart:60-62,101-117`, `features/home/home_tab.dart:94-124`.
- Kanıt (oturumlu soğuk açılış sırası): `/auth/me` (seri, bkz. A5-02) -> paralel: `/app/version` + `/app/info` (AppGate), `PATCH /users/me {language}` (her açılışta; yazma olduğu için `_invalidatedAt['users']` de sıfırlanır), `/me/summary` (kabuk `_refreshBadges`), `/users/me` (kabuk avatar), ardından HomeTab: `/app/info` (AGAIN), `/menu/today`, `/me/summary` (AGAIN, aynı anda), `/events/featured` (+ `/events/{id}/attendees/preview`), tembel `/news`, `/status`; ayrıca push kaydı (FCM token POST), analytics `app_open`, STOMP bağlantısı(lar) (A5-01), `legal/acceptance-status`. `ApiClient` uçuştaki aynı GET isteklerini birleştirmiyor (in-flight dedupe yok), bu yüzden `/me/summary` ve `/app/info` ikişer kez ağa gider.
- Düzeltme: (1) `ApiClient`'a tek uçuşlu GET (aynı anahtar için Future paylaş); (2) dil PATCH'ini yalnız dil değişince/sunucu dili farklıysa at (`/auth/me` zaten `language` döndürüyorsa karşılaştır); (3) `/auth/me` + `/users/me` birleştir; (4) HomeTab `/app/info`'yu AppGate sonucundan al.
- Kazanç: ~4 istek/açılış (~%30), veri ve radyo uyanması azalır; TAHMIN 50-150 ms daha hızlı ilk dolu ekran.

### A5-06 ORTA - `runApp` öncesi seri secure-storage okumaları
- Dosya: `mobile/lib/main.dart:110-111` (`await CrashReporter.instance.init(); await DeviceIdentity.instance.load();`), ayrıca `Session.restore` iki okuma (`session.dart:94-95`), tema/dil okumaları (unawaited), `PostLoginGate` izin bayrağı.
- Kanıt: İki Keystore okuması (+ CrashReporter'da dosya okuma/jsonDecode) `runApp`'ten ÖNCE ve SERİ bekleniyor; ilk kare bu iş bitene kadar gelmiyor (native splash uzar). Toplam soğuk açılışta ≥7 secure-storage okuması (device_id, crash ayarı, access, refresh, tema, dil, izin bayrağı).
- Etki: TAHMIN (düşük uçlu cihazda ilk Keystore erişimi 50-300 ms): ilk kareden önce 100-400 ms.
- Düzeltme: `runApp`'i bu `await`'lerden önce çağır (CrashReporter/DeviceIdentity `Future.wait` ile paralel, ilk istekten önce `DeviceIdentity` hazır olacak şekilde `ApiClient` ilk istekte `await DeviceIdentity.ready`); `access`+`refresh`'i tek okuma/paralel oku; `Firebase.initializeApp`'i (şu an `unawaited(PushService.prepare())`, main.dart:108) ilk kareden sonraya (`addPostFrameCallback`) ertele - arka plan işleyicisi yine kaydedilebilir.
- Kazanç: CIHAZDA ÖLÇÜLMELİ; beklenen 100-400 ms.

### A5-15 DÜŞÜK - Tema/dil yüklemesi runApp'ten sonra: ilk karede varsayılan tema/dil, sonra MaterialApp yeniden kurulur
- Dosya: `main.dart:122-126` (`unawaited(theme.load())`, `unawaited(localeCtl.load())`), `main.dart:195-` `ListenableBuilder` tüm `MaterialApp`'i yeniden kurar.
- Etki: koyu tema / Arapça kullanıcıda açılışta kısa bir "yanlış tema" parlaması (flash) + bir ek tam MaterialApp rebuild (splash üstünde ucuz). Düzeltme: değerleri `runApp`'ten önce paralel oku (A5-06 ile aynı `Future.wait`) ya da splash'te tema-bağımsız renk kullan.

### A5-16 DÜŞÜK - `AppShell` 1 dk'lık rozet zamanlayıcısı arka planda da çalışır
- Dosya: `app_shell.dart:62` `Timer.periodic(1 dk, _refreshBadges)`. `didChangeAppLifecycleState` yalnız `resumed`'ı işliyor; `paused`'ta zamanlayıcı iptal edilmiyor. Android arka planda Dart zamanlayıcıları kısa süre devam edebilir (süreç dondurulana kadar) => gereksiz `/me/summary`. STOMP bağlıyken rozetleri zaten olay besliyor. Düzeltme: `paused`'ta iptal, `resumed`'ta yeniden kur; STOMP bağlıyken aralığı 5 dk'ya çıkar. Kazanç: küçük (pil/veri).

## 4. BULGULAR - Ağ / pil

### A5-01 YÜKSEK - Aynı anda en çok 3 WebSocket (STOMP) bağlantısı
- Dosyalar: `mobile/lib/features/shell/app_shell.dart:56` (`s.realtime?.start()` - `Session.realtime`, `session.dart:35`), `mobile/lib/features/chat/chat_tab.dart:74-75` (`_rt = ChatRealtime(widget.session)` + `start()`), `mobile/lib/features/chat/chat_detail_page.dart:143,711` (`widget.realtime ?? ChatRealtime(widget.session)` + `start()`).
- Kanıt: `ChatRealtime` yapıcısı kendi `StompClient`'ını (kendi WebSocket'ini, kendi 10 sn kalp atışı, 5 sn `_recvWatch`, `_refreshTimer`, yeniden bağlanma geri çekilmesi) oluşturur. `Session.realtime` yorumu "tek sohbet gerçek zamanlı bağlantısı (ekranlar `session.realtime` ile erişir)" diyor, ama ChatTab ve ChatDetailPage onu KULLANMIYOR (`grep session.realtime` yalnız kabuk ve `main.dart`'ta). Sohbet sekmesi bir kez açıldıysa (IndexedStack'te canlı kalır) ve bir sohbet açıksa: kabuk + sekme + detay = 3 soket; her mesaj 3 kez alınır/JSON çözülür; öne gelince 3 TLS+STOMP el sıkışması; sunucuda kullanıcı başına 3 oturum (20k kullanıcıda 60k'ya varan bağlantı); `connected`/`resync` olayları 3 yerde ayrı GET tetikler.
- Etki: pil (3x radyo uyanması: 3 x 10 sn kalp atışı), veri, sunucu bağlantı sayısı. TAHMIN: sohbet açıkken ~%2-4 ek pil/saat (ölçülmeli).
- Düzeltme: tek `session.realtime` örneği; ChatTab/ChatDetail ona abone olur (`widget.realtime ?? widget.session.realtime!`), `start/stop` yalnız kabukta (referans sayaçlı). Testler zaten `realtime` enjeksiyonu destekliyor.
- Kazanç: soket ve zamanlayıcı sayısı 3 -> 1; mesaj başına JSON çözümü 3 -> 1.

### A5-03 YÜKSEK - Görsel indirme: her görsel için yeni `HttpClient` (yeniden kullanım yok), ana akış görsellerinde disk önbelleği yok
- Dosya: `mobile/lib/core/cache/image_disk_cache.dart:185` (`client ??= HttpClient()..connectionTimeout = ...`; her `_download` çağrısında yeni istemci, hiç `close()` yok); `mobile/lib/features/posts/post_card.dart:40` (Keşfet fotoğrafı `Image.network`), `mobile/lib/features/events/event_cover.dart:33`, `mobile/lib/widgets/common.dart:214` (`NewsThumb`), `mobile/lib/features/menu/menu_photo.dart:32` (`NetworkImage`, cacheWidth yok), `user_profile_page.dart:807`.
- Kanıt: Flutter'ın `NetworkImage`'ı süreç boyunca paylaşılan bir `HttpClient` kullanır (bağlantı yeniden kullanımı/keep-alive); `DiskNetworkImage` her görsel için yeni istemci => her görselde yeni TCP+TLS el sıkışması (avatar listesi, sohbet küçük resimleri, ızgaralar). Ayrıca `Image.network` kullanan ana yüzeyler (Keşfet akışı, etkinlik kapakları, haber küçük resmi, yemek fotoğrafı) diske YAZMIYOR: sunucu `Cache-Control: private, max-age=86400` + ETag veriyor ama Flutter `Image.network` HTTP önbelleği tutmaz; bellek önbelleği 80 MB/200 görselde evictlenince veya uygulama yeniden açılınca aynı fotoğraf (1000 px kod çözümlü, ~100-400 KB) yeniden iner.
- Etki: veri (Keşfet akışı oturum başına birkaç MB tekrar), gecikme (el sıkışma başına ~100-400 ms mobil ağda TAHMIN), pil. 
- Düzeltme: (1) `DiskNetworkImage` için tek statik `HttpClient` (`maxConnectionsPerHost` ~6, `idleTimeout` 15 sn) ya da `package:http` istemcisi; (2) `Image.network` kullanan yerleri `BuImage`/`persistentNetworkImage` ile değiştir (kapaklar/Keşfet/haber/yemek; kullanıcıya özel yetkili görsellerde mevcut `persist` ayrımı korunur); (3) menü fotoğrafına `ResizeImage`.
- Kazanç: tekrar açılışlarda görsel verisi ~%80-100 azalır; liste kaydırmada görsel başına el sıkışma gecikmesi kalkar.

### A5-17 DÜŞÜK - Sohbet yoklaması (4 sn) çok yüzeyde gereksiz sayfa çekiyor; çevrimdışı/STOMP açıkken makul
- Dosya: `chat_detail_page.dart:128,438-440,599-626`.
- Durum (olumlu): STOMP bağlıyken yalnız her 5. turda (~20 sn) son 30 mesaj çekiliyor; çevrimdışıyken 30 sn; arka planda zamanlayıcı iptal. Sorunlar: (a) `_tick % 5` turunda 30 mesajlık sayfa ETag/304 yoksa tam iniyor (sohbet uçları `Cache-Control: no-store`/disk dışı olabilir, `CachePolicy` açıklaması: mesajlar bellek ETag'ında); (b) rota üstte başka sayfa (bilgi, medya görüntüleyici) açıkken zamanlayıcı çalışmaya devam eder; (c) her turun sonunda koşulsuz `setState(() {})` (A5-04). Öneri: `ModalRoute.isCurrent` değilken duraklat.

### A5-18 DÜŞÜK - Diğer zamanlayıcılar (envanter; sorun yok / not)
`Analytics` 20 sn periyodik (kuyruk boşsa iş yok), `PushViewing` (`push_api.dart:99`, sohbet açıkken aralıklı "görüntülüyor" isteği), `TimetablePage` 1 dk, `STOMP` kalp atışı 10 sn + `_recvWatch` 5 sn (yalnız bağlıyken; paused'ta kapanır), `QR/ compose / auth` geri sayımları ekran ömrüne bağlı. Wakelock/konum/sürekli animasyon yok. Sürekli `repeat()` yalnız splash, iskelet (tek ticker, iyi), QR tarama çizgisi, `_PulseDot` (sohbet) - hepsi ekran ömrüne bağlı.

## 5. BULGULAR - Render / jank

### A5-04 YÜKSEK (TAHMIN) - Sohbet detayında her yoklama/olayda tam sayfa `setState`; görünen tüm balonlar yeniden kurulur
- Dosya: `chat_detail_page.dart:617` (`_poll` sonunda koşulsuz `setState(() {})`), `:2619-2655` (`ListView.builder`, öğe başına yeni `MessageBubble` + yeni closure'lar), `:2651` (`_rowKeys.putIfAbsent(id, GlobalKey.new)`), `:830` (her `_merge`'de tüm `_msgs` yeniden sıralanır), `:567-575`.
- Kanıt (sentetik, host, debug/JIT): 1000 mesajlık ters `ListView.builder`'da (görünen ~20 balon) tam yeniden kurma geçişi = ~99.6 ms/geçiş (≈5 ms/balon); ilk pump 220 ms (1000 mesaj, tembel olduğu için görünen ~20 satır); kaydırma ortalama 2.8 ms/kare, en kötü 15.3 ms. Komut: `C:\bu_a5\test\a5_perf_test.dart` (depoya eklenmedi). Release/AOT ve cihaz CPU'su farklıdır; TAHMIN: orta uçlu cihazda 20 balonluk tam rebuild 8-25 ms => bir kare kaçırma/yoklama. STOMP kapalı sohbette her 4 sn, açıkken ~20 sn'de bir; ayrıca her gelen/giden mesaj, tepki, yazıyor göstergesi (yazıyor/online `ValueNotifier` ile ayrı ve iyi) setState tetikler.
- Nedenler: (1) değişmeyen yoklamada bile `setState`; (2) `MessageBubble` `StatelessWidget` ama her yeniden kurmada yeni callback kimlikleri => `==` ile atlanamaz; (3) öğelerde `findChildIndexCallback` yok; ters listede yeni mesaj index 0'a eklenince tüm index->eleman eşleşmesi kayar, `GlobalKey`'li `KeyedSubtree`'ler Column'lar arasında taşınır (reparent) - GlobalKey taşıma pahalıdır ve `_rowKeys` hiç temizlenmez; (4) her `_merge` tam sıralama O(n log n) + `_persist` (25 mesaj temizleme) + `MessageCache.upsertMessage`'ın (main.dart:117-119) ikinci kez normalizasyonu.
- Düzeltme: `_poll`'da yalnız değişiklik varsa (`added || changed`) setState; satırı `Key(id)` ile anahtarla + `findChildIndexCallback`, `GlobalKey` yerine `Scrollable.ensureVisible` için gerektiğinde geçici anahtar ya da `ItemScrollController` benzeri indeks tabanlı atlama; satır başına `ValueListenableBuilder`/küçük `StatefulWidget` ile yalnız değişen satırı güncelle; `_msgs`'a yeni mesajı sıralı ekle (binary insert) ve tam sort yapma.
- Kazanç: yoklama başına 0 yeniden kurma (şu an ~20); STOMP mesajında yalnız ilgili satır.

### A5-07 ORTA (TAHMIN) - Alt gezinme `BackdropFilter` (σ=16) sürekli ekranda
- Dosya: `features/shell/floating_nav.dart:154` (`BackdropFilter(ImageFilter.blur(16,16))` + `ClipPath(ShapeBorderClipper(RoundedSuperellipseBorder))` + iki `BoxShadow` painter'ı `:230-251`), kabuk `extendBody: true` (`app_shell.dart:193`).
- Kanıt: nav çubuğu her sekmede, tüm kaydırılan içeriğin ÜSTÜNDE; arka plan her karede yeniden okunup bulanıklaştırılır (saveLayer + blur; arkadaki içerik kaydırılırken `RepaintBoundary` tüm çubuğu değil yalnız backdrop'u yeniden hesaplar ama her karede). Alan ≈ ekran genişliği x 68 dp (~390x68 dp ≈ 0.08 Mpx x dpr²) - küçük ama sürekli. Ayrıca `_OutsideShadow.paint` her boyamada `Path.combine` (CPU boolean) çağırır; `BuPressable` ölçek animasyonu sırasında boundary her kare yeniden boyanır.
- Etki: TAHMIN - üst/orta cihazda ihmal edilebilir; düşük uçlu (Mali-G52/Adreno 506 sınıfı, 2-3 GB RAM) cihazda kaydırmada kare başına +1-3 ms GPU olabilir. CIHAZDA ÖLÇÜLMELİ (Profile, GPU thread).
- Düzeltme (maliyetsiz seçenek): σ'yı 8-10'a indir veya `MediaQuery.disableAnimations`/`ui.PlatformDispatcher` düşük bellek algısıyla bulanıklığı kapatıp %96 opak düz yüzey kullan; `Path.combine` sonucunu `shape/size` değişene dek önbellekle.

### A5-08 ORTA (TAHMIN) - Sekme geçişinde tüm sekmeye `FadeTransition` + `ScaleTransition`
- Dosya: `app_shell.dart:227-243` (`_TabFade`), `:130-141`. Seçilen sekmenin tamamı (Keşfet akışı görselleriyle) 250 ms boyunca opaklık katmanı + ölçek dönüşümüyle yeniden raster edilir (saveLayer, tam ekran). Kısa (≈15 kare) ama içerik ağırsa ilk geçişte takılma. Düzeltme: yalnız `FadeTransition` (ölçeksiz) ya da hiç animasyon; sekme ilk kurulumunda (ağır) animasyonu atla.

### A5-09 ORTA - `BuPageScaffold` hazır içeriği `SliverFadeTransition(SliverMainAxisGroup)` ile sarıyor
- Dosya: `widgets/bu_page_scaffold.dart:196`. Her iskelet -> veri geçişinde 250 ms boyunca tüm sliver grubu opaklık katmanında çizilir; `SliverMainAxisGroup` tüm alt sliver'ları tek geçişte ölçer (alt sliver'lar tembel kalır). Küçük sayfalarda ucuz; uzun listelerde (haber, etkinlik, bildirim) ilk veri karesinde bir kare maliyeti artar. Düzeltme: ilk 8 öğe zaten `BuStaggerItem` ile animasyonlu; sayfa düzeyindeki ek fade kaldırılabilir.

### A5-10 ORTA - Bildirim listesi `ListView(children: [...])` (tembel değil) ve her derlemede gruplama
- Dosya: `features/notifications/notifications_page.dart:324-450` (tüm bildirimler `children` listesine yığılıyor; sayfalanmış sonsuz kaydırma ile yüzlerce olabilir), her `build`'de `_group()` ile tarih ayrıştırma. Widget nesneleri O(n) üretilir, elemanlar tembel kurulur => asıl maliyet yeniden kurma sırasında liste kurma + `DateTime.parse` O(n). Düzeltme: `SliverList.builder` + önceden hesaplanmış grup başlığı indeksi (veri geldiğinde bir kez).
- Benzer (daha küçük): `academic_*`, `legal_pages`, `search_page.dart:505,640,650` (`ListView(children:)`), `clubs_tab.dart:352` boş liste.

### A5-11 ORTA - `ChatTab` `_visible` her derlemede süzülüp `toLowerCase` ile yeniden hesaplanıyor
- Dosya: `chat_tab.dart:464-476`. Arama sorgusu varken her `setState`'te (STOMP mesajı başına) tüm sohbetlerde (`_title(...).toLowerCase()`) O(n). 50-500 sohbette ihmal edilebilir; STOMP yoğun gruplarda gereksiz. Öneri: sorgu/öğe değişince önbelleğe al.

### A5-19 DÜŞÜK - `BuDefaultAvatar`/`ChatlistAvatar`/`BuAvatar` yapısı (N4 endişesi: "her avatar için CustomPainter+ağ")
- Dosyalar: `widgets/bu_default_avatar.dart:69-190`, `features/chat/chatlist_widgets.dart:213-275`, `widgets/bu_widgets.dart:411-447`.
- Kanıt: `shouldRepaint` doğru (yalnız `variant`/`group` değişince). Her avatar fotoğraf olsa bile ALTTA varsayılan görseli de çizer (gradyan zemin + parlama + 2-6 gradyan gölgelendirici) ve üstüne `ClipRRect` + görsel (aşırı çizim, overdraw). Sentetik: 500 satırlık listede avatar yok/`ChatlistAvatar`/`BuDefaultAvatar`/grup => ortalama 9.2 / 8.0 / 7.6 / 5.0 ms/kare (host, kayıt maliyeti; avatar farkı ölçüm gürültüsü içinde) => build/layout/kayıt maliyeti ihmal edilebilir. Raster maliyeti (shader sayısı) CIHAZDA ÖLÇÜLMELİ.
- İyileştirme (isteğe bağlı): varsayılan avatarı bir kez `ui.Picture` -> `Image` olarak (6 renk x 2 tür x boyut) önbelleğe al ya da 6 sabit varlık PNG'si; fotoğraf yüklendikten sonra (`frame != null`) alttaki varsayılan görseli kaldır.

### A5-20 DÜŞÜK - Gölge ve opaklık kullanımı
- `BuElevation.of` ile kart başına `BoxShadow` (Keşfet `_CardSurface` post_card.dart:95-100: her kartta blur gölge, 12 kart sayfa); `Opacity(opacity: v)` bir `TweenAnimationBuilder` içinde (`message_bubble.dart:804`) yerine `FadeTransition`/`AnimatedOpacity` olmalı (saveLayer her kare). `ClipRRect` varsayılan `antiAlias` çok sayıda (≈90 dosya) - kabul edilebilir, `hardEdge` yeterli olan görsel köşelerde (`BuImage` zaten `hardEdge`) tutarlılık sağlanabilir.

## 6. BULGULAR - Görsel / bellek

### A5-12 ORTA - Görsel çözümleme (bellek) bütçesi: 80 MB / 200 görsel, Keşfet 1000 px, sohbet küçük resmi 720 px
- Dosya: `core/cache/cache_lifecycle.dart:50-54`, `post_card.dart:44` (`cacheWidth: 1000`), `message_bubble.dart:740` (`decodeWidth` <= 1600), `chat_media_viewer.dart:305`.
- Kanıt: 1000x1250 piksellik gönderi = ~5 MB çözümlenmiş; tavan 80 MB ≈ 16 Keşfet kartı. Sohbet küçük resmi kısa kenar 720 (P3): 720x1280 RGBA ≈ 3.7 MB; 80 MB'ta ≈ 21 küçük resim; hızlı kaydırmada geri dönüşte yeniden çözümleme (disk okuma + decode; Keşfet'te yeniden ağ, bkz. A5-03). `cacheWidth` kutu x dpr ile doğru (BuImage/ChatlistAvatar/message_bubble); tam ekran görüntüleyici bellek: `clamp(300,1600)` (4 MP => ~16 MB/görsel).
- Düzeltme: Keşfet kart genişliği ~350 dp x dpr(2.6-3) ≈ 900-1050 px: 1000 doğru; sohbet için balon genişliği (≈270 dp) x dpr => ~700-800 px yeterli. Bellek bütçesi cihaz RAM'ine göre (`ActivityManager.isLowRamDevice`/`MemoryInfo` kanalı) 50 MB'a düşürülebilir. Düşük uçlu cihazda OOM riski: CIHAZDA ÖLÇÜLMELİ (Android `dumpsys meminfo`, Graphics bölümü).

### A5-13 ORTA - Kırpma sayfası: tam çözünürlüklü `Image.memory` + codec ile ikinci çözümleme
- Dosya: `features/media_crop/crop_page.dart:46-53,305`, `crop_engine.dart:15-44`.
- Kanıt: kaynak >6 MB ise `shrinkLarge`; aksi halde `instantiateImageCodec(_src)` tüm kareyi çözüp yalnız boyut okuyor (geçici tam RGBA, 12 MP => 48 MB tepe) ve önizleme `Image.memory(bytes)` `cacheWidth` YOK => ikinci tam çözümleme (48 MB kalıcı). `image_picker` `maxWidth: 1600` ile geldiği için kamera/galeri yolunda kaynak ≤1600 px (≈ 8 MB çözümlenmiş) - güvenli; ancak `ImageService.pick` dışı yollar (`media_crop.dart:25`, `compose_post_page.dart:25` kendi seçicileri) için aynı sınır doğrulanmalı. Kırpma (`cropJpegSync`) `package:image` saf Dart (Isolate'ta, iyi) ama JPEG kod çözme+döndürme+yeniden kodlama saf Dart'ta yavaş: 1600x1200'de TAHMIN 300-900 ms düşük uçlu cihazda (UI akıcı, bekleme göstergesi var).
- Düzeltme: boyutu `ImageDescriptor`/`ImmutableBuffer` ile çöz (çözmeden başlık oku), `Image.memory`'ye `cacheWidth: ekranGenişliği*dpr`.

### A5-21 DÜŞÜK - Galeri seçici: `assetCountAsync` albüm döngüsünde seri
- Dosya: `features/chat/media_library.dart:75-78`. 30 albümde 30 seri yerel çağrı (TAHMIN 0.3-1 sn). `Future.wait` ile paralelleştir veya sayıyı tembel getir. Küçük resimler 200 px (`media_picker_page.dart:671`), sayfa 60 öğe: iyi.

### A5-22 DÜŞÜK - `_rowKeys` (GlobalKey) hiç temizlenmiyor
- `chat_detail_page.dart:178,2651`. Sohbet başına binlerce mesaj kaydırıldıkça `GlobalKey` haritası büyür (anahtar başına ~100 bayt, bellek sızıntısı değil ama sınırsız). `_msgs` ile eşitle.

### Olumlu bulgular (sorun yok)
- `ListView.builder`/`SliverList.builder` yaygın; `shrinkWrap:true` yalnız küçük listelerde (iskelet, `GridView.count` profil ızgarası <=9 öğe, sheet). Büyük `Column`+uzun liste YOK.
- `shouldRepaint` doğru; `BuSkeletonScope` tek ticker; `AnimationController` per-öğe yalnız ilk 8 (`BuStaggerItem`) ve `_SwipeReply` (idle'da ticker çalışmaz).
- `MediaQuery.of(context)` yalnız 16 yerde (95 yerde dar `sizeOf/paddingOf` kullanılıyor); `AppGate` `MediaQuery.of` ile klavye animasyonunda yeniden kurulur ama `child` aynı örnek olduğundan alt ağaç etkilenmez.
- Kamera (`media_camera_page.dart:56-60`), video (`chat_video_player.dart:86`), QR (`qr_scan_page.dart:77-81`) `dispose` doğru. QR `formats: [qrCode]` ile sınırlı.
- JSON: >256 KB yanıtlar `Isolate.run` ile (zero-copy `Isolate.exit`); `maxResponseBytes` 20 MB. Not: disk önbelleğine yazarken çözümlenmiş nesne ana izolatta yeniden `jsonEncode` edilir (`disk_cache.dart:165`), büyük gövdede izolat kazancını azaltır (DÜŞÜK; ham `bodyBytes` yazılabilir).
- STOMP: geri çekilme 1-30 sn + %20 jitter, paused'ta kapanma; çevrimdışı yoklama 30 sn; ETag/304 + taze-önbellek kuralları (`CachePolicy`) iyi.

## 7. APK/AAB boyutu

### 7.1 `bu-kampus-2.0.3+20003.aab` (85 587 511 bayt = 85.6 MB) içeriği (sıkıştırılmış bayt)
| Bileşen | MB (sıkıştırılmış) | Not |
|---|---|---|
| BUNDLE-METADATA debugsymbols (3 ABI .sym) | 34.80 | Play kullanıcıya vermez |
| BUNDLE-METADATA proguard.map | 4.63 | Play kullanıcıya vermez |
| lib/x86_64 | 12.70 | cihaz bölünmesinde yalnız eşleşen ABI iner |
| lib/arm64-v8a | 12.17 | libflutter 5.49, libapp 4.53, libbarhopper_v3 (ML Kit) 2.11 |
| lib/armeabi-v7a | 11.63 | |
| dex (classes + classes2) | 4.93 | 12.7 MB ham; Firebase/GMS/ML Kit/CameraX |
| flutter_assets | 3.61 | Lucide değişken fontları 1.39, Inter 5 ağırlık 0.99, logo.png 0.90, mark_white.png 0.12 |
| base/assets (ML Kit .tflite x3) | 0.62 | |
| res (321 dosya) | 0.31 | |
| diğer (root, manifest, ...) | ~0.2 | |

Tahmini tek arm64 cihaz indirmesi ≈ 12.17 + 4.93 + 3.61 + 0.62 + 0.31 + 0.2 ≈ 21.8 MB (Play'in kendi sıkıştırması yaklaşık aynı). Yani kullanıcı etkisi 85 MB DEĞİL ~22 MB.

### 7.1b `flutter build apk --release --analyze-size --target-platform android-arm64` (temiz kopya, hata ayıklama imzalı, obfuscate'siz; APK 50.6 MB ham)
- `lib/` 40.2 MB ham: `libapp.so` 13.8 MB, `libflutter.so` 11.8 MB, `libbarhopper_v3.so` arm64 4.9 MB (+ armv7 3.2 MB + x86_64 5.9 MB: ML Kit AAR'ı `--target-platform` ne olursa olsun üç ABI'yi taşıyor; AAB'de Play ayırır, düz APK dağıtımında ~9 MB gereksiz yük).
- `libapp.so` paket dağılımı (ham): `flutter` çerçevesi 3.77 MB, uygulama+sınıflandırılamayan 6.2 MB, `image` paketi (saf Dart görsel işleme: kırpma/küçültme) 0.89 MB, `flutter_localizations` 0.35 MB, `camera_android_camerax` 0.17 MB, `mobile_scanner` 0.05 MB. Yani `image` paketi AOT'ta ~0.9 MB ham (~0.3 MB sıkışık) - yerel `ImageDescriptor`/`dart:ui` ile küçültme+kırpma yapılırsa kalkar (ayrıca A5-13'ü hızlandırır); düşük öncelik.
- `assets/`: `flutter_assets/assets` 2.31 MB (Inter fontları 2.06 MB ham + marka PNG'leri), `flutter_assets/packages` 1.44 MB (Lucide), ML Kit modelleri 0.88 MB.

### 7.2 Küçültme önerileri (tahmini kazanç, kullanıcı indirmesi)
- A5-14 (ORTA) Kullanılmayan marka PNG'leri pakette: `assets/branding/logo.png` (1.1 MB ham/0.90 MB sıkışık), `mark_white.png` (128 KB), `mark.png`, `logo_horizontal(.dark).png`, `default_avatar.png`, `default_group.png` - `lib/` içinde HİÇ referans yok (yalnız `mark_white.svg` kullanılıyor; PNG'ler yalnız testlerde `precacheImage`). `pubspec.yaml` `assets:` listesinden çıkar (test için `test/` altına taşı). Kazanç ≈ 1.05 MB.
- A5-13b (ORTA) `lucide_icons_flutter` 6 değişken yazı tipi (`LucideVariable-w100..w600.ttf`, 1.39 MB sıkışık / 3.0 MB ham) pakete giriyor, kod yalnız `LucideIcons.xxx` (statik `lucide.ttf`, ağaç budamalı 39 KB) kullanıyor. Flutter başka paketin fontunu ayıklamaya izin vermez; çözüm: paketi `dependency_overrides` ile yerel dalgalı kopyaya (değişken font girdileri silinmiş `pubspec.yaml`) almak. Kazanç ≈ 1.4 MB.
- A5-14b (ORTA) ML Kit barkod "bundled": `libbarhopper_v3.so` (arm64 2.11 MB) + `.tflite` x3 (0.62 MB) = ~2.7 MB. `mobile_scanner` Android'de `unbundled` mod destekler (Google Play Hizmetleri'nden modeli ilk kullanımda indirir; GMS'siz cihazlarda çalışmaz - Huawei vb.). QR yalnız etkinlik yoklamasında kullanılıyor; ödünleşim: ilk taramada ~3 MB indirme ve GMS bağımlılığı. Kararı ürün sahibi vermeli. Kazanç ≈ 2.7 MB.
- A5-20b (DÜŞÜK-ORTA) R8: `proguard-rules.pro` içinde `-keep class com.google.firebase.** { *; }`, `-keep class com.google.android.gms.** { *; }`, `-keep class com.google.mlkit.** { *; }` bütün sınıfları tutar ve R8 küçültmesini büyük ölçüde etkisizleştirir (dex ham 12.7 MB). Flutter eklentileri kendi tüketici kurallarını getirir; bu geniş kurallar genelde gereksizdir. Kazanç TAHMIN 1-2 MB; risk: yansıma ile çağrılan sınıflar (FCM) - release AAB üzerinde fcm + QR + kamera duman testi şart.
- Inter fontları (5 ağırlık, 0.99 MB sıkışık): kullanılan ağırlıkları doğrula (400/500/600/700/800). 800 (ExtraBold) yalnız birkaç yerde ise 700'e düşürmek 0.2 MB kazandırır; Latin-Extended alt kümesi (Türkçe yeterli) `pyftsubset` ile ~%50 küçültebilir (ama Arapça sistem yedeği). Kazanç 0.3-0.5 MB.
- libapp.so (arm64 4.5 MB sıkışık): `--obfuscate --split-debug-info` zaten kullanılıyor (doğru). `l10n` üç dilli `app_localizations*.dart` (≈1.1 MB kaynak) AOT'ta ≈ 0.3-0.5 MB; tembel yükleme yok, kabul edilebilir.
- `intl: any` (sürüm sabitlenmeli - tekrarlanabilir derleme). Kullanılmayan paket YOK: 20 bağımlılığın hepsi `lib/` içinde kullanılıyor (doğrulandı).
- İşe yaramayanlar: Material Icons zaten ağaç budamalı (2.4 KB), `res/` yoğunlukları Play tarafından bölünür, `x86_64` ve `armeabi-v7a` kütüphaneleri Play'de yalnız ilgili cihaza iner (APK dağıtımı yapılıyorsa: `--split-per-abi` / yalnız arm64 APK: 92.4 MB universal -> ~29 MB).

Toplam gerçekçi kazanç (arm64 indirme): ~3.5-4 MB güvenli (14, 13b, Inter) + 2.7 MB (unbundled ML Kit, kararlı) + 1-2 MB (R8) => ~21.8 MB -> ~13-15 MB.

## 8. Cihazda ölçülmesi gerekenler (CIHAZDA ÖLÇÜLMELİ)
1. Soğuk açılış: native splash -> ilk Flutter karesi -> ilk dolu Ana Sayfa (`flutter run --profile --trace-startup`, `adb shell am start -W`), düşük uçlu (2-3 GB RAM) ve orta uçlu cihaz; zayıf ağ (Network Link Conditioner / Android emülatör ağı kısıtı) ile A5-02.
2. DevTools Performance: Keşfet akışı hızlı kaydırma (raster süresi; BackdropFilter A5-07 açık/kapalı karşılaştırması), sekme geçişi (A5-08), sohbet detayı 500+ mesaj kaydırma ve poll anı (A5-04).
3. Bellek: `adb shell dumpsys meminfo tr.com.bukampus.app` (Graphics/Native Heap) Keşfet + sohbet + galeri sonrası; `imageCache.currentSizeBytes` log.
4. Ağ/pil: Android Studio Energy/Network profiler veya `adb shell dumpsys batterystats`; sohbet açıkken 30 dk içinde soket sayısı (`ss`/sunucu tarafı oturum sayısı) ve radyo uyanma sayısı (A5-01 öncesi/sonrası).
5. Jank: `flutter run --profile` + `--trace-skia`/Impeller, "Rebuild stats" ile `ChatDetailPage` ve `AppGate` yeniden kurma sayıları.
6. Avatar raster maliyeti (A5-19): 500 satırlık sohbet listesi, GPU süresi.
7. Kırpma süresi ve bellek tepesi (A5-13): 12 MP kaynak (3. parti seçici yolu) ile.

## 9. Önerilen düzeltme sırası
1. A5-01 (tek soket) - küçük kod, büyük pil/sunucu kazancı.
2. A5-02 + A5-06 (splash'i ağdan ayır, runApp önüne seri await koyma).
3. A5-03 (paylaşılan HttpClient + Image.network -> BuImage).
4. A5-04 (setState kapsamı + satır anahtarı).
5. A5-05 (in-flight GET birleştirme, dil PATCH'ini koşullu yap).
6. A5-14, A5-13b, A5-20b (boyut).
7. Geri kalan ORTA/DÜŞÜK.

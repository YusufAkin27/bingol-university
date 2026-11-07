# İstemci etkisi: FINAL-ALL (2026-11-01) birleşik dalı

Canlıda ve mağazada **eski mobil sürümler (2.0.5, 2.0.6)** çalışır; bu dal onların API beklentisini bozmamalıdır. Her
davranış için eski istemci kodu (`mobile/lib/core/api.dart`, `core/session.dart`, `core/realtime/`, `features/chat/*`,
`features/notifications/*`) okunarak sonuç kanıtlanmıştır. Web istemcisi (`web/src/api/client.ts`) aynı dalla yayınlanır.

Karar sütunu: **KORUNDU** = yeni davranış eski istemciyle uyumlu, olduğu gibi yayında; **ESKİ DAVRANIŞ** = yeni davranış
yapılandırma anahtarının ARKASINA alındı, varsayılan = eski davranış; **GERİ ALINDI** = değer eski haline getirildi.

| Davranış (paket) | Eski istemcide etki (kanıt) | Karar |
|---|---|---|
| `POST /api/auth/refresh` eş zamanlı ikinci istek: 401 yerine **409 `REFRESH_IN_PROGRESS` + `Retry-After: 1`** (P02) | Mobil `ApiError.isAuthRejected` yalnız `401` ya da (400/403 + oturum bitiren kod) için doğrudur (`api.dart:51-58`); 409 değildir, `handleRefreshFailure` oturumu kapatmaz (`api.dart:557`), `isTransient` de değildir, yani çağıran istek bir kez hata alır, **çıkış yapılmaz**. Eski sunucuda aynı durum 401 idi ve `onSessionExpired` ile kullanıcıyı ÇIKARIRDI. STOMP (`stomp_client.dart:195`) ve `session.dart:144,180` de `isAuthRejected` kullanır. Web: yalnız 401/403 oturumu bitirir (`client.ts:isSessionRejected`) | KORUNDU (eski istemci için iyileşme) |
| `rtnext` yanıt-kaybı penceresi 45 sn → 5 dk; tekrar kullanımda yalnız **o oturum ailesi** kapanır (P02) | Görünmez: aynı refresh çifti döner, istemci kodu değişmez. Diğer cihazlar açık kalır | KORUNDU |
| Okunmamış sayacı konuşma başına **en çok 100** (`unreadCount`, `unread-count`) (P03) | Mobil rozetleri `n > 99 ? '99+' : '$n'` çizer (`chat_tab.dart:999`, `chat_detail_page.dart:2841`, `floating_nav.dart:327`); 100 ile 5000 aynı görünür. Sayaç başka yerde hesapta kullanılmaz (`chat_tab.dart:237,265` yalnız +1/0) | KORUNDU |
| Oda ve 20+ üyeli gruplarda `status=null`, `receipt`/`read-receipts`/`typing` olayı yok (P03, K2) | Tik widget'ı `status` null ise hep tek tik ("gönderildi") çizer (`message_bubble.dart:172-183`); iletildi/okundu tikleri ve "yazıyor" odalarda/büyük gruplarda **kaybolurdu** | **ESKİ DAVRANIŞ**: `ReceiptPolicy` varsayılanı her konuşmada açık (`app.chat.receipts-max-members=0`, `app.chat.receipts-rooms=true`). Kapatma, eski sürümler zorunlu yükseltmeyle elendikten sonra ayarla yapılır |
| Oda başına gönderim sınırı dakikada 120 (P03) | Eski istemci oda için 429 beklemez; canlı etkinlik odasında meşru trafiği keser | **GERİ ALINDI**: 600/dk (kullanıcı başına 30/dk aynen) |
| `MESSAGE_EDIT_LIMIT` (bir mesaj en çok 10 düzenleme) 409 (P03) | Genel hata kodu yolu: sunucu metni istek dilinde gelir; nadir | KORUNDU |
| Okundu/iletildi, STOMP `chat.send` sıralama, DEK önbelleği, mute/archive tek kolon (P03) | Alan/yol sözleşmesi değişmedi; iç iyileştirme | KORUNDU |
| 2FA: `202` yanıtı, `trustDevice` sunucu varsayılanı `false` (hardened tabanı) | Bu dalda **değişmedi** (`git diff` `auth/twofactor`, `admin/twofactor`: boş). Mobil istemcide 2FA kodu yoktur; 2FA açan hesap eski mobil ile giremez, bu tabanda zaten böyleydi | DEĞİŞMEDİ |
| `CursorPage` / DTO alanları | Yalnız ekleme: yönetici `Counters` (+`sent`,`dead`,`outboxSkipped`), `LegalSummary` fabrika yöntemi (JSON aynı). Mobilin okuduğu hiçbir alan kaldırılmadı/yeniden adlandırılmadı | KORUNDU |
| `GET /api/news?q=` en az **3** karakter, IP başına 30/dk, `page` ≤ 200 (P07, K19) | Mobil `q` göndermez (`news_list_page.dart:136` yalnız type/page/size). Site (web) `MIN_QUERY` 2 → **3** yapıldı | KORUNDU (web uyarlandı) |
| `POST /api/notifications/read` `ids` ≤ 200 (P04) | Mobil tek kimlik ya da `{all:true}` yollar (`notifications_page.dart:109,128`) | KORUNDU |
| `DELETE /api/devices/{idOrToken}` (P04) | Rakamdan oluşan değer kimlik, aksi hâlde eski gibi FCM token; iki biçim çalışır | KORUNDU |
| `GET /api/departments` `Cache-Control` (P08), `GET /api/menu/today` max-age 60 (P07) | Gövde aynı; ETag/304 katmanı etkilenmez | KORUNDU |
| `GET /api/exams/official`: SQL'de süzülür, bitişi 30 günden eski sınavlar düşer, `scope=all` en yeni 500 (P08, K21) | Alan şekli aynı; eskiden `scope=all` en ESKİ 500 kaydı döndürüp yeni sınavları gizliyordu (hata). Çok eski sınavlar listede görünmez | KORUNDU |
| Etkinlik açma sınırları `409 EVENT_LIMIT_OPEN` / `429 EVENT_LIMIT_DAILY`, seri tavanı (P05, K14) | Eski sürüm bu hataları beklemez (kulüp yöneticisi etkinlik açamaz hâle gelebilir) | **ESKİ DAVRANIŞ**: `event_max_open_per_user` ve `event_daily_create_limit` kod varsayılanı **0** (sınırsız); sınır yönetici ayarıyla bilinçli açılır |
| Engelleme iki yönlü takibi/istekleri siler (P05, K15) | Alan sözleşmesi aynı; profil `follow` durumu `NONE` döner, mobil her profilde yeniden okur | KORUNDU (güvenlik iyileştirmesi) |
| Etkinlik "yarın" hatırlatması 22-26 saat kala (P05, K16) | Metin/yol aynı, zamanlama | KORUNDU |
| Kulüp/etkinlik/duyuru/anket bildirimleri istek dışı, COMMIT sonrası, toplu (FINAL-ALL ikinci tur) | Bildirim satırı/push yükü aynı; birkaç sn gecikebilir. İstek artık üye sayısıyla yavaşlamaz. Etkinlik duyurusu `recipients` sayısı yanıtta yine döner | KORUNDU |
| Menü günlük 06:00 yakalama işi (P07, K20) | İstemci etkisi yok ama CLAUDE.md scraping kuralını (cron sıklaştırma yasağı) aşar | **ESKİ DAVRANIŞ**: varsayılan KAPALI (`menu.catchup.cron=-`), `MENU_CATCHUP_CRON` ile sahibin kararıyla açılır |
| Rate limit: kullanıcı anahtarları bütçeden muaf, önek başına bütçe, Redis kesici 3 hata/2 sn (P01) | Daha az 429 / daha kısa kesinti; kimliksiz anahtar koruması korundu | KORUNDU |
| Prod compose Redis parolası / silme defteri (P10) | Varsayılan kapalı (ortam değişkeni tanımsızsa bugünkü davranış) | KORUNDU |

## Eski sürümlere ne zaman kalıcı kapatma uygulanır

`X-App-Version` başlığı (mobil gönderir, `ClientContexts.VERSION_HEADER`) bu dalda KULLANILMADI: tek iş parçacıklı yayın
(`receipt`/`typing` olayları Redis pub/sub ile tüm üyelere gider) alıcı sürümüne göre ayrıştırılamaz. Güvenli yol: mağazada
`min_supported_version` (appinfo) ≥ makbuzu `null` işleyen sürüm olduktan sonra `app.chat.receipts-max-members=20` ve
`app.chat.receipts-rooms=false` ile P03'ün yük azaltmasını açmak.

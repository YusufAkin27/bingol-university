# Bildirim ve Kampüs Haritası: mobil / backend sözleşme karşılaştırması

Tarih: 2026-11-02. Kaynaklar: mobil `integration/mobile-ui2` (bu dal); backend `origin/feat/notif-design-backend` (`NotifCard`, `RichChatPayload`, `PushPayload`, `docs/MOBILE_API_GUIDE.md` 6.y, `docs/changes/push.md` "NOTIF-BE") ve `origin/feat/campus-map-backend` (`CampusDtos`, `CampusService`, `docs/CAMPUS_MAP.md`). Yöntem: kod okuma (cihazda ve gerçek sunucuda denenmedi).

Durum sütunu: **Düzeltildi** = bu entegrasyonda mobilde küçük uyum kodu eklendi (testli); **Açık** = karar/iş gerekiyor; **Uyumlu** = sorun yok.

## 1. Bildirim (push `data` ve `GET /api/notifications` satırı)

| # | Alan / konu | Mobil bekliyordu | Backend veriyor | Durum | Öneri |
|---|---|---|---|---|---|
| 1 | Kart kimliği | `subtype` + `actions` + `channelId` ipuçlarından çıkarım | `card` (NotifCard sabit adı, 27 değer) hem push hem satır `data` | **Düzeltildi** | `resolveRichKind` önce `card`'a bakar (`kBackendCardKinds`, `richKindOfCard`); bilinmeyen/boş değerde eski yola düşer. Bildirim satırında `notifKindOf` da `card`'ı okur. |
| 2 | Anket kapanıyor | `closing=1` ya da `subtype` içinde `CLOS` | Alt tür her zaman `POLL`; kapanış yalnız `card=POLL_CLOSING` | **Düzeltildi** (`card` ile) | Backend `closing` göndermek zorunda değil. |
| 3 | Etkinlik 1 saat / yarın | `EVENT_REMINDER` + `qr_checkin` eylemi | `card=EVENT_HOUR` (`qr_checkin`) / `EVENT_DAY` (`calendar,view`) | Uyumlu (+ `card` ile sağlamlaştı) | - |
| 4 | Etkinlik iptali | `cancelled=1` / `tone=danger` / alt tür `CANCEL` | Alt tür `EVENT_UPDATE`; iptal yalnız `card=EVENT_CANCELLED` | **Düzeltildi** (`card` ile) | Önceden iptal "değişiklik" kartı gibi çizilirdi. |
| 5 | Güvenlik kartları | `NEW_DEVICE_LOGIN`, `PASSWORD_CHANGED`... alt türleri veya eylem kimlikleri | SYSTEM türü, alt tür YOK; `channelId=security`; `card=SECURITY_*` | **Düzeltildi** (`card` ile) | `SECURITY_2FA_ON` (yalnız `view` eylemi) önceden hiçbir yola düşmüyordu. |
| 6 | Güvenlik hedefi | `targetType=ACCOUNT_SECURITY` | `targetType=SECURITY` | **Düzeltildi** | `push_targets.dart` `SECURITY` takma adı Hesap ve Güvenlik ekranına çözer; öncesinde bildirim listesine düşüyordu. |
| 7 | Takip isteği kimliği | `requesterId` / `senderId` / `userId` | `requestId` + `userId` (ikisi de istek sahibinin kullanıcı kimliği) | **Düzeltildi** | `personIdOf` artık `requestId`'yi de okur. (`userId` zaten çalışıyordu.) Kabul/red ucu: `POST /users/me/follow-requests/{id}/accept\|decline`, mobil `reject` -> `decline` eşler. |
| 8 | Alt tür adları | `CLASS_REMINDER`, `HOMEWORK_DUE`, `DEPT_ANNOUNCEMENT`, `POLL_CLOSING`, `NEW_DEVICE_LOGIN`... | Gerçek alt türler: `MESSAGE_DIRECT/GROUP`, `EVENT_REMINDER/UPDATE/ADMISSION`, `POLL`, `ACADEMIC_ANNOUNCEMENT`, `EXAM_REMINDER`, `UNIT_ANNOUNCEMENT`, `MENU_DAILY`, `POST_LIKE`, `USER_FOLLOW`, `FOLLOW_REQUEST`, `FOLLOW_ACCEPTED` | Uyumlu (karşılıklar) | `UNIT_ANNOUNCEMENT` -> bölüm kartı, `MENU_DAILY` -> menü kartı mobilde zaten parça eşleşmeyle çözülüyor. Ders (`CLASS`) ve ödev (`HOMEWORK`) kartlarının backend olayı YOK (ders yerel hatırlatma, ödev modülü yok): mobilde kullanılmayan kod yolu, zararsız. |
| 9 | Etkinlik başlangıcı (şerit tarih karosu) | `startsAt` / `eventStartsAt` | Hiçbiri gönderilmiyor | Açık | Backend etkinlik hatırlatma `data`'sına ISO `startsAt` eklerse şerit tarih karosu çizilir; yoksa takvim simgesi gösterilir (bozulmaz). |
| 10 | Mesaj kimliği | `messageId` (mark_read için) | `messageId` + `conversationType` sohbet `data`'sında var | Uyumlu | Birikmiş (`CHAT_MANY`) kartta `messageId` son mesajı göstermeli; değilse mobil sohbeti açar (güvenli geri düşüş). |
| 11 | Gönderen kimliği | `senderId` | Yok (`userId`/`actorId`; sohbette `conversationId`) | Uyumlu | Mobil `userId`/`requestId`'ye düşer. |
| 12 | Üst etiket | `label` | `label` (bölüm adı) | Uyumlu | - |
| 13 | Görsel | `imageUrl` + `imageStyle` | `imageUrl` mutlak https (uygulama alanı veya `*.bingol.edu.tr`), `imageStyle` `big\|thumb` | Uyumlu | Sohbet fotoğrafı `imageAttachmentId` önce `imageUrl`'e (imzalı küçük resim) çevrilir; mobil yalnız `imageUrl` okur. |
| 14 | Eylem kimlikleri | `reply, mark_read, mute_1h, view, calendar, qr_checkin, vote, follow_back, accept, reject, not_me, reset_password, enable_2fa, sign_out_device, view_ticket, exam_card` | Aynı küme (`NotifCard`) | Uyumlu | `open_schedule` yalnız yerel ders hatırlatması içindir. |
| 15 | Eylem uçları | `POST /conversations/{id}/messages`, `POST .../read {lastMessageId}`, `PUT .../mute {durationMinutes:60}`, `POST /users/{id}/follow`, `POST /security/not-me` | Aynı | Uyumlu | - |
| 16 | `targetType` yeni değerler | - | `UNIT_NEWS` (birim duyurusu), `MENU` (`targetId`=tarih) | Açık | Mobilde birim haberi (`/api/news/unit`) istemcisi ve menü tarih hedefi yok; iki değer şimdilik bildirim listesine düşer (zararsız). Birim haberi ekranı ve menü hedefi ayrı iş. |
| 17 | iOS kategorisi | - (iOS'ta `UNNotificationCategory` kaydı yok) | `iosCategory` = `BU_<EYLEMLER>` (örn. `BU_REPLY_MARK_READ`), APNs `category` | Açık | iOS eylem düğmeleri için `BuNativeBridge.swift` içinde bu kategorilerin kaydı gerekir; o zamana dek iOS standart bildirim (eylemsiz) alır. Android etkilenmez. |
| 18 | `X-Device-Model` | Gönderilmiyor | İsteğe bağlı başlık, yeni cihaz bildirimi gövdesinde kullanılır | Açık | Mobil `ApiClient`'a cihaz modeli başlığı eklenirse gövde "Samsung Galaxy S24 · 09:41" olur; yoksa platform adı. |
| 19 | `menuDaily` tercihi | Tercih sayfasında anahtar yok | `menuDaily` (varsayılan KAPALI) + `subtypes.MENU_DAILY` | Açık | Mobil tercih sayfasına "Bugünün menüsü" anahtarı eklenmedikçe kullanıcı günlük menü bildirimini açamaz. |
| 20 | Kutu süzgeci | İstemci tarafı süzer | `?category=all\|messages\|events\|announcements\|social\|system` | Uyumlu | İstenirse sunucu süzgecine geçilebilir; zorunlu değil. |

Bilinen sıra: backend zengin yolu `app.push.rich-chat-enabled` (varsayılan KAPALI) ve Android >= 2.0.8 ile sınırlıdır; mobil tarafı hazır.

## 2. Kampüs haritası (`GET /api/campus/map`, `/places`, `/places/{id}`)

| # | Alan / konu | Mobil | Backend | Durum | Öneri |
|---|---|---|---|---|---|
| 1 | `places` üst sınırı | `?limit=500` ister | Varsayılan 100, EN ÇOK 200 (üstü sessizce 200'e çekilir) | Açık (düşük) | Bugünkü ~45 kayıtta etkisiz. Mobil `limit=200` isteyip 200'e ulaşılırsa sayfalama/`category` ile devam etmeli; toplam 2000'e kadar büyüyebilir. |
| 2 | Sunucu `q`/`category` süzgeci | İstemcide süzer | Var | Uyumlu | Tek istek + istemci araması doğru. |
| 3 | Bölüm adları | `departments` (yoksa `units`); liste verisiyle çizer, yer detayını (`GET /places/{id}`) yalnız derin bağlantıyla açılışta ister | `departments` YALNIZ `GET /places/{id}`'de dolu (liste öğesinde `null`), `units` listede de | Açık | Yer detayı sayfası açılırken `GET /campus/places/{id}` çağrılıp `departments` ile zenginleştirilmeli; şimdilik "Birimler" satırı yalnız elle girilen `units`'i gösterir (akademik birimlerin bölüm listesi görünmez). Çökme yok, eksik bilgi. |
| 4 | Harita ayarı | `center, zoom{initial,min,max}, bounds{south,west,north,east}, boundary, tiles{urlTemplate,attribution,maxNativeZoom,userAgentHint}, categories[{key,label,icon,color}], version` | Aynı | Uyumlu | `color` bilerek kullanılmıyor (RENK-1). |
| 5 | Uydu katmanı | `tiles.satellite` / `satelliteTiles` varsa düğme | Alan yok | Uyumlu | Düğme çıkmaz; backend eklerse mobil kendiliğinden çizer. |
| 6 | `remote` birimler | Haritada iğne yok, "Diğer yerleşkeler" | `remote=true` | Uyumlu | - |
| 7 | `webUrl` | Yalnız https + bingol.edu.tr | Aynı kural (sunucu doğrular) | Uyumlu | - |
| 8 | `unitSourceCode` | Okunmuyor | Var (birim haber kaynağı kodu) | Açık (isteğe bağlı) | İleride yer detayından birim haberine bağlantı için kullanılabilir. |
| 9 | Kimlik / hız | Oturum açık istek | Giriş gerekli, kullanıcı başına dakikada 120 | Uyumlu | Ana Sayfa kartı ağ isteği atmaz. |
| 10 | Önbellek | ETag/304 + `version` | `ETag`, `Cache-Control: private, max-age` (harita 300 sn, liste 60 sn) | Uyumlu | - |
| 11 | Hata kodları | Genel hata kartı | `CAMPUS_PLACE_NOT_FOUND` (404) | Uyumlu | Detay 404'ünde mobil yer bulunamadı davranışına düşer. |

Not: harita karoları `tiles.urlTemplate` adresinden gelir. Mobil `userAgentHint`'i ayrıştırır ama kullanmaz; karo isteklerinde sabit `userAgentPackageName: tr.com.bukampus.app` gönderir (OSM politikası için yeterli bir açık kimlik; backend `BUKampus/{version}` kalıbını istiyorsa mobil sürümle doldurmalı). Bu bir sonraki cila işi.

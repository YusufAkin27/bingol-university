# Değişiklik günlüğü

## feature/mobil-uygulama (2026-10)

Ayrıntılı modül notları: `docs/changes/*.md`. Mobil API rehberi: [MOBILE_API_GUIDE.md](MOBILE_API_GUIDE.md).

### Mobil renk sistemi sadeleştirmesi (RENK-1)

- **Tek palet:** sakin marka kırmızısı (`pr` #C0392B, simge #F73B2E ile uyumlu) + dört anlam ailesi (koyu mavi `info`, su mavisi `aqua`, yeşil `ok`, amber `warn`) + `danger` (hata, markadan ayrı ton) + sıcak-nötr yüzeyler (açık kırık beyaz #F7F5F2, koyu yumuşak kömür #171819). Mor/pembe/turkuaz/çivit/sarı-turuncu kaldırıldı; `tints` 6 çift korunur ama dört aileye eşlenir (`BuTintId`). Yeni belirteçler: `info*`, `aqua*`, `onOkSoft`, `dangerSoft`, `bdStrong`, `selectedBorder`.
- **Erişilebilirlik (A6-02/03/16):** kontrol çerçevesi (`bdStrong`) tüm yüzeylere karşı >= 3:1; seçilmemiş seçim halkası aynı; seçili çip/segment için tek stil (`soft` + `onSoft` + `selectedBorder`) ve seçili sohbet seçim dairesine onay işareti.
- **Kod:** ekranlardaki sihirli renkler belirteçlere taşındı (`Color(0x..)`/`Colors.*` yalnız avatar painter, ders renk tabanı, sabit gölge); ders renk seçicisi 10 -> 6 renk (eski sunucu anahtarları en yakın aileye eşlenir); varsayılan avatar paleti yeni ailelerden; durum çubuğu ve Cupertino teması açıkça belirteçlere bağlandı. Test: `test/redesign/renk_paleti_test.dart` (AA kontrast, aile tutarlılığı, `lib/` taraması). Ayrıntı: [design/RENK_ENVANTERI.md](design/RENK_ENVANTERI.md), [MOBILE_DESIGN_SYSTEM.md](MOBILE_DESIGN_SYSTEM.md) bölüm 3. Web (`tokens.css`) bu paleti henüz almadı.

### iOS yayın hazırlığı (IOS1)

- **Belgeler:** [IOS_RELEASE.md](IOS_RELEASE.md) (Apple Developer hesabı açıldığında adım adım, kararlar K1-K9, kullanıcıdan gerekenler, red riskleri, yapılanlar/yapılamayanlar tablosu), mağaza paketi [ios-store/](ios-store/README.md) (tr/en/ar metin, App Privacy, inceleme notu, ekran görüntüsü kılavuzu), [MOBILE_PUSH.md](MOBILE_PUSH.md) "iOS doğrulama".
- **Proje (dosya düzeyinde, Xcode'da derlenmedi):** `PrivacyInfo.xcprivacy` (takip yok, 13 veri türü, FileTimestamp C617.1 + SystemBootTime 35F9.1), Info.plist (dürüst Türkçe izin metinleri, `ITSAppUsesNonExemptEncryption=false`, `CFBundleLocalizations` tr/en/ar, yalnız dikey iPhone, `arm64`), `{tr,en,ar}.lproj/InfoPlist.strings`, iPhone-only (`TARGETED_DEVICE_FAMILY=1`). Bundle id **değişmedi** (karar bekliyor: `scripts/ios/set-bundle-id.sh`).
- **iOS'a özgü düzeltmeler:** simge rozeti (`core/push/icon_badge.dart`, sunucu `badge` sayısı okununca takılı kalıyordu), iOS yerel ders/sınav hatırlatmaları ve rozet köprüsü (`ios/Runner/BuNativeBridge.swift`; yalnız `swiftc -parse` ve sahte modüllerle tip denetimi, macOS'ta derlenmeli), yeniden kurulumda Keychain'de kalan oturum jetonlarının temizlenmesi (`core/platform/fresh_install.dart`; cihaz kimliği korunur). Testler: `icon_badge_test`, `fresh_install_test`.
- **Hatlar (çalıştırılmadı):** `.github/workflows/ios-release.yml`, `codemagic.yaml`, `scripts/ios/{prepare-ci,build-ipa,upload-testflight,set-bundle-id,simulator-shots}.sh`, `mobile/ios/fastlane/`, `mobile/ios/ExportOptions.plist`; denetim betikleri `scripts/ios/check-ios-static.py`, `check-store-lengths.py`.

### Yayın hazırlığı (REL1)

- **Geri yükleme provası:** `scripts/restore-drill.sh` (tohum veri + fotoğraf -> gerçek yedek -> `down -v` -> yeni boş yığında `restore-live.sh` -> parmak izi karşılaştırması). Sonuç ve süreler: [BACKUP_RESTORE.md](BACKUP_RESTORE.md) bölüm 10. Prova üç gerçek hata buldu ve düzeltildi: prod compose'ta redis `setpriv` için `SETUID/SETGID`, yedek servisi için `FOWNER` (aksi halde yedek konteyneri döngüde), ve backend'in `prod` profilinde açılmamasına yol açan `OpenApiConfig.uniqueSchemaNames` (springdoc kapalıyken `ObjectMapperProvider` yok).
- **Belgeler/betikler:** [LAUNCH_CHECKLIST.md](LAUNCH_CHECKLIST.md) (alan adı, DNS, Brevo, VPS sırası), [DEPLOY.md](DEPLOY.md) bölüm 14 (dağıtım disiplini), `scripts/warmup.sh` (soğuk JVM ısıtma), `scripts/staging-smoke.sh` (canlı salt-okur duman), [DEVICE_TEST_PLAN.md](DEVICE_TEST_PLAN.md), [store/](store/README.md) (Play metinleri, veri güvenliği, derecelendirme), [ANDROID_RELEASE.md](ANDROID_RELEASE.md) bölüm 8, [PUSH_SETUP.md](PUSH_SETUP.md) bölüm 6 (API anahtarı kısıtlama).

### Backend

- **Auth:** şifre sıfırlama (3 adım: `forgot-password` → `verify-reset-code` → `reset-password`); `POST /api/auth/logout-all`; bekleyen kayıt Redis'te (`reg:<email>`, 1 saat), hesap yalnız `verify-email` ile oluşur (başkasının e-postasıyla önceden kayıt açıp hesabı ele geçirme yolu kapandı); kod deneme kilidi (5 yanlış → 10 dk), `verify-email` e-posta başına sınır; `/login` sabit süre; `pwchg:<uid>` ile eski access token iptali; `SessionService.revokeAll`.
- **Mail:** DB tabanlı e-posta kuyruğu (`mail_outbox`, V110), `MailQueueWorker`, geri çekilmeli yeniden deneme, ölü kayıt (DEAD), tr/en/ar HTML + düz metin şablonları, `mailQueue` sağlık göstergesi, maskeli log. Kodlar artık asenkron gelir.
- **Push:** `PushDispatcher` (asenkron, 500'lük parçalar, üstel geri çekilmeyle 3 yeniden deneme), cihaz upsert (`platform` büyük/küçük harf toleranslı, `appVersion`, `locale`, `lastSeenAt`; V120), 60 gün görülmeyen token temizliği, `targetType`/`targetId` yükü, Android kanalları + APNs ayarları, `FCM_CREDENTIALS_JSON` (ham/base64) veya `FCM_CREDENTIALS_FILE`, `fcm` sağlık göstergesi. Kurulum: [PUSH_SETUP.md](PUSH_SETUP.md).
- **Mesajlaşma:** kulüp (`CLUB`) ve etkinlik (`EVENT`) sohbetleri (`communityId`/`eventId`), yanıt/düzenleme/herkes için silme/tepki, sohbet görselleri (şifreli, yeniden kodlanmış), sessize alma (`mutedForever`) ve arşiv, tutarlı `unread-count`, `message-events` kuyruğu, okundu bilgisinde sessiz sınır, WebSocket token süresi dolunca kapanış (1008 `TOKEN_EXPIRED`), ek rate limitler.
- **Etkinlik/topluluk:** takvim zenginleştirme (`myRsvp`, sayaçlar, `capacity`, `status`, `communityName`, `X-Truncated`), `attendees/preview`, toplu `canManage`; `communities/categories`, `requests?include=answers`, üyelik düşme olayı (`ClubMemberLeftEvent`), keşfet indeksi (V140), oda bakımı.
- **Profil/arama:** `GET /api/me/summary`; `GET /api/search` tür + imleç sayfalama; `users/search` `nextCursor`; hesap silmede cihaz/bildirim/favori/başvuru/üyelik temizliği; arama indeksleri (V160).
- **Haber/menü/durum:** `eventDate` (V170), mutlak URL ve tarih ayrıştırma düzeltmeleri, içerik yeniden deneme (en çok 5, gece zamanlayıcısında), `NULLS LAST` sıralama, `type` toleransı (`NEWS_TYPE_INVALID`), `MENU_MONTH_INVALID`, `/api/status` `maintenanceMessage`.
- **Ops:** `Retry-After` başlıklı 429, `{code,message}` gövdeli 401 (`ApiAuthenticationEntryPoint`), CORS açık başlıkları (`X-Next-Cursor`, `X-Truncated`, `Retry-After`), `blocks`/`admin/faq` imleç sayfalama, analitik PII reddi, liste indeksleri (V180).
- **Üretim:** `prod` profili, `ProdSettingsValidator`, güvenlik başlıkları (HSTS vb.), `SchedulerLock` (çoklu örnek kilidi altyapısı), [DEPLOY.md](DEPLOY.md); mesaj şifreleme ve medya hattı ([ENCRYPTION.md](ENCRYPTION.md), [MEDIA_PIPELINE.md](MEDIA_PIPELINE.md)).
- **i18n:** metinler modül bazlı paketlere bölündü (`i18n/<modül>.properties`).

- **Keşfet gönderileri (sadeleştirme):** gönderi = tek fotoğraf + ≤7 kelime metin; yorum, hikâye, etiket/bahsetme, kaydet ve beğenenler listesi kaldırıldı (`410 FEATURE_REMOVED`); `GET /api/feed?scope=top` puanlı akış (imleç, `hint`); arama yalnız görünür+fotoğraflı gönderileri bulur; beğeni sayacı yarışı düzeltildi. Bkz. `changes/post.md`, [POSTS_DESIGN.md](POSTS_DESIGN.md).
- **Takip:** profil ve takipçi/takip edilen listelerinde `followsMe` (karşılıklılık istemcide `followedByMe && followsMe`).
- **Yemek menüsü fotoğrafı:** menü yanıtlarında `imageUrl`, yönetici uçları `GET /api/admin/menu`, `PUT|DELETE /api/admin/menu/{date}/image` (web: yönetim paneli menü fotoğrafı sayfası).
- **Yemek kalorisi (V870):** yemek başına yönetici kalorisi (`menu_item_calorie`, kaynak senkronuyla ezilmez); menü yanıtlarında `dishes[{name,kcal}]`, `totalKcal`, `kcalComplete`; yönetici uçları `PUT /api/admin/menu/{date}/calories` ve toplu `PUT /api/admin/menu/calories`; web panelinde satır içi düzenleme + toplu yapıştırma. Bkz. `changes/ops.md`.
- **Auth:** `POST /api/auth/change-password` (oturum açıkken şifre değiştirme; kullanıcı başına saatte 5).
- **Etkinlik:** herkes etkinlik açar; `joinPolicy` (`OPEN|APPROVAL`), katılım isteği uçları (`GET /events/{id}/requests`, `.../approve|reject`), `myRsvp=PENDING|REJECTED`. Bkz. `changes/event.md`.
- **Akademik takvim** 2026-2027 verisi; `docs/openapi.json` yeniden üretildi.

### Mobil (Flutter)

- Çok ekranlı uygulama: kimlik (kayıt, doğrulama, şifre sıfırlama), Ana Sayfa, Keşfet, Sohbet, Kulüpler, Etkinlikler, Yemek, Bildirimler, Arama, Destek, Profil, Ayarlar; açık/koyu tema ve tasarım belirteçleri.
- Gerçek zamanlı sohbet (STOMP), görsel yükleme, QR yoklama (üretim + tarama), açılış kapısı (zorunlu güncelleme/bakım), analitik, ETag/304 LRU önbelleği, sayfalama, kulüp katılım soruları, kategori, `me/summary` rozetleri, push servisi (Firebase bilgisi bekliyor).
- Testler: api, api_cache, app_gate, auth, stomp_frame, theme, widget, format. Belge: [MOBILE_UI.md](MOBILE_UI.md).

### Altyapı ve araçlar

- Performans ölçümü: `scripts/perf/perf-api.js` + [PERFORMANCE.md](PERFORMANCE.md).
- Duman/uçtan uca betikleri: sohbet özellikleri/görselleri/grupları, kulüp, etkinlik, şifreleme, medya saldırıları, moderasyon vb. (`scripts/`).
- Belgeler: [DEPLOY.md](DEPLOY.md), [PUSH_SETUP.md](PUSH_SETUP.md), [MOBILE_PUSH.md](MOBILE_PUSH.md), `docs/changes/` notları.

### B1: mobil tasarım isteklerinin backend karşılığı (opsiyonel alanlar, migration yok)

- **Anket:** `GET /api/polls` yanıtına `totalCount` ve `openCount`.
- **Sohbet:** `lastMessage.senderName` (grup/kulüp/etkinlik), `peer.online` (birebir; toplu Redis okuması); sohbet push `data`sına `senderAvatarUrl` (gizlilik + engel uyumlu).
- **Kulüp:** üye/başvuru satırlarında `department`, `classYear` (profil gizliliğine uyar) ve `requestedAt`; gönderilerde `authorRole`; `/me/communities` bekleyen kulüp satırında `requestedAt`. Gönderi beğenisi (`likeCount/liked`) beğeni modeli olmadığı için eklenmedi.
- **Etkinlik:** `checkin-code` yanıtına 6 karakterli `manualCode` (check-in kabul eder, ek hız sınırı); katılım isteği satırlarında `email` (yalnız yönetici) ve `classYear`; `EventView.communityLogoUrl`.
- **Arama:** `SearchHit` COMMUNITY için `memberCount/category/myStatus`, POSTS için `likeCount` (toplu sorgu).
- Ayrıntı: `MOBILE_API_GUIDE.md` "Tasarım uygulaması için eklenen opsiyonel alanlar (B1)".
- **B1 (devam):** takip listesi/öneri `classYear`; `/me/blocks` `X-Total-Count`; arama EVENT `startsAt/endsAt`; sohbet `peer` ve üye satırı `department/classYear`; takvim `pendingCount`; `EventView.cancelReason/rejectReason` (yalnız yönetici); `GET /users/me` `avatarHidden`.
- **B1 (devam 2):** bildirim tercihleri `polls` + `academicAnnouncements` (V880, `notification_pref` iki sütun; anket ve bölüm duyurusu gönderimleri bu bayraklara bakar); `GET /users/{id}` `blockedByMe`; `GET /events/{id}` `chatAccess`.
- **B1 (R1 duzeltmeleri):** anket/akademik tercih bayraklari ana tur bayragi VE kendi bayragi olarak uygulanir (V880 geri doldurma gerekmez); etkinlik basvuran `email` yalniz `showEmail=true` ise, `department`/`classYear` gizlilige uyar; sohbet push avatari yalniz push yukunde (bildirim kutusuna yazilmaz), `viewersAmong` toplu sorgu; `chatAccess` tek ek sorgu; kulup `PostView` sinif duzeyi NON_NULL kaldirildi (yalniz `authorRole`), OpenAPI semasi `CommunityDtosPostView`; anket sayaclari notu.

# Değişiklik günlüğü

## feature/mobil-uygulama (2026-10)

Ayrıntılı modül notları: `docs/changes/*.md`. Mobil API rehberi: [MOBILE_API_GUIDE.md](MOBILE_API_GUIDE.md).

### Hukuki metinler: e-posta alan adı kısıtı kalktı (2026-11-06, `deploy/legal-20261106`)

- **V1470** Kullanım Koşulları, Gizlilik Politikası ve KVKK Aydınlatma için yeni sürüm (tr/en/ar, `require_reaccept=FALSE`: yeniden onay istenmez): "yalnız bingol.edu.tr" kısıtı kalktı (herhangi bir geçerli e-posta + e-posta doğrulama kodu), isteğe bağlı Google/Apple girişi veri kategorisi eklendi, "kurumsal e-posta" ve alan adı denetimi ifadeleri düzeltildi. Üretim: `scripts/build-legal-migration-v1470.js`; V820 kaynakları `docs/legal/archive/v820/`.
- **V1471** SSS "Kimler kayıt olabilir?" (tr/en/ar) yalnız eski V3 varsayılanıyla birebir eşleşiyorsa güncellenir (yönetici düzenlemesi ezilmez).
- `error.ACCOUNT_NOT_FOUND` üç dilde "okul numarası" yerine "e-posta adresi". Metinler taslaktır; hukuk incelemesi önerilir (`docs/LEGAL_NOTES.md` bölüm 14).

### Çoklu oturum + Cihazlarım (2026-11-06, `deploy/multisession-20261106`)

- **Tek cihaz kuralı kalktı:** mobil giriş artık önceki mobil oturumları kapatmaz ve FCM kayıtlarını silmez; eski davranış `app.auth.single-mobile-session=true` (`AUTH_SINGLE_MOBILE_SESSION`) ile geri gelir. Bildirimler kullanıcının tüm cihazlarına gider.
- **Cihazlarım:** her giriş bir oturum kimliği (`sid`, JWT `sid` talebi + refresh kaydı) ve `user_session` satırı alır (**V1460**: tablo + `device.session_id`). Yeni uçlar `GET /api/auth/sessions`, `DELETE /api/auth/sessions/{sid}` (tek cihazdan çıkış: o sid'in token'ları anında 401, o cihazın push kaydı silinir, WS kapanır); `logout-all` aynen. `POST /api/auth/logout` artık yalnız o cihazın access token'ını da hemen geçersiz kılar. Girişte `X-Device-Name` başlığı okunur (yoksa User-Agent/platform).
- **Yeni cihaz girişi:** başka açık oturum varken bilinmeyen cihazdan giriş → tüm cihazlara uygulama içi bildirim + push (`SYSTEM`, tercihten bağımsız, `targetType=SECURITY`/`devices`) ve `SECURITY_NEW_LOGIN` e-postası.
- Saklama 100 gün (`app.dbmaint.session-days`), hesap silme/KVKK dışa aktarım kapsamı eklendi. Ayrıntı: `docs/changes/auth.md` "Çoklu oturum + Cihazlarım". Duman: `scripts/smoke-multi-session.sh`; `smoke-single-session.sh` yalnız bayrak açıkken koşar (aksi halde ATLANDI).

### Kaldırılanlar (2026-11-05, `deploy/nomap-20261105`)

- **Kampüs haritası kaldırıldı:** `campus` paketi, `GET /api/campus/*`, `/api/admin/campus/**`, `campus.read|write` izinleri, `campus` önbellek ad alanı, `campus_place.photo_key` medya referansı, i18n `campus*`, yönetim paneli "Kampüs haritası" sayfası, `docs/CAMPUS_MAP.md`, `scripts/smoke-campus.sh`. **V1250** `campus_place` ve `campus_config` tablolarını düşürür (V1200/V1201 canlıda uygulanmış olduğundan dosyaları DEĞİŞMEZ).
- **Akademik "bölüm duyuruları" kaldırıldı:** `DepartmentAnnouncementService`, `AnnouncementNotifier`, `/api/announcements*`, `/api/admin/announcements*`, `comms.announce` izni, bildirim alt türü `ACADEMIC_ANNOUNCEMENT` (+ `notif.academic.announcement` şablonu), toplu işlem/CSV `ANNOUNCEMENT` varlığı, panel sayfası. **V1251** `announcement_read`, `department_announcement` tablolarını düşürür ve eski bildirim/alt tür tercih satırlarını siler. (`notification_pref.academic_announcements` bayrağı sınav hatırlatması için kaldı. Haber türü "duyuru", `unitnews`, kulüp ve etkinlik duyuruları ayrı özelliklerdir, DEĞİŞMEDİ.)
- **Resmi sınav programı kaldırıldı:** `GET /api/exams/official`, `/api/admin/academic/exams*`, toplu işlem/CSV `EXAM` varlığı, panel sayfası; **V1251** `exam_schedule` tablosunu düşürür. Kişisel sınavlar (`tt_exam`, Sınavlarım, sınav hatırlatması) ve resmi ders programı kalır.
- **Mesaj önizleme tercihi kaldırıldı:** `messagePreview` (tercih API'si), `app.push.message-preview` / `message-preview-optin` ayarları, `PUSH_MESSAGE_PREVIEW`; push gövdesi her zaman mesaj metninin ilk 100 karakteridir, Android `chat` kanalı kilit ekranında `PUBLIC`. **V1252** `notification_pref.message_preview` sütununu düşürür.

### UNION (2026-11-04): iki dağıtım hattının birleşimi (`deploy/union-20261104`)

- `deploy/final-all-20261101` (Drive yedek, 2FA, birim haberleri, admin arama/panel yenileme, P01-P10 düzeltmeleri, V1040-V1141) + `deploy/final-20261104` (Keşfet V1220-V1230, kampüs V1200-V1201, resmî ders programı V1150-V1160, parola/kod süresi, davranış analizi V1240, site yeniden tasarımı). Migration numarası çakışması yok; A'nın V1040-V1141 dosyaları ve B'nin V1150+ dosyaları kaynaklarıyla bayt bayt aynıdır (Flyway checksum korunur). Yeni numara yok: en yüksek V1240.
- Site sayfaları B'nin yeniden tasarımıdır; A'nın SEO/içerik işleri (JSON-LD `@id` grafiği, SSS +15 soru, iç bağlantılar, haber JSON-LD, menü fotoğrafı doğrulaması `safeMenuImageUrl`, StoreButton `pending`) üzerine yeniden uygulandı. WebSite/Organization/MobileApplication JSON-LD'ye "bukampus"/"BuKampüs" takma adları eklendi (Organization türü A'daki gibi; üniversite adı takma ad olarak yazılmaz).
- Redis: `user: redis` (B, canlıda doğrulanmış); `DAC_READ_SEARCH` ekli kök yolu düştü. `REDIS_PASSWORD`/`--requirepass` (A) korunur.
- `DbMaintenanceJob`: P09 "rollup başarısızsa ham olay silme atlanır" + `behavior_rollup_days` birlikte.
- `docs/openapi.json` `OpenApiExportTest` ile yeniden üretildi.

### Resmi ders programı kişisel programa tohumlanır (V1160)
### Şifre kuralı gevşetildi + kayıtta ad isteğe bağlı

- **Şifre:** yönetici olmayan hesaplarda (kayıt, şifre sıfırlama, şifre değiştirme) yalnız **en az 6 karakter** ister; bileşim, yaygın liste, dizi/tekrar ve kişisel veri denetimi kalktı. Kısa şifre `400 PASSWORD_TOO_SHORT` (tr/en/ar). Yönetici hesapları eski güçlü kuralda (12+ karakter, `PASSWORD_TOO_WEAK`) kalır; giriş, hesap kilidi ve hız sınırı değişmedi. `app.auth.password-min-length` varsayılanı 10 → 6.
- **Kayıt:** ad kayıtta alınır; fakülte/bölüm/sınıf kayıttan sonra `PATCH /api/users/me` ile tek istekte girilir (kota yok). `displayName` sunucuda isteğe bağlı kabul edilir (boşsa geçici ad: e-posta kullanıcı adı ya da "Öğrenci"; geçici adın ilk değişimi 7 günlük bekleme kuralına sayılmaz). Yönetici kaydında ad zorunlu kalır. Bkz. `docs/changes/auth.md`.

### Şifremi unuttum 404 + kod süresi/bekleme

- **`forgot-password`:** kayıtlı olmayan hesap için e-posta gitmez, `404 ACCOUNT_NOT_FOUND` döner (bilinçli enumerasyon istisnası; IP başına dakikada 15 ek sınır). **Kodlar:** geçerlilik tam 10 dk; yeniden kod bekleme süresi 60 sn → **180 sn** (`resend-code`, `forgot-password`, tekrar `register`, destek formu): erken istek `429 RESEND_COOLDOWN` + `Retry-After`. Bkz. `docs/changes/auth.md`.

### Kullanıcı davranış analizi (V1240, yönetim paneli)

- **Sunucu (BK6):** mobil olay sözleşmesi genişledi (`props.sid` oturum kimliği, `session_start|session_end|screen_exit|action`, 22 izinli eylem türü; sözleşmeyi bozan olay tek tek elenir; `props` 5 -> 8 anahtar). Yeni `analytics.behavior` paketi: `GET /api/admin/analytics/behavior/{overview,screens,flows,actions}` (`analytics.read`) ve `/users`, `/users/{id}` (`users.pii`, her çağrı denetim kaydına yazılır): oturum/ekran süresi, çıkış ve bounce oranları, akışlar, eylem sayıları, kullanıcı oturum zaman çizelgesi. Aralık en çok 45 gün (`RANGE_TOO_LARGE`). Kalıcı günlük özetler `analytics_session_daily` / `analytics_screen_daily` (kullanıcı kimliği yok; gece dolum). Ayrıntı: `docs/ADMIN_API.md` "Kullanıcı davranış analizi", `docs/changes/ops.md`. Duman: `scripts/smoke-behavior.sh`.

### Resmî ders programı (Excel yükleme, V1070) + yeni hesap varsayılanı

- **Tohumlama:** `GET /api/timetable`, kişisel dersi olmayan ve resmi programı tek birimden gelen öğrencinin programını resmi programdan otomatik doldurur; `tt_official_seed` işareti sayesinde dersler silinse de aynı dönem için tekrarlanmaz. Çoklu birimde mobil birim seçtirir.
- **Yeni uçlar:** `GET /api/timetable/official/status`, `POST /api/timetable/official/apply` (`unit`, `replace`, `force`); yeni hata kodları `OFFICIAL_UNIT_REQUIRED` (422), `OFFICIAL_TIMETABLE_NOT_FOUND` (404). Ders eklemede kod/renk/not/derslik artık zorunlu değil. Ayrıntı: [MOBILE_API_GUIDE.md](MOBILE_API_GUIDE.md) "Resmi programdan kişisel program".

### FINAL-ALL (2026-11-01): backend düzeltme paketleri P01-P10 + panel dalı tek dalda (`deploy/final-all-20261101`)

- **Birleşen paketler (sırayla):** P10 altyapı/test hızı, P01 Redis dayanıklılığı + hız sınırı, P04 bildirim/e-posta, P02 kimlik/oturum + erişim engelleri, P03 sohbet/medya, P05 topluluk/etkinlik, P06 keşfet/gönderi, P07 içerik/destek/arama, P08 akademik/profil, P09 yönetim/çökme/dbmaint. Ayrıntı: `docs/changes/*.md` ("FIX-Pxx" bölümleri), istemci etkisi tablosu [CLIENT_IMPACT_20261101.md](CLIENT_IMPACT_20261101.md).
- **Flyway (yalnız YENİ dosyalar, uygulanmış hiçbiri değişmedi):** V1090, V1092 (sohbet indeksleri), V1100-V1102 (mail kampanya bağı, push SENT indeksi, kampanya ilerleme), V1110-V1111 (etkinlik/topluluk indeksleri), V1120-V1123 (gönderi indeksleri), V1140 (`grade` geriye doldurma), V1141 (hesap silme indeksleri). V1091, V1112, V1130, V1150+ kullanılmadı.
- **İkinci tur (P04 toplu API'sine bağlı kalemler):** üye/katılımcı/kitle bildirimleri istek thread'inden ve açık işlemden çıkarıldı (`FanoutNotifier`, `sendTemplatedBulk`): kulüp yazısı/duyurusu/silme, etkinlik güncelleme/iptal/duyuru, başvuru modu, anket, akademik duyuru, etkinlik hatırlatma. Kulüp satır kilidi artık bildirim boyunca tutulmaz.
- **Geriye uyumluluk (eski mobil 2.0.5/2.0.6):** makbuz/yazıyor varsayılan eski davranış (ayarla kapatılır), oda gönderim sınırı 600/dk, etkinlik açma sınırları varsayılan kapalı, menü yakalama cron'u varsayılan kapalı. Refresh çift istek `409 REFRESH_IN_PROGRESS` ve "99+" sayaç eski istemcide güvenli (kanıt tabloda).
- **Birleştirme düzeltmeleri:** P03 test derleme hatası, P09 panel önbelleği testleri, `AccountDataPurger` yeni sütun kararı, `NewsListPage` en az 3 karakter.
- **Test:** backend 3388 test, 0 başarısız, 6 atlandı (Docker Maven 17, `-Djacoco.skip=true`, 8 dk 18 sn; panel dalı 3079 test); duman: izole PostgreSQL 16 yığınında 41 betik yeşil (Flyway 116 migration temiz uygulandı, son sürüm 1141); web lint/typecheck/vitest (1781 geçti, 3 atlandı)/build/bundle/seo/i18n/contract yeşil; yedek betik öz testleri 97 + 25 OK.
- **Duman betiği düzeltmeleri:** `smoke-crash-reports` (taşma birleştirmesini bekler), `smoke-admin` (analitik önbelleği için 62 sn); ortam koşulları CLAUDE.md "Duman betikleri" bölümünde.
- **OpenAPI:** `docs/openapi.json` yeniden üretildi (+`POST /api/admin/push/campaigns/{id}/resend`, `DELETE /api/devices/{idOrToken}`), web `schema.d.ts` yenilendi.

### FINAL (2026-11-01): iki dağıtım hattının birleştirilmesi

- `deploy/hardened-20261101` (SEO, site içeriği, Drive yedek, 2FA, birim haberleri, HARDEN) ile panel görsel yenilemesi + varsayılan gizli hesap (`app.profile.default-private-account`) + menü kalori/görsel tek dalda (`deploy/final-20261101`) birleştirildi. Flyway sırası V1040 (menü) → V1050 (birim haberleri) → V1060 (2FA); numara çakışması yok.
- Yedekleme (`/admin/backup`), Birim haberleri (`/admin/content/unit-news`) ve İki faktörlü doğrulama (`/admin/two-factor`) sayfaları yeni görsel kite (Insight, StatTile, ResponsiveTable), menü gruplarına (Sistem / İçerik / Kullanıcılar), RBAC izinlerine ve Ctrl+K derin aramasına uyarlandı; kullanıcı listesinde 2FA süzgeci ve çipi.
- `web/bundle-budget.json`: totalJs 770 → 800 KB, `site.*` 23 → 26 KB (gerekçe dosyada).

### Entegrasyon (ENT-ALL): Drive yedek + birim duyuruları + iki faktörlü doğrulama

- **Google Drive yedek (backend/ops):** `scripts/backup/remote-sync.sh` (günde 1 doğrulanmış yükleme, `.partial` -> damga adı, uzak GFS saklama), `prune-local-after-remote.sh` (yalnız Drive'da doğrulanmış yerel yedekleri azaltır, varsayılan kuru çalışma), `GET /api/admin/system/backup` (`BackupReport`, izin `system.read`), `docker-compose.prod.yml` `backup` servisi (`RCLONE_CONF_DIR` ile kalıcı, yazılabilir rclone dizini), [BACKUP_GDRIVE.md](BACKUP_GDRIVE.md). Saatlik yedek yerelde kalır; Drive kopyası en kötü ~24 saat geridir.
- **Yönetim paneli:** `/admin/backup` (durum kartları + adım adım kurulum rehberi; rehber `docs/BACKUP_GDRIVE.md` ile hizalı), `/admin/content/unit-news` (kaynaklar, eşleme, bölümler, duyuru gizle/göster, sağlık özeti), `/admin/two-factor` (özet + tablo), kullanıcı listesinde 2FA sütunu/süzgeci, ayrıntıda gerekçeli kapatma, yönetici girişinde 202 kod adımı ve kalıcı `X-Device-Id`.
- **Birim duyuruları (V1050, `unitnews`):** 23 alt siteden gece çekimi, bölüme göre `GET /api/news/unit`, yönetici uçları `/api/admin/unit-news/**`; sözleşme [UNIT_NEWS_API.md](UNIT_NEWS_API.md). İlk açılışta tablolar boşken ilk doldurma yaklaşık 15 dk sürer.
- **İki faktörlü doğrulama (V1060, `auth.twofactor`, `admin.twofactor`):** e-posta kodu + güvenilen cihaz, `TWO_FACTOR_CODE` e-posta şablonu, yönetici özet/liste/gerekçeli kurtarma kapatması (RBAC `users.read`/`users.write`); sözleşme [TWO_FACTOR_API.md](TWO_FACTOR_API.md). CORS izinli başlıklara `X-Device-Id` eklendi.

### Menü: yemek adına bağlı kalori + içeriğe bağlı görsel (V1040)

- **Kalori:** yönetici bir yemeğe kalori girince değer yemek adına (`menu_dish_calorie`) da kaydedilir; aynı adlı yemek tarihe özel satırı olmayan günlerde (gelecek ay menüsü dahil) otomatik kalorili görünür. Kalori silmek kayıtlı değeri de siler.
- **Görsel:** menü görseli içeriğe (`menu_content_image`, yemek listesinin özeti) bağlıdır: birebir aynı menü aynı görseli alır, menüde en ufak değişiklik olursa görsel düşer ve gün "yeni görsel bekliyor" olur. Bkz. `changes/ops.md`.

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

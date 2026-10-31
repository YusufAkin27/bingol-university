# A18 — Ölü kod ve tekrar denetimi

Kapsam: `mobile/lib`, `backend/src/main`, `web/src`, belgeler. Yöntem: YALNIZ bulgu (kod değiştirilmedi, canlı sunucuya istek atılmadı).
Tarih: 2026-10-31. Çalışma ağacı diğer ajanlarca sürekli değiştiği için mobil analizler `git archive HEAD mobile` ile ASCII yolda (`C:\bu_a18_x\mobile`) alınan temiz kopyada, backend/web analizleri çalışma ağacında yapıldı (backend'de yalnız bir test dosyası değişikti).

## 0. Özet

| Alan | Bulgu |
|---|---|
| Mobil dosya | 7 `lib/` dosyası `main.dart`'tan erişilemiyor (4'ü yalnız testlerde kullanılıyor, 2'si hiçbir yerde, 1'i izlenmeyen bir iskelet dosya) |
| Mobil sembol | ~45 üretimde hiç çağrılmayan üst düzey fonksiyon/sabit/sınıf üyesi (+ ~12 yalnız testlerde kullanılan) |
| Mobil l10n | ARB'de 2736 anahtardan **397'si** kodda hiç geçmiyor (3 dilde; en çok `post*` 100, `profile*` 33, `story*` 25 — kaldırılan Keşfet özellikleri) |
| Mobil varlık/bağımlılık | `pubspec.yaml` varlık listesinde 6 referanssız görsel (~1,3 MB, en büyüğü `logo.png` 1,1 MB); kullanılmayan paket YOK |
| Backend | 8 asla fırlatılmayan hata kodu çevirisi, 2 eski mail anahtarı, 1 bağlanmamış `app.*` ayarı, ~25 çağrılmayan metot, `PostRank/PostScore` yorum bileşeni, kullanılmayan gönderi-video hattı (uç reddediyor ama ~1000+ satır kod/ayar yaşıyor), `HelloController` |
| Web | Üretimden erişilemeyen ~55 dosya (en/ar yönetim sözlükleri 46 dosya + 2 paket ≈ 292 KB yalnız testlerde, tür-tipli API pilotu + 1,27 MB `schema.d.ts`, tek başına `PlaceholderPage`), ~13 kullanılmayan dışa aktarım fonksiyonu, ~50 kesin sahipsiz sözlük anahtarı (+27 dinamik şüpheli), 32 sahipsiz CSS sınıfı; kullanılmayan npm paketi YOK |
| Tekrar | 4 ayrı CSV hücre kaçışı, 2 HTTP Range yazıcı, 3 takip-düğmesi, 8 `*EmptyCard`, 4 `_two()`, 2 süre biçimleyici, tekrar eden sayfalama/yenileme iskeleti, GuardedDialog/GuardedAction |
| Belge | CLAUDE.md'de en az 4 artık yanlış cümle; `POSTS_DESIGN.md`/`MOBILE_API_GUIDE.md` kodda olmayan 410 `FEATURE_REMOVED` uçlarını anlatıyor |

`dart analyze` (HEAD kopyası): 54 info, **0 warning**; `lib/`'te yalnız 2 `prefer_const_constructors` (follow_widgets.dart:418, privacy_data_page.dart:61). Yani analizör kullanılmayan `import`/özel öğe bulmuyor; aşağıdaki bulgular analizörün göremediği **genel (public)** ölü kodlardır.

### Önerilen silme sırası
1. **Mekanik/sıfır risk (mobil):** M1 (erişilemeyen dosyalar), M4 (referanssız varlıklar `pubspec`ten çıkarma), M3 hiç kullanılmayan semboller.
2. **Betikle (3 ARB + `flutter gen-l10n`):** M2'nin "kaldırılmış özellik" grupları (`postCompose*`, `postView*`, `story*`, `p10*`). `p05/p08/p11/p13–p20` önekli anahtarları sürmekte olan yeniden tasarım olabilir — o ajanlar bitince.
3. **Backend küçük temizlik:** B1–B3 (ölü i18n/ayar/metotlar), B4.2–B4.3 (`PostRank/PostScore` yorum bileşeni), B5.1 (`HelloController`).
4. **Web:** W1–W4, W7 (PlaceholderPage, kullanılmayan API fonksiyonları, sahipsiz anahtar/CSS).
5. **Karar gerektiren:** B4.1 (eski bildirim türleri; önce veri temizliği), B7 (gönderi video hattı — önce prod'da `post_media.kind='VIDEO'` satır sayısına bakın), W5 (en/ar yönetim sözlükleri ve `check-i18n` TR_ONLY mantığı), W6 (tür-tipli API pilotu).
6. **Yeniden düzenleme (davranışı koruyarak):** K1–K15; özellikle K1 (CSV kaçışı) ve K2 (Range) güvenlik/tutarlılık açısından önce yapılmalı.
7. **Belge:** D1–D8 (yalnız listelendi).

Derece: **G** = grep/derleyici kanıtı net, silmek güvenli; **O** = silmeden önce küçük doğrulama (test taşıma, veri sorgusu); **R** = dinamik/yansıma/veri riski var.

---

## 1. Mobil (`mobile/lib`)

### M1 — Erişilemeyen dosyalar (içe aktarma grafiği `lib/main.dart`'tan)
Yöntem: kendi yazdığım içe aktarma grafiği betiği (`import`/`export`/`part`), kök `lib/main.dart`; üretilmiş `app_localizations*.dart` erişilebilir.

| ID | Derece | Yer | Kanıt | Eylem |
|---|---|---|---|---|
| M1.1 | G | `lib/features/support/destek_widgets.dart` (83 satır: `DestekCard/Chip/ChipRow/BottomBar`) | Hiçbir `lib/`/`test/` dosyası içe aktarmıyor; sınıf adları dosya dışında 0 geçiş (`grep DestekCard\|DestekChip\|DestekBottomBar` boş) | Sil. l10n'deki `destek*` anahtarları M2'de |
| M1.2 | G | `lib/features/posts/profile_posts_section.dart` (117 satır, `ProfilePostsSection`) | İçe aktaran yok; `grep ProfilePostsSection` yalnız tanım. Canlı karşılığı `features/profile/icerik_user_posts_grid.dart` (tekrar: bkz. K6, 12+12 satır birebir blok) | Sil |
| M1.3 | O | `lib/features/profile/profile_paged_list.dart` (171 satır, `ProfilePagedList`) | `lib/` içinde içe aktaran yok; yalnız **izlenmeyen** `test/redesign/p18_shots_test.dart:15` içe aktarıyor | p18 ajanı bitince sil (testi de güncelle) |
| M1.4 | O | `lib/features/profile/settings_page.dart` (374 satır, `SettingsPage`) | `lib/`'te `SettingsPage` kullanımı yok; yalnız testler: `back_navigation_test.dart:193`, `crash_reporter_test.dart:179`, `l10n_test.dart:100,116`, `pages_c_test.dart:127,455,475`. Ayarlar artık `account_security_page`/`notification_prefs_page` üzerinden; `_logoutAll` ve `_pickLang` kopyaları da burada (K7) | Testleri canlı ekrana taşıyıp sil; l10n/çökme-raporu ayarı için canlı ekranı doğrula |
| M1.5 | O | `lib/widgets/academic_picker.dart` (216 satır, `AcademicFields`) | Üretimde içe aktaran yok (canlı olan `academic_pickers.dart`: `auth_academic.dart:5`, `edit_profile_page.dart:8`). Yalnız `test/academic_test.dart:8,40,98,221` | Testi `AuthAcademicFields`/`academic_pickers`e taşıyıp sil (K5) |
| M1.6 | O | `lib/core/push/push_channels.dart` (35 satır, `pushChannels`, `channelForType`, `PushChannel`) | `lib/` içinde içe aktaran yok; yalnız `test/push_foreground_test.dart:5,20-21`. Gerçek kanal eşlemesi `push_service.dart`/Android kanal kodunda ayrı yaşıyorsa bu dosya yanıltıcı ikinci kaynak | Üretim kanal tanımıyla birleştir ya da sil |
| M1.7 | G | `lib/features/chat/media_source_sheet.dart` (**izlenmeyen**, 2 satır yorum: "Kaldırıldı (N2)… silinebilir") | `git status`: `??`; içeriği yalnız yorum | Başkasının dosyası: N2 sahibi silsin / commit'lemesin |

### M2 — Kullanılmayan l10n anahtarları (ARB)
Yöntem: `app_tr.arb` anahtarı (2736; en/ar ile birebir aynı küme) `lib/` (l10n hariç) içinde belirteç olarak 0 kez geçiyor; `test/`'te de 0. Üretilmiş `app_localizations*.dart` ARB'den üretildiği için ARB'yi temizleyip `flutter gen-l10n` yeterli. Dinamik erişim riski yok (gen-l10n alıcı metotları statik; dizeyle anahtar araması mümkün değil) → derece G, **yalnız** aşağıdaki "devam eden iş" notu hariç.

| ID | Derece | Önek (adet) | Kanıt / not | Eylem |
|---|---|---|---|---|
| M2.1 | G | `postCompose*` ve `postView*` (**100**) | Kaldırılan Keşfet özellikleri: yorum, yanıt, kaydet, beğenenler, video, #etiket (`postViewReplyingTo`, `postViewCommentsWithCount`, `postViewSavedPostsTitle`, `postComposeVideo*`, `postComposeTagAdd`…) | Sil (3 ARB) |
| M2.2 | G | `story*` (**25**) | Hikâye kaldırıldı (V470). `storyCreateTitle`, `storyViewersTitle`… | Sil |
| M2.3 | G | `profile*` (33), `profilePrefs*` (içinde `…NotifStories/Mention/Comment/Reply/Like/Follow` bildirim satırları), `profilyard*` (6), `profil1*` (4), `profil2BlockedHint` | Eski profil/ayar tasarımı | Sil |
| M2.4 | G | `akademik2*` (16), `acad*` (6), `etkinlik2*` (15), `event*` (14: `eventForm*`, `eventList*`), `chat*` (13), `home*`/`anasayfa*` (15), `discover*`/`kesfet*` (14), `auth*` (10), `menu*`/`yemek*` (9), `cevrimdisi*` (6), `kulupdetay*` (5), `icerik*` (5), `destek*` (5), `support*`/`supportLabelMine` (7), `club*` (5), `poll*`/`anket*` (7), `notif*`/`bildirim*` (4), `welcome*` (3), `sohbetmedya*` (3), `sohbety*` (2), diğer tekil: `commonOpenInStore`, `configError`, `coreOffline`, `coreMaintenance`, `settingsCrashReportsDesc`, `newsOpenSource`, `authLangTitle`, `authTrustSecure` | Yeniden tasarımla bırakılmış eski dizeler | Sil |
| M2.5 | O | `p04*,p05*,p08*,p10*,p11*,p13*,p14*,p15*,p16*,p17*,p20*` (**~55**) | `p10*` (16) kaldırılan `media_source_sheet` ("Kaynak sheet" N2) dizeleri; ama `p08/p11/p13/p14/p18` izlenmeyen ekran-görüntü testleri çalışma ağacında yeni — bazı `p*` anahtarlar henüz bağlanmamış **devam eden iş** olabilir | `p10*` sil; diğerlerini yeniden tasarım ajanları bitince tekrar tara |

Tam liste: HEAD kopyasında 397 anahtar. Yeniden üretme: `app_tr.arb` anahtarlarını çıkar → `lib/` (l10n hariç) Dart belirteç sayacı 0 olanlar. `scripts/i18n-audit.js` yalnız yerelleştirilmemiş dizeleri bulur, bunun tersini yapmaz — ona bir `--unused-keys` seçeneği eklenmesi önerilir (betik 40 satır). Tahmini kazanç: tr ARB ~19 KB, ×3 dil + üretilmiş Dart (`app_localizations.dart` 473 KB'ın bir kısmı).

### M3 — Üretimde çağrılmayan semboller
Yöntem: bildirimde geçen belirteç `lib/` genelinde **yalnızca tanım satırında** (dize enterpolasyonu `$ad` dahil sayıldı). Çerçeve geçersiz kılmaları (`didPush`, `createRenderObject`, `performLayout`…) ve widget çağrıları (`MobileScanner(`) elendi.

Hiç kullanılmayan (test dahil 0), derece **G**:

| Yer | Sembol |
|---|---|
| `core/academic_catalog.dart` | `:157 facultyByName`, `:166 departmentByName`, `:197 gradeNameL` |
| `core/error_log.dart:140` | `readFile` |
| `core/locale_controller.dart:59` | `deviceLocalesChanged` (hiçbir `didChangeLocales` çağırmıyor; "sistem dili" izleme elle bağlanmamış — işlev kaybı olabilir, silmeden önce kontrol edin: **O**) |
| `core/notify/local_reminders.dart:193` | `unregisterProvider` |
| `core/realtime/chat_realtime.dart:262` | `watchPresence` |
| `core/theme.dart:13-15` | `red700`, `red800`, `red100` |
| `core/theme/bu_space.dart` | `xxs`, `xxxl`, `huge`, `h32`, `h48`, `w20`, `w24` |
| `features/academic/academic_api.dart:81` | `markRead` |
| `features/academic/academic_models.dart` | `:51 dayNames`, `:52 dayShort`, `:75 dayNameL`, `:112 colorLabel`, `:126 colorLabelL`, `:487 eventKindLabel`, `:579 fmtWallDate` |
| `features/academic/akad_widgets.dart:580` | `akadHeaderAction` |
| `features/academic/reminders.dart:62` | `acadLongDate` |
| `features/chat/chatd_parts.dart:14` | `chatdBottomShade` |
| `features/chat/message_placeholder.dart:27` | `isPlaceholderMessage` |
| `features/chat/sohbety_widgets.dart:12` | `sohbetyShadow` |
| `features/clubs/club_actions.dart:99` | `dangerItemStyle` |
| `features/clubs/kulup_widgets.dart` | `:68 kulupMenuShape`, `:110 kulupField` |
| `features/events/etkinlik2_widgets.dart:673` | `et2Name` |
| `features/events/etkinlik_parts.dart:8` | `etkinlikToneOf` |
| `features/events/event_parts.dart:8` | `eventMonthShort` |
| `features/polls/anket_style.dart` | `:36 anketText`, `:118 anketCardDeco` |
| `features/posts/post_api.dart:57` | `unlike` (kaldırılan/yerine `like` toggle? — `PUT/DELETE like` kullanımına bakın: **O**) |
| `features/profile/profil_widgets.dart:10` | `profilBlue` |
| `features/support/support_common.dart:18` | `supportTicketCategoryIcons` |
| `widgets/bu_widgets.dart:929` | `kBrandRed` |
| `widgets/sistem_widgets.dart:15` | `radioOff` |

Yalnız testlerde kullanılan (üretim ölü, test köprüsü), derece **O**: `core/api.dart:251 getSwr`, `academic_catalog.dart:175 searchFaculties`, `connectivity_service.dart:21 lastStaleAt`, `permission_service.dart:98 willAnswer`, `active_conversation.dart:20 openId`, `push_service.dart:72 showPushBanner`, `academic_models.dart:429 countdownText`, `:573 fmtInstant`, `auth_widgets.dart:9 validateEmail`, `chat_media.dart:31 galleryAttachments`, `:55 attachmentPreviewLabel`, `media_crop/crop_controller.dart:51 panBy`, `polls/poll_parts.dart:186 elapsedFraction`, `widgets/bu_overlays.dart:118 BuConfirmSheet`. Not: `debugSet/debugEmit*/resetLimiter` bilinçli test kancalarıdır, dokunmayın.

Eylem: G listesini sil, `dart analyze` + `flutter test` ile doğrula. Test-köprülü olanlarda ya testi canlı yola çevirin ya da üretimden kaldırıp test yardımcısına taşıyın.

### M4 — Varlıklar ve bağımlılıklar
| ID | Derece | Yer | Kanıt | Eylem |
|---|---|---|---|---|
| M4.1 | G | `pubspec.yaml` varlıklar: `assets/branding/logo.png` (1,1 MB), `logo_horizontal.png`, `logo_horizontal_dark.png`, `mark.png`, `mark.svg`, `mark_white.png` | `grep branding/` yalnız `mark_white.svg` (`widgets/bu_widgets.dart:922`) ve `default_avatar.png`/`default_group.png` (lib + testler). Diğer 6'sı `lib/` ve `test/`'te yok | `pubspec.yaml` `assets:` listesinden çıkar (dosyalar `tool/make_icon_from_logo.js` girdisi `logo.png` olarak kalabilir ya da `tool/` altına taşınır → APK ~1,3 MB küçülür) |
| M4.2 | O | Kök `logo.png` (izlenen) | `md5sum` `mobile/assets/branding/logo.png` ile **aynı** (68bcf471…) | Birini sil/taşı |
| M4.3 | O | `mobile/design/*.dc.html` (48 izlenen dosya, son değişiklik 2026-10-26) | `docs/MOBILE_UI.md:24` ve CLAUDE.md "tasarım şablonları" diyor; 2026-10-30'da Stitch yeniden tasarımı 51 grubu Flutter'a aktardı | Güncel mi kontrol edin; değilse `docs/design/` arşivine al, CLAUDE.md cümlesini düzelt |
| M4.4 | — | `pubspec.yaml` bağımlılıkları | Her paket `lib/`'te içe aktarılıyor (kontrol edildi: 24 paket); `video_player_platform_interface` yalnız `dev_dependencies` + testler, `flutter_launcher_icons` araç | Kullanılmayan paket yok |

---

## 2. Backend

### B1 — Hiç fırlatılmayan hata kodları / eski mesaj anahtarları (i18n)
Yöntem: 632 varsayılan anahtar için `"ANAHTAR"`/`error.KOD` dize ve `Kod` aranması; dinamik oluşturulanlar (`mail.tpl.*`, `mail.unsub.*`, `notif.news.many.<tür>`, `mod.reason.<KOD>`, `profile.complete.*`, `status.maintenance.<kaynak>`) tek tek koddan doğrulandı ve **elendi**.

| ID | Derece | Yer | Kanıt | Eylem |
|---|---|---|---|---|
| B1.1 | G | `i18n/post.properties:4` `error.POST_TOO_LONG` (+`_en`,`_ar`) | Kodda yok (`grep POST_TOO_LONG src/main/java` boş); `docs/POSTS_DESIGN.md:12` "Eski POST_TOO_LONG artık üretilmez" | Sil (3 dosya) |
| B1.2 | G | `i18n/messages.properties:24` `error.UNSUPPORTED_LANGUAGE`, `:61` `error.TURKISH_CONTENT_REQUIRED` | Kodda yok | Sil (3 dosya) |
| B1.3 | O | `messages.properties:259-262,264` `error.DECRYPT_REASON_REQUIRED`, `DECRYPT_RANGE_INVALID`, `DECRYPT_TOO_MANY`, `MESSAGE_READER_UNAVAILABLE`, `CRYPTO_DECRYPT_FAILED` | Backend hiçbir yerde üretmiyor; **ama** web `i18n/tr/admin-safety.ts:192-194` bu kodları çeviriyor (yanıltıcı) | Backend anahtarlarını ve web `admin.err.DECRYPT_*` satırlarını birlikte sil; admin çözme yolunun şimdiki kodlarıyla (`ADMIN_DECRYPT_DISABLED` vb.) uyumunu doğrula |
| B1.4 | G | `messages.properties:66-67` `mail.verification.subject/body`, `:338-339` `mail.reset.subject/body` | Mail artık `mail.tpl.<anahtar>.*` (`MailRenderer.java:59`); eski anahtarlara kodda referans yok | Sil (3 dosya) |

### B2 — Bağlanmamış yapılandırma
| ID | Derece | Yer | Kanıt | Eylem |
|---|---|---|---|---|
| B2.1 | G | `application.properties:297` `app.dbmaint.log-days=${DBMAINT_LOG_DAYS:90}` | Hiçbir `@Value`/`@ConfigurationProperties` okumuyor (`grep dbmaint.log-days` yalnız tanım + `docs/audit/A8…`). `DbMaintenanceJob.java:52-62` diğer `app.dbmaint.*` anahtarlarını okuyor | Sil **ya da** gerçekten `profanity_hit_log` saklamasına bağla (A8-16 "silinmez" bulgusu: ayar var görünüp işlevsiz) |
| B2.2 | O | `app.post.media.video-max-bytes/-max-seconds/max-videos-per-post`, `app.post.media.max-per-post=10` (`application.properties:194-199`) | Gönderi tek fotoğraf; `PostMediaController.java:43-45` videoyu reddeder; `max-per-post` 10 ama `requireImage` tam 1 ister (`PostMediaService.java:316`) | B7 ile birlikte kaldır |
| B2.3 | R | `app.media.transcode.*` (`TranscodeProperties`), `app.media.cdn.*` | Yalnız gönderi videosu dönüştürme/CDN yoluna bağlı (B7). Sohbet videosu ayrı yol (`MessageAttachmentService`) | B7 kararına bağlı |

Not: diğer ~330 `app.*`/ortam anahtarının tümü `@ConfigurationProperties` bileşenine ya da `@Value` yer tutucusuna bağlı (betik: `NO-BINDING` yalnız yukarıdaki).

### B3 — Çağrılmayan metotlar
Yöntem: yöntem adı `src/main` genelinde yalnız tanım satırında (`@Override`, `@Scheduled`, `@EventListener`, mapping, `@Autowired` seçimli setter'lar elendi). Test sütunu = `src/test`'te kullanım adedi.

| Yer | Metot | Test | Not |
|---|---|---|---|
| `accessban/AccessBanRepository.java:24` | `findLiveValues` | 0 | Spring Data/JPQL; sil |
| `accessban/AnonymizerRangeRepository.java:8` | `findByCidr` | 0 | sil |
| `accessban/AccessBanCache.java:64` | `isExempt` | 0 | sil |
| `community/CommunityMember.java:26` | `atLeastModerator` | 0 | sil |
| `community/category/CommunityCategoryRepository.java:15` | `countByActiveTrue` | 0 | sil |
| `community/permissions/ClubOwnershipTransferRepository.java:22` | `findByCommunityIdAndStatusIn` | 0 | sil |
| `event/admission/EventAdmissionService.java:789` | `configOf` | 0 | sil |
| `media/MediaService.java:139` | `utf8` | 0 | sil |
| `media/PrivateMediaStore.java:361` | `diskSize` | 0 | sil |
| `media/transcode/PostMediaTranscodeRepository.java:83` | `countPlainVideos` | 0 | B7 |
| `media/transcode/TranscodeWorker.java:126,130` | `doneCount`, `failedCount` | 1 / 0 | B7 |
| `messaging/room/ChatRoomLinkRepository.java:49` | `findByKind` | 0 | sil |
| `moderation/StrikeService.java:105` | `userOf` | 0 | sil |
| `notification/QuietHours.java:17` | `validMinute` | 0 | sil |
| `notification/outbox/PushOutbox.java:104` | `markCancelled` | 0 | iptal durumu hiç atanmıyor; `PushOutboxService.java:104 enqueueForUser` (test 1) da çağrılmıyor |
| `poll/PollBallotRepository.java:15` | `findByPollIdAndUserId` | 0 | sil |
| `poll/PollRepository.java:100` | `addVoters` | 0 | RL1b "atomik sayaç" sonrası artık |
| `poll/PollViewAssembler.java:201` | `idsOf` | 0 | sil |
| `poll/Poll.java:125` | `isVotingOpen` | 0 | sil |
| `post/follow/FollowService.java:261` | `dropBetween` | 0 | engelleme sonrası takip düşürme için tasarlanmış ama bağlanmamış olabilir — **O**: engelleme akışında takibin gerçekten düştüğünü doğrulayın |
| `post/like/PostLikeService.java:127` | `listLikers` (test 5) | 5 | "Beğenenler" ucu kaldırıldı; yalnız testler çağırıyor |
| `support/feedback/FeedbackRepository.java:32` | `countByUserIdAndCreatedAtAfter` | 0 | sil |
| `user/UserRepository.java:22,28` | `audienceAll`, `audienceClassYear` | 0 | kampanya hedef kitlesi başka sorguyla; sil |
| `mail/MailService.java:143,155` | `sendAccountDeleted`, `sendAnnouncement` | 1 / 2 | Yalnız testler; şablonlar (`mail.tpl.deleted/announcement`) canlı mı? Canlı değilse şablon anahtarları da B1'e |
| `admin/rbac/PermissionMatrix.java:127,137` | `allPermissions`, `isKnown` | 1 / — | yalnız test |
| `catalog/CatalogService.java:72` | `facultyNames` | 1 | yalnız test |
| `media/PostVideoCipher.java:99` | `sealedSize` | 1 | B7 |
| `moderation/profanity/ProfanityFilter.java:44,115` | `builtInOnly`, `builtInLines` | 4 / 8 | yalnız test |

Derece: Repository/`private`/yardımcı satırları **G**; test-köprülü olanlar **O**. Tamamı için `QueryRulesTest`, `RbacCoverageTest`, `OpenApiExportTest` etkilenmez (Spring Data türetilmiş sorgular yalnız tanım olarak duruyor).

### B4 — Kaldırılmış özellik (yorum/hikâye/#etiket/@bahsetme) kalıntıları
| ID | Derece | Yer | Kanıt | Eylem |
|---|---|---|---|---|
| B4.1 | R | `notification/NotificationType.java:9,11`, `NotificationSubtype.java:13-15`, `PushMessages.java:54,68`, `NotificationService.java:350` — `POST_COMMENT`, `COMMENT_REPLY`, `POST_MENTION` | Üreten kod yok. `docs/changes/post.md:130` bunları **bilerek** bıraktığını söylüyor ("mevcut bildirim satırları okunabilsin"); V470 `notification` satırlarını silmiyor → enum silinirse eski satırlar `IllegalArgumentException` verir. Web yönetici de listeliyor (`web/src/api/adminPushOps.ts:19-21`, `admin-p09.ts:88-90`) | Önce `DELETE FROM notification WHERE type IN (…)` + `push_outbox` temizliği migration'ı, sonra enum. Aksi halde dokunmayın |
| B4.2 | O | `post/PostRank.java:21-24`, `PostRankProperties.java:21 commentWeight`, `PostScore.java:8-9` | Tüm çağrılar yorum sayısına **0** geçiyor (`PostRankService.java:59,97`, `PostScoreJob.java:52`). Testler (`PostRankTest.java:15`, `PostServiceTest.java:272`) yorum bileşenini sınıyor | `comments` parametresi + `comment-weight` kaldır, testleri sadeleştir |
| B4.3 | G | `i18n/post_en.properties:16,21` yorum satırlarında "save, mention, follow, story" başlıkları | Yalnız yorum | Düzelt |
| B4.4 | G | `scripts/smoke-posts.sh:145-147`, `scripts/smoke-post-social.sh:89-96` | Kaldırılan uçların **404** beklediği testler (yararlı gerileme koruması). `docs/POSTS_DESIGN.md:10` ise 410 diyor → belge/kod çelişkisi (D1) | Sakla |

### B5 — Diğer
| ID | Derece | Yer | Kanıt | Eylem |
|---|---|---|---|---|
| B5.1 | G | `health/HelloController.java` (`GET /api/hello`) | Hiçbir istemci/betik/belge çağırmıyor (web, mobil, scripts, docs `grep /api/hello` boş); `RbacCoverageTest`/OpenAPI'de görünür | Sil (sağlık için `/actuator/health` var) |
| B5.2 | — | `@Scheduled` görevleri (44) | Hepsi bir bean üstünde; bağlanmamış/ölü görev bulunmadı | — |
| B5.3 | — | Ölü sınıf | Kullanılmayan (bean olmayan) sınıf yok; bean-benzeri sınıf adı tek geçen 19 dosya (Exporter/Config) Spring tarafından bulunuyor | — |

### B7 — Gönderi video hattı (tasarımca kapalı ama kod+ayar yaşıyor)
| ID | Derece | Yer | Kanıt | Eylem |
|---|---|---|---|---|
| B7.1 | R | `post/media/PostMediaService.java` `uploadVideo` (:179), `readVideo` (:252), `isVideoUpload`, video limit alanları (:78-89), `writeVideo` (~:500); `media/PrivateMediaStore.storeVideoSealed/Plain`, `media/PostVideoCipher`, `media/transcode/*` (10 dosya, ~1008 satır: `TranscodeService/Worker`, `VideoTranscoder`, `AdminTranscodeController`, `PostMediaCdnController`, `MediaCdn*`), `app.media.transcode.*`, `app.media.cdn.*`, `app.post.media.video-*` | Yükleme ucu videoyu reddeder (`PostMediaController.java:43-45`; `requireImage` `:316-326`). `PostMediaService.upload(…)` yalnız `DevSeedRunner.java:264` (PNG) çağırıyor. Yorum bile söylüyor: "servis eski kayıtlar/testler için video yolunu korur" (`:331`). Feed zaten videoyu gizliyor | **Veri kararı**: prod'da `SELECT count(*) FROM post_media WHERE kind='VIDEO'`. 0 ise yükleme+dönüştürme hattını, yoksa yalnız yükleme/dönüştürme tarafını kaldırıp servis (Range yazıcı) bırakın. Sohbet videosu (`MessageAttachmentService`) ayrı ve canlı — dokunmayın |

---

## 3. Web (`web/src`)

Yöntem: Vite/TS içe aktarma grafiği (`main.tsx` kökü; `import()`/`new URL` dahil), dışa aktarım adı sayacı, sözlük anahtarı + dinamik önek taraması, CSS Modules sınıf taraması, `package.json` denetimi. `knip`/`ts-prune` yerelde kurulu değil, ağ kurulumu yapılmadı; yerine kendi betiklerim kullanıldı.

| ID | Derece | Yer | Kanıt | Eylem |
|---|---|---|---|---|
| W1 | G | `src/components/PlaceholderPage.tsx` | Hiçbir yerden içe aktarılmıyor (ilk commit'in iskeleti, `3c4f80c`) | Sil |
| W2 | G | Kullanılmayan dışa aktarımlar (tanım dışında sıfır geçiş): `api/auth.ts:30 getMe`, `api/support.ts:13 getTicket`, `api/faq.ts:7 listFaqAdmin`, `api/modAdmin.ts:126 listUserStrikes`, `api/settings.ts:12-13 triggerNewsSync/triggerMenuSync`, `api/users.ts:33 getBasicStats`, `api/adminMail.ts:204 updateMailCampaign`, `components/LocalizedLink.tsx:41 useLocalizedNavigate`, `pages/admin/clubs/clubsLogic.ts:24 isOwner`, `pages/admin/pushops/lib.ts:60 sumGroups`, `api/academic.ts:87`/`api/adminChat.ts:191`/`pages/admin/users/filters.ts:4` (yalnız tür adları) | Betik çıktısı (own=1, test=0) | Sil; `check:contract` etkilenmez |
| W3 | G | Yalnız test kullanan dışa aktarımlar: `adminNav.ts:160 allAdminNavItems`, `chatReason.ts:45,62`, `events/lib.ts:37 filterEvents`, `modLogic.ts:91 shortHash`, `accessbans/logic.ts:81 shortDevice`, `analytics/transform.ts:118 truncate`, `posts/postsLogic.ts:72 postStatus`, `supportLogic.ts:14 nextTicketStatus`, `seo/routeMeta.ts:117 matchRouteMeta`, `InfoPage.tsx:23 infoKeys`, `DeleteAccountPage.tsx:27 deleteTableKeys`, `ReasonField.tsx:20 reportTemplatesToOptions` | Test sütunu >0 | Üretimde çağrılmıyor; testler yeniden yazılabilir ya da bırakılır |
| W4 | G/R | Sahipsiz sözlük anahtarları (tr; 4971 anahtardan **77**) | Dinamik önek eşleşmeyenler. **G (≈50):** `admin.ab.att.{at,ip,path}`, `admin.ab.bulk.empty`, `admin.events.filterNote`, `admin.events.pendingRequestsLabel`, `admin.legal.leaveConfirm`, `admin.legal.publish.irreversible`, `admin.faq.delete.body`, `admin.ds1.tables.error`, `admin.ds1.history.error`, `admin.reports.preview.{target,loading}`, `admin.p08.state.{HIDDEN,DELETED}`, `admin.p08.bulk.{limit,selectMode,selectModeOff}`, `admin.p08.export.disabled`, `admin.p15.select.limit`, `admin.p16.me.profile`, `admin.p16.admins.next`, `admin.pend.col.select`, `admin.posts.{close,author,detail.error}`, `admin.reports.ctx.feedMedia`, `admin.settings.{maintenance,storeLinks}`, `admin.audit.col.{action,at,method,path}`, `admin.audit.filter.q`, `admin.audit.empty.{title,hint}`, `admin.nav.groupToggle`, `admin.layout.topbar`, `admin.tickets.detail.userId`, `admin.feedback.{from,noChange}`, `admin.users.col.email`, `admin.users.detail.back`, `admin.users.actions.suspend.reasonRequired`, `admin.users.actions.delete.typeEmail`, `admin.wp02.audit.{openRow,exporting}`, `admin.login.brandLine`. **R:** `admin.*.err.<KOD>` (cr1, ds1, p09, p14 — `td('…err.'+code)` ile dinamik aranır, `lib/errors.ts:11`, `events/errors.ts:10` gibi) ve `seo.privacy.l1-l5` (önrender kodu dinamik kurabilir) | Tek tek kontrol edin; en/ar karşılıkları varsa üç dilde sil |
| W5 | O | `src/i18n/en/admin-*.ts` (23) + `src/i18n/ar/admin-*.ts` (23) + `bundles/admin.en.ts`, `bundles/admin.ar.ts` — **292 KB**, `all.ts` ve `seo/prerender.ts` | Üretimde yalnız `admin.tr` yüklenir (`registry.ts:23`, "Yönetim paneli yalnız Türkçedir"); en/ar yönetim paketleri yalnız `all.ts` (testler/önrender) üzerinden içe aktarılıyor; ayrıca `check-i18n.mjs` TR_ONLY listesi ile paritesi zorlanıyor. Not: proje kararı "admin yalnız Türkçe" (bellek notu) | Paritesiz kalacaksa en/ar admin dosyalarını ve parite denetimini kaldırın; `all.ts` yalnız site sözlüklerini + `admin.tr` birleştirsin. Karar gerekir (tür bütünlüğü gerekçesi yazılı) |
| W6 | O | `src/api/typed/*` (88+13+5+5 satır), `src/api/generated/schema.d.ts` (**1,27 MB**), `gen:api` betiği | `adminSettingsTyped.ts`, `appInfoTyped.ts`, `adminUsersTyped.ts` (yalnız `typed.test.ts`) hiçbir sayfada kullanılmıyor — "örnek tip güvenli modül" pilotu; `schema.d.ts` yalnız bunlara besleniyor | Ya yaygınlaştırın (sözleşme güvencesi) ya kaldırın; `check:contract` zaten openapi karşılaştırıyor |
| W7 | G | 32 sahipsiz CSS sınıfı (1657 sınıftan; 101 modül, hepsi içe aktarılıyor): `layouts/SiteLayout.module.css: adminLink`; `accessBans: kindPick`; `analytics: loading`; `campaigns: rowActions`; `chat: searchRow`; `clubs: dlRow`; `dashboard: chartLoading`; `mail: rtlField, mono`; `menu: items`; `polls: spacer, section`; `posts: reply, dim`; `settings: hintLine`; `users: topActions, heroName, dangerZone, modalForm`; `LegalPage: skip-link`; ayrıca (dinamik adlandırmayla çağrılanlar R) `Button: icon-md/icon-sm`, `shared: counter-warn/-over`, `moderation: thumb, warnBox`, `BrandPage: bad_*`, `site: ruled` | Betik: `styles.ad` / `styles['ad']` eşleşmesi yok | G olanları sil; R (`styles[...]` dinamik indeks) olanları önce kontrol |
| W8 | — | npm bağımlılıkları | 5 çalışma + 24 geliştirme paketinin tümü içe aktarma/yapılandırma/betikte kullanılıyor (`@types/*`, `@vitest/coverage-v8` komut satırı üzerinden). `src/components/admin/guard/README.md` kaynak ağacında bir belge | Kullanılmayan paket yok |
| W9 | — | `public/` | `brand/*.png|svg` `BrandPage.tsx:139,151` dinamik; `fonts`, ikonlar manifest/`index.html`'den | Referanssız dosya yok |

---

## 4. Belgelerde artık geçersiz bölümler (yalnız listeleme)

| ID | Yer | Sorun |
|---|---|---|
| D1 | `docs/POSTS_DESIGN.md:10-14` (güncel sözleşme kutusu); `docs/MOBILE_API_GUIDE.md:676`; `docs/changes/post.md:76` | Kaldırılan uçların kalıcı **410 `FEATURE_REMOVED`** döndüğünü ve `PostView`'in `commentCount/savedByMe/mentions/hashtags` taşıdığını söylüyor. Kodda `RemovedFeatureController` **yok** (`git log -S`: e8cee9d'de eklenmiş, 185725f'de silinmiş; `grep FEATURE_REMOVED backend/src` boş); `docs/changes/post.md:129-130` zaten "silindi, alanlar kalktı" diyor. Gerçek davranış: 404 (`smoke-post-social.sh` 404 bekler). CLAUDE.md `post` satırı doğru ("uçlar yok/404") |
| D2 | `docs/POSTS_DESIGN.md:16` ve devamı | "Yorum/hikâye/kaydet/etiket tabloları ve verileri korunur" — V470 tabloları **düşürdü**. Yorum/hikâye/#etiket bölümleri (`POSTS_DESIGN.md:64 Yorum ve yanıt`, `MOBILE_API_GUIDE.md:705 Yorum ve yanıt (iç içe)`, 22 "yorum" geçişi) tarihsel; `docs/API_CONTRACTS_V2.md:257` güncelleme notuyla kısmen işaretli |
| D3 | `CLAUDE.md` §1 `config` satırı ve §8 "Bilinen sınırlamalar" | "`@Scheduled` görevleri henüz sarmalanmadı / `SchedulerLock` ile henüz sarmalanmamıştır" — 16 kaynak dosya `SchedulerLock` kullanıyor; `docs/DEPLOY.md:172` zaten "`AccessBanRetentionJob`… `SchedulerLock` ile çok örnekte tek çalışır" diyor |
| D4 | `CLAUDE.md` §8 son madde | "Uygulama içi EN/AR çeviri henüz yok" — `app_en.arb`/`app_ar.arb` 2736 anahtarla tam, `docs/I18N_MOBILE.md` mimariyi anlatıyor; `I18N_MOBILE.md` içi "Yapıldı (ilk dalga) / Kalan iş listesi" bölümü de eski |
| D5 | `CLAUDE.md` §1 mobil satırı + `docs/MOBILE_UI.md:24` | `mobile/design/*.dc.html` şablonlarına referans; 2026-10-26'dan beri değişmedi, Stitch yeniden tasarımı sonrası geçerliliği belirsiz (M4.3) |
| D6 | `docs/ADMIN_API.md` (6 "hikâye", 6 "yorum", 6 "video" geçişi) | Kaldırılmış özelliklerin yönetici uçları (hikâye/yorum moderasyonu) hâlâ anlatılıyorsa kaldırılmalı — bölüm bölüm doğrulanmadı |
| D7 | `docs/MOBILE_PAGES.md` (725 satır, 2026-10-26), `docs/MVP.md`, `docs/WORK_PLAN.md`, `docs/AGENT_BRIEF_COMMON.md`, `docs/AGENT_RULES_V2.md`, `docs/API_CONTRACTS_V2.md` | Tek seferlik plan/ajan brifingi nitelikli; yeniden tasarım sonrası güncel değil. Arşive (`docs/archive/`) alınması önerilir; CLAUDE.md "İlgili belgeler" listesinde yalnız `MVP.md` var |
| D8 | `docs/PERF.md` ile `docs/PERFORMANCE.md`; `docs/BACKUP.md` ile `docs/BACKUP_RESTORE.md`; `docs/SECURITY_AUDIT.md` ile `SECURITY_AUDIT_2026-10-28.md` | Çift/üst üste belgeler; birleştirme adayı |

(Not: `docs/audit/A17-belge-kod-ve-api-sozlesmesi.md` belge/kod uyumunu ayrıca inceliyor; çakışmada A17 esas alınmalı.)

---

## 5. Kopya (tekrarlanan) mantık

Yöntem: normalleştirilmiş 6 satırlık pencere eşleştirmesi (mobil, backend, web) + aynı adlı yardımcıların taraması. Blok düzeyinde tekrar düşük (mobil ≥25 satırlık eşleşme yok), asıl tekrar **aynı işi yapan paralel yardımcı/sınıf** düzeyinde.

| ID | Alan | Yer | Kanıt | Birleştirme önerisi |
|---|---|---|---|---|
| K1 | Backend / **güvenlik** | CSV hücre kaçışı **4 kopya**: `admin/Csv.java:15` (kanonik), `event/AttendanceService.java:~202`, `moderation/profanity/ProfanityAdminController.java:~229`, `poll/PollAdminService.java:~162` | Hepsi `"=+-@\t\r"` ön ek kuralını ayrı yazıyor; davranışları farklı (biri her zaman tırnaklar, biri yalnız gerekince) | Tümü `Csv.cell/row`'a; CSV enjeksiyonu kuralı tek yerde (CLAUDE.md güvenlik 10) |
| K2 | Backend | HTTP Range (`HttpRange.parseRanges` → 206/416) gövdesi: `messaging/media/MessageAttachmentService.writeVideo` (:526) ve `post/media/PostMediaService.writeVideo` (:500); 19 satır birebir | Aynı iskelet, yalnız varlık tipi farklı | `common/web/RangeResponses` ortak yardımcı (B7 kararıyla biri düşebilir) |
| K3 | Backend | CSV akış kabuğu (`Content-Type text/csv`, `Content-Disposition`, `Cache-Control: no-store`, `res.reset()` hata mantığı): `admin/bulk/AdminBulkController.stream` ve `event/admin/EventAdminOpsController`, `moderation/admin/ModerationExportController`, `support/admin/SupportExportController` (16–17 satır eşleşme); toplam 11 dosya `CONTENT_DISPOSITION` yazıyor | `text/csv` geçen 9 denetleyici | `CsvResponse.stream(res, filename, target, body)` |
| K5 | Mobil | Akademik seçici mantığı **3 kopya**: `_gradeName`, `_pickDepartment`, `_pickGrade`, `_openable` → `auth/widgets/auth_academic.dart:33-61`, `profile/edit_profile_page.dart:401-430`, `widgets/academic_picker.dart:40-66` (+ `widgets/academic_pickers.dart` ortak seçiciler) | Aynı ad ve gövde | `academic_pickers.dart` altında tek `AcademicSelection` denetleyicisi; `academic_picker.dart` silinir (M1.5) |
| K6 | Mobil | Gönderi ızgarası: `posts/profile_posts_section.dart:73,100` ↔ `profile/icerik_user_posts_grid.dart:88,117` (12+12 satır) | Ölü kopya (M1.2) | Silmek yeter |
| K7 | Mobil | `_logoutAll`: `profile/account_security_page.dart:121` ↔ `profile/settings_page.dart:75` (10 satır); `_pickLang`: `profile_tab.dart:136` ↔ `settings_page.dart:125` | settings_page ölü (M1.4) | settings_page silinince biter |
| K8 | Mobil | **3 takip düğmesi**: `follow/follow_button.dart` (`FollowButton`), `follow/follow_widgets.dart:240` (`FollowRowButton`), `profile/profily_widgets.dart:200` (`ProfilyFollowButton`) — aynı iyimser `api.follow/unfollow` + hata geri alma + haptic (22 satır birebir: `follow_widgets.dart:258` ↔ `profily_widgets.dart:218`) | Üç ayrı `_toggle` | Tek `FollowToggleController` (mixin) + 3 görsel varyant |
| K9 | Mobil | Boş durum kartları: `AcadhubEmptyCard`, `DiscoverEmptyCard`, `EtkinlikEmptyCard`, `HomeEmptyCard`, `MenuEmptyCard`, `AnketEmptyCard`, `ProfilyEmptyCard`, `SupportEmptyCard` (8) + `BuEmptyState` (`widgets/bu_state.dart:64`); sekme çubukları `SohbetyTabs`, `FollowTabs`, `IcerikTabs`, `AnketTabs`, `ProfilyTabs` (5); `P2SectionLabel`/`FollowSectionLabel`/`AkadSection` | Arayüz "kilitli" (MOBILE_DESIGN_SYSTEM) — piksel eşitliği korunarak `BuEmptyState`/`BuTabs` ayarlarıyla birleştirilmeli | Önce `BuEmptyState`'e `icon/headline/body/action` yetenekleri; golden testlerle doğrula |
| K10 | Mobil | Küçük yardımcılar: `String _two(int)` ×4 (`chat_detail_page.dart:1602`, `message_bubble.dart:19`, `event_detail_page.dart:1234`, `user_profile_page.dart:264`); süre biçimleyici ×2 (`chat/chat_media.dart:19 formatMediaDuration` ↔ `chat_info_media.dart:154 formatDuration`, ikincisi saat desteklemiyor — tutarsızlık); `_isArabic` ×2 (`akad_widgets.dart:26`, `bu_widgets.dart:35`); gün etiketi `_dayLabel` ×2 (`chat_detail_page.dart:1637`, `support_ticket_page.dart:301`); `_intOrNull` ×2 (`post_models.dart:40`, `social_models.dart:4`); `_gradeName`; `_isPast`+`_parse` (`events_page.dart:196,132` ↔ `my_events_page.dart:74,80`); tarih biçimleyiciler dağınık (`widgets/common.dart:12 fmtDate/43 relativeTime`, `academic_models.dart fmtInstant*`, `event_detail_page.dart:28 _fmtDate`, `semester_sheet.dart:312`, `poll_form_page.dart:62`, `notification_prefs_page.dart:343`) | — | `core/format.dart` (iki hane, süre, gün etiketi, göreli zaman) |
| K11 | Mobil | Sayfalama/yenileme iskeleti: `_onScroll`+`_loadMore`+`_reload`+`_footer` en az 5 sayfada ( `announcements_page`, `chat_tab`, `media_picker_page`, `new_chat_page`, `clubs_tab`, `discover_masonry`, `news_list_page`, `poll_list_page`, `saved_news_page`); `ProfilePagedList` (ölü) bu işin yarım bırakılmış genelleştirmesi | — | Canlı bir `PagedListController` + `BuPagedSliver` ya da ölü `profile_paged_list.dart`'ı tamamlayıp yayginlastırın |
| K12 | Mobil | Doğrulama kodu sayfaları: `auth/reset_code_page.dart` ↔ `verify_code_page.dart` (21 + 15 + 12 satır eşleşme: OTP kutusu + `_resend` + hata/info) | — | `AuthCodeScaffold` |
| K13 | Mobil | Disk önbelleği kökleri: `_defaultDir` ×3 (`disk_cache.dart:63`, `image_disk_cache.dart:37`, `message_cache.dart:42`), `_prune` ×3 | — | `DiskCacheBase` |
| K14 | Web | `GuardedDialog.tsx` (174 satır) ↔ `guard/GuardedAction.tsx` (232 satır): 22+16+14 satır aynı gerekçe/ onay mantığı | İkisi de canlı (6+ kullanım) | Mantığı `useGuardedMutation` içinde topla, dialog yalnız kabuk olsun |
| K15 | Web | Akademik yönetim sayfaları: `AcademicAnnouncementsPage` ↔ `AcademicExamsPage` (19+18+16+16+20 satır eşleşme), `AcademicCalendarPage` ↔ `AcademicExamsPage` (20+14); `HiddenContentPage` ↔ `StrikesPage` (19); `CommunitiesAdminPage` ↔ `EventsAdminPage` (14); `CrashesPage` ↔ `MailQueuePage` (14); `UserDevices.tsx:179` ↔ `:219` | Süzgeç çubuğu + tablo + silme iletişim iskeleti kopya | `AdminListPage` iskeleti (kolon tanımı + süzgeç şeması) |

---

## 6. Neye bakılamadı / sınırlar

- **Mobil derleme/test çalıştırılmadı** (yalnız `flutter analyze` ve `gen-l10n`): silme önerilerinin hiçbiri derlenerek doğrulanmadı; her silme `flutter analyze && flutter test` ile doğrulanmalı. iOS/Android yerel kodunda (`android/`, `ios/`) kullanılan varlıklar/ayarlar `analysis_options.yaml` ile hariç; `res/` içindeki simge varlıkları bu denetime girmedi.
- **Backend derlenmedi/test koşulmadı** (bu makinede Java 8; Docker konteyneri istenmedi). Ölü metot taraması belirteç sayımına dayanır: yansıma, SpEL, `@Query` içinde ad geçişi (JPQL'de yöntem adı yok), `@ConditionalOnProperty` ve Jackson getter/setter'ları için tek tek ele alma yapılmadı — Spring Data türetilmiş sorgu yöntemlerinin silinmesi bu yüzden güvenli, entity/DTO getter'ları ise **hiç incelenmedi**.
- **Kullanılmayan DTO/entity alanları** sistematik taranmadı (yalnız `PostView`/`PostRow` yorum alanları belge üzerinden doğrulandı). Entity sütunları `ddl-auto=validate` nedeniyle migration olmadan silinemez.
- **Üretim verisi görülmedi**: B4.1 (eski bildirim satırları) ve B7 (video satırı) için canlı DB sorgusu atılmadı (talimat gereği); kararları bu sayıma bağlıdır.
- **İzlenmeyen/yarım dosyalara dokunulmadı**: `mobile/lib/features/chat/media_source_sheet.dart`, `test/redesign/p08|p11|p13|p14|p18_shots_test.dart`, `scripts/ci/*`. `p*` l10n anahtarları ve M1.3 bu ajanların işine bağlı olabilir.
- Mobil `dart analyze` HEAD (2026-10-31, `AUDIT-A8` civarı) kopyasında alındı; çalışma ağacında başkalarının değişiklikleri sonrası sayılar küçük oynayabilir (ilk turda `$ad` enterpolasyonu belirteçlerini yanlış saydığımı fark edip düzelttim; `apiBase`, `kEmailDomain`, `_homeNewsType` gibi 6 yanlış pozitif elendi).
- Web: `knip` yok; `export` edilip yalnız aynı dosyada kullanılan ~330 **tür** (interface/type) adı gürültü olduğundan listelenmedi (yalnızca `export` anahtar sözcüğü fazlalığı). Kullanılmayan e2e/Playwright senaryoları, `public/` PNG'lerin tek tek görsel doğrulaması ve `docs/openapi.json` ile yol eşleşmesi bu işin dışında.
- Belge bölümü yalnız taramayla: D6 ve D7 maddelerinde tüm bölümler satır satır doğrulanmadı.
- Ağ kurulumu yok, kaynak eklenmedi; `C:\bu_a18_x` altında geçici kopya oluşturuldu (repo dışı; silme izni sistem tarafından verilmediği için silinmedi — elle silinebilir).

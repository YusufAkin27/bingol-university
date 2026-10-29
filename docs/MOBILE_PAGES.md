# Mobil sayfa envanteri ve yeniden tasarım planı (UI0)

> Durum: planlama belgesi, kod değiştirilmedi. Tarih 2026-10-29, dal `feature/mobil-uygulama`.
> Amaç: kullanıcı kararı "20 ajan yalnız mobil tasarımı güncellesin, her sayfaya tek tek bakarak; modern, şık, yenilikçi, hızlı açılan sayfalar" için (1) eksiksiz ekran envanteri, (2) 20 ayrık iş paketi + temel paket, (3) kurallar, (4) mevcut durum ölçümü, (5) tasarım yönü seçenekleri.
> Kaynaklar: `mobile/lib/**` (kod taraması), `mobile/test/**`, `docs/MOBILE_UI.md`, `mobile/design/*.dc.html`. Rakamlar 2026-10-29 çalışma ağacından ölçüldü.

## 0. Sayılar (önce özet)

| Ölçü | Değer |
|---|---|
| Toplam ekran envanteri satırı (numaralı, aşağıda) | **101** |
| Sekme (alt gezinme) | **5** (Ana Sayfa, Keşfet, Sohbet, Kulüpler, Profil) |
| Tam sayfa/rota ekranı (E) | **75** |
| Kabuk/kapı bileşeni (K: AppShell, FloatingNav, AppGate, PostLoginGate, LegalReacceptGate) | **5** |
| Durum ekranı/şeridi (D: Splash, hata, güncelleme, bakım, çevrimdışı, erişim engeli, şeritler, push şeridi) | **11** |
| Tam ekran görüntüleyici (Z: sohbet görseli/video/tek gösterimlik/avatar) | **5** |
| Alt sayfa / diyalog / seçici / katman (ayrı tablo, çağrı noktası) | **60** (alt sayfa 21, diyalog 25, `showGeneralDialog` katmanı 2, tarih seçici 5, saat seçici 5, tam ekran seçici rotası 2) |
| Push ile açılan hedef türü (`PushDest`) | **15** (bkz. bölüm 3) |
| Toplam UI kaynak dosyası (paketlere atanan) | **161 dosya / 50.923 satır** |
| Dokunulmaz davranış/veri dosyası (api, session, realtime, push, modeller...) | **44 dosya / 7.328 satır** |
| Üretilmiş l10n dosyaları (el ile düzenlenmez) | 5 dart + 3 arb (2144 anahtar, tr/en/ar) |
| Yönlendirme | GoRouter yok; yalnız `Navigator.push(MaterialPageRoute)` ve `showModalBottomSheet/showDialog/showGeneralDialog` (rotalar adlandırılmamış) |

Not: kimlik (P2) dosya/satır rakamları, başka sürecin devam eden çalışmasını (yeni `features/auth/widgets/*`) içerir ve değişebilir. "Ekran" sayımı sınıf/rota düzeyindedir; bir ekranın içindeki bölümler (ör. Kulüp detayındaki Gönderiler/Etkinlikler/Üyeler sekmeleri, Etkinlikler sayfasının 4 modu) ayrı ekran sayılmadı, ilgili satırda yazıldı. Alt sayfa listesi çağrı noktalarına göre çıkarıldı; paket sahibi ekranı açarak doğrular.

## 1. Ekran envanteri (numaralı)

Sütunlar: tür (E ekran, T sekme, K kabuk/kapı, D durum, Z görüntüleyici), dosya (satır), nasıl açılır ve bağımlı uçlar, ana içerik, durum varyantları, ilgili testler (`mobile/test/` içinde `_test` soneki yazılmadı), l10n anahtar öneki (`lib/l10n/app_tr.arb`; `*` önek ailesi), paket numarası. Paylaşılan widget'lar: aksi belirtilmedikçe `widgets/bu_widgets.dart` (BuHeader/BuCard/BuButton/BuChip/BuAvatar...), `widgets/common.dart` (LoadingView/ErrorView/EmptyView), modül yerel dosyaları (bölüm 4 dosya kümelerinde görünür).

### A. Kök, kapılar ve sistem durumları

| No | Ekran (sınıf) | Dosya (satır) | T | Nasıl açılır / uçlar | Ana içerik | Durumlar | Test | l10n | Pk |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `SplashScreen` | `features/system/splash_screen.dart` (161) | D | Oturum çözülürken (`SessionState.loading`) ve karşılama bayrağı okunurken kök ekran | Kırmızı zemin, halka boyacısı, logo karosu, uygulama adı | yalnız statik | yok (dolaylı) | `—` | 1 |
| 2 | `ConfigErrorApp` | `main.dart` (295) | D | `apiConfigValid()` false ise `runApp` yerine | Geçersiz API yapılandırma uyarısı (ayrı MaterialApp) | hata | api_config_test (yalnız mantık) | `config*` | 1 |
| 3 | `_ErrorView (ErrorWidget)` | `main.dart` (295) | D | Release modda `ErrorWidget.builder`; çizim hatasında kırmızı ekran yerine | Sade hata + yeniden dene; Localizations yokken cihaz dilinden çözülür | hata | yok | `commonSomethingWentWrong` | 1 |
| 4 | `AppGate` | `core/app_gate.dart` (264) | K | `MaterialApp.builder`: tüm ekranların üstünde katman. `GET /app/version`, `GET /app/info`, `GET /status` | Sürüm/bakım/duyuru/çevrimdışı kararı; zorunlu güncelleme tam ekranı, bakım şeridi, duyuru şeridi | güncelleme zorunlu / bakım / duyuru / çevrimdışı | app_gate (karar mantığı) | `update*, cevrimdisi*, sistemui*` | 1 |
| 5 | `UpdateRequiredScreen` | `features/system/gate_views.dart` (221) | D | AppGate: sürüm zorunlu eşiğin altındaysa, kapatılamaz | Sürüm satırı, mağaza düğmesi, yeniden dene | çevrimdışı yeniden deneme | b2_audit, pages_a, sistem_design, visual_a | `update*, sistemui*` | 1 |
| 6 | `MaintenanceScreen` | `features/system/gate_views.dart` (221) | D | AppGate: `maintenance_mode` açık | Tam ekran bakım + ek uyarı bandı | bakım | sistem_design | `sistemui*` | 1 |
| 7 | `OfflineScreen` | `features/system/gate_views.dart` (221) | D | Bağlantı yok görünümü (tam ekran) | Yeniden dene | çevrimdışı | sistem_design | `cevrimdisi*` | 1 |
| 8 | `AccessBlockedScreen` | `features/system/gate_views.dart` (221) | D | `session.accessBlocked` (403 `ACCESS_BLOCKED`); oturum silinmiş | Erişim kapatıldı bilgisi; yeniden dene -> giriş | engellendi | robustness, sistem_design | `access*, sistemui*` | 1 |
| 9 | `TopStrip (şerit)` | `features/system/gate_views.dart` (221) | D | AppGate üst şeridi: bakım, duyuru, çevrimdışı | Tek satır uyarı şeridi | bakım / duyuru / çevrimdışı | sistem_design | `sistemui*, cevrimdisi*` | 1 |
| 10 | `UpdateNotice (alt bildirim)` | `features/system/gate_views.dart` (221) | D | AppGate: yeni sürüm var, kapatılabilir | Alt bildirim kartı | — | app_gate (karar) | `update*` | 1 |
| 11 | `OfflineBanner + StaleLabel` | `core/connectivity/offline_banner.dart` (78) | D | Uygulama kökü sarmalayıcısı (bekleyen mesaj kuyruğu); `StaleLabel` önbellekten gelen veriyle | İnce şerit: bekleyen çevrimdışı mesaj sayısı; 'Son güncelleme' etiketi | bekleyen kuyruk / bayat veri | offline_banner | `cevrimdisi*` | 1 |
| 12 | `PushBanner (_BannerHost)` | `core/push/push_banner.dart` (155) | D | Ön plandaki uygulamada gelen push; 4 sn | Üstten inen ince kart, aynı sohbetten gelenler tek kartta birleşir | — | push_foreground | `push*` | 1 |
| 13 | `PostLoginGate` | `features/auth/permissions_page.dart` (414) | K | İlk girişten sonra, cihaz bayrağı yoksa kabuğun yerine | Bayrak okuma (Keychain/Keystore) + izin sayfası ya da çocuk | — | permissions | `perm*` | 1 |
| 14 | `PermissionsPage` | `features/auth/permissions_page.dart` (414) | E | PostLoginGate; her kart ayrı atlanabilir | Bildirim, rehber, kamera/galeri izin kartları, 3 parçalı ilerleme | izin verildi / reddedildi / ayara git | permissions, sistem_design, visual_a | `perm*, sistemui*` | 1 |
| 15 | `LegalReacceptGate` | `features/legal/legal_reaccept_page.dart` (288) | K | Kabuğun üstünde; `GET /legal/acceptance-status` | Bekleyen belge varsa tam ekran onay; ağ hatasında açılmaz | enforced (atlanamaz) / atlanabilir | legal_reaccept | `legal*` | 1 |
| 16 | `LegalReacceptPage` | `features/legal/legal_reaccept_page.dart` (288) | E | LegalReacceptGate; `POST /legal/accept` | Belge listesi (tam metne açılır), tek onay kutusu, Kabul et / Daha sonra / Kabul etmiyorum | yükleniyor / hata / enforced | legal_reaccept | `legal*` | 1 |
| 17 | `LegalListPage` | `features/profile/legal_pages.dart` (226) | E | Ayarlar > Sözleşmeler; `GET /legal` | Sözleşme türleri listesi | yükleniyor / hata / boş | pages_c, robustness | `legal*` | 1 |
| 18 | `LegalDocPage` | `features/profile/legal_pages.dart` (226) | E | Liste, kayıt ekranı, yeniden onay ekranından; `GET /legal/{type}` | Markdown sözleşme metni (`SimpleMarkdown`) | yükleniyor / hata | pages_c, destek, legal_reaccept, robustness, visual_c | `legal*` | 1 |
| 19 | `QrScanPage` | `features/platform/qr_scan_page.dart` (348) | E | Etkinlik yoklaması (EventDetail) ve QR gereken yerler; sonuç `pop(code)` | Kamera önizleme, köşe işaretleri, elle kod girişi (her zaman ekranda) | yükleniyor / izin yok / elle giriş | pages_b, sistem_design | `qr*` | 1 |

### B. Kimlik akışı

| No | Ekran (sınıf) | Dosya (satır) | T | Nasıl açılır / uçlar | Ana içerik | Durumlar | Test | l10n | Pk |
|---|---|---|---|---|---|---|---|---|---|
| 20 | `WelcomePage` | `features/auth/welcome_page.dart` (304) | E | Cihazda ilk açılış (`welcome_seen` yoksa); giriş/kayıt'a geçiş | Tanıtım satırları, TR/EN/AR dil hapı, Giriş / Kayıt | — | yok | `welcome*, auth*` | 2 |
| 21 | `LoginPage` | `features/auth/login_page.dart` (263) | E | Çıkış yapmış kök ekran; `POST /auth/login` | E-posta (@bingol.edu.tr sonek), şifre, doğrulama bekleyen kayıt bandı | hata / kilit / bekleyen doğrulama | pages_a, student_number, single_session, visual_a, l10n | `login*, auth*` | 2 |
| 22 | `RegisterPage` | `features/auth/register_page.dart` (411) | E | Giriş ekranından / karşılamadan; `POST /auth/register` | 3 adım: akademik bilgi -> kişisel bilgi -> şifre; sözleşme bilgi satırı | doğrulama hataları / ağ hatası | pages_a, student_number, academic, b2_audit, visual_a | `auth*` | 2 |
| 23 | `VerifyCodePage` | `features/auth/verify_code_page.dart` (180) | E | Kayıttan / giriş bandından; `POST /auth/verify-email`, `resend-code` | 6 haneli OTP kutuları, 60 sn yeniden gönderme | hata / bekleme sayacı | pages_a, student_number, academic, visual_a | `auth*` | 2 |
| 24 | `ForgotPasswordPage` | `features/auth/forgot_password_page.dart` (93) | E | Giriş ekranı; `POST /auth/forgot-password` | E-posta gir, kod gönder (genel yanıt) | hata | pages_a, student_number, visual_a | `auth*, login*` | 2 |
| 25 | `ResetCodePage` | `features/auth/reset_code_page.dart` (131) | E | Şifre sıfırlama 2. adım; `POST /auth/verify-reset-code` | OTP kutuları | hata / sayaç | pages_a, student_number, visual_a | `auth*` | 2 |
| 26 | `NewPasswordPage` | `features/auth/new_password_page.dart` (123) | E | Şifre sıfırlama 3. adım; `POST /auth/reset-password` | Yeni şifre + tekrar, güç ipuçları | hata | pages_a, visual_a | `auth*` | 2 |
| 27 | `ResetSuccessPage (YENİ)` | `features/auth/reset_success_page.dart` (83) | E | Şifre sıfırlama başarısından sonra; başka sürecin eklediği, henüz izlenmeyen ekran (envanter anında çalışma ağacında) | Şifre güncellendi bilgisi (`authResetDone*`), girişe dön | — | yok | `auth*` | 2 |
| 28 | `Bölüm seçici (_DepartmentPicker)` | `widgets/academic_picker.dart` (392) | E | Kayıt/Profil düzenle `AcademicFields`; tam ekran diyalog rotası | Aranabilir fakülte/bölüm listesi | katalog yükleniyor / hata | academic, student_number (dolaylı) | `acad*` | 2 |
| 29 | `Sınıf seçici (_GradePicker)` | `widgets/academic_picker.dart` (392) | E | `AcademicFields`; tam ekran diyalog rotası | Sınıf (hazırlık, 1-6, lisansüstü) listesi | — | academic (dolaylı) | `acad*` | 2 |

### C. Kabuk ve sekmeler

| No | Ekran (sınıf) | Dosya (satır) | T | Nasıl açılır / uçlar | Ana içerik | Durumlar | Test | l10n | Pk |
|---|---|---|---|---|---|---|---|---|---|
| 30 | `AppShell` | `features/shell/app_shell.dart` (171) | K | Giriş sonrası kök; `IndexedStack` 5 sekme; `GET /me/summary` (rozetler, 1 dk) | Sekme durumu, geri davranışı (Ana Sayfa'ya, 2 sn çift basış), STOMP başlatma | — | back_navigation, b4, pages_a, store_shots | `exit*, nav*` | 18 |
| 31 | `FloatingNav` | `features/shell/floating_nav.dart` (234) | K | AppShell alt gezinmesi (yüzen kart, kayan hap, sohbet rozeti) | 5 sekme ikon+etiket, RTL ayna | rozet | floating_nav, back_navigation, l10n, visual_a | `nav*` | 18 |
| 32 | `HomeTab` | `features/home/home_tab.dart` (749) | T | Sekme 0; `GET /me/summary`, `/status`, `/news?type=&page=0&size=3`, `/events/featured`, `PUT /events/{id}/rsvp` | Selamlama, arama kutusu, hızlı erişim, bugünün yemeği, öne çıkan etkinlik, duyurular | yükleniyor / hata / bakım / bayat / boş | home_redesign, events_*, menu_photo, pages_a, robustness, visual_a | `home*, anasayfa*` | 3 |
| 33 | `DiscoverTab` | `features/discover/discover_tab.dart` (137) | T | Sekme 1 (+ `typeRequest`); `GET /posts` (masonry) | Başlık + gönderi paylaş düğmesi, arama kutusu, iki sütun masonry akış | iskelet / boş / hata / bitti | discover_masonry, robustness, visual_a | `discover*, kesfet*` | 4 |
| 34 | `ChatTab` | `features/chat/chat_tab.dart` (947) | T | Sekme 2; `GET /conversations`, `/conversations/unread-count`; STOMP | Süzgeç (hepsi/birebir/grup/kulüp/etkinlik), arama, konuşma satırları, okunmamış, kaydırarak sessize al/sil | iskelet / boş / hata / çevrimdışı / canlı güncelleme | chatlist_design, chat_extras, pages_b, visual_b, robustness, b4 | `chat*, chatlist*` | 6 |
| 35 | `ClubsTab` | `features/clubs/clubs_tab.dart` (398) | T | Sekme 3; `GET /communities`, `/communities/categories`, `/me/communities` | Keşfet | Kulüplerim, kategori çipleri, kulüp kartları, kulüp kur düğmesi | yükleniyor / boş / hata / sayfalama | clubs_tab_design, club_categories, clubs_manage, pages_b, visual_b | `club*, kulupler*` | 12 |
| 36 | `ProfileTab` | `features/profile/profile_tab.dart` (399) | T | Sekme 4; `GET /users/me`, `/me/summary` | Avatar+ad, profili düzenle, gruplu ayar kartları, tema ve dil seçici (alt sayfa), çıkış | yükleniyor / hata | profil1, profil_rows_layout, academic, pages_c, visual_c | `profile*, profil1*` | 18 |

### D. Ana Sayfa, Yemek, Bildirimler

| No | Ekran (sınıf) | Dosya (satır) | T | Nasıl açılır / uçlar | Ana içerik | Durumlar | Test | l10n | Pk |
|---|---|---|---|---|---|---|---|---|---|
| 37 | `MenuPage (Yemek)` | `features/menu/menu_page.dart` (341) | E | Ana Sayfa hızlı erişim; `GET /menu?month=`, `/menu/today`, `GET /status` | Gün seçici, öğle yemeği kartı (fotoğraflı/fotoğrafsız), günlük menü puanlama (anket) | yükleniyor / boş / hata / bakım / bayat | yemek_page, menu_photo, pages_c, back_navigation, robustness, visual_c | `yemek*, menu*` | 3 |
| 38 | `NotificationsPage` | `features/notifications/notifications_page.dart` (465) | E | Ana Sayfa zili / push yedeği; `GET /notifications`, `POST /notifications/read`, `DELETE` | Okunmamış rozeti, hedefe yönlendirme (`push_targets`), sil | yükleniyor / boş / hata / sayfalama | notif_design, push_notify, pages_c, back_navigation, robustness, visual_c | `bildirim*, notif*` | 3 |

### E. Keşfet, gönderi, haber, arama

| No | Ekran (sınıf) | Dosya (satır) | T | Nasıl açılır / uçlar | Ana içerik | Durumlar | Test | l10n | Pk |
|---|---|---|---|---|---|---|---|---|---|
| 39 | `ComposePostPage` | `features/posts/compose_post_page.dart` (374) | E | Keşfet + düğmesi; `POST /posts/media`, `POST /posts` (tam ekran diyalog rotası) | Tam 1 fotoğraf + en çok 7 kelime metin, canlı sayaç, vazgeç onayı | yükleniyor / hata / 422 küfür | gonderi_sade, visual_a | `post*, gonderi*` | 4 |
| 40 | `PostDetailPage` | `features/posts/post_detail_page.dart` (127) | E | Masonry/profil kartı/push (`openPostDetail`); `GET /posts/{id}` | Fotoğraf, yazar, kısa metin, beğeni | yükleniyor / hata / silinmiş | gonderi_sade, discover_masonry, robustness, visual_a | `post*` | 4 |
| 41 | `NewsListPage` | `features/news/news_list_page.dart` (395) | E | Ana Sayfa hızlı erişim (`AppShell._go`); `GET /news`, `/status`, `/bookmarks/news/*` | Haber | Duyuru | Etkinlik sekmeleri, favori + arama kısayolu, bakım bandı | yükleniyor / boş / hata / bakım / bayat / sayfalama | icerik | `news*, icerik*` | 5 |
| 42 | `NewsDetailPage` | `features/news/news_detail_page.dart` (349) | E | Liste / Ana Sayfa / push (`NewsDetailPage(item:{id})`); `GET /news/{id}`, `PUT/DELETE /bookmarks/news/{id}` | Kapak, başlık, makale metni, kaynak düğmesi, favori | yükleniyor / hata | icerik, pages_a, back_navigation, robustness, visual_a | `news*, icerik*` | 5 |
| 43 | `SavedNewsPage` | `features/profile/saved_news_page.dart` (233) | E | Haber listesi / Profil; `GET /bookmarks`, `DELETE /bookmarks/news/{id}` | Favori haber satırları, kesikli ipucu kartı | yükleniyor / boş / hata / sayfalama | icerik, pages_c, robustness | `icerik*, profile*` | 5 |
| 44 | `SearchPage` | `features/search/search_page.dart` (819) | E | Keşfet ve haber arama kutusu; `GET /search`, `/users/search` | Sekmeler: Tümü/Haber/Kulüp/Etkinlik/Gönderi/Kişi, sayfalama | boş sorgu / yükleniyor / sonuç yok / hata | pages_c, icerik, back_navigation, robustness, visual_c | `search*` | 5 |

### F. Sohbet

| No | Ekran (sınıf) | Dosya (satır) | T | Nasıl açılır / uçlar | Ana içerik | Durumlar | Test | l10n | Pk |
|---|---|---|---|---|---|---|---|---|---|
| 45 | `NewChatPage` | `features/chat/new_chat_page.dart` (499) | E | Sohbet sekmesi +; `GET /users/search`, `POST /conversations` | Kişi ara, birebir seç / çoklu seç = grup, 'Yeni grup' kartı, rehber girişi | yükleniyor / boş / hata | pages_b, sohbety_design, visual_b | `chat*, sohbety*` | 6 |
| 46 | `ContactsMatchPage` | `features/chat/contacts_match_page.dart` (378) | E | Yeni sohbet / Ayarlar `ContactsEntryRow`; rehber e-posta özeti (SHA-256) eşleştirme, `POST /conversations` | Rehberden bulunan BÜ kişileri, Mesaj düğmesi, gizlilik notu | faz: yükleniyor / izin gerek / hazır / hata | contacts_match, sohbety_design | `chat*` | 6 |
| 47 | `ChatDetailPage` | `features/chat/chat_detail_page.dart` (2478) | E | Liste / push (`GET /conversations/{id}`) / profil / kulüp / etkinlik sohbeti; STOMP + `GET /conversations/{id}/messages` | Mesaj geçmişi (imleçli), iyimser gönderim, yanıt/düzenle/sil/tepki, görsel/video, arama, kapalı sohbet bandı, çevrimdışı kuyruk | yükleniyor / boş / hata / çevrimdışı / kapalı (`CONVERSATION_CLOSED`) / bağlantı yok (4 sn yoklama) | chat_extras, chat_status_video, chat_offline, chatd_bubbles, media_picker, pages_b, user_profile, b4, push_notify, store_shots, visual_b, back_navigation | `chat*, chatd*` | 7 |
| 48 | `ChatMediaViewer` | `features/chat/chat_media_viewer.dart` (422) | Z | Mesaj görseli / ortam ızgarası; yatay gezinme, yakınlaştırma, galeriye kaydet | Siyah zemin, sayfa göstergesi, video poster sayfası | yükleniyor / hata | chat_status_video, media_grid | `chat*, sohbetmedya*` | 8 |
| 49 | `ChatVideoPlayerPage` | `features/chat/chat_video_player.dart` (292) | Z | Galeri video sayfası / mesaj videosu; yetkili HTTP Range | Otomatik oynat, dokununca durdur, ilerleme çubuğu | yükleniyor / oynatılamadı + yeniden dene | yok | `chat*` | 8 |
| 50 | `ViewOnceViewer` | `features/chat/view_once_viewer.dart` (203) | Z | Tek gösterimlik fotoğraf; bayt yalnız bellekte, kopya/kaydet/paylaş YOK | Siyah zemin, ekran yakalama koruması | yükleniyor / 410 tüketildi / hata | chat_extras | `chat*` | 8 |
| 51 | `ChatImageViewer` | `features/chat/message_bubble.dart` (1163) | Z | Mesaj görseline dokunma (`chat_detail_page.dart:1184`) | Yetkili başlıkla tam ekran görsel + yakınlaştırma | yükleniyor / hata | chat_status_video (dolaylı) | `chat*` | 8 |
| 52 | `ChatInfoPage` | `features/chat/chat_info_page.dart` (1122) | E | Sohbet başlığı; `GET/PATCH /conversations/{id}`, mute/archive/leave/avatar, `/users/{id}/block` | Avatar+başlık, hızlı eylemler, medya önizlemesi, üyeler, çık/engelle/şikâyet; pop sonucu `search`/`left` | yükleniyor / hata | chat_info, sohbety_design, user_profile, visual_b | `chat*, sohbety*` | 9 |
| 53 | `ChatMembersPage` | `features/chat/chat_info_members.dart` (188) | E | ChatInfoPage üyeler bölümünden | Üye listesi, yönetici işlemleri, üye ekleme girişi | yükleniyor / boş | yok | `chat*` | 9 |
| 54 | `ChatMediaGridPage` | `features/chat/chat_info_media.dart` (330) | E | ChatInfoPage medya bölümünden | Görsel/video ızgarası (cacheWidth 360), ChatMediaViewer'a gider | yükleniyor / boş | chat_info, media_grid | `chat*, sohbetmedya*` | 9 |
| 55 | `MediaPickerPage` | `features/chat/media_picker_page.dart` (534) | E | Sohbet ek düğmesi; `photo_manager` galerisi | Kare ızgara (sayfalı), ilk karo kamera, çoklu seçim, albüm seçici | yükleniyor / izin yok / boş | media_picker, visual_b | `chat*, pick*` | 10 |
| 56 | `MediaPreviewPage` | `features/chat/media_preview_page.dart` (454) | E | MediaPickerPage / kameradan | Sayfa sayfa önizleme, küçük resim şeridi, açıklama, 'tek gönderimlik' | yükleniyor | media_picker | `chat*` | 10 |
| 57 | `MediaCameraPage` | `features/chat/media_camera_page.dart` (253) | E | Galeri ilk karosu (tam ekran diyalog rotası) | Dokun = fotoğraf, bas-tut = video (60 sn, sayaç) | izin yok / hazırlanıyor | yok | `chat*` | 10 |

### G. Kulüpler

| No | Ekran (sınıf) | Dosya (satır) | T | Nasıl açılır / uçlar | Ana içerik | Durumlar | Test | l10n | Pk |
|---|---|---|---|---|---|---|---|---|---|
| 58 | `ClubDetailPage` | `features/clubs/club_detail_page.dart` (1127) | E | Kulüp kartı / push / arama / profil; `GET /communities/{id}`, `/chat-room`, posts, `DELETE /membership` | Kapak, üyelik düğmesi, sohbet, sekmeler: gönderiler/etkinlikler/üyeler, yönetici araçları, anket bölümü | yükleniyor / hata / sayfalama / üyelik durumları | kulup_detay_design, clubs_manage, pages_b, back_navigation, b2_audit, b4, robustness, visual_b | `club*, kulupdetay*` | 11 |
| 59 | `ClubMembersPage` | `features/clubs/club_members_page.dart` (247) | E | ClubDetail yönetici menüsü; `GET/PUT/DELETE /communities/{id}/members` | Arama, rol değiştir (sahip), çıkar, yasakla; pop=değişti | yükleniyor / boş / hata | clubs_manage, kulup_detay_design, visual_b | `club*` | 11 |
| 60 | `ClubRequestsPage` | `features/clubs/club_requests_page.dart` (196) | E | ClubDetail / Kulüplerim; `GET /requests?include=answers`, `POST /requests/{uid}/approve|reject` | Avatar+ad+cevaplar, Onayla/Reddet | yükleniyor / boş / hata | clubs_manage, kulup_detay_design, visual_b | `club*` | 11 |
| 61 | `PollFormPage` | `features/polls/poll_form_page.dart` (355) | E | Kulüp yöneticisi (`poll_routes.dart`); `POST /polls` | Soru, tür, 2-12 seçenek, bitiş, görünürlük, gizli oy, bildirim anahtarı | doğrulama hataları | polls, anket | `poll*, anket*` | 11 |
| 62 | `ClubFormPage` | `features/clubs/club_form_page.dart` (542) | E | Kulüpler sekmesi + / ClubDetail düzenle / Kulüplerim; `POST/PATCH /communities`, join-questions | Kapak, ad, kategori, açıklama, katılım soruları | yükleniyor / hata / incelemede diyaloğu | clubs_manage, club_categories, kulup_detay_design, visual_b | `club*` | 12 |
| 63 | `MyClubsPage` | `features/profile/my_clubs_page.dart` (295) | E | Profil > Kulüplerim; `GET /me/communities`, `DELETE /membership` | Kurduklarım / üye olduklarım / bekleyen başvurular | yükleniyor / boş / hata | clubs_manage, pages_c, profilyard, robustness, visual_b | `profile*, profilyard*` | 12 |
| 64 | `(yeniden kullanım) Scaffold(ClubsTab)` | `features/profile/my_clubs_page.dart` (295) | E | `Scaffold(body: ClubsTab)` ayrı rota olarak (MyClubs:144, EventForm:667) | Kulüpler sekmesinin tam ekran kopyası | ClubsTab durumları | clubs_manage | `club*` | 12 |

### H. Anketler ve Destek

| No | Ekran (sınıf) | Dosya (satır) | T | Nasıl açılır / uçlar | Ana içerik | Durumlar | Test | l10n | Pk |
|---|---|---|---|---|---|---|---|---|---|
| 65 | `PollListPage` | `features/polls/poll_list_page.dart` (208) | E | Profil/Ana Sayfa/kulüp (`poll_routes.dart`); `GET /polls` | Açık | Katıldıklarım | Kapanan, kulüp süzgeci, imleçli sayfalama | yükleniyor / boş / hata | polls, anket, pages_c | `poll*, anket*` | 13 |
| 66 | `PollDetailPage` | `features/polls/poll_detail_page.dart` (474) | E | Liste / push (`openPollDetail`); `GET/POST/DELETE /polls/{id}/vote` | SINGLE/MULTI/RATING/RANKED seçim, oy ver/değiştir/geri çek, sonuçlar | yükleniyor / hata / kapalı / henüz açılmadı / bayat | polls, anket, store_shots | `poll*` | 13 |
| 67 | `SupportPage` | `features/support/support_page.dart` (347) | E | Profil > Destek / push (FEEDBACK); `GET /faq`, `/support/tickets` | SSS akordeonu, talep oluştur, taleplerim, geri bildirim/öneri girişleri | yükleniyor / boş / hata / sayfalama | destek, pages_c, back_navigation, robustness, visual_c | `support*, destek*` | 13 |
| 68 | `NewTicketPage` | `features/support/support_new_ticket_page.dart` (89) | E | SupportPage; `POST /support/tickets` | Konu + mesaj formu | doğrulama / hata | pages_c | `support*` | 13 |
| 69 | `SupportTicketPage` | `features/support/support_ticket_page.dart` (241) | E | SupportPage / push (TICKET); `POST /support/tickets/{id}/messages|close` | Mesaj akışı, yanıt yaz, kapat | yükleniyor / hata | destek, pages_c | `support*` | 13 |
| 70 | `FeedbackPage` | `features/support/support_feedback_page.dart` (233) | E | SupportPage; `GET /feedback/mine`, `POST /feedback` | Geri bildirim formu + gönderdiklerim (imleçli) | yükleniyor / boş / hata | pages_c, profilyard | `support*, profilyard*` | 13 |
| 71 | `SuggestionsPage` | `features/support/support_suggestions_page.dart` (245) | E | SupportPage; `GET /suggestions?sort=` | Yönetici onaylı öneriler, oy verme (top|new) | yükleniyor / boş / hata | destek, pages_c, robustness | `support*` | 13 |

### I. Etkinlikler

| No | Ekran (sınıf) | Dosya (satır) | T | Nasıl açılır / uçlar | Ana içerik | Durumlar | Test | l10n | Pk |
|---|---|---|---|---|---|---|---|---|---|
| 72 | `EventsPage` | `features/events/events_page.dart` (1391) | E | Ana Sayfa / Profil / etkinlik kısayolları; `GET /events`, `PUT/DELETE /events/{id}/rsvp`, `POST /events/{id}/check-in|close|reopen` | Keşfet (takvim) | Yaklaşan | Geçmiş | Oluşturduklarım; sabit segment çubuğu | iskelet / boş / hata / sayfalama / çevrimdışı | events_page, events_layout, events_cover, pages_b, robustness, visual_b | `event*, evc*` | 14 |
| 73 | `MyEventsPage` | `features/profile/my_events_page.dart` (297) | E | Profil > Etkinliklerim; `GET /me/events?mode=` | Katıldıklarım (yaklaşan/geçmiş) | Oluşturduklarım | yükleniyor / boş / hata | pages_c, profilyard | `event*, profilyard*` | 14 |
| 74 | `EventDetailPage` | `features/events/event_detail_page.dart` (1012) | E | Etkinlik kartı / push / kulüp / takvim; `GET /events/{id}`, `/admission`, `/attendance`, `/chat`, `POST /applications|check-in` | Kapak, bilgi, RSVP, yoklama, organizatör araçları, etkinlik sohbeti, QR okut | yükleniyor / hata / kapalı / dolu / başvuru durumları | etkinlik2, events_layout, events_page, event_club_rule, pages_b, back_navigation, robustness, visual_b | `event*, evd*` | 15 |
| 75 | `EventFormPage` | `features/events/event_form_page.dart` (973) | E | Etkinlikler + / EventDetail düzenle; `POST/PATCH /events`, `DELETE /events/{id}/cover` | Kulüp seçimi (zorunlu), kapak, tarih/saat, yer, kontenjan; incelemede diyaloğu | yükleniyor / hata / 202 inceleme | etkinlik2, events_cover, events_layout, event_club_rule, visual_b | `event*, evd*, etkinlik2*` | 15 |
| 76 | `Etkinlik2SettingsPage` | `features/events/etkinlik2_settings_page.dart` (289) | E | EventDetail (organizatör); `GET/PUT /events/{id}/admission`, `/chat-room`, `DELETE` | Katılım türü, kontenjan, kayıt aç/kapat, sohbet aç/kapat, iptal | yükleniyor / hata | etkinlik2 | `etkinlik2*, event*` | 16 |
| 77 | `Etkinlik2RequestsPage` | `features/events/etkinlik2_requests_page.dart` (349) | E | EventDetail (organizatör); `GET /events/{id}/requests?status=` | Kontenjan sayacı, bekleyenler Onayla/Reddet, yanıtlananlar | yükleniyor / boş / hata / dolu uyarısı | etkinlik2 | `etkinlik2*` | 16 |
| 78 | `Etkinlik2QrPage` | `features/events/etkinlik2_qr_page.dart` (254) | E | EventDetail (organizatör); `GET /events/{id}/checkin-code`, `/attendance` | QR (`QrView` özel boyacı) + elle kod + yenilenme sayacı + N/M geldi | yükleniyor / hata / süre doldu | etkinlik2, qr_painter, b2_audit, store_shots | `etkinlik2*, event*` | 16 |
| 79 | `Etkinlik2AttendancePage` | `features/events/etkinlik2_attendance_page.dart` (257) | E | EventDetail / QR sayfası; `GET/PUT /events/{id}/attendance` | Özet, Hepsi/Geldi/Gelmedi süzgeci, elle yoklama anahtarı | yükleniyor / boş / hata | etkinlik2 | `etkinlik2*` | 16 |

### J. Akademik

| No | Ekran (sınıf) | Dosya (satır) | T | Nasıl açılır / uçlar | Ana içerik | Durumlar | Test | l10n | Pk |
|---|---|---|---|---|---|---|---|---|---|
| 80 | `TimetablePage` | `features/academic/timetable_page.dart` (441) | E | Akademik giriş / push (CLASS); `GET /timetable`, `DELETE /timetable/courses|semesters` | Dönem düğmesi, gün şeridi, renkli ders blokları, alt eylem çubuğu | yükleniyor / boş / hata / bayat | akad_design, academic_features | `acad*` | 17 |
| 81 | `CourseFormPage` | `features/academic/course_form_page.dart` (378) | E | TimetablePage ekle/düzenle; pop=true | Ders adı, çoklu oturum (gün/saat/yer), renk | doğrulama / hata | akad_design | `acad*` | 17 |
| 82 | `ExamsPage` | `features/academic/exams_page.dart` (318) | E | Akademik giriş / push (EXAM); `GET /timetable/exams`, resmi sınav programı | Kişisel sınavlar (geri sayım) + resmi program | yükleniyor / boş / hata / bayat | akad_design, academic_features | `acad*` | 17 |
| 83 | `ExamFormPage` | `features/academic/exam_form_page.dart` (216) | E | ExamsPage ekle/düzenle; pop=true | Sınav adı, ders, tarih/saat, yer, tür | doğrulama / hata | akad_design | `acad*, akademik*` | 17 |
| 84 | `AcademicHubPage` | `features/academic/academic_hub_page.dart` (227) | E | Profil > Akademik | Ders programı, sınavlar, takvim, bölüm duyuruları kartları | boş (bölüm yok) / erişilebilirlik | academic_features, notif_design | `acad*, acadhub*` | 20 |
| 85 | `AcademicCalendarPage` | `features/academic/academic_calendar_page.dart` (288) | E | Akademik giriş; `GET /academic/calendar?month=`, `/next` | Ay görünümü + önemli tarihler | yükleniyor / hata / boş | academic_features, akad_design | `acad*` | 20 |
| 86 | `AnnouncementsPage` | `features/academic/announcements_page.dart` (329) | E | Akademik giriş; `GET /announcements` | Imleçli akış, okunmamış rozeti, sabitlenmişler, Bölümüm | Tümü | yükleniyor / boş / hata | academic_features, akad_design | `acad*` | 20 |
| 87 | `AnnouncementDetailPage` | `features/academic/announcements_page.dart` (329) | E | Duyuru listesi / push (DEPT_ANNOUNCEMENT); `GET /announcements/{id}` (okundu işaretler) | Duyuru metni | yükleniyor / hata | yok | `acad*` | 20 |
| 88 | `ReminderSettingsPage` | `features/academic/reminder_settings_page.dart` (98) | E | Ayarlar > Hatırlatmalar (bildirim tercihleri sayfasından) | Ders ve sınav yerel bildirim ayarları | izin yok | academic_features, akad_design | `acad*, akademik*` | 20 |

### K. Profil ve hesap

| No | Ekran (sınıf) | Dosya (satır) | T | Nasıl açılır / uçlar | Ana içerik | Durumlar | Test | l10n | Pk |
|---|---|---|---|---|---|---|---|---|---|
| 89 | `UserProfilePage` | `features/profile/user_profile_page.dart` (746) | E | Avatar/sohbet/arama/push (`openUserProfile`); `GET /users/{id}`, `/presence`, `POST /users/{id}/block`, `POST /conversations` | Bilgiler, çevrimiçi, takip, mesaj/engelle/şikâyet, gönderi ızgarası | iskelet / hata / engelli / gizli alanlar | user_profile, icerik, visual_c | `profile*, user*` | 20 |
| 90 | `_AvatarViewer` | `features/profile/user_profile_page.dart` (746) | Z | UserProfilePage avatara dokunma | Tam ekran avatar | — | user_profile (dolaylı) | `profile*` | 20 |
| 91 | `UserPostsPage` | `features/posts/user_posts_page.dart` (150) | E | Profil gönderiler bölümü; `GET /posts/mine` / kullanıcı gönderileri | Kullanıcının gönderi listesi (imleçli) | yükleniyor / boş / hata | gonderi_sade, visual_a | `post*` | 18 |
| 92 | `FollowListPage` | `features/follow/follow_list_page.dart` (292) | E | Profil takipçi/takip sayıları; `GET /users/{id}/followers|following` | İki sekme, kullanıcı satırı + Takip | yükleniyor / boş / hata | profilyard | `followers*, following*, follow*` | 18 |
| 93 | `FollowSuggestionsPage` | `features/follow/follow_suggestions.dart` (116) | E | ProfileTab; `GET /users/me/follow-suggestions` | Önerilen kişiler | yükleniyor / boş / hata | yok | `follow*` | 18 |
| 94 | `EditProfilePage` | `features/profile/edit_profile_page.dart` (530) | E | Profil sekmesi / UserProfile (kendi); `PATCH /users/me`, `DELETE /users/me/avatar` | Avatar, ad, bio, akademik alanlar, vazgeç onayı | yükleniyor / hata | pages_c, profil1, academic, visual_c | `profile*, profil1*` | 19 |
| 95 | `SettingsPage` | `features/profile/settings_page.dart` (340) | E | Profil sekmesi; `PATCH /users/me`, `POST /auth/logout-all` | Dil seçici (alt sayfa), bildirim satırı, hata raporu anahtarı, rehber eşleştirme girişi, tüm cihazlardan çıkış | yükleniyor / hata | pages_c, crash_reporter, back_navigation, l10n, visual_c | `settings*, push*` | 19 |
| 96 | `AccountSecurityPage` | `features/profile/account_security_page.dart` (252) | E | Ayarlar; `POST /auth/change-password`, logout-all | E-posta, şifre güncelle, tüm cihazlardan çıkış | hata | profil2 | `profil*` | 19 |
| 97 | `PrivacyDataPage` | `features/profile/privacy_data_page.dart` (324) | E | Ayarlar > Gizlilik; `GET/PATCH /users/me/privacy` | Alan bazlı görünürlük, e-posta anahtarı, engellenenler | yükleniyor / hata | profil2, academic, visual_c | `profil*` | 19 |
| 98 | `MyDataPage` | `features/profile/profil2_my_data_page.dart` (148) | E | Gizlilik > Verilerim; `GET /users/me/export` (günde 3) | KVKK veri indirme, aydınlatma, silme girişi | hata / sınır | profil2 | `profil2*` | 19 |
| 99 | `DeleteAccountPage` | `features/profile/profil2_delete_account_page.dart` (389) | E | Verilerim / yeniden onay `Kabul etmiyorum`; `DELETE /users/me` | Uyarı, 'neler olur', onay kutusu, tehlike düğmesi | hata | profil2, b4, visual_c | `profil2*` | 19 |
| 100 | `NotificationPrefsPage` | `features/profile/notification_prefs_page.dart` (484) | E | Ayarlar; `GET/PUT /notifications/preferences` | Push durumu, ana anahtarlar, ayrıntılı tercihler, sessiz saatler | yükleniyor / hata / geri alma | profil1, pages_c, push_notify | `profil*, profile*` | 20 |
| 101 | `BlockedUsersPage` | `features/profile/blocked_users_page.dart` (210) | E | Gizlilik; `GET /users/me/blocks`, `DELETE /users/{id}/block` | Engellenenler ve kaldırma | yükleniyor / boş / hata | pages_c, profilyard, back_navigation, robustness, visual_c | `profile*, profilyard*` | 20 |

## 2. Alt sayfa, diyalog, seçici ve katman envanteri

Tür: SH modal alt sayfa, DG diyalog, GD `showGeneralDialog` katmanı, DP tarih seçici, TP saat seçici, PK tam ekran seçici rotası. Her satır bir çağrı noktasıdır (`dosya:satır`).

| No | Çağrı noktası | Tür | Ne | Pk |
|---|---|---|---|---|
| A1 | `core/permissions/ensure_permission.dart:83` | SH | İzin reddedildi/kalıcı reddedildi -> ayarlara git alt sayfası (`_showSettingsSheet`) | 1 |
| A2 | `features/legal/legal_reaccept_page.dart:162` | SH | 'Kabul etmiyorum' seçenekleri (hesabı sil / çıkış yap) | 1 |
| A3 | `widgets/academic_picker.dart:54` | PK | Bölüm seçici tam ekran rota (`_DepartmentPicker`) | 2 |
| A4 | `widgets/academic_picker.dart:72` | PK | Sınıf seçici tam ekran rota (`_GradePicker`) | 2 |
| A5 | `widgets/report_sheet.dart:57` | SH | Şikâyet alt sayfası: USER/POST/COMMUNITY/EVENT + mesaj için `showForMessage`; 6 kullanım yeri | 0 |
| A6 | `features/posts/compose_post_page.dart:112` | DG | Gönderiyi at/devam onayı | 4 |
| A7 | `features/posts/post_actions.dart:39` | GD | Gönderi ⋯ menü katmanı (`_PostMenuOverlay`: düzenle/sil/şikâyet/engelle) | 4 |
| A8 | `features/posts/post_actions.dart:51` | DG | Gönderi metin düzenleme (`_EditDialog`, 7 kelime, 422 küfür iletisi) | 4 |
| A9 | `features/posts/post_actions.dart:72` | DG | Gönderi silme onayı | 4 |
| A10 | `features/posts/post_actions.dart:98` | DG | Yazarı engelleme onayı | 4 |
| A11 | `features/chat/conversation_actions.dart:43` | SH | Sohbet sessize alma süresi (8 sa/1 hafta/süresiz) alt sayfası | 6 |
| A12 | `features/chat/conversation_actions.dart:74` | DG | Sohbeti sil/ayrıl onayı (grup/birebir metni) | 6 |
| A13 | `features/chat/chat_detail_page.dart:1072` | DG | 'Video hazırlanıyor %N' ilerleme penceresi (`_VideoPrepareDialog`, iptal edilebilir) | 7 |
| A14 | `features/chat/chat_detail_page.dart:1336` | DG | Onay diyaloğu (sil/vazgeç: `chatDetailNevermind`) | 7 |
| A15 | `features/chat/chat_detail_page.dart:1666` | SH | Sohbet menüsü (sohbette ara, üyeler, bilgi...) | 7 |
| A16 | `features/chat/chat_detail_page.dart:1768` | SH | Üyeler alt sayfası (grup/kulüp/etkinlik) | 7 |
| A17 | `features/chat/message_actions.dart:36` | GD | Mesaj uzun basma katmanı: emoji tepkileri + eylem listesi (yanıtla/kopyala/düzenle/sil/ilet/şikâyet) | 7 |
| A18 | `features/chat/forward_sheet.dart:13` | SH | Mesaj iletme alt sayfası (`showSohbetySheet` çerçevesi; `GET /conversations?size=50`) | 9 |
| A19 | `features/chat/sohbety_add_members.dart:15` | SH | Gruba üye ekleme alt sayfası | 9 |
| A20 | `features/chat/chat_info_page.dart:173` | DG | Onay (gruptan çık / engelle) | 9 |
| A21 | `features/chat/chat_info_page.dart:240` | SH | Sohbet sessize alma süresi | 9 |
| A22 | `features/chat/chat_info_page.dart:401` | DG | Grup adı değiştirme (`_RenameDialog`) | 9 |
| A23 | `features/chat/chat_info_page.dart:420` | SH | Grup fotoğrafı kaynağı (galeri/kamera/kaldır) | 9 |
| A24 | `features/chat/media_picker_page.dart:228` | SH | Albüm seçici alt sayfası | 10 |
| A25 | `features/chat/sohbety_sheet.dart:11` | SH | Ortak sohbet alt sayfa çerçevesi `SohbetySheetFrame` (kapı tutamacı, başlık) | 10 |
| A26 | `features/clubs/club_actions.dart:21` | DG | Kulüpten ayrılma onayı | 11 |
| A27 | `features/clubs/club_actions.dart:51` | DG | 'Sahip ayrılamaz' uyarısı | 11 |
| A28 | `features/clubs/club_detail_page.dart:295` | DG | Kulüp silme son onayı (kulüp adını yazdır, `_DeleteClubDialog`) | 11 |
| A29 | `features/clubs/club_detail_page.dart:403` | DG | Kulüp gönderisini silme onayı | 11 |
| A30 | `features/polls/poll_form_page.dart:61` | DP | Anket bitiş tarihi | 11 |
| A31 | `features/polls/poll_form_page.dart:64` | TP | Anket bitiş saati | 11 |
| A32 | `features/clubs/club_form_page.dart:29` | DG | 'Kulüp başvurunuz incelemede' bilgi diyaloğu | 12 |
| A33 | `features/clubs/club_join_flow.dart:34` | SH | Katılım soruları alt sayfası (`_JoinQuestionsSheet`) | 12 |
| A34 | `features/polls/poll_detail_page.dart:98` | DG | Oyu geri çekme onayı | 13 |
| A35 | `features/support/support_ticket_page.dart:83` | DG | Talebi kapatma onayı | 13 |
| A36 | `features/events/event_parts.dart:143` | DG | Etkinliği listeden kaldır/kapat onayı (`eventListDismiss`) | 14 |
| A37 | `features/events/etkinlik2_apply_sheet.dart:19` | SH | Etkinliğe katılma isteği formu (`_ApplySheet`, organizatör soruları) | 15 |
| A38 | `features/events/event_form_page.dart:182` | SH | Etkinlik kapağı kaynağı (galeri/kamera) | 15 |
| A39 | `features/events/event_form_page.dart:289` | DP | Etkinlik başlangıç tarihi | 15 |
| A40 | `features/events/event_form_page.dart:299` | TP | Etkinlik saati | 15 |
| A41 | `features/events/event_form_page.dart:316` | DP | Etkinlik bitiş tarihi | 15 |
| A42 | `features/events/event_form_page.dart:557` | DG | 'Etkinliğiniz incelemede' diyaloğu (202 PENDING_REVIEW) | 15 |
| A43 | `features/events/event_form_page.dart:638` | SH | Kulüp seçici alt sayfası (`etkinlik2ClubSheetTitle`, zorunlu kulüp) | 15 |
| A44 | `features/academic/timetable_page.dart:90` | SH | Dönem alt sayfası (`SemesterSheet`) | 17 |
| A45 | `features/academic/semester_sheet.dart:81` | DG | Yeni dönem diyaloğu (`_NewSemesterDialog`) | 17 |
| A46 | `features/academic/semester_sheet.dart:257` | DP | Dönem başlangıç/bitiş tarihi | 17 |
| A47 | `features/academic/course_form_page.dart:84` | TP | Ders oturumu saati | 17 |
| A48 | `features/academic/exam_form_page.dart:64` | TP | Sınav saati | 17 |
| A49 | `features/academic/exam_form_page.dart:171` | DP | Sınav tarihi | 17 |
| A50 | `features/academic/academic_widgets.dart:165` | DG | Ders/sınav/dönem silme onayı (ortak) | 17 |
| A51 | `features/profile/profile_tab.dart:94` | DG | Çıkış yapma onayı | 18 |
| A52 | `features/profile/profil_widgets.dart:243` | SH | Seçenek listesi alt sayfası `showProfilChoiceSheet` (tema ve dil seçimi) | 18 |
| A53 | `features/profile/edit_profile_page.dart:123` | DG | Değişiklikleri at/devam onayı | 19 |
| A54 | `features/profile/edit_profile_page.dart:284` | SH | Avatar kaynağı (galeri/kamera/kaldır) | 19 |
| A55 | `features/profile/settings_page.dart:72` | DG | Tüm cihazlardan çıkış onayı | 19 |
| A56 | `features/profile/settings_page.dart:143` | SH | Dil seçici alt sayfası (sistem/TR/EN/AR) | 19 |
| A57 | `features/profile/account_security_page.dart:110` | DG | Tüm cihazlardan çıkış onayı (ikinci kopya) | 19 |
| A58 | `features/profile/profil2_delete_account_page.dart:26` | SH | Şifre isteyen silme onayı (`DeleteConfirmSheet`, klavye ile yukarı kayar) | 19 |
| A59 | `features/profile/notification_prefs_page.dart:290` | TP | Sessiz saat başlangıç/bitiş | 20 |
| A60 | `features/profile/user_profile_page.dart:197` | DG | Kullanıcıyı engelleme onayı | 20 |

Ek notlar: (a) `showSohbetySheet` (sohbet ortak alt sayfa çerçevesi), `showProfilChoiceSheet` (profil seçenek listesi), `ReportSheet` ve `PermissionInfo` sheet'i aynı işi (başlıklı modal çerçeve) dört ayrı biçimde yapıyor; P0 `BuSheet` ile birleştirir. (b) Onay diyaloğu 25 yerde elle yazılmış `AlertDialog` (Vazgeç/Sil çiftleri); P0 `BuConfirmDialog` sağlar. (c) Tarih/saat seçicileri Material varsayılan tema ile açılıyor; P0 `BuPickerTheme` sağlar.

## 3. Navigasyon haritası ve push hedefleri

**Kök karar ağacı** (`main.dart` -> `BingolApp.home`): `accessBlocked` ise `AccessBlockedScreen`; yoksa `SessionState`: `loading` -> `SplashScreen`; `signedOut` -> `_SignedOutRoot` (ilk açılışta `WelcomePage`, sonra `LoginPage`); `signedIn` -> `PostLoginGate` (izin sayfası, cihaz başına bir kez) -> `LegalReacceptGate` (bekleyen sözleşme varsa tam ekran) -> `AppShell` (5 sekme, `IndexedStack`). Tüm bu ağacın üstünde `MaterialApp.builder`: `AppGate` (sürüm/bakım/duyuru/çevrimdışı) + `OfflineBanner`. Ön planda push şeridi `PushBannerCenter` (`push_banner.dart`).

**Sekmeden sayfaya akışlar:** Ana Sayfa -> Haber listesi (Haber/Duyuru/Etkinlik) / Yemek / Etkinlik detayı / Anketler / Bildirimler / Arama; Keşfet -> Arama, Gönderi oluştur, Gönderi detayı, Kullanıcı profili; Sohbet -> Sohbet detayı, Yeni sohbet (+ rehber), Sohbet bilgisi; Kulüpler -> Kulüp detayı (-> üyeler, istekler, anket, etkinlik, sohbet), Kulüp kur; Profil -> Düzenle, Ayarlar (-> Hesap/Gizlilik/Verilerim/Hesabı sil/Bildirim tercihleri/Hatırlatmalar/Sözleşmeler), Kulüplerim, Etkinliklerim, Favoriler, Akademik (-> Ders programı/Sınavlar/Takvim/Duyurular), Destek (-> Talep/Geri bildirim/Öneriler), Takipçi listeleri.

**Push hedefleri** (`core/push/push_targets.dart` + `push_router.dart`, DAVRANIŞ KATMANI, değişmez):

| `PushDest` | Açılan ekran (numara bölüm 1'de) | Not |
|---|---|---|
| conversation | ChatDetailPage | `GET /conversations/{id}` sarmalayıcısı çözülür |
| chatList | Sohbet sekmesi | `shellTabRequest=2`, açık rotalar kapanır |
| event | EventDetailPage | |
| community | ClubDetailPage | |
| news | NewsDetailPage | |
| post | PostDetailPage (`openPostDetail`) | `commentId` artık yok sayılır |
| poll | PollDetailPage (`openPollDetail`) | |
| user | UserProfilePage (`openUserProfile`) | STORY/FOLLOW da buraya |
| deptAnnouncement | AnnouncementDetailPage | |
| timetable | TimetablePage | kimliksiz geçerli |
| exams | ExamsPage | kimliksiz geçerli |
| ticket | SupportTicketPage | |
| feedback | SupportPage | |
| notifications | NotificationsPage | bilinmeyen/bozuk yük ve hata yedeği |
| signOut | oturum kapanır (`session_replaced`) | ekran yok |

Sonuç: bir ekranın **kurucu imzası** (örn. `EventDetailPage(session:, eventId:)`, `ChatDetailPage(session:, conversation:)`, `ClubDetailPage(session:, communityId:)`) push, arama, profil ve diğer sayfalardan çağrıldığından yeniden tasarımda DEĞİŞMEZ (yalnız isteğe bağlı parametre eklenir).

## 4. İş paketleri (Paket 0 + 20 paket)

Dağıtım ilkesi: ekran/akış bütünlüğü korunur; her UI dosyası **tam bir pakete** aittir (ayrık küme, doğrulandı: çakışma 0, atanmamış UI dosyası 0). Paylaşılan temel (`lib/widgets/`, `lib/core/theme*`, `typography`) yalnız Paket 0'ındır. Dosyayı çok pakette kullanılan modül yerel widget dosyaları (`auth_widgets`, `profil_widgets`, `profily_widgets`, `icerik_parts`, `event_parts`, `etkinlik2_widgets`, `kulup_widgets`, `sohbety_widgets`, `akad_widgets`, `destek_widgets`, `anket_style`) tek **sahip** pakete verildi; tüketen paketler bunların **imzasını** kullanır (bölüm 5.4 kural 17).

### 4.1 Özet tablo

| Pk | Paket | Ekran no (bölüm 1) | UI dosya | Satır | İş yükü | Dalga | Alt sayfa |
|---|---|---|---|---|---|---|---|
| 0 | TEMEL (foundation): tasarım belirteçleri, ortak bileşenler, test altyapısı | — | 8 | 1.981 | M-L (≈ 1 ajan, önce) | — | 1 |
| 1 | Açılış, kapılar, durum ekranları, izinler, sözleşme ve QR tarayıcı | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 | 11 | 2.570 | M | Dalga 2 | 2 |
| 2 | Kimlik: karşılama, giriş, kayıt, doğrulama, şifre sıfırlama, akademik seçici | 20, 21, 22, 23, 24, 25, 26, 27, 28, 29 | 18 | 5.115 | M | Dalga 1 | 2 |
| 3 | Ana Sayfa, Yemek listesi, Bildirimler | 32, 37, 38 | 6 | 2.018 | M | Dalga 2 | 0 |
| 4 | Keşfet sekmesi ve gönderiler (oluştur, detay, kart, eylemler) | 33, 39, 40 | 9 | 2.235 | M | Dalga 2 | 5 |
| 5 | Haber (liste/detay/favoriler) ve Arama | 41, 42, 43, 44 | 6 | 2.283 | M | Dalga 1 | 0 |
| 6 | Sohbet listesi, yeni sohbet, rehberden bul | 34, 45, 46 | 5 | 2.135 | M | Dalga 2 | 2 |
| 7 | Sohbet detayı (konuşma ekranı + mesaj eylem katmanı) | 47 | 2 | 2.826 | XL | Dalga 2 | 5 |
| 8 | Mesaj balonu ve medya görüntüleyiciler (görsel/video/tek gösterimlik) | 48, 49, 50, 51 | 8 | 2.503 | L | Dalga 1 | 0 |
| 9 | Sohbet bilgisi, üyeler, iletme, gruba üye ekleme | 52, 53, 54 | 6 | 2.025 | M | Dalga 2 | 6 |
| 10 | Medya seçici, kamera, önizleme + sohbet ortak bileşenleri | 55, 56, 57 | 7 | 2.209 | M | Dalga 1 | 2 |
| 11 | Kulüp detayı, üyeler, istekler, kulüp anket oluşturma | 58, 59, 60, 61 | 7 | 2.353 | M | Dalga 1 | 6 |
| 12 | Kulüpler sekmesi, kulüp kur/düzenle, katılım akışı, Kulüplerim | 35, 62, 63, 64 | 6 | 1.800 | M | Dalga 2 | 2 |
| 13 | Anketler (liste/detay) ve Destek (SSS, talep, geri bildirim, öneri) | 65, 66, 67, 68, 69, 70, 71 | 13 | 2.641 | L | Dalga 1 | 2 |
| 14 | Etkinlik listesi (Etkinlikler sayfası, Etkinliklerim, ortak etkinlik kartları) | 72, 73 | 5 | 2.148 | M | Dalga 1 | 1 |
| 15 | Etkinlik detayı, etkinlik formu, katılma isteği | 74, 75 | 3 | 2.092 | M-L | Dalga 2 | 7 |
| 16 | Etkinlik organizatör araçları ve QR (ayarlar, istekler, QR, yoklama, QR boyacı) | 76, 77, 78, 79 | 6 | 2.106 | M | Dalga 1 | 0 |
| 17 | Akademik 1: ders programı, ders/sınav formları, dönem, ortak akademik bileşenler | 80, 81, 82, 83 | 7 | 2.403 | M-L | Dalga 1 | 7 |
| 18 | Kabuk (AppShell/FloatingNav) + Profil sekmesi + takip + kullanıcı gönderileri + profil ortak bileşenleri | 30, 31, 36, 91, 92, 93 | 13 | 2.751 | M-L | Dalga 1 | 2 |
| 19 | Profil düzenle, Ayarlar, Hesap/güvenlik, Gizlilik, Verilerim, Hesabı sil | 94, 95, 96, 97, 98, 99 | 7 | 2.217 | M | Dalga 2 | 6 |
| 20 | Akademik 2 (giriş, takvim, duyuru, hatırlatma), başkasının profili, bildirim tercihleri, engellenenler | 84, 85, 86, 87, 88, 89, 90, 100, 101 | 8 | 2.512 | M-L | Dalga 2 | 2 |

İş yükü: S/M/L/XL mutlak satır sayısından çok karmaşıklığa göredir (tek dosyada 2.478 satırlık sohbet detayı XL; çok sayıda küçük form/liste dosyası olan akademik/destek paketleri satırca büyük ama düşük risklidir). **Dalga 1** = ortak modül widget'ının sahibi (üretici), **Dalga 2** = bu widget'ları tüketen paketler. Kural 17 imza uyumunu zorunlu kıldığından dalgalar kesin sıra değil, **birleştirme önceliğidir**: Dalga 2 paketleri, sahiplerinin yeni görünümünü görmek için Dalga 1 bitince rebase eder.

### 4.2 Paket ayrıntıları

#### Paket 0: TEMEL (foundation): tasarım belirteçleri, ortak bileşenler, test altyapısı

- **Ekranlar:** yok (bileşen paketi); alt sayfa `ReportSheet`
- **Alt sayfa / diyalog:** A5
- **Dosyalar (8, 1.981 satır):** `core/theme.dart`(260), `core/theme_controller.dart`(34), `core/typography.dart`(33), `widgets/bu_widgets.dart`(683), `widgets/common.dart`(272), `widgets/report_sheet.dart`(229), `widgets/simple_markdown.dart`(247), `widgets/sistem_widgets.dart`(223)
- **Test dosyaları:** `bu_widgets_test`, `theme_test`, `format_test`, l10n_test (ortak), sistem_design_test (ortak 0/1)
- **Bağımlılık:** Hiçbiri (ilk). Çıktısı tüm paketlerin girdisidir.
- **İş yükü / dalga:** M-L (≈ 1 ajan, önce) / —
- **P0'dan beklenen:** —

#### Paket 1: Açılış, kapılar, durum ekranları, izinler, sözleşme ve QR tarayıcı

- **Ekranlar:** 1 SplashScreen, 2 ConfigErrorApp, 3 _ErrorView (ErrorWidget), 4 AppGate, 5 UpdateRequiredScreen, 6 MaintenanceScreen, 7 OfflineScreen, 8 AccessBlockedScreen, 9 TopStrip (şerit), 10 UpdateNotice (alt bildirim), 11 OfflineBanner + StaleLabel, 12 PushBanner (_BannerHost), 13 PostLoginGate, 14 PermissionsPage, 15 LegalReacceptGate, 16 LegalReacceptPage, 17 LegalListPage, 18 LegalDocPage, 19 QrScanPage
- **Alt sayfa / diyalog:** A1, A2
- **Dosyalar (11, 2.570 satır):** `core/app_gate.dart`(264), `core/connectivity/offline_banner.dart`(78), `core/permissions/ensure_permission.dart`(120), `core/push/push_banner.dart`(155), `features/auth/permissions_page.dart`(414), `features/legal/legal_reaccept_page.dart`(288), `features/platform/qr_scan_page.dart`(348), `features/profile/legal_pages.dart`(226), `features/system/gate_views.dart`(221), `features/system/splash_screen.dart`(161), `main.dart`(295)
- **Test dosyaları:** `legal_reaccept_test`, `permissions_test`, `offline_banner_test`, `push_foreground_test`, `app_gate_test`, `api_config_test`
- **Bağımlılık:** P0. Tüketir: auth_widgets/login/register/welcome (P2), destek_widgets (P13), app_shell (P18), profil2_delete_account_page (P19). `ensure_permission`, `offline_banner`, `qr_scan_page`, `legal_pages` başka paketlerce kullanılır (imzalar korunur).
- **İş yükü / dalga:** M / Dalga 2
- **P0'dan beklenen:** BuStateView (bakım/çevrimdışı/güncelleme/erişim engeli), BuBand (şerit), BuSheet (izin), BuMotion, BuSkeleton

#### Paket 2: Kimlik: karşılama, giriş, kayıt, doğrulama, şifre sıfırlama, akademik seçici

- **Ekranlar:** 20 WelcomePage, 21 LoginPage, 22 RegisterPage, 23 VerifyCodePage, 24 ForgotPasswordPage, 25 ResetCodePage, 26 NewPasswordPage, 27 ResetSuccessPage (YENİ), 28 Bölüm seçici (_DepartmentPicker), 29 Sınıf seçici (_GradePicker)
- **Alt sayfa / diyalog:** A3, A4
- **Dosyalar (18, 5.115 satır):** `features/auth/auth_widgets.dart`(507), `features/auth/forgot_password_page.dart`(93), `features/auth/login_page.dart`(263), `features/auth/new_password_page.dart`(123), `features/auth/otp_code_boxes.dart`(193), `features/auth/register_page.dart`(411), `features/auth/reset_code_page.dart`(131), `features/auth/reset_success_page.dart`(83), `features/auth/verify_code_page.dart`(180), `features/auth/welcome_page.dart`(304), `features/auth/widgets/auth_academic.dart`(253), `features/auth/widgets/auth_art.dart`(501), `features/auth/widgets/auth_controls.dart`(579), `features/auth/widgets/auth_fields.dart`(322), `features/auth/widgets/auth_motion.dart`(247), `features/auth/widgets/auth_sheets.dart`(289), `features/auth/widgets/auth_shell.dart`(244), `widgets/academic_picker.dart`(392)
- **Test dosyaları:** `student_number_test`, `single_session_test`, `auth_test`, auth_shots_test (izlenmiyor, başka süreç ekledi), academic_test (ortak 2/19)
- **Bağımlılık:** P0. Tüketir: legal_pages (P1). `auth_widgets`/`academic_picker` P1/P19 tarafından kullanılır. NOT: başka bir süreç bu paketin dosyalarında şu an çalışıyor (bkz. Riskler).
- **İş yükü / dalga:** M / Dalga 1
- **P0'dan beklenen:** BuField (metin alanı), BuButton, BuPageScaffold, OTP kutusu stilleri tokenları, BuMotion

#### Paket 3: Ana Sayfa, Yemek listesi, Bildirimler

- **Ekranlar:** 32 HomeTab, 37 MenuPage (Yemek), 38 NotificationsPage
- **Dosyalar (6, 2.018 satır):** `features/home/home_parts.dart`(268), `features/home/home_tab.dart`(749), `features/menu/menu_page.dart`(341), `features/menu/menu_photo.dart`(45), `features/notifications/notif_row.dart`(150), `features/notifications/notifications_page.dart`(465)
- **Test dosyaları:** `home_redesign_test`, `menu_photo_test`, `yemek_page_test`, `notif_design_test`, push_notify_test (ortak)
- **Bağımlılık:** P0. Tüketir: news_tile/news_detail/search (P5), poll_menu_card/support_page (P13), event_cover/event_parts/events_page (P14), event_detail (P15), academic_hub (P20), offline_banner (P1), app_shell (P18).
- **İş yükü / dalga:** M / Dalga 2
- **P0'dan beklenen:** BuCard/BuHeroCard, BuSkeleton (kart + satır), BuImage, BuListRow, BuStateView

#### Paket 4: Keşfet sekmesi ve gönderiler (oluştur, detay, kart, eylemler)

- **Ekranlar:** 33 DiscoverTab, 39 ComposePostPage, 40 PostDetailPage
- **Alt sayfa / diyalog:** A6, A7, A8, A9, A10
- **Dosyalar (9, 2.235 satır):** `features/discover/discover_masonry.dart`(626), `features/discover/discover_tab.dart`(137), `features/posts/compose_post_page.dart`(374), `features/posts/like_button.dart`(321), `features/posts/post_actions.dart`(352), `features/posts/post_card.dart`(191), `features/posts/post_detail_page.dart`(127), `features/posts/post_media_uploader.dart`(87), `features/posts/post_routes.dart`(20)
- **Test dosyaları:** `discover_masonry_test`, `gonderi_sade_test`
- **Bağımlılık:** P0. Tüketir: search_page (P5), poll_routes (P13), user_posts_page (P18), user_profile_page (P20). `post_card`/`like_button` P18/P20 profil ızgaralarında kullanılır.
- **İş yükü / dalga:** M / Dalga 2
- **P0'dan beklenen:** BuImage (masonry, ağ), BuSkeleton (masonry), BuSheet/menü katmanı, BuConfirmDialog

#### Paket 5: Haber (liste/detay/favoriler) ve Arama

- **Ekranlar:** 41 NewsListPage, 42 NewsDetailPage, 43 SavedNewsPage, 44 SearchPage
- **Dosyalar (6, 2.283 satır):** `features/news/icerik_parts.dart`(223), `features/news/news_detail_page.dart`(349), `features/news/news_list_page.dart`(395), `features/news/news_tile.dart`(264), `features/profile/saved_news_page.dart`(233), `features/search/search_page.dart`(819)
- **Test dosyaları:** `icerik_test`
- **Bağımlılık:** P0. Tüketir: club_detail (P11), event_detail (P15), user_profile (P20), post_routes (P4), offline_banner (P1). `icerik_parts`/`news_tile` P3/P18/P20 tarafından kullanılır.
- **İş yükü / dalga:** M / Dalga 1
- **P0'dan beklenen:** BuImage, BuSkeleton (liste), BuSegmented/sekme, BuStateView (bakım/bayat), BuListRow

#### Paket 6: Sohbet listesi, yeni sohbet, rehberden bul

- **Ekranlar:** 34 ChatTab, 45 NewChatPage, 46 ContactsMatchPage
- **Alt sayfa / diyalog:** A11, A12
- **Dosyalar (5, 2.135 satır):** `features/chat/chat_tab.dart`(947), `features/chat/chatlist_widgets.dart`(213), `features/chat/contacts_match_page.dart`(378), `features/chat/conversation_actions.dart`(98), `features/chat/new_chat_page.dart`(499)
- **Test dosyaları:** `chatlist_design_test`, `contacts_match_test`, sohbety_design_test (ortak 6/9/10)
- **Bağımlılık:** P0 + P10 (`sohbety_widgets`) + P8 (`message_bubble`) arayüzü. Tüketir: chat_detail/message_actions (P7), ensure_permission (P1), user_profile (P20).
- **İş yükü / dalga:** M / Dalga 2
- **P0'dan beklenen:** BuListRow (konuşma), BuSkeleton (liste), BuSheet, BuConfirmDialog, BuSearchField

#### Paket 7: Sohbet detayı (konuşma ekranı + mesaj eylem katmanı)

- **Ekranlar:** 47 ChatDetailPage
- **Alt sayfa / diyalog:** A13, A14, A15, A16, A17
- **Dosyalar (2, 2.826 satır):** `features/chat/chat_detail_page.dart`(2478), `features/chat/message_actions.dart`(348)
- **Test dosyaları:** `chat_offline_test`, chat_extras_test (ortak 6/7/8/10), chatd_bubbles_test (ortak 7/8)
- **Bağımlılık:** P0 + P8 (balon/görüntüleyici) + P9/P10 (sohbet bilgisi, medya seçici). Çıktısı (`ChatDetailPage` kurucusu) push/rota ile kilitli.
- **İş yükü / dalga:** XL / Dalga 2
- **P0'dan beklenen:** BuSheet, BuConfirmDialog, BuMotion (balon giriş/kayma), BuToast, BuImage

#### Paket 8: Mesaj balonu ve medya görüntüleyiciler (görsel/video/tek gösterimlik)

- **Ekranlar:** 48 ChatMediaViewer, 49 ChatVideoPlayerPage, 50 ViewOnceViewer, 51 ChatImageViewer
- **Dosyalar (8, 2.503 satır):** `features/chat/bubble_text_meta.dart`(141), `features/chat/chat_media.dart`(57), `features/chat/chat_media_viewer.dart`(422), `features/chat/chat_video_player.dart`(292), `features/chat/chatd_parts.dart`(198), `features/chat/message_bubble.dart`(1163), `features/chat/message_placeholder.dart`(27), `features/chat/view_once_viewer.dart`(203)
- **Test dosyaları:** `chat_status_video_test`, `media_grid_test`, chatd_bubbles_test (ortak)
- **Bağımlılık:** P0. `MessageBubble`, `ChatMediaViewer`, `ChatVideoPlayerPage` kurucuları P6/P7/P9/P10 tarafından kullanılır (imza kilitli).
- **İş yükü / dalga:** L / Dalga 1
- **P0'dan beklenen:** BuImage (decode boyutu), BuMotion (yakınlaştırma), siyah medya zemin tokenı (`onMedia`/`scrim`)

#### Paket 9: Sohbet bilgisi, üyeler, iletme, gruba üye ekleme

- **Ekranlar:** 52 ChatInfoPage, 53 ChatMembersPage, 54 ChatMediaGridPage
- **Alt sayfa / diyalog:** A18, A19, A20, A21, A22, A23
- **Dosyalar (6, 2.025 satır):** `features/chat/chat_info_media.dart`(330), `features/chat/chat_info_members.dart`(188), `features/chat/chat_info_page.dart`(1122), `features/chat/chat_info_tabs.dart`(35), `features/chat/forward_sheet.dart`(176), `features/chat/sohbety_add_members.dart`(174)
- **Test dosyaları:** `chat_info_test`
- **Bağımlılık:** P0 + P10 (`sohbety_widgets`, `sohbety_sheet`) + P8 (`ChatMediaViewer`).
- **İş yükü / dalga:** M / Dalga 2
- **P0'dan beklenen:** BuListRow/BuGroup, BuSheet, BuConfirmDialog, BuAvatar

#### Paket 10: Medya seçici, kamera, önizleme + sohbet ortak bileşenleri

- **Ekranlar:** 55 MediaPickerPage, 56 MediaPreviewPage, 57 MediaCameraPage
- **Alt sayfa / diyalog:** A24, A25
- **Dosyalar (7, 2.209 satır):** `features/chat/media_camera_page.dart`(253), `features/chat/media_library.dart`(118), `features/chat/media_pick.dart`(105), `features/chat/media_picker_page.dart`(534), `features/chat/media_preview_page.dart`(454), `features/chat/sohbety_sheet.dart`(102), `features/chat/sohbety_widgets.dart`(643)
- **Test dosyaları:** `media_picker_test`
- **Bağımlılık:** P0. `sohbety_widgets` P6/P9 tarafından kullanılır; `MediaPickerPage/MediaPreviewPage/MediaPick` P7 tarafından.
- **İş yükü / dalga:** M / Dalga 1
- **P0'dan beklenen:** BuImage (thumb), BuSheet (albüm), siyah medya zemin tokenı, BuMotion

#### Paket 11: Kulüp detayı, üyeler, istekler, kulüp anket oluşturma

- **Ekranlar:** 58 ClubDetailPage, 59 ClubMembersPage, 60 ClubRequestsPage, 61 PollFormPage
- **Alt sayfa / diyalog:** A26, A27, A28, A29, A30, A31
- **Dosyalar (7, 2.353 satır):** `features/clubs/club_actions.dart`(83), `features/clubs/club_detail_page.dart`(1127), `features/clubs/club_members_page.dart`(247), `features/clubs/club_requests_page.dart`(196), `features/clubs/kulup_widgets.dart`(248), `features/polls/poll_club_section.dart`(97), `features/polls/poll_form_page.dart`(355)
- **Test dosyaları:** `kulup_detay_design_test`, clubs_manage_test (ortak 11/12), polls_test + anket_test (ortak 11/13: yalnız PollForm blokları)
- **Bağımlılık:** P0. Tüketir: club_form/join/categories (P12), poll_parts/anket_style/poll_routes (P13), chat_detail (P7), event_detail/form (P15). `kulup_widgets` P12 ile paylaşılır.
- **İş yükü / dalga:** M / Dalga 1
- **P0'dan beklenen:** BuHeroCard/kapak, BuTabs/BuSegmented, BuListRow, BuConfirmDialog, BuSheet, BuSkeleton

#### Paket 12: Kulüpler sekmesi, kulüp kur/düzenle, katılım akışı, Kulüplerim

- **Ekranlar:** 35 ClubsTab, 62 ClubFormPage, 63 MyClubsPage, 64 (yeniden kullanım) Scaffold(ClubsTab)
- **Alt sayfa / diyalog:** A32, A33
- **Dosyalar (6, 1.800 satır):** `features/clubs/club_categories.dart`(122), `features/clubs/club_form_page.dart`(542), `features/clubs/club_join_flow.dart`(154), `features/clubs/clubs_tab.dart`(398), `features/clubs/clubs_widgets.dart`(289), `features/profile/my_clubs_page.dart`(295)
- **Test dosyaları:** `club_categories_test`, `clubs_tab_design_test`, clubs_manage_test (ortak)
- **Bağımlılık:** P0 + P11 (`kulup_widgets`) + P18 (`profil_widgets`, `profily_widgets`).
- **İş yükü / dalga:** M / Dalga 2
- **P0'dan beklenen:** BuCard, BuChip (kategori), BuField, BuSheet, BuSkeleton (kart), BuImage

#### Paket 13: Anketler (liste/detay) ve Destek (SSS, talep, geri bildirim, öneri)

- **Ekranlar:** 65 PollListPage, 66 PollDetailPage, 67 SupportPage, 68 NewTicketPage, 69 SupportTicketPage, 70 FeedbackPage, 71 SuggestionsPage
- **Alt sayfa / diyalog:** A34, A35
- **Dosyalar (13, 2.641 satır):** `features/polls/anket_style.dart`(179), `features/polls/poll_detail_page.dart`(474), `features/polls/poll_list_page.dart`(208), `features/polls/poll_menu_card.dart`(106), `features/polls/poll_parts.dart`(199), `features/polls/poll_routes.dart`(31), `features/support/destek_widgets.dart`(112), `features/support/support_common.dart`(177), `features/support/support_feedback_page.dart`(233), `features/support/support_new_ticket_page.dart`(89), `features/support/support_page.dart`(347), `features/support/support_suggestions_page.dart`(245), `features/support/support_ticket_page.dart`(241)
- **Test dosyaları:** `polls_test`, `anket_test`, `destek_test`
- **Bağımlılık:** P0 + P18 (`profily_widgets`) + P11 (`poll_form_page`). `destek_widgets` P1 (legal_pages) ile paylaşılır.
- **İş yükü / dalga:** L / Dalga 1
- **P0'dan beklenen:** BuAccordion (SSS), BuSegmented, BuListRow, BuField, BuStateView, BuConfirmDialog, BuProgressBar (anket)

#### Paket 14: Etkinlik listesi (Etkinlikler sayfası, Etkinliklerim, ortak etkinlik kartları)

- **Ekranlar:** 72 EventsPage, 73 MyEventsPage
- **Alt sayfa / diyalog:** A36
- **Dosyalar (5, 2.148 satır):** `features/events/etkinlik_parts.dart`(111), `features/events/event_cover.dart`(42), `features/events/event_parts.dart`(307), `features/events/events_page.dart`(1391), `features/profile/my_events_page.dart`(297)
- **Test dosyaları:** `events_page_test`, `events_layout_test`, `events_cover_test`
- **Bağımlılık:** P0. `event_parts`/`event_cover` P3/P15/P16 tarafından kullanılır. Tüketir: qr_scan/offline_banner (P1), news_detail (P5), event_detail/form (P15), profil_widgets (P18).
- **İş yükü / dalga:** M / Dalga 1
- **P0'dan beklenen:** BuCard (etkinlik kartı), BuSegmented sabit çubuk, BuSkeleton, BuImage, BuConfirmDialog

#### Paket 15: Etkinlik detayı, etkinlik formu, katılma isteği

- **Ekranlar:** 74 EventDetailPage, 75 EventFormPage
- **Alt sayfa / diyalog:** A37, A38, A39, A40, A41, A42, A43
- **Dosyalar (3, 2.092 satır):** `features/events/etkinlik2_apply_sheet.dart`(107), `features/events/event_detail_page.dart`(1012), `features/events/event_form_page.dart`(973)
- **Test dosyaları:** `event_club_rule_test`, etkinlik2_test (ortak 15/16)
- **Bağımlılık:** P0 + P14 (`event_parts`, `event_cover`) + P16 (`etkinlik2_widgets`) + P1 (`qr_scan_page`) + P11/P12 (kulüp rotaları).
- **İş yükü / dalga:** M-L / Dalga 2
- **P0'dan beklenen:** BuField, BuSheet, tarih/saat seçici teması (BuPickerTheme), BuImage (kapak), BuHeroCard

#### Paket 16: Etkinlik organizatör araçları ve QR (ayarlar, istekler, QR, yoklama, QR boyacı)

- **Ekranlar:** 76 Etkinlik2SettingsPage, 77 Etkinlik2RequestsPage, 78 Etkinlik2QrPage, 79 Etkinlik2AttendancePage
- **Dosyalar (6, 2.106 satır):** `features/events/etkinlik2_attendance_page.dart`(257), `features/events/etkinlik2_qr_page.dart`(254), `features/events/etkinlik2_requests_page.dart`(349), `features/events/etkinlik2_settings_page.dart`(289), `features/events/etkinlik2_widgets.dart`(526), `features/events/qr_painter.dart`(431)
- **Test dosyaları:** `qr_painter_test`, etkinlik2_test (ortak)
- **Bağımlılık:** P0 + P14 (`event_parts`). `etkinlik2_widgets` P15 ile paylaşılır.
- **İş yükü / dalga:** M / Dalga 1
- **P0'dan beklenen:** BuCard, BuListRow, BuSwitch, BuStateView, QR zemin tokenı (yüksek kontrast sabit)

#### Paket 17: Akademik 1: ders programı, ders/sınav formları, dönem, ortak akademik bileşenler

- **Ekranlar:** 80 TimetablePage, 81 CourseFormPage, 82 ExamsPage, 83 ExamFormPage
- **Alt sayfa / diyalog:** A44, A45, A46, A47, A48, A49, A50
- **Dosyalar (7, 2.403 satır):** `features/academic/academic_widgets.dart`(239), `features/academic/akad_widgets.dart`(488), `features/academic/course_form_page.dart`(378), `features/academic/exam_form_page.dart`(216), `features/academic/exams_page.dart`(318), `features/academic/semester_sheet.dart`(323), `features/academic/timetable_page.dart`(441)
- **Test dosyaları:** `akad_design_test`, academic_features_test (ortak 17/20)
- **Bağımlılık:** P0. Başkasına bağımlı değil. `academic_widgets`/`akad_widgets` P20 tarafından kullanılır.
- **İş yükü / dalga:** M-L / Dalga 1
- **P0'dan beklenen:** BuListRow, BuField, BuSheet, BuPickerTheme, BuSkeleton, ders renk paleti tokenı (`categoryTints`)

#### Paket 18: Kabuk (AppShell/FloatingNav) + Profil sekmesi + takip + kullanıcı gönderileri + profil ortak bileşenleri

- **Ekranlar:** 30 AppShell, 31 FloatingNav, 36 ProfileTab, 91 UserPostsPage, 92 FollowListPage, 93 FollowSuggestionsPage
- **Alt sayfa / diyalog:** A51, A52
- **Dosyalar (13, 2.751 satır):** `features/follow/follow_button.dart`(78), `features/follow/follow_list_page.dart`(292), `features/follow/follow_suggestions.dart`(116), `features/follow/follow_summary.dart`(92), `features/posts/profile_posts_section.dart`(121), `features/posts/user_posts_page.dart`(150), `features/profile/icerik_user_posts_grid.dart`(135), `features/profile/profil_widgets.dart`(266), `features/profile/profile_paged_list.dart`(155), `features/profile/profile_tab.dart`(399), `features/profile/profily_widgets.dart`(542), `features/shell/app_shell.dart`(171), `features/shell/floating_nav.dart`(234)
- **Test dosyaları:** `floating_nav_test`, `profil_rows_layout_test`, back_navigation_test (ortak), store_shots_test (ortak)
- **Bağımlılık:** P0. Tüketir: home_tab (P3), discover/post_card (P4), news (P5), chat_tab (P6), clubs/my_clubs (P12), support_page (P13), my_events (P14), profil/account/edit (P19), hub/prefs/user_profile (P20). `profil_widgets`/`profily_widgets` P12/P13/P14/P19/P20 tarafından kullanılır.
- **İş yükü / dalga:** M-L / Dalga 1
- **P0'dan beklenen:** BuListRow/BuGroup (ProfilRow/ProfilCard birleşimi), BuSwitch (PrefSwitch), BuSheet (seçim listesi), BuAvatar, BuSkeleton, BuPageRoute

#### Paket 19: Profil düzenle, Ayarlar, Hesap/güvenlik, Gizlilik, Verilerim, Hesabı sil

- **Ekranlar:** 94 EditProfilePage, 95 SettingsPage, 96 AccountSecurityPage, 97 PrivacyDataPage, 98 MyDataPage, 99 DeleteAccountPage
- **Alt sayfa / diyalog:** A53, A54, A55, A56, A57, A58
- **Dosyalar (7, 2.217 satır):** `features/profile/account_security_page.dart`(252), `features/profile/edit_profile_page.dart`(530), `features/profile/privacy_data_page.dart`(324), `features/profile/profil2_delete_account_page.dart`(389), `features/profile/profil2_my_data_page.dart`(148), `features/profile/profil2_widgets.dart`(234), `features/profile/settings_page.dart`(340)
- **Test dosyaları:** `profil2_test`, academic_test (ortak)
- **Bağımlılık:** P0 + P2 (`auth_widgets`, `academic_picker`) + P18 (`profil_widgets`) + P20 (`blocked_users`, `notification_prefs`, `reminder_settings`).
- **İş yükü / dalga:** M / Dalga 2
- **P0'dan beklenen:** BuField, BuListRow, BuSwitch, BuSheet, BuConfirmDialog, tehlike düğmesi (BuButton.danger)

#### Paket 20: Akademik 2 (giriş, takvim, duyuru, hatırlatma), başkasının profili, bildirim tercihleri, engellenenler

- **Ekranlar:** 84 AcademicHubPage, 85 AcademicCalendarPage, 86 AnnouncementsPage, 87 AnnouncementDetailPage, 88 ReminderSettingsPage, 89 UserProfilePage, 90 _AvatarViewer, 100 NotificationPrefsPage, 101 BlockedUsersPage
- **Alt sayfa / diyalog:** A59, A60
- **Dosyalar (8, 2.512 satır):** `features/academic/academic_calendar_page.dart`(288), `features/academic/academic_hub_page.dart`(227), `features/academic/acadhub_widgets.dart`(130), `features/academic/announcements_page.dart`(329), `features/academic/reminder_settings_page.dart`(98), `features/profile/blocked_users_page.dart`(210), `features/profile/notification_prefs_page.dart`(484), `features/profile/user_profile_page.dart`(746)
- **Test dosyaları:** `user_profile_test`, `profil1_test`, profilyard_test (ortak 12/14/18/20), academic_features_test (ortak)
- **Bağımlılık:** P0 + P17 (`akad_widgets`, `academic_widgets`) + P18 (`profil_widgets`, `profily_widgets`, `follow_list_page`) + P5 (`icerik_parts`) + P3 (`notif_row`) + P19.
- **İş yükü / dalga:** M-L / Dalga 2
- **P0'dan beklenen:** BuListRow, BuSwitch, BuSegmented, BuPickerTheme, BuAvatar, BuStateView

### 4.3 Paket 0 (temel) kapsamı ve KİLİTLİ arayüz

Paket 0, 20 pakete başlamadan önce tamamlanır ve **birleştirilir**; sonra aşağıdaki arayüz kilitlenir (yalnız ekleme; var olan imza ve davranış değişmez, yeni parametreler isteğe bağlı). Paket 0'ın dosya kümesi: `lib/core/theme.dart`, `typography.dart`, `theme_controller.dart`, `lib/widgets/*` (bu_widgets, common, sistem_widgets, report_sheet, simple_markdown) ve **yeni** `lib/core/design/` ile `lib/widgets/bu_*.dart` dosyaları. Mevcut sınıf adları (`LoadingView`, `ErrorView`, `EmptyView`, `BuHeader`...) korunur ve yeni bileşenlere ince sarmalayıcı olur; sayfalar kademeli geçer.

| # | Teslimat | İçerik | Neden |
|---|---|---|---|
| 0.1 | Belirteçler (`lib/core/design/`) | `BuSpace` (4/8/12/16/20/24/32 ölçeği + `Gap`), `BuRadius` (sm 10, md 14, lg 18, xl 24, pill), `BuMotion` (120/220/300 ms, eğriler, `MediaQuery.disableAnimations` ise sıfır), `BuElevation` (iki yumuşak gölge, açık/koyu), semantik renk eklemeleri `BuTokens`'a ek alanlar: `warn/warnSoft`, `onMedia`/`scrim` (siyah medya zemini), `categoryTints` (kulüp/ders/haber renkleri), `qrInk/qrPaper` | 200 `Color(0x..)` ve 219 `Colors.*` kaçağı (bölüm 6.4) ve 677 `EdgeInsets`, 409+343 sabit `SizedBox` |
| 0.2 | Durum bileşenleri | `BuStateView` (yükleniyor-iskelet / hata / boş / bakım / çevrimdışı / bayat tek API; `LoadingView`, `ErrorView`, `EmptyView`, `SistemStatusView`, `StaleBanner`, `AcademicErrorView` bunun sarmalayıcısı), `BuSkeleton` (kutu, satır, daire + hazır: liste satırı, kart, ızgara, masonry; tek paylaşılan animasyon denetleyicisi, `disableAnimations` ise statik), `BuBand` (üst şerit) | 59 `CircularProgressIndicator`, iskelet yalnız 5 dosyada |
| 0.3 | Görsel | `BuImage` (ağ görseli: `cacheWidth/Height` düzen boyutu x DPR'den otomatik, `FadeIn`, yer tutucu rengi, `errorBuilder`, isteğe bağlı `DiskCache` tabanlı `ImageProvider`; **yeni paket yok**), `BuAvatar` önbellek düzeltmesi | 22 `Image.network`'ün 9'unda `cacheWidth` yok |
| 0.4 | Çerçeve ve etkileşim | `BuPageScaffold` (BuHeader + gövde + `RefreshIndicator` + safe area + klavye), `BuSheet.show` (tutamaç, köşe, klavye payı, azami yükseklik, RTL; `SohbetySheetFrame`, `showProfilChoiceSheet`, `ReportSheet` çerçevesi buna taşınır), `BuConfirmDialog.show`, `BuToast`, `BuPickerTheme` (tarih/saat), `BuPageRoute` + `pageTransitionsTheme` (220 ms) | 4 farklı alt sayfa çerçevesi, 25 elle `AlertDialog` |
| 0.5 | Liste/form bileşenleri | `BuListRow` + `BuGroup` (`ProfilRow/ProfilCard/BuMenuRow/PrefSwitchRow` birleşimi), `BuSwitch` (`PrefSwitch`), `BuField` (metin alanı; 48 dp, hata/yardım), `BuChip`, `BuButton` (48 dp tabanı, `danger`, yükleniyor durumu), `BuTabs`, `BuProgressBar`, `BuAccordion` | kapsüllenmemiş tekrarlar (bölüm 6.4) |
| 0.6 | Test altyapısı | (a) `pages_a/b/c` ve `visual_a/b/c` dosyalarını **ekran bazlı dosyalara böl** (test sayısı 3300 korunur, doğrulama: JSON rapor sayımı) — paket çakışmasını önler; (b) `test/support/ui_matrix.dart`: bir ekranı {tr,en,ar} x {açık,koyu} x {yazı 1.0, 1.3} ile çizer, taşma ve `meetsGuideline(androidTapTargetGuideline, labeledTapTargetGuideline, textContrastGuideline)` denetler; (c) `test/support/frame_budget.dart` (hafif widget testi: `pumpAndSettle` süresi/yeniden çizim sayacı); (d) `store_shots_test` analiz hataları (5 error, 'Session' dynamic) düzeltilir | 3 büyük paylaşılan test dosyasına 20 ajan yazamaz |
| 0.7 | l10n kuralı | Yeni anahtar öneki `p<NN>` (paket numarası); ARB ekleme yalnız dosya sonuna, üretilmiş dosyalar `flutter gen-l10n` ile yeniden üretilir ve aynı push'ta gider; mevcut anahtar silinmez/yeniden adlandırılmaz | ARB ve 4 üretilmiş dosya tek çakışma noktası |
| 0.8 | Tasarım sözleşmesi | Seçilen yön (bölüm 7) için bileşen kataloğu sayfası: `docs/MOBILE_UI.md` güncellemesi + `test/support/` içinde 'katalog' widget testi (tüm bileşenler, 6 tema/dil/ölçek kombinasyonu) | 20 ajanın tek referansı |

**Kilitli arayüz listesi (P0 çıktısı, ekleme-yalnız):** `BuSpace`, `BuRadius`, `BuMotion`, `BuElevation`, `BuTokens` (mevcut alanlar + yeni semantik alanlar), `BuStateView`, `BuSkeleton*`, `BuBand`, `BuImage`, `BuAvatar`, `BuPageScaffold`, `BuHeader`, `BuSheet`, `BuConfirmDialog`, `BuToast`, `BuPickerTheme`, `BuPageRoute`, `BuListRow`, `BuGroup`, `BuSwitch`, `BuField`, `BuChip`, `BuButton`, `BuSegmented`, `BuTabs`, `BuCard`, `BuHeroCard`, `BuSearchField`, `BuProgressBar`, `BuAccordion`, `ui_matrix` test yardımcıları. 20 paket bu dosyaları DEĞİŞTİRMEZ; eksik/yanlış bulunan şey `docs/ui0-p0-istekleri.md` yerine Paket 0 sahibine (yönetici) bildirilir ve P0 ekleme sürümü çıkarır (birleştirme `scripts/agent-push.sh` kilidi altında).

### 4.4 Dokunulmaz dosyalar (davranış ve veri katmanı)

Aşağıdaki 44 dosya (7.328 satır) hiçbir pakete verilmedi; yeniden tasarım sırasında DEĞİŞMEZ (yalnız yorum/biçim değişikliği de yapılmaz). Bir ekranın bu katmandan bir şeye ihtiyacı varsa yönetici onayıyla ayrı, küçük bir davranış değişikliği olarak ele alınır.

- `core/`: academic_catalog.dart(205), analytics.dart(92), api.dart(460), app_hooks.dart(39), badges.dart(19), closed_conversations.dart(86), device_identity.dart(78), error_log.dart(158), identifier.dart(44), locale_controller.dart(72), nav.dart(9), pending_verification.dart(79), session.dart(419)
- `core/cache/`: cache_policy.dart(56), disk_cache.dart(240)
- `core/connectivity/`: connectivity_service.dart(61)
- `core/contacts/`: contacts_service.dart(135)
- `core/crash/`: crash_reporter.dart(262)
- `core/notify/`: local_reminders.dart(206)
- `core/outbox/`: outbox.dart(392)
- `core/permissions/`: permission_service.dart(118)
- `core/platform/`: image_service.dart(162), video_service.dart(382)
- `core/push/`: active_conversation.dart(59), push_api.dart(102), push_channels.dart(35), push_router.dart(119), push_service.dart(326), push_targets.dart(146)
- `core/realtime/`: chat_realtime.dart(277), stomp_client.dart(348), stomp_frame.dart(91)
- `features/academic/`: academic_api.dart(89), academic_models.dart(652), reminders.dart(301)
- `features/legal/`: legal_reaccept.dart(161)
- `features/menu/`: menu_models.dart(26)
- `features/polls/`: poll_api.dart(101), poll_models.dart(296)
- `features/posts/`: post_api.dart(74), post_models.dart(214), post_text_rules.dart(13), social_api.dart(46), social_models.dart(78)

Ek olarak üretilmiş `lib/l10n/app_localizations*.dart` (4) ve `app_{tr,en,ar}.arb` yalnız kural 0.7 ile (ekleme + yeniden üretim) değişir.

### 4.5 Ortak (çok paketli) test dosyaları

Şu dosyalar birden çok paketin ekranına dokunur; Paket 0 bunları ekran bazlı dosyalara böler (0.6). Bölme yapılana kadar kural: bir paket **yalnız kendi ekranının test bloğunu** (`group/testWidgets`) düzenler, dosyanın kalanına dokunmaz, düzenlemeyi küçük ve hemen `scripts/agent-push.sh` ile gönderir.

| Dosya | Paketler (çağrı sayısı büyükten) |
|---|---|
| `pages_a_test` (668 satır, 144 test) | 2, 1, 5, 18, 3 |
| `pages_b_test` (1402 satır, 134 test) | 6, 1, 7, 12, 14, 11, 15 |
| `pages_c_test` (689 satır, 181 test) | 13, 19, 3, 5, 1, 20, 12 |
| `visual_a_test` (449 test), `visual_b_test` (367), `visual_c_test` (309) | a: 2,1,4,5,3,18 / b: 6,11,15,12,14,7,9 / c: 19,3,20,5,18,1,13 |
| `robustness_test` (179 test) | 1, 3, 5, 4, 12, 13, 6 |
| `back_navigation_test` | 18, 3, 5, 7, 11, 13, 15 |
| `b2_audit_test`, `b4_server_contracts_test`, `store_shots_test`, `l10n_test` | çoklu |
| `sistem_design_test` (145 test) | 0, 1 |

Davranış/veri testleri (UI paketlerinin DOKUNMADIĞI): `api_*`, `offline_cache`, `outbox`, `push_ios_token`, `stomp_frame`, `transient_session`, `crash_reporter`, `format`, `app_gate` (karar mantığı).

## 5. Yeniden tasarım kuralları ve sınırları (tüm paketler)

### 5.1 Kapsam sınırı
1. **Davranış/API katmanı değişmez:** `lib/core/api.dart`, `session.dart`, `realtime/*`, `push/*` (rota ve hedef çözümleme dahil), `outbox`, `cache`, `crash`, `connectivity_service`, `*_api.dart`, `*_models.dart`, `reminders.dart` (bölüm 4.4). Ekran kurucu imzaları ve pop sonuçları (`true`, `search`, `left`...) korunur.
2. Yeni uç, yeni istek, yeni sunucu alanı **yok**. Bir ekranın istek sayısı artmaz; azalabilir (ör. gereksiz tekrar yükleme).
3. Güvenlik davranışları aynı: `FLAG_SECURE`/ekran yakalama koruması (tek gösterimlik görüntüleyici, kimlik ekranları), ham kimlik/jeton gösterilmez, kaynak sitelere doğrudan istek yok.

### 5.2 Dil, yön, tema, durumlar
4. **3 dil (tr/en/ar):** yeni metin `AppLocalizations`'tan (kural 0.7); sabit metin yok. Arapçada **RTL**: yalnız mantıksal özellikler (`EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `BorderRadiusDirectional`, `start/end`); yeni `left/right/Alignment.centerLeft` yazılmaz; yönlü ikonlar (geri, ok) aynalanır. Mevcut 192 fiziksel left/right kullanımı dokunulan dosyalarda temizlenir.
5. **Renk yalnız `context.bu` (BuTokens):** `Color(0x..)` ve `Colors.white/black/...` yeni yazılmaz; dokunulan dosyadaki mevcut kaçaklar tokena çevrilir (medya zemini için `onMedia/scrim`). Açık ve koyu temada her ekran el ile doğrulanır.
6. **Her ekranda beş durum korunur:** yükleniyor (iskelet), hata (yeniden dene), boş (yönlendirici), bakım (`/status`, `maintenance_mode`), çevrimdışı/bayat (`StaleLabel`, `OfflineBanner`). Durum eşlemesi bölüm 1 'Durumlar' sütunudur; bir durumu **kaldırmak yasak**, birleştirmek (BuStateView) serbest.
7. **Erişilebilirlik:** her dokunma hedefi >= 48x48 dp (görsel küçük olsa da `InkResponse`/`ConstrainedBox`), `Semantics`/`tooltip` etiketleri (mevcut 329 korunur, yeniler eklenir), ikonla tek başına bilgi verilmez, metin kontrastı AA (4.5:1; 3:1 büyük metin ve ikonlar), odak sırası mantıksal, **yazı ölçeği 1.3x'te taşma/kırpılma yok** (`ui_matrix` testi), `MediaQuery.disableAnimationsOf` ise animasyonlar kapalı veya anlık.
8. **Testler:** mevcut 3300 test yeşil kalır; ekranı değişen paketin testleri **güncellenir, silinmez**; yeni ekran davranışı için yeni test eklenir (özellikle test boşluğu olan ekranlar: WelcomePage, SplashScreen, MediaCameraPage, ChatVideoPlayerPage, ChatMembersPage, AnnouncementDetailPage, FollowSuggestionsPage, AddMembersSheet). `dart analyze lib` 0 sorun.
9. **Ağır yeni bağımlılık yok.** Görsel/animasyon yalnız Flutter çekirdeği (`AnimatedContainer`, `TweenAnimationBuilder`, `CustomPainter`, `Hero` ölçülü). `cached_network_image`, `shimmer`, `lottie`, `rive`, `flutter_animate` vb. **eklenmez** (`flutter_svg` zaten bağımlılıktır). Paket eklemek gerekiyorsa yazılı gerekçe + APK/IPA boyut etkisi (MB) + lisans belgelenir ve yönetici onayı alınır (mevcut: `flutter_svg` zaten var).

### 5.3 Hız kuralları (bütçe)
10. **Hedefler (profil modu, orta sınıf Android):** soğuk açılış (ilk kare + kullanılabilir ana sayfa) < 2 sn; kaydırma 60 fps (kare süresi p95 < 16 ms, kaçırılan kare < %1); rota geçişi < 300 ms; ilk kare yerel iskeletle ağ beklemeden. Ölçüm: `flutter run --profile --trace-startup` (`start_up_info.json`), DevTools Performance (kare grafiği), `ui_matrix`/`frame_budget` widget testi (yeniden çizim sayacı).
11. `const` kurucular (analizör `prefer_const_constructors` temiz), uzun/dinamik listelerde `ListView.builder`/`SliverList`/`SliverGrid` (yeni `ListView(children: [...])` yazılmaz; mevcut 69 yerde dokunulan listeler dönüştürülür), `itemExtent`/`prototypeItem` ve `findChildIndexCallback` (sıralı akışlarda `ValueKey`), `AutomaticKeepAliveClientMixin` yalnız gerektiğinde.
12. **İskelet:** ilk açılışta ağ cevabı beklenirken (önbellek yoksa) `BuSkeleton`, önbellek varsa eski veri + sessiz yenileme (`StaleLabel`). Dönen çember yalnız eylem düğmesi içinde.
13. **Yeniden çizim:** `setState` kapsamı dar (alt widget'a böl, `ValueListenableBuilder`/`ListenableBuilder`), ağır alt ağaçlar (masonry, balon listesi, QR, ders programı bloğu, harita benzeri çizimler) `RepaintBoundary` ile izole; `Opacity`/`ClipRRect`/`BackdropFilter`/`ShaderMask` ve `saveLayer` doğuran gölge+yuvarlak kombinasyonları kaydırılan listelerde **kullanılmaz** (`DecoratedBox` + `borderRadius` + `Clip.hardEdge` tercih); `AnimatedBuilder` çocuğu dışarıdan verilir.
14. **Görseller:** tüm ağ görselleri `BuImage` ile (decode boyutu = düzen genişliği x DPR; avatarlar <= 3x), yer tutucu renk, hata yedeği; `gaplessPlayback`; ızgara küçük resimleri `thumbUrl`; disk önbelleği mevcut `DiskCache` üzerinden (yeni paket yok); ekran dışı görsel ön yüklemesi yalnız sıradaki 1-2 öğe.
15. **Animasyon:** süre 200-300 ms (mikro etkileşim 120 ms), eğri `Curves.easeOutCubic`/`fastOutSlowIn`, yalnız `transform`/`opacity` (düzen değiştiren animasyon yok), kaydırma sırasında sürekli animasyon yok, `Timer.periodic`/`AnimationController` dispose kontrol edilir; liste girişinde kademeli animasyon en çok ilk 8 öğe.
16. **İlk açılış yolu:** `IndexedStack` 5 sekmeyi birden kurar ve hepsi ilk karede ağ isteği başlatır (bölüm 6.5); bu yol P18'in sahipliğindedir. Sekme gövdelerinin **ilk ziyarette** kurulması (kurulduktan sonra korunması) önerisi yönetici onayıyla ele alınır; geri/konum koruma davranışı değişmeyecek şekilde ve `back_navigation_test` ile doğrulanarak.

### 5.4 Çalışma kuralları
17. **İmza uyumu (modül widget'ları):** çok pakette kullanılan dosyaların (`auth_widgets`, `profil_widgets`, `profily_widgets`, `icerik_parts`, `news_tile`, `event_parts`, `event_cover`, `etkinlik2_widgets`, `kulup_widgets`, `sohbety_widgets`, `message_bubble`, `akad_widgets`, `academic_widgets`, `destek_widgets`, `anket_style`, `poll_parts`, `post_card`, `ensure_permission`, `offline_banner`, `qr_scan_page`, `legal_pages`, `app_shell`) herkese açık sınıf/fonksiyon imzaları **değişmez**; yalnız isteğe bağlı parametre eklenir, eskisi silinmez.
18. **Dosya sahipliği:** bir paket yalnız kendi dosya kümesini düzenler (bölüm 4.2). Küme dışına dokunma gereksinimi çıkarsa dur, yöneticiye bildir. Yeni dosyalar paketin kendi klasöründe, `uiNN_` öneki gerekmez ama adlar benzersiz olmalı (bean/sınıf adı çakışması).
19. **Doğrulama (paket başına):** `cd C:\bu_mobile; flutter test test/<paketin dosyaları>`, `dart analyze <paketin dosyaları>`; ortak çalışma ağacında başkasının yarım değişikliği tam paket koşusunu bozabileceğinden **tam `flutter test` ve `dart analyze lib` dalga sonunda** yönetici/entegrasyon adımında koşulur (şu an ~197 sn).
20. **Teslim:** `scripts/agent-push.sh "UI0-P<NN>: ..." <dosyalar>` (seri kilit, yalnız verilen yollar), `.env`/sır/`build/` yok; ekran görüntüsü kanıtı (aşağıdaki 'Kanıt' satırı) `docs/changes/` altına değil, commit mesajına ve yönetici raporuna yazılır.
21. **Kanıt:** her ekran için {tr açık, ar koyu 1.3x} iki ekran görüntüsü (golden dosyası olarak kaydetmeden; `ui_matrix` ile üretilen PNG'ler paket çıktısına eklenir) ve testin yeşil çıktısı.

## 6. Mevcut durum ölçümü (salt okunur)

| Ölçü | Sonuç |
|---|---|
| `dart analyze lib` | ölçüm anında **0 sorun**; sonradan başka sürecin yarım kimlik (P2) değişiklikleri 6 info ekledi (`prefer_const...` türü, `auth/*_page.dart`) |
| `dart analyze test` | 9 sorun: `test/store_shots_test.dart` 5 error (`dynamic` -> `Session`) + 2 info, `test/support/store_shots_images.dart` 2 info; IMG1 işinden kalan, UI paketlerinin değil Paket 0.6(d)'nin işi |
| `flutter test` (tüm paket) | **3300 test geçti, 16 atlandı, 0 başarısız** (+94 gizli kurulum girdisi); toplam ≈ 197 sn; 73 test dosyası (+ izlenmeyen `auth_shots_test`) ve destek dosyaları (`test/support/fake_app.dart` 1070 satır) |
| En çok test taşıyan dosyalar | visual_a 449, visual_b 367, visual_c 309, pages_c 181, robustness 179, sistem_design 145, pages_a 144, etkinlik2 141, pages_b 134 |
| Kaynak | lib altında Dart dosyası (üretilmiş l10n hariç) ve satır sayısı bölüm 0 tablosunda; ARB 2144 anahtar |

### 6.1 En büyük 10 ekran/UI dosyası

| # | Dosya | Satır | Paket |
|---|---|---|---|
| 1 | `features/chat/chat_detail_page.dart` | 2478 | 7 |
| 2 | `features/events/events_page.dart` | 1391 | 14 |
| 3 | `features/chat/message_bubble.dart` | 1163 | 8 |
| 4 | `features/clubs/club_detail_page.dart` | 1127 | 11 |
| 5 | `features/chat/chat_info_page.dart` | 1122 | 9 |
| 6 | `features/events/event_detail_page.dart` | 1012 | 15 |
| 7 | `features/events/event_form_page.dart` | 973 | 15 |
| 8 | `features/chat/chat_tab.dart` | 947 | 6 |
| 9 | `features/search/search_page.dart` | 819 | 5 |
| 10 | `features/home/home_tab.dart` | 749 | 3 |

(11. `user_profile_page` 746, 12. `widgets/bu_widgets` 683, 13. `sohbety_widgets` 643, 14. `discover_masonry` 626.) 1000+ satırlık 6 dosyanın hepsi tek paketin içinde; paket sahibi büyük dosyayı **kendi paketinde** parçalara bölebilir (yeni dosyalar paketin klasöründe).

### 6.2 Tasarım dilinin özeti (`lib/core/theme.dart`, `typography.dart`)

- **Marka:** kırmızı `pr` açık `#C62A20` / koyu `#FF6A5F`; hero gradyanı açık `#DC3125 -> #C62A20`, koyu `#C62A20 -> #9E1F17`; mürekkep lacivert `#171E33`. Yazı tipi **Inter** (400/500/600/700/800 paketli; Arapçada sistem yedeği).
- **BuTokens (17 renk):** `bg` `#FAF6F3`/`#14161F`, `sf` (kart) `#FFFFFF`/`#1D2030`, `sf2` `#F3ECE7`/`#24283A`, `ink`, `mut`, `bd` `#E8DFD8`/`#2E3247`, `pr`, `onPr`, `soft`/`onSoft` (yumuşak kırmızı), `nav`/`onNav`, `h1`/`h2`, `ok`/`okSoft`, `danger`. Erişim: yalnız `context.bu`.
- **Yazı ölçeği (`BuType`):** display 23.4/800, title 18/800, heading 15.3/700, body 13.5/400, bodyStrong 13.5/600, label 11.7/600, caption 10.8/400, micro 9.9/500 (hepsi eski ölçeğin %90'ı; küçük yazı sınırda: caption/micro 1.3x ölçekte taşma riski).
- **Köşe yarıçapı (kodda en sık):** 16 (79 kez), 14 (59), 20 (44), 18 (35), 12 (34), 999 hap (19), 22, 10, 8; tema: kart 20, diyalog 24, girdi/düğme 14. **Boşluk:** `SizedBox(height:)` 409 kez (12: 71, 14: 68, 8: 59, 10: 50, 4: 34, 6: 26, 16: 23...), `width` 343, `EdgeInsets` 677; ortak ölçek yok. **Gölge:** `BoxShadow` 58 yerde elle.
- **Düğme/alan:** Filled/Outlined 54 dp yükseklik, 14 yarıçap; girdi 16 dolgu, 14 yarıçap, odak 2 px `pr`. Simgeler: Lucide (`lucide_icons_flutter`), 21.6 px.
- **Gezinme:** `FloatingNav` yüzen kart (68 dp, 24 köşe, kayan yumuşak kırmızı hap, sohbet rozeti); uygulama çubuğu yerine çoğunlukla `BuHeader` (43 dosya; `AppBar` yalnız 2 dosyada).

### 6.3 Mevcut paylaşılan widget'lar

- `lib/widgets/bu_widgets.dart` (683 satır): `BuHeader`, `BuIconButton`, `BuCard`, `BuChip`, `BuBadge`, `BuAvatar`, `BuButton`(primary/outline/soft), `BuSegmented`, `BuSearchField`, `BuSectionTitle`, `BuHeroCard`, `BuMenuRow`, `BuGroup`, `BuMark`, `trUpper`, `initialsOf`.
- `lib/widgets/common.dart`: tarih biçimleri, `LoadingView`, `ErrorView`, `EmptyView`, `StaleBanner`, `TypeBadge`, `SectionHeader`, `NewsThumb`. `sistem_widgets.dart`: `SistemTile/Button/StatusView`, `MaintenanceBand`. `report_sheet.dart`, `simple_markdown.dart`, `academic_picker.dart`.
- Modül yerel dosyaları (ayrı ayrı yazılmış, kısmen aynı işi yapan): `auth_widgets`, `sohbety_widgets`, `chatlist_widgets`, `chatd_parts`, `profil_widgets`, `profily_widgets`, `profil2_widgets`, `icerik_parts`, `event_parts`, `etkinlik_parts`, `etkinlik2_widgets`, `kulup_widgets`, `clubs_widgets`, `home_parts`, `poll_parts`, `anket_style`, `destek_widgets`, `support_common`, `akad_widgets`, `academic_widgets`, `acadhub_widgets`. Bu ad kalıbı (`sohbety`, `profily`, `profil2`, `etkinlik2`, `kulup`/`clubs`, `akad`/`academic`/`acadhub`, `icerik`) önceki paralel tasarım dalgalarından kalmadır; aynı bileşenin (kart, başlık, satır, anahtar, boş durum) 3-4 farklı uygulaması vardır.
- **Tasarım şablonları** (`mobile/design/*.dc.html`, 48 dosya): Kimlik (`A-*`, giriş/kayıt/kod/unuttum/sıfırla açık+koyu), alternatifler (`B/C/D-Home`, `B/C/D-Login`), `P-*` serisi (Chat, ChatDetail, ClubDetail, Clubs, Discover, EditProfile, EventDetail, Events, Menu, NewChat, Notifications, Profile, Saved, Search, Settings, Support: açık+koyu), `Main`. **Şablonu olmayan ekranlar:** akademik (hepsi), anketler, etkinlik organizatör araçları, sistem ekranları, izinler, sözleşme, gönderi oluştur/detay, kulüp formu/üyeler/istekler, Verilerim/Hesabı sil/Gizlilik. Şablonlar yazı tipi olarak **Plus Jakarta Sans** kullanır, uygulama **Inter**; şablonlar bu yüzden referans değil yön örneğidir.

### 6.4 Tutarsızlıklar ve sayılar (`mobile/lib`, l10n hariç)

| Gözlem | Sayı | Yorum |
|---|---|---|
| `Color(0x..)` doğrudan | 200 (40'ı `theme.dart` token tanımı; **160 kaçak**) | en çok: `anket_style` 11, `discover_masonry` 10, `academic_models` 10, `profil2_widgets` 8, `home_parts` 7, `sohbety_widgets` 7, `profily_widgets` 6, `notif_row` 6, `media_preview_page` 6 |
| `Colors.white/black/red/...` | 219 | medya ekranlarında (önizleme, balon, video, görüntüleyiciler, QR) yoğun; bir kısmı meşru (siyah medya zemini) ama tokenlaşmalı |
| Elle `fontSize:` | 281 (`TextStyle(` 86) | kural "sayfalarda elle fontSize yazılmaz" ihlali; `profily_widgets` 15, `timetable_page` 15, `akad_widgets` 12, `sohbety_widgets` 11, `chat_info_page` 11 |
| Fiziksel yön (`left/right/Alignment.*Left/Right`, `fromLTRB`) | ~192 | RTL riski; Directional karşılıkları 219 kez kullanılıyor |
| `SizedBox(height: n)` / `width: n` sabit | 409 / 343 | ortak ölçek yok (2,3,4,6,8,10,12,14,16,18,20,32) |
| `BorderRadius.circular(n)` | 359 (14 farklı değer) | 16/14/20/18/12 dağınık |
| Aynı bileşen farklı uygulama | satır/kart: `ProfilRow`, `BuMenuRow`, `PrefSwitchRow`, `SettingsRow`, `_SettingsRow`; anahtar: `PrefSwitch` vs `Switch`(8); alt sayfa çerçevesi: 4; onay diyaloğu: 25 `AlertDialog(` çağrısı elle; bölüm segmenti: `BuSegmented` yanında `_Seg` (events, polls), `_TypeTab` (news); boş/hata: `EmptyView/ErrorView` + `AcademicErrorView` + `SistemStatusView` + `_StateCard` |
| Yükleniyor göstergesi | 59 `CircularProgressIndicator`, 50 `LoadingView()` | iskelet yalnız `chat_tab`, `discover_masonry`, `events_page`, `user_profile_page`, `message_bubble`, `chatd_parts` |

### 6.5 Performans riski gözlemleri

1. **`IndexedStack` ile 5 sekme aynı anda kurulur** (`app_shell.dart`): ilk karede `HomeTab` (6 istek), `DiscoverTab` (masonry `_reload`), `ChatTab` (liste + STOMP başlatma + rozet), `ClubsTab` (3 istek), `ProfileTab` kurulur ve başlar. Soğuk açılış maliyetinin ana adayı.
2. `main()` ilk kareden önce `await CrashReporter.init()` ve `await DeviceIdentity.load()` bekliyor (disk okumaları); `SystemChrome.setPreferredOrientations` de await.
3. `ListView(children: [...])` 69 yerde (eylemsiz uzun listeler dahil: `clubs_tab`, `news_list_page`, `notifications_page`, `follow_list_page`, `blocked_users_page`, `my_clubs/my_events`, `exams_page`, `polls`), `builder` ailesi 28 yerde. Sayfalı listelerde tüm öğeler bir kerede kurulabiliyor.
4. `RepaintBoundary` yalnız 2 yerde (`floating_nav` ve bir yer); masonry, mesaj balonu, QR, ders bloğu izole değil. `Opacity` 12, `ClipRRect` 28 (kaydırılan listelerde saveLayer riski).
5. `Image.network` 22 çağrının **9'unda `cacheWidth/Height` yok** (`chat_media_viewer` 2, `message_bubble:876`, `club_detail` 2, `club_form`, `edit_profile`, `profile_tab`, `user_profile`): tam çözünürlükte çözülür. Diske ağ görseli önbelleği yok (`DiskCache` yalnız API yanıtları için); Flutter bellek önbelleği oturumla sınırlı.
6. `FutureBuilder` 7 yerde (`news_detail_page`, `legal_pages` x2, `profile_tab`, medya önizleme/seçici küçük resimleri): `build` içinde yeni `Future` üretilirse her yeniden çizimde tekrar istek riski; paket sahipleri `initState`'e taşımalı (bunlar `profile_tab`, `legal_pages` içinde doğrulanacak).
7. `setState(` 782 kez; 2478 satırlık `chat_detail_page` tek `State` içinde çok sayıda `setState` ve sürekli yoklama (4 sn `after` yedeği) taşıyor; `Timer.periodic` 13 yerde (iptal denetimi paket sahibinde).
8. Hareket: `AnimationController` 12; `MediaQuery.disableAnimations` **yalnız 1 dosyada** (`qr_scan_page`); sayfa geçişi varsayılan Material (özel `pageTransitionsTheme` yok).
9. Yazı: `caption` 10.8 ve `micro` 9.9 puntoluk metinler 1.3x ölçek ve Arapça için sınırda; metin ölçeği testleri yalnız 10 dosyada geçiyor.

## 7. Tasarım yönü önerisi (karar kullanıcıda)

Ortak şartlar (üç yönde de): marka kırmızısı (`pr` açık `#C62A20` / koyu `#FF6A5F`) ve **Inter** korunur; tüm yönler aynı `BuTokens` + yeni `BuSpace/BuRadius/BuMotion/BuElevation` ölçeğini kullanır; yalnızca "yüzey dili" ve "hareket yoğunluğu" değişir.

### Yön A: "Sade-Cam" (kırık beyaz yüzeyler, yarı saydam üst/alt çubuk)
- **İlke:** az çizgi, çok nefes; içerik (fotoğraf, metin) öne çıkar, krom ikincil. Kartlar kenarlıksız, çok açık yüzey farkı; üst başlık ve alt gezinme arkada içeriği hafif bulanık gösterir (cam).
- **Bileşen dili:** kart köşesi 16-20, gölge yok (yalnız 1 px `bd` ince çizgi); çipler ince çizgili hap; alt gezinme yarı saydam yüzen çubuk (`BackdropFilter` YALNIZ burada ve üst başlıkta, en çok 2 yüzey); başlıklar büyük ve hafif ağırlıkta (display 700); boşluk ölçeği geniş (16/24/32).
- **Hareket:** hafif ölçek ve solma (opacity 0->1, 220 ms), başlık kaydırmada küçülür (collapsing), `Hero` yalnız görsel -> detay.
- **En çok değişen ekranlar:** Ana Sayfa, Keşfet, Kulüp/Etkinlik detay kapakları, Profil, FloatingNav, başlıklar (tüm ekranlar).
- **Artı/eksi:** en "şık"; fakat `BackdropFilter` düşük sınıf cihazlarda kare süresini artırır (saveLayer), açık/koyu temada cam üstü metin kontrastı AA için riskli, Arapça RTL cam katmanı testi ek iş.

### Yön B: "Kart-Yumuşak" (tonal katmanlı, yumuşak köşeli kart ailesi)
- **İlke:** her bilgi bir kart ailesinden; yüzey, ikincil yüzey (`sf2`) ve yumuşak kırmızı (`soft`) üç tonu hiyerarşiyi kurar; gölge değil ton farkı. Tüm ekranlarda tek satır/kart/bölüm başlığı sistemi.
- **Bileşen dili:** kart köşesi 20 (içeride 14), 1 px `bd` yerine ton farkı (koyu temada kenarlık), çip: hap, seçili = `soft` zemin + `onSoft` yazı; alt gezinme: mevcut yüzen kart korunur, seçili sekme `soft` hap + etiket; sayfa başlığı: 18/800 sol hizalı + eylem düğmeleri 48 dp; liste satırı: 56-64 dp, 40 dp avatar/ikon karosu; boşluk 4'ün katları (8/12/16/24); bölüm başlığı küçük büyük harf (mevcut `BuSectionTitle`).
- **Hareket:** 120 ms basma geri bildirimi (ölçek 0.98), 220 ms sayfa geçişi (yatay kayma + solma), iskelet -> içerik 200 ms çapraz solma, liste girişi ilk 8 öğede kademeli; hepsi `disableAnimations`'a saygılı.
- **En çok değişen ekranlar:** Profil ve alt sayfaları (Ayarlar, Gizlilik...), Akademik (tüm), Destek, Anketler, Kulüp/Etkinlik listeleri, Sohbet listesi, formlar. Büyük ölçüde mevcut dilin (BuCard/BuGroup/BuMenuRow) **tutarlı hale getirilmesi**; kimlik ve sohbet balonu az değişir.
- **Artı/eksi:** en hızlı render (saveLayer yok, düz dolgu), AA kontrast en kolay, mevcut tokenlarla birebir uyumlu (geçiş maliyeti en düşük, paketler arası tutarlılık en kolay denetlenir); riski "yeterince yenilikçi görünmeme" — bunu hareket ve hero yüzeyleriyle dengelemek gerekir.

### Yön C: "Canlı-Gradyan" (kırmızı gradyan hero + renk kodlu kategoriler + zengin hareket)
- **İlke:** enerjik, marka kırmızısı baskın; hero alanlar gradyan, kategoriler renk kodlu, eylemler büyük ve dolgulu.
- **Bileşen dili:** hero kartları `h1->h2` gradyan + yarı saydam desenli halkalar (splash'taki halka dili), kategori çipleri renkli (`categoryTints`), düğmeler gradyanlı büyük (56 dp), alt gezinme koyu `nav` yüzen hap, başlıklar gradyan üstü beyaz; kartlarda gölge + renkli şerit.
- **Hareket:** sekme geçişinde paralaks/kayma, listelerde kademeli giriş, beğeni/RSVP'de mikro konfeti benzeri parıltı (yalnız `CustomPainter`), sayfa geçişi paylaşılan öğe (`Hero`).
- **En çok değişen ekranlar:** Splash/Karşılama/Giriş, Ana Sayfa, Etkinlik/Kulüp kapakları, Yemek, Akademik hub, Anketler sonuçları.
- **Artı/eksi:** en "yenilikçi" ve akılda kalan; fakat gradyan + gölge + uzun hareket zinciri en çok GPU/saveLayer maliyeti, renkli yüzeylerde koyu temada kontrast ve RTL aynalama maliyeti, kategori renkleri için erişilebilirlik (yalnız renkle anlatım yasak) ek iş, 20 ajanın tutarlı uygulaması en zoru.

### Öneri: **Yön B "Kart-Yumuşak"**, hero yüzeylerde Yön C'den sınırlı ödünç (yalnız splash, karşılama, giriş, Ana Sayfa hero kartı, etkinlik/kulüp kapağı) ve Yön A'dan yalnız **daraltılan başlık** (collapsing header, bulanıklık yok)
Gerekçe: (1) **Hız:** düz dolgu + ton katmanı saveLayer üretmez; `BackdropFilter` kullanılmaz, "hızlı açılan sayfalar" hedefini doğrudan destekler. (2) **Erişilebilirlik:** AA kontrast ve 48 dp hedefler katı yüzeylerde kolay kanıtlanır, 1.3x yazı ve RTL için öngörülebilir. (3) **Geçiş maliyeti ve tutarlılık:** mevcut `BuTokens` ve `BuCard/BuGroup/BuMenuRow` ailesi bu dilin zaten yarısı; 20 paket aynı kataloga (Paket 0) uyduğunda ekranlar arası fark kapanır. (4) **Yenilik hissi** hareket (220 ms geçiş, iskelet -> içerik çapraz solma, basma geri bildirimi) ve hero yüzeylerle verilir; bunların maliyeti ölçülebilir ve kapatılabilir (`disableAnimations`). Karar sonrası Paket 0 bileşen kataloğunu seçilen yöne göre üretir.

## 8. Riskler ve açık noktalar

1. **Paralel çalışma çakışması (şu an gerçekleşiyor):** ortak çalışma ağacında başka bir süreç kimlik ekranlarını (Paket 2) işliyor: `features/auth/widgets/` (yeni), `otp_code_boxes.dart`, `test/auth_shots_test.dart` ve `lib/l10n/*` değişikliği izlenmeyen/commitlenmemiş durumda (`welcomeChip*`, `authLangTitle`, `authTrust*`, `authReset*` anahtarları). Paket 2 başlamadan bu işin sahibiyle uzlaşılmalı; aksi halde aynı dosyalar iki kez yeniden tasarlanır. Bu belge yalnız kendi dosyasını commitler.
2. **Tek çalışma ağacı:** `scripts/agent-push.sh` ajanların aynı ağacı paylaştığını varsayar (seri kilit). Birinin yarım yazdığı dosya diğerinin `dart analyze`/`flutter test` koşusunu bozar. Çözüm: paket başına yalnız kendi dosyalarının testi, tam koşu dalga sonunda; mümkünse ajan başına `git worktree` (CLAUDE.md bölüm 6) — ancak her worktree ASCII junction yolu ister (`C:\bu_mobile_<n>`) ve ayrı `PUB_CACHE` paylaşımı gerekir.
3. **ARB/üretilmiş l10n tek çakışma noktası** (3.811 + 2.147 + 2.147 satır + 4 üretilmiş dosya, 13 bin satırlık `app_localizations.dart`): ekleme-yalnız + `p<NN>` öneki + dosya sonuna ekleme + aynı push'ta yeniden üretim; çakışmada üretilmiş dosyalar yeniden üretilir, elle birleştirilmez. Arapça çeviriler anadil incelemesi ister (CLAUDE.md bölüm 8).
4. **Ortak test dosyaları** (pages_a/b/c, visual_a/b/c, robustness, back_navigation...): Paket 0.6 bölmeyi yapmazsa 20 paket aynı 7 dosyada çakışır. Bölme sırasında test sayısı 3300 korunmalı.
5. **Paketler arası görünüm tutarsızlığı:** modül widget'ı sahibi (Dalga 1) yeni dili uyguladıktan sonra tüketen paketler (Dalga 2) eski imza ile eski görünüm alabilir; Dalga 2 rebase + görsel doğrulama zorunlu.
6. **XL paket (P7 sohbet detayı, 2478 satır tek dosya):** tek ajan için en riskli; ilk adım dosyayı paket klasöründe parçalara ayırmak (davranış değişmeden, mevcut sohbet testleri yeşil), sonra tasarım. Gerekirse P7 içinde iki ajan (üst çubuk+liste / yazma çubuğu+eylemler) sıralı çalışır (aynı dosyayı aynı anda değil).
7. **Erişilebilirlik küçük yazısı:** `BuType.caption/micro` değerleri 1.3x'te ve Arapçada sınırda; Paket 0 en küçük yazıyı yükseltebilir (10.8 -> 11.5, 9.9 -> 10.5), bu tüm ekranları etkileyen tek karardır (kullanıcı onayı).
8. **Performans hedefi ölçülemez olabilir:** profil modu ölçümü için gerçek cihaz gerekir; bu makinede yalnız widget testi var. Gerçek cihaz ölçümü yöneticide/kullanıcıdadır; widget testleri yalnız yeniden çizim ve kurulum sayısını güvenceler.
9. **Tarih/saat seçici ve sistem diyalogları** yerel (Material/Cupertino) davranır; tam özel tasarım gerekirse bağımlılık sınırı (kural 9) devreye girer.
10. **Belge kapsamı:** ekran içerikleri sınıf başlık yorumlarından ve kodun taranmasından çıkarıldı; her paket sahibi kendi ekranlarını çalıştırıp 'Durumlar' sütununu doğrulayacak (özellikle alt sayfa içerikleri).

## 9. Önerilen sonraki adım

1. Kullanıcı tasarım yönünü seçer (A/B/C; öneri B).
2. Paket 0 tek ajanla koşar: belirteçler, bileşenler, test bölme, katalog; `flutter test` = 3300 yeşil, `dart analyze lib test` 0.
3. Paket 0 birleşince 20 paket Dalga 1 (10 paket) ardından Dalga 2 (10 paket) olarak koşar; her dalga sonunda tam test + analiz + ekran görüntüsü kanıtları.
4. Dalga 2 sonunda: gerçek cihazda soğuk açılış ve kaydırma ölçümü, `docs/MOBILE_UI.md` ve `CLAUDE.md` mobil bölümü güncellenir.

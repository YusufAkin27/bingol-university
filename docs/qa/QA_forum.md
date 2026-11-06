# QA-5: Kampüs Forum + Destek + Sözleşme + Uygulama Kabuğu (2026-11-06, 2. tur)

Kapsam: `mobile/lib/features/forum/**`, `support/**`, `legal/**`, `shell/**`, `core/app_gate.dart`, `core/analytics.dart`,
`core/crash*`, `core/push/push_router.dart`, `core/user_data.dart`; backend `forum` (admin dahil), `support`, `legal`, `crash`,
`analytics`, `appinfo`, `export`. Kulüp/etkinlik/floating_nav kapsam dışı.

Yöntem: ekran/öğe envanteri -> test eşlemesi (dosya + test adı düzeyinde doğrulandı) -> boşluklara yeni etkileşim testleri
-> parametrik durum matrisi -> kod incelemesi (hata + yanlış mantık) -> bulgular -> düzeltme + regresyon testi.

Yeni test dosyaları (`mobile/test/qa5/`):
- `qa5_regression_test.dart`: sürüm varsayılanı = pubspec, compareVersions, kısmi kesinti kapısı, taslak temizliği, çift silme.
- `qa5_matrix_test.dart`: 13 ekran x {başarı x5 ortam, hata 401/403/404/429/500 x2, çevrimdışı x2, boş x2} + 4 kapı ekranı x 5 ortam.
  Ortamlar: tr/en/ar (RTL), 320 dp @1.3 yazı, 390 dp @1.0, açık/koyu. Her hücre: istisna/taşma yok, ham hata metni
  (Exception/ApiError/Instance of) sızmıyor; başarı hücresi 4 ekranda verinin gerçekten çizildiğini doğrular.
- `qa5_create_topic_test.dart`: yeni konu formu (15 test: sınırlar, çift dokunma, anonim, hata + aynı anahtar, taslak, anket, 320 dp).
- `qa5_support_interactions_test.dart`: talep yanıtı, kapalı talep, 2000 sınırı, öneri oyu (iyimser + 429 geri alma), form doğrulamaları.
- `qa5_interactions_test.dart`: destek Idempotency-Key, UTF-16 sınırı, PIN sınırı iletisi.

## 1. Envanter ve test eşlemesi

Test sayıları dosyadaki `test/testWidgets` adedidir (grep ile sayıldı).

| Alan | Ekran / öğe | Öğeler (buton, alan, jest, sheet, durum) | Test dosyası (adet) |
|---|---|---|---|
| Forum | Ana sayfa `forum_home_page` | iskelet; kartlar (sabitlenmiş/anonim rozet); boş forum + "Konu aç"; 500 hata + Yeniden dene; çevrimdışı; kategori çipi (Tümü başta, seçince yeniden yükleme, boş kategori); sıralama sheet'i (sort parametresi); imleçli sayfalama; beğeni (iyimser, geri alma, art arda dokunuş tek istek); kaydet (iyimser/geri alma); karta dokun -> detay; bildirim/arama kısayolu; üç nokta menüsü (şikâyet/engelle/sessize al/anonimde sessize alma yok/kendi konusunda yalnız kopyala-kaydet); ek menü (kaydedilenler, faaliyetim, bildirim ayarı); koyu + 320 dp + 1.3 yazı | `forum_home_test` (20), `qa5_matrix` |
| Forum | Kategori seçici | aramalı liste, gruplar, seçim, "Tümü", boş sonuç, 79 kategori | `forum_category_picker_test` (22) |
| Forum | Konu açma `create_topic_page` | başlık 150 / açıklama 10 000 sınırı (alan keser), yalnız boşluk, kategori, anonim anahtarı, çift dokunma tek POST, Idempotency-Key, 401/403/422/429/500/çevrimdışı, yazılanlar korunur, hata sonrası aynı anahtar, taslak kaydet/geri yükle/yayında silinir, anket kurucu, 320 dp + 1.3 | `qa5_create_topic_test` (15), `forum_compose_rules_test` (12), `forum_entry_test` (4) |
| Forum | Konu detayı `topic_detail_page` | beğeni, kaydet, takip, paylaş, sohbete gönder, şikâyet, engelle, düzenle/sil, moderatör Sabitle/Kilitle (+PIN sınırı iletisi), kilitli/silinmiş/gizli konu bandı, anonim yazar, anket oyu, yorum çubuğu | `forum_topic_detail_test` (56), `forum_topic_detail_visual_test` (4), `qa5_interactions` |
| Forum | Yorum ağacı | yanıtla (yanıtın yanıtı), "N yanıtı göster/gizle", girinti sınırı + ayrı zincir, beğeni (tek uçuşlu), düzenle, sil (yer tutucu), kopyala, kaydet, şikâyet, engelle, devamını oku, bildirimden odak | `forum_comment_tree_test` (20), `forum_topic_detail_test`, `qa5_regression` (çift silme) |
| Forum | Arama `forum_search_page` | 350 ms debounce, 1 karakterde istek yok, vurgu (Türkçe I/i), yorum kesiti, boş/hata/çevrimdışı, kategori + sıralama, sayfalama, son aramalar (ekle/sil/temizle, en çok 10), popüler konular | `forum_search_test` (17) |
| Forum | Profil forum sekmeleri / faaliyet | 4 sekme (konularım anonim rozet, yorumlarım, kaydedilenler, takip), kaydı kaldır (iyimser/geri alma), profilde Forum bölümü, menü satırları | `forum_activity_test` (13) |
| Forum | Bildirim ayarları | ana/alt anahtar, iyimser PUT, hata geri alma, hızlı ardışık dokunuş, sessize alınanlar listesi | `forum_prefs_test` (9) |
| Forum | Şikâyet / paylaşım / push hedefi | şikâyet sheet'i, `/s/...` paylaşım bağlantıları, sohbete gönder, `forumTopic`/`forumComment` push hedefi | `forum_report_test` (14), `forum_share_test` (15), `forum_push_route_test` (10) |
| Destek | `support_page` (SSS + talepler) | SSS ara/aç, talep listesi, Yeni talep/Geri bildirim/Öneri girişleri | `destek_test` (3), `qa5_matrix` |
| Destek | `support_new_ticket_page` | kategori, konu >=3 karakter, mesaj, Idempotency-Key (5xx'te aynı, 4xx'te yeni), gövde, başarıda kapanma | `qa5_support_interactions` (11), `qa5_interactions` |
| Destek | `support_ticket_page` | mesajlar, ekip yanıtı, yanıt gönder, boş yanıt, 500'de metin korunur, kapalı talep, 2000 UTF-16 sınırı | `qa5_support_interactions` |
| Destek | `support_feedback_page` | kategori, konu/mesaj doğrulama, gövde (platform/appVersion), Idempotency-Key, 1000 sınırı | `qa5_support_interactions`, `qa5_interactions` |
| Destek | `support_suggestions_page` | liste, oy (PUT/DELETE iyimser), 429 geri alma, detay | `qa5_support_interactions`, `qa5_matrix` |
| Sözleşme | `legal_reaccept(_page)` | bekleyen belgeler, okuma, kabul, "daha sonra" (enforced=false), engelleyici kapı (403 `LEGAL_REACCEPT_REQUIRED`), 409 VERSION_OUTDATED | `legal_reaccept_test` (18) |
| Kabuk | Açılış kapısı `app_gate` | zorunlu güncelleme (market/https/yalnız metin, uzun metin 320 dp), isteğe bağlı güncelleme iletisi (günde 1), bakım bandı, duyuru bandı, çevrimdışı sessiz mod, öne dönüşte yeniden sorgu, kısmi kesinti | `app_gate_test` (5), `update_gate_test` (23), `m1_silent_offline_ui_test` (4), `qa5_regression`, `qa5_matrix` (4 kapı x 5 ortam) |
| Kabuk | `app_shell` | sekme kaydırma, varsayılan sekme | `shell_swipe_test` (5), `shell_default_tab_test` (2) |
| Kabuk | Çıkış temizliği `user_data.dart` | 17 yerel depo temizleyicisi (+ forum taslakları) | `a15_cache_test`, `qa5_regression` |
| Kabuk | Tema/dil/analitik/çökme | açık/koyu, tr/en/ar + RTL, analitik anahtarı, çökme raporu | `theme_test`, `crash_reporter_test` (12), `crash_audit_test` (12) |
| Kabuk | Push yönlendirme / derin bağlantı | oturumsuz bekleme, yinelenen bildirim, yabancı hesap, `/s/...` ayrıştırma | `push_actions_test` (5), `share_test`, `forum_share_test` |
| Backend | forum (konu/yorum/akış/arama/moderasyon/bildirim/anket/medya/profil/paylaşım/admin), support, legal, crash, appinfo, export | paket başına testler (bkz. bölüm 4) | `forum/**`, `support/**`, `legal/**`, `appinfo/**`, `common/IdempotencyFilterTest` |

Bilinen eşleme boşluğu: tek tek yorum eylemlerinin (düzenle/şikâyet/engelle) 320 dp ve ar/RTL varyantları matriste yalnız sayfa
düzeyinde (başarı hücresi) çizilir; eylem sheet'leri ayrı ayrı o ortamlarda açılmaz (mevcut testler tr/390 dp).

## 2. Bulgular

Şiddet: K=kritik, Y=yüksek, O=orta, D=düşük. Tür: HATA / YANLIŞ MANTIK (YM) / İYİLEŞTİRME (İY).

| Id | Şiddet | Tür | Ekran | Adım | Beklenen / Gerçek | Kök neden | Durum |
|---|---|---|---|---|---|---|---|
| QA5-01 | Y | YM | Açılış kapısı, push kaydı, çökme raporu | `--dart-define=APP_VERSION` verilmeden çalıştırma | Gerçek sürüm yerine koddaki `2.0.8` gidiyordu; eşik 2.1.3 olunca yanlış "zorunlu güncelleme", yanlış push/çökme sürümü | varsayılan pubspec'ten kopuk | DÜZELTİLDİ (2.2.0 + pubspec eşitlik testi) |
| QA5-02 | O | HATA | `compareVersions` (mobil), `AppInfoService.checkVersion` (backend) | `2.2.0+22006`, `2.1.3-beta` | mobil `0+22006`->22006; backend 400 ve kapı sessizce açılıyordu | ek/yapı numarası kesilmiyordu | DÜZELTİLDİ (iki yan + test) |
| QA5-03 | Y | HATA | Açılış kapısı | zorunlu güncelleme açıkken yalnız `/app/version` düşer | kapı kalkıyordu (zorunlu güncelleme atlatma) | koşul iki ucu birden istiyordu | DÜZELTİLDİ + widget testi |
| QA5-04 | O | HATA (KVKK) | Çıkış/hesap silme | konu taslağı yazıp çıkış | `forum_draft_v1_<uid>` cihazda kalıyordu | temizleyici listesinde yok | DÜZELTİLDİ (`ForumDraftStore.clearAll`) + test |
| QA5-05 | D | HATA | Yorum silme | aynı yorum iki kez silinir | sayaç iki kez düşüyordu | `remove` tek uçuşlu değildi | DÜZELTİLDİ + test |
| QA5-06 | O | HATA | `GET /api/app/version` | bozuk min/latest ayarı | 500 | `Long.parseLong` | DÜZELTİLDİ (bozuk parça 0) + test |
| QA5-07 | O | YM | Forum akışı | 5'ten fazla konu sabitlenir | fazlası Sana Özel/En Yeni'de hiç görünmüyordu | sınır yoktu | DÜZELTİLDİ: moderatör PIN'i en çok 5 (409 `FORUM_PIN_LIMIT`, tr/en/ar çeviri), mobil sunucu iletisini gösterir; testler (backend MVC + mobil widget) |
| QA5-08 | D | İY | Analitik | ilk açılış | Kullanım analizi varsayılan AÇIK, açık rıza ekranı yok | tasarım kararı | HUKUK KARARI BEKLİYOR (kod değişmedi) |
| QA5-09 | D | İY | Destek talebi / geri bildirim | yanıtı kaybolan gönderimin tekrarı | çift talep | `Idempotency-Key` yoktu | DÜZELTİLDİ: `IdempotencyFilter` `POST /api/support/tickets` ve `POST /api/feedback`'i de kapsar (kullanıcı kimliği + anahtar, Redis, 60 sn, 2xx sonucu tekrar döner, 2xx dışı anahtarı serbest bırakır, Redis yoksa fail-open); mobil anahtar üretir (ağ/5xx'te aynı, 4xx sonrası yeni); migration yok |
| QA5-10 | D | İY | Forum metin temizleme | konu/yorum/gerekçe | üç ayrı temizleyici, farklı kurallar | tarihsel | DÜZELTİLDİ: `ForumTextSanitizer` TEK uygulama; `ForumText` ve `ForumCommentText` ince cephe. Davranış farkları aşağıda |
| QA5-11 | D | İY | Ölü kod | `forum_placeholder_page.dart` | üretimde kullanılmıyordu | kalıntı | DÜZELTİLDİ (dosya + iki test içe aktarması silindi) |
| QA5-12 | D | İY | Destek formları | çok emojili metin | Flutter `maxLength` grafem sayar, sunucu `@Size` UTF-16 birimi: sınır altında görünen metin 400 alırdı | sayım birimi farkı | DÜZELTİLDİ: `Utf16LengthLimiter` (vekil çift bölünmez), sunucu birimiyle aynı; testli. Forum konu/yorum alanları zaten UTF-16 (`String.length`) saydığı için aynı birimde |

### QA5-10 davranış farkları (birleştirme sonrası)
Konu metni artık yorum/gerekçe ile aynı kurallardan geçer. Eskiye göre:
- `<script>...</script>` / `<style>` / `<iframe>` bloğu içeriğiyle silinir (önceden yalnız etiket silinir, içerik "alert(1)" kalırdı).
- HTML yorumları (`<!-- -->`) ve kapanmamış `<script` kuyruğu silinir; iç içe hile ("<scr<script>ipt>") 6 turda temizlenir.
- NFC normalizasyonu; soft hyphen, word joiner, BOM, bidi (LRE/RLE/PDF/LRO/RLO/izolat) silinir; ASCII harf/rakam arasındaki ZWJ/ZWNJ
  silinir, Arapça/Farsça ve emoji içindekiler korunur; LRM/RLM korunur.
- Satır içi ardışık boşluklar tek boşluğa iner (yorumda önceden korunurdu: "a   b" -> "a b"); satır başı/sonu boşluk kırpılır
  (önceden konu gövdesinde satır başı boşluk korunurdu).
- Korunanlar: tek başına `<`/`>` ("a < b"), `javascript:` gibi düz metin, 3+ boş satır -> 2, tek satır alanlarda satır sonu -> boşluk.
Testler: `ForumTextUnifiedTest` (üç yol aynı sonucu verir), `ForumTextTest`, `ForumTextSanitizerTest`, `ForumCommentServiceTest`,
`ForumTopicServiceTest` (güncellendi).

### Açık / karar bekleyen
- QA5-08: analitik varsayılan açık (hukuk).
- Eski test başlığı: `forum_search_test` "TopicCard 320 dp/1.3x yazıda kendi taşması var: author_line.dart:125" ifadesi bayat;
  `author_line.dart` şimdi `Wrap` kullanıyor, matris 320 dp/1.3x'te taşma görmedi (başlık düzeltilmedi, test geçiyor).
- Sürüm varsayılanı hâlâ derleme sabitidir (`APP_VERSION` verilmezse); release betikleri dart-define verir. Kalıcı çözüm
  `package_info_plus` bağımlılığıdır (yeni bağımlılık kararı).

## 3. Olumlu doğrulamalar (kod incelemesi)
Yorum sayaçları (`ForumCommentLifecycle`/`Counters` atomik UPDATE, kilit sırası, yer tutucu zinciri) mobil `_applyRemoved` ile uyumlu;
beğeni PK + atomik sayaç + mobil tek uçuş; anonimlik (konu/yorum/arama/profil/bildirim/FOR_YOU sıralaması/KVKK dışa aktarma kendi
verisi); silinmiş/kaldırılmış/gizli içerik akış, arama (yorum eşleşmesi dahil) ve profil sorgularında dışarıda; kendine bildirim yok,
10 dk birleştirme, kalıcı defter; hesap silme `AccountDataPurger` kayıt defteri + forum purger'ları; tüm forum yazma uçlarında hız
sınırı; moderasyon yalnız yetkili profil (`ForumPermissionPolicy`, `RbacCoverageTest`).

## 4. Backend taraması ve testleri
Taranan: sayaç atomikliği, anonimlik (DTO/arama/profil), moderasyon yetkileri, hız sınırları (tüm `@RestController` yazma uçları),
silinmiş/gizli içerik, arama SQL'i, bildirim tekrar koruması, KVKK silme/dışa aktarma. Yeni bulgu: QA5-07 (PIN sınırı), QA5-09
(destek idempotency), QA5-10 (temizleyici), QA5-06 (sürüm ucu). Hedefli koşu: `forum/**`, `support/**`, `legal/**`, `appinfo/**`,
`IdempotencyFilterTest`, `I18nMessagesIntegrityTest`, `RbacCoverageTest` (sonuçlar rapor/commit mesajında).

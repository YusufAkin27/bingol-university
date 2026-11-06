# QA-5: Kampüs Forum + Destek + Sözleşme + Uygulama Kabuğu (2026-11-06)

Kapsam: `mobile/lib/features/forum/**`, `support/**`, `legal/**`, `shell/**`, `core/app_gate.dart`, `core/analytics.dart`,
`core/crash*`, `core/push/push_router.dart`, `core/user_data.dart`; backend `forum` (admin dahil), `support`, `legal`, `crash`,
`analytics`, `appinfo`, `export`. Kulüp/etkinlik/floating_nav kapsam dışı.

Yöntem: ekran/öğe envanteri -> mevcut widget testleri taranıp boşluklar yeni testle kapatıldı -> kod incelemesi (hata + yanlış
mantık) -> bulgular -> düzeltme + regresyon testi. Yeni testler: `mobile/test/qa5/qa5_regression_test.dart`, backend
`AppInfoVersionCheckTest` (QA5 yöntemleri).

## 1. Envanter (ekran -> öğeler -> mevcut test kapsamı)

Not: "Test" sütunu dosya adı/konu eşlemesiyle çıkarılmıştır; öğe öğe doğrulanmadı, boşluk bulunan yerler bulgular bölümünde.

| Alan | Ekran / dosya | Öğeler (buton, alan, jest, sheet, durum) | Test (mevcut -> yeni) |
|---|---|---|---|
| Forum | Ana sayfa `forum_home_page` | sıralama çipleri (Sana Özel/En Yeni/Popüler/En Çok Yorumlanan/Takip), 79 kategori çipi (tek yatay satır, seçili çip görünür alana kayar), kategori seçici girişi, arama girişi, yeni konu FAB, çekerek yenile, sonsuz kaydırma + "tekrar dene" satırı, iskelet/boş/hata/yeniden onay durumları | `forum_home_test`, `forum_category_picker_test`, `forum_entry_test` |
| Forum | Kategori seçici `forum_category_picker_page` | aramalı liste, grup başlıkları, seçim, "tümü", boş sonuç | `forum_category_picker_test` |
| Forum | Konu açma `create_topic_page` | başlık(150)/metin(10 000) sayaç + sınır, kategori, anonim anahtarı, görsel şeridi (<=4, yükleme/hata/yeniden dene/kaldır), anket kurucu (2-N seçenek, tür), taslak kaydet/geri yükle, çift dokunma = tek konu (Idempotency-Key), çıkış onayı, 4xx/5xx/429/422 hata eşlemesi | `forum_compose_rules_test`, `forum_data_test`, `forum_entry_test` |
| Forum | Konu düzenleme `edit_topic_page` | başlık/metin/kategori, değişiklik yoksa kaydet kapalı, kilitli konu 409 | `forum_data_test` |
| Forum | Konu detayı `topic_detail_page` | başlık menüsü (düzenle/sil/paylaş/sohbete gönder/kaydet/takip/şikâyet/engelle/sessize al/moderatör), beğeni (iyimser), anket oyu, yorum yazma çubuğu, yorum sıralama, silinmiş/kilitli/gizli konu durumları, anonim yazar etiketi | `forum_topic_detail_test`, `forum_topic_detail_visual_test`, `forum_d/forum_share_test` |
| Forum | Yorum ağacı `comment_section/tree/card/controller` | yanıtla (üst, yanıtın yanıtı), "N yanıtı göster/gizle", girinti sınırı + ayrı zincir ekranı `comment_thread_page`, beğeni (tek uçuşlu iyimser), düzenle, sil (yer tutucu), kopyala, kaydet, şikâyet, engelle, "devamını oku", bildirimden yoruma odak | `forum_comment_tree_test`, `forum_d/forum_report_test` |
| Forum | Arama `forum_search_page` | metin alanı, debounce, kategori süzgeci, sıralama, son aramalar (ekle/sil/temizle), boş/hata durumları | `forum_d/forum_search_test` |
| Forum | Kaydedilenler / Etkinlik / Tercihler | `forum_saved_page`, `forum_activity_page` (konularım/yorumlarım/beğendiklerim), `forum_prefs_page` (bildirim tercihleri, sessize alınanlar) | `forum_d/forum_activity_test`, `forum_prefs_test` |
| Forum | Paylaşım / derin bağlantı | konu/yorum bağlantısı `/s/forum...`, sohbete gönder, push hedefi `forumTopic`/`forumComment` | `forum_d/forum_share_test`, `forum_push_route_test` |
| Destek | `support_page` (SSS + sekmeler), `support_new_ticket_page`, `support_ticket_page`, `support_feedback_page`, `support_suggestions_page` | SSS ara/aç, talep formu (konu 120/mesaj 2000), talep yanıtı (2000), geri bildirim (kategori, konu 80/mesaj 1000), öneri panosu (oy, sırala) | `test/support/*` + sayfa testleri |
| Sözleşme | `legal_reaccept(_page)` | bekleyen belge listesi, belge okuma, "kabul et", "daha sonra" (enforced=false), 403 `LEGAL_REACCEPT_REQUIRED` engelleyici kapı, 409 VERSION_OUTDATED yenileme | `legal_reaccept_test` |
| Kabuk | `app_gate`, `gate_views`, `splash_screen`, `error_views` | zorunlu güncelleme ekranı (market/https/yalnız metin), isteğe bağlı güncelleme iletisi (günde 1), bakım bandı, duyuru bandı (kapatılabilir), çevrimdışı sessiz mod, öne dönüşte yeniden sorgu (15 dk / kilit açıkken her dönüş) | `app_gate_test`, `update_gate_test`, `m1_silent_offline_ui_test`, `qa5` |
| Kabuk | `app_shell` | sekme geçişi, kaydırma, varsayılan sekme, push ile sekme isteği | `shell_swipe_test`, `shell_default_tab_test` |
| Kabuk | çıkış / oturum değişimi `core/user_data.dart` | 16 yerel depo temizleyicisi (+ forum taslakları: QA5-04) | `a15/a15_cache_test`, `qa5` |
| Kabuk | tema / dil / analitik / çökme | tema (açık/koyu/sistem), dil (tr/en/ar + RTL), "Kullanım analizi" ve "Çökme raporu" anahtarları (kapalıyken kuyruk silinir) | `theme_test`, `crash_reporter_test`, `crash_audit_test` |
| Kabuk | push yönlendirme `push_router` | oturumsuz bekleme (30 dk), yinelenen bildirim (8 sn), başka hesabın bildirimi yok sayılır, çözülemeyen hedef -> Bildirimler | `push_*_test` |
| Backend | forum (konu/yorum/akış/arama/moderasyon/bildirim/anket/medya/profil/paylaşım/admin), support, legal, crash, analytics, appinfo, export | mevcut paket testleri (`ForumReleaseIntegrationTest` + paket başına testler) | + `AppInfoVersionCheckTest` |

## 2. Bulgular

Şiddet: K=kritik, Y=yüksek, O=orta, D=düşük. Tür: HATA / YANLIŞ MANTIK (YM) / İYİLEŞTİRME (İY).

| Id | Şiddet | Tür | Ekran | Adım | Beklenen / Gerçek | Kök neden | Durum |
|---|---|---|---|---|---|---|---|
| QA5-01 | Y | YM | Açılış kapısı, push kaydı, çökme raporu | `--dart-define=APP_VERSION` verilmeden derlenen/çalıştırılan uygulama | Beklenen: gerçek sürüm (2.2.0) sunucuya gider. Gerçek: koddaki varsayılan `2.0.8` gider; sunucu `min_version`'ı 2.1.3 yapınca debug/dart-define'sız derlemeler yanlışlıkla "zorunlu güncelleme"ye düşer, "yeni sürüm var" iletisi sürekli çıkar, push cihaz kaydı ve çökme raporu yanlış sürüm yazar | `appVersion` varsayılanı pubspec'ten kopuk (docs/ANDROID_RELEASE.md "üçünü birlikte güncelleyin" kuralı elle) | DÜZELTİLDİ: varsayılanlar 2.2.0; `qa5_regression_test` varsayılanın pubspec ile eşit olmasını denetler (sürüm artınca test kırılır, unutulamaz) |
| QA5-02 | O | HATA | `compareVersions` (mobil), `AppInfoService.checkVersion` (backend) | sürüm `2.2.0+22006` ya da `2.1.3-beta` | Beklenen: ek yok sayılır. Gerçek: mobil `0+22006` -> 22006 sayar (her eşik yanlış); backend 400 `INVALID_VERSION` döner ve kapı sessizce açılır | ayrıştırma ek/yapı numarasını kesmiyor | DÜZELTİLDİ (iki yanda `+`/`-` sonrası kesilir) + testler |
| QA5-03 | Y | HATA | Açılış kapısı | zorunlu güncelleme açıkken yalnız `/app/version` 5xx/ağ hatası verir, `/app/info` gelir | Beklenen: kapı kalkmaz. Gerçek: koruma yalnız İKİ uç da düşünce çalışıyordu; kısmi kesintide kapı kalkıp uygulama açılıyordu (zorunlu güncelleme atlatılıyor) | koşul `r[0]==null && r[1]==null` | DÜZELTİLDİ (`r[0]==null`) + widget testi |
| QA5-04 | O | HATA (KVKK) | Çıkış / hesap silme / oturum değişimi | konu taslağı yazılıp çıkış yapılır | Beklenen: kullanıcıya özel yerel veri silinir. Gerçek: `forum_draft_v1_<uid>` (başlık, metin, yüklenmiş görsel adresleri, anonim bayrağı) cihazda kalıyordu; ortak cihazda aynı hesapla girene eski taslak görünür, hesap silinse bile kalır | `registerUserDataCleaners` listesinde yok | DÜZELTİLDİ (`ForumDraftStore.clearAll`, öneke göre tüm kullanıcılar) + test |
| QA5-05 | D | HATA | Yorum silme | yavaş ağda aynı yorumun silme eylemi iki kez onaylanır | Beklenen: sayaç bir kez düşer. Gerçek: sunucu ikinci silmeye de 204 döner; istemci `onCountDelta(-1)`'i iki kez uygular, "N yorum" sayısı yanlış düşer (ekran yenilenene dek) | `CommentsController.remove` tek uçuşlu değil | DÜZELTİLDİ (`_removing` + `deleted` koruması) + test |
| QA5-06 | O | HATA (dayanıklılık) | `GET /api/app/version` | `min_version_*`/`latest_version_*` ayarı elle bozulursa (örn. `2.x.3`, boş) | Beklenen: uç çalışır. Gerçek: `Long.parseLong` istisnası -> 500, tüm istemcilerin kapısı etkilenir | `compare` ayrıştırma hatasını yakalamıyor | DÜZELTİLDİ (bozuk parça 0) + test |
| QA5-07 | O | YM | Forum akışı (Sana Özel / En Yeni) | 5'ten fazla konu sabitlenir ya da `size`-1'den çok | Beklenen: sabitlenenler görünür. Gerçek: sabitleme sınırı yok; akış yalnız ilk `min(5,size-1)` sabitlenmişi gösterir, kalanlar bu iki sıralamada akıştan da çıkarıldığı için HİÇ görünmez (Popüler/En çok yorumlanan/Takip'te görünür) | `pinned()` limitli, `newest/candidates` tüm sabitlenmişleri hariç tutar; moderatör PIN'inde üst sınır yok | KARAR BEKLİYOR (iki çözüm: PIN'e 5 sınırı + 409 `FORUM_PIN_LIMIT` 3 dil çeviri, ya da fazla sabitlenmişi normal akışa bırakmak); ürün kararı |
| QA5-08 | D | İY | Analitik | ilk açılış | Kullanım analizi varsayılan AÇIK (toplulaştırılmış, kişisel veri yok); açık rıza ekranı yok. KVKK yorumu hukuk danışmanı kararı | tasarım kararı | KARAR BEKLİYOR |
| QA5-09 | D | İY | Destek talebi / geri bildirim gönderimi | yanıt kaybolur, kullanıcı tekrar gönderir | `Idempotency-Key` yok: sunucuya ulaşmış ama yanıtı kaybolmuş gönderim çift talep üretir (forum konu/yorumunda var, destekte yok) | uç sözleşmesinde anahtar yok | KARAR BEKLİYOR (backend + mobil birlikte; migration gerekir) |
| QA5-10 | D | İY | Forum metin temizleme | konu/yorum/gerekçe | Üç ayrı temizleyici: `ForumText` (konu), `ForumCommentText` (yorum), `ForumTextSanitizer` (SPI); kurallar farklı (örn. soft hyphen/ZWNJ/`<script>` bloğu yalnız birinde). İstemci düz metin çizdiği için XSS riski yok ama tutarsız | tarihsel olarak üç modülde | KARAR BEKLİYOR (tek temizleyiciye birleştirme, geriye uyumlu) |
| QA5-11 | D | İY | Ölü kod | `forum_placeholder_page.dart` | Üretimde kullanılmıyor; yalnız iki test içe aktarır | önceki aşama kalıntısı | Açık (silinirse iki test güncellenir) |
| QA5-12 | D | İY | Destek formları | 2000 emoji | Flutter `maxLength` grafem sayar, sunucu `@Size` UTF-16 birim sayar: çok emojili metin sınırın altında görünse de 400 `VALIDATION_ERROR` | sayım birimi farkı | Açık (düşük olasılık) |

İncelenip HATA bulunmayanlar (olumlu doğrulamalar): yorum sayaçları (`ForumCommentLifecycle`/`Counters` atomik, yer tutucu
mantığı mobil `_applyRemoved` ile uyumlu), beğeni idempotency (PK + atomik sayaç) ve mobil tek uçuşlu iyimser geri alma, anonim
kimlik (yorum/arama/bildirim/FOR_YOU sıralaması sızdırmıyor; arama anonim yorumları hariç tutuyor), silinmiş/kaldırılmış/gizli
içerik arama ve akış sorgularında dışarıda, kendine bildirim yok + 10 dk birleştirme + kalıcı defter, moderasyon yetkisi
(`/api/admin` yalnız ADMIN + RBAC), FOR_YOU sıralaması (üstel sönüm, imleç kararlı), derin bağlantı bekletme (oturum açılana
dek), geri bildirim/talep sınırları (mobil == sunucu).

## 3. Test özeti

Yeni: `mobile/test/qa5/qa5_regression_test.dart` (sürüm varsayılanı-pubspec eşitliği, compareVersions ek/2.1.3 eşiği, kısmi
kesintide kapı, taslak temizliği, çift silme); backend `AppInfoVersionCheckTest` (+2 test).

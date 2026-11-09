# Veri tabanı sağlık, güvenlik ve performans denetimi (2026-11-08)

Kapsam: BÜ Kampüs backend (Spring Boot 4, PostgreSQL 16 + Flyway, Redis 7, FCM) ve mobil veri erişim katmanı (Flutter).
Yöntem: yalnız **kod okuma** (4 bağımsız salt-okunur denetim: sorgu/indeks, güvenlik/yetki, bütünlük/eşzamanlılık, mobil + yedek/izleme). Canlı sisteme erişilmedi, canlıda hiçbir şey çalıştırılmadı, hiçbir veri okunmadı/değiştirilmedi.
**Ölçüm yok:** bu rapordaki hiçbir performans iddiası ölçülmüş değildir (EXPLAIN/yük testi yapılmadı); "önce/sonra" rakamı verilmez. Ölçüm için bkz. bölüm 7.

## 1. Gerçek altyapı

PostgreSQL 16 (tek kaynak, şema yalnız Flyway, 162 migration), Redis (oturum, rate limit, kilit, önbellek, pub/sub), STOMP/WebSocket, FCM (yalnız push). **Firebase Auth / Firestore / Realtime DB / Cloud Functions / Supabase kullanılmıyor**; bu teknolojilere ait denetim maddeleri uygulanamaz. Mobil tek API katmanından (`lib/core/api.dart`) backend'e gider.

Mevcut olgun noktalar (doğrulandı): cursor sayfalama, dar projeksiyonlar, `QueryRulesTest`, `statement_timeout 8 sn`, sayaçların atomik SQL ile artması, `client_id` ile mesaj idempotency, beğeni/oy için PK/UNIQUE kısıtları, `AccountDataPurger` kapsam testi, `RbacCoverageTest`, STOMP abonelik beyaz listesi, saatlik şifreli yedek + haftalık otomatik geri yükleme doğrulaması + alarmlar.

## 2. Bu dalda uygulanan düşük riskli değişiklikler

Dal: `audit/db-health` (backend), `feature/mobil-uygulama` (mobil). **Hiçbiri canlıya alınmadı.**

| # | Değişiklik | Dosyalar | Neden / etki | Geri alma |
|---|---|---|---|---|
| 1 | Çok örnekli çalışmada çift iş/yarışı önlemek için 5 `@Scheduled` işine `SchedulerLock` (isteğe bağlı setter enjeksiyonu; kilit yoksa eski davranış, Redis kesintisinde tek örnekli ayar korunur: `tryRunOrLocal`) | `news/NewsSyncService`, `menu/MenuSyncService` (sync + catch-up), `media/MediaOrphanSweeper`, `notification/DeviceCleanupJob`, `notification/NotificationRetentionJob` | İki örnekte kaynak siteye çift istek/çift bildirim, aynı yetim dosyayı iki örneğin silmesi. Tek örnekte davranış aynı | Dosya bazlı `git revert` |
| 2 | Geliştirme `docker-compose.yml` Redis'e `--maxmemory 200mb --maxmemory-policy volatile-lru` (prod ile aynı) | `docker-compose.yml` | Bellek dolunca konteynerin OOM ile ölmesi yerine tahliye | Satırı eski haline getir |
| 3 | Mobil `Idempotency-Key` rastgeleliği `Random.secure()` ile güçlendirildi (biçim aynı) | `mobile/lib/core/idempotency_key.dart`, test `idempotency_key_unique_test.dart` (100 bin anahtar benzersiz) | Düşük entropi: aynı mikrosaniyede çakışırsa sunucu ikinci kaydı sessizce yutardı | Dosyayı geri al |

Testler: bkz. bölüm 6.

## 3. Bulgular (önem sırasıyla; hepsi KOD OKUMASINA dayanır)

### YÜKSEK
1. **Forum anonimliği engelleme uçlarıyla kırılabilir** — `forum/moderation/ForumBlockAuthorController` (`POST /api/forum/topics/{id}/block-author`, `/comments/{id}/block-author`) anonim olup olmadığına bakmadan gerçek yazarla global `blocks.block(...)` çağırıyor; `GET /api/users/me/blocks` listesinde yazar görünür. Ayrıca yazar beni engellemişse uç 404 döndüğü için bir oracle oluşur. **Çözüm önerisi:** anonim içerikte global engel yerine forum sessize alma anahtarı (`ForumViewerFilter.mutedKey`) kullanmak; engel listesine anonim kaynaklı kayıt yazmamak. **Risk: ORTA** (davranış + istemci değişir) → uygulanmadı. Test: anonim konu aç, B `block-author` çağırsın, B'nin `/me/blocks` çıktısında A olmamalı.
2. **Yedek tek katmanlı kalabilir** — `BACKUP_REMOTE` boşsa yedekler yalnız sunucu diskindedir (deploy yalnız uyarı verir); yerel saklama yalnız 3 yedek (≈3 saat). Bozulma/yanlış silme 3 saatten geç fark edilirse yerelde temiz kopya kalmaz. Uzak hedef varken uzak RPO ~24 sa; dokümanlar (BACKUP.md / BACKUP_RESTORE.md) RPO'yu tek rakamla (1 sa) yazıyor. **Öneri:** uzak hedefi zorunlu yapmak/prod'da alarmlamak, yerelde haftalık+aylık tutmak (`KEEP_WEEKLY=1`, `KEEP_MONTHLY=1`, hardlink), RPO'yu iki katmanlı yazmak. Risk: disk (yapılandırma) → uygulanmadı, karar sende.
3. **Bildirim kategori sorgusu indeks kullanamaz** — `notification/NotificationRepository.pageCategory`: `n.data LIKE '%"pollId"%'` ve `replace(n.data,' ','') LIKE ...` zinciri. Kullanıcı başına ≤200 satır sınırı etkiyi sınırlar. **Öneri:** kategori bilgisini yazım anında `type/subtype`'a taşıyıp sorguda yalnız onları kullanmak; **önce `EXPLAIN (ANALYZE, BUFFERS)` ile ölç**. Risk ORTA (migration/yazan servisler) → uygulanmadı.

### ORTA
4. Forum/anket sayaçları için **onarım işi yok** (`PostCounterRepairJob` yalnız post beğeni + takip; `CommentCounterRepairJob` yalnız gönderi yorumları). Onarılmayanlar: `forum_topic.comment_count/like_count/bookmark_count`, `forum_comment.like_count/reply_count`, `forum_poll_option.vote_count`, `poll_option.vote_count`. **Öneri:** `PostCounterRepairJob` kalıbında, `SchedulerLock`'lu, parçalı `ForumCounterRepairJob` (yalnız sapmış satırı `UPDATE`). Yeni davranış → onay bekler. Not: `poll.voter_count` hesap silmede **bilerek** sapar (oy NULL'lanır, sayaç korunur); sapma denetiminde hariç tutulmalı.
5. **Mesaj "okundu" imleci id'ye bağlı** (IDENTITY id commit sırasından önce alınır): A(100) yavaş, B(101) önce commit olur ve alıcı 101'e okundu atarsa 100 "okundu" sayılabilir. Pratikte nadir (şüphe). Kabul edilmiş risk olarak belgelendi.
6. **Çok örnekli kilitsiz `@Scheduled` işleri (kalan):** `messaging/DeletedMessageRetention`, `messaging/media/ChatMediaMaintenance`, `common/IdempotentCreate`, `community/extras/ClubExtrasMaintenance`, `messaging/room/RoomMaintenance`, `event/chat/EventChatMaintenance`. Silmeler idempotent olduğundan zarar değil, çift yüktür. Aynı setter kalıbıyla kilitlenebilir (bu dalda 5'i yapıldı).
7. **5 dk'da bir periyodik ağır sorgular:** `RoomMaintenance` / `ClubExtrasMaintenance` (`club_join_answer ... app_user.status='DELETED'`, `app_user.status` indeksi doğrulanmadı), `EventChatMaintenance` (çok tablolu NOT EXISTS, sınırsız `toClose`). **Öneri:** `LIMIT` + parçalama; aralığı `app.chat.room-purge-ms` ile gevşetmek. Ölçülmedi.
8. **Herkese açık arama `LIKE '%x%'`**, trigram indeksi yok: `event/UserEventRepository` (title/description/location), `community/CommunityRepository` (name/description), `search/SearchSuggestService` (topluluk). `pg_trgm` GIN indeksi **migration** gerektirir → canlıda otomatik uygulanmaz (YÜKSEK/ORTA risk). Haber araması için indeks zaten var.
9. **Sıcak satır sayaçları:** `post.view_count/completion_pct_sum/like_count`, forum/anket sayaçları tek satırı güncelliyor; viral içerikte satır kilidi sırası/ölü satır. Doğruluk açısından güvenli (atomik). İyileştirme (Redis'te biriktirip toplu yazma) davranış değiştirir. Ölçülmedi.
10. **Gizli oy yalnız API düzeyinde** (şüphe): `poll_vote`/`forum_poll_vote` oyu `user_id` ile saklar; CSV/API kimliksiz ama DB/yedek oyu kişiye bağlar. Gerçek anonimlik ürün sözüyse `ballot` (kim oy verdi) ile `vote` (ne verdi) ayrılmalı (şema değişikliği, YÜKSEK risk). Ürün kararı.
11. **Herkese açık `/files/**`** (permitAll, `public, immutable, 30 gün`): gizlenen/silinen gönderi görseli URL sızdıysa 30 gün erişilebilir (şüphe; sohbet/forum özel depoda imzalı). **Öneri:** gizli/silinen gönderi dosyasını fiziksel silmek, önbellek süresini kısaltmak.
12. **Mobil önbellek şifresiz düz dosya** (`message_cache`, `disk_cache`, uygulama sandbox'ında). Root'lu cihaz/yedek (Android `allowBackup`) ile okunabilir. **Öneri:** `allowBackup=false`/`dataExtractionRules` doğrulaması; hassas içerik için secure storage anahtarıyla şifreleme. Risk orta.
13. **Sohbet yoklaması:** STOMP açıkken bile ~20 sn'de bir tam `?size=30` isteği (ETag/304 hafifletir). Aralığı artırmak mesaj kaçırma emniyetini zayıflatır → uygulanmadı.
14. **Redis yedeği yok** (prod'da AOF var ama `redisdata` yedeğe girmiyor); kaybında oturumlar gider. `suspended:<id>` gibi TTL'siz işaretlerin kaynağının DB olduğu doğrulanmalı (değilse DB'den yeniden yüklenmeli).
15. **Redis parolası prod'da isteğe bağlı** (`REDIS_PASSWORD` boşsa parolasız; ağ `internal` olduğu için erişim sınırlı). **Öneri:** deploy/`gen-secrets` ile zorunlu üretmek.
16. **Idempotency kapsamı:** `IdempotencyFilter.covered()` yalnız admin yazma, destek talebi, geri bildirim, gönderi yorumu; rapor (`report`), topluluk katılma/başvuru, takip isteği gibi POST'lar eklenebilir (filtre Redis yokken fail-open, TTL 60 sn). Düşük risk ama yanıt önbelleği sınırını (16 KB) doğrulamak gerekir.
17. **Forum yorum FK'lerinde ON DELETE yok** (`forum_comment`, `forum_comment_like`); bugün yumuşak silme olduğundan sorun yok, ileride fiziksel silen bir saklama işi FK hatasıyla takılır (şüphe).

### DÜŞÜK / BİLGİ
- `/api/auth/**` `permitAll`: yeni kimlikli bir uç buraya eklenip listelenmezse sessizce açılır. **Öneri:** `SecurityConfigAuthMatrixTest` (her `/api/auth/*` uç için beklenen erişim).
- STOMP SUBSCRIBE'da abonelik sayısı sınırı ve süresi dolmuş token reddi yok (kuyruklar Principal'a bağlı, başkasının kuyruğuna abone olunamıyor; canlıda denenmedi).
- `PublicProfile.email` alanının `showEmail=false` iken null döndüğü doğrulanmadı (şüphe) → test eklenmeli.
- Video izlenme sayacı istemci beyanına dayanır (hesap başı 240/dk limit var); çoklu hesapla şişirilebilir. IP başına günlük tavan eklenebilir.
- Beğeni görünen sayısı = `like_count + like_boost`; liste (beğenenler) gerçek sayıyı gösterir → "50 beğeni, listede 3 kişi" görünür. Ürün kararı (bilinçli).
- `NewsSyncService.existsByUrl` döngüde (gece, küçük liste; `news_item.url` UNIQUE'i doğrulanmalı).
- `AppInfoService.all()` önbelleksiz (yönetici ucuysa sorun değil).
- Mobil: dakikalık rozet yoklaması ve push `viewing` zamanlayıcısının arka planda iptali doğrulanmalı; çıkışta widget deposu temizliği test edilmeli; genel istek zaman aşımı 20 sn (yükleme yolu ayrı).
- Insert'lerde `CURRENT_TIMESTAMP` (DB saati) ile `Instant.now()` (uygulama saati) karışık; çok sunuculu kurulumda küçük sıralama sapması olabilir (şüphe).
- Bağlantı bütçesi: Hikari 30 × replika + yedek/exporter/Flyway ≤ `max_connections=100`; replika artırılırken `pg_stat_activity` ile ölçülmeli.
- KVKK: silinen kullanıcının mesaj metni karşı tarafın verisi gerekçesiyle korunuyor (hukuki karar, kod hatası değil).

## 4. Yedekleme ve felaket kurtarma durumu

Mevcut: saatlik `pg_dump -Fc` + uploads tar/zstd, **age ile şifreli**, SHA256 doğrulamalı; haftalık otomatik geri yükleme doğrulaması (`verify-restore.sh`); rclone ile uzak kopya (indirip doğrular); `BackupTooOld/LastRunFailed/VerifyFailed/RemoteStale` alarmları + webhook; RPO 1 sa / RTO 2 sa hedefi dokümante.
Riskler: bölüm 3 madde 2, 14, 15; WAL arşivi/PITR yok (saat içi veri kaybı kabul edilmiş, işletme kararı); DB ve uploads yedeği atomik değil (geri yüklemede DB'de olup diskte olmayan dosya referansı çıkabilir → geri yükleme sonrası tutarlılık betiği önerilir); age özel anahtarı yerel tek kopya ise geliştirici makinesi kaybında tüm yedekler çözülemez (iki ayrı fiziksel yerde saklama + yıllık çözme provası). **Canlıda geri yükleme testi yapılmadı** (yalnız izole ortam önerilir).

## 5. Veri tutarlılığı: salt okunur denetim sorguları

`docs/db-integrity-checks.sql` — yalnız `SELECT COUNT(*)`, kişisel veri göstermez, **otomatik çalıştırılmaz**; sütun adları çalıştırmadan önce şemada doğrulanmalıdır (özellikle forum tabloları ve `device`/`app_user` kalıntı sorguları). `poll.voter_count` karşılaştırılmaz (tasarım gereği sapar).

## 6. Testler

Backend (Docker, Java 17, H2): hedefli testler `NewsSyncServiceTest, MenuSync*Test, MediaStorageTest, OrphanSweeperQueryCountTest, DeviceAndPrefServiceTest, PushDeliveryTest, PostFeedSeenTest, RbacCoverageTest`. Sonuç: 52 test, 0 hata (RbacCoverageTest, MediaStorageTest, OrphanSweeperQueryCountTest, MenuSyncServiceTest, DeviceAndPrefServiceTest, PushDeliveryTest, PostFeedSeenTest). NewsSyncServiceTest adında test yok (haber senkron testleri farklı adla).
Mobil: `flutter test test/idempotency_key_unique_test.dart` geçti (100 bin anahtar benzersiz, biçim korunur).
**Çalıştırılmayan:** gerçek cihaz/ağ, üretim entegrasyonu, yük testi, EXPLAIN ANALYZE, güvenlik kurallarının canlı doğrulaması, çoklu örnek entegrasyon testi.

## 7. Üretime geçiş öncesi yapılacaklar ve ölçüm planı

1. `audit/db-health` dalını inceleyip birleştirmek ve **ayrı bir deploy kararı** vermek (bu çalışma deploy etmedi).
2. Ölçüm: `scripts/perf/seed-20k.sql` ile test yığınında `EXPLAIN (ANALYZE, BUFFERS)`: `NotificationRepository.pageCategory`, topluluk/etkinlik `ILIKE`, `EventChatMaintenance`; `pg_stat_user_tables.n_dead_tup` (sayaç sıcak satırları); `pg_stat_activity` bağlantı sayısı; k6 yük testi (`scripts/perf/load`).
3. Karar bekleyenler: forum anonim engel davranışı (madde 1), gizli oy mimarisi (10), uzak yedek zorunluluğu ve yerel saklama (2), `/files` önbellek/silme politikası (11).
4. Migration gerektirenler (trigram, kategori sütunu) yalnız **staging'de** denenip ayrı onayla uygulanmalı.

## 8. Geri alma talimatı

Bu dalın değişiklikleri küçük ve bağımsızdır: `git revert <commit>` (backend) veya ilgili dosyayı eski haline getirmek yeterlidir. Veri/şema değişikliği yoktur, migration eklenmemiştir.

## 9. Genel sağlık değerlendirmesi (ölçüme dayanmayan, kod incelemesine dayalı nitel görüş)

| Boyut | Görüş |
|---|---|
| Güvenlik | İyi; bir yüksek bulgu (forum anonimlik) ve birkaç şüphe |
| Performans | İyi tasarım; birkaç periyodik/LIKE sorgusu ölçülmeli (ölçülmedi) |
| Veri bütünlüğü | İyi; forum/anket sayaç onarımı eksik |
| Yedekleme | Güçlü mekanizma; uzak kopya/yerel saklama süresi ve Redis yedeği riskleri |
| Dayanıklılık | İyi (retry yalnız GET, idempotency, fail-closed kilit) |
| İzlenebilirlik | İyi (alarmlar mevcut); alıcı kanalların dolu olduğu doğrulanmalı |

Sayısal puan verilmemiştir (yeterli ölçüm yok).

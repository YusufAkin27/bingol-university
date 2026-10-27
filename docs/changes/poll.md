# Anket ve oylama (poll)

Paket `edu.bingol.backend.poll`, migration `V330__polls.sql` (önek `pol330_`), çeviri `i18n/poll*.properties` (tr/en/ar; `spring.messages.basename` listesine eklendi). Sözleşme: `docs/API_CONTRACTS_V2.md` → "Anket ve oylama".

## Davranış özeti
- **Türler:** `SINGLE`, `MULTI` (`maxChoices`), `RATING` (1–5 yıldız; 5 sabit seçenek), `RANKED` (sıralı seçim; 1. tercih sayısı + Borda puanı).
- **Kapsamlar:** `GLOBAL` (yalnız ADMIN oluşturur), `COMMUNITY` (kulüp yöneticisi/sahibi; yalnız aktif üyeler görür/oy verir; varsayılan gizli oy = kulüp seçimi), `MENU` (yemek listesi günü; `GET /api/polls/menu/today` ilk istekte otomatik oluşturur, her gece 00:05 de önceden oluşturulur).
- **Gizli oy:** `poll_vote.user_id` yalnız tekillik/değiştirme için tutulur; hiçbir API/yönetici/CSV bunu göstermez. Kullanıcı yalnız kendi oyunu (`myVote`) ve `GET /api/users/me/export` → `polls` bölümünde görür.
- **Sonuç görünürlüğü:** `ALWAYS | AFTER_VOTE | AFTER_CLOSE`; yönetici uçları her zaman görür.
- **Hedef kitle:** `audience {faculty, department, grade}` profil alanlarıyla büyük/küçük harf duyarsız eşleşir.
- **Yarış güvenliği:** oy/değiştirme/geri çekme anket satırını `PESSIMISTIC_WRITE` ile kilitler; sayaçlar atomik `UPDATE ... SET x = x + :d`; `(poll_id,user_id)` seçmen kaydı UNIQUE, `(poll_id,user_id,option_id)` UNIQUE. Oy anında süre yeniden denetlenir (kapanış işi gecikse bile oy kabul edilmez).
- **Kapanış işi** (`PollCloseJob`, varsayılan her 10 dk, `app.poll.close-cron`; `SchedulerLock "poll-close"`): süresi dolan anketleri `CLOSED` yapar, "anket açıldı" (`notify=true`) ve "24 saat kaldı" (yalnız oy vermemiş uygun kullanıcılara) bildirimlerini gönderir.
- **Bildirim:** `GLOBAL` → `ANNOUNCEMENT`, `COMMUNITY` → `COMMUNITY` türü (kullanıcı tercihi kapalıysa gitmez); alıcı dilinde (`notif.poll.opened.*`, `notif.poll.closing.*`); push `target=POLL`.
- **Küfür filtresi** başlık/açıklama/seçeneklerde (`CONTENT_PROFANITY` + `field`).
- **Hız sınırları:** oy 60/dk, oluşturma 10/saat, okuma 120/dk, diğer yazma 60/dk, yönetici 120/dk.

## KVKK
- `AccountDataPurger`: `poll_ballot` silinir; `poll_vote.user_id` NULL (anonimleşir, sayaçlar `poll_option.vote_count` / `poll.voter_count` korunur); `poll.created_by` NULL.
- `DataExporter` `polls`: kullanıcının oyları (seçenek metniyle, gizli ankette de) ve oluşturduğu anketler.

## Kısıtlar / notlar
- Menü anketi için bir gün = bir anket (`UNIQUE menu_date`); öğün ayrımı yok (menü modülü günlük tek satır tutar). Silinmeden aynı gün yeniden oluşturulamaz.
- `RANKED` yüzdesi 1. tercih sayısına göredir; sıralama için `score` (Borda) kullanın.
- Kapanış işi PostgreSQL/H2 farkı gerektirmez; ancak `FOR UPDATE` kilidi ve kısmi indeksler gerçek PostgreSQL'de `scripts/smoke-poll.sh` ile doğrulanır.

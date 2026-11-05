# Kampüs Forum — C alanı: konu anketi (2026-11-05)

Paket `edu.bingol.backend.forum.poll`, migration `V1420__forum_poll.sql`, i18n `forumpoll*.properties`. Sözleşme: `docs/FORUM_API.md` §1-C, §2-C.

## Veri modeli

- `forum_poll(id, topic_id UNIQUE, question ≤200 NULL, ends_at NULL, allow_change_vote, created_at)`
- `forum_poll_option(id, poll_id, text ≤80, position, vote_count ≥ 0)`
- `forum_poll_vote(poll_id, user_id, option_id, created_at, PK(poll_id, user_id))` — kişi başına tek oy veritabanı seviyesinde.
- İndeks adları `fc14_` önekli. Mevcut `poll` modülü yeniden kullanılmaz (ayrı tablo, `Forum...` sınıf önekleri; bean/tablo çakışması yok).

## Uçlar

| Uç | Davranış |
|---|---|
| `PUT /api/forum/topics/{id}/poll/vote` `{optionId}` → `Poll` | Oy ver; aynı seçeneğe tekrar = idempotent; başka seçenek: `allowChangeVote=true` ise taşınır (eski sayaç düşer, yenisi artar, tek işlem), değilse 409 `FORUM_POLL_ALREADY_VOTED`. Kapalı anket / kilitli konu 409 `FORUM_POLL_CLOSED`; görünmez, kaldırılmış konu ya da anketsiz konu 404 `FORUM_POLL_NOT_FOUND`; seçenek başka ankete ait/yok 404 `FORUM_POLL_OPTION_NOT_FOUND`; `optionId` yok 400 `FORUM_POLL_OPTION_REQUIRED`. |
| `DELETE /api/forum/topics/{id}/poll/vote` → `Poll` | Oyu geri al; yalnız `allowChangeVote` ve açık anket (aksi 409 `FORUM_POLL_CHANGE_NOT_ALLOWED` / `FORUM_POLL_CLOSED`); oy yoksa idempotent. |
| `GET /api/forum/topics/{id}/poll` → `Poll` | **Ek (sözleşmede yok):** yalnız anket gövdesini tazelemek için; `TopicView.poll` ile aynı biçim. |

`Poll`: `{id,question,options:[{id,text,voteCount,percent}],totalVotes,myOptionId,endsAt,closed,allowChangeVote,canVote}`. Yüzde 0-100, **1 ondalık** (yarı yukarı), toplam 0 ise 0.0. Sonuçlar herkese her zaman görünür. Oy verenler kimlikle HİÇBİR uçta listelenmez (görünümde kimlik alanı yoktur; test eder). `closed` = `ends_at <= şimdi` (okuma anında hesap, zamanlayıcı yok). `canVote` = açık ve (oy yok ya da değiştirme açık).
Hız sınırı: oy ver / geri al 60/dk (kullanıcı başına ortak anahtar `forum:poll:vote:<id>`).

## Oluşturma (A çağırır)

`ForumPollService.createForTopic(topicId, req)` konu oluşturma işlemine KATILIR (`@Transactional` REQUIRED): geçersiz anket konuyu da geri alır. Kurallar: 2-6 seçenek, her biri ≤80 karakter, boş/yalnız-HTML seçenek yok, büyük-küçük harf duyarsız tekrar yok, soru ≤200, `endsAt` gelecekte ve ≤30 gün, metinler HTML/kontrol/yön-geçersiz karakterlerden arındırılır, `ContentGuard` (alan adı `poll.question`, `poll.options[i]`) uygulanır. Hata kodları (hepsi 422 aksi belirtilmedikçe): `FORUM_POLL_OPTIONS_INVALID`, `FORUM_POLL_OPTION_TOO_LONG`, `FORUM_POLL_QUESTION_TOO_LONG`, `FORUM_POLL_DUPLICATE_OPTION`, `FORUM_POLL_ENDS_INVALID`, 409 `FORUM_POLL_EXISTS`.

## Yarış dayanıklılığı

- Çift oy: PK(poll_id, user_id). Eşzamanlı iki ilk oyda ikincisi benzersizlik kısıtına çarpar, işlem geri alınır ve YENİDEN denenir (oy artık görünür: aynı seçenekse idempotent).
- Oy değişimi koşulludur (`UPDATE ... WHERE option_id = eski`); eşzamanlı ikinci değişim 0 satır etkiler, yeniden okur.
- Sayaçlar yalnız atomik `vote_count = vote_count + k`; seçenek kimliğine göre sıralı (kilitlenme yok). Dört denemeden sonra 409 `FORUM_POLL_BUSY`.

## KVKK

- Hesap silme: `ForumPollAccountPurger` `UserAccountDeletedEvent`'i (ProfileService'ten senkron, aynı işlem) dinler; sayaçları düşürür ve oy satırlarını siler. `AccountDataPurger.HANDLED_ELSEWHERE` içinde `forum_poll_vote.user_id` kayıtlıdır (coverage testi).
- `DataExporter` bölümü `forumPollVotes` (kullanıcının oy verdiği konu/seçenek). E alanı genel forum dışa aktarımı yapıyorsa bu bölüm yine ayrıdır, çakışmaz.

## Sapmalar / notlar

- Görünmez konu da, anketsiz konu da 404 `FORUM_POLL_NOT_FOUND` (A'nın hata koduna bağımlılık yok).
- Kilitli konuda oy 409 `FORUM_POLL_CLOSED` (kilitli konu = anket oylamaya kapalı); `Poll.closed` yalnız `ends_at`'a bakar, `canVote` kilidi bilmez (A, `TopicView.locked` ile birlikte sunar).
- `GET .../poll` eklendi (yukarıda).

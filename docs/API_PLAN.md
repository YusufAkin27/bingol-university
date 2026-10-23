# API ve Özellik Planı (öneri — onay bekliyor)

Kural: yalnızca `@bingol.edu.tr` (alt alan dahil) e-postası olan, doğrulanmış kullanıcılar. Dışarıdan kullanıcı yok.
Aşağıdaki her modül bağımsızdır; beğenilenler seçilip sırayla yazılır. ✅ = mevcut, 🆕 = yeni.

## Genel kurallar (tüm yeni uçlar)
- Kimlik: `Authorization: Bearer <access>`; herkese açık olanlar işaretli (🌐).
- Hata gövdesi: `{"code","message"}` (mevcut `ApiException`). Doğrulama: `VALIDATION_ERROR`.
- Liste: imleç tabanlı sayfalama `?cursor=<id>&size=20` → `{items, nextCursor}`.
- Rate limit (Redis): yazma uçlarında kullanıcı başına dakika/saat limiti; aşılırsa 429 `RATE_LIMITED`.
- Yetki: `USER`, topluluk içinde `MEMBER | MODERATOR | OWNER`, sistemde `ADMIN`. `User`'a `role` alanı eklenir.
- Silme: kullanıcı verisinde yumuşak silme (`deletedAt`), KVKK için hesap silme uçu.

## Mevcut ✅
`/api/auth/*` (register, resend-code, verify-email, login, refresh, logout, me) · `GET /api/news`, `/api/news/{id}` · `GET /api/menu`, `/api/menu/today` · `GET /api/status` · `POST /api/admin/sync`, `/api/admin/sync-menu`

---

## 1. Profil 🆕 (küçük, diğer her şeyin temeli)
Alanlar: `displayName`, `department` (bölüm), `year`, `bio`, `avatarUrl`, `showEmail`(varsayılan false).

| Metod | Yol | Açıklama |
|---|---|---|
| GET | `/api/users/me` | Kendi profilim (genişletilmiş `me`) |
| PATCH | `/api/users/me` | `{displayName?, department?, year?, bio?, showEmail?}` |
| POST | `/api/users/me/avatar` | multipart, ≤2 MB, jpg/png |
| GET | `/api/users/{id}` | Başkasının herkese açık profili |
| GET | `/api/users/search?q=ali` | İsim ile ara (≥2 harf, sayfalı); e-posta dönmez |
| DELETE | `/api/users/me` | Hesabı sil (şifre ister) — KVKK |
| GET | `/api/departments` 🌐 | Bölüm listesi (sabit/seed) |

## 2. Bildirimler 🆕 (FCM push + uygulama içi)
| Metod | Yol | Açıklama |
|---|---|---|
| POST | `/api/devices` | `{fcmToken, platform}` cihaz kaydı (aynı token tekrar gelirse güncellenir) |
| DELETE | `/api/devices/{token}` | Çıkışta cihaz kaydını sil |
| GET | `/api/notifications` | Uygulama içi bildirim listesi (sayfalı) |
| POST | `/api/notifications/read` | `{ids:[...]}` veya `{all:true}` |
| GET / PUT | `/api/notifications/preferences` | `{news, announcements, events, messages, communities}` aç/kapa |

Tetikleyiciler: scraper yeni duyuru/haber bulunca (konu `news-duyuru` vb. — abonelik tabanlı, kişi başı değil), yeni mesaj, etkinlik hatırlatma (1 gün/1 saat önce), topluluk daveti.

## 3. Topluluklar (kulüp / öğrenci grupları) 🆕
Model: `Community{name, slug, description, category, coverUrl, joinPolicy(OPEN|APPROVAL), visibility(PUBLIC|PRIVATE), ownerId}`, `Membership{userId, role, status(ACTIVE|PENDING|BANNED)}`, `CommunityPost{authorId, text, imageUrl, pinned}`.
Oluşturma: herkes oluşturabilir ama `PENDING_REVIEW` olur, ADMIN onaylayınca yayına girer (spam önleme). Kullanıcı başına en fazla 3 sahip olunan topluluk.

| Metod | Yol | Açıklama |
|---|---|---|
| POST | `/api/communities` | Oluştur → 202 (onay bekler) |
| GET | `/api/communities?category=&q=&cursor=` | Keşfet (yalnızca onaylı + PUBLIC) |
| GET | `/api/communities/{id}` | Detay + benim üyelik durumum + üye sayısı |
| PATCH | `/api/communities/{id}` | OWNER/MODERATOR: bilgi güncelle |
| POST | `/api/communities/{id}/join` | OPEN → hemen üye, APPROVAL → PENDING |
| DELETE | `/api/communities/{id}/membership` | Ayrıl |
| GET | `/api/communities/{id}/members` | Üyeler (sayfalı) |
| GET | `/api/communities/{id}/requests` | MODERATOR: bekleyen istekler |
| POST | `/api/communities/{id}/requests/{userId}/approve` · `/reject` | |
| PUT | `/api/communities/{id}/members/{userId}/role` | OWNER: `MODERATOR/MEMBER` |
| DELETE | `/api/communities/{id}/members/{userId}` | MODERATOR: çıkar / `ban` |
| GET / POST | `/api/communities/{id}/posts` | Akış / paylaşım (üye) |
| DELETE | `/api/communities/{id}/posts/{postId}` | Yazar veya MODERATOR |
| GET | `/api/me/communities` | Üyesi olduklarım |
| POST | `/api/admin/communities/{id}/approve` · `/reject` | ADMIN |

## 4. Kullanıcı etkinlikleri 🆕 (resmi etkinliklerden ayrı)
Model: `UserEvent{title, description, startsAt, endsAt, location, coverUrl, capacity, communityId?, createdBy, status}`, `Rsvp{userId, status(GOING|INTERESTED)}`.
Topluluğa bağlı etkinliği yalnızca MODERATOR+ açar; bağımsız etkinlik ADMIN onayına düşer.

| Metod | Yol | Açıklama |
|---|---|---|
| POST | `/api/events` | Oluştur (`communityId` opsiyonel) |
| GET | `/api/events?from=&to=&communityId=&cursor=` | Yaklaşan etkinlikler (+ siteden gelen resmi `ETKINLIK` kayıtlarıyla birleşik takvim görünümü opsiyonel) |
| GET | `/api/events/{id}` | Detay + katılımcı sayısı + benim durumum |
| PATCH / DELETE | `/api/events/{id}` | Oluşturan veya MODERATOR |
| PUT | `/api/events/{id}/rsvp` | `{status: GOING\|INTERESTED}`; kapasite dolunca 409 `EVENT_FULL` |
| DELETE | `/api/events/{id}/rsvp` | Vazgeç |
| GET | `/api/events/{id}/attendees` | Katılımcılar (organizatöre) |
| POST | `/api/events/{id}/check-in` | QR/kod ile giriş yoklaması (isteğe bağlı) |
| GET | `/api/me/events` | Katılacaklarım |

## 5. Mesajlaşma 🆕 (tasarım: `docs/MESSAGING_DESIGN.md`)
REST
| Metod | Yol | Açıklama |
|---|---|---|
| POST | `/api/conversations` | `{userId}` birebir (varsa mevcut döner) · `{title, memberIds}` grup |
| GET | `/api/conversations` | Konuşma listesi (son mesaj, okunmamış sayısı) |
| GET | `/api/conversations/{id}/messages?before=&size=30` | Geçmiş (imleç) |
| POST | `/api/conversations/{id}/messages` | WebSocket yoksa yedek gönderim; `{text, clientId}` (idempotent) |
| POST | `/api/conversations/{id}/read` | `{lastMessageId}` okundu imleci |
| POST/DELETE | `/api/conversations/{id}/members` | Grup üye ekle/çıkar |
| POST | `/api/users/{id}/block` · DELETE | Engelle / kaldır |
| POST | `/api/messages/{id}/report` | Raporla |

WebSocket (STOMP, `/ws`, CONNECT'te JWT): gönder `/app/chat.send` · al `/user/queue/messages`, `/user/queue/read-receipts`, `/user/queue/typing`. Limit: kullanıcı başına dakikada 30 mesaj, mesaj ≤2000 karakter.

## 6. Favoriler ve arama 🆕 (hızlı kazanım)
| Metod | Yol | Açıklama |
|---|---|---|
| PUT / DELETE | `/api/bookmarks/news/{id}` | Haber/duyuru kaydet |
| GET | `/api/bookmarks` | Kaydedilenler |
| GET | `/api/search?q=&type=` | Haber+duyuru+etkinlik+topluluk tek arama (PostgreSQL full-text, Türkçe) |
| GET | `/api/news?q=` | Mevcut liste ucuna metin filtresi |

## 7. Moderasyon ve yönetim 🆕 (Play Store UGC politikası için zorunlu)
| Metod | Yol | Açıklama |
|---|---|---|
| POST | `/api/reports` | `{targetType: USER\|MESSAGE\|POST\|COMMUNITY\|EVENT, targetId, reason, note}` |
| GET | `/api/admin/reports?status=OPEN` | ADMIN kuyruk |
| POST | `/api/admin/reports/{id}/resolve` | `{action: DISMISS\|HIDE\|WARN\|SUSPEND_USER}` |
| POST | `/api/admin/users/{id}/suspend` · `/unsuspend` | |
| GET | `/api/admin/stats` | Kullanıcı/mesaj/topluluk sayıları |

---

## Diğer fikirler (beğenirseniz modül olarak eklenir)
| Fikir | Kısa tanım | Başlıca uçlar | Efor |
|---|---|---|---|
| **Ders/bölüm grupları** | Bölüm+sınıfa göre otomatik grup sohbeti ve duyuru akışı | `GET /api/me/class-groups` | küçük (3+5 üzerine) |
| **Kampüs pazarı** | İkinci el ilan, ders notu, ev arkadaşı | `/api/listings` CRUD + `/api/listings/{id}/contact` (mesaj açar) | orta |
| **Kayıp eşya** | Kayıp/bulundu ilanları, foto + konum | `/api/lost-found` | küçük |
| **Anket / oylama** | Topluluk veya genel (ör. yemek memnuniyeti) | `/api/polls`, `POST /api/polls/{id}/vote` | küçük |
| **Yemek puanlama** | Günlük menüye 1–5 puan + kısa yorum | `PUT /api/menu/{date}/rating`, `GET /api/menu/{date}/ratings` | küçük |
| **Soru-Cevap** | "Hocam/bölüm hakkında soru" akışı, anonim seçeneği (moderasyonlu) | `/api/questions`, `/api/questions/{id}/answers` | orta |
| **Akademik takvim** | Sınav/kayıt tarihleri, hatırlatma | `GET /api/academic-calendar` (+ bildirim) | küçük–orta (kaynak bulunmalı) |
| **Ring/servis saatleri** | Statik/yarı statik hat bilgisi | `GET /api/shuttles` | küçük |
| **Çalışma arkadaşı eşleştirme** | Ders+saat bazlı eşleşme | `/api/study-sessions` | orta |

## Önerilen sıra
1. **Profil + Moderasyon temeli** (rol alanı, rapor, engelle) → 2. **Bildirimler (FCM)** → 3. **Favori + arama** → 4. **Topluluklar** → 5. **Etkinlikler** → 6. **Mesajlaşma** (en çok risk/emek; moderasyon hazır olunca).
Gerekçe: 1–3 içerik üretimi olmadan değer katar; 4–5 topluluk oluşturur; mesajlaşma en son, rapor/engel mekanizmaları hazırken açılır.

## Önce karar verilmesi gerekenler
- Topluluk ve etkinlik açma: herkes mi, yalnızca onaylı/rektörlük birimleri mi? (öneri: herkes oluşturur, ADMIN onaylar)
- Fotoğraf yükleme nerede saklanacak? (öneri: S3 uyumlu depolama / MinIO; yerel disk ölçeklenmez)
- Anonim paylaşım olacak mı? (olacaksa moderasyon yükü artar)
- Mesaj saklama süresi (KVKK): öneri 1 yıl, hesap silinince anonimleştir.
- Veritabanı şeması artık `ddl-auto=update` ile yönetilmemeli → bu modüllerden önce **Flyway** eklenir.

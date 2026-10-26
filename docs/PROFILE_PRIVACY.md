# Profil gizliliği ve avatar görünürlüğü (T11)

## API
- `GET /api/users/me/privacy`, `PATCH /api/users/me/privacy` (kısmi): `avatar`, `bio`, `department`, `faculty`, `classYear` alanlarının her biri `EVERYONE | SHARED_CONTEXT | ONLY_ME`. Yanıtta ayrıca `avatarHiddenByModeration`. Varsayılan hepsi `EVERYONE` (satır yoksa da).
- `GET /api/users/me/completeness` → `{percent, filled[], missing[{field, weight, suggestion}]}`; öneri metni istek dilinde. Ağırlıklar: avatar 20, bio 20, fakülte 15, bölüm 15, sınıf 15, ad 15.
- `GET /api/users/{id}` ve `GET /api/users/search` alan bazlı gizliliği `PublicProfileMapper` ile uygular. Silinmiş/askıdaki/engel ilişkili hesap: 404 `USER_NOT_FOUND` (alan sızıntısı yok).
- Görünen ad: `DisplayNamePolicy` (kontrol/bidi/sıfır genişlik/görünmez harf reddi, boşluk sadeleştirme, 2-80 kod noktası, en çok 2 emoji, kelime içi Latin+Kiril/Yunan karışımı reddi, yönetici/destek taklidi "iskelet" denetimi; ADMIN rolü muaf). Kodlar: `INVALID_DISPLAY_NAME`, `RESERVED_DISPLAY_NAME`.

## "Ortak bağlam" (SHARED_CONTEXT)
Bakan ile sahibin ortak ACTIVE kulüp üyeliği, ayrılmamış ortak sohbeti veya aynı etkinliğe RSVP'si. Tek SQL: `SharedContextRepository.sharedWith`. Kendi profilini her zaman görürsün.
Kural matrisi (`AvatarVisibility.allowed`): sahip her zaman görür; `EVERYONE` herkes; `SHARED_CONTEXT` yalnız ortak bağ; `ONLY_ME` kimse. Ek olarak moderasyon bayrağı `avatar_hidden` (USER_AVATAR "gizle") sahibi dışında herkesten avatarı saklar.

## Diğer modüllere entegrasyon rehberi
Sohbet listesi/üyeler/akış, topluluk üyeleri/gönderileri, etkinlik katılımcıları DTO'larında `avatarUrl` döner; bu modüller henüz **filtrelenmemiştir** (kapsam gereği dokunulmadı). Bağlama, DTO'yu kurmadan hemen önce toplu çağrıdır (N+1 yok: bir ayar sorgusu + en çok bir ortak bağ sorgusu):

```java
Map<Long, String> urls = avatarVisibility.filterAvatars(viewerId, ownerIdToAvatarUrl); // gizli olanın değeri null
// veya tek kayıt: avatarVisibility.avatarFor(viewerId, ownerId, user.getAvatarUrl())
```
Yapılacaklar: `ConversationService` (liste + üye listesi + mesaj gönderen), `CommunityService`/`CommunityPostService` (üye, yazar), `EventService` (organizatör, katılımcı), `BlockController` (engellenenler), WS ile giden akış olayları. Bilgi alanları için `AvatarVisibility.visibleOwners(viewer, owners, Field.BIO ...)`. Admin uçları (`AdminUserRepository`) filtrelenmez: yönetici moderasyon için gerçek avatarı görmelidir.
WebSocket ile önceden yayınlanmış avatar URL'leri istemcide önbellekte kalabilir; ayar değişince yeni istekte düzelir.

## Hesap silme (KVKK) ve temizleme kancası
`ProfileService.anonymize` → `AvatarCleanups.run(userId, avatarUrl)`: kayıtlı tüm `AvatarCleanup` bean'lerini çağırır (hata yutulur) ve `profile_privacy` satırını siler. T1 dosya silme API'sini bir `AvatarCleanup` @Component olarak ekler; şimdilik `storage.delete` doğrudan çağrılmaya devam eder (ikisi birleşince tekilleştirin). Kapak görseli yapılmadı (isteğe bağlı).

## Moderasyon
`ReportTargetType.USER_AVATAR` (targetId = avatar sahibinin kullanıcı id'si), `AvatarReportHandler`: yalnız aktif ve avatarı olan hesap raporlanabilir; HIDE → `avatar_hidden=true` (dosya kanıt olarak kalır). Avatarı yeniden göstermek / yeni avatar yüklenince bayrağı sıfırlamak için `PrivacyService.setAvatarHidden(id, false)` T12/T1 tarafından bağlanmalıdır. `moderation` paketinde yalnızca enum'a `USER_AVATAR` eklendi.

## DataExporter
`profilePrivacy` bölümü (`PrivacyView`).

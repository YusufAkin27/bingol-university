# Medya hattı (görsel işleme) — T1

Tüm görsel yüklemeleri tek, güvenli hattan geçer. Paket: `edu.bingol.backend.media`. Dosyalar **sunucunun yerel diskinde** tutulur (`app.storage.dir`, Docker'da `uploads` volume'u); bulut/S3 yoktur.

## Ne yapar
1. **Bildirilen alanlar**: Content-Type `image/jpeg|png|webp|application/octet-stream`, uzantı `jpg|jpeg|png|webp` dışındaysa 400 `INVALID_FILE` (SVG, GIF, HTML, `.gif` adlı gerçek PNG...).
2. **Sihirli bayt**: yalnız JPEG/PNG/WebP imzası kabul edilir (polyglot, GIF/HEIC/SVG reddedilir). Asıl karar bayttadır.
3. **Boyut bombası koruması**: görüntü çözülmeden önce başlıktan genişlik/yükseklik okunur; `w*h > app.media.max-pixels` (25 MP) → 400 `IMAGE_TOO_MANY_PIXELS`. Çok büyük görseller kaynak örneklemeyle (subsampling) çözülür; eşzamanlı işleme `app.media.concurrency` (4) ile sınırlıdır (dolarsa 503 `MEDIA_BUSY`).
4. **Yeniden kodlama**: piksel verisi çözülür, EXIF yönü uygulanır (EXIF atılacağı için), uzun kenara küçültülür, **JPEG** (opak) veya **PNG** (gerçek saydamlık varsa) olarak yeniden yazılır → EXIF/GPS/ICC/yorum/eklenmiş artık veri çıktıya geçmez. Bozuk/desteklenmeyen dosya → 400 `IMAGE_CORRUPT`.
5. **Sıkıştırma hedefi** (`max-stored-bytes`): kalite `jpeg-quality`'den 10'ar düşürülür (alt sınır 40); sığmazsa boyut %15 küçültülüp tekrar denenir; yine sığmazsa **422 `IMAGE_TOO_COMPLEX`**.
6. **Küçük resim** (`thumb-dimension`, 320 px).
7. **Adlandırma** (herkese açık): içerik özeti `sha256(çıktı)[0..40]` → `/files/<klasör>/<özet>.jpg|png`, küçük resim `<özet>-t.jpg|png`. Aynı içerik tekrar yazılmaz (yalnız `mtime` yenilenir). Yazım atomiktir (geçici dosya + taşıma).
8. **Yetim temizliği**: `MediaOrphanSweeper` her gece 03:30 (`app.media.sweep-cron`), `orphan-min-age-hours`'tan (24) eski ve hiçbir `MediaReferenceSource`'un kullanılıyor demediği dosyaları (+küçük resimleri, eski `.tmp-*`) siler.

WebP: `com.twelvemonkeys.imageio:imageio-webp:3.12.0` ile **yalnız okuma** (kayıpsız ve kayıplı 1x1 örnekleri birim testinde çözülür); çıktı hiçbir zaman WebP değildir. Tam-yığın (fat jar) içinde çalıştığı test aşamasında `scripts/media-attacks.sh` ile doğrulanır.

## Ayarlar (`application.properties`, ortam değişkeniyle ezilir)
Her tür (`avatar`, `cover`, `post`, `chat`) için ayrı:

| Anahtar | Anlam | Varsayılan (avatar / cover / post / chat) |
|---|---|---|
| `app.media.<tür>.max-upload-bytes` | ham yükleme üst sınırı → 413 `FILE_TOO_LARGE` | 2 MB / 3 MB / 3 MB / 5 MB |
| `app.media.<tür>.max-dimension` | uzun kenar px | 512 / 1600 / 1600 / 1600 |
| `app.media.<tür>.max-stored-bytes` | sıkıştırma SONRASI üst sınır | 150 KB / 400 KB / 400 KB / 500 KB |
| `app.media.<tür>.jpeg-quality` | başlangıç kalitesi (1-100) | 85 |

Genel: `app.media.thumb-dimension` (320), `max-pixels` (25000000), `concurrency` (4), `grace-seconds` (10), `orphan-min-age-hours` (24), `private-dir` (boşsa `<storage.dir>/_private`), `signing-secret` (boşsa JWT sırrından türetilir), `extra-reference-columns`, `sweep-folders`, `sweep-enabled`. Ortam değişkenleri: `MEDIA_AVATAR_MAX_STORED_BYTES`, `MEDIA_COVER_MAX_DIMENSION`, `MEDIA_CHAT_JPEG_QUALITY`... (bkz. `application.properties`).
**Tutarlılık**: `spring.servlet.multipart.max-file-size` (`MULTIPART_MAX_FILE`, 5MB) en büyük `max-upload-bytes`'tan küçük olmamalı; uygulama düzeyi sınır çevrilmiş `FILE_TOO_LARGE` döner (multipart sınırı aşılırsa da aynı kod, "5" MB argümanıyla).

## Genel API

```java
// 1) Herkese açık görsel (avatar, kapak, gönderi)
StoredImage img = mediaService.storeImage(multipartFile, ImageKind.COVER);
entity.setCoverUrl(img.url());        // /files/covers/<özet>.jpg
// img: url, thumbUrl, width, height, bytes, contentType
// değiştirme/silmede (DB değişikliğini FLUSH ettikten sonra):
mediaService.release(eskiUrl);        // başka kayıt kullanmıyorsa ve taze değilse siler; exception atmaz
String thumb = MediaService.thumbUrlOf(url);

// 2) Özel görsel (sohbet): URL yok, /files/** dışında
PrivateMedia m = privateMediaStore.store("chat", multipartFile, ImageKind.CHAT);
// m.key(), m.thumbKey(), width, height, bytes, contentType -> mesaj satırına yaz
// Okuma: ÖNCE kendi yetki kontrolünü yap (katılımcı mı? ayrılmış mı? engel?), sonra
return privateMediaStore.serve("chat", m.key());            // no-store + nosniff + CSP
// ya da <img> için kısa ömürlü imzalı URL (en çok 1 saat):
String url = mediaUrlSigner.sign("chat", m.thumbKey(), Duration.ofMinutes(5)); // /files/p/chat/<anahtar>?exp=..&sig=..
// silme: privateMediaStore.delete("chat", m.key());
// yetim temizliği (kova sahibi modül zamanlar):
privateMediaStore.sweep("chat", key -> messageRepo.existsByMediaKey(key), Duration.ofDays(1));
```

* `ImageKind`: `AVATAR`, `COVER`, `POST` (herkese açık klasörlü), `CHAT` (yalnız özel depo; `storeImage` ile kullanılırsa `IllegalArgumentException`). Yeni tür = enum değeri + `MediaProperties` alanı.
* Hatalar `ApiException` (3 dilde çevrili): 400 `INVALID_FILE`/`IMAGE_CORRUPT`/`IMAGE_TOO_MANY_PIXELS`, 413 `FILE_TOO_LARGE`, 422 `IMAGE_TOO_COMPLEX`, 503 `MEDIA_BUSY`/`STORAGE_UNAVAILABLE`. Yazma uçlarında `RateLimiter` kullanmak çağıranın görevidir.
* **Yeni bir tabloda herkese açık görsel URL'si saklıyorsanız** onu yetim temizliğine bildirin, yoksa 24 saat sonra dosyanız silinir: ya `app.media.extra-reference-columns=tablo.sutun` ekleyin ya da `MediaReferenceSource` bean'i yazın. Varsayılan sütunlar: `app_user.avatar_url`, `community.cover_url`, `community_post.image_url`, `user_event.cover_url`.
* Eski `FileStorage.save(...)` yolu da (kapak/gönderi) artık aynı hattan geçer (UUID adlı, küçük resimsiz); yeni kod `MediaService` kullanmalı.

### Özel depo ve imzalı URL
Dosyalar `<storage.dir>/_private/<kova>/<uuid>.jpg|png` (+ `-t`); `FileController` deseni (`[a-z]+`) bu dizine ulaşamaz. Adlar rastgele UUID'dir (özet-varlık sorgusu yok). Kova `[a-z]{1,20}`, anahtar sıkı desenle doğrulanır (yol gezintisi imkânsız). `GET /files/p/{kova}/{anahtar}?exp&sig` geçersiz imza/süre/yoksa **aynı 404** döner.

### `BlobCipher` (diskte şifreleme için hazır nokta)
`PrivateMediaStore` diske yazarken `BlobCipher.encrypt(bayt, "kova/anahtar")`, okurken `decrypt` çağırır. Varsayılan `NoopBlobCipher` şifrelemez. Şifreleme için uygulamada bir `BlobCipher` bean'i tanımlamak yeterlidir (`ObjectProvider` ile enjekte edilir, varsa varsayılanın yerini alır); `context` AEAD ek verisi olarak kullanılabilir. Birim testi `XorCipher` ile disk baytlarının farklı, okumanın özdeş olduğunu doğrular.

## Profil avatarı
`POST /api/users/me/avatar` (alan `file`, sözleşme aynı; yanıt `ProfileView`), yeni `DELETE /api/users/me/avatar` (idempotent, `avatarUrl: null`). Eski dosya `release` ile (referans yoksa ve ≥10 sn eskiyse) silinir; hesap silmede de aynı. `avatarUrl` null iken istemci baş harf avatarı gösterir. Küçük resim URL'si: `thumbUrlOf` kuralı (`.jpg` → `-t.jpg`).

## Testler
* Birim: `ImageProcessorTest` (EXIF/GPS temizliği + yön, polyglot/artık veri, SVG/GIF/HEIC/HTML, bozuk dosya, boyut bombası, WebP, `max-stored-bytes`/`jpeg-quality`/`max-dimension` değişince davranış, 32 eşzamanlı işlem), `MediaStorageTest` (özetle adlandırma, yükleme sınırı, release/sweep, eşzamanlı aynı yükleme, özel depo, `BlobCipher`, imzalı URL).
* Yığın üzerinde: `scripts/media-attacks.sh` (+ `scripts/media-fixtures.js`, `scripts/fixtures/media/*`).

## Sohbet gorselleri (T8) — `messaging/media/**`, `V95`
* **Yukleme:** `POST /api/conversations/{id}/media` (multipart `file`, yalniz uye; dakikada 10 / gunde 200; gonderilmemis en fazla 20) -> `{id, width, height, bytes, contentType, url, thumbUrl}`. T1 hatti `ImageKind.CHAT` (sikistirma, EXIF temizligi, `app.media.chat.*`); islenmis cikti ve ham bayt ozeti `ContentBlocklist` ile denetlenir (422 `MEDIA_BLOCKED`). Baytlar ozel depoda (`_private/chat`), `MediaBlobCipherAdapter` ile diskte sifreli.
* **Gonderim:** `POST /api/conversations/{id}/messages` (veya STOMP `chat.send`) govdesine `attachmentIds` (en fazla 4; yukleyen = gonderen, bir ek yalniz bir kez; `text` bos olabilir). Baglama mesajla ayni transaction'da atomik `UPDATE ... WHERE message_id IS NULL`. Mesaj gorunumu `attachments[]` tasir; WS olayi normal (sifreli `ChatEventBus`) yoldan ek meta verisiyle gider.
* **Okuma:** `GET .../media/{aid}` ve `.../thumb` (Bearer; `Cache-Control: private, no-store`), `GET .../media/{aid}/link` -> `/files/p/chat/...` kisa omurlu (varsayilan 300 sn) imzali adresler. Yetki: aktif uye + (grupta katilim sonrasi mesaj) + mesaj/ek gizli degil + yukleyen engelli/askida/silinmis degil; aksi hep 404. Gonderilmemis yukleme yalniz sahibine gorunur.
* **Moderasyon:** `MESSAGE_IMAGE` handler (geri alinabilir). `POST .../media/{aid}/report`. Gizleme: erisim kapanir, bayt YENI anahtara kopyalanip eskisi silinir (eski imzali adresler hemen olur); `unhide` yalniz bayrak kaldirir. Yonetici onizlemesi `GET /api/admin/media/attachments/{id}/preview[?thumb=true]` (ADMIN; GET olsa da denetim kaydi).
* **Silme/temizlik:** `DELETE .../media/{aid}` (yalniz gonderilmemis kendi yuklemesi). Saatlik temizleyici baglanmamis >24 saat yuklemeleri ve satiri olmayan eski dosyalari siler. T13 mesaj silmede `MessageAttachmentService.purgeForMessage(messageId)` cagirmalidir. Hesap silmede (AvatarCleanup kancasi) kullanicinin tum ekleri kaldirilir. KVKK: `sentChatImages` (sayi/boyut/meta, icerik haric).
* Ayarlar: `app.chat.media.*` (uploads-per-minute, uploads-per-day, max-per-message, pending-max, unclaimed-hours, link-ttl-seconds, cleanup-cron). Betik: `scripts/chat-images-e2e.sh`.

## Sohbet videosu (V230) — `messaging/media/**`, `media/Mp4Info`, `media/PrivateMediaStore`
* **Yukleme:** `POST /api/conversations/{id}/media` `file=video/mp4` (+ istege bagli `poster`). Dogrulama: Content-Type `video/mp4`, ilk kutu `ftyp`, boyut `app.chat.media.video-max-bytes` (40 MB; `VIDEO_TOO_LARGE` 413), sure `video-max-seconds` (60; `VIDEO_TOO_LONG`), `Mp4Info` ile `moov/mvhd` (timescale/duration) ve ilk gorsel izin `tkhd` boyutlari ayristirilir; bozuk/atom yoksa `VIDEO_INVALID`. Kodek dogrulanmaz, **sunucu yeniden kodlamaz** (ffmpeg yok); sıkıştırma istemcidedir. Yukleme sirasinda tum dosya bellekte (en cok 40 MB) tutulur; sunum ise akislidir.
* **Depo:** `_private/chat/<uuid>.mp4` + (varsa) `<uuid>-t.jpg|png` poster. Video baytlari konusma DEK'li parcali AES-GCM (`crypto.BlobCipher`, 64 KB parca) ile diske yazilir; sifreleyici yoksa duz. Poster `ImageKind.CHAT` hattindan (yeniden kodlama, EXIF temizligi) `dimCap=720` px ile gecer ve `thumbUrl` olarak sunulur. Yasakli ozet denetimi ham video, ham poster ve islenmis poster icin yapilir (422 `MEDIA_BLOCKED`).
* **Sunum:** `GET .../media/{aid}` `Range` basligini isler (tek aralik; `206` + `Content-Range`, `416`, `Accept-Ranges: bytes`). Dosya belleğe okunmaz: duz dosyada dogrudan konumlanir, sifreliyse parca parca cozulur (basa kadar atlanir, aralik bitince durulur). Yetki gorselle ayni (`accessible`); imzali `/files/p/` adresi videoda verilmez.
* **Yasam dongusu:** `PrivateMediaStore.delete` videoyla birlikte posterini siler; moderasyon gizlemesi `copyVideo` ile yeni anahtarlara tasir; yetim temizleyici `.mp4` anahtarlarini `existsByStorageKey` ile tarar.
* Ayarlar: `app.chat.media.video-max-bytes`, `video-max-seconds`, `video-daily-limit`; `spring.servlet.multipart.max-file-size` 45 MB.

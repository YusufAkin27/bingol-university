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

## Gonderi medyasi (V310) — `post/media/**`
* **Yukleme:** `POST /api/posts/media` (multipart `file`; video icin istege bagli `poster`) -> 201 `{id, kind, url, thumbUrl, width, height, durationMs, bytes}`. Gorsel: yeni `ImageKind.FEED` (herkese acik klasoru yok; ham 8 MB, uzun kenar 1600 px, onizleme 480 px, yeniden kodlama + EXIF temizligi). Video: `video/mp4` + `ftyp`, <=60 sn (`VIDEO_TOO_LONG`), <=40 MB (`VIDEO_TOO_LARGE` 413), `Mp4Info` ile ayristirma (`VIDEO_INVALID`); poster `FEED` hattindan 720 px ile gecer. Yasakli ozet: ham + islenmis gorsel/poster/video (422 `MEDIA_BLOCKED`).
* **Depo:** `_private/post/<uuid>.jpg|png|mp4` (+ `-t` onizleme/poster), `/files/**` disinda. Gorseller `BlobCipher` varsa diskte AES-GCM sifreli. **Videolar duz yazilir**: video sifrelemesi konusma DEK'ine (`conversation_key.conversation_id` -> `conversation` FK) baglidir, gonderide konusma yoktur; icerik zaten herkese acik gonderidir. Bu nedenle `PrivateMediaStore.storeVideoPlain` eklendi (poster yine sifreli); okuma `streamVideo` ile ayni, bellek dostu.
* **Kota:** saatte 30 yukleme (`app.post.media.uploads-per-hour`, `RateLimitedException` 429); baglanmamis medya en cok 30/kullanici (`pending-max`, 429 `POST_MEDIA_PENDING_LIMIT`).
* **Sunum:** `GET /api/posts/media/{id}[?thumb=true]` (JWT): `Cache-Control: private, max-age=86400`, `ETag` (depo anahtari; `If-None-Match` -> 304), video icin `Range` (206/416, `Accept-Ranges`). Yetki tek yerde (`PostMediaService.accessible`): baglanmamis -> yalniz sahibi; baglanmissa gonderi silinmemis + gizlenmemis + medya gizli degil + yazarla engel yok; aksi 404 `POST_MEDIA_NOT_FOUND`. Yonetici: `GET /api/admin/posts/media/{id}` (silinmis/gizli de; GET olsa da denetim kaydi).
* **Baglama:** `PostMediaBinder.attach(postId, ownerId, mediaIds)` (<=10 medya, <=10 video, sahip, baglanmamis, tekrar yok; atomik `UPDATE ... WHERE post_id IS NULL`; ihlal 400 `POST_MEDIA_INVALID`). Sira = istemci sirasi (`position`).
* **Gizleme / silme / KVKK:** `hide(postId)` / `unhide(postId)` yalniz `hidden_at` bayragi (anahtar degismez). Gonderi silinince (`PostDeletedEvent`) medya `app.post.media.deleted-retention-days` (30) gun sonra gece 04:40 isi ile diskten ve DB'den kalkar (0 = olayda hemen). Baglanmamis yuklemeler 24 saat sonra saatlik isle silinir (satiri olmayan eski dosyalar da). `purgeUser(userId)`: hesap silmede tum medya.
* Ayarlar: `app.post.media.{video-max-bytes, video-max-seconds, uploads-per-hour, pending-max, max-per-post, max-videos-per-post, unattached-hours, deleted-retention-days, cleanup-cron, deleted-cleanup-cron}`.

## Gönderi videosu: sunucuda ffmpeg ile yeniden kodlama + dosya-başına şifreleme + CDN (V360) — `media/transcode/**`, `media/PostVideoCipher`

> Bu bölüm yukarıdaki "Gönderi medyası (V310)" notunu **günceller**: gönderi videoları artık düz yazılmaz (ana anahtar varsa). Sohbet videosu davranışı değişmedi (hâlâ istemci sıkıştırır, sunucu yeniden kodlamaz, konuşma DEK'iyle şifreli).

### Akış
1. `POST /api/posts/media` (sözleşme **aynı**): doğrulama (`video/mp4`, `ftyp`, süre, boyut) eskisi gibi; baytlar `PrivateMediaStore.storeVideoSealed` ile **dosya-başına rastgele DEK** (AES-256-GCM, parçalı) ile yazılır, DEK ana anahtarla (`CRYPTO_MASTER_KEYS`, etkin `CRYPTO_ACTIVE_KEY_ID`) sarılıp `post_media.wrapped_dek`'e yazılır, `encrypted=true`.
2. ffmpeg+ffprobe çalışıyorsa satır `transcode_status=PENDING` olur; **yanıt hemen döner**, orijinal (şifreli) video oynatılabilir kalır.
3. `TranscodeWorker` (her `app.media.transcode.poll-ms`=5 sn; çok örnekte `SchedulerLock` ile tek örnek): `PENDING` → atomik `UPDATE` ile `PROCESSING` (aynı iş iki kez alınmaz, `SKIP LOCKED` karşılığı) → en çok `workers` (2) paralel. Bir iş: şifreyi çöz → geçici dosya (`/tmp`) → `ffprobe` (video akışı var mı, süre <= `max-duration-seconds`) → `ffmpeg` → çıktı `ffprobe` → yeni DEK ile yeniden şifrele (**yeni anahtar adı** → ETag/önbellek tazelenir) → poster yoksa ilk anlamlı kareden üret → tek atomik `UPDATE` (`DONE`) → eski dosya + eski poster silinir → geçici dizin silinir.
4. **Hata** (zaman aşımı, ffmpeg hatası, geçersiz video): `transcode_attempts++`; `max-attempts` (3) dolana kadar `PENDING`, sonra `FAILED`. **Orijinal video her zaman sunulur** (kullanıcı etkilenmez); yeni dosyalar silinir. Çöken işleyicinin bıraktığı `PROCESSING` işleri `stale-minutes` (30) sonra kuyruğa döner.
5. ffmpeg yok/kapalı (`MEDIA_TRANSCODE_ENABLED=false` ya da imajda yoksa): satır `transcode_status=NULL` kalır, kuyruğa alınmaz → **mevcut davranış** (orijinal saklanır).

`transcode_status`: `NULL` (dönüştürme yok) · `PENDING` · `PROCESSING` · `DONE` · `FAILED`. İstemci sözleşmesi **değişmedi** (yanıtlarda alan yok); ileride `status` alanı eklenirse geriye uyumlu eklenir. `message_attachment.transcode_status` kolonu sohbet için hazırdır (V360), sohbet videosu dönüştürmesi bu sürümde **etkin değildir**.

### ffmpeg komutu (kabuk yok, argüman listesi)
`ffmpeg -hide_banner -nostdin -loglevel error -y -protocol_whitelist file -i IN -t <max sn> -map 0:v:0 -map 0:a:0? -sn -dn -map_metadata -1 -vf scale=-2:'min(720,ih)' -c:v libx264 -profile:v main -pix_fmt yuv420p -preset veryfast -b:v 1500k -maxrate 1800k -bufsize 3000k -threads 1 -c:a aac -b:a 96k -ac 2 -movflags +faststart -f mp4 OUT`. Yükseltme yok (`min`), genişlik çift, meta veri (GPS vb.) atılır, yalnız `file` protokolü. Yollar uygulamanın ürettiği geçici dosyalardır. Zaman aşımı `timeout-seconds` (300): süreç ve alt süreçleri öldürülür. Poster: `thumbnail=60,scale=...` ile tek JPEG → mevcut `ImageKind.FEED` hattı (yeniden kodlama, EXIF temizliği).

### Şifreli biçim (`BUP1`)
`"BUP1" | parçaBoyu(4) | { AES-GCM(parça 64 KB) + etiket(16) }*`. Parçalar sabit boyutlu → **Range okuması doğrudan konumlanır** (yalnız ilgili parçalar çözülür, 206/416 sözleşmesi aynı). AAD: dosya yolu + başlık + "son parça" bayrağı (sıra/kesme/başka dosyaya taşıma yakalanır). Sarma AAD'si de yolu içerir. Eski kayıtlar (`encrypted=false`) düz okunur (geriye uyum). Ana anahtar yoksa (yalnız geliştirme) düz yazım sürer.

### Eski düz videoların sifrelenmesi
`MEDIA_ENCRYPT_EXISTING=true` (prod compose varsayılanı): işleyici her turda `legacy-batch` (5) düz videoyu şifreler (yeniden kodlamadan; yeni anahtar adı, poster taşınır, eski dosya silinir). İlerleme: `bash scripts/ops/encrypt-existing-post-videos.sh --status`; tek komutla: `--run`. Yeniden sarma (anahtar sızıntısı): `--reseal-key k1` (`MEDIA_RESEAL_KEY_ID`). Önce yedek alın.

### CDN
`MEDIA_CDN_BASE_URL` boş = kapalı. `MEDIA_CDN_REDIRECT=true` iken yetkili isteğe `302` + imzalı `.../files/cdn/post/{id}?t=0|1&exp&sig`; origin ucu (`PostMediaCdnController`) imzayı doğrular, gizli/silinmiş/bağlanmamış medyada 404, `Cache-Control: public, max-age<=imza ömrü`. Kurulum ve uyarılar: [DEPLOY.md](DEPLOY.md) bölüm 10.

### Ayarlar
`app.media.transcode.{enabled, ffmpeg-path, ffprobe-path, workers, threads-per-job, timeout-seconds, max-height, video-kbps, audio-kbps, max-duration-seconds, max-attempts, poll-ms, stale-minutes, temp-dir, poster-enabled, encrypt-existing, legacy-batch, reseal-key-id}` (ortam: `MEDIA_TRANSCODE_*`, `MEDIA_ENCRYPT_EXISTING`, `MEDIA_RESEAL_KEY_ID`), `app.media.cdn.{base-url, redirect, ttl-seconds}` (`MEDIA_CDN_*`).

### Testler
`PostVideoCipherTest` (sınır boyutları, Range, kurcalama/kesme/yanlış bağlam, sarma, rotasyon), `VideoTranscoderTest` (komut oluşturma, ffprobe ayrıştırma, ffmpeg yok, zaman aşımı + gerçek süreç öldürme), `TranscodeServiceTest` (durum geçişleri, orijinalin korunması, poster, yetim dosya yok, worker eşzamanlılık/yarış, eski video şifreleme, yeniden sarma), `PostMediaSealedVideoTest` (yükleme/Range/geriye uyum, CDN imza + origin ucu + yönlendirme), `PostMediaTranscodeRepositoryTest` (H2 JPQL), `TranscodeMigrationTest` (V360 dosyası). Gerçek ffmpeg ile uçtan uca: `scripts/media-transcode-e2e.sh` (Docker, kısa örnek videoyu dönüştürür ve codec/boyutu doğrular).

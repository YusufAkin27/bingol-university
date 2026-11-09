# Aktarımlar: arka plan yükleme/indirme ve canlı ilerleme (G10)

Kapsam: sohbet medyası (foto/video/dosya), gönderi ve forum medyası yüklemesi. Dal: `feat/g10-transfers-20261109`.

## Durum özeti (dürüst)

| Parça | Durum |
|---|---|
| Dart kalıcı kuyruk (`mobile/lib/core/transfers/`) | Yazıldı, birim testli (sahte aktarıcı) |
| Sunucu: sohbet medya yüklemede `Idempotency-Key` | Yazıldı, birim testli |
| Android ön plan servisi + tek ilerleme bildirimi | Yazıldı, `assembleDebug` ile derlendi; **cihazda çalıştırılmadı** |
| Aktarımlar arayüzü (`TransfersList`) | Yazıldı, widget testli; hiçbir ekrana bağlanmadı (G2/G4 yerleştirir) |
| iOS (background URLSession, Canlı Etkinlik/ActivityKit) | **YAPILMADI.** Bu sürümde iOS yalnız uygulama içi takip + kuyruk kurtarma ile çalışır; Swift derlenemediği için dokunulmadı |
| Gönderi (G2) / sohbet (G4) çalıştırıcıları | Bu işin kapsamı dışı; sohbet için hazır `ChatMediaTransferExecutor` var |

"Arka planda aktarım çalıştı" doğrulanmadı: emülatör/cihaz yok.

## Mimari

```
Özellik (G2/G4) --enqueue--> TransferQueue --run--> TransferExecutor (özelliğe ait: HTTP + tamamlama)
                                 |  (tek özet)
                                 +--> TransferSummary --> TransfersList (uygulama içi)
                                                      --> TransferPlatform --> Android TransferService (tek bildirim)
```

* İlerleme TEK yerde (`TransferJob.doneBytes/totalBytes`) tutulur; sohbet balonu, Aktarımlar alanı ve bildirim aynı
  `TransferSummary`'yi okur, ayrı yüzde üretmez.
* Yüzde yalnız toplam bayt biliniyorsa ve iş `active` iken vardır; toplam bilinmiyorsa ya da sunucu işlerken `fraction == null`
  (belirsiz ilerleme çizilir).
* Durumlar ayrı: `preparing / queued / active / waitingNetwork / processing / published / failed / canceled`.
  `published` yalnız çalıştırıcı sunucu sonucunu döndürünce olur; "Gönderildi/Paylaşıldı" metni bundan önce gösterilmez.
* Yükleniyor = sunucuya (`TransferDirection.upload`), indiriliyor = cihaza (`download`).
* Kalıcılık: `<uygulama destek dizini>/transfers/jobs.json` (atomik yazım) + `transfers/files/<jobId>/` kopyası.
  Kaynak dosya kuyruğa alınırken uygulama dizinine KOPYALANIR (seçicinin geçici dosyası kaybolsa da iş sürer);
  iş bitince/iptalde/çıkışta kopya silinir, kullanıcının özgün dosyasına dokunulmaz.
* Yeniden deneme: 2, 4, 8 ... en çok 300 sn (±%20), en çok 6 deneme; ağ hatası `waitingNetwork`; bağlantı geri gelince
  (`ConnectivityService.reconnects`) beklemeler atlanır. Kullanıcı iptal ettiyse hiçbir zaman otomatik başlamaz.
* Eşzamanlılık: varsayılan 2 iş. Sunucu kullanıcı başına tek eşzamanlı yüklemeye izin verir; fazlası 429 `UPLOAD_BUSY` döner,
  bu geçici hata sayılır ve geri çekilmeyle tekrar denenir.
* Kurtarma (`start`): yürütülürken süreç ölen iş sırada başa döner (yükleme baştan başlar, aralıklı devam YOK);
  aynı `Idempotency-Key` ile gittiği için sunucuya ulaşmışsa ikinci kayıt oluşmaz. `published/failed/canceled` yeniden gönderilmez;
  24 saatten eski sonlanmış kayıtlar silinir.
* Hesap (G8): iş `ownerUserId` taşır. Çıkış/hesap değişimi/silme (`AppLifecycleHooks.onSignedOut`) -> `signOut()`: sahibin işleri
  durdurulur, gönderilmemiş sunucu eki silinir (`discard`), yerel dosyalar silinir. Giriş yapan hesaba ait olmayan kayıtlar da silinir.
  `docs/changes/account-context.md` bu dalda yoktu; birleştirirken G8 sözleşmesiyle çelişki kontrol edilmeli.
* Yarım/iptal temizliği: iptalde sunucuda yüklenmiş ama mesaja bağlanmamış ek `DELETE /conversations/{cid}/media/{aid}` ile silinir
  (mesaja bağlıysa sunucu 409 verir, yutulur). Yayımlanmış içeriğin dosyası hiçbir yolda silinmez.
* Yeniden dene: kalıcı reddedilen (4xx) ya da iptal sonrası işte YENİ `Idempotency-Key`; geçici hatada aynı anahtar korunur.
  İptal edilen iş yeniden denenemez (yerel kopya silindi): çağıran dosyayı yeniden `enqueue` eder.

## G2 / G4 için Dart API'si

```dart
final q = TransferHub.instance.queue!;               // oturum açıkken dolu (TransferHub.attach main.dart'ta yapıldı)

// Çalıştırıcı kaydı (oturumdan önce de çağrılabilir; main/feature başlatmada bir kez):
TransferHub.instance.addExecutor(TransferKind.chatMedia,
    (session) => ChatMediaTransferExecutor(session, (job, attachmentId) async {
      // G4: mesajı gönder (attachmentIds + clientId = job.meta['clientId']); SUNUCUDAN dönen mesaj id'sini döndür.
      final res = await session.api.post('/conversations/${job.meta['conversationId']}/messages',
          {'attachmentIds': [attachmentId], 'clientId': job.meta['clientId'], 'text': job.meta['text']});
      return '${res['id']}';
    }));

// Sıraya al (hemen döner; iş ekran kapansa da sürer):
final job = await q.enqueue(TransferRequest(
  ownerUserId: session.userId!, kind: TransferKind.chatMedia, targetKey: 'conv:$cid',
  sourcePath: file.path, mime: 'video/mp4',
  meta: {'conversationId': cid, 'clientId': clientId, 'durationMs': ms, 'posterPath': posterPath},
  jobId: clientId,                                   // aynı kimlik -> ikinci enqueue mevcut işi döner
));

q.watch(targetKey: 'conv:$cid');   // Stream<List<TransferJob>> (bayt ilerlemesi ~120 ms'de bir)
q.watchJob(job.id);                // Stream<TransferJob?>
q.watchSummary();                  // Stream<TransferSummary>: rozet/bildirim/aktarım merkezi
q.cancel(id); q.retry(id); q.dismiss(id);
```

Kendi türünüz için `TransferExecutor` yazın: `run(job, ctx)` yükler, `ctx.progress(done, total)`, dosya sunucuya ulaşınca
`ctx.markProcessing()`, yükleme kimliğini `ctx.setServerRef(...)` ile kalıcılaştırır; sunucunun yayımladığını doğruladıktan sonra
yayımlanan içeriğin kimliğini DÖNDÜRÜR. Hata: `TransferFailure` (`retryable`, `network`) ya da `ApiError` (otomatik sınıflanır:
0/408 ağ, 429/5xx geçici, diğer 4xx kalıcı). `ctx.canceled` true ise bırakıp `TransferFailure('CANCELED', retryable: false)` fırlatın.
Çalıştırıcı sunucuya giden her istekte `job.idempotencyKey`'i `Idempotency-Key` olarak kullanmalıdır (`MultipartUploader.upload`/
`VideoUploader.upload` artık `headers:` alır). Gönderi (`POST /posts`) ve forum zaten `Idempotency-Key` destekler.

Arayüz: `TransfersList(queue: q, targetKey: ...)` (`transfers_view.dart`); metinler `TransferTexts` ile verilir (varsayılan Türkçe;
G2/G4 l10n anahtarlarına bağlar).

## Sunucu

`POST /api/conversations/{cid}/media` `Idempotency-Key` (8-64 karakter) kabul eder (`IdempotentCreate`, kapsam `chatmedia:<cid>`,
mevcut `idempotency_record` tablosu; yeni migration yok). Aynı kullanıcı+sohbet+anahtar ikinci istekte yeni dosya üretmez,
mevcut eki (`AttachmentView`) döner ve hız sınırı/kota harcanmaz. Başlık yoksa eski davranış. Mesaj gönderimi zaten `clientId`
ile idempotent.

## Android

* `BuTransfers.kt` (`bu_kampus/transfers`): `update` -> TEK bildirim (kimlik 7710, kanal `bu_transfers`, düşük önem,
  `onlyAlertOnce`), `stop`. `TransferService`: `foregroundServiceType="dataSync"`, `START_NOT_STICKY`; Android 15+ `onTimeout`
  ile kapanır. İzinler: `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC` (mevcut `POST_NOTIFICATIONS` kullanılır).
* Servis YALNIZ süreci canlı tutar; yükleme Dart HTTP istemcisinde sürer. Sınırlar: kullanıcı "Zorla durdur" derse, sistem süreci
  sonlandırırsa ya da dataSync zaman aşımı dolarsa aktarım biter (sınırsız çalışma garantisi YOK); sonraki açılışta kuyruk kalan
  işi aynı `Idempotency-Key` ile sürdürür. Arka plandan servis başlatmak Android 12+'da yasaktır: servis iş kuyruğa alındığında
  (uygulama önde) başlar; başlatılamazsa sade bildirimle devam edilir. `POST_NOTIFICATIONS` reddedilirse bildirim görünmez,
  uygulama içi takip sürer.
* WorkManager kullanılmadı: dosya yüklemesi Dart tarafında ve süreç içindedir; süreç ölünce iş uygulama açılınca kurtarılır.
  Uygulama kapalıyken sürdürmek istenirse sonraki adım WorkManager + yerel HTTP yükleyici (yeni bağımlılık, ayrı iş).
* Gizlilik: bildirim yalnız sayı/durum taşır (alıcı, mesaj metni, dosya adı, önizleme yok).

## iOS (yapılmadı; sonraki adım)

Planlanan: background `URLSession` (kalıcı oturum kimliği, dosya tabanlı yükleme, `application(_:handleEventsForBackgroundURLSession:)`
ile olay yeniden bağlama), ActivityKit Canlı Etkinlik (güncelleme kaynağı: yerel yürütme ya da APNs; mevcut `core/live` ve
`BUWidgets` uzantısı yeniden kullanılabilir). Swift Windows'ta derlenemez; Codemagic derlemesi gerekir. Zorla kapatmada aktarım
kesintisiz sürer SÖZÜ VERİLMEZ; sonraki açılışta kuyruk sunucuyla karşılaştırır (aynı `Idempotency-Key`).

## Bilinen eksikler

* Aralıklı (resume) yükleme yok: süreç ölünce yükleme baştan başlar.
* Görsel yüklemede ara ilerleme yok (tek parça); video ilerlemesi gönderilen bayttan ölçülür.
* İndirme (`TransferDirection.download`) için çalıştırıcı yazılmadı; model/UI hazır.
* Mevcut `Outbox` (sohbet metin kuyruğu) değiştirilmedi; G4 medya mesajlarını bu kuyruğa taşıyınca Outbox medya yolu kaldırılabilir.

# Ana ekran widget veri sözleşmesi (schema 1)

Bu belge **uygulama (Flutter) ile native widget'lar (iOS WidgetKit, Android Glance) arasındaki tek sözleşmedir**. Native ajanlar yalnız bunu ve [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)'yi okuyarak widget yazar; ağ isteği, çeviri tablosu, tarih/sayı biçimlendirme **yoktur**.

- Üretici: `mobile/lib/features/widgets/widget_snapshots.dart` (`WidgetSnapshotBuilder`), yazıcı: `widget_sync_service.dart`.
- Makine okunur şema: [schemas/widget-snapshots.schema.json](schemas/widget-snapshots.schema.json) (JSON Schema 2020-12; `mobile/test/widgets/widget_schema_test.dart` örnekleri doğrular).
- **Hazır örnekler (yerleşim testleri için fikstür):** `examples/{tr,en,ar}/{menu,timetable,events,announcements,poll,quickaccess,social,meta,meta-signed-out}.json`, boş durumlar `examples/tr/empty/*.json`, oturumsuz `examples/tr/signed-out/menu.json`. Saat sabit: 6 Kasım 2026 Cuma 10:00 (İstanbul).

## 1. Depolama

Uygulama her widget için TEK bir JSON metin (UTF-8 string) yazar; widget yalnız okur.

| Platform | Depo | Nasıl yazılır / okunur |
|---|---|---|
| iOS | App Group `group.tr.com.bukampus.app` → `UserDefaults(suiteName:)` | uygulama `home_widget` eklentisiyle yazar; widget `UserDefaults(suiteName: "group.tr.com.bukampus.app")?.string(forKey: key)` |
| Android | `SharedPreferences("HomeWidgetPreferences")` | eklenti bu dosyaya yazar; widget `context.getSharedPreferences("HomeWidgetPreferences", MODE_PRIVATE).getString(key, null)` |

App Group Apple Developer'da tanımlanmalı ve **hem Runner hem BUWidgets hedefinin** entitlements'ına eklenmelidir (iOS ajanı). Anahtar adları sabittir (aşağıda ve her üç token dosyasında).

## 2. Anahtarlar

| Anahtar | İçerik |
|---|---|
| `bu_widget_meta` | ortak durum (bölüm 3) |
| `bu_widget_menu` | Günün yemek menüsü |
| `bu_widget_timetable` | Ders programı |
| `bu_widget_events` | Yaklaşan etkinlikler |
| `bu_widget_announcements` | Kampüs duyuruları |
| `bu_widget_poll` | Günün anketi |
| `bu_widget_quickaccess` | Hızlı erişim |
| `bu_widget_social` | Sosyal bildirim özeti (yalnız sayılar) |
| `bu_widget_exams` | Yaklaşan sınavlarım (yalnız kullanıcının kendi kayıtları) |
| `bu_widget_academic` | Yaklaşan akademik takvim tarihleri (herkese açık) |

Anahtar yok / değer boş / JSON bozuk / `schema` > 1 → widget **oturumsuz düzenini** çizer (bölüm 7); asla çökmez, asla örnek veri uydurmaz.

## 3. `bu_widget_meta`

```json
{ "schema": 1, "updatedAt": "2026-11-06T10:00:00+03:00", "lang": "tr", "rtl": false, "theme": "system", "signedIn": true,
  "strings": { "signedOutTitle": "Giriş yap", "signedOutSub": "BÜ Kampüs'ü aç", "appName": "BÜ Kampüs" } }
```

| Alan | Tip | Anlam |
|---|---|---|
| `schema` | int | sözleşme sürümü (şimdi 1). Alan EKLEMEK sürümü artırmaz (widget bilmediği alanı yok sayar); alan kaldırma/anlam değişikliği artırır. |
| `updatedAt` | ISO | son eşitleme anı (`+03:00`, Türkiye saati; yaz saati yok) |
| `lang` | `tr` \| `en` \| `ar` | uygulama dili. Tüm metinler bu dilde HAZIR gelir. |
| `rtl` | bool | `lang == ar`. Yerleşim yönü. |
| `theme` | `"system"` | widget sistem temasını izler (açık/koyu); uygulama teması yansımaz |
| `signedIn` | bool | `false`: oturum yok, tüm `bu_widget_<slug>` anahtarları SİLİNMİŞTİR |
| `strings` | map | oturumsuz düzenin metinleri (`signedOutTitle`, `signedOutSub`) + `appName` |

## 4. Ortak zarf (her slug snapshot'ında)

| Alan | Tip | Anlam |
|---|---|---|
| `schema` | int | 1 |
| `slug` | string | `menu`, `timetable`, `events`, `announcements`, `poll`, `quickaccess`, `social`, `exams`, `academic` |
| `state` | `ok` \| `empty` \| `signedOut` | `empty` = o widget'ın boş durumu (README'deki ikon + metin) |
| `generatedAt` | ISO | üretim anı |
| `expiresAt` | ISO \| null | bu andan sonra snapshot **boş durum** sayılır (bölüm 7). `null` = süresiz |
| `lang`, `rtl` | | meta ile aynı |
| `deepLink` | string | widget gövdesine/başlığa dokununca açılan adres (bölüm 8) |
| `a11y` | string | ekran okuyucu özet cümlesi (widget TEK öğe; bunu okut) |
| `strings` | map<string,string> | o widget'ın TÜM sabit metinleri (başlıklar, boş durum metinleri, şablonlar) + `signedOutTitle/Sub`. Anahtarlar aşağıdaki tablolarda |

Tarih-saat alanları her yerde `YYYY-MM-DDTHH:mm:ss+03:00`; yalnız gün `YYYY-MM-DD`; saat `HH:mm`. Sayılar Batı rakamıdır (tr binlik `.`, en/ar `,`; hazır metinde). `{n}`, `{time}`, `{date}`, `{day}`, `{kcal}`, `{votes}` yer tutucuları yalnız `strings` içindeki **şablonlarda** kalır; veri alanlarındaki metinler dolu gelir.

Şablon doldurma: tek yerleştirme, düz metin; metin kesme ve satır sayısı DESIGN_SYSTEM bölüm 6.

## 5. Slug alanları

### 5.1 `menu` — dokununca `bukampus://menu`

Üst düzey alanlar **bugünün** menüsüdür; `upcoming` sonraki en çok 2 günü aynı biçimde taşır (gece yarısı geçişi). Widget, yerel İstanbul gününe eşit `date` taşıyan nesneyi (üst düzey veya `upcoming[i]`) seçer; hiçbiri eşleşmezse boş durum.

| Alan | Tip | Anlam |
|---|---|---|
| `date`, `dateLabel` | string | `2026-11-06`, `Cuma, 6 Kasım` (medium/large başlığı) |
| `empty` | bool | o gün menü yok |
| `meals[]` | `{id, label, items[{name,kcal,kcalText}], totalKcal, totalText}` | `id`: `lunch` (bugün tek öğün; backend öğün ayırmaz) / `dinner` (ileride). `label` = caption (`ÖĞLE`). `kcal` null olabilir (kcalText de null) |
| `totalKcal` / `totalText` | int \| null / string \| null | `1.570 kcal`; kalori eksikse `~1.570 kcal`; hiç yoksa null (satırı gizle) |
| `totalLine` | string \| null | `Toplam 1.570 kcal` (medium alt satırı) |
| `kcalComplete` | bool | tüm yemeklerin kalorisi girilmiş |
| `small` | `{caption, main, sub, kcalLine}` \| null | small/2x2 için hazır: `ÖĞLE`, ana yemek, `Tavuk Sote · Pilav · Salata`, `1.570 kcal bugün` |

`strings`: `caption`, `captionAny` (YEMEK), `captionFull` (YEMEK MENÜSÜ), `emptyTitle`, `emptySmallSub`, `emptySub`, `totalLine`, `kcalToday`, `dailyTotal`, `kcalUnit`, `more` (`+{n} yemek`).
Bayatlık: `expiresAt` = sonraki gün 00:00 (yazılan son günün sonu).

### 5.2 `timetable` — dokununca `bukampus://timetable`

Üst düzey alanlar bugün (`date`, `dateLabel`, `dayName`, `count`, `lessons[]`); `upcoming[]` sonraki 6 takvim günü (aynı alanlar, ders olmayan gün `count: 0`). `next` = şu andan sonra başlayan ilk ders (bugün veya sonraki 7 gün) ya da null.

| Alan | Anlam |
|---|---|
| `lessons[]` | `{start,end,startMin,endMin,title,room}` başlangıca göre sıralı, en çok 8. `startMin/endMin` gece yarısından dakika (widget **şimdiki zamana göre** durum hesaplar). `room` null olabilir, en çok 8 karakter |
| `count` | o günün ders sayısı (liste 8'e kırpılsa da gerçek sayı) |
| `next` | `{date,time,dayName,dayShort,labelFull,labelShort}` → boş durum alt metni: `Sıradaki: {labelShort}` (small) / `Sıradaki ders: {labelFull}` (medium) |

Widget durum kuralı (yerel İstanbul saati `nowMin`): `endMin <= nowMin` → geçmiş (opaklık 0,5); `startMin <= nowMin < endMin` → "Şu an" (rozet `strings.nowBadge`, alt metin `endsAt`); ilk `startMin > nowMin` → sıradaki (ters rozet). Kalan süre: `d = startMin - nowMin`; `d < 60` → `inMin` (`{n}` = d), aksi `inHour` (`{n}` = `floor(d / 60)`, en az 1). Bugünün tüm dersleri bitmişse sıradaki yerine `next` (veya boş durum).
`strings`: `captionNext`, `captionNone`, `captionFull`, `headerNext` (`{date} · Sıradaki`), `nowBadge`, `inMin`, `inHour`, `endsAt` (`{time} biter`), `todayCount` (`Bugün {n} ders`), `lastEnds` (`Son ders {time} biter`, `{time}` = son dersin `end`), `more` (`+{n} ders daha`), `emptyTitle`, `nextSmall`, `nextFull`.
Bayatlık: `expiresAt` = yazılan son günün sonu (bugün + 6).

### 5.3 `events` — dokununca `bukampus://events` (satır: `events[i].deepLink`)

Alanlar: `count`, `countLabel` (`3 etkinlik`), `events[]` ≤ 3: `{id,title,communityName,startsAt,day,monthCaps,timeLabel,venue,deepLink}`; `day` sıfırsız (`5`), `monthCaps` `KAS`, `timeLabel` `14:00`, `venue` null/boş ise mekan öğesi (pin + metin) tamamen gizlenir. Sıra: başlangıç artan. Tek etkinlik small'da tüm widget `events[0].deepLink` açar.
Widget, `startsAt < şimdi - 1 saat` olan satırı kendisi eler (liste uygulamada 36 saat bayat olabilir).
`strings`: `captionSmall` (Yaklaşan), `captionEmpty` (Etkinlik), `title`, `countLabel` (şablon `{n} etkinlik`), `emptyTitle`, `emptySub`.
Bayatlık: `expiresAt` = üretim + 36 sa.

### 5.4 `announcements` — dokununca `bukampus://news` (satır: `items[i].deepLink`)

`items[]` ≤ 4: `{id,title,sourceName,publishedAt,dateLabel,urgent,urgentLabel,metaText,deepLink}`. Sıra: acil üstte, sonra yayın tarihi azalan. `metaText` hazır: `Acil · Kütüphane · 02 Kas` / `05 Kas`. Kesme kuralı: önce `sourceName` kısalır, `dateLabel` ASLA. `sourceName` bugün genelde null (backend vermiyor) → yalnız tarih. `urgent=true` ise `urgentLabel` `danger` renginde (tek kırmızı kullanım). `count`, `lastLabel` (`Son 4`).
`strings`: `titleSmall` (Duyurular), `title` (Kampüs Duyuruları), `last`, `urgent`, `emptyTitle`, `emptySub`.
Bayatlık: `expiresAt` = üretim + 72 sa.

### 5.5 `poll` — dokununca `bukampus://poll/{pollId}` (anket yoksa `bukampus://home`)

| Alan | Anlam |
|---|---|
| `pollId`, `question` | null → boş durum |
| `options[]` (2-4) | `{label, percent, percentText}`; `percent` yalnız `userVoted && resultsVisible` iken dolu (tam sayı, toplam 100; çoklu seçimde bağımsız), aksi null ve widget **yüzde/çubuk çizmez**, yalnız etiket + "Oy ver" |
| `userVoted` | true → small'da "Oy verildi" (`strings.voted`), aksi "Oy ver" hapı |
| `resultsVisible` | yüzdeler gösterilebilir |
| `totalVotes`, `totalVotesLabel` | `1.280`, `1.280 oy`; sonuç gizliyse null |
| `microLine` | medium sol alt `1.280 oy · gizli`; `secretLine` large alt `Oylar gizlidir · 1.280 oy` (oy sayısı null ise ikisi null; "gizli" yalnız statik kısım) |
| `leaderIndex` | en yüksek yüzdeli seçenek (tam renk); null → hepsi eşit ağırlıkta |

Kimlik/oy veren hiçbir yerde YOKTUR (gizli oy). `strings`: `caption`, `captionFull`, `vote`, `voted`, `voteMicro`, `voteCount`, `secretLine`, `detail`, `emptyTitle`, `emptySmallSub`, `emptySub`. Bayatlık: `expiresAt` = min(anket kapanışı, üretim + 24 sa).

### 5.6 `quickaccess` — dokununca `bukampus://home` (karo: `items[i].deepLink`)

`items[]` her zaman 8 öğe, kullanıcı sırasıyla: `{id,icon,label,a11yLabel,deepLink}`. `id`: `menu, timetable, events, clubs, chat, qr, news, search`; `icon`: Lucide adı (`utensils, calendar-clock, ticket, users, message-circle, qr-code, newspaper, search`). `smallIds[]` = small/2x2'deki 4 karo (varsayılan `menu, events, chat, qr`; özelleştirilince ilk 4). Medium/large 8 karo `items` sırasıyla 4x2. Etiket `Ders` (sığsın diye); ekran okuyucu `a11yLabel` (`Ders Programı`). `strings`: `caption`, `heading`, `sub`, `menu`..`search`, `timetableFull`. Boş durum yok, `expiresAt` null.

### 5.7 `social` — YALNIZ SAYILAR (KVKK)

`unreadMessages`, `newNotifications`, `newLikesAndFollowers` (int ≥ 0) ve hazır metinleri `…Text` (`99+`). `allZero` → boş durum (`state: empty`, kırmızı yok). `links`: `messages` → `bukampus://chat`, `notifications` → `bukampus://notifications`, `likes` → `bukampus://discover`, `header` → `bukampus://home`. Small'da tüm widget `deepLink` (mesaj>0 ise chat, değilse sıfır olmayan ilk hedef). Kişi adı, mesaj metni, fotoğraf, avatar HİÇBİR alanda yoktur ve eklenmez.
`strings`: `captionSmall`, `captionFull`, `captionEmpty`, `unreadSmall`, `labelMessages`, `labelNotifications`, `labelLikes`, `heading`, `privacyNote`, `rowMessages`, `rowNotifications`, `rowLikes`, `subMessages`, `subNotifications`, `subLikes`, `emptyTitle`, `emptySub`. `expiresAt` null (sayaçlar bir sonraki eşitlemeye kadar kalır; bayat sayı kabul edilmiş bir ödünleşimdir).

### 5.8 `exams` — dokununca `bukampus://exams`

Duyuru (`announcements`) ile AYNI satır biçimi: `count`, `lastLabel` (`Sonraki 3`), `items[]` ≤ 4 `{id,title,sourceName(null),publishedAt,startsAt,dateLabel,urgent(false),urgentLabel(null),metaText,deepLink}`. `title` ders adı (yoksa sınav başlığı); `metaText` hazır: `Vize · 12 Kas 10:30 · B-204` (tür · tarih saat · varsa salon). Sıra: başlangıç artan; `startsAt < şimdi - 1 saat` olanlar üretimde elenir. **Göreli gün ("6 gün kaldı") YAZILMAZ** (gece yarısı sonrası yanlışlaşır); tarih mutlaktır. Kırmızı kullanılmaz. Veri YALNIZ kullanıcının kendi sınavlarıdır (`GET /timetable/exams/upcoming`).
`strings`: `titleSmall` (Sınavlarım), `title` (Yaklaşan Sınavlar), `last`, `emptyTitle`, `emptySub`. Bayatlık: `expiresAt` = min(ilk sınavın başlangıcı + 1 sa, üretim + 72 sa).

### 5.9 `academic` — dokununca `bukampus://academic`

`exams` ile aynı biçim. `items[]` ≤ 4: akademik takvim kayıtları (dönem başı, ders kaydı, sınav haftası, tatil...), `metaText`: `Vize · 9 – 15 Kas` (tür · tarih ya da aralık; tek gün `10 Kas`; aylar arası `29 Kas – 3 Ara`). Biten kayıtlar elenir, sürenler listede kalır. Veri herkese açık takvimdir (`GET /academic/calendar?from&to`, 60 gün).
`strings`: `titleSmall`, `title` (Akademik Takvim), `last`, `emptyTitle`, `emptySub`. Bayatlık: `expiresAt` = min(ilk kaydın bitiş günü sonu, üretim + 72 sa).

Native çizim: iki widget de duyuru çizim koduyla çalışır (iOS `BuAnnouncementsView`, Android `announcements()`); farkı yalnız anahtar, başlık ve boş durum simgesidir.

## 6. Hangi boyut hangi alanı kullanır

| Slug | small / 2x2 | medium / 4x2 | large / 4x4 |
|---|---|---|---|
| menu | `small.*` | `dateLabel`, `meals[0].items[0..2]` (tek öğünde 0..5 iki sütun), `totalLine` | `dateLabel`, `meals[].items[0..3]` (tek öğünde 0..7), `meals[].totalText`, `totalText` (chip), `strings.more` |
| timetable | `next`/sıradaki ders + `strings` | `dateLabel`, `lessons` (2 satır) | `dateLabel`, `todayCount`, `lessons` (4), `lastEnds`, `more` |
| events | `events[0]` | `events[0..2]` | `events[0..2]`, `countLabel` |
| announcements | `items[0]` | `items[0..2]` | `items[0..3]`, `lastLabel` |
| poll | `question`, `userVoted` | `question`, `options[0..2]`, `microLine` | `question`, `options`, `secretLine` |
| quickaccess | `smallIds` → `items` | `items[0..7]` | `items[0..7]`, `strings.heading/sub` |
| social | `unreadMessages` + alt satır | 3 sütun | 3 satır, `privacyNote` |
| exams | `items[0]` | `items[0..2]` | `items[0..3]`, `lastLabel` |
| academic | `items[0]` | `items[0..2]` | `items[0..3]`, `lastLabel` |

## 7. Bayatlık, boş durum, oturumsuz, yenileme

| Durum | Widget ne çizer |
|---|---|
| `meta.signedIn == false` ya da anahtar yok / bozuk | **oturumsuz**: `display` "Giriş yap" (`meta.strings.signedOutTitle`) + `micro` `signedOutSub`, dokununca `bukampus://home` |
| `state == empty` | slug'ın boş durumu (README) |
| `now > expiresAt` | **boş durum** (ör. menü: "Bugün menü yok"). "Güncel değil" yazısı GÖSTERİLMEZ (menu README kararı: eski veri yerine doğrudan boş durum) |
| `social` | süresiz; bayat olabilir |
| `schema > 1` | oturumsuz düzen (güvenli geri düşüş) |

Meta yoksa (uygulama hiç açılmadı) yerel iki metin (`Giriş yap` / `BÜ Kampüs'ü aç`) native pakette tr/en/ar `Localizable.strings` / `strings.xml` olarak bulunur; başka hiçbir çeviri native'de tutulmaz.

**Yenileme.** Uygulama şu olaylarda ilgili snapshot'ları yeniden yazar ve widget'lara "yeniden çiz" der (iOS `WidgetCenter.reloadTimelines(ofKind:)`, Android `GlanceAppWidget.updateAll`): uygulama açılışı / ön plana geliş, giriş, çıkış, dil değişimi, push alma (sosyal + türüne göre etkinlik/duyuru/anket/menü/ders), ilgili veri değişimi (oy verme → poll, ders ekleme/silme → timetable), kısa debounce (2 sn). Uygulama kapalıyken **widget kendi zamanlayıcısını** kullanır:
- iOS timeline: `.after(30 dk)` + giriş noktaları: gece 00:05, ders başlangıç/bitişleri (`startMin`/`endMin`), menü için 12:00 ve 18:00.
- Android: `updatePeriodMillis` 30 dk (sistem alt sınırı) + uygulamanın kurduğu `HomeWidgetScheduledUpdateReceiver` alarmı (her sync'te ertesi gün 00:05 İstanbul; menü, ders, etkinlik receiver'larına). Android ajanı receiver'ı manifest'e ve `RECEIVE_BOOT_COMPLETED` iznini ekler.
Widget yerel saatle seçim yapar (gün eşleşmesi, `startMin`, `startsAt`); gün/ders geçişi için ağ ya da uygulama gerekmez.

## 8. Derin bağlantılar (koddan doğrulandı)

Şema **`bukampus://`** zaten iki platformda kayıtlıdır: iOS `Info.plist` `CFBundleURLTypes` (`bukampus`), Android `AndroidManifest.xml` `<data android:scheme="bukampus"/>` (BROWSABLE). Gelen adresi `app_links` verir; `ShareLinks.ingest` → `WidgetLink.parse` (`mobile/lib/features/widgets/widget_link.dart`) → oturum açıksa `openWidgetLink` (`widget_open.dart`). Soğuk açılışta hedef oturum/onay/profil kapıları geçilene kadar bekler (`ShareLinkHost`), sıcak açılışta hemen açılır. `bukampus://s/{t}/{id}` paylaşım bağlantısıdır, widget için kullanılmaz.

| Adres | Uygulamada açılan |
|---|---|
| `bukampus://home` | Ana Sayfa sekmesi |
| `bukampus://menu` | Yemek ekranı (bugün) |
| `bukampus://timetable` | Ders Programı |
| `bukampus://events` | Etkinlikler |
| `bukampus://events/{id}` | etkinlik detayı (alt sayfa) |
| `bukampus://clubs` | Kulüpler sekmesi |
| `bukampus://chat` | Sohbet sekmesi |
| `bukampus://qr` | Etkinliklerim (biletler/QR) |
| `bukampus://news` | Haberler/Duyurular listesi |
| `bukampus://news/{id}` | haber/duyuru detayı |
| `bukampus://search` | Arama |
| `bukampus://notifications` | Bildirimler |
| `bukampus://discover` | Keşfet sekmesi |
| `bukampus://exams` | Sınavlarım (akademik merkez) |
| `bukampus://academic` | Akademik Takvim |
| `bukampus://poll/{id}` | anket detayı (alt sayfa); kimliksiz `bukampus://poll` = home |

Native uygulama: iOS `Link(destination:)` / `.widgetURL(URL(string:)!)` (satır başına `Link`); Android Glance `actionStartActivity(Intent(ACTION_VIEW, Uri.parse(link)).setPackage(packageName))`. Tanınmayan/bozuk adres uygulamada yok sayılır (hiçbir şey açılmaz). Push yönlendirici (`targetType`/`targetId`) ayrı yoldur ve değişmedi.

## 9. Gizlilik (KVKK) ve oturum

- Snapshot'larda başka kullanıcının adı, mesaj içeriği, fotoğrafı/avatarı, e-postası **asla** bulunmaz (`widget_snapshots_test.dart` ve `widget_sync_test.dart` denetler). Sosyal yalnız sayıdır. Anket gizli oydur (kimlik yok). Etkinlik/duyuru/menü herkese açık içeriktir; ders programı yalnız kullanıcının kendi dersidir.
- **Çıkış, hesap değişimi, hesap silme, oturum iptali:** uygulamanın kullanıcı verisi temizleyicisi (`registerUserDataCleaners` → `WidgetSyncService.clearUserData`) TÜM `bu_widget_<slug>` anahtarlarını SİLER, `bu_widget_meta` `signedIn=false` (dil korunur) yazılır, widget'lar yenilenir ve "Giriş yap" durumuna döner. Hızlı erişim kısayol sırası da silinir. Yeni hesapla girişte yeniden yazılır; eski hesabın verisi sızmaz.
- Widget hiçbir zaman ağ isteği atmaz, kaynak sitelere gitmez, token/kimlik okumaz.

## 10. Native adlandırma sözleşmesi

| Slug | iOS WidgetKit `kind` | Android `GlanceAppWidgetReceiver` (paket `edu.bingol.bu_kampus.widgets`) |
|---|---|---|
| menu | `BUMenuWidget` | `MenuWidgetReceiver` |
| timetable | `BUTimetableWidget` | `TimetableWidgetReceiver` |
| events | `BUEventsWidget` | `EventsWidgetReceiver` |
| announcements | `BUAnnouncementsWidget` | `AnnouncementsWidgetReceiver` |
| poll | `BUPollWidget` | `PollWidgetReceiver` |
| quickaccess | `BUQuickAccessWidget` | `QuickAccessWidgetReceiver` |
| social | `BUSocialWidget` | `SocialWidgetReceiver` |
| exams | `BUExamsWidget` | `ExamsWidgetReceiver` |
| academic | `BUAcademicWidget` | `AcademicWidgetReceiver` |

Uygulama bu adlarla `HomeWidget.updateWidget(iOSName: kind, qualifiedAndroidName: ...)` çağırır (`WidgetSlug.iosKind/androidReceiver`); farklı ad verirseniz `widget_snapshots.dart` `WidgetSlug` ve bu tabloyu birlikte güncelleyin. Eklenmemiş widget için çağrı sessizce yok sayılır.
iOS hedef: `mobile/ios/BUWidgets/` (token dosyası `Shared/BuWidgetTokens.swift` hazır); Android: `mobile/android/app/src/main/kotlin/edu/bingol/bu_kampus/widgets/` (token dosyası + `res/values(-night)/widget_colors.xml` hazır).

## 11. Sürümleme

`schema: 1`. Yeni alan eklemek geriye uyumludur (widget yok sayar). Alan kaldırma/anlam değişimi → `schema: 2` ve widget'lar hem 1 hem 2'yi okumalıdır (en az bir sürüm boyunca). `kWidgetSchema` (Dart) + bu belge + şema dosyası birlikte güncellenir.

## G9 ek alanlari (2026-11-09; sozlesme surumu DEGISMEZ, yalniz alan eklendi)
- `bu_widget_meta.ownerUserId` (opsiyonel, int): snapshot'lari yazan hesap. Cikista/oturumsuzda YOKTUR. Yerel taraf, meta sahibi ile uyusmayan veriyi gostermemeyi buna dayandirabilir (su an yalniz Dart eslemesi hesap degisiminde eski turu yazmaz ve cikista her sey silinir).
- Her snapshot `strings.stale` ("Eski veri" / "Old data" / "بيانات قديمة"): yerel taraf `generatedAt` 24 saatten eskiyse (cevrimdisi / uygulama acilmadi) baslik satirina ` · <stale>` ekler. Android uygular (`WidgetGate.isStale`); iOS UYGULAMASI BEKLIYOR (macOS derlemesi gerekir). Hizli erisim (quickaccess) hariç.
- Gizlilik tercihi (Ayarlar > Ana ekran widgetlari): aciksa `timetable`, `exams`, `social` yerine icerik tasimayan `state:"empty"` kart yazilir (`strings.emptyTitle` = "Ayrıntılar gizli", `next:null`, `emptySmallSub` yok). Tercih cihaza ozel, `bu_widget_privacy` ("1"/"0"), cikista silinmez. Menu/etkinlik/duyuru/anket/akademik takvim herkese acik oldugu icin etkilenmez.


## W1 Hizli Erisim kisayol secimi (2026-11-10; sozlesme surumu DEGISMEZ)

- Snapshot DEGISMEZ: `quickaccess` her zaman 8 karoyu tasir; secim yerel tarafta uygulanir (secilen kimlikler, secim sirasiyla; small ilk 4).
- **Android:** `QuickAccessConfigActivity` (APPWIDGET_CONFIGURE; Android 12+ `reconfigurable|configuration_optional`): 8 kisayol, onay kutusu + yukari/asagi sira, en az 1. Secim widget ORNEGI basina, CIHAZA ozel, `HomeWidgetPreferences` anahtari `bu_widget_qa_sel_<appWidgetId>` = `<ownerUserId>|id,id,...` (yalniz sabit kimlikler; kisisel veri yok). Hesap baglami: `meta.signedIn=false` -> tum secimler silinir; baska `meta.ownerUserId` -> secim yok sayilir ve silinir; oturumsuzken yapilan secim (sahip bos) ilk oturumlu cizimde o hesaba baglanir; widget silinince anahtar silinir. "Kisisel ayrintilari gizle" tercihi hizli erisimi etkilemez (kisisel veri yok).
- **iOS (17+):** `AppIntentConfiguration` ile ayri widget (`BUQuickAccessPickerWidget`); secim sistemin widget yapilandirmasinda (App Intents), cihaza ozel. iOS 15-16'da mevcut statik widget. Bkz. mobile/ios/BUWidgets/BuQuickAccessPickerWidget.swift (DERLENMEDI).

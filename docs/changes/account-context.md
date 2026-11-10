# Hesap baglami (G8, 2026-11-09)

Kapsam: mobil `bu_kampus`. Backend degisikligi YOK (yeni Flyway yok).

## Giden kutusu (Outbox) sahipligi - G10 icin sozlesme
- `OutboxItem.ownerUserId` (JSON `u`): ogeyi kuyruga alan hesabin kullanici kimligi. Kuyruk kayitlari bu alani tasir; G10 aktarim (yukleme)
  kuyrugu da AYNI kurali uygulamalidir: kayit `ownerUserId` ile damgalanir, yalniz o hesap etkinken gonderilir/gorunur.
- `Outbox.bindOwner(id)`: `Session.userId` her atandiginda otomatik cagrilir (acilis, giris, hesap gecisi). `id == null` = oturum yok.
  Baglama degisince suren `drain` kesilir (eski hesabin kalan mesaji yeni kimlikle GITMEZ), zamanlayici durur, yeni hesap icin yeniden dener.
- Hesap degisimi / zorunlu oturum sonu / normal cikis: kayitlar SILINMEZ, diskte hesabina bagli bekler (`ApiClient.setTokens(null)` artik
  `clear()` degil `bindOwner(null)` cagirir). Yedi gun / 24 saat yas kurallari ayni (`_prune`).
- Kalici silme: hesap silme (`Session.signOut(purgeQueue: true)` -> `Outbox.purgeOwner(id)`) ve "tum hesaplardan cik" (`Outbox.clear()`).
- Sahipsiz eski kayit (alan yok): yuklemede ilk baglanan hesaba atanir (eski surumde kuyruk hesap degisiminde temizleniyordu).
- Suren HTTP istegi: `ApiClient._gen` oturum gecisinde artar, ucustaki istek `SESSION_CHANGED` ile iptal olur (degismedi).
- UI okumalari (`items`, `pendingCount`, `failedCount`) yalniz etkin hesabi gosterir; `contains/byClientId` clientId tekil oldugu icin tumunu tarar.
- Yeni aktarim kuyrugu kurali: (1) kayit sahibi yazilir, (2) gonderim oncesi `owner == aktif kullanici` denetlenir, (3) hesap degisince
  suren aktarim iptal edilir ama kayit/dosya silinmez, (4) hesap silinince `purgeOwner` benzeri kalici silme.

## Bildirim yonlendirme - G7 icin sozlesme
- `PushRouter.open`: yukteki `recipientId` etkin hesaptan farkliysa `_openForeign`: hesap cihazda kayitliysa `Session.switchAccount`, yuk
  `_pending` olarak saklanir ve gecisle tetiklenen `onSignedIn -> flushPending` hedefi yeni hesapta acar (toast: `pushForeignSwitched`).
  Oturumu dolmus hesap: yuk bekletilir + toast `pushForeignExpired`. Cihazda kayitli olmayan: yuk atilir + `pushForeignMissing`.
- `PushRouter.isForeignRecipient(data, session)`; `PushService.handleForeground` yabanci aliciyi erkenden eler: serit yok, rozet artmaz.
- Hedef 404/403/410: alakasiz bildirim listesi ACILMAZ; `pushContentGone` toast'i. Sohbet hedefinde ayrica Sohbet sekmesine gecilir
  (`shellTabRequest = 2`). Ag hatasi vb. eski davranisla listeye duser.

## Giris
- Google girisi derleme bayragi VARSAYILAN ACIK (`GOOGLE_SIGNIN` defaultValue true): Android AAB'de ekstra dart-define gerekmez. Sunucuda
  `AUTH_OAUTH_ENABLED`/`GOOGLE_CLIENT_IDS` kapaliysa 404 `OAUTH_DISABLED` ilk denemede duguyu gizler. Canli sunucu degeri dogrulanamadi.
- Apple adi on doldurmasi (I2-07): hesap ekleme akisinda `_accept -> _leaveActive` taslagi siliyordu; on doldurma artik `_accept` SONRASI
  yeniden yazilir.

## Kalan (bu dalda yapilmadi)
Hesap bazli anahtarli onbellek/taslak (simdilik hesap degisiminde `registerUserDataCleaners` ile temizlenir, sizinti yok), varsayilan avatar
olcu/kirpma (G1 ortak bilesen `bu_default_avatar.dart`), forceSignOut acik form uyarisi (I2-05), profil fotografi secimi sadelestirme.

## Ek (2. tur)
- Onboarding taslagi hesap bazli: anahtar `onboarding_draft_<uid>`, etkin hesap `OnboardingDraftStore.activeUserId` (Session atar). Hesap
  bilinmeden gelen Apple adi `onboarding_draft_pending`'te bekler, `savePrefill` ile hesabin taslagina katilir. Hesap kaldirilinca `clearFor(id)`.
- `forceSignOut`: acik sayfa varsa kapaninca "Oturumun sona erdigi icin acik sayfa kapatildi" toast'i (yazilanlar kaydedilmez).
- Destek talebi formu: yazilmis metin varken geri/kenar jesti onay ister (`formDiscard*`).
- ~~Gizlilik notu: cikista bekleyen mesaj/ek dosyalari hesabina bagli diskte kalir~~ **DEGISTI (2026-11-10, S1, kullanici karari):**
  `Session.signOut` artik `purgeQueue: true` varsayilanli: NORMAL cikista (ayarlar, cihazlar "bu cihazdan cik", zorunlu cikis yollari)
  bekleyen mesaj kuyrugu (Outbox, `purgeOwner`) ve yerel ek kopyalari silinir; aktarim kuyrugu (TransferQueue) `onSignedOut` kancasiyla
  zaten siler. Hesap DEGISTIRME (`switchAccount`) bu yoldan gecmez: kuyruk hesabina bagli kalir, dokunulmaz. Cikis oncesi kuyrukta
  gonderilmemis mesaj varsa `confirmUnsentLoss` (`features/profile/signout_guard.dart`, BuDialog.confirm) "Gonderilmemis N mesaj silinecek"
  onayi ister (ayarlar cikisi, tum hesaplardan cik, cihazlar ekraninda bu cihaz). `signOut(purgeQueue: false)` yalniz kasitli korumada.

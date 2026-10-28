# Gelistirme tohum verisi (DEV_SEED)

Yalnizca yerel gelistirme icin tekrar calistirilabilir ornek veri. **Uretimde calismaz.**

## Koruma
- Kod: `backend/.../devseed/DevSeedRunner` yalnizca `seed` profili acik ve `prod` kapaliyken (`@Profile("seed & !prod")`) bean olur.
- `DevSeedProdGuard` (`@Profile("prod")`): `prod` ile birlikte `seed` aciksa uygulama baslamaz.
- `scripts/reset-dev-db.sh` `prod` iceren profilde reddeder ve silme oncesi onay ister.

## Calistirma
- Sifirdan: `./scripts/reset-dev-db.sh [proje-adi]` (varsayilan `bu_fresh`; `docker compose -p <ad> down -v` + up + saglik bekleme; `BACKEND_PORT` varsayilan 18080, `INITIAL_FILL` varsayilan false). Mevcut yigina dokunmaz (farkli proje adi/port).
- Mevcut veritabanina ekleme: backend'i `SPRING_PROFILES_ACTIVE=dev,seed` ile baslatin; acilista calisir, tekrar calistirmak cogaltmaz (her kayit once aranir).

## Icerik
12 kullanici (hepsi `@bingol.edu.tr`, sahte, ASCII): `seed.admin@bingol.edu.tr` (ADMIN), `mobil.test@bingol.edu.tr` (perf betigi), `seed.ayse|mehmet|zeynep|emre|elif|can|selin|burak|derya|ozan@bingol.edu.tr`.
**DEV sifresi (hepsi): `DevSeed-2026!`** (yalnizca yerel). Fakulte/bolum/sinif dagitik, 3 dil.
5 kulup (OPEN/APPROVAL, sahip/yonetici/uye/bekleyen), 11 etkinlik (OPEN + APPROVAL, bekleyen basvurular, gecmis/gelecek, onay bekleyen, iptal), 15 gonderi (cogu yer tutucu gorselli; gorseller `PostMediaService` hattindan gecer), takip iliskileri, 3 birebir + 1 grup sohbeti (`MessageService` ile, sifreli), 4 anket (oylu), 2 destek talebi, bildirimler. Hikaye ve yorum OLUSTURULMAZ. Akademik takvim ve sozlesmeler migration'dan gelir. Kulup/etkinlik kapak yer tutucu PNG'leri `<storage>/devseed/` altina yazilir.

## Notlar
- Kayit/log: `DEV TOHUM:` oneki. Gorsel/sohbet adimlari hata verirse uyari log'lanir, diger adimlar surer.
- Tohum SQL ile dogrudan yazar (etkinlik, kulup, gonderi, anket, destek): sema degisirse `DevSeedRunner` guncellenmelidir.

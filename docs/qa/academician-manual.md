# Akademisyen alanı ve QR yoklama: elle test kılavuzu

Yerelde, tek makinede, sahte verilerle. Kontrol listesi biçimindedir: her adımın sonunda "Beklenen" yazar. Otomatik karşılığı: `scripts/smoke-academician.sh` (aşağıda "Otomatik duman testi").

> **Web adresleri HENÜZ KESİN DEĞİL.** Akademisyen paneli ve yönetici sayfaları ayrı web dallarında yazılıyor. Aşağıda sayfalar adıyla ve eylemle anlatılır; adresler SPEC'e göre varsayımdır (`/akademisyen/...`, `/admin/academicians`) ve web dalları birleştirilince doğrulanıp bu belge güncellenmelidir. Bölüm 5 ve 6'daki "[URL?]" işaretleri bu yüzden vardır. Arka uç (API) adımları (bölüm 1-4 ve 7) kesindir.

## 0. Ön koşullar
- Docker Desktop açık, `docker compose` çalışıyor. Node 20+ (web için). Depo kökünde `.env` var (`cp .env.example .env`; `DB_PASSWORD`, `JWT_SECRET` (en az 32 karakter), `ADMIN_PASSWORD` değerlerini doldurun; yerel sahte değerler yeter).
- Makinenizde başka projelerin konteynerleri varsa ve kapılar çakışıyorsa `BACKEND_PORT` değiştirin (aşağıda 18080 varsayılan).

## 1. Yığını başlatma (PostgreSQL + Redis + arka uç, tohum verisiyle)
```bash
# depo kökünden; proje adı bu_fresh, arka uç http://localhost:18080
ASSUME_YES=1 ./scripts/reset-dev-db.sh bu_fresh
```
- Bu komut `bu_fresh` projesinin verisini SİLER ve sıfırdan kurar (yalnız o proje; başka konteynerlere dokunmaz). `MAIL_ENABLED=false`, profil `dev,seed`.
- Postgres ve Redis ana makineye açılmaz (yalnız arka uç: `http://localhost:18080`). Başka kapı için: `BACKEND_PORT=18081 ASSUME_YES=1 ./scripts/reset-dev-db.sh bu_fresh`.
- Sağlık: `curl http://localhost:18080/actuator/health` -> `{"status":"UP"...}`. İlk açılış 1-3 dk sürebilir (imaj derlenir).
- [ ] Beklenen: komut "Hazır: http://localhost:18080 ..." yazarak biter.

Web arayüzü (web dalları birleştikten sonra), ayrı bir terminalde:
```bash
cd web && npm ci && VITE_DEV_BACKEND=http://localhost:18080 npm run dev     # http://localhost:5173
```

## 2. Doğrulama kodunu alma (e-posta kapalıyken)
Kayıt/e-posta doğrulama kodu e-posta yerine arka uç günlüğüne düşer:
```bash
./scripts/dev/last-code.sh bu_fresh          # son 3 kod: "<zaman>  <e-posta>  KOD=123456"
```
- [ ] Beklenen: kayıt isteğinden birkaç saniye sonra ilgili e-posta ve 6 haneli kod görünür.

## 3. Hazır hesaplar (hepsi sahte; şifre: `DevSeed-2026!`, yalnız yerel)
| Hesap | Rol |
|---|---|
| `seed.admin@bingol.edu.tr` | Yönetici (ADMIN) |
| `seed.hoca@bingol.edu.tr` | ONAYLI akademisyen; dersi `SEED101`, 2 ders saati, 4 kayıtlı öğrenci (mobil.test, ayse, mehmet, zeynep) |
| `seed.hoca.bekleyen@bingol.edu.tr` | BEKLEYEN akademisyen başvurusu |
| `seed.ayse`, `seed.mehmet`, `seed.zeynep`, `seed.emre`, `seed.elif`, `seed.can`, `seed.selin`, `seed.burak`, `seed.derya`, `seed.ozan` + `@bingol.edu.tr`; `mobil.test@bingol.edu.tr` | Öğrenci (rehberde görünürler) |

Yeni akademisyen denemek için kendiniz kayıt olun (bölüm 5.1); doğrulama kodu bölüm 2'deki gibi alınır.

## 4. Telefonu oynamak: öğrenci taraması (yardımcı betik)
Mobil uygulama yerine öğrencinin telefonunu bu betik oynar: giriş yapar, kodu `POST /api/attendance/scan`'e gönderir.
```bash
BASE=http://localhost:18080 ./scripts/dev/attendance-scan.sh seed.ayse@bingol.edu.tr 'bingol-lesson:12.345678.AbCd...'
echo 'bingol-lesson:...' | BASE=http://localhost:18080 ./scripts/dev/attendance-scan.sh seed.mehmet@bingol.edu.tr
```
Şifre varsayılan olarak tohum şifresidir; farklıysa `SEED_PASSWORD=...`. Kod web ekranındaki QR'ın altında düz metin olarak da görünüyorsa oradan kopyalayın (görünmüyorsa: tarayıcı geliştirici araçları > Ağ > `.../live` yanıtı, `codes[0].code`).
Kod 5 sn'de bir değişir, yaklaşık 10 sn geçerlidir: kodu alır almaz çalıştırın.

| Durum | Yanıt |
|---|---|
| Kayıtlı öğrenci, ilk okutma | `HTTP 200 {"status":"MARKED",...}` |
| Aynı öğrenci tekrar | `HTTP 200 {"status":"ALREADY",...}` |
| Kayıtlı olmayan öğrenci | `HTTP 200 {"status":"PENDING",...}` (hocaya iletildi) |
| Süresi geçmiş / bozuk / kapalı oturum | `HTTP 422 ... ATTENDANCE_CODE_INVALID` |
| Hoca kaydını kaldırmışsa | `HTTP 403 ... ATTENDANCE_REVOKED` |
| Hoca "yok say" demişse | `HTTP 403 ... ATTENDANCE_NOT_ENROLLED` |
| Dakikada 10'dan fazla | `HTTP 429` |

## 5. Akademisyen paneli (tarayıcı) [URL?]
Her adımda panelin gösterdiğini ve "Beklenen"i karşılaştırın. Giriş ekranı için `[URL? /akademisyen/giris]`.

### 5.1 Kayıt ve başvuru
1. [ ] **Kayıt** sayfası `[URL? /akademisyen/kayit]`: üniversite dışı bir adresle (ör. `deneme.hoca@example.org`) kayıt ol; bölüm 2'deki kodla e-postayı doğrula. Beklenen: başvuru formuna geçer.
2. [ ] Başvuru formu: unvan, ad, soyad, birim -> gönder. Beklenen: **Beklemede** sayfası `[URL? /akademisyen/beklemede]` ("başvurunuz inceleniyor").
3. [ ] Beklemedeyken panel sayfalarına gitmeyi deneyin (ör. Dersler). Beklenen: erişim yok, bekleme sayfasına döner (API 403 `ACADEMICIAN_NOT_APPROVED`).
4. [ ] Otomatik onay kuralı: ayrı bir tarayıcı profilinde `isim.soyisim@bingol.edu.tr` biçiminde yeni bir adresle kayıt+başvuru. Beklenen: hemen ONAYLI (panel açılır; yönetici "Otomatik onaylanan" sekmesinde görür). `<9-12 rakam>@bingol.edu.tr` ile başvuru: BEKLEMEDE kalır.

### 5.2 Yönetici onayı `[URL? /admin/academicians]`
1. [ ] `seed.admin@bingol.edu.tr` ile yönetici paneline girin. **Akademisyenler** sayfası, sekmeler: Bekleyen / Onaylı / Otomatik onaylanan / Reddedilen.
2. [ ] Bekleyen sekmesinde başvurunuzu bulun, **detay** açın: ad, unvan, birim görünür; e-posta maskeli olabilir (yetkiye bağlı).
3. [ ] **Reddet** (gerekçe yazın) -> Reddedilen sekmesine geçer; başvuran panelde gerekçeyi görür ve yeniden başvurabilir -> yine Bekleyen'de görünür.
4. [ ] **Onayla**. Beklenen: Onaylı sekmesi; başvuran sayfayı yenileyince panel açılır (uygulama içi bildirim gelir).
5. [ ] **İptal et** (gerekçe) -> hesap panele giremez (`403`); yeniden başvuru da reddedilir (`ACADEMICIAN_REVOKED`).

### 5.3 Ders, program, öğrenci
1. [ ] **Dersler** -> yeni ders: ad, dönem (`2026 Güz`), fakülte + bölüm (listeden seçilir). Beklenen: ders listede.
2. [ ] Ders detayı, sekme **Program**: haftalık saatler ekle (gün, başlangıç, bitiş, derslik). Bitiş başlangıçtan önceyse kayıt reddedilir.
3. [ ] Sekme **Öğrenciler** -> **Öğrenci ekle**: arama kutusuna `ayse` yazın. Beklenen: ad, bölüm, sınıf görünür; **e-posta HİÇ görünmez**. Seçip ekleyin; ayrıca "bölümdeki herkesi ekle" (toplu) deneyin. Eklenen öğrenciye bildirim gider.
4. [ ] Aynı öğrenci tekrar eklenirse sayı değişmez (tekrar yok).

### 5.4 Canlı yoklama
1. [ ] Ders detayı -> **Yoklama başlat** (isteğe bağlı "öğrencilere bildirim gönder" kutusu). Beklenen: **canlı ekran** açılır; her 5 sn'de değişen QR; "Var: 0 / Kayıtlı: N".
2. [ ] Kodu bölüm 4'teki betikle okutun (`seed.ayse`): ekranda Ayşe yaklaşık 2,5 sn içinde "Var" listesine düşer; sayaç 1 olur. Betik `MARKED`; tekrar okutunca `ALREADY`.
3. [ ] **Eski kod:** bir kodu kopyalayın, 11 sn bekleyin, okutun -> `422`. Değiştirilmiş (bir harfi bozuk) kod -> `422`.
4. [ ] **Kayıtsız öğrenci:** `seed.emre` ile okutun -> `PENDING`. Canlı ekranda "Kayıtlı değil" listesinde belirir, rozetle. `seed.zeynep` yerine başka biri için de tekrarlayın.
   - **Derse ekle ve var say:** öğrenci derse eklenir ve "Var" olur; öğrenciye bildirim gider.
   - **Yok say:** öğrenci aynı oturumda tekrar okutursa `403 ATTENDANCE_NOT_ENROLLED`.
5. [ ] **Hocanın son sözü:** Var listesinde bir öğrenciyi **Kaldır** -> sayaç düşer, satır "kaldırıldı" görünür; öğrenci tekrar okutursa `403 ATTENDANCE_REVOKED`. **Elle var say** ile geri alın (yöntem "elle"). Okutmamış başka bir öğrenciyi de elle işaretleyin.
6. [ ] **Oturumu kapat**: yeni okutma `422`; **Yeniden aç** çalışır; kapalıyken de kayıt düzeltmek mümkündür.
7. [ ] Aynı derste ikinci bir oturum (farklı tarih) açıp kapatın.

### 5.5 Devamsızlık ve dışa aktarma
1. [ ] Sekme **Devamsızlık**: satırlarda öğrenci, sütunlarda oturum; her hücre dört durumdan biri: **Var (QR)**, **Var (elle)**, **Silindi**, **Yok**.
2. [ ] Devamsızlık sınırı: tür "sayı", değer `2`. Beklenen: 1 devamsızlığı olan "risk altında", 2 ve üstü "sınırı aştı" rozetli. Sınır değişince öğrenciye bir kez uyarı bildirimi gider (aynı düzey tekrar gönderilmez).
3. [ ] Sekme **Dışa aktar** -> CSV indir. Beklenen: Excel'de Türkçe karakterler doğru (BOM); bir satır = bir kayıtlı öğrenci; hücreler "Var (QR) / Var (elle) / Silindi / Yok".
4. [ ] Öğrenci tarafı: `GET /api/my-courses` sayıları matrisle aynıdır (mobil "Derslerim" ekranında da bakın).

### 5.6 Duyurular (yedi tür) ve dosya
Sekme **Duyurular**; her tür için gönderin, listede görünsün:
- [ ] Ders başladı, Yoklama başladı (alan yok; ikisi de 10 dk'da bir; tekrarı "çok sık" hatası verir).
- [ ] Sınav (başlık + tarih zorunlu), Ödev (başlık + teslim tarihi zorunlu), Materyal (başlık), Ders iptal (tarih zorunlu), Derslik değişti (yeni derslik zorunlu).
- [ ] Zorunlu alan boş bırakılırsa form hata verir (API 400).
- [ ] Ödev/Sınav/Materyal'e **küçük bir PDF** ekleyin (en çok 5 dosya). Beklenen: listede dosya adı/boyutu; indirilebilir.
- [ ] `.pdf` uzantılı ama aslında program (exe) dosyası -> reddedilir (`NOTICE_FILE_TYPE_NOT_ALLOWED`).
- [ ] **ŞU AN BİLİNEN SORUN:** yaklaşık 64 KB'dan büyük dosya `413` ile reddedilir (bkz. bulgular); gerçek bir ödev PDF'siyle deneyince bunu göreceksiniz.
- [ ] Duyuruyu sil -> öğrencide liste ve dosya kalkar (indirme 404).

### 5.7 Sahiplik
- [ ] İkinci bir onaylı akademisyenle (ör. otomatik onaylı yeni hesap) birinci hocanın ders/oturum/duyuru adresini elle açın. Beklenen: bulunamadı (404), veri yok.

## 6. Yönetici salt-okunur sayfalar [URL? /admin/academicians/:id]
- [ ] Akademisyen detayında: dersleri, ders detayı, devamsızlık matrisi ve duyurular (dosyalı olanlar dahil) **okunur**; dosya indirilebilir (denetim kaydı düşer). Yönetici yazma yetkisi yoksa onay/red/iptal düğmeleri çalışmaz (403).

## 7. Otomatik duman testi (API düzeyi)
```bash
BASE=http://localhost:18080 PROJECT=bu_fresh ./scripts/smoke-academician.sh
```
- Tohum veritabanı gerekir (bölüm 1). Betik rastgele hesaplar açar, tekrar çalıştırılabilir; her adım için `PASS`/`FAIL` yazar, sonunda özet verir; hata varsa çıkış kodu 1. Yaklaşık 1,5-3 dk. Araçlar: bash, curl, node, sha256sum, docker compose.
- Başlangıçta Redis'i temizler (kayıt IP sınırı için): `FLUSH_REDIS=0` ile kapatılır.
- Tüm duman testleri için `scripts/smoke-all.sh` bu betiği de bulur (`smoke-*.sh`).

## 8. Kapatma
```bash
docker compose -p bu_fresh down -v        # yalnız bu_fresh projesinin konteyner ve volume'ları
```
Başka projelerin konteynerlerine dokunmayın (`docker system prune` KULLANMAYIN).
- [ ] `docker ps` yalnız başka projelerin konteynerlerini gösterir.

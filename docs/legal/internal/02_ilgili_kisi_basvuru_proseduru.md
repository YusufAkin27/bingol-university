# İlgili Kişi Başvuru Prosedürü ve Cevap Şablonları (İç Belge)

Dayanak: KVKK m.11, m.13; "Veri Sorumlusuna Başvuru Usul ve Esasları Hakkında Tebliğ". Süre: **talebin niteliğine göre en geç 30 gün**; cevap ücretsiz (ek maliyet gerekirse Kurul tarifesi).

## 1. Kanallar

1. Uygulama içi Destek > "Kişisel veri başvurusu" (hesap kimliği oturumdan bilinir; en güvenli kanal).
2. Web `/data-request` sayfası / Destek e-postası (girişsiz; kimlik doğrulama şart).
3. Yazılı (ıslak imzalı dilekçe, noter), KEP.

## 2. Akış

| Adım | Süre | Sorumlu | Eylem |
|---|---|---|---|
| 1. Kayıt | Gün 0 | Destek | Başvuruyu kaydet (tarih, kanal, talep türü); etiket `KVKK` |
| 2. Kimlik doğrulama | Gün 0-3 | Destek | Oturumlu başvuru: kimlik doğrulanmış sayılır. Girişsiz: kayıtlı `bingol.edu.tr` adresine doğrulama e-postası gönder; yeterli değilse ek bilgi iste. **Başka kişinin hesabına dair veri verme.** |
| 3. Değerlendirme | Gün 3-15 | Teknik + hukuk | Talebi karşıla/kısmen/reddet; istisnaları (KVKK m.28, başkalarının hakları, yasal saklama) belirle |
| 4. Uygulama | Gün 15-25 | Teknik | Erişim: `GET /api/users/me/export` (kullanıcı kendisi alır); düzeltme: profil; silme: hesap silme akışı/`AccountDataPurger`; itiraz: not al |
| 5. Cevap | En geç gün 30 | Veri sorumlusu temsilcisi | Yazılı/elektronik cevap; ret ise gerekçeli |
| 6. Kayıt | — | Destek | Başvuru-cevap dosyası 3 yıl saklanır (KVKK m.14 şikâyet süreleri) |

Süre uzatma tek seferlik değildir; 30 günü aşamayacak durumda kullanıcıya gerekçeli ara bilgi verilir.

## 3. Mesaj içeriği ve yönetici kayıtları talepleri

- Kullanıcı kendi mesaj kopyasını "Verilerimi indir" ile alır (silinmiş mesajlar çıktıda yoktur). Silinmiş/düzenlenmiş mesajların şifreli kopyaları ve **yönetici erişim kayıtları** hakkında talep gelirse: hukuk danışmanı değerlendirir; başkalarının mahremiyeti, güvenlik ve hukuki uyuşmazlık istisnaları gözetilerek cevap verilir.
- "Mesajlarıma yönetici baktı mı?" sorusu: ilgili `message_access_audit` kaydı (hedef kullanıcı = başvuran) hukuk onayıyla özetlenerek verilebilir; yöneticinin kimliği ve amacı kayıt politikasına göre sınırlandırılabilir.

## 4. Cevap şablonları

**A. Kabul (erişim/bilgi)**
> Sayın {ad}, {tarih} tarihli başvurunuz KVKK m.13 uyarınca incelenmiştir. Hesabınıza ilişkin işlenen kişisel veriler, amaçları ve aktarıldığı alıcı grupları ekte/aşağıda yer almaktadır: … Verilerinizin kopyasını uygulamadaki Profil > Verilerimi indir bölümünden de alabilirsiniz. Saygılarımızla, {unvan}

**B. Kabul (silme)**
> Başvurunuz doğrultusunda hesabınız anonimleştirilmiş, bildirim cihazı kayıtlarınız, bildirim kutunuz, tercihleriniz, favorileriniz ve yüklediğiniz sohbet görselleriniz silinmiştir. Hukuki yükümlülük ve başkalarının hakları nedeniyle sözleşme onay kayıtları, moderasyon izleri ve sohbet geçmişindeki mesajlar kimliksiz/sınırlı olarak saklanmaktadır; cihaz/IP kayıtları {90} gün, analitik olaylar 180 gün içinde silinecektir.

**C. Kısmi kabul / ret**
> Talebinizin … kısmı, {gerekçe: KVKK m.7/m.28 veya yasal saklama yükümlülüğü, başkalarının hak ve özgürlükleri, hukuki uyuşmazlık delili} nedeniyle karşılanamamıştır. Cevabı öğrendiğiniz tarihten itibaren 30, her halde başvuru tarihinden itibaren 60 gün içinde Kişisel Verileri Koruma Kurulu'na şikâyet hakkınız saklıdır.

**D. Kimlik doğrulama talebi**
> Başvurunuzun sahibi olduğunuzu doğrulamak için hesabınıza kayıtlı bingol.edu.tr adresinizden bu iletiye yanıt verin veya {ek bilgi} iletin. Doğrulama yapılamazsa başvurunuz işleme alınamayacaktır.

**E. Süre uzatma/ara bilgi**
> Başvurunuz işleme alınmış olup {gerekçe} nedeniyle sonuçlandırma için ek süreye ihtiyaç duyulmaktadır. En geç {tarih} tarihine kadar (başvuru tarihinden itibaren 30 günü aşmayacak şekilde) cevap verilecektir.

## 5. Kayıt alanları

Başvuru no, tarih, kanal, kimlik doğrulama yöntemi, talep türü (m.11 bent), karar, gerekçe, cevap tarihi, sorumlu. Kayıtlar kişisel veri içerir; erişim sınırlı tutulur.

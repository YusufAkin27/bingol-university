# Akademisyen alanı hukuki metin revizyonu: değişiklik notları ve açık sorular (İç Belge, TASLAK)

Tarih: 2026-11-14. Dal: `feat/academician-legal-20261114`. Migration: **V1910** (`V1910__legal_texts_academician.sql`, `scripts/build-legal-migration-v1910.js` ile üretilir). Bu belge kullanıcıya gösterilmez.

**Bu bir taslaktır; hazırlayan bir avukat değildir. Aşağıdaki "AÇIK SORULAR" cevaplanmadan V1910 prod'a uygulanmamalıdır** (V1910 uygulandığı anda metinler canlıya çıkar). Kod gerçeği kaynağı: `docs/changes/academician.md`, `docs/DATABASE.md` bölüm 16 ve 18, `backend/.../academician/`.

## 1. Mekanizma (özet)

- Metinler `docs/legal/<tür>_<dil>.md` (tr esas; en/ar aynı bölüm yapısı) → generator betiği → Flyway migration → `legal_document` tablosu (sürümlü, tr+en+ar aynı numara). Yeni sürüm eskileri pasife alır; onay kayıtları değişmez.
- Yeniden onay: `require_reaccept` bayrağı; yalnızca TERMS/PRIVACY/KVKK/COMMUNITY_RULES "imzada zorunlu" türlerdir (`LegalType.isSignupRequired`). Diğerleri bilgilendirmedir.
- Web ve mobil metni API'den okur (`GET /api/legal/{tür}`); istemci kaynaklarında gömülü sözleşme metni **yoktur**, bu yüzden web/mobil kaynak değişikliği gerekmedi.
- Testler: `LegalMigrationV1910FileTest` (SQL = Markdown birebir, tr/en/ar bölüm şekli eşit, `require_reaccept` kararı, temel beyanlar), `LegalMigrationV1470FileTest` ve `LegalMigrationV820FileTest` (arşivlenmiş kaynaklardan), `LegalMigrationV620FileTest`, `LegalServiceTest`.

## 2. Değişiklik tablosu

"Eski" sütunu V1470 sürümüdür. EN ve AR, TR ile aynı anlamda ve aynı bölüm/madde/satır sayısıdır.

| Belge | Bölüm | Eski (özet) | Yeni (özet) | Neden |
|---|---|---|---|---|
| Kullanım Koşulları | 1.3 (hizmet listesi) | "...topluluklar ve etkinlikler (QR ile yoklama dahil), gönderiler..." | Listeye "öğretim elemanlarına (akademisyen) yönelik ders, ders yoklaması ve ders duyurusu alanı" eklendi | Yeni özelliğin hizmet kapsamında sayılması |
| Kullanım Koşulları | 4.8 | "Etkinlik yoklama (QR) sistemini kötüye kullanmak" | "Etkinlik veya ders yoklama (QR) sistemini ..." | Aynı kural derse genişledi (başkası adına yoklama, kodu paylaşma) |
| Kullanım Koşulları | 4.11 (yeni madde) | Yok | Akademisyen alanını kötüye kullanmak: akademisyen olmadan başvurmak, yanlış unvan/birim, rehberi ders yürütme amacı dışında kullanmak/kopyalamak/paylaşmak, yoklama dışa aktarımını amaç dışı kullanmak | Rehberin kötüye kullanımını caydırmak; **yeni yükümlülük** (açık soru 8) |
| Kullanım Koşulları | 7.5 (yeni madde) | Yok | Akademisyen başvurusu yönetici onayına tabidir; onay üniversitenin personel doğrulaması değildir; onaylı akademisyen rehberi görür, derse ekler, yoklama alır, duyuru gönderir; usul Gizlilik 15 ve KVKK 12'de; akademisyen öğrenci verisini yalnız ders yürütme amacıyla ve hukuka uygun kullanır | Rolün ve sınırın tanımı |
| Kullanım Koşulları | 13.1 (hesap silme) | Silinenler listesi | Öğrenciyseniz ders kayıtları ve yoklama kayıtları; akademisyenseniz başvuru ve dersler de silinir | Kodun silme davranışı (`AcademicianAccountPurger`) |
| Kullanım Koşulları | 15.3 (yeni madde) | Yok | Akademisyen alanındaki yoklama ve duyurular akademisyenin kullanıcı olarak yaptığı kayıt/bildirimdir; üniversitenin resmî devam/yoklama kaydı veya bildiriminin yerini tutmaz, üniversite sorumlu tutulamaz | 15.1 ile (uygulama üniversitenin resmî uygulaması değildir) uyumlu açıklama; **hukuki iddia, açık soru 7** |
| Gizlilik | 1 (Kısaca) madde 6 (yeni) | Yok | Akademisyen alanı ve rehber görünürlüğü tek cümlede; yoklamada konum/cihaz kimliği yok | Okuyana ilk bakışta uyarı |
| Gizlilik | 2 (veri tablosu), 4 yeni satır | Yok | Akademisyen başvurusu; Öğrenci rehberi; Ders kaydı ve yoklama; Ders duyuruları ve ekleri (amaç, hukuki sebep, saklama süresi) | Yeni veri kategorileri ve amaçlar |
| Gizlilik | 4 (alıcılar) yeni satır | Yok | Onaylı akademisyenler (uygulama kullanıcıları); ayrı ülkeye aktarım yok | Kim görür |
| Gizlilik | 7 (verilerimi indir; hesap silme tablosu) | Dışa aktarım ve silme listeleri | Ders kaydı, yoklama, bekleyen okutma isteği (akademisyense başvuru ve ders özeti) dışa aktarımda; silinenler listesine ders kaydı/yoklama ve akademisyenin dersleri (oturum, yoklama, duyuru, ek) | Kodla uyum (`AcademicianExporters`, `AcademicianAccountPurger`) |
| Gizlilik | 15 (yeni bölüm; İletişim 16 oldu) | Yok | 9 madde: başvuru/onay, **öğrenci rehberi (açık cümle)**, derse ekleme, yoklama (konum/cihaz kimliği yok), devamsızlık uyarıları, duyurular, kim görür, saklama (otomatik süre yok, dürüstçe), haklar | Tek yerde sade anlatım |
| KVKK | 2 (kategoriler) | Eğitim/mesleki bilgi satırı | Satıra unvan/birim ve e-postadan türetilen öğrenci numarası eklendi; yeni satırlar "Akademisyen başvurusu", "Ders kaydı ve yoklama" | Kategoriler |
| KVKK | 3 (amaçlar) madde 11 (yeni) | Yok | Akademisyen başvurusu, rehber, derse ekleme, yoklama, uyarı, duyuru, CSV, yönetici izleme | Amaçlar |
| KVKK | 4 (hukuki sebepler) | (c) ve (f) örnekleri | (c)'ye akademisyen başvurusu ve öğrencinin kendi QR okutması; (f)'ye rehber, ders kaydı, yoklama, uyarı, duyuru eklendi | Dayanak eşlemesi |
| KVKK | 5 (aktarım) yeni satır | Yok | Onaylı akademisyenler; ayrı ülkeye aktarım yok | Alıcı |
| KVKK | 7 (saklama) | Başlıca süreler | Akademisyen alanı için otomatik süre yok; ders/hesap silinene kadar; bağsız dosya 24 saat | Dürüst saklama beyanı |
| KVKK | 9 (otomatik karar) | Otomatik önlemler | Otomatik onayın (olumlu sonuç) ve devamsızlık uyarısının (yalnız bildirim) niteliği | Otomatik işleme şeffaflığı |
| KVKK | 12 (yeni bölüm) | Yok | Akademisyen alanı: ilgili kişiler, rehberde görünen veriler, amaç-dayanak tablosu, alıcılar, toplama yöntemi, işlenmeyenler, haklar | Ek aydınlatma |
| Saklama ve İmha | 2 (tablo) 5 yeni satır | Yok | Akademisyen başvurusu; ders kaydı/yoklama (otomatik süre yok); duyuru ve ekleri; bağsız dosya 24 saat; öğrenci rehberi (kopya yok) | Süre tablosu |
| Saklama ve İmha | 3 (hesap silinince) | Silinenler | Öğrenci/akademisyen için ek paragraf | Kodla uyum |
| Gizlilik 2, 15.4-15.5, 15.8; KVKK 2, 9, 12; Saklama 2 (tr/en/ar) | (düzeltme turu, V1910 yeniden üretildi) | Yoklama durumları var/yok/kaldırıldı; devamsızlık cümlesi "karar vermez"; duyuru silinince ekleriyle birlikte silinir; bağsız dosya "24 saat" | Durumlar: var (QR/elle), **izinli** (elle; ne var ne devamsız), kaldırıldı, yok; derse eklenmeden önceki dersler "henüz kayıtlı değil" ve devamsızlık sayılmaz. Sayılar kayıtlardan otomatik hesaplanır; hoca kaydı düzeltebilir, oturumu hesaptan çıkarabilir veya kayıtlarıyla silebilir, sayı/uyarı yeniden hesaplanır; uygulama geçme/kalmaya karar vermez. Limit ders sayısı/yüzde olarak anlatıldı (yeni veri kategorisi yok). Silinen duyuru yumuşak silinir: kimseye gösterilmez, ekleri silinir, kayıt gönderim sınırları için kalır. Bağsız dosya "bir sonraki zamanlanmış temizlikte, normalde 24 saat içinde" | Backend düzeltme turu (izinli, oturum dışlama/silme, limit, yumuşak silinen duyuru, gece temizliği) |
| Açık Rıza, Çerez, Topluluk Kuralları, İçerik Bildirimi | - | - | DEĞİŞMEDİ | Yeni açık rıza gerektiren işlem eklenmedi (karar değil, açık soru 3); izleme çerezi eklenmedi |
| İç belgeler | 01 envanter, 06 VERBİS envanteri, 09 DPIA bölüm 3 | - | Yeni satırlar ve kısa DPIA | Projenin kendi checklist'i |

Değişmeyenler (bilerek): veri sorumlusu kimliği/adresi, VERBİS satırı ve tüm `{{controller.*}}` yer tutucuları; Kullanım Koşulları 15.1 (`{{controller.relation|...}}`, uygulama üniversitenin resmî uygulaması değildir); yurt dışı aktarım alıcıları ve mekanizması (Firebase/APNs, Brevo); mevcut saklama süreleri. Hiçbir saklama sayısı uydurulmadı: yeni verilerde yalnızca kodda gerçekten olan "24 saat" (bağsız dosya) yazıldı.

## 3. Hukuki sebep eşlemesi (taslak)

| Yeni amaç | Uygulanan dayanak (KVKK m.5/2) | Neden | Durum |
|---|---|---|---|
| Akademisyen başvurusu ve onayı | c + f | Akademisyen alanı bir hizmettir (c); öğrenci verisine yetkisiz erişimin önlenmesi (f) | Makul; onay bekliyor |
| **Öğrenci rehberinin onaylı akademisyenlere gösterilmesi** | **f** | Öğrenci bu işlemi başlatmaz, sözleşme/rıza yok; metindeki mevcut dayanaklardan yalnızca meşru menfaat kalır. Profil gizlilik ayarından bağımsızdır ve rehberden çıkma ayarı yoktur | **KARAR VERİLMEDİ, avukata bırakıldı (soru 1)** |
| Derse ekleme, ders kaydı | f | Öğrenci eylemi yok | Soru 2 |
| Yoklama (öğrenci kendisi QR okutur) | c (+ f) | Öğrencinin kendi eylemi | Makul |
| Yoklama (hoca elle işler/kaldırır), devamsızlık takibi | f | Ders yürütme | Soru 2-4 |
| Devamsızlık uyarısı ve duyuru iletimi | f; c (bildirim) | Bilgilendirme | Soru 4, 15 |
| Yönetici salt okunur izleme | f + ç | Mevcut yönetici erişimi çizgisi (denetim, `@AuditRead`) | Makul |

## 4. Yeniden onay kararı

**TRUE: TERMS, PRIVACY, KVKK. FALSE: RETENTION.** Proje kuralı (`LEGAL_NOTES.md` bölüm 8, 9, 14): FALSE, yalnızca "yeni işleme amacı veya veri kategorisi yok; kullanıcı aleyhine değişiklik yok; açık rıza gerektiren yeni işlem yok" iken seçilmişti. Bu revizyonda yeni amaç ve kategori vardır, bu yüzden FALSE gerekçesi geçerli değildir; kural bu durumu açıkça yazmadığı için mekanizmanın desteklediği **muhafazakar** seçenek (TRUE) seçildi. Etki ve açma sırası: `LEGAL_NOTES.md` bölüm 15 ve 8. Avukat "aydınlatma güncellemesi yeter" derse FALSE'lu yeni bir migration yayımlanabilir (açık soru 9).

## 5. AÇIK SORULAR: hukuki onay gerekli

Her soru tek cümleyle cevaplanabilecek biçimdedir. "Metin" = V1910 taslağı.

1. **Rehber dayanağı.** Tüm onaylı akademisyenlerin, uygulamaya kayıtlı ve profili tamam *tüm* öğrencilerin adını, öğrenci numarasını, fakültesini, bölümünü ve sınıfını görmesi için meşru menfaat (m.5/2-f) yeterli mi, yoksa açık rıza veya üniversitenin kendi görev/yetkisi gerekir mi?
2. **Rehberden çıkma ve derse ekleme.** Öğrencinin rehberden çıkma (itiraz) ayarı olmadan ve öğrenci eylemi olmadan derse eklenmesi (öğrenci kendi çıkamaz; yalnız bildirim gider) orantılı mı; hangi asgari hak (çıkma/itiraz düğmesi, yalnız kendi bölümünün listelenmesi) şart koşulur?
3. **Açık Rıza Metni.** Rehber görünürlüğü veya yoklama için ayrı bir açık rıza metni gerekir mi (şu an Açık Rıza Metni DEĞİŞMEDİ)?
4. **Resmî nitelik ve rol.** Uygulama üniversitenin resmî uygulaması olmadığı hâlde, resmî devam/yoklama verisi gibi görünen veriyi işlemesi veri sorumlusu rolünü (veya üniversiteyle ortak sorumluluğu) değiştirir mi; üniversitenin yazılı katılımı/protokolü ya da veri işleyen sözleşmesi gerekir mi? (Mevcut metindeki "kullanıcı verileri üniversiteye aktarılmaz" ve "resmî uygulama değildir" ifadeleri bu nedenle bu revizyonda DEĞİŞTİRİLMEDİ.)
5. **Saklama süresi.** Ders kaydı, yoklama ve duyurular için kodda otomatik süre yok (ders veya hesap silinene kadar; arşivlemek veri silmez); dönem sonu sonrası makul azami süre (ör. X yıl) belirlensin mi, belirlenirse süre ne olmalı (kod sonra eklenir, metin güncellenir)?
6. **Akademisyen doğrulaması.** Otomatik onay yalnızca e-posta örüntüsüne dayanır (kodla doğrulanmış, bingol.edu.tr, harfli yerel kısım, sınıf bilgisi yok) ve personel doğrulaması değildir; "onay üniversitenin kişiyi personel olarak doğruladığı anlamına gelmez" cümlesi doğru ve yeterli mi, otomatik onay kapatılmalı mı (`NEVER`)?
7. **Koşullar 15.3.** "Akademisyen alanındaki yoklama ve duyurular resmî devam kaydı/bildirimi yerine geçmez ve üniversite sorumlu tutulamaz" cümlesi, üniversitenin aslında bu kayıtları resmî saydığı bir durumda sorun yaratır mı; cümle kalsın mı?
8. **Akademisyenin rolü.** Akademisyen, öğrenci verisini (rehber, yoklama CSV'si) indirdiğinde bağımsız veri sorumlusu mu olur; Koşullar 4.11 ve 7.5'teki yükümlülük (yalnız ders yürütme amacı, hukuka uygun kullanım) bu risk için yeterli mi, taahhütname (`07`) gerekir mi?
9. **Yeniden onay.** Muhafazakar `require_reaccept=TRUE` (TERMS/PRIVACY/KVKK) doğru mu, yoksa bu bir KVKK m.10 aydınlatma güncellemesi olduğundan FALSE yeterli mi (KVKK metni için onay kaydı hukuken gerekmeyebilir)?
10. **Yurt dışı aktarım kapsamı.** Anlık bildirim içeriği artık ders adı, duyuru başlığı ve devamsızlık durumu ("sınıra ulaştınız") gibi eğitim verisi içerir ve Firebase/APNs'ten yurt dışına gider; mevcut m.9 mekanizması (bildirim izni = açık rıza ve/veya standart sözleşme, `05`) bu içeriği de kapsıyor mu?
11. **Reşit olmayanlar.** Rehberde 18 yaş altı öğrenci olabilir (kayıtta yaş sorulmuyor); bu durumda ek önlem gerekir mi (mevcut Gizlilik 10 değişmedi)?
12. **Mağaza formları.** Play Veri Güvenliği ve App Store App Privacy formları akademisyen alanı verileriyle (ad, öğrenci numarası, fakülte/bölüm/sınıf, yoklama kaydı, duyuru dosyası) nasıl güncellenmeli (`docs/store/data_safety.md`, `docs/ios-store/APP_PRIVACY.md` bu revizyonda DEĞİŞTİRİLMEDİ)?
13. **Hesap silme etkisi.** Akademisyen hesabı silinince dersleri ve öğrencilerin o derslerdeki yoklama kayıtları da silinir (öğrencinin ispat imkânı kaybolur); öğrenci hesabı silinince satırları silinir (hoca verisinden düşer); bu ters etki kabul edilebilir mi, yoklama için saklama (m.5/2-e) gerekir mi? Ek açı: akademisyen tek tek oturumları da kayıtlarıyla silebildiğinden öğrencinin yoklama kanıtı hesap silinmeden de kaybolabilir; oturum silme için kayıt/iz (ör. silme günlüğü) gerekir mi?
14. **Öğrencinin ders kaydını silme/itiraz hakkı.** Öğrenci kendi ders kaydını silemez (hoca veya Destek yoluyla); KVKK m.11 başvurusunun "hocadan istenmesi veya Destek" şeklinde karşılanması yeterli mi?
15. **Bildirim tercihleri.** Metinde "bildirim tercihleri geçerlidir" demedim, yalnızca bildirim gittiğini yazdım (ders duyuruları "akademik duyurular" alt türünü kullanır; diğer akademisyen bildirimlerinin tercihe tabi olup olmadığı doğrulanmalı); kullanıcı bu bildirimleri kapatabilmeli mi?
16. **Yönetici erişimi.** Yönetim paneli yöneticilerinin tüm akademisyen/ders/yoklama/ek verisini salt okunur görmesi için yönetici erişim çizgisi (m.5/2-f, ç; `@AuditRead` kaydı; maskeli roller) yeterli mi, ayrı gerekçe/erişim defteri (`04`) istenir mi?
17. **Dosya ekleri.** Duyuru eklerinin içeriği (ör. öğrenci listeleri) kişisel veri içerebilir ve içeriği biz denetlemiyoruz (yalnız tür/imza doğrulanır); bu sorumluluk Koşullar 7.5'te akademisyene bırakıldığı gibi kalabilir mi?
18. **Ayrılmış cihaz sütunu.** `ac_attendance.device_hash` ayrılmış ama kullanılmıyor; metin "cihaz kimliği kullanılmaz" der; ileride kullanılırsa bu metin ve onay yenilenmelidir, bu taahhüt yeterli mi?

Ürün/doğruluk notları (hukuki soru değil): kodda "mazeret/excused" durumu yoktur (var/yok/kaldırıldı), metinde de yazılmadı; öğrenci numarası e-posta yerel kısmından türetilir ve yalnız `bingol.edu.tr` adresinde, numara biçimindeyse vardır; rehber yalnız ACTIVE + e-postası doğrulanmış + profili tamam + USER rolü + akademisyen olmayan hesapları listeler; rehber arama 60/dk ve 500/gün sınırlıdır; bağsız duyuru dosyaları 24 saat sonra bir sonraki yüklemede temizlenir (zamanlayıcı yok).

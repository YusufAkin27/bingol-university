# Yönetici / Moderatör Mesaj Erişimi Politikası (İç Belge)

Kapsam: sohbet mesajları, ekleri ve tek gönderimlik görsellerin yönetici panelinden görüntülenmesi (`/api/admin/users/{id}/conversations…`, `/api/admin/media/attachments/{id}/preview`, şikâyet bağlamı, sohbet izleme akışı). Dayanak: KVKK m.12 (veri güvenliği), meşru menfaat dengesi, kullanıcıya yapılan açık bilgilendirme (Gizlilik Politikası bölüm 3).

## 1. İlke

Mesajlar kullanıcıların özel yazışmalarıdır. Sistem uçtan uca şifreli **değildir**; teknik olarak yönetici çözebilir. Bu nedenle erişim **ihtiyaç ilkesi**, **en az yetki** ve **denetlenebilirlik** ile sınırlıdır. Kullanıcılara bu erişimin varlığı ve koşulları bildirilmiştir; bildirimin ötesine geçen erişim yasaktır.

## 2. Kim erişebilir?

- Yalnızca `ROLE_ADMIN` (JWT ile; Basic auth çalışmaz, kimlik kayda yazılır). Kişi sayısı asgari tutulur ve yazılı olarak listelenir.
- Erişim yetkisi **yazılı atama** ile verilir; her yönetici bu politikayı ve çalışan taahhütnamesini (07) imzalar.
- Yönetici kendi sohbetlerini veya yakınlarının sohbetlerini görüntüleyemez; çıkar çatışması halinde başka yönetici görevlendirilir.

## 3. Ne zaman erişilebilir? (izinli gerekçeler)

| Gerekçe | Örnek | Dayanak belge |
|---|---|---|
| Kullanıcı şikâyeti/raporu incelemesi | Mesaj raporu, taciz, tehdit | Rapor kaydı no |
| Güvenlik / kötüye kullanım şüphesi | Spam ağı, dolandırıcılık, ban dolanma | Olay kaydı |
| Yetkili makam talebi | Mahkeme/savcılık yazısı | Resmi yazı, hukuk onayı |
| Kullanıcının kendi talebi | Kullanıcı kendi sohbetinin incelenmesini ister | Destek talebi no |
| Teknik hata incelemesi | Şifre çözme/tutarsızlık | Arıza kaydı (içerik gösterimi asgari) |

**Yasak:** merak, kişisel ilgi, performans izleme, ilgisiz kişileri izleme, içerik sızdırma, kopyalama/ekran görüntüsü alma (yasal gereklilik dışında).

## 4. Nasıl erişilir?

1. Önce rapor bağlamı (`GET /api/admin/reports/{id}` → `context`) kullanılır; yeterliyse tüm sohbet açılmaz.
2. Tüm sohbet izleme yalnızca gerekçe kaydı (rapor/olay/yazı no) belirlenmişse yapılır. **Kodda serbest metin gerekçe alanı yoktur** (sistem sabit gerekçe yazar); bu nedenle gerekçe, panel dışında **erişim defterine** (aşağıda) yazılır: tarih, yönetici, hedef kullanıcı, gerekçe türü, dayanak no.
3. Yalnızca olayla ilgili konuşma ve aralık incelenir. Başka kullanıcıların alakasız mesajları okunmaz.
4. Tek gönderimlik görseller yalnızca raporlandığında veya yetkili makam talebinde açılır.

## 5. Denetim

- Her görüntüleme `message_access_audit` tablosuna içerik gösterilmeden önce yazılır (yönetici, hedef kullanıcı, konuşma, mesaj sayısı, aralık, IP, zaman). Tablo yalnızca-eklemedir (DB tetikleyicisi UPDATE/DELETE/TRUNCATE'i reddeder). Kayıt yazılamazsa içerik dönmez.
- Panel işlemleri ayrıca `admin_audit`'e yazılır.
- **Aylık gözden geçirme:** veri sorumlusu temsilcisi (veya bağımsız bir yönetici) denetim kayıtlarını erişim defteriyle karşılaştırır; gerekçesiz erişim ihlal soruşturması başlatır (disiplin + gerekirse 03 numaralı ihlal planı).
- Kayıtlar dış arşive düzenli aktarılır; tabloya `ALTER/DROP TRIGGER` yetkisi uygulama DB kullanıcısında olmamalıdır (`docs/ENCRYPTION.md` bölüm 4).

## 6. Gizlilik taahhüdü ve eğitim

Her yönetici/moderatör erişim öncesi gizlilik taahhütnamesi imzalar (07). Yılda bir KVKK ve bu politika eğitimi verilir. Görüntülenen içerik üçüncü kişilerle paylaşılmaz; hukuki gereklilik olmadıkça dışa aktarılmaz.

## 7. Çıkış (işten ayrılma / görev değişikliği)

Görev bitiminde aynı gün: rol düşürülür (`rolechg` ile eski token reddedilir), oturumlar kapatılır, panel erişimi ve paylaşılan sırlar iptal edilir, cihaz/hesap erişimleri kontrol edilir. Gizlilik yükümlülüğü görev bitiminden sonra da sürer. Son yönetici korunur (sistem son yöneticiyi düşürmeye izin vermez).

## 8. Kullanıcı talebi ve şeffaflık

Kullanıcı "mesajlarıma bakıldı mı?" diye sorarsa 02 numaralı prosedür izlenir. Mesaj içeriği hakkında yönetici erişimi olduğu bilgisi Gizlilik Politikası'nda yer alır.

## 9. Erişim defteri şablonu

| Tarih/saat | Yönetici | Hedef kullanıcı | Gerekçe türü | Dayanak no | Kapsam (sohbet/aralık) | Sonuç |
|---|---|---|---|---|---|---|

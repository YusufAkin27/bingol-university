# Veri İhlali Müdahale Planı (İç Belge)

Dayanak: KVKK m.12/5; Kurul'un 24/01/2019 tarih ve 2019/10 sayılı "Kişisel Veri İhlali Bildirimi" kararı: veri sorumlusu ihlali öğrendiği andan itibaren **en geç 72 saat içinde Kurul'a**, ilgili kişilere ise **makul olan en kısa sürede** bildirir.

## 1. Tanım

Kişisel verilerin hukuka aykırı biçimde ele geçirilmesi, ifşa edilmesi, değiştirilmesi, kaybolması veya yetkisiz erişilmesi. Örnekler: veritabanı/yedek sızıntısı, şifreleme ana anahtarının sızması, yönetici hesabı ele geçirilmesi, yetkisiz mesaj görüntüleme, yanlış alıcıya toplu e-posta/bildirim, FCM kimlik dosyası sızıntısı.

## 2. Ekip

| Rol | Görev |
|---|---|
| Olay yöneticisi (teknik sorumlu) | Tespit, sınırlama, kanıt, kayıt |
| Veri sorumlusu temsilcisi | Karar, Kurul ve kullanıcı bildirimi onayı |
| Hukuk danışmanı | Bildirim metni, yasal değerlendirme |
| İletişim sorumlusu | Kullanıcı duyurusu, Destek yanıtları |

## 3. Zaman çizelgesi

| Süre | Eylem |
|---|---|
| T0 | İhlal öğrenildi (zaman damgası kaydedilir; 72 saat buradan başlar) |
| T0 + 1 sa | Olay yöneticisi atanır; sınırlama başlar |
| T0 + 24 sa | Kapsam ilk değerlendirmesi (hangi veri, kaç kişi, risk) |
| T0 + 48 sa | Bildirim taslağı hukuk onayında |
| **T0 + 72 sa** | **Kurul'a bildirim** (eksik bilgi sonradan aşamalı tamamlanabilir) |
| Makul en kısa süre | İlgili kişilere bildirim (e-posta + uygulama içi duyuru) |

## 4. Sınırlama ve ilk müdahale (teknik kontrol listesi)

1. Etkilenen hesap/anahtarı hemen iptal et: yönetici hesabı için şifre sıfırla + `logout-all`, rol düşür; kullanıcılar için oturumları kapat (`SessionService.revokeAll`).
2. JWT sırrı sızdıysa `JWT_SECRET` değiştir (tüm oturumlar düşer); FCM kimliği sızdıysa Firebase'de anahtarı iptal et ve yenisini yükle; SMTP şifresi sızdıysa değiştir.
3. Şifreleme ana anahtarı sızdıysa: yeni anahtar üret, `crypto-rotate.sh` + `rewrap`; mesajların yeniden şifrelenmesi gerekebilir (`docs/ENCRYPTION.md` bölüm 5).
4. `message_access_audit` ve `admin_audit` kayıtlarını dondur/kopyala (delil); erişim günlüklerini (nginx, uygulama) sakla.
5. Etkilenen sistemi ağdan ayır / bakım modunu aç (`maintenance_mode`).
6. Kök neden analizi; yamayı üretime al.

## 5. Risk değerlendirmesi

Ölçütler: veri türü (kimlik/iletişim/mesaj içeriği/özel nitelikli), kişi sayısı, şifreleme durumu (sızan veri şifreli mi, anahtar sızdı mı), kötüye kullanım ihtimali, sonuçların ağırlığı. Düşük riskli (ör. yalnızca şifreli ve anahtarı güvende veri) olaylar da **kayıt altına alınır**; Kurul'a bildirim gerekliliği hukuk danışmanıyla değerlendirilir.

## 6. Kurul'a bildirim içeriği

İhlalin ne zaman ve nasıl olduğu; etkilenen kişi/kayıt sayısı ve veri kategorileri; olası sonuçlar; alınan ve alınacak önlemler; ilgili kişilere nasıl bildirileceği; iletişim noktası. Kurul'un ihlal bildirim formu kullanılır (VERBİS/Kurul web sitesi).

## 7. İlgili kişilere bildirim

Açık ve sade Türkçe: ne oldu, hangi verileriniz etkilendi, olası sonuçlar, aldığımız önlemler, sizin alabileceğiniz önlemler (şifre değiştirme, şüpheli e-postalara dikkat), iletişim. Kanal: kayıtlı e-posta ve uygulama içi duyuru/banner.

## 8. İhlal kayıt defteri

Her ihlal için: olay no, T0, keşfeden, kapsam, kategoriler, kişi sayısı, risk, bildirim kararı/tarihleri, önlemler, kök neden, kapanış. Defter, Kurul talebinde sunulmak üzere 3 yıl saklanır.

## 9. Tatbikat

Yılda bir masa başı tatbikat; yönetici hesabı ele geçirilmesi ve anahtar sızıntısı senaryoları.

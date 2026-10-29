# Google Play mağaza metni: Türkçe (tr-TR, varsayılan dil)

Sınırlar (Play Console): başlık ≤ 30, kısa açıklama ≤ 80, uzun açıklama ≤ 4000 karakter. Mevcut uzunluklar: başlık 9, kısa 73, uzun ~2650; metni değiştirirseniz alanı yeniden sayın.

> Marka/itibar kuralı: üniversitenin adı ve logosu **başlıkta, simgede ve görsellerde kullanılmaz**; yalnızca açıklamada, "bu uygulamanın ilgili olduğu kurum" anlamında ve **resmî olmadığı** belirtilerek anılır (Play "Taklit/yanıltıcı davranış" politikası). Yönetim tarafı: [LEGAL_NOTES.md](../LEGAL_NOTES.md) madde 1.

## Başlık (≤ 30)

```
BÜ Kampüs
```

## Kısa açıklama (≤ 80)

```
Kampüste haber, yemek, kulüp ve sohbet. Resmî olmayan, bağımsız uygulama.
```

## Uzun açıklama (≤ 4000)

```
BÜ Kampüs, Bingöl Üniversitesi öğrencileri ve personeli için geliştirilmiş BAĞIMSIZ ve RESMÎ OLMAYAN bir kampüs uygulamasıdır. Kişisel bir projedir; Bingöl Üniversitesi ile hiçbir kurumsal bağlantısı, ortaklığı veya onayı yoktur. Üniversitenin adı ve markası ilgili kurumun mülkiyetindedir.

NELER YAPABİLİRSİNİZ?

• Haber, duyuru ve etkinlikler: Üniversitenin herkese açık haber ve duyuru sayfalarındaki içerikleri tek yerde, hızlı ve okunaklı biçimde takip edin. Haberleri favorilerinize kaydedin.
• Yemek listesi: Günün ve ayın yemek listesi cebinizde.
• Keşfet: Bir fotoğraf ve kısa bir notla gönderi paylaşın, arkadaşlarınızın ve bölümünüzün paylaşımlarını beğenin, kişileri takip edin.
• Sohbet: Birebir ve grup sohbetleri, gerçek zamanlı mesajlaşma, fotoğraf gönderme, yanıtlama, tepki verme, sessize alma. Mesajlar sunucuda şifreli saklanır.
• Kulüpler ve etkinlikler: Öğrenci topluluklarını keşfedin, katılın, kulüp ve etkinlik sohbetlerine girin; etkinliklere katılım bildirin, QR kod ile yoklamanızı verin.
• Anketler: Kampüsle ilgili anketlere gizli oyla katılın.
• Arama: Haber, kullanıcı, kulüp ve etkinliklerde arama yapın.
• Bildirimler: Mesajlar, etkinlik hatırlatmaları ve duyurular için bildirim tercihlerinizi siz belirleyin.
• Destek ve güvenlik: Uygunsuz içerik ve kullanıcıları bildirin, kullanıcıları engelleyin; destek talebi gönderin.
• Üç dil, iki tema: Türkçe, İngilizce ve Arapça (sağdan sola düzen desteğiyle); açık ve koyu tema.

KİMLER KULLANABİLİR?

Kayıt yalnızca üniversite e-posta adresi (bingol.edu.tr) ile ve e-posta doğrulamasıyla yapılır. Hizmet üniversite öğrencileri ve personeline yöneliktir; 18 yaşından küçük kullanıcılar yalnızca yasal temsilcilerinin bilgisi ve izniyle kullanabilir (Kullanım Koşulları madde 4).

GİZLİLİK VE VERİLERİNİZ

• Hesabınızı uygulamanın içinden istediğiniz zaman silebilirsiniz; silme, hesabın anonimleştirilmesidir.
• Verilerinizi indirebilirsiniz (KVKK kapsamında "verilerimi indir").
• Konum bilgisi toplanmaz. Rehberiniz yalnızca siz izin verirseniz ve yalnızca e-posta özetleri (hash) ile arkadaş bulmak için kullanılır; ham rehber sunucuya gönderilmez.
• Reklam yoktur, verileriniz üçüncü taraflara satılmaz veya reklam amacıyla paylaşılmaz.
• Gizlilik politikası ve hesap silme bilgisi: https://bukampus.net/tr/privacy ve https://bukampus.net/tr/delete-account

ÖNEMLİ NOT

Bu uygulamadaki haber, duyuru ve yemek listesi içerikleri üniversitenin herkese açık web sitelerinden alınır; doğruluğu ve güncelliği için kaynak siteyi esas alın. Uygulama bir kamu hizmeti veya resmî bilgilendirme kanalı değildir.

Sorularınız için: uygulamadaki Destek bölümü veya <DESTEK_E_POSTASI>
```

## Diğer alanlar

| Alan | Değer |
|---|---|
| Uygulama adı (cihazdaki) | `BÜ Kampüs` (`android/app/src/main/res/values/strings.xml`) |
| Kategori | Sosyal (ya da Eğitim; Sosyal önerilir: sohbet/akış çekirdek özellik) |
| Etiketler | Sosyal, Eğitim, Mesajlaşma |
| Yeni sürüm notları (tr, ≤ 500) | `İlk sürüm: haber, yemek listesi, keşfet, sohbet, kulüpler, etkinlikler, QR yoklama, anketler, bildirimler. Resmî olmayan bağımsız bir uygulamadır.` |
| İletişim e-postası (herkese görünür) | `<DESTEK_E_POSTASI>` (örn. `destek@bukampus.net`, Cloudflare yönlendirmesi: [MAIL_DELIVERABILITY.md](../MAIL_DELIVERABILITY.md) 9.5) |
| Web sitesi | `https://bukampus.net` |
| Gizlilik politikası URL'si | `https://bukampus.net/tr/privacy` (3 dilde sayfa var: `/tr`, `/en`, `/ar` önekli) |
| Hesap silme URL'si | `https://bukampus.net/tr/delete-account` (veri silme talebi formu: `https://bukampus.net/tr/data-request`) |

`<DESTEK_E_POSTASI>` ve alan adı, [LAUNCH_CHECKLIST.md](../LAUNCH_CHECKLIST.md) tamamlanınca doldurulur. Geliştirici (kişi) adı ve adresi Play'de görünür; kişisel adres gizliliği için [LEGAL_NOTES.md](../LEGAL_NOTES.md) "Gizlilik uyarısı" bölümüne bakın (Play, kişisel geliştirici hesabında adresi herkese açık gösterir).

# App Store metni: Türkçe (tr, birincil dil)

Sınırlar (App Store Connect): ad ≤ 30, alt başlık ≤ 30, tanıtım metni ≤ 170, anahtar kelimeler ≤ 100 (virgülle, boşluksuz tercih edilir), açıklama ≤ 4000, Yenilikler ≤ 4000. Uzunluklar `python -I -X utf8 scripts/ios/check-store-lengths.py` ile denetlenir. Üniversite adı/logosu ad, simge ve görsellerde kullanılmaz; açıklamada "bu uygulamanın ilgili olduğu kurum" anlamında ve **resmî olmadığı** belirtilerek geçer ([../store/README.md](../store/README.md) değişmez ilkeler, [../IOS_RELEASE.md](../IOS_RELEASE.md) K3).

## Uygulama adı (≤ 30)

```
BÜ Kampüs
```

## Alt başlık (≤ 30)

```
Bağımsız kampüs uygulaması
```

## Tanıtım metni (≤ 170, sürüm göndermeden değiştirilebilir)

```
Haber, duyuru, yemek listesi, kulüpler, etkinlikler ve sohbet tek uygulamada. Bağımsız ve resmî olmayan bir öğrenci uygulamasıdır.
```

## Anahtar kelimeler (≤ 100)

```
kampüs,üniversite,yemek listesi,kulüp,etkinlik,sohbet,haber,duyuru,öğrenci,bingöl,qr yoklama,anket
```

## Açıklama (≤ 4000)

```
BÜ Kampüs, Bingöl Üniversitesi öğrencileri ve personeli için geliştirilmiş BAĞIMSIZ ve RESMÎ OLMAYAN bir kampüs uygulamasıdır. Kişisel bir projedir; Bingöl Üniversitesi ile hiçbir kurumsal bağlantısı, ortaklığı veya onayı yoktur. Üniversitenin adı ve markası ilgili kurumun mülkiyetindedir.

NELER YAPABİLİRSİNİZ?

• Haber, duyuru ve etkinlikler: Üniversitenin herkese açık haber ve duyuru sayfalarındaki içerikleri tek yerde, hızlı ve okunaklı biçimde takip edin. Haberleri favorilerinize kaydedin.
• Yemek listesi: Günün ve ayın yemek listesi cebinizde.
• Keşfet: Bir fotoğraf ve kısa bir notla gönderi paylaşın, arkadaşlarınızın ve bölümünüzün paylaşımlarını beğenin, kişileri takip edin.
• Sohbet: Birebir ve grup sohbetleri, gerçek zamanlı mesajlaşma, fotoğraf ve video gönderme, yanıtlama, tepki verme, sessize alma. Mesajlar sunucuda şifreli saklanır.
• Kulüpler ve etkinlikler: Öğrenci topluluklarını keşfedin, katılın, kulüp ve etkinlik sohbetlerine girin; etkinliklere katılım bildirin, QR kod ile yoklamanızı verin.
• Anketler: Kampüsle ilgili anketlere gizli oyla katılın.
• Akademik: Ders programınızı ve sınav takviminizi görün, ders ve sınav hatırlatmaları alın.
• Arama: Haber, kullanıcı, kulüp ve etkinliklerde arama yapın.
• Bildirimler: Mesajlar, etkinlik hatırlatmaları ve duyurular için bildirim tercihlerinizi siz belirleyin.
• Destek ve güvenlik: Uygunsuz içerik ve kullanıcıları bildirin, kullanıcıları engelleyin; destek talebi gönderin.
• Üç dil, iki tema: Türkçe, İngilizce ve Arapça (sağdan sola düzen desteğiyle); açık ve koyu tema.

KİMLER KULLANABİLİR?

Kayıt yalnızca üniversite e-posta adresi (bingol.edu.tr) ile ve e-posta doğrulamasıyla yapılır. Hizmet üniversite öğrencileri ve personeline yöneliktir; 18 yaşından küçük kullanıcılar yalnızca yasal temsilcilerinin bilgisi ve izniyle kullanabilir (Kullanım Koşulları madde 4).

GİZLİLİK VE VERİLERİNİZ

• Hesabınızı uygulamanın içinden istediğiniz zaman silebilirsiniz; silme, hesabın anonimleştirilmesidir.
• Verilerinizi indirebilirsiniz (KVKK kapsamında "verilerimi indir").
• Konum bilgisi toplanmaz. Rehberiniz yalnızca siz izin verirseniz ve yalnızca e-posta özetleri (hash) ile arkadaş bulmak için kullanılır; adlar, numaralar ve ham e-posta adresleri sunucuya gönderilmez.
• Reklam ve izleme yoktur, verileriniz üçüncü taraflara satılmaz veya reklam amacıyla paylaşılmaz.
• Gizlilik politikası ve hesap silme bilgisi: https://bukampus.com.tr/tr/privacy ve https://bukampus.com.tr/tr/delete-account

ÖNEMLİ NOT

Bu uygulamadaki haber, duyuru ve yemek listesi içerikleri üniversitenin herkese açık web sitelerinden alınır; doğruluğu ve güncelliği için kaynak siteyi esas alın. Uygulama bir kamu hizmeti veya resmî bilgilendirme kanalı değildir.

Sorularınız için: uygulamadaki Destek bölümü veya ysufakin23@gmail.com
```

## Yenilikler (≤ 4000)

```
İlk sürüm: haber, yemek listesi, keşfet, sohbet, kulüpler, etkinlikler, QR yoklama, anketler, ders ve sınav hatırlatmaları, bildirimler. Resmî olmayan, bağımsız bir uygulamadır.
```

## Diğer alanlar

| Alan | Değer |
|---|---|
| Birincil kategori / ikincil | Sosyal Ağ / Eğitim |
| Destek URL'i (zorunlu) | `https://bukampus.com.tr/tr/contact` |
| Pazarlama URL'i | `https://bukampus.com.tr` |
| Gizlilik politikası URL'i (zorunlu) | `https://bukampus.com.tr/tr/privacy` |
| Hesap silme (inceleme notunda) | `https://bukampus.com.tr/tr/delete-account` |
| Telif | `2026 <adınız>` (KULLANICIDAN) |
| İletişim e-postası | `ysufakin23@gmail.com` (Play ile aynı destek adresi) |

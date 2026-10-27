# Yurt Dışına Aktarım Değerlendirmesi (İç Belge)

Dayanak: KVKK m.9 (7499 sayılı Kanunla değişik hâli) ve "Kişisel Verilerin Yurt Dışına Aktarılmasına İlişkin Usul ve Esaslar Hakkında Yönetmelik". **Güncel mevzuat ve Kurul kararları hukuk danışmanıyla yayın öncesi doğrulanmalıdır.**

## 1. Aktarım envanteri

| Alıcı | Ülke/konum | Aktarılan veri | Amaç | Rol |
|---|---|---|---|---|
| Google LLC (Firebase Cloud Messaging) | ABD / Google küresel altyapı | FCM cihaz token'ı, bildirim başlığı/kısa metni, `targetType`/`targetId`, platform | Android ve (APNs köprüsüyle) iOS anlık bildirim | Veri işleyen / bağımsız altyapı sağlayıcısı |
| Apple Inc. (APNs) | ABD | Cihaz token'ı (APNs), bildirim yükü | iOS anlık bildirim | Altyapı sağlayıcısı |
| Barındırma ({{hosting.location}}) | **Doldurulacak** | Tüm hizmet verisi | Barındırma | Veri işleyen |
| SMTP sağlayıcısı | **Doldurulacak** | Alıcı e-posta, e-posta içeriği | Doğrulama/şifre sıfırlama | Veri işleyen |

(Barındırma ve SMTP yurt içindeyse bu satırlar aktarım değildir.) Mesaj metni push yüküne varsayılan olarak **konmaz** (`app.push.message-preview=false`); ayar açılırsa mesaj önizlemesi yurt dışına gider ve bu değerlendirme güncellenmelidir.

## 2. Mekanizma seçenekleri (m.9 sırası)

1. **Yeterlilik kararı:** Kurul tarafından ülke/sektör için yeterlilik kararı varsa aktarım serbesttir. (Karar durumu yayın öncesi kontrol edilir.)
2. **Uygun güvenceler:** standart sözleşme (Kurul'un yayımladığı örnek metin), bağlayıcı şirket kuralları, taahhütname vb. Standart sözleşme **imzadan itibaren 5 iş günü içinde Kurum'a bildirilir**; bildirilmezse idari para cezası riski vardır.
3. **Arızi aktarım / açık rıza:** m.9'a göre açık rıza yalnızca arızi nitelikteki aktarımlarda başvurulabilecek bir araçtır; sürekli ve düzenli push aktarımı için rıza **tek başına dayanak yapılmamalı**, yukarıdaki güvencelerle desteklenmelidir.

## 3. Mevcut durum ve öneri

- Kullanıcıya sunulan metinlerde (KVKK Aydınlatma, Açık Rıza Madde 3) aktarım, "bildirim iznine dayanan açık rıza ve/veya uygun güvence mekanizmaları" olarak anlatılmıştır.
- **Yapılacaklar (LEGAL_CHECKLIST'e bağlı):** (a) Google/Apple ile ilgili standart sözleşme imzalama yolunun (Google Cloud/Firebase veri işleme şartları ve Kurul standart sözleşmesi) hukuk danışmanıyla belirlenmesi; (b) imza varsa 5 iş günü içinde Kurum bildirimi; (c) aktarım kaydının tutulması; (d) Aydınlatma metninde dayanağın kesinleştirilmesi; (e) iOS push (APNs) ücretli Apple hesabı beklediği için iOS ile ilgili dayanak, yayın öncesi netleştirilir.
- Bildirim yükü asgari tutulur: yalnızca başlık/kısa metin; kişisel veri taşıyan serbest metin eklenmez; mesaj önizlemesi kapalıdır.
- FCM token'ı kullanıcı çıkışında/hesap silmede/60 günde silinir; Google tarafında token ömrü Google ilkelerine tabidir.

## 4. Kayıt

Aktarım kaydı tutulur: alıcı, tarih, mekanizma, bildirim tarihi, sorumlu. VERBİS kaydında "yurt dışına aktarılan alıcı grubu" bölümü bununla uyumlu doldurulur (06).

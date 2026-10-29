# Alan adı tutarlılığı: yasal metinler için yapılacaklar

Karar (2026-10-29): site **`bukampus.com.tr`**, e-posta gönderen alan adı **`bukampus.online`** (`noreply@bukampus.online`), destek adresi **`ysufakin23@gmail.com`**. Eski taslak alan adı `bukampus.net` kod, yapılandırma, belge ve mağaza metinlerinde güncellendi (RL1b/REL1b paketi, commit mesajına bakın). Yasal metinler ve uygulanmış migration'lar bu pakette **değiştirilmedi**; bu dosya o kısımların envanteridir.

## 1. Yasal metinlerde (migration + `docs/legal/`) kalan `bukampus.net`

Tarama: `grep -rIn "bukampus" backend/src/main/resources/db/migration docs/legal` -> **eşleşme yok**. Yasal metinler site ya da gönderen alan adını doğrudan yazmaz; iletişim bilgilerini çalışma zamanında `app_setting` anahtarlarından doldurur:

| Yer | Ne yazıyor | Durum |
|---|---|---|
| `V820__legal_terms_v4.sql` (Kullanım Koşulları tr/en/ar, satırlar yaklaşık 19-171, 178-324 ve Arapça bölümü) | `{{controller.name}}`, `{{support.email\|uygulama içi Destek bölümü}}`, `{{controller.email}}`, `{{controller.kep}}`, `{{controller.address}}` yer tutucuları; sabit alan adı yok | Değişiklik gerekmez |
| `V820` içinde `@bingol.edu.tr` (satır 625, 768, 911) | Üyelik için üniversite e-posta alan adı | Doğru (kayıt kısıtı), dokunulmaz |
| `V481__legal_controller_settings.sql` (satır 10-11) | `legal.controller.email` ve `support_email` = `ysufakin23@gmail.com` | Zaten kararla uyumlu |
| `docs/legal/privacy_*.md` (satır 136/138) | yalnız `@bingol.edu.tr` | Değişiklik gerekmez |

Sonuç: **yeni sözleşme sürümü (migration) gerektiren bir `bukampus.net` kalıntısı bulunamadı.** Metinlerde site adresi ya da gönderen alan adı geçmesi istenirse (ör. "Hizmetin web sitesi: bukampus.com.tr", "bildirimler noreply@bukampus.online adresinden gelir") bu bir metin değişikliğidir ve [LEGAL_NOTES.md](LEGAL_NOTES.md) bölüm 9'daki yeni sürüm yolunu (V620 deseni, `scripts/build-legal-migration-v620.js`) izler; V480/V820 değiştirilmez.

## 2. Yasal metinleri etkileyen çalışma zamanı ayarları (yönetici panelinden, migration değil)

Canlıya çıkmadan önce panelde (Ayarlar) şu `app_setting` değerleri kontrol edilmelidir; metinlerdeki yer tutucular bunlardan dolar:

- `website`: V5 varsayılanı `https://www.bingol.edu.tr` (üniversitenin sitesi). Uygulamanın kendi sitesi `https://bukampus.com.tr` ise bu alan bilinçli seçilmelidir (uygulama bilgisi ekranında "web sitesi" olarak görünür); karar sizindir.
- `support_email`, `legal.controller.email`: `ysufakin23@gmail.com` (V481 yazar).
- `legal.controller.name`, `legal.controller.address`, `legal.controller.kep`, `legal.controller.jurisdiction`: veri sorumlusu bilgileri, gerçek değerlerle doldurulmalıdır ([LEGAL_NOTES.md](LEGAL_NOTES.md)).

## 3. Bilerek değiştirilmeyen diğer `bukampus.net` geçişi

- `docs/SECURITY_AUDIT_2026-10-28.md` satır 136: tarihli denetim raporunun alıntısı (o gün geçerli taslak adres); tarihsel kayıt olarak bırakıldı.
- `_design_tmp/` (tasarım taslağı; kod/belge değil) ve gitignored yerel dosyalar (`.env`, `.deploy.env`) bu pakette taranmadı/değiştirilmedi; yerel `.env`'nizde `MAIL_FROM`, `MAIL_REPLY_TO`, `PUBLIC_WEB_URL`, `DOMAIN` değerlerini [LAUNCH_CHECKLIST.md](LAUNCH_CHECKLIST.md) Aşama 2 sırasıyla güncelleyin.

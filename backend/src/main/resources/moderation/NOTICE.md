# Uygunsuz ifade listeleri - kaynak ve lisans

`profanity-tr.txt`, `profanity-en.txt` ve `profanity-ar.txt` dosyalarındaki "GENERATED" blokları şu açık veri setinden türetilmiştir:

- **LDNOOBW - List of Dirty, Naughty, Obscene, and Otherwise Bad Words**
  https://github.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words
- Lisans: **Creative Commons Attribution 4.0 (CC-BY-4.0)** - https://creativecommons.org/licenses/by/4.0/
- Değişiklikler: çok kısa (3 harften az), rakam/simge içeren, klinik veya masum anlamlı (yanlış pozitif riski yüksek) girişler ayıklandı; tekrarlar kaldırıldı; tekli sözcükler "tam eşleşme" olarak işaretlendi.
- Blok `scripts/fetch-profanity-lists.js` ile üretilir (tek seferlik indirme; çalışma zamanında ağ çağrısı yoktur).

Blok dışındaki girişler (kök listesi, `profanity-allow-tr.txt` izin listesi) proje ekibi tarafından yazılmıştır.
Listeler yalnızca içerik moderasyonu için kullanılır; yönetici panelinden (Uygunsuz ifade filtresi) ek BLOCK/ALLOW kaydı eklenebilir.

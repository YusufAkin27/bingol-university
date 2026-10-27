# Güvenlik politikası

## Güvenlik açığı bildirimi

Bir güvenlik açığı bulduysanız **herkese açık issue açmayın**.

1. GitHub deposunda **Security → Report a vulnerability** (özel güvenlik danışmanlığı) ile bildirin; ya da
2. proje sahiplerine kurumsal e-posta ile yazın (adres depo sahibinden istenir; bu dosyaya gerçek adres eklenmelidir: `<GUVENLIK_E_POSTASI>`).

Bildirimde şunları belirtin: etkilenen bileşen (backend / web / mobil), yeniden üretim adımları, olası etki. Gerçek kullanıcı verisine erişmeyin, hizmeti aksatacak yük göndermeyin.

## Süreç

- 3 iş günü içinde alındı bilgisi, 10 iş günü içinde ilk değerlendirme hedeflenir.
- Düzeltme yayımlanana kadar ayrıntıları paylaşmamanızı rica ederiz; sonrasında teşekkür (isterseniz) belirtilir.

## Kapsam

Depodaki backend (Spring Boot), web (yönetici paneli + tanıtım sitesi) ve mobil uygulama. Üçüncü taraf hizmetlerin (Firebase, SMTP sağlayıcısı) kendi açıkları kendi programlarına bildirilmelidir.

## Desteklenen sürümler

Yalnızca `main` dalındaki en güncel sürüm.

## Depodaki otomatik denetimler

CodeQL, bağımlılık incelemesi, Dependabot, gitleaks (sır taraması), OWASP ZAP baseline (staging). Ayrıntı: [docs/CI_CD.md](docs/CI_CD.md).

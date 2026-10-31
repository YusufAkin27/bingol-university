# Mağaza paketi (Apple App Store / TestFlight)

Bu klasör App Store Connect'e girilecek metin ve cevapları hazır tutar. **Hiçbiri henüz Connect'e girilmedi** (Apple Developer hesabı gerekir). Rehber ve kontrol listesi: [../IOS_RELEASE.md](../IOS_RELEASE.md). Google Play karşılığı: [../store/README.md](../store/README.md). Değişmez ilkeler Play ile aynıdır (resmî olmayan beyanı, üniversite logosu/adı başlıkta yok, form = gizlilik politikası).

| Dosya | İçerik |
|---|---|
| [store_tr.md](store_tr.md) | Türkçe (birincil): ad, alt başlık, tanıtım metni, anahtar kelimeler, açıklama, Yenilikler, URL'ler |
| [store_en.md](store_en.md) | İngilizce karşılığı |
| [store_ar.md](store_ar.md) | Arapça **taslak** (anadil incelemesi yok; ilk sürümde eklemeyin) |
| [APP_PRIVACY.md](APP_PRIVACY.md) | "App Privacy" (Nutrition Label) cevap tablosu, takip yok beyanı, Required Reason API'ler, ihracat uyumluluğu |
| [REVIEW_NOTES.md](REVIEW_NOTES.md) | App Review notu şablonu (demo hesap, UGC, hesap silme, izinler) |
| [SCREENSHOTS.md](SCREENSHOTS.md) | iPhone 6.9" boyutları ve simülatörle üretim |

Uzunluk denetimi: `python -I -X utf8 scripts/ios/check-store-lengths.py` (ad/alt başlık ≤ 30, tanıtım ≤ 170, anahtar kelime ≤ 100, açıklama ≤ 4000). Dosya düzeyi iOS denetimi: `python -I -X utf8 scripts/ios/check-ios-static.py`.

## Doldurulacak yer tutucular (KULLANICIDAN)
- Telif satırı (`2026 <adınız>`), iletişim adı/telefonu (App Review Information, herkese görünmez)
- Demo hesap e-postası/parolası (yalnız Connect'e)
- Destek e-postası: Play ile aynı `ysufakin23@gmail.com` mı, yoksa alan adı adresi mi

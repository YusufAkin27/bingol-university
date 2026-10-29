# Mağaza paketi (Google Play, kapalı test)

Bu klasör Play Console'a girilecek metin ve cevapları hazır tutar. **Hiçbiri henüz Console'a girilmedi** (geliştirici hesabı gerekir). Derleme/imza: [../ANDROID_RELEASE.md](../ANDROID_RELEASE.md); yayın sırası: [../LAUNCH_CHECKLIST.md](../LAUNCH_CHECKLIST.md).

| Dosya | İçerik |
|---|---|
| [store_tr.md](store_tr.md) | Türkçe (varsayılan) başlık (≤30), kısa açıklama (≤80), uzun açıklama, sürüm notu, URL'ler |
| [store_en.md](store_en.md) | İngilizce karşılığı |
| [data_safety.md](data_safety.md) | "Veri güvenliği" formu cevapları, hassas izin ve diğer beyanlar |
| [content_rating.md](content_rating.md) | IARC içerik derecelendirme anketi cevapları, hedef kitle |
| [screenshots.md](screenshots.md) | Görsel listesi, boyutlar, tohum veriyle çekim yönergesi |

## Değişmez ilkeler
1. **Resmî değil.** Her metinde ilk paragrafta: "bağımsız, resmî olmayan, kişisel proje; Bingöl Üniversitesi ile kurumsal bağlantısı/onayı yok". Üniversite adı ve logosu başlıkta, simgede ve görsellerde kullanılmaz (Play taklit politikası; [LEGAL_NOTES.md](../LEGAL_NOTES.md) madde 1).
2. **Form = gizlilik politikası.** Veri güvenliği cevapları [privacy_tr.md](../legal/privacy_tr.md) ile aynı olgulara dayanır; biri değişince ikisi de güncellenir.
3. **Kişisel veri sızdırma.** Metinlere kişisel adres/telefon yazılmaz; iletişim `<DESTEK_E_POSTASI>` (destek adresi: `ysufakin23@gmail.com`). Ekran görüntülerinde yalnız sahte tohum hesaplar.

## Herkese açık sayfalar (Play URL'leri) - kontrol edildi
`web/src/routes.tsx`'te dil önekli (`/tr`, `/en`, `/ar`) rotalar **mevcut** ve 3 dilli içerik taşır; yeni sayfa eklenmedi:

| Play alanı | URL | Kaynak |
|---|---|---|
| Gizlilik politikası | `https://bukampus.com.tr/tr/privacy` (`/en/privacy`, `/ar/privacy`) | `pages/site/LegalPage.tsx` (`fixedType="PRIVACY"`, metin API'den: `docs/legal/privacy_*.md`) |
| Hesap silme | `https://bukampus.com.tr/tr/delete-account` | `pages/site/DeleteAccountPage.tsx` (tablo: hangi veri silinir/saklanır/süre) |
| Veri silme/erişim talebi | `https://bukampus.com.tr/tr/data-request` | `pages/site/DataRequestPage.tsx` |
| Kullanım koşulları | `https://bukampus.com.tr/tr/terms` | `LegalPage` |

`BASE=https://bukampus.com.tr bash scripts/staging-smoke.sh` bu sayfaların 200 döndüğünü denetler. Sayfa içeriği sözleşme metinlerine bağlı olduğundan **yasal metin migration'ına dokunulmadı**.

## Yayın öncesi son kontrol
- [ ] `<DESTEK_E_POSTASI>` ve alan adı gerçek değerlerle dolduruldu; adres çalışıyor (`ysufakin23@gmail.com`; site alan adı `bukampus.com.tr`, e-posta gönderen alan adı `bukampus.online`).
- [ ] Hesap silme ve gizlilik URL'leri canlıda açılıyor (3 dil).
- [ ] Veri güvenliği formu, uygulamadaki izinlerle ([ANDROID_RELEASE.md](../ANDROID_RELEASE.md) bölüm 5) birebir.
- [ ] İnceleyici hesabı (App access) hazır; parola repoya yazılmadı.
- [ ] Görsellerde üniversite logosu/gerçek kişi yok.

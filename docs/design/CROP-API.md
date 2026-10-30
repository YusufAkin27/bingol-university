# Fotoğraf kırpma API'si (`mobile/lib/features/media_crop/`)

Tek giriş: `import '.../media_crop/media_crop.dart';`. Yeni paket yok: kaydır/yakınlaştır `GestureDetector` + `CustomPainter` çerçeve, kesme `package:image` (isolate) ile yapılır; çıktı her zaman **JPEG** baytlarıdır (kalite 88, EXIF yönü uygulanmış, meta veri yok). Sunucuya değişiklik gerekmez (`ImageProcessor` yeniden kodlar).

## Biçimler (`CropSpec`)

| Biçim | Oran | Çıktı üst sınırı (uzun kenar) | Önizleme |
|---|---|---|---|
| `CropSpec.profile({previewName})` | 1:1 | 1024 | üstte "Profilde böyle görünecek": 96 px + 40 px daire (canlı) |
| `CropSpec.post({previewName, previewCaption, allowChange})` | 4:5 (tek sabit biçim) | 1350 | altta "Akışta böyle görünecek" akış kartı (+ "Fotoğrafı değiştir") |
| `CropSpec.logo({previewName})` | 1:1 (daire kılavuzu) | 512 | "Kulüp sayfası" (daire) + "Kulüp kartı" (yuvarlak kare + ad) |
| `CropSpec.cover({previewTitle, previewSubtitle, allowRemove})` | 16:9 | 1280 | etkinlik/kulüp kartı kapağı (+ "Kapağı kaldır") |
| `CropSpec.chat()` | görselin kendi oranı (serbest oran **yok**) | 1600 | yok (yalnız kaydır/yakınlaştır/döndür) |

Kırpılan bölge hedeften küçükse büyütülmez. Filtre, çıkartma, metin, çizim yoktur; yalnız kırp + döndür.

## İşlevler

```dart
// Elinizdeki baytları kırpma sayfasında açar (tam ekran). null = vazgeçildi.
Future<CropOutcome?> cropImage(BuildContext context, Uint8List bytes, CropSpec spec);

// Seç + kırp tek çağrıda. "Fotoğrafı değiştir" seçilirse seçici yeniden açılır. null = iptal.
Future<Uint8List?> pickAndCrop(BuildContext context, CropSpec spec,
    {ImageSource source = ImageSource.gallery, CropPhotoPicker? pick});

// "Fotoğraf" kaynak alt sayfası: Galeriden seç / Fotoğraf çek / (removable) Fotoğrafı kaldır; error verilirse
// altta kırmızı uyarı kartı (örn. "Fotoğraf en fazla 2 MB olabilir...").
Future<PhotoSource?> showPhotoSourceSheet(BuildContext context, {bool removable = false, String? error});
enum PhotoSource { gallery, camera, remove }

class CropOutcome { Uint8List? bytes; bool removed; bool changeRequested; }
```

`pick` yalnız testler içindir (varsayılan `ImageService().pick`, kamera izni dahil).

## Bağlama örnekleri

```dart
// Profil fotoğrafı (K19/yeni profil ajanı): kırp -> mevcut yükleyiciye ver.
final bytes = await pickAndCrop(context, CropSpec.profile(previewName: me.displayName), source: src);
if (bytes != null) { final img = await ImageService().prepare(bytes, avatar: true); /* MultipartUploader ile yükle */ }

// Kulüp logosu (K7): CropSpec.logo(previewName: clubName); kapak (K7/K9): CropSpec.cover(previewTitle: ..., allowRemove: hasCover)
final out = await cropImage(context, pickedBytes, CropSpec.cover(previewTitle: title, previewSubtitle: club, allowRemove: true));
if (out?.removed == true) {/* kapağı sil */} else if (out?.bytes != null) {/* yükle */}
```

Gönderi oluşturma (`ComposePostPage`) kırpmayı kendi içinde bağlar (4:5; `cropPhoto` parametresi testler için enjekte edilir; "Yeniden kırp" özgün seçimi tekrar açar).

## Sohbet görseli notu
Referans 09/5 "Orijinal / Serbest" oran çipleri gösterir; serbest köşe sürükleme **uygulanmadı** (istege bağlı). `CropSpec.chat()` şimdilik yalnız kaydır/yakınlaştır/döndür sunar; çip ve "Tek gönderimlik"/açıklama alanı sohbet medya önizleme sayfasındadır (Paket 10).

## Dosyalar
`crop_spec.dart` (biçimler, `CropOutcome`), `crop_controller.dart` (geometri, test edilebilir), `crop_engine.dart` (isolate'ta döndür + kes + JPEG), `crop_page.dart` (arayüz), `media_crop.dart` (genel API + kaynak sayfası). Testler: `mobile/test/redesign/k4_posts_test.dart`; ekran görüntüleri: `mobile/test/redesign/k4_yeni_shots_test.dart`.

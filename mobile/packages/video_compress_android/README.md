# video_compress (yalnizca Android kopyasi)

Kaynak: `video_compress` 3.1.4 (https://github.com/jonataslaw/VideoCompress, MIT, bkz. `LICENSE`),
pub.dev'den alinmistir.

Yapilan degisiklik: `pubspec.yaml` icinden `ios` ve `macos` platform bolumleri ve `ios/`, `macos/`,
`example/`, `test/` klasorleri kaldirildi; `publish_to: 'none'` eklendi. Kod (android/ ve lib/) degismedi.

Neden: iOS derlemesi Windows'ta `xcross` ile (Xcode'suz) yapiliyor ve yalnizca Swift Package Manager
destekli eklentileri derleyebiliyor; `video_compress` iOS'ta yalniz CocoaPods (podspec) sunuyor.
Paket adi ayni kaldigi icin Dart importlari (`package:video_compress/video_compress.dart`) degismez.
iOS'ta eklenti derlemeye girmez; uygulama tarafi (`lib/core/platform/video_service.dart`) iOS'ta cagri yapmaz.

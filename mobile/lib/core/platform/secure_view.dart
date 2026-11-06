import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Ekran koruması durumu (iOS yerel köprüsü `bu_kampus/secure` döner).
class SecureStatus {
  const SecureStatus(
      {this.secureLayer = false, this.captured = false, this.layerRequested = false, this.secureImage = false});

  /// iOS: fotoğraf, güvenli metin alanının iç kapsayıcısındaki yerel görünümde ([ChatSecureView.secureImage])
  /// gösterilebilir; ekran görüntüsü/kaydında bu görünüm BOŞ çıkar. Pencereye dokunmaz (çökme/kayma riski yok).
  final bool secureImage;

  /// Pencere, "güvenli metin alanı" katmanına taşındı: ekran görüntüsü/kaydında içerik SİYAH çıkar (iOS'ta resmî
  /// olmayan, ama yaygın yöntem; yalnız `layerTrick` açıkken; yerleşemez ya da pencere kayarsa false ve uygulama
  /// normal çalışır). Katman istenmişse ([layerRequested]) tek gösterimlik fotoğraf iOS'ta YALNIZ bu true iken açılır
  /// ([ChatSecureView.allowsViewOnce]).
  final bool secureLayer;

  /// Bu `enable` çağrısında katman hilesi istendi mi (derleme bayrağı `BU_SECURE_LAYER`). İstenmişse katman kurulamazsa
  /// açılış engellenir; istenmemişse katman denenmez ve (operatör kararı) açılışa izin verilir, koruma İDDİA EDİLMEZ.
  final bool layerRequested;

  /// Ekran şu anda kaydediliyor / yansıtılıyor / AirPlay'e gidiyor (`UIScreen.isCaptured`, iOS 17+'da
  /// `sceneCaptureState`).
  final bool captured;
}

/// `layerRevoked`: yerel taraf güvenli katmanı sonradan geri aldı (pencere kaydı); görüntü hemen düşürülmelidir.
enum SecureEventKind { captureStarted, captureEnded, screenshot, layerRevoked }

/// Tek gösterimlik fotoğraf görüntüleyicisi için ekran koruması kanalı sarmalayıcısı.
///
/// Android'de hiçbir şey yapmaz: `MainActivity` release'te pencereye `FLAG_SECURE` koyar (ekran görüntüsü, kayıt ve
/// son uygulamalar önizlemesi zaten engelli). iOS'ta resmî bir "ekran görüntüsünü engelle" API'si YOKTUR; yerel taraf
/// (BuNativeBridge.swift) şunları yapar: (a) güvenli katman, (b) kayıt/yansıtma algılama, (c) ekran görüntüsü
/// algılama (sonradan), (d) uygulama değiştirici önizlemesi için opak örtü. Hata sızdırmaz; kanal yoksa (test,
/// masaüstü, eski yerel kod) koruma sessizce devre dışıdır.
class ChatSecureView {
  ChatSecureView({MethodChannel? channel, bool? isIOS, bool? layerTrick, Widget Function(Uint8List bytes)? imageBuilder})
      : _ch = channel ?? const MethodChannel('bu_kampus/secure'),
        _ios = isIOS ?? (!kIsWeb && Platform.isIOS),
        _layerTrick = layerTrick ?? layerTrickDefault,
        _imageBuilder = imageBuilder;

  final Widget Function(Uint8List bytes)? _imageBuilder;

  /// Ekran görüntüsünde BOŞ çıkan yerel fotoğraf görünümü (iOS PlatformView `bu_kampus/secure_image`): baytlar
  /// yerel tarafa verilir, Flutter bunları ASLA çizmez. Yalnız [SecureStatus.secureImage] true iken kullanılır.
  Widget secureImage(Uint8List bytes) =>
      (_imageBuilder ?? _nativeImage)(bytes);

  /// Ekran görüntüsünde fotoğrafın yerine görünen kapak resmi (siyah ekran yerine); [enable] önceden yükler.
  static Uint8List? _cover;

  static Future<void> _loadCover() async {
    if (_cover != null) return;
    try {
      final d = await rootBundle.load('assets/branding/screenshot_cover.jpg');
      _cover = d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
    } catch (_) {
      // kapak yoksa ekran görüntüsü siyah/boş çıkar; koruma yine geçerli
    }
  }

  static Widget _nativeImage(Uint8List bytes) => UiKitView(
        key: const ValueKey('secureNativeImage'),
        viewType: 'bu_kampus/secure_image',
        creationParams: <String, Object?>{'bytes': bytes, if (_cover != null) 'cover': _cover},
        creationParamsCodec: const StandardMessageCodec(),
      );

  /// Uygulama genelinde paylaşılan örnek; testler [instance] değerini değiştirebilir.
  static ChatSecureView instance = ChatSecureView();

  /// "Güvenli alan katmanı" yöntemi (pencere katmanını `isSecureTextEntry` alanının içine taşıma): iOS'ta ekran
  /// görüntüsü/ekran kaydı bu katmanı SİYAH çizer (tek gönderimlik fotoğrafta ekran görüntüsü boş çıkar).
  ///
  /// VARSAYILAN KAPALI: TestFlight'ta iPhone'da tek gösterimlik fotoğrafta ekran görüntüsü alınınca uygulama çöktü
  /// (neden cihazda doğrulanamadı); iPhone'da kanıtlanana kadar katman denenmez. Açmak için
  /// `--dart-define=BU_SECURE_LAYER=true` ile derle (docs/IOS_RELEASE.md "Katman hilesi doğrulama").
  ///
  /// İki mod (iOS; Android'de bayrak etkisizdir, FLAG_SECURE pencere genelinde):
  /// - BAYRAK AÇIK: katman kurulamazsa/geri alınırsa fotoğraf HİÇ istenmez (sunucuda açma hakkı tüketilmez) ve
  ///   "bu cihazda güvenli açılamıyor" kartı gösterilir; korumasız açılış yoktur.
  /// - BAYRAK KAPALI (varsayılan): katman denenmez; açılışa izin verilir (operatör kararı), arayüz KORUMA İDDİA ETMEZ;
  ///   yedekler çalışır: ekran kaydı sürerken içerik istenmez/örtülür, ekran görüntüsü ALINDIKTAN SONRA algılanırsa
  ///   görüntü hemen düşer + uyarı (engelleyemez), uygulama değiştiricide opak örtü.
  static const bool layerTrickDefault = bool.fromEnvironment('BU_SECURE_LAYER', defaultValue: false);

  final MethodChannel _ch;
  final bool _ios;
  final bool _layerTrick;
  final _events = StreamController<SecureEventKind>.broadcast();
  int _holders = 0;

  /// Yerel taraftan gelen olaylar (kayıt başladı/bitti, ekran görüntüsü alındı).
  Stream<SecureEventKind> get events => _events.stream;

  /// Koruma bu platformda yerel destek arar mı (Android'de false: FLAG_SECURE zaten pencere genelinde).
  bool get supported => _ios;

  /// Tek gösterimlik fotoğraf bu koruma durumunda açılabilir mi? Android: evet (FLAG_SECURE pencere genelinde,
  /// release'te). iOS: katman hilesi İSTENMİŞSE yalnız katman kuruluysa (Apple ekran görüntüsünü engelleyen resmî bir
  /// API vermez; istenen katman yoksa AÇILMAZ); istenmemişse (varsayılan) açılabilir ama [isProtected] false'tur.
  ///
  /// iOS (GÜNCEL): yalnız ekran görüntüsünü gerçekten boş çıkaran bir yol kuruluysa ([SecureStatus.secureImage] ya da
  /// [SecureStatus.secureLayer]) açılır; yoksa (yerel köprü yok, kapsayıcı bulunamadı) fail-closed: fotoğraf istenmez.
  bool allowsViewOnce(SecureStatus st) => !_ios || st.secureImage || st.secureLayer;

  /// Arayüzün "korunmaktadır" diyebilmesi için koruma gerçekten doğrulandı mı (Android: pencere bayrağı; iOS: yerel
  /// güvenli görünüm ya da katman).
  bool isProtected(SecureStatus st) => !_ios || st.secureImage || st.secureLayer;

  /// Korumayı açar; her çağrı bir [disable] ile eşlenmelidir. Dönen durum, yakalama zaten sürüyorsa `captured` olur.
  /// [layerTrick]: güvenli alan katmanı yöntemi (bkz. [layerTrickDefault]); null ise varsayılan.
  Future<SecureStatus> enable({bool? layerTrick}) async {
    if (!_ios) return const SecureStatus();
    _holders++;
    await _loadCover();
    final lt = layerTrick ?? _layerTrick;
    _ch.setMethodCallHandler(_onCall);
    try {
      // Yerel taraf yanıt vermezse görüntüleyici bekletilmesin (koruma devre dışı kalır).
      final r = await _ch.invokeMethod<Object?>('enable', {'layerTrick': lt}).timeout(const Duration(seconds: 3));
      if (r is Map) {
        return SecureStatus(
            secureLayer: r['secureLayer'] == true,
            secureImage: r['secureImage'] == true,
            captured: r['captured'] == true,
            layerRequested: lt);
      }
    } on MissingPluginException {
      // yerel köprü yok: koruma devre dışı
    } on PlatformException {
      // yerleşim başarısız: koruma devre dışı, uygulama çalışır
    } on TimeoutException {
      // yanıt gelmedi: koruma devre dışı
    }
    return SecureStatus(layerRequested: lt);
  }

  /// Korumayı kapatır (son tutan kapatınca yerel taraf eski haline döner).
  Future<void> disable() async {
    if (!_ios || _holders == 0) return;
    _holders--;
    if (_holders > 0) return;
    try {
      await _ch.invokeMethod<Object?>('disable');
    } on MissingPluginException {
      // yerel köprü yok
    } on PlatformException {
      // yoksay
    }
    _ch.setMethodCallHandler(null);
  }

  Future<Object?> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'onCaptured':
        final on = call.arguments is Map ? (call.arguments as Map)['captured'] == true : call.arguments == true;
        _events.add(on ? SecureEventKind.captureStarted : SecureEventKind.captureEnded);
      case 'onScreenshot':
        _events.add(SecureEventKind.screenshot);
      case 'onLayerRevoked':
        _events.add(SecureEventKind.layerRevoked);
    }
    return null;
  }
}

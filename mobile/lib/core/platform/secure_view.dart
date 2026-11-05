import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ekran koruması durumu (iOS yerel köprüsü `bu_kampus/secure` döner).
class SecureStatus {
  const SecureStatus({this.secureLayer = false, this.captured = false});

  /// Pencere, "güvenli metin alanı" katmanına taşındı: ekran görüntüsü/kaydında içerik SİYAH çıkar (iOS'ta resmî
  /// olmayan, ama yaygın yöntem; yalnız `layerTrick` açıkken; yerleşemez ya da pencere kayarsa false ve uygulama
  /// normal çalışır).
  final bool secureLayer;

  /// Ekran şu anda kaydediliyor / yansıtılıyor / AirPlay'e gidiyor (`UIScreen.isCaptured`).
  final bool captured;
}

enum SecureEventKind { captureStarted, captureEnded, screenshot }

/// Tek gösterimlik fotoğraf görüntüleyicisi için ekran koruması kanalı sarmalayıcısı.
///
/// Android'de hiçbir şey yapmaz: `MainActivity` release'te pencereye `FLAG_SECURE` koyar (ekran görüntüsü, kayıt ve
/// son uygulamalar önizlemesi zaten engelli). iOS'ta resmî bir "ekran görüntüsünü engelle" API'si YOKTUR; yerel taraf
/// (BuNativeBridge.swift) şunları yapar: (a) güvenli katman, (b) kayıt/yansıtma algılama, (c) ekran görüntüsü
/// algılama (sonradan), (d) uygulama değiştirici önizlemesi için opak örtü. Hata sızdırmaz; kanal yoksa (test,
/// masaüstü, eski yerel kod) koruma sessizce devre dışıdır.
class ChatSecureView {
  ChatSecureView({MethodChannel? channel, bool? isIOS})
      : _ch = channel ?? const MethodChannel('bu_kampus/secure'),
        _ios = isIOS ?? (!kIsWeb && Platform.isIOS);

  /// Uygulama genelinde paylaşılan örnek; testler [instance] değerini değiştirebilir.
  static ChatSecureView instance = ChatSecureView();

  /// "Güvenli alan katmanı" yöntemi (pencere katmanını `isSecureTextEntry` alanının içine taşıma) varsayılan KAPALI.
  /// Neden: gerçek iPhone'da tek gönderimlik fotoğraf açılınca tüm pencere içeriği SAĞ-ALTA kaydı (yerleşimi bozan
  /// tek yerel yöntem buydu) ve macOS/iPhone olmadan doğrulanamıyor. Kapalıyken yerleşime hiç dokunulmaz; geriye
  /// yakalama algılama (kayıt/yansıtma), ekran görüntüsü algılama + görüntüyü kapatma ve uygulama değiştirici örtüsü
  /// kalır. Cihazda doğrulandıktan sonra `enable(layerTrick: true)` ile açılır.
  static const bool layerTrickDefault = false;

  final MethodChannel _ch;
  final bool _ios;
  final _events = StreamController<SecureEventKind>.broadcast();
  int _holders = 0;

  /// Yerel taraftan gelen olaylar (kayıt başladı/bitti, ekran görüntüsü alındı).
  Stream<SecureEventKind> get events => _events.stream;

  /// Koruma bu platformda yerel destek arar mı (Android'de false: FLAG_SECURE zaten pencere genelinde).
  bool get supported => _ios;

  /// Korumayı açar; her çağrı bir [disable] ile eşlenmelidir. Dönen durum, yakalama zaten sürüyorsa `captured` olur.
  /// [layerTrick]: güvenli alan katmanı yöntemi (bkz. [layerTrickDefault]); null ise varsayılan.
  Future<SecureStatus> enable({bool? layerTrick}) async {
    if (!_ios) return const SecureStatus();
    _holders++;
    _ch.setMethodCallHandler(_onCall);
    try {
      // Yerel taraf yanıt vermezse görüntüleyici bekletilmesin (koruma devre dışı kalır).
      final r = await _ch
          .invokeMethod<Object?>('enable', {'layerTrick': layerTrick ?? layerTrickDefault})
          .timeout(const Duration(seconds: 3));
      if (r is Map) {
        return SecureStatus(secureLayer: r['secureLayer'] == true, captured: r['captured'] == true);
      }
    } on MissingPluginException {
      // yerel köprü yok: koruma devre dışı
    } on PlatformException {
      // yerleşim başarısız: koruma devre dışı, uygulama çalışır
    } on TimeoutException {
      // yanıt gelmedi: koruma devre dışı
    }
    return const SecureStatus();
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
    }
    return null;
  }
}

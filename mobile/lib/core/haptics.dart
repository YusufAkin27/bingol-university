import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dokunsal geri bildirim için ince, tek noktalı sarmalayıcı.
///
/// * `selection`: çip/sekme/anahtar seçimi gibi hafif "tık".
/// * `light`: eşik geçişi (yenile eşiği, sürükle-bırak eşiği, beğeni).
/// * `medium`: onay/silme gibi daha belirgin eylem.
///
/// Sistem titreşimi kapalıysa platform zaten sessiz kalır; uygulama içi kapatma için [enabled].
/// Web'de no-op'tur; platform hatası sessizce yutulur. Testte platform kanalına gider (sahte işleyiciyle sayılabilir,
/// işleyici yoksa zararsızdır).
abstract final class BuHaptics {
  /// Uygulama içi genel anahtar (ileride ayarlara bağlanabilir).
  static bool enabled = true;

  static bool get _active => enabled && !kIsWeb;

  static void selection() => _fire(HapticFeedback.selectionClick);

  static void light() => _fire(HapticFeedback.lightImpact);

  static void medium() => _fire(HapticFeedback.mediumImpact);

  static void _fire(Future<void> Function() call) {
    if (!_active) return;
    try {
      call().catchError((Object _) {});
    } catch (_) {}
  }
}

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// iOS uygulama simgesi rozeti. Sunucu APNs yükünde `badge` olarak okunmamış bildirim sayısını gönderir; ama
/// kullanıcı bildirimleri uygulamada okuyunca yeni push gelmedikçe rozet takılı kalırdı. Bu sınıf, uygulama içi
/// okunmamış bildirim sayacını (`AppBadges.notifications`) yerel `bu_kampus/badge` kanalıyla simgeye yansıtır.
/// Android'de ve kanal yoksa (test/masaüstü) hiçbir şey yapmaz; hata sızdırmaz.
class IconBadge {
  IconBadge({MethodChannel? channel, bool? isIOS})
      : _ch = channel ?? const MethodChannel('bu_kampus/badge'),
        _ios = isIOS ?? (!kIsWeb && Platform.isIOS);

  final MethodChannel _ch;
  final bool _ios;
  ValueListenable<int>? _source;
  int? _last;

  /// Kaynağı dinlemeye başlar ve güncel değeri hemen yansıtır (eski push rozeti düzeltilsin).
  void attach(ValueListenable<int> source) {
    if (!_ios) return;
    detach(clear: false);
    _source = source;
    source.addListener(_onChange);
    _onChange();
  }

  /// Dinlemeyi bırakır; [clear] ise rozeti sıfırlar (çıkışta başka kullanıcının sayısı kalmasın).
  void detach({bool clear = true}) {
    _source?.removeListener(_onChange);
    _source = null;
    if (clear) unawaited(set(0));
  }

  void _onChange() {
    final v = _source?.value;
    if (v != null) unawaited(set(v));
  }

  /// Rozeti ayarlar (tekrarlayan aynı değer gönderilmez).
  Future<void> set(int count) async {
    if (!_ios) return;
    final n = count < 0 ? 0 : count;
    if (_last == n) return;
    _last = n;
    try {
      await _ch.invokeMethod<void>('set', {'count': n});
    } on MissingPluginException {
      // platform kodu yok
    } catch (e) {
      debugPrint('Simge rozeti ayarlanamadi: ${e.runtimeType}');
    }
  }
}

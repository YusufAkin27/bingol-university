import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'transfer_job.dart';

/// Sistem bildirimi metinleri (çağıran yerelleştirir). GİZLİLİK: alıcı adı, mesaj metni, dosya adı ve önizleme
/// BURAYA KONMAZ; bildirim yalnız genel sayım gösterir ("2 dosya gönderiliyor").
class TransferLabels {
  const TransferLabels({
    this.channelName = 'Aktarımlar',
    this.uploading = 'Yükleniyor',
    this.waiting = 'Bağlantı bekleniyor',
    this.processing = 'Sunucuda işleniyor',
    this.failed = 'Aktarım başarısız',
    this.retryHint = 'Yeniden denemek için dokunun',
  });

  final String channelName, uploading, waiting, processing, failed, retryHint;
}

/// İşletim sistemi köprüsü. Kuyruktaki TEK özetten beslenir; kendi yüzdesini üretmez.
/// Uygulama arka plana geçtiğinde işin süreceğine dair GARANTİ vermez: Android'de ön plan servisi süreci canlı tutar
/// (kullanıcı zorla durdurursa / sistem sonlandırırsa biter), iOS'ta bu sürüm yalnız uygulama içi takip yapar.
abstract class TransferPlatform {
  Future<void> update(TransferSummary summary, TransferLabels labels);
  Future<void> stop();
}

class NoopTransferPlatform implements TransferPlatform {
  const NoopTransferPlatform();
  @override
  Future<void> update(TransferSummary summary, TransferLabels labels) async {}
  @override
  Future<void> stop() async {}
}

/// Android: `bu_kampus/transfers` kanalı -> `TransferService` (ön plan servisi, dataSync) tek ilerleme bildirimi.
/// Aynı bildirim kimliği güncellenir (her ilerlemede yeni bildirim yok); güncellemeler en çok 700 ms'de bir gider.
class MethodChannelTransferPlatform implements TransferPlatform {
  MethodChannelTransferPlatform({MethodChannel? channel, this.throttle = const Duration(milliseconds: 700)})
      : _ch = channel ?? const MethodChannel('bu_kampus/transfers');

  final MethodChannel _ch;
  final Duration throttle;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _pending;
  TransferSummary? _queued;
  TransferLabels _labels = const TransferLabels();
  bool _running = false;

  static bool get supported => !kIsWeb && Platform.isAndroid;

  @override
  Future<void> update(TransferSummary s, TransferLabels labels) async {
    if (s.isIdle) return stop();
    _labels = labels;
    final now = DateTime.now();
    final since = now.difference(_last);
    // Durum değişimi (sayı farkı) hemen, salt bayt ilerlemesi seyrekleştirilir.
    if (since >= throttle) {
      _push(s);
    } else {
      _queued = s;
      _pending ??= Timer(throttle - since, () {
        _pending = null;
        final q = _queued;
        _queued = null;
        if (q != null) _push(q);
      });
    }
  }

  void _push(TransferSummary s) {
    _last = DateTime.now();
    _running = true;
    final pct = s.fraction;
    unawaited(_ch.invokeMethod<void>('update', {
      'live': s.liveCount,
      'active': s.active,
      'waiting': s.waiting,
      'processing': s.processing,
      'failed': s.failed,
      // -1: toplam bilinmiyor ya da sunucu işliyor -> belirsiz ilerleme (yüzde uydurulmaz)
      'percent': pct == null ? -1 : (pct * 100).round(),
      'channelName': _labels.channelName,
      'uploading': _labels.uploading,
      'waitingText': _labels.waiting,
      'processingText': _labels.processing,
      'failedText': _labels.failed,
      'retryHint': _labels.retryHint,
    }).catchError((Object _) {
      // Bildirim iznı yok / servis başlatılamadı: uygulama içi takip sürer, akışı bozma.
    }));
  }

  @override
  Future<void> stop() async {
    _pending?.cancel();
    _pending = null;
    _queued = null;
    if (!_running) return;
    _running = false;
    try {
      await _ch.invokeMethod<void>('stop');
    } catch (_) {
      // Bilerek yutulur: en iyi çaba.
    }
  }
}

/// Platforma uygun köprü. iOS: ActivityKit / background URLSession bu sürümde YOK (docs/changes/transfers.md).
TransferPlatform defaultTransferPlatform() =>
    MethodChannelTransferPlatform.supported ? MethodChannelTransferPlatform() : const NoopTransferPlatform();

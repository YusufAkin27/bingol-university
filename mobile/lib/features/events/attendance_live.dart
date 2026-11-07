import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/realtime/chat_realtime.dart';
import '../../core/session.dart';

/// Etkinlik yoklaması canlı eşitleme: STOMP `attendance-events` olayları + KISA YOKLAMA (poll) yedeği.
/// Pub/sub kalıcı değildir; bağlantı kopması/olay kaçması durumunda [onPoll] düzenli aralıkla (ve her yeniden
/// bağlanmada) çağrılır. Bağlıyken aralık uzar, kopukken kısalır. Sayfa kapanınca [dispose] her şeyi iptal eder.
class AttendanceLiveBinding {
  AttendanceLiveBinding({
    required this.session,
    required this.eventId,
    required this.onEvent,
    required this.onPoll,
    this.connectedEvery = const Duration(seconds: 30),
    this.offlineEvery = const Duration(seconds: 8),
  });

  final Session session;
  final int eventId;
  final void Function(AttendanceLiveEvent e) onEvent;
  final Future<void> Function() onPoll;
  final Duration connectedEvery;
  final Duration offlineEvery;

  StreamSubscription<AttendanceLiveEvent>? _ev;
  StreamSubscription<void>? _resync;
  Timer? _timer;
  bool _disposed = false;

  void start() {
    final rt = session.realtime;
    if (rt != null) {
      _ev = rt.attendanceEvents.where((e) => e.eventId == eventId).listen(onEvent);
      _resync = rt.resync.listen((_) => _poll());
    }
    _schedule();
  }

  void _schedule() {
    if (_disposed) return;
    final connected = session.realtime?.isConnected ?? false;
    _timer?.cancel();
    _timer = Timer(connected ? connectedEvery : offlineEvery, () async {
      await _poll();
      _schedule();
    });
  }

  Future<void> _poll() async {
    if (_disposed) return;
    try {
      await onPoll();
    } catch (_) {
      // En iyi çaba: sonraki turda yeniden denenir.
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _ev?.cancel();
    _resync?.cancel();
  }
}

/// Hareket azaltma açıksa animasyon süresi sıfırlanır.
Duration liveMotion(BuildContext context, [Duration d = const Duration(milliseconds: 220)]) =>
    MediaQuery.maybeDisableAnimationsOf(context) == true ? Duration.zero : d;

import 'dart:async';

import 'package:flutter/widgets.dart';

/// Uygulama arka plana alinca (paused/hidden) durup one gelince (resumed) yeniden baslayan periyodik zamanlayici.
/// `dispose` sirasinda [stopForegroundTimer] cagrilir.
/// Kullanim: `class _S extends State<W> with WidgetsBindingObserver, ForegroundTimer<W>`.
mixin ForegroundTimer<T extends StatefulWidget> on State<T>, WidgetsBindingObserver {
  Timer? _fgTimer;
  Duration? _fgEvery;
  VoidCallback? _fgTick;

  bool get foregroundTimerActive => _fgTimer != null;

  void startForegroundTimer(Duration every, VoidCallback tick) {
    stopForegroundTimer();
    _fgEvery = every;
    _fgTick = tick;
    WidgetsBinding.instance.addObserver(this);
    _arm();
  }

  void stopForegroundTimer() {
    WidgetsBinding.instance.removeObserver(this);
    _fgTimer?.cancel();
    _fgTimer = null;
    _fgEvery = null;
    _fgTick = null;
  }

  void _arm() {
    _fgTimer?.cancel();
    final e = _fgEvery, t = _fgTick;
    if (e != null && t != null) _fgTimer = Timer.periodic(e, (_) => t());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_fgEvery == null) return;
    if (state == AppLifecycleState.resumed) {
      if (_fgTimer == null) {
        _arm();
        _fgTick?.call(); // geri donuste bayat veriyi hemen tazele
      }
    } else {
      _fgTimer?.cancel();
      _fgTimer = null;
    }
  }
}

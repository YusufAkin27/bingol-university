import 'dart:async';

import 'package:flutter/material.dart';

import '../../../widgets/bu.dart';
import 'auth_ref.dart';

/// Yeniden gönder: geri sayım halkası + metin; süre bitince düğme olur. Zamanlayıcı yalnız bu parçayı yeniler.
class AuthResendRow extends StatefulWidget {
  const AuthResendRow({
    super.key,
    required this.onResend,
    required this.waitingLabel,
    required this.resendLabel,
    this.initialSeconds = 180,
    this.startReady = false,
  });

  final VoidCallback onResend;
  final String Function(int seconds) waitingLabel;
  final String resendLabel;
  final int initialSeconds;

  /// Bekleme olmadan hazır başlar (ör. deneme sınırı aşıldı).
  final bool startReady;

  @override
  State<AuthResendRow> createState() => AuthResendRowState();
}

class AuthResendRowState extends State<AuthResendRow> {
  Timer? _timer;
  late int _total = widget.initialSeconds;
  late int _left = widget.startReady ? 0 : widget.initialSeconds;

  @override
  void initState() {
    super.initState();
    if (_left > 0) _tick();
  }

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  /// Sayacı yeniden başlatır (yeni kod gönderildi).
  void restart([int? seconds]) {
    if (!mounted) return;
    setState(() {
      _total = seconds ?? widget.initialSeconds;
      _left = _total;
    });
    _tick();
  }

  /// Beklemeyi atlar ve düğmeyi açar.
  void makeReady() {
    _timer?.cancel();
    if (mounted) setState(() => _left = 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return AnimatedSwitcher(
      duration: BuMotion.of(context, BuMotion.short),
      child: _left > 0
          ? Row(
              key: const ValueKey('wait'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(BuIcons.clock, size: 20, color: t.mut),
                const SizedBox(width: 8),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Text(widget.waitingLabel(_left), style: tx.labelLarge!.copyWith(color: t.mut, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            )
          : Align(
              key: const ValueKey('ready'),
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 1,
              child: RefLink(
                label: widget.resendLabel,
                icon: BuIcons.refreshCw,
                compact: true,
                onPressed: widget.onResend,
              ),
            ),
    );
  }
}

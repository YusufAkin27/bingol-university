import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/locale_controller.dart';
import '../../../core/pin.dart';
import '../../../widgets/bu.dart';
import 'auth_motion.dart';
import 'auth_ref.dart';

/// Yeniden gönder: geri sayım halkası + metin; süre bitince düğme olur. Zamanlayıcı yalnız bu parçayı yeniler.
class AuthResendRow extends StatefulWidget {
  const AuthResendRow({
    super.key,
    required this.onResend,
    required this.waitingLabel,
    required this.resendLabel,
    this.initialSeconds = 60,
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

/// Şifre (6 haneli PIN) kural ipuçları: "6 rakamdan oluşur" ve "Kolay tahmin edilmez"; sağlandıkça tik atar.
/// Kural sunucuyla birebir aynıdır (bkz. `core/pin.dart`).
class AuthPasswordGuide extends StatelessWidget {
  const AuthPasswordGuide({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final formatOk = isPinFormat(password);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthRule(ok: formatOk, label: l.authRuleLen),
          const SizedBox(height: 10),
          AuthRule(ok: formatOk && !isWeakPin(password), label: l.authRuleMix),
        ],
      ),
    );
  }
}

/// Kural satırı: sağlanınca yumuşak mavi daire dolar, tik belirir ve hafif titreşim verir.
class AuthRule extends StatefulWidget {
  const AuthRule({super.key, required this.ok, required this.label});

  final bool ok;
  final String label;

  @override
  State<AuthRule> createState() => _AuthRuleState();
}

class _AuthRuleState extends State<AuthRule> {
  @override
  void didUpdateWidget(AuthRule old) {
    super.didUpdateWidget(old);
    if (widget.ok && !old.ok) authHaptic(AuthHaptic.tap);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final ok = widget.ok;
    return Row(
      children: [
        // Sağlanınca ink tik, sağlanmayınca boş halka (renk yok).
        SizedBox(
          width: 20,
          height: 20,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedOpacity(
                duration: BuMotion.of(context, BuMotion.short),
                opacity: ok ? 0 : 1,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.bdStrong, width: 1.2)),
                ),
              ),
              AnimatedScale(
                scale: ok ? 1 : 0,
                duration: BuMotion.of(context, BuMotion.medium),
                curve: Curves.easeOutBack,
                child: Icon(BuIcons.check, size: 18, color: t.ink),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AnimatedDefaultTextStyle(
            duration: BuMotion.of(context, BuMotion.short),
            style: tx.bodyMedium!.copyWith(color: ok ? t.ink : t.mut),
            child: Text(widget.label),
          ),
        ),
      ],
    );
  }
}

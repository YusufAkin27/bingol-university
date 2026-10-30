import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/locale_controller.dart';
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
      duration: const Duration(milliseconds: 220),
      child: _left > 0
          ? Row(
              key: const ValueKey('wait'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.clock, size: 20, color: t.mut),
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
                icon: LucideIcons.refreshCw,
                onPressed: widget.onResend,
              ),
            ),
    );
  }
}

/// Parola gücü ("Şifre gücü" + durum, 3 parçalı çubuk) ve tek tek tik atan kural listesi.
class AuthPasswordGuide extends StatelessWidget {
  const AuthPasswordGuide({super.key, required this.password});

  final String password;

  static int score(String p) {
    if (p.isEmpty) return 0;
    var s = 0;
    if (p.length >= 8) s++;
    if (p.length >= 12 || (RegExp(r'[A-Za-z]').hasMatch(p) && RegExp(r'\d').hasMatch(p))) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p) && p.length >= 8 ||
        (p.length >= 12 && RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'\d').hasMatch(p))) {
      s++;
    }
    return s == 0 ? 1 : s;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final sc = score(password);
    final color = sc >= 3 ? t.ok : t.danger;
    final label = sc <= 1 ? l.authPwWeak : (sc == 2 ? l.authPwFair : l.authPwStrong);
    final hasMix = RegExp(r'[A-Za-z]').hasMatch(password) && RegExp(r'\d').hasMatch(password);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(l.p02PwStrengthTitle, style: tx.bodySmall!.copyWith(color: t.mut, fontWeight: FontWeight.w500))),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  password.isEmpty ? '' : label,
                  key: ValueKey(password.isEmpty ? '' : label),
                  style: tx.labelLarge!.copyWith(color: color, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: password.isNotEmpty && i < sc ? color : t.sf2,
                    ),
                  ),
                ),
                if (i < 2) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 14),
          AuthRule(ok: password.length >= 8, label: l.authRuleLen),
          const SizedBox(height: 10),
          AuthRule(ok: hasMix, label: l.authRuleMix),
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
    final tint = t.tint(1);
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutBack,
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ok ? tint.bg : t.sf2,
          ),
          child: AnimatedScale(
            scale: ok ? 1 : 0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: Icon(LucideIcons.check, size: 14, color: tint.fg),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: tx.bodyMedium!.copyWith(color: ok ? t.ink : t.mut),
            child: Text(widget.label),
          ),
        ),
      ],
    );
  }
}

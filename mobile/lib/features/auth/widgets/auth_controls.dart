import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/locale_controller.dart';
import '../../../core/theme.dart';
import '../../../core/typography.dart';
import '../../../widgets/bu_widgets.dart';
import 'auth_fields.dart';
import 'auth_motion.dart';

/// Ana eylem: 56 dp, 20 dp yuvarlak, ince dikey gradyan, basınca hafif küçülür, yükleniyorken içte yay göstergesi.
class AuthPrimaryButton extends StatefulWidget {
  const AuthPrimaryButton({super.key, required this.onPressed, required this.label, this.busy = false, this.icon});

  final VoidCallback? onPressed;
  final String label;
  final bool busy;

  /// Etiketin yanında (sonda) küçük simge; yön gerektiren simgeler çağıranda aynalanır.
  final IconData? icon;

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final enabled = widget.onPressed != null || widget.busy;
    final top = Color.lerp(t.pr, Colors.white, .10)!;
    final fg = widget.onPressed == null && !widget.busy ? t.onPr.withValues(alpha: .8) : t.onPr;
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down && enabled ? .985 : 1,
        duration: const Duration(milliseconds: 110),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kAuthRadius),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: enabled ? [top, t.pr] : [top.withValues(alpha: .38), t.pr.withValues(alpha: .38)],
            ),
          ),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              foregroundColor: fg,
              disabledForegroundColor: fg,
              shadowColor: Colors.transparent,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAuthRadius)),
              textStyle: BuType.bodyStrong.copyWith(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: .1),
            ),
            // Yüklenirken tıklama yutulur ama düğme dolu görünür (soluklaşıp zıplamasın).
            onPressed: widget.busy ? () {} : widget.onPressed,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: widget.busy
                  ? SizedBox(
                      key: const ValueKey('busy'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.6, color: t.onPr, semanticsLabel: widget.label),
                    )
                  : Row(
                      key: const ValueKey('label'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: Text(widget.label, textAlign: TextAlign.center)),
                        if (widget.icon != null) ...[const SizedBox(width: 8), Icon(widget.icon, size: 18)],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// İkincil/bağlantı eylemi: en az 48 dp yüksek.
class AuthTextAction extends StatelessWidget {
  const AuthTextAction({super.key, required this.label, required this.onPressed, this.muted = false, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final bool muted;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final c = muted ? t.mut : t.pr;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: c,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 17), const SizedBox(width: 6)],
          Flexible(child: Text(label, style: BuType.bodyStrong.copyWith(fontSize: 14.5, color: c, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

/// "Hesabınız yok mu? Kayıt ol" satırı (bağlantı ayrı Text olarak kalır; 48 dp dokunma alanı).
class AuthFooterPrompt extends StatelessWidget {
  const AuthFooterPrompt({super.key, required this.prompt, required this.action, required this.onPressed});

  final String prompt;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prompt, style: BuType.body.copyWith(color: t.mut, fontSize: 14.5)),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            foregroundColor: t.pr,
          ),
          child: Text(action, style: BuType.bodyStrong.copyWith(fontSize: 14.5, color: t.pr, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

enum AuthBannerKind { error, info, success }

/// Satır içi geri bildirim: renkli zemin + yuvarlak simge; ekranda yumuşakça açılır.
class AuthBanner extends StatelessWidget {
  const AuthBanner(this.text, {super.key, this.kind = AuthBannerKind.error, this.icon, this.onClose, this.closeKey});

  final String text;
  final AuthBannerKind kind;
  final IconData? icon;
  final VoidCallback? onClose;
  final Key? closeKey;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final cs = Theme.of(context).colorScheme;
    final (bg, fg, ic) = switch (kind) {
      AuthBannerKind.error => (cs.errorContainer, t.danger, LucideIcons.circleAlert),
      AuthBannerKind.success => (t.okSoft, t.ok, LucideIcons.circleCheck),
      AuthBannerKind.info => (t.sf2, t.ink, LucideIcons.info),
    };
    final tint = kind == AuthBannerKind.info ? t.pr : fg;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 6, 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tint.withValues(alpha: .18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(shape: BoxShape.circle, color: tint.withValues(alpha: .14)),
              child: Icon(icon ?? ic, color: tint, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Text(text, style: BuType.body.copyWith(color: fg, height: 1.4, fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ),
            if (onClose != null)
              IconButton(
                key: closeKey,
                tooltip: context.l10n.commonClose,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: Icon(LucideIcons.x, size: 18, color: fg),
                onPressed: onClose,
              )
            else
              const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

/// Banner yuvası: içerik değişince yükseklik yumuşakça açılır/kapanır; hata gelince sarsılır.
class AuthFeedbackSlot extends StatelessWidget {
  const AuthFeedbackSlot({super.key, this.error, this.info, this.success, this.shake = 0});

  final String? error;
  final String? info;
  final String? success;
  final int shake;

  @override
  Widget build(BuildContext context) {
    final Widget? child = error != null
        ? AuthShake(trigger: shake, child: AuthBanner(error!, key: ValueKey('e$error')))
        : success != null
            ? AuthBanner(success!, kind: AuthBannerKind.success, key: ValueKey('s$success'))
            : info != null
                ? AuthBanner(info!, kind: AuthBannerKind.info, key: ValueKey('i$info'))
                : null;
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
        child: child ?? const SizedBox(key: ValueKey('none'), width: double.infinity),
      ),
    );
  }
}

/// Adım noktaları: etkin adım uzun hap, tamamlananlar dolu nokta, gelecekler boş nokta (250 ms geçiş).
class AuthStepDots extends StatelessWidget {
  const AuthStepDots({super.key, required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == step ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: i == step ? t.pr : (i < step ? t.pr.withValues(alpha: .45) : t.mut.withValues(alpha: .28)),
              ),
            ),
        ],
      ),
    );
  }
}

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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _left > 0
          ? Row(
              key: const ValueKey('wait'),
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CustomPaint(painter: _RingPainter(_left / _total, t.pr, t.bd)),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Text(widget.waitingLabel(_left),
                        textAlign: TextAlign.center, style: BuType.body.copyWith(color: t.mut, fontSize: 14)),
                  ),
                ),
              ],
            )
          : Center(
              key: const ValueKey('ready'),
              child: AuthTextAction(
                label: widget.resendLabel,
                icon: LucideIcons.refreshCw,
                onPressed: widget.onResend,
              ),
            ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.track);

  final double value;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * value.clamp(0.0, 1.0), false, p..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color;
}

/// Parola gücü (3 parçalı, renkli) ve tek tek tik atan kural listesi.
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
    final sc = score(password);
    final warn = Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFFC66B) : const Color(0xFF8A5200);
    final color = sc <= 1 ? t.danger : (sc == 2 ? warn : t.ok);
    final label = sc <= 1 ? l.authPwWeak : (sc == 2 ? l.authPwFair : l.authPwStrong);
    final hasMix = RegExp(r'[A-Za-z]').hasMatch(password) && RegExp(r'\d').hasMatch(password);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                      color: password.isNotEmpty && i < sc ? color : t.bd,
                    ),
                  ),
                ),
                if (i < 2) const SizedBox(width: 5),
              ],
              const SizedBox(width: 12),
              SizedBox(
                width: 56,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(position: Tween(begin: const Offset(0, .3), end: Offset.zero).animate(a), child: c),
                  ),
                  child: Text(
                    password.isEmpty ? '' : label,
                    key: ValueKey(password.isEmpty ? '' : label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BuType.label.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                ),
              ),
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

/// Kural satırı: sağlanınca daire dolar, tik "yaylanarak" belirir ve hafif titreşim verir.
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
    final ok = widget.ok;
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutBack,
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ok ? t.ok : Colors.transparent,
            border: Border.all(color: ok ? t.ok : t.bd, width: 1.6),
          ),
          child: AnimatedScale(
            scale: ok ? 1 : 0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: Icon(LucideIcons.check, size: 13, color: Theme.of(context).brightness == Brightness.dark ? t.bg : Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: BuType.body.copyWith(color: ok ? t.ink : t.mut, fontSize: 14, fontWeight: ok ? FontWeight.w600 : FontWeight.w400),
            child: Text(widget.label),
          ),
        ),
      ],
    );
  }
}

/// Güven veren mikro metin: küçük kalkan + açıklama.
class AuthTrustNote extends StatelessWidget {
  const AuthTrustNote(this.text, {super.key, this.icon = LucideIcons.shieldCheck});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 15, color: t.ok),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: BuType.caption.copyWith(color: t.mut, fontSize: 12.5, height: 1.45))),
      ],
    );
  }
}

/// Başlığın üstündeki rozet: yumuşak zeminli kare + simge (illüstrasyon yoksa).
class AuthIconBadge extends StatelessWidget {
  const AuthIconBadge(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(18)),
      child: Icon(icon, color: t.pr, size: 26),
    );
  }
}

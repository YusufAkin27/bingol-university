import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/locale_controller.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'widgets/auth_art.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_fields.dart';
import 'widgets/auth_motion.dart';
import 'widgets/auth_sheets.dart';

/// İlk açılışta (cihaz başına bir kez) gösterilen karşılama: markaya özgü hareketli kırmızı sahne
/// (yavaş dalgalar, nefes alan halkalar, ölçeklenerek gelen logo + parıltı) ve altta yumuşak köşeli eylem sayfası.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, required this.onLogin, required this.onRegister});

  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Animation<double> _seg(double a, double b, [Curve c = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _intro, curve: Interval(a, b, curve: c));

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final top = MediaQuery.viewPaddingOf(context).top;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final card = _seg(0, .45, Curves.easeOutBack);
    final sheen = _seg(.4, .85, Curves.easeInOut);
    final chips = _seg(.45, .9);
    final sheet = _seg(.25, .8);

    return AuthClockHost(
      child: Scaffold(
        backgroundColor: t.bg,
        body: LayoutBuilder(
          builder: (context, cons) {
            final h = cons.maxHeight;
            final heroH = (h * .53).clamp(330.0, 470.0);
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: heroH,
                          child: _Hero(top: top, card: card, sheen: sheen, chips: chips),
                        ),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(26, 6, 26, 0),
                              child: _Reveal(
                                animation: sheet,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Semantics(
                                      header: true,
                                      child: Text(
                                        l.welcomeHeadline,
                                        style: BuType.display.copyWith(
                                            color: t.ink, fontSize: 32, height: 1.1, letterSpacing: -1, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(l.welcomeSub, style: BuType.body.copyWith(color: t.mut, fontSize: 15.5, height: 1.5)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(26, 24, 26, 18 + bottom),
                          child: _Reveal(
                            animation: sheet,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AuthPrimaryButton(
                                  onPressed: widget.onLogin,
                                  label: l.loginSubmit,
                                  icon: buDirIcon(context, LucideIcons.arrowRight),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(56),
                                    backgroundColor: t.sf,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAuthRadius)),
                                    side: BorderSide(color: t.bd, width: 1.2),
                                  ),
                                  onPressed: widget.onRegister,
                                  child: Text(l.authCreateAccount,
                                      style: BuType.bodyStrong.copyWith(color: t.ink, fontSize: 16, fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(height: 16),
                                AuthTrustNote(l.welcomeNote),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// İçeriğin belirirken hafifçe yukarı süzülmesi (animasyon bitince katman kalmaz).
class _Reveal extends StatelessWidget {
  const _Reveal({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, ch) => Opacity(
          opacity: animation.value,
          child: Transform.translate(offset: Offset(0, (1 - animation.value) * 22), child: ch),
        ),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.top, required this.card, required this.sheen, required this.chips});

  final double top;
  final Animation<double> card;
  final Animation<double> sheen;
  final Animation<double> chips;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final clock = authClockOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: t.hero),
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: RepaintBoundary(child: CustomPaint(painter: AuthHeroPainter(clock))),
            ),
          ),
          PositionedDirectional(top: top + 12, end: 20, child: const AuthLanguageButton(onDark: true)),
          Align(
            alignment: const Alignment(0, -.30),
            child: Padding(
              padding: EdgeInsets.only(top: top * .4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: Tween(begin: .5, end: 1.0).animate(card),
                    child: FadeTransition(
                      opacity: card,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .28), blurRadius: 34, offset: const Offset(0, 16), spreadRadius: -8)],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SvgPicture.asset(
                                'assets/branding/mark_white.svg',
                                width: 62,
                                height: 62,
                                colorFilter: const ColorFilter.mode(kBrandRed, BlendMode.srcIn),
                                semanticsLabel: 'BÜ Kampüs',
                              ),
                              Positioned.fill(child: CustomPaint(painter: AuthSheenPainter(sheen))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FadeTransition(
                    opacity: chips,
                    child: Column(
                      children: [
                        Text('BÜ Kampüs',
                            style: BuType.display.copyWith(color: Colors.white, fontSize: 28, letterSpacing: -.6, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('Bingöl Üniversitesi',
                            style: BuType.body.copyWith(color: Colors.white.withValues(alpha: .86), fontSize: 14.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: -1,
            height: 34,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: t.bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 50,
            child: FadeTransition(
              opacity: chips,
              child: AnimatedBuilder(
                animation: clock,
                builder: (context, _) {
                  final p = clock.value * math.pi * 12;
                  Widget chip(int i, IconData icon, String label) => Transform.translate(
                        offset: Offset(0, math.sin(p + i * 1.9) * 2.5),
                        child: _HeroChip(icon: icon, label: label),
                      );
                  return Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      chip(0, LucideIcons.newspaper, l.welcomeChipNews),
                      chip(1, LucideIcons.utensils, l.welcomeChipMenu),
                      chip(2, LucideIcons.calendarDays, l.welcomeChipClubs),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 7),
          Text(label, style: BuType.label.copyWith(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

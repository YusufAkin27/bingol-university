import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/locale_controller.dart';
import '../../../core/theme.dart';
import '../../../core/typography.dart';
import '../../../widgets/bu_widgets.dart';
import 'auth_art.dart';
import 'auth_controls.dart';
import 'auth_motion.dart';

/// Kimlik ekranlarının ortak iskeleti.
///
/// Üstte geri düğmesi (ya da marka işareti) + adım noktaları + sağ parça; altında kaydırılan içerik;
/// en altta klavyeyle birlikte yükselen sabit eylem çubuğu ([bottom]). Arka plan: tek saatli, yavaş süzülen
/// marka lekeleri. İçerik parçaları açılışta sırayla (staggered) belirir.
class AuthShell extends StatefulWidget {
  const AuthShell({
    super.key,
    required this.title,
    this.subtitle,
    this.emphasis,
    required this.body,
    this.bottom,
    this.showBack = false,
    this.onBack,
    this.trailing,
    this.step,
    this.stepTotal = 3,
    this.art,
    this.icon,
    this.stepLabel,
  });

  final String title;
  final String? subtitle;

  /// [subtitle] içinde kalın gösterilecek parça (ör. e-posta adresi).
  final String? emphasis;
  final List<Widget> body;

  /// Sabit alt çubuk (ana eylem + bağlantı); klavye açıkken yukarı kayar.
  final List<Widget>? bottom;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? trailing;

  /// 0 tabanlı adım; verilirse üstte noktalar görünür.
  final int? step;
  final int stepTotal;

  /// Başlık üstündeki illüstrasyon (klavye açılınca küçülüp kaybolur).
  final AuthArtKind? art;
  final IconData? icon;

  /// Adım noktaları için erişilebilirlik etiketi ("Adım 2/3").
  final String? stepLabel;

  @override
  State<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends State<AuthShell> with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
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

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;

    final subtitle = widget.subtitle;
    Widget? sub;
    if (subtitle != null) {
      final base = BuType.body.copyWith(color: t.mut, fontSize: 15.5, height: 1.5);
      final e = widget.emphasis;
      final at = e == null ? -1 : subtitle.indexOf(e);
      sub = at < 0
          ? Text(subtitle, style: base)
          : Text.rich(TextSpan(style: base, children: [
              TextSpan(text: subtitle.substring(0, at)),
              TextSpan(text: e, style: base.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
              TextSpan(text: subtitle.substring(at + e!.length)),
            ]));
    }

    final header = <Widget>[
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: AlignmentDirectional.topStart,
        child: keyboard || (widget.art == null && widget.icon == null)
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (c, a) => ScaleTransition(scale: Tween(begin: .85, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: c)),
                    layoutBuilder: (cur, prev) => Stack(alignment: AlignmentDirectional.centerStart, children: [...prev, if (cur != null) cur]),
                    child: widget.art != null
                        ? AuthArt(widget.art!, key: ValueKey(widget.art), size: 104)
                        : AuthIconBadge(widget.icon!, key: ValueKey(widget.icon)),
                  ),
                ),
              ),
      ),
      Semantics(
        header: true,
        child: Text(
          widget.title,
          style: BuType.display.copyWith(color: t.ink, fontSize: keyboard ? 27 : 31, height: 1.14, letterSpacing: -.8, fontWeight: FontWeight.w800),
        ),
      ),
      if (sub != null) Padding(padding: const EdgeInsets.only(top: 10), child: sub),
      SizedBox(height: keyboard ? 20 : 28),
    ];
    final all = [...header, ...widget.body];

    return AuthClockHost(
      child: Scaffold(
        backgroundColor: t.bg,
        body: Stack(
          children: [
            const Positioned(top: 0, left: 0, right: 0, child: AuthAmbient()),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _TopBar(shell: widget),
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < all.length; i++) AuthReveal(controller: _intro, index: i, child: all[i]),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.bottom != null)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: t.bg,
                        border: Border(top: BorderSide(color: t.bd.withValues(alpha: .6))),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(24, 12, 24, keyboard ? 10 : 8 + safeBottom),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: widget.bottom!,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.shell});

  final AuthShell shell;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final Widget leading = shell.showBack
        ? Semantics(
            button: true,
            label: context.l10n.authBack,
            child: Material(
              color: t.sf,
              shape: CircleBorder(side: BorderSide(color: t.bd)),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: shell.onBack ?? () => Navigator.maybePop(context),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: Icon(buDirIcon(context, LucideIcons.arrowLeft), color: t.ink, size: 20),
                ),
              ),
            ),
          )
        : SvgPicture.asset('assets/branding/mark.svg', width: 40, height: 40, semanticsLabel: 'BÜ Kampüs');
    return SizedBox(
      height: 66,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(alignment: AlignmentDirectional.centerStart, child: leading),
            if (shell.step != null)
              Semantics(
                label: shell.stepLabel,
                child: AuthStepDots(step: shell.step!, total: shell.stepTotal),
              ),
            if (shell.trailing != null) Align(alignment: AlignmentDirectional.centerEnd, child: shell.trailing),
          ],
        ),
      ),
    );
  }
}

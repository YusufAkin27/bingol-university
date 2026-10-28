import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/locale_controller.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'auth_widgets.dart';

/// İlk açılışta (cihaz başına bir kez) gösterilen karşılama ekranı: tanıtım, dil seçimi, giriş / kayıt.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.onLogin, required this.onRegister});

  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(
        children: [
          PositionedDirectional(
            top: -120,
            end: -120,
            child: ExcludeSemantics(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(shape: BoxShape.circle, color: t.soft),
              ),
            ),
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(28, top + 16, 28, 20 + bottom),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight - top - 36 - bottom),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              SvgPicture.asset('assets/branding/mark.svg',
                                  width: 40, height: 40, semanticsLabel: 'BÜ Kampüs'),
                              const Spacer(),
                              const _LanguagePill(),
                            ],
                          ),
                          const SizedBox(height: 40),
                          Text(
                            l.welcomeHeadline,
                            style: BuType.display.copyWith(
                                color: t.ink, fontSize: 36, height: 1.1, letterSpacing: -0.8, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          Text(l.welcomeSub, style: BuType.body.copyWith(color: t.mut, fontSize: 16, height: 1.5)),
                          const SizedBox(height: 30),
                          _FeatureRow(icon: LucideIcons.newspaper, tint: t.soft, color: t.pr, label: l.welcomeNews),
                          const SizedBox(height: 12),
                          _FeatureRow(
                              icon: LucideIcons.utensils,
                              tint: const Color(0xFFE6F2EA),
                              color: const Color(0xFF1F7A4A),
                              label: l.welcomeMenu),
                          const SizedBox(height: 12),
                          _FeatureRow(
                              icon: LucideIcons.calendarDays,
                              tint: const Color(0xFFE8EDF8),
                              color: const Color(0xFF2F4FA8),
                              label: l.welcomeClubs),
                          const SizedBox(height: 32),
                          AuthButton(onPressed: onLogin, label: l.loginSubmit),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              backgroundColor: t.sf,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              side: BorderSide(color: t.bd),
                            ),
                            onPressed: onRegister,
                            child: Text(l.authCreateAccount, style: BuType.bodyStrong.copyWith(color: t.ink, fontSize: 15)),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            l.welcomeNote,
                            textAlign: TextAlign.center,
                            style: BuType.caption.copyWith(color: t.mut, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.tint, required this.color, required this.label});

  final IconData icon;
  final Color tint;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.bd),
        boxShadow: [BoxShadow(color: t.ink.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, 6), spreadRadius: -12)],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: BuType.bodyStrong.copyWith(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

/// TR / EN / عربي seçici: seçim anında uygulanır ve saklanır.
class _LanguagePill extends StatelessWidget {
  const _LanguagePill();

  static const _items = [('tr', 'TR'), ('en', 'EN'), ('ar', 'عربي')];

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final lc = LocaleController.current;
    final current = Localizations.localeOf(context).languageCode;
    return Semantics(
      container: true,
      label: context.l10n.welcomeLanguage,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: t.sf,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: t.bd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (code, label) in _items)
              Semantics(
                button: true,
                selected: code == current,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: lc == null ? null : () => lc.set(code),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: code == current ? t.pr : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      label,
                      style: BuType.label.copyWith(
                        fontSize: 13,
                        fontWeight: code == current ? FontWeight.w700 : FontWeight.w600,
                        color: code == current ? t.onPr : t.mut,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

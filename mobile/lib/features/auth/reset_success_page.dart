import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'widgets/auth_art.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_motion.dart';

/// Şifre sıfırlama başarı ekranı: çizilen tik + konfeti, kısa açıklama, tek eylem (girişe dön).
/// Geri tuşu da girişe döner (sıfırlama adımlarına geri gidilmez).
class ResetSuccessPage extends StatelessWidget {
  const ResetSuccessPage({super.key});

  void _toLogin(BuildContext context) => Navigator.of(context).popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _toLogin(context);
      },
      child: AuthClockHost(
        child: Scaffold(
          backgroundColor: t.bg,
          body: Stack(
            children: [
              const Positioned(top: 0, left: 0, right: 0, child: AuthAmbient()),
              SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const AuthSuccessBadge(),
                                const SizedBox(height: 4),
                                Semantics(
                                  header: true,
                                  liveRegion: true,
                                  child: Text(l.authResetDoneTitle,
                                      textAlign: TextAlign.center,
                                      style: BuType.display.copyWith(color: t.ink, fontSize: 28, letterSpacing: -.6, fontWeight: FontWeight.w800)),
                                ),
                                const SizedBox(height: 12),
                                Text(l.authResetDoneBody,
                                    textAlign: TextAlign.center, style: BuType.body.copyWith(color: t.mut, fontSize: 15.5, height: 1.5)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: AuthPrimaryButton(
                          onPressed: () => _toLogin(context),
                          label: l.authBackToLogin,
                          icon: buDirIcon(context, LucideIcons.arrowRight),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

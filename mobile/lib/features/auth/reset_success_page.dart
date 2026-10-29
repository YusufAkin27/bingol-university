import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'widgets/auth_ref.dart';

/// Şifre sıfırlama başarı ekranı (Stitch 03): yeşil onay işareti, kısa açıklama, tek eylem (girişe dön).
/// Geri tuşu da girişe döner (sıfırlama adımlarına geri gidilmez).
class ResetSuccessPage extends StatelessWidget {
  const ResetSuccessPage({super.key});

  void _toLogin(BuildContext context) => Navigator.of(context).popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _toLogin(context);
      },
      child: RefPage(
        onBack: () => _toLogin(context),
        children: [
          const SizedBox(height: 4),
          RefCard(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              children: [
                Container(
                  width: 112,
                  height: 112,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: t.okSoft, shape: BoxShape.circle),
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: t.ok,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: t.ok.withValues(alpha: .3), blurRadius: 18, offset: const Offset(0, 6), spreadRadius: -4)],
                    ),
                    child: Icon(LucideIcons.check, size: 44, color: t.onMedia),
                  ),
                ),
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(l.authResetDoneTitle,
                      textAlign: TextAlign.center, style: tx.headlineMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 10),
                Text(l.authResetDoneBody, textAlign: TextAlign.center, style: tx.bodyLarge!.copyWith(color: t.mut, height: 1.5)),
                const SizedBox(height: 28),
                SizedBox(width: double.infinity, child: RefButton(label: l.authBackToLogin, onPressed: () => _toLogin(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

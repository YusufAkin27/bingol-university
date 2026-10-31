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
      // Stitch v3 "12 Başarı": geri oku yok; ortada 56 dp okSoft daire + onay, alta sabit tek birincil düğme.
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: kRefPad),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(color: t.okSoft, shape: BoxShape.circle),
                            child: Icon(LucideIcons.check, size: 28, color: t.ok),
                          ),
                          const SizedBox(height: 24),
                          Semantics(
                            header: true,
                            liveRegion: true,
                            child: Text(l.authResetDoneTitle,
                                textAlign: TextAlign.center, style: tx.headlineMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 8),
                          Text(l.authResetDoneBody, textAlign: TextAlign.center, style: tx.bodyLarge!.copyWith(color: t.mut, height: 1.5)),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: RefButton(label: l.authBackToLogin, onPressed: () => _toLogin(context)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

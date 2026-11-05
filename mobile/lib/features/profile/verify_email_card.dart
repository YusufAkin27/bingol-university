import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../auth/verify_email_sheet.dart';

/// Profil sekmesi duyuru kartı: hesap e-postası DOĞRULANMAMIŞSA (günlük posta kotası aşılınca kayıt doğrulaması
/// ertelenir) "E-postanızı doğrulayın" + kısa açıklama + "Kodu gir" düğmesi. Doğrulanmış kullanıcıda hiçbir şey
/// çizmez (boşluk bile bırakmaz). Durum [Session.emailUnverified]'dan gelir; doğrulanınca kart yumuşakça kapanır.
class VerifyEmailCard extends StatelessWidget {
  const VerifyEmailCard({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: session.emailUnverified,
      builder: (context, unverified, _) => AnimatedSize(
        duration: BuMotion.of(context, BuMotion.short),
        curve: BuMotion.decelerate,
        alignment: Alignment.topCenter,
        child: unverified
            ? Padding(padding: const EdgeInsets.only(bottom: 16), child: _Card(session: session))
            : const SizedBox(width: double.infinity),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      child: Container(
        key: const ValueKey('verify-email-card'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.warnSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(child: Icon(BuIcons.mailCheck, size: 22, color: t.onWarnSoft)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(l.verifyEmailBannerTitle, style: tx.titleMedium!.copyWith(color: t.onWarnSoft, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 4),
                      Text(l.verifyEmailBannerBody, style: tx.bodyMedium!.copyWith(color: t.onWarnSoft, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BuButton(
                label: l.verifyEmailBannerCta,
                compact: true,
                onPressed: () => showVerifyEmailSheet(context, session),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

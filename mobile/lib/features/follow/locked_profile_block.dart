import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';

/// Gizli (kilitli) profilde gönderi ızgarası yerine gösterilen kısa blok: kilit simgesi, "Bu hesap gizli" ve tek cümle.
/// [requested] true ise (istek gönderilmiş) metin onay beklediğini söyler.
class LockedProfileBlock extends StatelessWidget {
  const LockedProfileBlock({super.key, this.requested = false});

  final bool requested;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final body = requested ? l.frqLockedBodyRequested : l.frqLockedBody;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Semantics(
        container: true,
        label: '${l.frqLockedTitle}. $body',
        excludeSemantics: true,
        child: DecoratedBox(
          key: const ValueKey('locked-profile-block'),
          decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.bd)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                child: Icon(BuIcons.lock, size: 26, color: t.onSoft),
              ),
              const SizedBox(height: 14),
              Text(l.frqLockedTitle,
                  textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w400, color: t.ink)),
              const SizedBox(height: 6),
              Text(body, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.45)),
            ]),
          ),
        ),
      ),
    );
  }
}

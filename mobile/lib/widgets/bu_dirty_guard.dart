import 'package:flutter/widgets.dart';

import '../core/locale_controller.dart';
import 'bu_overlays.dart';

/// Form sarmalayıcı: kaydedilmemiş değişiklik varken geri jesti / geri oku / sistem geri tuşu "değişiklikler atılsın mı"
/// onayı ister (veri kaybı önlemi). Kaydetme sonrası kod `Navigator.pop` çağırır; `pop` doğrudan çağrısı korumayı aşar.
/// `dirty` her derlemede okunur; `busy` iken (kayıt sürüyor) geri jesti yutulur.
class BuDirtyGuard extends StatelessWidget {
  const BuDirtyGuard({super.key, required this.dirty, required this.child, this.busy = false});

  final bool Function() dirty;
  final bool busy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final blocked = busy || dirty();
    return PopScope(
      canPop: !blocked,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || busy) return;
        FocusScope.of(context).unfocus();
        final l = context.l10n;
        final discard = await BuConfirmSheet.show(
          context,
          title: l.forumComposeDiscardTitle,
          confirmLabel: l.forumComposeDiscardConfirm,
          cancelLabel: l.forumComposeDiscardKeep,
          destructive: true,
        );
        if (discard && context.mounted) Navigator.of(context).pop();
      },
      child: child,
    );
  }
}

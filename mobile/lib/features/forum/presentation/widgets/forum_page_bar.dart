import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../widgets/bu.dart';

/// Forum ikincil sayfalarının üst çubuğu: geri + (isteğe bağlı) eylemler. Kullanıcı kuralı gereği SAYFA BAŞLIĞI
/// METNİ görünmez; ekran okuyucu için [semanticTitle] başlık etiketi olarak korunur.
class ForumPageBar extends StatelessWidget {
  const ForumPageBar({super.key, required this.semanticTitle, this.actions = const [], this.onBack, this.middle});

  final String semanticTitle;
  final List<Widget> actions;
  final VoidCallback? onBack;

  /// Geri ile eylemler arasındaki alan (ör. arama kutusu). Verilmezse boşluk.
  final Widget? middle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(16, MediaQuery.of(context).padding.top + 8, 16, 4),
      child: Row(children: [
        BuIconButton(icon: BuIcons.arrowLeft, tooltip: context.l10n.commonBack, onTap: onBack ?? () => Navigator.maybePop(context)),
        const SizedBox(width: 8),
        Semantics(header: true, label: semanticTitle, child: const SizedBox.shrink()),
        Expanded(child: middle ?? const SizedBox.shrink()),
        for (final a in actions) ...[const SizedBox(width: 8), a],
      ]),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../widgets/bu.dart';

/// Moderatör kaldırma gerekçesi alt sayfası. Gerekçe zorunludur (sunucu `forum_moderation_action` + denetim kaydı
/// tutar ve içerik sahibine gerekçeyi bildirir). Gerekçe döner; vazgeçilirse null.
Future<String?> showForumModRemoveSheet(BuildContext context, {required String title}) {
  return BuSheet.show<String>(
    context,
    title: title,
    builder: (_) => const _ModReasonBody(),
  );
}

class _ModReasonBody extends StatefulWidget {
  const _ModReasonBody();

  @override
  State<_ModReasonBody> createState() => _ModReasonBodyState();
}

class _ModReasonBodyState extends State<_ModReasonBody> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final ok = _c.text.trim().length >= 3;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.forumModReasonBody, style: tx.bodyMedium!.copyWith(color: t.mut)),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('forum-mod-reason'),
          controller: _c,
          maxLength: 250,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          style: tx.bodyMedium!.copyWith(color: t.ink),
          decoration: InputDecoration(
            hintText: l.forumModReasonHint,
            counterText: '',
            filled: true,
            fillColor: t.sf,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(BuRadius.sm), borderSide: BorderSide(color: t.bd)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BuRadius.sm), borderSide: BorderSide(color: t.bd)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BuRadius.sm), borderSide: BorderSide(color: t.ink)),
          ),
        ),
        const SizedBox(height: 14),
        BuButton(
          key: const ValueKey('forum-mod-remove-confirm'),
          label: l.forumModRemoveConfirm,
          kind: BuButtonKind.danger,
          onPressed: ok ? () => Navigator.of(context).pop(_c.text.trim()) : null,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

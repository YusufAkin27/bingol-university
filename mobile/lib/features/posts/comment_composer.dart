import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'comment_tile.dart' show kCommentMax;

/// Yorum yazma çubuğu: metin kutusu + ayrı gönder düğmesi, "Yanıtlıyor: @ad ✕" bandı, sayaç ve hata satırı.
class CommentComposer extends StatelessWidget {
  const CommentComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    this.replyingTo,
    this.onCancelReply,
    this.error,
    this.sending = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  /// Yanıtlanan kullanıcının adı (null: kök yorum).
  final String? replyingTo;
  final VoidCallback? onCancelReply;
  final String? error;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Material(
      color: t.sf,
      child: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: t.bd))),
        padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + (keyboard ? 0 : bottom)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (replyingTo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Yanıtlıyor: @$replyingTo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BuType.label.copyWith(color: t.mut)),
                    ),
                    Semantics(
                      button: true,
                      label: 'Yanıtı iptal et',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: onCancelReply,
                        child: SizedBox(width: 32, height: 28, child: Icon(LucideIcons.x, size: 16, color: t.mut)),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (_, v, __) => TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      inputFormatters: [LengthLimitingTextInputFormatter(kCommentMax)],
                      style: BuType.body.copyWith(color: t.ink),
                      decoration: InputDecoration(
                        hintText: replyingTo != null ? 'Yanıtını yaz…' : 'Yorum yaz…',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        counterText: '',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (_, v, __) {
                    final ok = v.text.trim().isNotEmpty && !sending;
                    return BuIconButton(
                      icon: LucideIcons.send,
                      filled: true,
                      size: 44,
                      tooltip: 'Gönder',
                      onTap: ok ? onSend : null,
                    );
                  },
                ),
              ],
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, v, __) {
                final len = v.text.length;
                final warn = len >= kCommentMax - 200;
                if (!warn && error == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Row(
                    children: [
                      if (error != null)
                        Expanded(child: Text(error!, style: BuType.caption.copyWith(color: t.danger)))
                      else
                        const Spacer(),
                      if (warn)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text('$len/$kCommentMax',
                              style: BuType.caption.copyWith(color: len >= kCommentMax ? t.danger : t.mut)),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

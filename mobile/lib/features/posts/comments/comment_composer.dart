import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/locale_controller.dart';
import '../../../core/session.dart';
import '../../../widgets/bu.dart';
import '../post_models.dart';
import 'comment_models.dart';

/// Sabit alt yazma çubuğu: kendi avatarın + "Yorum ekle…" alanı + gönder düğmesi (boşken pasif). Yanıtlarken üstte
/// "X kişisine yanıt veriliyor" çipi + kapat. Kalan karakter sayacı yalnız son [kCommentCounterAt] karakterde görünür.
/// Alan metni [controller]'da durur; gönderim [onSend] ile üst katmana bırakılır.
class CommentComposer extends StatelessWidget {
  const CommentComposer({
    super.key,
    required this.session,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    this.replyingToName,
    this.onCancelReply,
    this.sending = false,
  });

  final Session session;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final String? replyingToName;
  final VoidCallback? onCancelReply;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.sf3, border: Border(top: BorderSide(color: t.bd, width: .5))),
      child: SafeArea(
        top: false,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, v, _) {
            final len = v.text.length;
            final can = v.text.trim().isNotEmpty && len <= kCommentMaxLength && !sending;
            final left = kCommentMaxLength - len;
            return Column(mainAxisSize: MainAxisSize.min, children: [
              if (replyingToName != null)
                Container(
                  key: const ValueKey('commentReplyChip'),
                  margin: const EdgeInsetsDirectional.fromSTEB(BuSpace.page, 8, BuSpace.page, 0),
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.pill)),
                  child: Row(children: [
                    Expanded(
                      child: Text(l.pcmReplyingTo(replyingToName!),
                          key: const ValueKey('commentReplyingTo'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(color: t.mut)),
                    ),
                    IconButton(
                      key: const ValueKey('commentReplyChipClose'),
                      tooltip: l.postComposeClose,
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      padding: EdgeInsets.zero,
                      icon: Icon(BuIcons.x, size: 16, color: t.mut),
                      onPressed: onCancelReply,
                    ),
                  ]),
                ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(BuSpace.page, 8, 4, 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ValueListenableBuilder<String?>(
                      valueListenable: session.avatarUrl,
                      builder: (_, url, __) =>
                          BuAvatar(name: session.displayName, url: url, size: 32, headers: postAuthHeaders(session)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Stack(alignment: AlignmentDirectional.bottomEnd, children: [
                      TextField(
                        key: const ValueKey('commentInput'),
                        controller: controller,
                        focusNode: focusNode,
                        minLines: 1,
                        maxLines: 4,
                        inputFormatters: [LengthLimitingTextInputFormatter(kCommentMaxLength)],
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.newline,
                        style: tt.bodyMedium?.copyWith(color: t.ink),
                        decoration: InputDecoration(
                          hintText: l.pcmWriteHint,
                          isDense: true,
                          filled: true,
                          fillColor: t.sf2,
                          contentPadding: EdgeInsetsDirectional.fromSTEB(14, 12, left <= kCommentCounterAt ? 44 : 14, 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: t.bd)),
                        ),
                      ),
                      if (left <= kCommentCounterAt)
                        PositionedDirectional(
                          end: 12,
                          bottom: 12,
                          child: Semantics(
                            label: l.pcmCharsLeft('$left'),
                            excludeSemantics: true,
                            child: Text('$left',
                                key: const ValueKey('commentCounter'),
                                style: tt.labelSmall?.copyWith(color: left <= 10 ? t.danger : t.mut)),
                          ),
                        ),
                    ]),
                  ),
                  IconButton(
                    key: const ValueKey('commentSend'),
                    tooltip: l.kesCommentsSend,
                    constraints: const BoxConstraints(minWidth: BuSize.touch, minHeight: BuSize.touch),
                    icon: Icon(BuIcons.send, size: 22, color: can ? t.pr : t.mut.withValues(alpha: .6)),
                    onPressed: can ? onSend : null,
                  ),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

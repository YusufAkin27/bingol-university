import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/icons/bu_icons.dart';
import '../../../../core/locale_controller.dart';
import '../../../../core/theme.dart';
import '../../../../core/theme/bu_motion.dart';
import '../../../../widgets/bu_pressable.dart';
import '../../data/forum_api.dart';

/// Yorum metni üst sınırı (sunucuyla aynı). Aşılınca metin sessizce kesilir; sınıra yaklaşınca sayaç görünür.
const int kCommentMaxLength = 4000;
const int _counterFrom = 3600;

/// Klavyeye uyumlu sabit yorum yazma alanı. Üç kip:
///
/// * normal: üst düzey yorum;
/// * yanıt ([replyName] dolu): "X kişisine yanıt veriyorsun" bandı + iptal;
/// * düzenleme ([editing] true): metin editöre gelir, gönder düğmesi Kaydet olur, anonim anahtarı gizlenir.
///
/// Anonim yazma AYRI bir anahtardır (varsayılan kapalı; gönderimden sonra kapanır, konu anonim olsa da
/// otomatik açılmaz). Gönderirken düğme dönen çember olur ve ikinci dokunuş yok sayılır; aynı niyet için tek
/// `Idempotency-Key` üretilir (hatada aynı metinle yeniden denemede çift yorum olmaz). Hata olursa metin KALIR.
class CommentComposer extends StatefulWidget {
  const CommentComposer({
    super.key,
    required this.locked,
    required this.onSend,
    required this.onSave,
    required this.onError,
    this.replyName,
    this.editing = false,
    this.editText,
    this.onCancelTarget,
    this.threadReplyName,
  });

  /// Kilitli konu: alan pasif, kilit satırı gösterilir.
  final bool locked;

  /// Yeni yorum/yanıt gönder; hata fırlatırsa metin korunur.
  final Future<void> Function(String body, bool anonymous, String key) onSend;

  /// Düzenlemeyi kaydet.
  final Future<void> Function(String body) onSave;
  final void Function(Object error) onError;

  /// Yanıtlanan kişinin adı (null = üst düzey yorum).
  final String? replyName;

  /// Zincir ekranında varsayılan hedef (kök yorumun yazarı): bandı gösterir ama iptal edilemez.
  final String? threadReplyName;

  final bool editing;

  /// Düzenleme kipine girerken editöre konacak metin.
  final String? editText;

  /// Yanıt/düzenleme hedefini bırak.
  final VoidCallback? onCancelTarget;

  @override
  State<CommentComposer> createState() => CommentComposerState();
}

class CommentComposerState extends State<CommentComposer> {
  final TextEditingController _c = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _anon = false;
  bool _sending = false;
  String? _key;

  bool get _hasText => _c.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    if (widget.editing && widget.editText != null) _c.text = widget.editText!;
  }

  /// Dışarıdan odak iste (Yanıtla / Düzenle sonrası klavye açılır).
  void focus() => _focus.requestFocus();

  String get text => _c.text;

  @override
  void didUpdateWidget(CommentComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editing && (!oldWidget.editing || widget.editText != oldWidget.editText)) {
      _c.text = widget.editText ?? '';
      _c.selection = TextSelection.collapsed(offset: _c.text.length);
      _key = null;
      _focus.requestFocus();
    } else if (!widget.editing && oldWidget.editing) {
      // Düzenleme bırakıldı: editördeki düzenleme metni yeni yorum taslağı olmasın.
      _c.clear();
    }
    if (widget.replyName != oldWidget.replyName) {
      _key = null;
      if (widget.replyName != null) _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending || !_hasText || widget.locked) return;
    final text = _c.text.trim();
    setState(() => _sending = true); // eşzamanlı: ikinci dokunuş geçmez
    try {
      if (widget.editing) {
        await widget.onSave(text);
        if (!mounted) return;
        _c.clear();
      } else {
        final key = _key ??= ForumApi.newIdempotencyKey();
        await widget.onSend(text, _anon, key);
        if (!mounted) return;
        _c.clear();
        _key = null;
        _anon = false;
      }
    } catch (e) {
      // Metin kaybolmaz; anahtar korunur (aynı niyetin yeniden denemesi).
      if (mounted) widget.onError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;

    if (widget.locked) {
      return DecoratedBox(
        decoration: BoxDecoration(color: t.bg, border: Border(top: BorderSide(color: t.bd))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Icon(BuIcons.lock, size: 18, color: t.mut),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(l.forumCommentLockedHint,
                      key: const ValueKey('commentLockedHint'), style: tx.bodyMedium!.copyWith(color: t.mut))),
            ]),
          ),
        ),
      );
    }

    final bannerText = widget.editing
        ? l.forumCommentEditingBanner
        : widget.replyName != null
            ? l.forumCommentReplyingTo(widget.replyName!)
            : widget.threadReplyName != null
                ? l.forumCommentReplyingTo(widget.threadReplyName!)
                : null;
    final cancellable = widget.editing || widget.replyName != null;
    final showExtras = !widget.editing && (_focus.hasFocus || _hasText || _anon);
    final len = _c.text.length;

    return DecoratedBox(
      decoration: BoxDecoration(color: t.bg, border: Border(top: BorderSide(color: t.bd))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 8, 6),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AnimatedSize(
              duration: BuMotion.of(context, const Duration(milliseconds: 180)),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: bannerText == null
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      key: const ValueKey('commentTargetBanner'),
                      margin: const EdgeInsetsDirectional.only(bottom: 6, end: 4),
                      padding: const EdgeInsetsDirectional.only(start: 12),
                      decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Icon(widget.editing ? BuIcons.pencil : BuIcons.reply, size: 16, color: t.onSoft),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(bannerText,
                                maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.onSoft)),
                          ),
                        ),
                        if (cancellable)
                          Semantics(
                            button: true,
                            label: l.forumCommentCancelTarget,
                            excludeSemantics: true,
                            child: InkResponse(
                              key: const ValueKey('commentCancelTarget'),
                              onTap: widget.onCancelTarget,
                              radius: 24,
                              child: SizedBox(width: 44, height: 40, child: Center(child: Icon(BuIcons.x, size: 18, color: t.onSoft))),
                            ),
                          )
                        else
                          const SizedBox(width: 12),
                      ]),
                    ),
            ),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('commentField'),
                  controller: _c,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [LengthLimitingTextInputFormatter(kCommentMaxLength)],
                  style: tx.bodyMedium!.copyWith(color: t.ink),
                  onChanged: (_) => setState(() => _key = null),
                  decoration: InputDecoration(
                    hintText: widget.replyName != null || widget.threadReplyName != null ? l.forumCommentHintReply : l.forumCommentHint,
                    hintStyle: tx.bodyMedium!.copyWith(color: t.mut),
                    filled: true,
                    fillColor: t.sf2,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: t.bdStrong)),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _SendButton(
                busy: _sending,
                enabled: _hasText && !_sending,
                editing: widget.editing,
                onTap: _submit,
              ),
            ]),
            AnimatedSize(
              duration: BuMotion.of(context, const Duration(milliseconds: 180)),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !showExtras
                  ? const SizedBox(width: double.infinity)
                  : Row(children: [
                      Expanded(
                        child: InkWell(
                          key: const ValueKey('commentAnonToggle'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: _sending ? null : () => setState(() => _anon = !_anon),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Semantics(
                              toggled: _anon,
                              label: l.forumCommentAnonLabel,
                              excludeSemantics: true,
                              child: Row(children: [
                                const SizedBox(width: 4),
                                Icon(BuIcons.eyeOff, size: 18, color: _anon ? t.prText : t.mut),
                                const SizedBox(width: 8),
                                Flexible(
                                    child: Text(l.forumCommentAnonLabel,
                                        maxLines: 2, style: tx.bodySmall!.copyWith(color: _anon ? t.ink : t.mut))),
                                const SizedBox(width: 8),
                                IgnorePointer(
                                  child: Transform.scale(
                                    scale: .78,
                                    child: Switch(
                                      key: const ValueKey('commentAnonSwitch'),
                                      value: _anon,
                                      onChanged: (_) {},
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ),
                      if (len >= _counterFrom)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: Text(l.forumCommentCounter(len.toString(), kCommentMaxLength.toString()),
                              key: const ValueKey('commentCounter'),
                              style: tx.bodySmall!.copyWith(color: len >= kCommentMaxLength ? t.danger : t.mut)),
                        ),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.busy, required this.enabled, required this.editing, required this.onTap});

  final bool busy;
  final bool enabled;
  final bool editing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final strong = Theme.of(context).brightness == Brightness.light ? t.prPressed : t.pr;
    return Semantics(
      button: true,
      enabled: enabled,
      label: editing ? l.forumCommentSaveEdit : l.forumCommentSend,
      excludeSemantics: true,
      child: BuPressable(
        key: const ValueKey('commentSend'),
        onTap: enabled ? onTap : null,
        enabled: enabled,
        haptic: BuHaptic.light,
        scale: .92,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: BuMotion.of(context, const Duration(milliseconds: 150)),
              width: 40,
              height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: enabled || busy ? strong : t.sf2),
              child: busy
                  ? Padding(
                      padding: const EdgeInsets.all(11),
                      child: CircularProgressIndicator(key: const ValueKey('commentSending'), strokeWidth: 2, color: t.onPr),
                    )
                  : Icon(editing ? BuIcons.check : BuIcons.arrowUp, size: 20, color: enabled ? t.onPr : t.mutSoft),
            ),
          ),
        ),
      ),
    );
  }
}

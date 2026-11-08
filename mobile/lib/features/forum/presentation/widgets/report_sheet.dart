import '../../../chat/emoji_presentation.dart';
import 'package:flutter/material.dart';

import '../../../../core/api.dart';
import '../../../../core/locale_controller.dart';
import '../../../../core/session.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../widgets/bu.dart';
import '../../data/forum_api.dart';
import '../../data/forum_models.dart';

/// Şikâyet nedeni kodları (sunucu `ReportReason`).
const List<String> kForumReportReasons = ['SPAM', 'HARASSMENT', 'PERSONAL_INFO', 'INAPPROPRIATE', 'OTHER'];

/// Forum şikâyet nedeninin dile göre adı.
String forumReportReasonLabel(AppLocalizations l, String code) => switch (code) {
      'SPAM' => l.forumReportReasonSpam,
      'HARASSMENT' => l.forumReportReasonHarassment,
      'PERSONAL_INFO' => l.forumReportReasonPersonalInfo,
      'INAPPROPRIATE' => l.forumReportReasonInappropriate,
      _ => l.forumReportReasonOther,
    };

IconData forumReportReasonIcon(String code) => switch (code) {
      'SPAM' => BuIcons.megaphone,
      'HARASSMENT' => BuIcons.shieldAlert,
      'PERSONAL_INFO' => BuIcons.eyeOff,
      'INAPPROPRIATE' => BuIcons.flag,
      _ => BuIcons.ellipsis,
    };

/// Forum konu/yorum şikâyet alt sayfası. [targetType] `FORUM_TOPIC` | `FORUM_COMMENT`.
///
/// Neden seçilir (zorunlu) + isteğe bağlı not. [offerBlock] açıksa "Bu yazarı da engelle" anahtarı çıkar; yazar
/// anonim olsa bile sunucu `block-author` ucu kimliği sızdırmadan engeller. Şikâyet gönderildiyse `true` döner.
/// Aynı içerik daha önce bildirildiyse (409 `ALREADY_REPORTED`) kısa bir bilgi mesajı çıkar ve sayfa kapanır.
Future<bool> showForumReportSheet(
  BuildContext context,
  Session session, {
  required String targetType,
  required int targetId,
  bool offerBlock = true,
}) async {
  assert(targetType == kForumReportTopic || targetType == kForumReportComment);
  final result = await BuSheet.show<_ReportOutcome>(
    context,
    title: context.l10n.forumReportTitle,
    builder: (_) => _ReportBody(session: session, targetType: targetType, targetId: targetId, offerBlock: offerBlock),
  );
  if (result == null) return false;
  final sent = result == _ReportOutcome.reported || result == _ReportOutcome.reportedAndBlocked;
  if (!context.mounted) return sent;
  final l = context.l10n;
  switch (result) {
    case _ReportOutcome.reported:
      BuToast.show(context, l.forumReportThanks, kind: BuToastKind.success);
    case _ReportOutcome.reportedAndBlocked:
      BuToast.show(context, '${l.forumReportThanks} ${l.forumReportBlocked}', kind: BuToastKind.success);
    case _ReportOutcome.already:
      BuToast.show(context, l.forumReportAlready, kind: BuToastKind.info);
  }
  return sent;
}

enum _ReportOutcome { reported, reportedAndBlocked, already }

class _ReportBody extends StatefulWidget {
  const _ReportBody({required this.session, required this.targetType, required this.targetId, required this.offerBlock});

  final Session session;
  final String targetType;
  final int targetId;
  final bool offerBlock;

  @override
  State<_ReportBody> createState() => _ReportBodyState();
}

class _ReportBodyState extends State<_ReportBody> {
  String? _reason; // ön seçim yok: yanlış neden gönderilmesin
  final _note = EmojiTextEditingController();
  bool _busy = false;
  bool _block = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _busy) return; // çift dokunma: tek istek
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = ForumApi(widget.session);
    try {
      await api.report(widget.targetType, widget.targetId, reason, note: _note.text);
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.status == 409) {
        Navigator.pop(context, _ReportOutcome.already);
        return;
      }
      setState(() {
        _busy = false;
        _error = errorText(e);
      });
      return;
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(e);
        });
      }
      return;
    }
    var blocked = false;
    if (_block) {
      try {
        if (widget.targetType == kForumReportTopic) {
          await api.blockTopicAuthor(widget.targetId);
        } else {
          await api.blockCommentAuthor(widget.targetId);
        }
        blocked = true;
      } catch (_) {
        // Şikâyet gitti; engelleme ayrıca denenebilir (içerik menüsünden). Sessiz geç.
      }
    }
    if (mounted) Navigator.pop(context, blocked ? _ReportOutcome.reportedAndBlocked : _ReportOutcome.reported);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.reportPrompt, style: tx.bodyMedium!.copyWith(color: t.mut)),
        const SizedBox(height: 12),
        for (final code in kForumReportReasons) ...[
          _ReasonRow(
            key: ValueKey('forum-report-reason-$code'),
            code: code,
            selected: _reason == code,
            enabled: !_busy,
            onTap: () => setState(() => _reason = code),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 6),
        TextField(
          key: const ValueKey('forum-report-note'),
          controller: _note,
          maxLength: 250,
          maxLines: 3,
          enabled: !_busy,
          style: tx.bodyMedium!.copyWith(color: t.ink),
          decoration: InputDecoration(
            hintText: l.forumReportNoteHint,
            counterText: '',
            filled: true,
            fillColor: t.sf,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(BuRadius.sm), borderSide: BorderSide(color: t.bd)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BuRadius.sm), borderSide: BorderSide(color: t.bd)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BuRadius.sm), borderSide: BorderSide(color: t.ink)),
          ),
        ),
        if (widget.offerBlock) ...[
          const SizedBox(height: 8),
          Semantics(
            container: true,
            toggled: _block,
            label: '${l.forumReportAlsoBlock}. ${l.forumReportAlsoBlockHint}',
            onTap: _busy ? null : () => setState(() => _block = !_block),
            excludeSemantics: true,
            child: InkWell(
              key: const ValueKey('forum-report-block-toggle'),
              borderRadius: BorderRadius.circular(16),
              onTap: _busy ? null : () => setState(() => _block = !_block),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: BuSize.row),
                child: Row(children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(l.forumReportAlsoBlock, style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
                        const SizedBox(height: 2),
                        Text(l.forumReportAlsoBlockHint, style: tx.bodySmall!.copyWith(color: t.mut)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ExcludeSemantics(child: Switch(value: _block, onChanged: _busy ? null : (v) => setState(() => _block = v))),
                ]),
              ),
            ),
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(liveRegion: true, child: Text(_error!, key: const ValueKey('forum-report-error'), style: tx.bodySmall!.copyWith(color: t.danger))),
          ),
        const SizedBox(height: 14),
        BuButton(
          key: const ValueKey('forum-report-send'),
          label: l.reportSend,
          icon: BuIcons.send,
          busy: _busy,
          onPressed: (_busy || _reason == null) ? null : _submit,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({super.key, required this.code, required this.selected, required this.enabled, required this.onTap});

  final String code;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final label = forumReportReasonLabel(l, code);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      label: label,
      onTap: enabled ? onTap : null,
      child: Material(
        color: selected ? t.sf2 : t.sf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BuRadius.sm),
          side: BorderSide(color: selected ? t.ink : t.bd, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(BuRadius.sm),
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: BuSize.row),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                Icon(forumReportReasonIcon(code), size: 18, color: t.ink),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: tx.titleSmall!.copyWith(fontWeight: BuType.emphasisWeight, color: t.ink))),
                const SizedBox(width: 12),
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: t.sf, shape: BoxShape.circle, border: Border.all(color: selected ? t.ink : t.bdStrong, width: selected ? 2 : 1)),
                  child: selected ? Container(width: 10, height: 10, decoration: BoxDecoration(color: t.ink, shape: BoxShape.circle)) : null,
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

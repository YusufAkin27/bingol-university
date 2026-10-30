import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'etkinlik2_widgets.dart';

/// Katılma isteği formu cevapları.
class Etkinlik2ApplyAnswers {
  const Etkinlik2ApplyAnswers(this.note, this.answers);

  final String? note;
  final List<String> answers;
}

/// Organizatör soru tanımladıysa (400 `ANSWERS_REQUIRED`) cevapları toplar. İptalde `null`.
Future<Etkinlik2ApplyAnswers?> showEtkinlik2ApplySheet(BuildContext context, List<String> questions) {
  return BuSheet.show<Etkinlik2ApplyAnswers>(
    context,
    title: context.l10n.etkinlik2SendRequest,
    subtitle: context.l10n.etkinlik2RequestHint,
    builder: (c) => _ApplySheet(questions: questions),
  );
}

class _ApplySheet extends StatefulWidget {
  const _ApplySheet({required this.questions});

  final List<String> questions;

  @override
  State<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<_ApplySheet> {
  final _note = TextEditingController();
  late final List<TextEditingController> _answers = [for (final _ in widget.questions) TextEditingController()];
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    for (final c in _answers) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final answers = _answers.map((c) => c.text.trim()).toList();
    if (answers.any((a) => a.isEmpty)) {
      setState(() => _error = context.l10n.etkinlik2AnswerRequired);
      return;
    }
    final note = _note.text.trim();
    Navigator.pop(context, Etkinlik2ApplyAnswers(note.isEmpty ? null : note, answers));
  }

  InputDecoration _dec(BuildContext context, {String? hint}) {
    final t = context.bu;
    return InputDecoration(
      counterText: '',
      hintText: hint,
      hintStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(color: t.mut),
      filled: true,
      fillColor: t.sf2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(BuRadius.sm + 2), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BuRadius.sm + 2), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BuRadius.sm + 2), borderSide: BorderSide(color: t.pr, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < widget.questions.length; i++) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 4),
          child: Text(widget.questions[i], style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
        ),
        TextField(
          key: ValueKey('et2-answer-$i'),
          controller: _answers[i],
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          style: tx.bodyLarge!.copyWith(color: t.ink),
          decoration: _dec(context, hint: l.p15AnswerHint),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 12),
      ],
      Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(l.etkinlik2NoteLabel, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
      ),
      TextField(
        key: const ValueKey('et2-note'),
        controller: _note,
        maxLength: 500,
        minLines: 1,
        maxLines: 3,
        style: tx.bodyLarge!.copyWith(color: t.ink),
        decoration: _dec(context, hint: l.p15NoteHint),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Container(
            key: const ValueKey('et2-apply-error'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: t.danger.withValues(alpha: .12), borderRadius: BorderRadius.circular(BuRadius.sm)),
            child: Row(children: [
              Icon(LucideIcons.circleAlert, size: 18, color: t.danger),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: t.danger))),
            ]),
          ),
        ),
      ],
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          flex: 4,
          child: Et2GreyButton(key: const ValueKey('et2-apply-cancel'), label: l.eventListDismiss, onPressed: () => Navigator.pop(context)),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 7,
          child: BuButton(key: const ValueKey('et2-apply-send'), label: l.etkinlik2SendRequest, onPressed: _submit),
        ),
      ]),
      const SizedBox(height: 8),
    ]);
  }
}

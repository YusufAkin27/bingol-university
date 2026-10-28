import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'etkinlik2_widgets.dart';

/// Katılma isteği formu cevapları.
class Etkinlik2ApplyAnswers {
  const Etkinlik2ApplyAnswers(this.note, this.answers);

  final String? note;
  final List<String> answers;
}

/// Organizatör soru tanımladıysa (400 `ANSWERS_REQUIRED`) cevapları toplar. İptalde `null`.
Future<Etkinlik2ApplyAnswers?> showEtkinlik2ApplySheet(BuildContext context, List<String> questions) {
  return showModalBottomSheet<Etkinlik2ApplyAnswers>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.bu.sf,
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
  late final List<TextEditingController> _answers =
      [for (final _ in widget.questions) TextEditingController()];
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

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.etkinlik2SendRequest, style: BuType.heading.copyWith(color: t.ink)),
            const SizedBox(height: 12),
            for (var i = 0; i < widget.questions.length; i++) ...[
              Et2FieldLabel(widget.questions[i]),
              TextField(
                key: ValueKey('et2-answer-$i'),
                controller: _answers[i],
                maxLength: 500,
                minLines: 1,
                maxLines: 3,
                style: BuType.body.copyWith(color: t.ink),
                decoration: const InputDecoration(counterText: ''),
              ),
              const SizedBox(height: 10),
            ],
            Et2FieldLabel(l.etkinlik2NoteLabel),
            TextField(
              controller: _note,
              maxLength: 500,
              minLines: 1,
              maxLines: 3,
              style: BuType.body.copyWith(color: t.ink),
              decoration: const InputDecoration(counterText: ''),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: BuType.label.copyWith(color: t.danger)),
            ],
            const SizedBox(height: 14),
            BuButton(label: l.etkinlik2SendRequest, onPressed: _submit),
          ]),
        ),
      ),
    );
  }
}

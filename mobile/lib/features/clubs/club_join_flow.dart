import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'club_ref_widgets.dart';

/// Kulübe katılım akışı: onaylı kulüplerde önce katılım soruları sorulur.
/// Dönüş: sunucunun verdiği durum ('ACTIVE' | 'PENDING'); kullanıcı vazgeçtiyse null.
/// Hata durumunda [ApiError] fırlatır (çağıran gösterir).
Future<String?> joinClubFlow(
  BuildContext context,
  Session session, {
  required int communityId,
  required String clubName,
  required bool needsApproval,
}) async {
  List<Map<String, dynamic>> questions = const [];
  if (needsApproval) {
    // Soru listesi okunamazsa (ör. ağ) katılım yine denenir; sunucu ANSWERS_REQUIRED derse hata gösterilir.
    try {
      final r = await session.api.get('/communities/$communityId/join-questions');
      if (r is List) {
        questions = r.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>>? answers;
  if (questions.isNotEmpty) {
    if (!context.mounted) return null;
    answers = await BuSheet.show<List<Map<String, dynamic>>>(
      context,
      builder: (_) => _JoinQuestionsSheet(clubName: clubName, questions: questions),
    );
    if (answers == null) return null;
  }

  final res = await session.api.post(
    '/communities/$communityId/join',
    answers == null ? null : {'answers': answers},
  );
  final st = res is Map ? res['status']?.toString() : null;
  return st ?? (needsApproval ? 'PENDING' : 'ACTIVE');
}

class _JoinQuestionsSheet extends StatefulWidget {
  const _JoinQuestionsSheet({required this.clubName, required this.questions});

  final String clubName;
  final List<Map<String, dynamic>> questions;

  @override
  State<_JoinQuestionsSheet> createState() => _JoinQuestionsSheetState();
}

class _JoinQuestionsSheetState extends State<_JoinQuestionsSheet> {
  late final List<TextEditingController> _ctrls =
      List.generate(widget.questions.length, (_) => TextEditingController());
  bool _showErrors = false;
  static const _max = 500;

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (_ctrls.any((c) => c.text.trim().isEmpty)) {
      setState(() => _showErrors = true);
      return;
    }
    Navigator.pop(context, [
      for (var i = 0; i < _ctrls.length; i++)
        {'questionId': widget.questions[i]['id'], 'answer': _ctrls[i].text.trim()},
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: Text(l10n.clubMgmtJoinTitle, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800))),
                  const SizedBox(height: 4),
                  Text(l10n.clubMgmtJoinAdminsSee(widget.clubName), style: tx.bodyMedium!.copyWith(color: t.mut)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const ClubIconBox(icon: LucideIcons.lock, size: 40, circle: true),
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < widget.questions.length; i++) ...[
          Text.rich(
            TextSpan(children: [
              TextSpan(text: (widget.questions[i]['question'] ?? '').toString()),
              TextSpan(text: ' *', style: TextStyle(color: t.pr)),
            ]),
            style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrls[i],
            maxLength: _max,
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            style: tx.bodyLarge!.copyWith(color: t.ink),
            decoration: InputDecoration(
              hintText: l10n.clubMgmtAnswerHint,
              counterText: '',
              errorText: _showErrors && _ctrls[i].text.trim().isEmpty ? l10n.clubMgmtQuestionRequired : null,
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 4, end: 4, bottom: 12),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text('${_ctrls[i].text.length} / $_max', style: tx.labelSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.md)),
          child: Row(
            children: [
              ExcludeSemantics(child: Icon(LucideIcons.info, size: 18, color: t.mut)),
              const SizedBox(width: 10),
              Expanded(child: Text(l10n.p12JoinNote, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.35))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(flex: 10, child: ClubBtn(label: l10n.clubMgmtCancel, onPressed: () => Navigator.pop(context))),
            const SizedBox(width: 12),
            Expanded(flex: 14, child: ClubBtn(label: l10n.clubMgmtSendRequest, icon: LucideIcons.send, kind: ClubBtnKind.primary, onPressed: _submit)),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

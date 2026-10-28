import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../core/typography.dart';
import 'kulup_widgets.dart';

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
    answers = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.bu.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
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
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tutamaç
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: t.bd, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Semantics(
              header: true,
              child: Text(l10n.clubMgmtJoinTitle, style: BuType.title.copyWith(fontSize: 19.5, color: t.ink)),
            ),
            const SizedBox(height: 4),
            Text(l10n.clubMgmtJoinAdminsSee(widget.clubName), style: BuType.caption.copyWith(fontSize: 12.5, color: t.mut)),
            const SizedBox(height: 14),
            for (var i = 0; i < widget.questions.length; i++) ...[
              Text((widget.questions[i]['question'] ?? '').toString(),
                  style: BuType.bodyStrong.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
              const SizedBox(height: 6),
              TextField(
                controller: _ctrls[i],
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_showErrors) setState(() {});
                },
                style: BuType.body.copyWith(fontSize: 14.5, color: t.ink),
                decoration: kulupField(
                  context,
                  hint: l10n.kulupdetayAnswerHint,
                  error: _showErrors && _ctrls[i].text.trim().isEmpty ? l10n.kulupdetayRequired : null,
                  pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  flex: 10,
                  child: BuButton(label: l10n.clubMgmtCancel, kind: BuButtonKind.outline, onPressed: () => Navigator.pop(context)),
                ),
                const SizedBox(width: 10),
                Expanded(flex: 14, child: BuButton(label: l10n.kulupdetaySendRequest, onPressed: _submit)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

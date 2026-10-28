import 'package:flutter/material.dart';

import '../core/locale_controller.dart';
import '../core/session.dart';
import '../l10n/app_localizations.dart';
import '../core/theme.dart';
import 'bu_widgets.dart';
import '../core/typography.dart';

/// İçerik/kullanıcı raporlama alt sayfası. Sayfalar yalnızca [ReportSheet.show] çağırır.
/// Hedef türleri backend `ReportTargetHandler` ile aynı: USER, POST, COMMUNITY, EVENT (mesajlar için
/// `POST /messages/{id}/report` kullanılır: [ReportSheet.showForMessage]).
abstract final class ReportSheet {
  static const reasons = [
    ('SPAM', 'Spam veya reklam'),
    ('HARASSMENT', 'Taciz veya zorbalık'),
    ('INAPPROPRIATE', 'Uygunsuz içerik'),
    ('IMPERSONATION', 'Başkasını taklit'),
    ('OTHER', 'Diğer'),
  ];

  /// Sebep kodunun dile göre adı.
  static String reasonLabel(AppLocalizations l, String code) => switch (code) {
        'SPAM' => l.reportReasonSpam,
        'HARASSMENT' => l.reportReasonHarassment,
        'INAPPROPRIATE' => l.reportReasonInappropriate,
        'IMPERSONATION' => l.reportReasonImpersonation,
        'OTHER' => l.reportReasonOther,
        _ => code,
      };

  static Future<void> show(
    BuildContext context,
    Session session, {
    required String targetType,
    required int targetId,
    String? title,
  }) =>
      _open(context, session, title, false, (reason, details) => session.api.post(
            '/reports',
            {'targetType': targetType, 'targetId': targetId, 'reason': reason, if (details.isNotEmpty) 'note': details},
          ));

  static Future<void> showForMessage(BuildContext context, Session session, {required int messageId}) =>
      _open(context, session, null, true, (reason, details) => session.api.post(
            '/messages/$messageId/report',
            {'reason': reason, if (details.isNotEmpty) 'note': details},
          ));

  static Future<void> _open(
    BuildContext context,
    Session session,
    String? title,
    bool forMessage,
    Future<dynamic> Function(String reason, String details) send,
  ) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bu.sf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _SheetBody(title: title, forMessage: forMessage, send: send),
    );
    if (done == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.reportThanks)),
      );
    }
  }
}

class _SheetBody extends StatefulWidget {
  const _SheetBody({required this.title, required this.forMessage, required this.send});

  final String? title;
  final bool forMessage;
  final Future<dynamic> Function(String reason, String details) send;

  @override
  State<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<_SheetBody> {
  String _reason = ReportSheet.reasons.first.$1;
  final _details = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.send(_reason, _details.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                  width: 40, height: 4, decoration: BoxDecoration(color: t.bd, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text(widget.title ?? (widget.forMessage ? context.l10n.reportMessageTitle : context.l10n.reportTitle), style: BuType.title.copyWith(color: t.ink)),
            const SizedBox(height: 4),
            Text(context.l10n.reportPrompt, style: BuType.body.copyWith(color: t.mut)),
            const SizedBox(height: 12),
            for (final r in ReportSheet.reasons)
              Semantics(
                inMutuallyExclusiveGroup: true,
                checked: _reason == r.$1,
                child:
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                enabled: !_busy,
                onTap: () => setState(() => _reason = r.$1),
                title: Text(ReportSheet.reasonLabel(context.l10n, r.$1), style: BuType.bodyStrong.copyWith(color: t.ink)),
                trailing: Icon(
                  _reason == r.$1 ? LucideIcons.circleCheck : LucideIcons.circle,
                  color: _reason == r.$1 ? t.pr : t.mut,
                ),
              )),
            const SizedBox(height: 8),
            TextField(
              controller: _details,
              maxLength: 500,
              maxLines: 3,
              enabled: !_busy,
              decoration: InputDecoration(hintText: context.l10n.reportDetailsHint),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: BuType.caption.copyWith(color: t.danger)),
              ),
            BuButton(label: context.l10n.reportSend, busy: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

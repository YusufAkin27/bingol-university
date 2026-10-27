import 'package:flutter/material.dart';

import '../core/session.dart';
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

  static Future<void> show(
    BuildContext context,
    Session session, {
    required String targetType,
    required int targetId,
    String title = 'Şikâyet et',
  }) =>
      _open(context, session, title, (reason, details) => session.api.post(
            '/reports',
            {'targetType': targetType, 'targetId': targetId, 'reason': reason, if (details.isNotEmpty) 'note': details},
          ));

  static Future<void> showForMessage(BuildContext context, Session session, {required int messageId}) =>
      _open(context, session, 'Mesajı şikâyet et', (reason, details) => session.api.post(
            '/messages/$messageId/report',
            {'reason': reason, if (details.isNotEmpty) 'note': details},
          ));

  static Future<void> _open(
    BuildContext context,
    Session session,
    String title,
    Future<dynamic> Function(String reason, String details) send,
  ) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bu.sf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _SheetBody(title: title, send: send),
    );
    if (done == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şikâyetiniz alındı. Teşekkürler.')),
      );
    }
  }
}

class _SheetBody extends StatefulWidget {
  const _SheetBody({required this.title, required this.send});

  final String title;
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
            Text(widget.title, style: BuType.title.copyWith(color: t.ink)),
            const SizedBox(height: 4),
            Text('Sebep seçin. Şikâyetiniz yöneticilere iletilir.', style: TextStyle(color: t.mut)),
            const SizedBox(height: 12),
            for (final r in ReportSheet.reasons)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                enabled: !_busy,
                onTap: () => setState(() => _reason = r.$1),
                title: Text(r.$2, style: TextStyle(fontWeight: FontWeight.w600, color: t.ink)),
                trailing: Icon(
                  _reason == r.$1 ? LucideIcons.circleCheck : LucideIcons.circle,
                  color: _reason == r.$1 ? t.pr : t.mut,
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _details,
              maxLength: 500,
              maxLines: 3,
              enabled: !_busy,
              decoration: const InputDecoration(hintText: 'Ek açıklama (isteğe bağlı)'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: BuType.caption.copyWith(color: t.danger)),
              ),
            BuButton(label: 'Gönder', busy: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import 'destek_widgets.dart';
import 'support_common.dart';
import '../../core/typography.dart';

/// Yeni destek talebi formu. Başarıda `true` ile döner.
class NewTicketPage extends StatefulWidget {
  const NewTicketPage({super.key, required this.session});

  final Session session;

  @override
  State<NewTicketPage> createState() => _NewTicketPageState();
}

class _NewTicketPageState extends State<NewTicketPage> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _category = 'TECHNICAL';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = _subject.text.trim();
    final m = _message.text.trim();
    if (s.isEmpty || m.isEmpty) {
      setState(() => _error = context.l10n.supportFillFields);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.api.post('/support/tickets', {'category': _category, 'subject': s, 'message': m});
      if (!mounted) return;
      supportSnack(context, context.l10n.supportTicketReceived);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = supportError(context, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: context.l10n.supportNewTicketTitle, onBack: () => Navigator.pop(context)),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
            SupportLabel(context.l10n.supportLabelCategory, form: true),
            SupportChoices(
                options: supportTicketCategories(context.l10n), value: _category, onChanged: (v) => setState(() => _category = v)),
            SupportLabel(context.l10n.supportLabelSubject, form: true),
            SupportField(controller: _subject, hint: context.l10n.supportHintSubject, maxLength: 120),
            SupportLabel(context.l10n.supportLabelMessage, form: true),
            SupportField(controller: _message, hint: context.l10n.supportHintIssue, maxLength: 2000, minLines: 5, maxLines: 10),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: BuType.caption.copyWith(color: t.danger)),
              ),
          ]),
        ),
        DestekBottomBar(
          child: BuButton(label: context.l10n.supportSend, icon: LucideIcons.send, busy: _busy, onPressed: _submit),
        ),
      ]),
    );
  }
}

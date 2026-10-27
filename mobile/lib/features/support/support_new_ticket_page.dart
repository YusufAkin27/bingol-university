import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
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
      setState(() => _error = 'Konu ve mesaj alanlarını doldurun.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.api.post('/support/tickets', {'category': _category, 'subject': s, 'message': m});
      if (!mounted) return;
      supportSnack(context, 'Destek talebiniz alındı.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = supportError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: 'Yeni talep', onBack: () => Navigator.pop(context)),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
            const SupportLabel('KATEGORİ', form: true),
            SupportChoices(
                options: supportTicketCategories, value: _category, onChanged: (v) => setState(() => _category = v)),
            const SupportLabel('KONU', form: true),
            SupportField(controller: _subject, hint: 'Kısaca konu', maxLength: 120),
            const SupportLabel('MESAJ', form: true),
            SupportField(controller: _message, hint: 'Sorununuzu anlatın', maxLength: 2000, minLines: 5, maxLines: 10),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: BuType.caption.copyWith(color: t.danger)),
              ),
            const SizedBox(height: 16),
            BuButton(label: 'Gönder', icon: LucideIcons.send, busy: _busy, onPressed: _submit),
          ]),
        ),
      ]),
    );
  }
}

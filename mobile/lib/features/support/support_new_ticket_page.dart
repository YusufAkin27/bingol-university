import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'support_common.dart';

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
  String _category = 'ACCOUNT';
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
      buHaptic(BuHaptic.light);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.api.post('/support/tickets', {'category': _category, 'subject': s, 'message': m});
      if (!mounted) return;
      supportSnack(context, context.l10n.supportTicketReceived, BuToastKind.success);
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
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final label = tx.labelMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800, letterSpacing: Localizations.localeOf(context).languageCode == 'ar' ? 0 : .6);
    Widget caption(String text) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Semantics(header: true, child: Text(text, style: label)),
        );
    return BuPageScaffold(
      title: l.supportNewTicketTitle,
      large: false,
      bottomInset: 24,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              BuCard(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    caption(l.supportLabelCategory),
                    SupportCategoryChips(options: supportTicketCategories(l), value: _category, onChanged: (v) => setState(() => _category = v)),
                    caption(l.supportLabelSubject),
                    SupportField(controller: _subject, hint: l.supportHintSubject, label: l.supportLabelSubject, maxLength: 120, soft: true),
                    caption(l.supportLabelMessage),
                    SupportField(
                      controller: _message,
                      hint: l.supportHintIssue,
                      label: l.supportLabelMessage,
                      maxLength: 2000,
                      minLines: 5,
                      maxLines: 10,
                      counter: true,
                      soft: true,
                    ),
                    AnimatedSize(
                      duration: BuMotion.of(context, BuMotion.medium),
                      curve: BuMotion.emphasized,
                      alignment: Alignment.topCenter,
                      child: _error == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Semantics(
                                liveRegion: true,
                                container: true,
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Padding(padding: const EdgeInsets.only(top: 2), child: Icon(LucideIcons.circleAlert, size: 18, color: t.danger)),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_error!, style: tx.bodyMedium!.copyWith(color: t.danger, height: 1.4))),
                                ]),
                              ),
                            ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              BuButton(label: l.supportSend, icon: LucideIcons.send, busy: _busy, onPressed: _submit),
            ]),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../polls/anket_flat.dart';
import 'support_common.dart';

/// Yeni destek talebi formu (Stitch v3 03): "Konu" (sağda "Zorunlu") + "Mesaj" (sayaç) beyaz alanları, kategori çipleri
/// (API kategori ister; referansta yok, davranış korunur), "Yanıtı bildirim ve e-posta ile alırsın." notu ve `pr`
/// "Gönder". Başarıda `true` ile döner.
class NewTicketPage extends StatefulWidget {
  const NewTicketPage({super.key, required this.session});

  final Session session;

  @override
  State<NewTicketPage> createState() => _NewTicketPageState();
}

class _NewTicketPageState extends State<NewTicketPage> {
  static const _subjectMax = 120;
  static const _messageMax = 2000;

  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _category = 'ACCOUNT';
  bool _busy = false;
  String? _subjectErr;
  String? _messageErr;
  String? _error;

  @override
  void initState() {
    super.initState();
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final s = _subject.text.trim();
    final m = _message.text.trim();
    final subjectErr = s.characters.length < 3 ? l.p68SubjectMin : null;
    final messageErr = m.isEmpty ? l.supportFillFields : null;
    if (subjectErr != null || messageErr != null) {
      setState(() {
        _subjectErr = subjectErr;
        _messageErr = messageErr;
        _error = null;
      });
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
    final field = tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400);
    return BuPageScaffold(
      title: l.supportNewTicketTitle,
      large: false,
      bottomInset: 32,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 0, kAnketPad, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AnketFieldLabel(l.p68SubjectLabel, trailing: l.p68Required),
              Semantics(
                textField: true,
                label: l.p68SubjectLabel,
                child: TextField(
                  controller: _subject,
                  maxLength: _subjectMax,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  style: field,
                  onChanged: (_) {
                    if (_subjectErr != null) setState(() => _subjectErr = null);
                  },
                  decoration: anketFieldDeco(context, hint: l.p68SubjectHint, hasError: _subjectErr != null),
                ),
              ),
              if (_subjectErr != null) AnketFieldError(_subjectErr!),
              AnketFieldLabel(l.p68MessageLabel, top: 18),
              Semantics(
                textField: true,
                label: l.p68MessageLabel,
                child: TextField(
                  controller: _message,
                  maxLength: _messageMax,
                  minLines: 5,
                  maxLines: 10,
                  textCapitalization: TextCapitalization.sentences,
                  style: field,
                  onChanged: (_) {
                    if (_messageErr != null) setState(() => _messageErr = null);
                  },
                  decoration: anketFieldDeco(context,
                      hint: l.p68MessageHint, hasError: _messageErr != null, pad: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 15.5)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text('${_message.text.characters.length}/$_messageMax', style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 13)),
                ),
              ),
              if (_messageErr != null) AnketFieldError(_messageErr!),
              AnketFieldLabel(l.p68CategoryLabel, top: 10, bottom: 0),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final e in supportTicketCategories(l).entries) ...[
                    _CategoryChip(label: e.value, selected: e.key == _category, onTap: () => setState(() => _category = e.key)),
                    const SizedBox(width: 8),
                  ],
                ]),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l.p68ReplyNote, style: tx.bodyMedium!.copyWith(color: t.mut, fontSize: 13.5, height: 1.4)),
              ),
              AnimatedSize(
                duration: BuMotion.of(context, BuMotion.medium),
                curve: BuMotion.emphasized,
                alignment: Alignment.topCenter,
                child: _error == null ? const SizedBox(width: double.infinity) : AnketFieldError(_error!),
              ),
              const SizedBox(height: 26),
              BuButton(label: l.supportSend, busy: _busy, onPressed: _submit),
            ]),
          ),
        ),
      ],
    );
  }
}

/// Kategori çipi: 34 dp görünür; seçili `soft` zemin + `pr` metin, değilse çerçeveli. Dokunma alanı 48 dp.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!selected) buHaptic(BuHaptic.selection);
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: BuMotion.of(context, BuMotion.short),
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? t.soft : t.sf,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: selected ? t.soft : t.bdStrong),
              ),
              child: Center(widthFactor: 1, child: Text(label, maxLines: 1, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: selected ? t.onSoft : t.ink, fontWeight: FontWeight.w500))),
            ),
          ),
        ),
      ),
    );
  }
}

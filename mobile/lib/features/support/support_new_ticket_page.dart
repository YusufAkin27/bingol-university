import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../polls/anket_flat.dart';
import 'support_attachments.dart';
import 'support_common.dart';
import 'support_list_widgets.dart';

/// Yeni destek talebi: kategori kartları, konu, mesaj (sayaçlı), ekler (en çok 4: fotoğraf / 1 video) ve `pr` "Gönder".
/// Ekler seçilir seçilmez yüklenir (önizleme şeridinde ilerleme); gönderimde yalnız kimlikleri gider.
/// Başarıda `true` ile döner. Sunucu `TICKET_OPEN_LIMIT` derse açıklayıcı sınır notu gösterilir.
class NewTicketPage extends StatefulWidget {
  const NewTicketPage({super.key, required this.session, this.attachmentUploader, this.attachments});

  final Session session;

  /// Testlerde sahte yükleyici; verilmezse oturumun `/support/attachments` ucu.
  final SupportAttachmentUploader? attachmentUploader;

  /// Testlerde hazır denetleyici (seçici/yükleyici sahte).
  final SupportAttachmentsController? attachments;

  @override
  State<NewTicketPage> createState() => _NewTicketPageState();
}

class _NewTicketPageState extends State<NewTicketPage> {
  static const _subjectMax = 120;
  static const _messageMax = 2000;

  final _subject = TextEditingController();
  final _message = TextEditingController();
  late final SupportAttachmentsController _att =
      widget.attachments ?? SupportAttachmentsController(uploader: widget.attachmentUploader ?? SessionAttachmentUploader(widget.session));
  String _category = 'ACCOUNT';
  bool _busy = false;
  bool _limitReached = false;
  String? _subjectErr;
  String? _messageErr;
  String? _attErr;
  String? _error;

  @override
  void initState() {
    super.initState();
    _message.addListener(() => setState(() {}));
    _subject.addListener(() => setState(() {}));
    _att.addListener(_onAtt);
  }

  void _onAtt() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _att.removeListener(_onAtt);
    if (widget.attachments == null) _att.dispose();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _addAttachment() async {
    if (_busy) return;
    setState(() => _attErr = null);
    await runSupportAttachFlow(context, _att, onError: (m) {
      if (mounted) setState(() => _attErr = m);
    });
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
    if (_att.hasPending) {
      setState(() => _error = l.supAttWaitUpload);
      return;
    }
    if (_att.hasFailed) {
      setState(() => _error = l.supAttFailedPending);
      buHaptic(BuHaptic.light);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ids = _att.ids;
      await widget.session.api.post('/support/tickets', {
        'category': _category,
        'subject': s,
        'message': m,
        if (ids.isNotEmpty) 'attachmentIds': ids,
      });
      if (!mounted) return;
      _att.clear();
      supportSnack(context, context.l10n.supportTicketReceived, BuToastKind.success);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _limitReached = e is ApiError && e.code == 'TICKET_OPEN_LIMIT';
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
    Widget counter(int n, int max) => Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text('$n/$max', textDirection: TextDirection.ltr, style: tx.bodySmall!.copyWith(color: n >= max ? t.danger : t.mut, fontSize: 13)),
          ),
        );
    final uploading = _att.hasPending;
    return BuPageScaffold(
      title: l.supportNewTicketTitle,
      large: false,
      bottomInset: 32,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 0, kAnketPad, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Yanıtın nereden geleceği baştan söylenir (formun sonunda gözden kaçmasın).
              Container(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 14, 10),
                decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  ExcludeSemantics(child: Icon(BuIcons.bell, size: 18, color: t.onSoft)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(l.p68ReplyNote, style: tx.bodyMedium!.copyWith(color: t.onSoft, height: 1.35))),
                ]),
              ),
              AnketFieldLabel(l.p68CategoryLabel, top: 20),
              SupportChoiceGrid(
                options: supportTicketCategories(l),
                value: _category,
                icons: supportTicketCategoryIcons,
                onChanged: (v) => setState(() => _category = v),
              ),
              AnketFieldLabel(l.p68SubjectLabel, top: 20, trailing: l.p68Required),
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
              if (_subjectErr != null) AnketFieldError(_subjectErr!) else counter(_subject.text.characters.length, _subjectMax),
              AnketFieldLabel(l.p68MessageLabel, top: 10),
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
              if (_messageErr != null) AnketFieldError(_messageErr!) else counter(_message.text.characters.length, _messageMax),
              AnketFieldLabel(l.supAttTitle, top: 10, trailing: '${_att.items.length}/${_att.maxAttachments}'),
              SupportAttachmentStrip(controller: _att, onAdd: _busy ? null : _addAttachment),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(l.supAttLimits, style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 13, height: 1.4)),
              ),
              AnimatedSize(
                duration: BuMotion.of(context, BuMotion.medium),
                curve: BuMotion.emphasized,
                alignment: Alignment.topCenter,
                child: _attErr == null ? const SizedBox(width: double.infinity) : AnketFieldError(_attErr!),
              ),
              AnimatedSize(
                duration: BuMotion.of(context, BuMotion.medium),
                curve: BuMotion.emphasized,
                alignment: Alignment.topCenter,
                child: _limitReached
                    ? const Padding(padding: EdgeInsets.only(top: 16), child: SupportLimitNote(max: kSupportDefaultMaxOpen))
                    : (_error == null ? const SizedBox(width: double.infinity) : AnketFieldError(_error!)),
              ),
              const SizedBox(height: 24),
              BuButton(
                label: uploading ? l.supAttWaitUpload : l.supportSend,
                busy: _busy,
                onPressed: (uploading || _limitReached) ? null : _submit,
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

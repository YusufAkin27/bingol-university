import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'destek_widgets.dart';
import 'support_common.dart';
import '../../core/typography.dart';

/// Talep detayı: mesajlar, yanıt yazma, kapatma. Değişiklik olduysa `true` ile döner.
class SupportTicketPage extends StatefulWidget {
  const SupportTicketPage({super.key, required this.session, required this.ticketId});

  final Session session;
  final int ticketId;

  @override
  State<SupportTicketPage> createState() => _SupportTicketPageState();
}

class _SupportTicketPageState extends State<SupportTicketPage> {
  final _reply = TextEditingController();
  Map<String, dynamic>? _ticket;
  List<Map<String, dynamic>> _messages = [];
  Object? _error;
  bool _loading = true;
  bool _sending = false;
  bool _closing = false;
  bool _changed = false;

  String get _path => '/support/tickets/${widget.ticketId}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final r = await widget.session.api.get(_path) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _ticket = (r['ticket'] as Map?)?.cast<String, dynamic>();
        _messages = ((r['messages'] as List?) ?? []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.session.api.post('$_path/messages', {'text': text});
      _reply.clear();
      _changed = true;
      await _load(silent: true);
    } catch (e) {
      if (mounted) supportSnack(context, supportError(context, e));
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _close() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(context.l10n.supportCloseTicketTitle),
        content: Text(context.l10n.supportCloseTicketBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(context.l10n.supportCancel)),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(context.l10n.supportClose)),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _closing = true);
    try {
      await widget.session.api.post('$_path/close');
      _changed = true;
      await _load(silent: true);
    } catch (e) {
      if (mounted) supportSnack(context, supportError(context, e));
    }
    if (mounted) setState(() => _closing = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final closed = _ticket?['status'] == 'CLOSED';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: Column(children: [
          BuHeader(title: context.l10n.supportTicketTitle, onBack: () => Navigator.pop(context, _changed)),
          Expanded(child: _body(t)),
          if (_ticket != null && !closed) _composer(t),
        ]),
      ),
    );
  }

  Widget _body(BuTokens t) {
    if (_loading) return const LoadingView();
    if (_error != null && _ticket == null) return ErrorView(error: _error!, onRetry: _load);
    final tk = _ticket ?? {};
    final closed = tk['status'] == 'CLOSED';
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
        DestekCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text('${tk['subject'] ?? ''}',
                    style: BuType.heading.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              SupportStatusPill(tk['status'] as String?),
            ]),
            const SizedBox(height: 6),
            Text('${supportTicketCategories(context.l10n)[tk['category']] ?? context.l10n.supportCatOther} · ${niceDate(tk['createdAt'] as String?)}',
                style: BuType.caption.copyWith(color: t.mut)),
          ]),
        ),
        const SizedBox(height: 14),
        for (final m in _messages) _bubble(t, m),
        if (closed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(child: Text(context.l10n.supportTicketClosedNote, style: BuType.caption.copyWith(color: t.mut))),
          )
        else ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: BuButton(
                label: context.l10n.supportCloseTicketTitle,
                kind: BuButtonKind.outline,
                compact: true,
                busy: _closing,
                onPressed: _close),
          ),
        ],
      ]),
    );
  }

  Widget _bubble(BuTokens t, Map<String, dynamic> m) {
    final staff = m['fromStaff'] == true;
    const big = Radius.circular(20), small = Radius.circular(6);
    return Align(
      alignment: staff ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
        child: Column(crossAxisAlignment: staff ? CrossAxisAlignment.start : CrossAxisAlignment.end, children: [
          if (staff)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 6, bottom: 3),
              child: Text(context.l10n.supportStaff, style: BuType.micro.copyWith(color: t.mut, fontWeight: FontWeight.w700)),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: staff ? t.sf : t.pr,
              border: staff ? Border.all(color: t.bd) : null,
              borderRadius: BorderRadiusDirectional.only(
                topStart: big,
                topEnd: big,
                bottomStart: staff ? small : big,
                bottomEnd: staff ? big : small,
              ),
            ),
            child: Text('${m['text'] ?? ''}', style: BuType.body.copyWith(height: 1.45, color: staff ? t.ink : t.onPr)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 3, 6, 0),
            child: Text(relativeTime(m['createdAt'] as String?), style: BuType.micro.copyWith(color: t.mut)),
          ),
        ]),
      ),
    );
  }

  Widget _composer(BuTokens t) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: t.bg, border: Border(top: BorderSide(color: t.bd))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: TextField(
            controller: _reply,
            minLines: 1,
            maxLines: 4,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            style: BuType.body.copyWith(color: t.ink),
            decoration: InputDecoration(
              hintText: context.l10n.supportHintReply,
              hintStyle: BuType.body.copyWith(color: t.mut),
              counterText: '',
              filled: true,
              fillColor: t.sf,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: t.bd, width: 1.5)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: t.pr, width: 1.5)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: t.bd, width: 1.5)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        BuIconButton(icon: LucideIcons.send, filled: true, size: 56, onTap: _sending ? null : _send, tooltip: context.l10n.supportSend),
      ]),
    );
  }
}

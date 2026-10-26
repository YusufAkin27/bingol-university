import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'support_common.dart';

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
      if (mounted) supportSnack(context, supportError(e));
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _close() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Talebi kapat'),
        content: const Text('Bu talep kapatılacak ve yeni yanıt yazamayacaksınız. Devam edilsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Kapat')),
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
      if (mounted) supportSnack(context, supportError(e));
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
          BuHeader(title: 'Talep', onBack: () => Navigator.pop(context, _changed)),
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
        BuCard(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text('${tk['subject'] ?? ''}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: t.ink)),
              ),
              const SizedBox(width: 8),
              SupportStatusPill(tk['status'] as String?),
            ]),
            const SizedBox(height: 6),
            Text('${supportTicketCategories[tk['category']] ?? 'Diğer'} · ${niceDate(tk['createdAt'] as String?)}',
                style: TextStyle(fontSize: 12, color: t.mut)),
          ]),
        ),
        const SizedBox(height: 14),
        for (final m in _messages) _bubble(t, m),
        if (closed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(child: Text('Bu talep kapatıldı.', style: TextStyle(fontSize: 13, color: t.mut))),
          )
        else ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: BuButton(
                label: 'Talebi kapat',
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
    return Align(
      alignment: staff ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: staff ? t.sf : t.pr,
          border: staff ? Border.all(color: t.bd) : null,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (staff) Text('Destek ekibi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: t.pr)),
          Text('${m['text'] ?? ''}', style: TextStyle(fontSize: 14, height: 1.4, color: staff ? t.ink : t.onPr)),
          const SizedBox(height: 4),
          Text(relativeTime(m['createdAt'] as String?),
              style: TextStyle(fontSize: 10, color: staff ? t.mut : t.onPr.withValues(alpha: .8))),
        ]),
      ),
    );
  }

  Widget _composer(BuTokens t) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: t.sf, border: Border(top: BorderSide(color: t.bd))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: TextField(
            controller: _reply,
            minLines: 1,
            maxLines: 4,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(fontSize: 15, color: t.ink),
            decoration: InputDecoration(
              hintText: 'Yanıt yazın',
              hintStyle: TextStyle(color: t.mut),
              counterText: '',
              filled: true,
              fillColor: t.sf2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 8),
        BuIconButton(icon: LucideIcons.send, filled: true, onTap: _sending ? null : _send, tooltip: 'Gönder'),
      ]),
    );
  }
}

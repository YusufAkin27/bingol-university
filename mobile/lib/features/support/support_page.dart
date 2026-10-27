import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'support_common.dart';
import 'support_feedback_page.dart';
import 'support_new_ticket_page.dart';
import 'support_suggestions_page.dart';
import 'support_ticket_page.dart';
import '../../core/typography.dart';

/// Destek: SSS akordeonu, talep oluşturma, taleplerim, geri bildirim ve öneri panosu.
class SupportPage extends StatefulWidget {
  const SupportPage({super.key, required this.session});

  final Session session;

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  List<Map<String, dynamic>> _faq = [];
  final List<Map<String, dynamic>> _tickets = [];
  int? _next;
  bool _loading = true;
  bool _more = false;
  Object? _error;
  String? _ticketsError;
  final Set<int> _open = {};
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = widget.session.api;
    Object? faqErr;
    try {
      final r = await api.get('/faq');
      _faq = (r as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } catch (e) {
      faqErr = e;
    }
    String? tErr;
    try {
      final r = await api.get('/support/tickets?size=10') as Map<String, dynamic>;
      _tickets
        ..clear()
        ..addAll(((r['items'] as List?) ?? []).whereType<Map>().map((e) => e.cast<String, dynamic>()));
      _next = (r['nextCursor'] as num?)?.toInt();
    } catch (e) {
      tErr = supportError(e);
    }
    if (!mounted) return;
    setState(() {
      // Her iki istek de başarısızsa tam ekran hata göster.
      _error = (faqErr != null && tErr != null) ? faqErr : null;
      _ticketsError = tErr;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_next == null || _more) return;
    setState(() => _more = true);
    try {
      final r = await widget.session.api.get('/support/tickets?size=10&cursor=$_next') as Map<String, dynamic>;
      _tickets.addAll(((r['items'] as List?) ?? []).whereType<Map>().map((e) => e.cast<String, dynamic>()));
      _next = (r['nextCursor'] as num?)?.toInt();
    } catch (e) {
      if (mounted) supportSnack(context, supportError(e));
    }
    if (mounted) setState(() => _more = false);
  }

  Future<void> _push(Widget page) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => page));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: 'Destek', onBack: () => Navigator.pop(context)),
        Expanded(child: _body(t)),
      ]),
    );
  }

  Widget _body(BuTokens t) {
    if (_loading) return const LoadingView();
    if (_error != null) {
      return ErrorView(
          error: _error!,
          onRetry: () {
            setState(() => _loading = true);
            _load();
          });
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 14, bottom: 32),
          children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _cta(t)),
        const SupportLabel('SIK SORULAN SORULAR'),
        _faqCard(t),
        const SupportLabel('TALEPLERİM'),
        _ticketsCard(t),
        const SupportLabel('GÖRÜŞÜNÜZÜ PAYLAŞIN'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Expanded(
              child: _shareBtn(t, LucideIcons.messageCircle, 'Geri bildirim',
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => FeedbackPage(session: widget.session)))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _shareBtn(t, LucideIcons.lightbulb, 'Öneri panosu',
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => SuggestionsPage(session: widget.session)))),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _cta(BuTokens t) => Material(
        color: t.pr,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => _push(NewTicketPage(session: widget.session)),
          child: SizedBox(
            height: 52,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(LucideIcons.plus, size: 20, color: t.onPr),
              const SizedBox(width: 8),
              Text('Destek talebi oluştur', style: BuType.bodyStrong.copyWith(color: t.onPr)),
            ]),
          ),
        ),
      );

  Widget _faqCard(BuTokens t) {
    final rows = <Widget>[];
    var idx = 0;
    for (final g in _faq) {
      final cat = g['category'] as String?;
      final items = ((g['items'] as List?) ?? []).whereType<Map>().toList();
      if (cat != null && cat.isNotEmpty && _faq.length > 1) {
        rows.add(Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          decoration: rows.isEmpty ? null : BoxDecoration(border: Border(top: BorderSide(color: t.bd))),
          child: Text(cat.toUpperCase(),
              style: BuType.micro.copyWith(letterSpacing: .5, color: t.pr)),
        ));
      }
      for (final it in items) {
        final i = idx++;
        final open = _open.contains(i);
        rows.add(Container(
          decoration: rows.isEmpty ? null : BoxDecoration(border: Border(top: BorderSide(color: t.bd))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              onTap: () => setState(() => open ? _open.remove(i) : _open.add(i)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Expanded(
                    child: Text('${it['question'] ?? ''}',
                        style: BuType.bodyStrong.copyWith(color: t.ink)),
                  ),
                  const SizedBox(width: 10),
                  Icon(open ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 18, color: t.mut),
                ]),
              ),
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text('${it['answer'] ?? ''}', style: BuType.caption.copyWith(height: 1.5, color: t.mut)),
              ),
          ]),
        ));
      }
    }
    return _card(
      t,
      rows.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: EmptyView(icon: LucideIcons.circleHelp, text: 'Henüz sık sorulan soru yok.'),
            )
          : Column(children: rows),
    );
  }

  Widget _ticketsCard(BuTokens t) {
    if (_ticketsError != null && _tickets.isEmpty) {
      return _card(
        t,
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: Text(_ticketsError!, style: BuType.caption.copyWith(color: t.danger))),
            BuButton(label: 'Yeniden dene', compact: true, kind: BuButtonKind.soft, onPressed: _load),
          ]),
        ),
      );
    }
    if (_tickets.isEmpty) {
      return _card(
        t,
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: EmptyView(icon: LucideIcons.inbox, text: 'Henüz destek talebiniz yok.'),
        ),
      );
    }
    return _card(
      t,
      Column(children: [
        for (var i = 0; i < _tickets.length; i++)
          InkWell(
            onTap: () => _push(SupportTicketPage(session: widget.session, ticketId: (_tickets[i]['id'] as num).toInt())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: i == 0 ? null : BoxDecoration(border: Border(top: BorderSide(color: t.bd))),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${_tickets[i]['subject'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BuType.bodyStrong.copyWith(color: t.ink)),
                    const SizedBox(height: 2),
                    Text(niceDate(_tickets[i]['createdAt'] as String?), style: BuType.caption.copyWith(color: t.mut)),
                  ]),
                ),
                const SizedBox(width: 8),
                SupportStatusPill(_tickets[i]['status'] as String?),
              ]),
            ),
          ),
        if (_more)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          ),
      ]),
    );
  }

  Widget _card(BuTokens t, Widget child) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: t.sf,
          border: Border.all(color: t.bd),
          borderRadius: BorderRadius.circular(22),
        ),
        child: child,
      );

  Widget _shareBtn(BuTokens t, IconData icon, String label, VoidCallback onTap) => Material(
        color: t.sf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: t.bd)),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          onTap: onTap,
          child: SizedBox(
            height: 50,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 18, color: t.pr),
              const SizedBox(width: 8),
              Text(label, style: BuType.label.copyWith(color: t.ink)),
            ]),
          ),
        ),
      );
}

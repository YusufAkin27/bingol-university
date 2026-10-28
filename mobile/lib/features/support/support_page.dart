import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'destek_widgets.dart';
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
  final _search = TextEditingController();
  String _q = '';
  String? _cat; // seçili SSS kategorisi (null = tümü)
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
    _search.dispose();
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
      if (!mounted) return;
      tErr = supportError(context, e);
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
      if (mounted) supportSnack(context, supportError(context, e));
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
        BuHeader(title: context.l10n.supportTitle, onBack: () => Navigator.pop(context)),
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
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: SupportLabel(context.l10n.destekFaqHeading, form: true)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: _searchField(t)),
        const SizedBox(height: 10),
        if (_categories.length > 1) ...[
          DestekChipRow(children: [
            DestekChip(label: context.l10n.destekFaqAll, selected: _cat == null, onTap: () => setState(() => _cat = null)),
            for (final c in _categories)
              DestekChip(label: c, selected: _cat == c, onTap: () => setState(() => _cat = c)),
          ]),
          const SizedBox(height: 10),
        ],
        _faqCard(t),
        SupportLabel(context.l10n.supportMyTickets),
        _ticketsCard(t),
        SupportLabel(context.l10n.supportShareLabel),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Expanded(
              child: _shareBtn(t, LucideIcons.messageCircle, context.l10n.supportFeedbackTitle,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => FeedbackPage(session: widget.session)))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _shareBtn(t, LucideIcons.lightbulb, context.l10n.supportBoard,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => SuggestionsPage(session: widget.session)))),
            ),
          ]),
        ),
      ]),
    );
  }

  List<String> get _categories => [
        for (final g in _faq)
          if (((g['category'] as String?) ?? '').isNotEmpty) g['category'] as String,
      ];

  Widget _searchField(BuTokens t) {
    OutlineInputBorder b(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: 1.5));
    return TextField(
      controller: _search,
      onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
      textInputAction: TextInputAction.search,
      style: BuType.body.copyWith(color: t.ink),
      decoration: InputDecoration(
        hintText: context.l10n.destekFaqSearchHint,
        hintStyle: BuType.body.copyWith(color: t.mut),
        prefixIcon: Icon(LucideIcons.search, size: 18, color: t.mut),
        filled: true,
        fillColor: t.sf,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        enabledBorder: b(t.bd),
        focusedBorder: b(t.pr),
        border: b(t.bd),
      ),
    );
  }

  Widget _cta(BuTokens t) => BuButton(
        label: context.l10n.supportCreateTicket,
        icon: LucideIcons.plus,
        onPressed: () => _push(NewTicketPage(session: widget.session)),
      );

  Widget _faqCard(BuTokens t) {
    final rows = <Widget>[];
    var idx = 0;
    for (final g in _faq) {
      final cat = g['category'] as String?;
      if (_cat != null && cat != _cat) continue;
      final items = ((g['items'] as List?) ?? [])
          .whereType<Map>()
          .where((it) =>
              _q.isEmpty ||
              '${it['question'] ?? ''}'.toLowerCase().contains(_q) ||
              '${it['answer'] ?? ''}'.toLowerCase().contains(_q))
          .toList();
      if (items.isEmpty) continue;
      if (cat != null && cat.isNotEmpty && _faq.length > 1) {
        rows.add(Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          decoration: rows.isEmpty ? null : BoxDecoration(border: Border(top: BorderSide(color: t.bd))),
          child: Text(trUpper(cat),
              style: BuType.micro.copyWith(letterSpacing: .5, color: t.pr)),
        ));
      }
      for (final it in items) {
        final i = idx++;
        final open = _open.contains(i);
        rows.add(Container(
          decoration: rows.isEmpty ? null : BoxDecoration(border: Border(top: BorderSide(color: t.bd))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(
              button: true,
              expanded: open,
              child: InkWell(
              onTap: () => setState(() => open ? _open.remove(i) : _open.add(i)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Expanded(
                    child: Text('${it['question'] ?? ''}',
                        style: BuType.bodyStrong.copyWith(color: t.ink)),
                  ),
                  const SizedBox(width: 10),
                  Icon(open ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 16, color: t.mut),
                ]),
              ),
            )),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text('${it['answer'] ?? ''}', style: BuType.body.copyWith(height: 1.5, color: t.mut)),
              ),
          ]),
        ));
      }
    }
    return _card(
      t,
      rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: EmptyView(
                  icon: LucideIcons.circleHelp,
                  text: _faq.isNotEmpty ? context.l10n.destekFaqNoMatch : context.l10n.supportNoFaq),
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
            BuButton(label: context.l10n.supportRetry, compact: true, kind: BuButtonKind.soft, onPressed: _load),
          ]),
        ),
      );
    }
    if (_tickets.isEmpty) {
      return _card(
        t,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: EmptyView(icon: LucideIcons.inbox, text: context.l10n.supportNoTickets),
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: BuType.bodyStrong.copyWith(color: t.ink)),
                    const SizedBox(height: 2),
                    Text('${supportTicketCategories(context.l10n)[_tickets[i]['category']] ?? ''}${_tickets[i]['category'] == null ? '' : ' · '}${niceDate(_tickets[i]['createdAt'] as String?)}', style: BuType.caption.copyWith(color: t.mut)),
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

  Widget _card(BuTokens t, Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: DestekCard(clip: true, child: child),
      );

  Widget _shareBtn(BuTokens t, IconData icon, String label, VoidCallback onTap) => Semantics(
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          excludeFromSemantics: true,
          onTap: onTap,
          child: DestekCard(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 20, color: t.pr),
                const SizedBox(height: 6),
                Text(label, style: BuType.label.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      );
}

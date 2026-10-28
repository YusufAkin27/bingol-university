import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'destek_widgets.dart';
import 'support_common.dart';
import 'support_feedback_page.dart';
import '../../core/typography.dart';

/// Öneri panosu: yönetici onaylı öneriler, oy verme. Sayfa tabanlı (sort=top|new).
class SuggestionsPage extends StatefulWidget {
  const SuggestionsPage({super.key, required this.session});

  final Session session;

  @override
  State<SuggestionsPage> createState() => _SuggestionsPageState();
}

class _SuggestionsPageState extends State<SuggestionsPage> {
  final List<Map<String, dynamic>> _items = [];
  int _sort = 0; // 0 top, 1 new, 2 benim
  int _page = 0;
  int _totalPages = 1;
  bool _loading = true;
  bool _more = false;
  Object? _error;
  final Set<int> _voting = {};

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset) {
      if (_more || _page + 1 >= _totalPages) return;
      setState(() => _more = true);
    }
    final page = reset ? 0 : _page + 1;
    try {
      // "Benim": kendi geri bildirimlerim (öneri kategorisi); tek sayfa.
      final r = (_sort == 2
          ? await widget.session.api.get('/feedback/mine?size=50')
          : await widget.session.api.get('/suggestions?sort=${_sort == 0 ? 'top' : 'new'}&page=$page&size=20')) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(((r['items'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .where((e) => _sort != 2 || e['category'] == null || e['category'] == 'SUGGESTION'));
        _page = page;
        _totalPages = _sort == 2 ? 1 : (r['totalPages'] as num?)?.toInt() ?? 1;
        _error = null;
        _loading = false;
        _more = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _more = false;
      });
    }
  }

  Future<void> _toggleVote(Map<String, dynamic> s) async {
    final id = (s['id'] as num).toInt();
    if (_voting.contains(id)) return;
    final voted = s['votedByMe'] == true;
    final count = (s['voteCount'] as num?)?.toInt() ?? 0;
    setState(() {
      _voting.add(id);
      s['votedByMe'] = !voted;
      s['voteCount'] = count + (voted ? -1 : 1);
    });
    try {
      final p = '/suggestions/$id/vote';
      if (voted) {
        await widget.session.api.delete(p);
      } else {
        await widget.session.api.put(p);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          s['votedByMe'] = voted;
          s['voteCount'] = count;
        });
        supportSnack(context, supportError(context, e));
      }
    }
    if (mounted) setState(() => _voting.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: context.l10n.supportBoard, onBack: () => Navigator.pop(context)),
        const SizedBox(height: 14),
        DestekChipRow(children: [
          for (final e in [
            (0, context.l10n.destekSortPopular),
            (1, context.l10n.supportSortNew),
            (2, context.l10n.destekSortMine),
          ])
            DestekChip(
              label: e.$2,
              selected: _sort == e.$1,
              onTap: () {
                if (e.$1 == _sort) return;
                setState(() {
                  _sort = e.$1;
                  _loading = true;
                });
                _load(reset: true);
              },
            ),
        ]),
        const SizedBox(height: 12),
        Expanded(child: _body(t)),
        DestekBottomBar(
          child: BuButton(
            label: context.l10n.destekShareSuggestion,
            icon: LucideIcons.plus,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FeedbackPage(session: widget.session, initialCategory: 'SUGGESTION')),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _body(BuTokens t) {
    if (_loading) return const LoadingView();
    if (_error != null && _items.isEmpty) return ErrorView(error: _error!, onRetry: () => _load(reset: true));
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: _items.isEmpty
          ? ListView(children: [
              const SizedBox(height: 80),
              EmptyView(icon: LucideIcons.lightbulb, text: context.l10n.supportNoSuggestions),
            ])
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: _items.length + 1,
              itemBuilder: (_, i) {
                if (i == _items.length) {
                  if (_page + 1 >= _totalPages) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Center(
                        child: BuButton(
                            label: context.l10n.supportMore,
                            kind: BuButtonKind.outline,
                            compact: true,
                            busy: _more,
                            onPressed: _load)),
                  );
                }
                return _card(t, _items[i]);
              },
            ),
    );
  }

  Widget _card(BuTokens t, Map<String, dynamic> s) {
    final voted = s['votedByMe'] == true;
    final resp = s['adminResponse'] as String?;
    final count = (s['voteCount'] as num?)?.toInt() ?? 0;
    final canVote = _sort != 2 && s['id'] != null;
    final fg = voted ? t.pr : t.ink;
    final voteBox = Container(
      width: 52,
      constraints: const BoxConstraints(minHeight: 60),
      decoration: BoxDecoration(
        color: voted ? t.soft : t.sf,
        border: Border.all(color: voted ? t.pr : t.bd, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(LucideIcons.chevronUp, size: 18, color: fg),
        const SizedBox(height: 2),
        Text('$count', style: BuType.bodyStrong.copyWith(color: fg, fontWeight: FontWeight.w800)),
      ]),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DestekCard(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (canVote)
            Semantics(
              button: true,
              toggled: voted,
              label: context.l10n.destekVoteLabel('$count'),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                excludeFromSemantics: true,
                onTap: () => _toggleVote(s),
                child: voteBox,
              ),
            )
          else
            ExcludeSemantics(child: voteBox),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text('${s['subject'] ?? ''}',
                      style: BuType.bodyStrong.copyWith(color: t.ink, fontWeight: FontWeight.w800, height: 1.3)),
                ),
                const SizedBox(width: 8),
                SupportFeedbackPill(s['status'] as String?),
              ]),
              const SizedBox(height: 4),
              Text('${s['message'] ?? ''}', style: BuType.caption.copyWith(height: 1.45, color: t.mut)),
              if (resp != null && resp.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(12)),
                  child: Text(resp, style: BuType.caption.copyWith(height: 1.4, color: t.onSoft)),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

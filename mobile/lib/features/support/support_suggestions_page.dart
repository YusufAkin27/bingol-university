import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'support_common.dart';
import 'support_feedback_page.dart';

/// Öneri panosu: yönetici onaylı öneriler, oy verme. Sayfa tabanlı (sort=top|new).
class SuggestionsPage extends StatefulWidget {
  const SuggestionsPage({super.key, required this.session});

  final Session session;

  @override
  State<SuggestionsPage> createState() => _SuggestionsPageState();
}

class _SuggestionsPageState extends State<SuggestionsPage> {
  final List<Map<String, dynamic>> _items = [];
  int _sort = 0; // 0 top, 1 new
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
      final r = await widget.session.api.get('/suggestions?sort=${_sort == 0 ? 'top' : 'new'}&page=$page&size=20')
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(((r['items'] as List?) ?? []).whereType<Map>().map((e) => e.cast<String, dynamic>()));
        _page = page;
        _totalPages = (r['totalPages'] as num?)?.toInt() ?? 1;
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
        supportSnack(context, supportError(e));
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
        BuHeader(title: 'Öneri panosu', onBack: () => Navigator.pop(context), actions: [
          BuIconButton(
            icon: LucideIcons.plus,
            filled: true,
            tooltip: 'Öneri ekle',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => FeedbackPage(session: widget.session, initialCategory: 'SUGGESTION')),
            ),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: BuSegmented(
            items: const ['En çok oy', 'En yeni'],
            index: _sort,
            onChanged: (i) {
              if (i == _sort) return;
              setState(() {
                _sort = i;
                _loading = true;
              });
              _load(reset: true);
            },
          ),
        ),
        Expanded(child: _body(t)),
      ]),
    );
  }

  Widget _body(BuTokens t) {
    if (_loading) return const LoadingView();
    if (_error != null && _items.isEmpty) return ErrorView(error: _error!, onRetry: () => _load(reset: true));
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: _items.isEmpty
          ? ListView(children: const [
              SizedBox(height: 80),
              EmptyView(icon: LucideIcons.lightbulb, text: 'Henüz yayımlanmış öneri yok. İlk öneriyi siz ekleyin.'),
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
                            label: 'Daha fazla',
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BuCard(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text('${s['subject'] ?? ''}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: t.ink)),
                ),
                const SizedBox(width: 8),
                SupportFeedbackPill(s['status'] as String?),
              ]),
              const SizedBox(height: 6),
              Text('${s['message'] ?? ''}', style: TextStyle(fontSize: 13, height: 1.4, color: t.mut)),
              if (resp != null && resp.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(12)),
                  child: Text(resp, style: TextStyle(fontSize: 13, height: 1.4, color: t.onSoft)),
                ),
              ],
            ]),
          ),
          const SizedBox(width: 12),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _toggleVote(s),
            child: Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: voted ? t.pr : t.sf2, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Icon(LucideIcons.chevronUp, size: 20, color: voted ? t.onPr : t.ink),
                Text('${s['voteCount'] ?? 0}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: voted ? t.onPr : t.ink)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

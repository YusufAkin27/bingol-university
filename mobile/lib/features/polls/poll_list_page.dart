import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'anket_style.dart';
import 'poll_api.dart';
import 'poll_models.dart';
import 'poll_parts.dart';
import 'poll_routes.dart';

/// Anket listesi: Açık | Katıldıklarım | Kapanan, imleçli sayfalama. [communityId] verilirse tek kulüp.
class PollListPage extends StatefulWidget {
  const PollListPage({super.key, required this.session, this.communityId, this.title});

  final Session session;
  final int? communityId;
  final String? title;

  @override
  State<PollListPage> createState() => _PollListPageState();
}

class _PollListPageState extends State<PollListPage> {
  static const _scopes = ['open', 'mine', 'closed'];

  late final PollApi _api = PollApi(widget.session);
  final _scroll = ScrollController();
  final List<Poll> _items = [];
  int _tab = 0;
  int _gen = 0;
  String? _cursor;
  bool _hasMore = false;
  bool _loading = false;
  bool _loaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _load();
    });
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || !_hasMore)) return;
    final gen = reset ? ++_gen : _gen;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _cursor = null;
        _hasMore = false;
        _loaded = false;
      }
    });
    try {
      final page = await _api.list(
          scope: widget.communityId != null ? 'community:${widget.communityId}' : _scopes[_tab], cursor: _cursor);
      if (!mounted || gen != _gen) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loaded = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _select(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    _load(reset: true);
  }

  Future<void> _open(Poll p) async {
    final changed = await openPollDetail(context, widget.session, p.id, initial: p);
    if (changed == true && mounted) _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final labels = [context.l10n.pollTabOpen, context.l10n.pollTabMine, context.l10n.pollTabClosed];
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: widget.title ?? context.l10n.pollListTitle, onBack: () => Navigator.pop(context)),
          const SizedBox(height: 12),
          if (widget.communityId == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _Seg(labels: labels, index: _tab, onSelect: _select),
            ),
          const SizedBox(height: 8),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_error != null && _items.isEmpty) return ErrorView(error: _error!, onRetry: () => _load(reset: true));
    if (!_loaded) return const LoadingView();
    if (_items.isEmpty) {
      final text = switch (_tab) {
        0 => context.l10n.pollEmptyOpen,
        1 => context.l10n.pollEmptyMine,
        _ => context.l10n.pollEmptyClosed,
      };
      return RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [SizedBox(height: 320, child: EmptyView(icon: LucideIcons.vote, text: text))],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: _items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          if (i == _items.length) {
            if (_loading) return const Padding(padding: EdgeInsets.all(12), child: LoadingView());
            if (_error != null) {
              return Center(child: TextButton(onPressed: _load, child: Text(context.l10n.pollLoadFailedRetry)));
            }
            return const SizedBox.shrink();
          }
          final p = _items[i];
          return PollCard(poll: p, onTap: () => _open(p));
        },
      ),
    );
  }
}

/// Segment (An1): beyaz çerçeveli kap, seçili sekme yumuşak kırmızı.
class _Seg extends StatelessWidget {
  const _Seg({required this.labels, required this.index, required this.onSelect});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: t.sf, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.bd)),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              button: true,
              selected: i == index,
              excludeSemantics: true,
              label: labels[i],
              onTap: () => onSelect(i),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                      color: i == index ? t.soft : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                  child: Text(labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: anketText(13, FontWeight.w700, i == index ? t.pr : t.mut)),
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

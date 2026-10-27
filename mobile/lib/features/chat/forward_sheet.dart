import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';

/// Sohbet seçici alt sayfa (İlet): sohbet listesi, arama, en çok [max] sohbet seçilir.
/// Dönüş: seçilen sohbetlerin id listesi; vazgeçilirse null.
Future<List<int>?> showForwardSheet(BuildContext context, ApiClient api,
    {int max = 5}) {
  return showModalBottomSheet<List<int>>(
    context: context,
    backgroundColor: context.bu.sf,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => ForwardSheet(api: api, max: max),
  );
}

class ForwardSheet extends StatefulWidget {
  const ForwardSheet({super.key, required this.api, this.max = 5});

  final ApiClient api;
  final int max;

  @override
  State<ForwardSheet> createState() => _ForwardSheetState();
}

class _ForwardSheetState extends State<ForwardSheet> {
  final _items = <Map<String, dynamic>>[];
  final _selected = <int>[];
  final _q = TextEditingController();
  bool _loading = true;
  Object? _error;
  bool _limit = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.api.get('/conversations?size=50');
      final raw = res is Map ? res['items'] : null;
      final list = (raw is List ? raw : const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(list.where((c) => c['blocked'] != true));
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

  static String titleOf(Map<String, dynamic> c) {
    final peer = c['peer'];
    if ((c['type'] as String?) == 'DIRECT' &&
        peer is Map &&
        peer['displayName'] != null) return '${peer['displayName']}';
    return (c['title'] as String?) ?? 'Sohbet';
  }

  int _id(Map<String, dynamic> c) => (c['id'] as num).toInt();

  void _toggle(Map<String, dynamic> c) {
    final id = _id(c);
    setState(() {
      if (_selected.remove(id)) {
        _limit = false;
      } else if (_selected.length >= widget.max) {
        _limit = true;
      } else {
        _selected.add(id);
        _limit = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final query = _q.text.trim().toLowerCase();
    final shown = _items
        .where((c) => query.isEmpty || titleOf(c).toLowerCase().contains(query))
        .toList();
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .78),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Text('İlet',
                      style: BuType.heading.copyWith(color: t.ink)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: BuSearchField(
                      hint: 'Sohbet ara',
                      controller: _q,
                      onChanged: (_) => setState(() {})),
                ),
                if (_limit)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                    child: Text('En fazla ${widget.max} sohbet seçilebilir.',
                        style: BuType.caption.copyWith(color: t.danger)),
                  ),
                Flexible(child: _list(t, shown)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: BuButton(
                    label: _selected.isEmpty
                        ? 'Gönder'
                        : 'Gönder (${_selected.length})',
                    onPressed: _selected.isEmpty
                        ? null
                        : () =>
                            Navigator.pop(context, List<int>.from(_selected)),
                  ),
                ),
              ]),
        ),
      ),
    );
  }

  Widget _list(BuTokens t, List<Map<String, dynamic>> shown) {
    if (_loading) return const SizedBox(height: 160, child: LoadingView());
    if (_error != null)
      return SizedBox(
          height: 220, child: ErrorView(error: _error!, onRetry: _load));
    if (shown.isEmpty) {
      return const SizedBox(
          height: 160,
          child: EmptyView(
              icon: LucideIcons.messageCircle, text: 'Sohbet bulunamadı.'));
    }
    return ListView.builder(
      shrinkWrap: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: shown.length,
      itemBuilder: (c, i) {
        final conv = shown[i];
        final on = _selected.contains(_id(conv));
        final title = titleOf(conv);
        final direct = (conv['type'] as String?) == 'DIRECT';
        final peer = conv['peer'];
        return InkWell(
          key: ValueKey('fwd-${_id(conv)}'),
          onTap: () => _toggle(conv),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(children: [
              BuAvatar(
                  name: title,
                  url: direct && peer is Map
                      ? peer['avatarUrl'] as String?
                      : null,
                  size: 40,
                  square: !direct,
                  group: !direct),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BuType.bodyStrong.copyWith(color: t.ink))),
              const SizedBox(width: 8),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: on ? t.pr : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: on ? t.pr : t.bd, width: 1.5),
                ),
                child: on
                    ? Icon(LucideIcons.check, size: 12.5, color: t.onPr)
                    : null,
              ),
            ]),
          ),
        );
      },
    );
  }
}

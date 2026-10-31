import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'chat_info_parts.dart';
import 'chat_sheet_parts.dart';
import 'chatlist_widgets.dart';
import '../../core/academic_catalog.dart';

/// Gruba üye ekleme seçici (Stitch 22-4): kişi ara (en az 2 karakter), çoklu seç, seçilenler çip olarak üstte.
/// Dönüş: seçilen kullanıcı kimlikleri; vazgeçilirse null.
Future<List<int>?> showAddMembersSheet(BuildContext context, Session session,
    {required Set<int> exclude, required int max}) {
  return BuSheet.show<List<int>>(
    context,
    scrollable: false,
    maxHeightFactor: .9,
    padding: const EdgeInsets.symmetric(horizontal: kChatInfoMargin),
    builder: (c) => AddMembersSheet(session: session, exclude: exclude, max: max),
  );
}

class AddMembersSheet extends StatefulWidget {
  const AddMembersSheet(
      {super.key, required this.session, required this.exclude, required this.max});

  final Session session;
  final Set<int> exclude;
  final int max;

  @override
  State<AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends State<AddMembersSheet> {
  final _q = TextEditingController();
  Timer? _debounce;
  int _seq = 0;
  List<Map<String, dynamic>> _results = [];

  /// Seçilenler (sıralı); çip için kullanıcı kaydı da tutulur (arama değişse de kalır).
  final _selected = <int, Map<String, dynamic>>{};
  bool _loading = false;
  Object? _error;
  bool _limit = false;
  String _last = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onQuery(String v) {
    _debounce?.cancel();
    final q = v.trim();
    if (q.length < 2) {
      _seq++;
      setState(() {
        _results = [];
        _loading = false;
        _error = null;
        _last = q;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(q));
  }

  Future<void> _run(String q) async {
    final my = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
      _last = q;
    });
    try {
      final res = await widget.session.api
          .get('/users/search?q=${Uri.encodeQueryComponent(q)}&size=20');
      if (!mounted || my != _seq) return;
      final items = (res is Map ? res['items'] : null) as List? ?? const [];
      setState(() {
        _results = items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((u) => !widget.exclude.contains((u['id'] as num?)?.toInt()))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted || my != _seq) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  void _toggle(Map<String, dynamic> u) {
    final id = (u['id'] as num).toInt();
    setState(() {
      if (_selected.remove(id) != null) {
        _limit = false;
      } else if (_selected.length >= widget.max) {
        _limit = true;
      } else {
        _selected[id] = u;
        _limit = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final n = _selected.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ChatSheetHeader(title: l.sohbetyAddMember),
      if (n > 0) ...[
        const SizedBox(height: 4),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final u in _selected.values) ...[
                _SelectedChip(user: u, onRemove: () => _toggle(u)),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
      const SizedBox(height: 4),
      ChatSheetSearch(hint: l.chatMiscUserSearchHint, controller: _q, autofocus: true, onChanged: _onQuery),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChatSheetHint(l.chatMiscGroupMax, warn: _limit),
      ),
      const SizedBox(height: 4),
      Expanded(child: _body()),
      const SizedBox(height: 8),
      BuButton(
        label: n == 0 ? l.sohbetyAddMember : l.sohbetyAddCount(n.toString()),
        icon: LucideIcons.userPlus,
        onPressed: n == 0 ? null : () => Navigator.pop(context, _selected.keys.toList()),
      ),
    ]);
  }

  Widget _body() {
    final l = context.l10n;
    if (_q.text.trim().length < 2) {
      return BuEmptyState(illustration: BuIllustration.search, title: l.chatMiscSearchMin, compact: true);
    }
    if (_loading && _results.isEmpty) return const BuSkeletonList(variant: BuSkeletonVariant.row, itemCount: 5);
    if (_error != null) return BuErrorState(error: _error!, onRetry: () => _run(_last), compact: true);
    if (_results.isEmpty) {
      return BuEmptyState(illustration: BuIllustration.search, title: l.chatMiscNoMatchPeople, compact: true);
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final u = _results[i];
        final id = (u['id'] as num).toInt();
        final name = '${u['displayName'] ?? ''}';
        final sub = context.departmentOrFacultyName(u['department']?.toString(), u['faculty']?.toString());
        return Semantics(
          button: true,
          selected: _selected.containsKey(id),
          child: InkWell(
            key: ValueKey('add-$id'),
            onTap: () => _toggle(u),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 70),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                child: Row(children: [
                  ChatlistAvatar(name: name, url: u['avatarUrl']?.toString(), size: 52, circle: true),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: chatInfoTitle16(context)),
                      if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: chatInfoBody12(context)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  ChatSheetCheck(on: _selected.containsKey(id), filledOff: true),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Seçilen kişi çipi: soluk kırmızı zemin, küçük avatar, ad, kaldırma işareti.
class _SelectedChip extends StatelessWidget {
  const _SelectedChip({required this.user, required this.onRemove});

  final Map<String, dynamic> user;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final name = '${user['displayName'] ?? ''}';
    return Semantics(
      button: true,
      label: '$name, ${context.l10n.chatInfoRemove}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onRemove,
        child: Center(
          child: Container(
            height: 40,
            padding: const EdgeInsetsDirectional.only(start: 6, end: 10),
            decoration: BoxDecoration(color: t.soft, borderRadius: BuRadius.bPill),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              ChatlistAvatar(name: name, url: user['avatarUrl']?.toString(), size: 28, circle: true),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: chatInfoLabel14(context, color: t.onSoft)),
              ),
              const SizedBox(width: 6),
              Icon(LucideIcons.x, size: 16, color: t.onSoft),
            ]),
          ),
        ),
      ),
    );
  }
}

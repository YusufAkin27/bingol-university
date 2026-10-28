import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'sohbety_sheet.dart';
import 'sohbety_widgets.dart';

/// Gruba üye ekleme seçici: kişi ara (en az 2 karakter), çoklu seç.
/// Dönüş: seçilen kullanıcı kimlikleri; vazgeçilirse null.
Future<List<int>?> showAddMembersSheet(BuildContext context, Session session,
    {required Set<int> exclude, required int max}) {
  return showSohbetySheet<List<int>>(
      context, (c) => AddMembersSheet(session: session, exclude: exclude, max: max));
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
  final _selected = <int>[];
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

  void _toggle(int id) {
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
    final n = _selected.length;
    return SohbetySheetFrame(
      title: context.l10n.sohbetyAddMember,
      search: SohbetyField(
          hint: context.l10n.chatMiscUserSearchHint,
          controller: _q,
          autofocus: true,
          onChanged: _onQuery),
      note: _limit
          ? Text(context.l10n.chatMiscGroupMax,
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: t.danger))
          : null,
      body: _body(t),
      footer: SohbetyButton(
        label: n == 0
            ? context.l10n.sohbetyAddMember
            : context.l10n.sohbetyAddCount(n.toString()),
        onPressed: n == 0 ? null : () => Navigator.pop(context, List<int>.from(_selected)),
      ),
    );
  }

  Widget _body(BuTokens t) {
    if (_q.text.trim().length < 2) {
      return EmptyView(icon: LucideIcons.search, text: context.l10n.chatMiscSearchMin);
    }
    if (_loading && _results.isEmpty) return const LoadingView();
    if (_error != null) {
      return ErrorView(error: _error!, onRetry: () => _run(_last));
    }
    if (_results.isEmpty) {
      return EmptyView(icon: LucideIcons.userX, text: context.l10n.chatMiscNoMatchPeople);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        SohbetyCard(children: [
          for (final u in _results)
            SohbetyRow(
              key: ValueKey('add-${u['id']}'),
              minHeight: 64,
              onTap: () => _toggle((u['id'] as num).toInt()),
              child: Row(children: [
                SohbetyAvatar(
                    name: '${u['displayName'] ?? ''}',
                    url: u['avatarUrl']?.toString(),
                    size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: SohbetyTexts(
                      title: '${u['displayName'] ?? ''}',
                      sub: (u['department'] ?? u['faculty'] ?? '').toString()),
                ),
                const SizedBox(width: 8),
                SohbetyCheck(on: _selected.contains((u['id'] as num).toInt())),
              ]),
            ),
        ]),
      ],
    );
  }
}

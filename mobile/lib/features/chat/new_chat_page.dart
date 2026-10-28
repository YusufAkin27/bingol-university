import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../profile/user_profile_page.dart';
import 'chat_detail_page.dart';
import 'contacts_match_page.dart';
import 'sohbety_widgets.dart';

/// Yeni sohbet: kişi ara, bir kişi seç (birebir) ya da birden çok kişi seç (grup).
class NewChatPage extends StatefulWidget {
  const NewChatPage({super.key, required this.session});

  final Session session;

  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  static const _maxMembers = 49; // sunucu: kendiniz hariç en çok 49 üye

  final _search = TextEditingController();
  final _title = TextEditingController();
  Timer? _debounce;
  int _seq = 0;

  List<Map<String, dynamic>> _results = [];
  final List<Map<String, dynamic>> _selected = [];
  bool _searching = false;
  Object? _searchError;
  String _lastQuery = '';
  bool _busy = false;
  String? _createError;
  final _scroll = ScrollController();
  int? _nextCursor;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _debounce?.cancel();
    _search.dispose();
    _title.dispose();
    super.dispose();
  }

  void _onQuery(String v) {
    _debounce?.cancel();
    final q = v.trim();
    if (q.length < 2) {
      _seq++;
      setState(() {
        _results = [];
        _nextCursor = null;
        _loadingMore = false;
        _searching = false;
        _searchError = null;
        _lastQuery = q;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _runSearch(q));
  }

  void _onScroll() {
    if (_nextCursor != null &&
        !_loadingMore &&
        !_searching &&
        _scroll.position.extentAfter < 300) {
      _loadMore();
    }
  }

  List<Map<String, dynamic>> _items(dynamic res) {
    final items = (res is Map ? res['items'] : null) as List? ?? const [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  int? _next(dynamic res) {
    final n = res is Map ? res['nextCursor'] : null;
    return n is num ? n.toInt() : null;
  }

  Future<void> _runSearch(String q) async {
    final my = ++_seq;
    setState(() {
      _searching = true;
      _searchError = null;
      _lastQuery = q;
      _loadingMore = false;
    });
    try {
      final res = await widget.session.api
          .get('/users/search?q=${Uri.encodeQueryComponent(q)}&size=20');
      if (!mounted || my != _seq) return;
      setState(() {
        _results = _items(res);
        _nextCursor = _next(res);
        _searching = false;
      });
    } catch (e) {
      if (!mounted || my != _seq) return;
      setState(() {
        _searching = false;
        _searchError = e;
      });
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null) return;
    final my = _seq;
    setState(() => _loadingMore = true);
    try {
      final res = await widget.session.api.get(
          '/users/search?q=${Uri.encodeQueryComponent(_lastQuery)}&size=20&cursor=$cursor');
      if (!mounted || my != _seq) return;
      setState(() {
        final known = _results.map((u) => u['id']).toSet();
        _results = [
          ..._results,
          ..._items(res).where((u) => !known.contains(u['id']))
        ];
        _nextCursor = _next(res);
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted && my == _seq) setState(() => _loadingMore = false);
    }
  }

  bool _isSelected(Object? id) => _selected.any((u) => u['id'] == id);

  void _toggle(Map<String, dynamic> u) {
    if (_isSelected(u['id'])) {
      setState(() => _selected.removeWhere((s) => s['id'] == u['id']));
      return;
    }
    if (_selected.length >= _maxMembers) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatMiscGroupMax)));
      return;
    }
    setState(() {
      _selected.add(u);
      _createError = null;
    });
  }

  bool _groupMode = false;

  bool get _isGroup =>
      _selected.length > 1 || (_groupMode && _selected.isNotEmpty);

  Future<void> _create() async {
    if (_busy || _selected.isEmpty) return;
    Map<String, dynamic> body;
    if (_isGroup) {
      if (_selected.length < 2) {
        setState(() => _createError = context.l10n.sohbetyGroupMin);
        return;
      }
      final title = _title.text.trim();
      if (title.isEmpty) {
        setState(() => _createError = context.l10n.chatMiscGroupNameRequired);
        return;
      }
      body = {
        'title': title,
        'memberIds': _selected.map((u) => u['id']).toList()
      };
    } else {
      body = {'userId': _selected.first['id']};
    }
    setState(() {
      _busy = true;
      _createError = null;
    });
    try {
      final res = await widget.session.api.post('/conversations', body);
      if (!mounted) return;
      final conv = Map<String, dynamic>.from(res as Map);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) =>
                ChatDetailPage(session: widget.session, conversation: conv)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _createError = errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final n = _selected.length;
    return Scaffold(
      backgroundColor: t.bg,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          SohbetyHeader(
              title: context.l10n.chatMiscNewChat,
              onBack: () => Navigator.pop(context)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SohbetyField(
              hint: context.l10n.chatMiscUserSearchHint,
              controller: _search,
              onChanged: _onQuery,
              autofocus: true,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _NewGroupRow(
              active: _groupMode,
              onTap: () => setState(() {
                _groupMode = !_groupMode;
                _createError = null;
              }),
            ),
          ),
          ContactsEntryRow(session: widget.session),
          if (n > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final u in _selected) _pill(t, u)],
                ),
              ),
            ),
          if (_isGroup || _groupMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _groupCard(t, n),
            ),
          Expanded(child: _list(t)),
          if (_createError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(_createError!,
                  style: TextStyle(
                      fontFamily: 'Inter', fontSize: 13, color: t.danger)),
            ),
          if (n > 0)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 10, 16, 12 + MediaQuery.of(context).padding.bottom),
              child: SohbetyButton(
                label: _isGroup
                    ? context.l10n.chatMiscCreateGroup
                    : context.l10n.chatMiscStartChat,
                busy: _busy,
                onPressed: _create,
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill(BuTokens t, Map<String, dynamic> u) {
    return Material(
      color: t.soft,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => _toggle(u),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 8, 0),
          child: SizedBox(
            height: 36,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text('${u['displayName'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: t.onSoft)),
                ),
                const SizedBox(width: 6),
                Icon(LucideIcons.x, size: 14.5, color: t.onSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _groupCard(BuTokens t, int n) {
    return SohbetyCard(children: [
      Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const SohbetyTile(icon: LucideIcons.users, size: 40, filled: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.chatMiscGroupCardTitle,
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: t.ink)),
                  const SizedBox(height: 2),
                  Text(context.l10n.chatMiscSelectedCount(n.toString()),
                      style: TextStyle(
                          fontFamily: 'Inter', fontSize: 13, color: t.mut)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _title,
                    maxLength: 100,
                    cursorColor: t.pr,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 15, color: t.ink),
                    onChanged: (_) {
                      if (_createError != null) {
                        setState(() => _createError = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: context.l10n.chatMiscGroupName,
                      hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 15, color: t.mut),
                      counterText: '',
                      isDense: true,
                      filled: true,
                      fillColor: t.bg,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: t.bd)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: t.bd)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: t.pr)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(context.l10n.chatMiscMax50,
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: t.mut)),
          ],
        ),
      ),
    ]);
  }

  Widget _list(BuTokens t) {
    if (_search.text.trim().length < 2) {
      return EmptyView(
          icon: LucideIcons.search, text: context.l10n.chatMiscSearchMin);
    }
    if (_searching && _results.isEmpty) return const LoadingView();
    if (_searchError != null) {
      return ErrorView(
          error: _searchError!, onRetry: () => _runSearch(_lastQuery));
    }
    if (_results.isEmpty) {
      return EmptyView(
          icon: LucideIcons.userX, text: context.l10n.chatMiscNoMatchPeople);
    }
    return RefreshIndicator(
      onRefresh: () => _runSearch(_lastQuery),
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        children: [
          SohbetyLabel(sohbetyUpper(context, context.l10n.chatMiscPeopleHeader)),
          SohbetyCard(children: [for (final u in _results) _row(t, u)]),
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4))),
            ),
        ],
      ),
    );
  }

  void _profile(Map<String, dynamic> u) {
    final id = (u['id'] as num?)?.toInt();
    if (id == null) return;
    openUserProfile(context, widget.session,
        userId: id,
        name: u['displayName']?.toString(),
        avatarUrl: u['avatarUrl']?.toString());
  }

  Widget _row(BuTokens t, Map<String, dynamic> u) {
    final on = _isSelected(u['id']);
    final sub = (u['department'] ?? u['faculty'] ?? '').toString();
    return SohbetyRow(
      onTap: () => _toggle(u),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _profile(u),
            child: SohbetyAvatar(
                name: u['displayName']?.toString() ?? '',
                url: u['avatarUrl']?.toString(),
                size: 48),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: SohbetyTexts(title: '${u['displayName'] ?? ''}', sub: sub)),
          if (on || _groupMode) ...[
            const SizedBox(width: 8),
            SohbetyCheck(on: on),
          ],
        ],
      ),
    );
  }
}

/// "Yeni grup" kartı: kırmızı karo, başlık + "En fazla 50 kişi".
class _NewGroupRow extends StatelessWidget {
  const _NewGroupRow({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      selected: active,
      child: SohbetyCard(children: [
        SohbetyRow(
          key: const ValueKey('new-group'),
          minHeight: 64,
          onTap: onTap,
          child: Row(children: [
            const SohbetyTile(icon: LucideIcons.userPlus, size: 40, filled: true),
            const SizedBox(width: 12),
            Expanded(
                child: SohbetyTexts(
                    title: context.l10n.sohbetyNewGroup,
                    sub: context.l10n.sohbetyNewGroupSub)),
            Icon(active ? LucideIcons.check : buDirIcon(context, LucideIcons.chevronRight),
                size: 18, color: active ? t.pr : t.mut),
          ]),
        ),
      ]),
    );
  }
}

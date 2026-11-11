import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/icons/bu_icons.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'chat_detail_page.dart';
import 'department_chat_entry.dart';

class DepartmentChatsPage extends StatefulWidget {
  const DepartmentChatsPage({super.key, required this.session});

  final Session session;

  @override
  State<DepartmentChatsPage> createState() => _DepartmentChatsPageState();
}

class _DepartmentChatsPageState extends State<DepartmentChatsPage> {
  /// Sunucu sayfa boyutu (en çok 50; sunucu tavanı uygular). Dönen sayı < size ise liste biter.
  static const _pageSize = 30;

  final _rooms = <Map<String, dynamic>>[];
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _busy = <String>{};
  Timer? _debounce;

  /// Her yeni arama/yenileme bunu artırır: eski isteğin yanıtı yenisinin üstüne yazılmaz.
  int _gen = 0;
  String _q = '';
  bool _loading = true;
  bool _loadingMore = false;
  bool _moreFailed = false;
  bool _hasMore = true;
  Object? _error;

  DepartmentChatApi get _api => DepartmentChatApi(widget.session);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < 320 &&
        !_loadingMore &&
        !_loading &&
        _hasMore &&
        !_moreFailed &&
        _error == null) {
      _loadMore();
    }
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final q = text.trim();
      if (q == _q || !mounted) return;
      _q = q;
      _load();
    });
  }

  /// İlk sayfa: listeyi sıfırlar (yeni arama / yenile / yeniden dene).
  Future<void> _load() async {
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _moreFailed = false;
      _error = null;
    });
    try {
      final rooms = await _api.rooms(size: _pageSize, q: _q);
      if (!mounted || gen != _gen) return;
      setState(() {
        _rooms
          ..clear()
          ..addAll(rooms);
        _hasMore = rooms.length >= _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_rooms.isEmpty) return;
    final gen = _gen;
    final after = '${_rooms.last['departmentName']}';
    setState(() {
      _loadingMore = true;
      _moreFailed = false;
    });
    try {
      final rooms = await _api.rooms(size: _pageSize, after: after, q: _q);
      if (!mounted || gen != _gen) return;
      setState(() {
        final known = _rooms.map((r) => r['departmentName']).toSet();
        _rooms.addAll(rooms.where((r) => !known.contains(r['departmentName'])));
        _hasMore = rooms.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _loadingMore = false;
        _moreFailed = true;
      });
    }
  }

  /// Katıl/ayrıl sonrası listeyi baştan çekmeden (kaydırma konumu bozulmasın) satırı yerinde günceller.
  void _patch(String name, Map<String, dynamic> changes) {
    final i = _rooms.indexWhere((r) => r['departmentName'] == name);
    if (i < 0) return;
    setState(() => _rooms[i] = {..._rooms[i], ...changes});
  }

  Future<void> _open(Map<String, dynamic> room) async {
    final name = room['departmentName'] as String;
    if (_busy.contains(name)) return;
    setState(() => _busy.add(name));
    try {
      final joined = room['joined'] == true ? room : await _api.join(name);
      if (!mounted) return;
      final id = (joined['conversationId'] as num?)?.toInt();
      widget.session.badges.conversationsDirty.value++;
      _patch(name, {
        'joined': id != null,
        'conversationId': id,
        'memberCount': joined['memberCount'] ?? room['memberCount'],
      });
      if (id == null) return;
      await Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'chat_detail'),
            builder: (_) =>
                ChatDetailPage(session: widget.session, conversation: {
              'id': id,
              'type': 'DEPARTMENT',
              'title': joined['departmentName'] ?? name,
              'memberCount': joined['memberCount'],
            }),
          ));
    } catch (e) {
      if (mounted) BuToast.show(context, errorText(e), kind: BuToastKind.error);
    } finally {
      if (mounted) setState(() => _busy.remove(name));
    }
  }

  Future<void> _leave(Map<String, dynamic> room) async {
    final name = room['departmentName'] as String;
    final id = (room['conversationId'] as num?)?.toInt();
    if (id == null || _busy.contains(name)) return;
    setState(() => _busy.add(name));
    try {
      await _api.leave(id);
      widget.session.badges.conversationsDirty.value++;
      final count = (room['memberCount'] as num?)?.toInt() ?? 1;
      _patch(name, {
        'joined': false,
        'conversationId': null,
        'memberCount': count > 0 ? count - 1 : 0,
      });
    } catch (e) {
      if (mounted) BuToast.show(context, errorText(e), kind: BuToastKind.error);
    } finally {
      if (mounted) setState(() => _busy.remove(name));
    }
  }

  Widget _row(Map<String, dynamic> room) {
    final l = context.l10n;
    final name = room['departmentName'] as String;
    final joined = room['joined'] == true;
    final busy = _busy.contains(name);
    return ListTile(
      key: ValueKey('department-$name'),
      leading: const Icon(BuIcons.graduationCap),
      title: Text(name),
      onTap: busy ? null : () => _open(room),
      trailing: busy
          ? const BuSpinner(size: 24)
          : TextButton(
              onPressed: () => joined ? _leave(room) : _open(room),
              child: Text(joined ? l.chatInfoLeave : l.clubJoin),
            ),
    );
  }

  Widget _body() {
    final l = context.l10n;
    if (_loading) return const BuSkeletonList();
    if (_error != null) {
      return BuErrorState(
          error: _error, title: l.authDepartmentsLoadFailed, onRetry: _load);
    }
    if (_rooms.isEmpty) {
      return BuEmptyState(
          illustration: BuIllustration.search, title: l.chatMiscEmptyNoMatch);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _rooms.length + (_loadingMore || _moreFailed ? 1 : 0),
        itemBuilder: (context, i) {
          if (i < _rooms.length) return _row(_rooms[i]);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
                child: _moreFailed
                    ? TextButton(
                        onPressed: _loadMore, child: Text(l.commonRetry))
                    : const BuSpinner()),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: context.bu.bg,
      body: SafeArea(
          child: Column(children: [
        BuHeader(title: l.deptChatBrowse, onBack: () => Navigator.pop(context)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(l.deptChatBrowseSubtitle,
              style: TextStyle(color: context.bu.mut)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            controller: _search,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l.deptChatSearch,
              prefixIcon: const Icon(BuIcons.search),
            ),
          ),
        ),
        Expanded(child: _body()),
      ])),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'chat_detail_page.dart';
import '../../core/typography.dart';

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
    if (_nextCursor != null && !_loadingMore && !_searching && _scroll.position.extentAfter < 300) {
      _loadMore();
    }
  }

  List<Map<String, dynamic>> _items(dynamic res) {
    final items = (res is Map ? res['items'] : null) as List? ?? const [];
    return items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
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
      final res = await widget.session.api.get('/users/search?q=${Uri.encodeQueryComponent(q)}&size=20');
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
      final res = await widget.session
          .api
          .get('/users/search?q=${Uri.encodeQueryComponent(_lastQuery)}&size=20&cursor=$cursor');
      if (!mounted || my != _seq) return;
      setState(() {
        final known = _results.map((u) => u['id']).toSet();
        _results = [..._results, ..._items(res).where((u) => !known.contains(u['id']))];
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Gruba en çok 50 kişi eklenebilir.')));
      return;
    }
    setState(() {
      _selected.add(u);
      _createError = null;
    });
  }

  bool get _isGroup => _selected.length > 1;

  Future<void> _create() async {
    if (_busy || _selected.isEmpty) return;
    Map<String, dynamic> body;
    if (_isGroup) {
      final title = _title.text.trim();
      if (title.isEmpty) {
        setState(() => _createError = 'Grup adı girin.');
        return;
      }
      body = {'title': title, 'memberIds': _selected.map((u) => u['id']).toList()};
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
        MaterialPageRoute(builder: (_) => ChatDetailPage(session: widget.session, conversation: conv)),
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
          BuHeader(title: 'Yeni sohbet', onBack: () => Navigator.pop(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: BuSearchField(
              hint: 'Ad veya e-posta ile ara',
              controller: _search,
              onChanged: _onQuery,
              autofocus: true,
            ),
          ),
          if (n > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final u in _selected) _pill(t, u)],
                ),
              ),
            ),
          if (_isGroup)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: _groupCard(t, n),
            ),
          Expanded(child: _list(t)),
          if (_createError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(_createError!, style: BuType.caption.copyWith(color: t.danger)),
            ),
          if (n > 0)
            Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 12 + MediaQuery.of(context).padding.bottom),
              child: BuButton(
                label: _isGroup ? 'Grubu oluştur' : 'Sohbet başlat',
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
          padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 6, 0),
          child: SizedBox(
            height: 34,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text('${u['displayName'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BuType.label.copyWith(color: t.onSoft)),
                ),
                const SizedBox(width: 6),
                Icon(LucideIcons.x, size: 16, color: t.onSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _groupCard(BuTokens t, int n) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.bd),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: t.ink, borderRadius: BorderRadius.circular(16)),
            child: Icon(LucideIcons.users, size: 22, color: t.bg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Grup oluştur', style: BuType.bodyStrong.copyWith(color: t.ink)),
                const SizedBox(height: 2),
                Text('$n kişi seçildi', style: BuType.caption.copyWith(color: t.mut)),
                const SizedBox(height: 6),
                TextField(
                  controller: _title,
                  maxLength: 100,
                  style: BuType.body.copyWith(color: t.ink),
                  onChanged: (_) {
                    if (_createError != null) setState(() => _createError = null);
                  },
                  decoration: InputDecoration(
                    hintText: 'Grup adı',
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: t.sf2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    enabledBorder:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.pr)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('en çok 50', style: BuType.label.copyWith(color: t.mut)),
        ],
      ),
    );
  }

  Widget _list(BuTokens t) {
    if (_search.text.trim().length < 2) {
      return const EmptyView(icon: LucideIcons.search, text: 'Kişi aramak için en az 2 karakter yazın.');
    }
    if (_searching && _results.isEmpty) return const LoadingView();
    if (_searchError != null) {
      return ErrorView(error: _searchError!, onRetry: () => _runSearch(_lastQuery));
    }
    if (_results.isEmpty) return const EmptyView(icon: LucideIcons.userX, text: 'Eşleşen kişi bulunamadı.');
    return RefreshIndicator(
      onRefresh: () => _runSearch(_lastQuery),
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        itemCount: _results.length + 1 + (_loadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: Text('KİŞİLER',
                  style: BuType.label.copyWith(letterSpacing: .5, color: t.mut)),
            );
          }
          if (i > _results.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
            );
          }
          return _row(t, _results[i - 1]);
        },
      ),
    );
  }

  Widget _row(BuTokens t, Map<String, dynamic> u) {
    final on = _isSelected(u['id']);
    final sub = (u['department'] ?? u['faculty'] ?? '').toString();
    return InkWell(
      onTap: () => _toggle(u),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            BuAvatar(name: u['displayName']?.toString(), url: u['avatarUrl']?.toString(), size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${u['displayName'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BuType.bodyStrong.copyWith(color: t.ink)),
                  if (sub.isNotEmpty)
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BuType.caption.copyWith(color: t.mut)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: on ? t.pr : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: on ? t.pr : t.bd, width: 2),
              ),
              child: on ? Icon(LucideIcons.check, size: 14, color: t.onPr) : null,
            ),
          ],
        ),
      ),
    );
  }
}

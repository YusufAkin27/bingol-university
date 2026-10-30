import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../profile/user_profile_page.dart';
import 'chat_detail_page.dart';
import 'chat_new_parts.dart';
import 'chatlist_widgets.dart';
import 'contacts_match_page.dart';

/// Yeni sohbet: kişi ara, bir kişi seç (birebir) ya da "Yeni grup" ile birden çok kişi seç (grup). Referans 23.
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
  bool _groupMode = false;

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
      final res = await widget.session.api.get('/users/search?q=${Uri.encodeQueryComponent(_lastQuery)}&size=20&cursor=$cursor');
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

  /// Grup kipinde kişiyi seçer/bırakır; birebir kipte kişiye dokunmak sohbeti doğrudan başlatır.
  void _toggle(Map<String, dynamic> u) {
    if (!_groupMode && _selected.length <= 1) {
      _selected
        ..clear()
        ..add(u);
      _create();
      return;
    }
    if (_isSelected(u['id'])) {
      setState(() => _selected.removeWhere((s) => s['id'] == u['id']));
      return;
    }
    if (_selected.length >= _maxMembers) {
      BuToast.show(context, context.l10n.chatMiscGroupMax);
      return;
    }
    setState(() {
      _selected.add(u);
      _createError = null;
    });
  }

  Future<void> _create() async {
    if (_busy || _selected.isEmpty) return;
    Map<String, dynamic> body;
    if (_groupMode || _selected.length > 1) {
      if (_selected.length < 2) {
        setState(() => _createError = context.l10n.sohbetyGroupMin);
        return;
      }
      final title = _title.text.trim();
      if (title.isEmpty) {
        setState(() => _createError = context.l10n.chatMiscGroupNameRequired);
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
    final l = context.l10n;
    final n = _selected.length;
    final query = _search.text.trim();
    final grouping = _groupMode;
    final showActions = !grouping && query.length < 2;
    return Scaffold(
      backgroundColor: t.bg,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          NcHeader(
            title: grouping ? l.sohbetyNewGroup : l.chatMiscNewChat,
            onBack: () {
              if (grouping) {
                setState(() {
                  _groupMode = false;
                  _selected.clear();
                  _createError = null;
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
          Expanded(
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                if (grouping) ...[
                  if (n > 0) ...[
                    Align(alignment: AlignmentDirectional.centerStart, child: _CountPill(text: l.chatMiscSelectedCount(n.toString()))),
                    const SizedBox(height: 12),
                  ],
                  _selectedCard(t, n),
                  const SizedBox(height: 12),
                  _nameCard(t),
                  const SizedBox(height: 20),
                  _SectionTitle(l.p23AddPeople),
                ],
                ChatlistSearch(hint: l.chatMiscUserSearchHint, controller: _search, onChanged: _onQuery),
                const SizedBox(height: 12),
                if (showActions) ...[
                  NcActionCard(
                    cardKey: const ValueKey('new-group'),
                    tile: NcTile(icon: LucideIcons.userPlus, bg: t.soft, fg: t.onSoft),
                    title: l.sohbetyNewGroup,
                    subtitle: l.sohbetyNewGroupSub,
                    onTap: () => setState(() {
                      _groupMode = true;
                      _createError = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  ContactsEntryRow(session: widget.session),
                  const SizedBox(height: 28),
                ],
                ..._resultWidgets(t),
              ],
            ),
          ),
          if (grouping)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + MediaQuery.paddingOf(context).bottom),
              child: BuButton(label: l.chatMiscCreateGroup, icon: LucideIcons.userPlus, busy: _busy, onPressed: _create),
            ),
        ],
      ),
    );
  }

  /// Seçilen katılımcılar kartı: başlık + "En az 2 kişi" + kaldırılabilir çipler.
  Widget _selectedCard(BuTokens t, int n) {
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return NcCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(l.p23Selected, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700))),
          Text(l.p23MinTwo, style: tx.labelSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w600)),
        ]),
        if (n > 0) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final u in _selected) _chip(t, u)]),
        ],
      ]),
    );
  }

  Widget _chip(BuTokens t, Map<String, dynamic> u) {
    final name = '${u['displayName'] ?? ''}';
    return Material(
      color: t.sf2,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => _toggle(u),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 12, 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            ChatlistAvatar(name: name, url: u['avatarUrl']?.toString(), size: 28, circle: true),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 6),
            Icon(LucideIcons.x, size: 14, color: t.mut),
          ]),
        ),
      ),
    );
  }

  /// Grup adı kartı: etiket + "en çok 50" + alan + doğrulama satırı.
  Widget _nameCard(BuTokens t) {
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return NcCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(l.chatMiscGroupName, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700))),
          Text(l.chatMiscMax50, style: tx.labelSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          maxLength: 100,
          cursorColor: t.pr,
          style: tx.bodyLarge!.copyWith(color: t.ink),
          onChanged: (_) {
            if (_createError != null) setState(() => _createError = null);
          },
          decoration: InputDecoration(
            hintText: l.p23GroupNameHint,
            hintStyle: tx.bodyLarge!.copyWith(color: t.mut),
            prefixIcon: Icon(LucideIcons.notebookPen, size: 18, color: t.mut),
            counterText: '',
            isDense: true,
            filled: true,
            fillColor: t.sf2,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: t.pr, width: 2)),
          ),
        ),
        if (_createError != null) ...[
          const SizedBox(height: 12),
          NcNote(noteKey: const ValueKey('create-error'), icon: LucideIcons.circleAlert, text: _createError!),
        ],
      ]),
    );
  }

  List<Widget> _resultWidgets(BuTokens t) {
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    if (_search.text.trim().length < 2) {
      return [
        Center(
          child: Column(children: [
            NcTile(icon: LucideIcons.textSearch, bg: t.sf2, fg: t.mut, size: 56),
            const SizedBox(height: 14),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.info, size: 15, color: t.mut),
              const SizedBox(width: 6),
              Flexible(child: Text(l.chatMiscSearchMin, textAlign: TextAlign.center, style: tx.bodySmall!.copyWith(color: t.mut))),
            ]),
          ]),
        ),
      ];
    }
    if (_searching && _results.isEmpty) {
      return [
        BuSkeletonScope(
          child: Column(children: [
            for (var i = 0; i < 3; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: NcCard(child: Row(children: [BuSkeleton.circle(48), SizedBox(width: 12), Expanded(child: BuSkeleton(height: 14))])),
              ),
          ]),
        ),
      ];
    }
    if (_searchError != null) {
      return [BuErrorState(error: _searchError!, onRetry: () => _runSearch(_lastQuery), compact: true)];
    }
    if (_results.isEmpty) {
      return [
        NcCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(children: [
            NcTile(icon: LucideIcons.userSearch, bg: t.sf2, fg: t.mut, size: 56),
            const SizedBox(height: 14),
            Text(l.chatMiscNoMatchPeople, textAlign: TextAlign.center, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
          ]),
        ),
      ];
    }
    return [
      if (!_groupMode) NcLabel(trUpper(l.chatMiscPeopleHeader)),
      for (final u in _results) ...[
        _row(t, u),
        const SizedBox(height: 12),
      ],
      if (_loadingMore)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
        ),
    ];
  }

  void _profile(Map<String, dynamic> u) {
    final id = (u['id'] as num?)?.toInt();
    if (id == null) return;
    openUserProfile(context, widget.session, userId: id, name: u['displayName']?.toString(), avatarUrl: u['avatarUrl']?.toString());
  }

  Widget _row(BuTokens t, Map<String, dynamic> u) {
    final on = _isSelected(u['id']);
    final sub = (u['department'] ?? u['faculty'] ?? '').toString();
    return NcPersonRow(
      name: u['displayName']?.toString() ?? '',
      sub: sub,
      avatarUrl: u['avatarUrl']?.toString(),
      onTap: () => _toggle(u),
      onAvatarTap: () => _profile(u),
      trailing: _groupMode ? NcCheck(on: on) : NcPillButton(label: context.l10n.chatMiscStartChat, onTap: () => _toggle(u)),
    );
  }
}

/// "2 kişi seçildi" kırmızı noktalı hap.
class _CountPill extends StatelessWidget {
  const _CountPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bPill),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Küçük harfli bölüm başlığı ("Kişi ekle").
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(text, style: Theme.of(context).textTheme.titleSmall!.copyWith(color: context.bu.ink, fontWeight: FontWeight.w700)),
          // Kırmızı zorunlu noktası: en az 2 kişi seçilmeli.
          const SizedBox(width: 6),
          Container(width: 6, height: 6, decoration: BoxDecoration(color: context.bu.pr, shape: BoxShape.circle)),
        ]),
      );
}

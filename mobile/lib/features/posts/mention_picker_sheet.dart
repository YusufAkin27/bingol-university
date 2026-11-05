import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'post_models.dart';
import 'social_api.dart';
import 'social_models.dart';

/// Bir gönderide en çok etiketlenebilecek kişi sayısı (sunucu sınırıyla aynı).
const kPostMaxMentions = 10;

/// Takip ettiklerimin bir sayfası (imleçli). Testlerde sahtesi verilir.
typedef FollowingFetcher = Future<PostPage<SocialUser>> Function(String? cursor);

/// Aramada Türkçe karakter/büyük-küçük harf farkı yok sayılır ("İsmail" ~ "ismail", "Şule" ~ "sule").
String foldForSearch(String s) {
  const from = 'İIıŞşĞğÜüÖöÇç';
  const to = 'iiissgguuoocc';
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final i = from.indexOf(c);
    b.write(i >= 0 ? to[i] : c.toLowerCase());
  }
  return b.toString().trim();
}

/// Takip ettiklerimden kişi seçer (çoklu, en çok [max]). Seçilenlerin tam listesini döndürür; vazgeçilirse null.
/// Yalnız takip ettiklerim listelenir (`GET /users/{id}/following`); kimseyi takip etmiyorsam boş durum çıkar.
Future<List<SocialUser>?> showMentionPicker(
  BuildContext context,
  Session session, {
  List<SocialUser> selected = const [],
  int max = kPostMaxMentions,
  FollowingFetcher? fetch,
}) {
  final f = fetch ??
      (String? cursor) => SocialApi(session).following(session.userId ?? 0, cursor: cursor);
  return BuSheet.show<List<SocialUser>>(
    context,
    scrollable: false,
    maxHeightFactor: .9,
    padding: EdgeInsets.zero,
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * .78,
      child: MentionPicker(session: session, selected: selected, max: max, fetch: f),
    ),
  );
}

class MentionPicker extends StatefulWidget {
  const MentionPicker({super.key, required this.session, required this.selected, required this.max, required this.fetch});

  final Session session;
  final List<SocialUser> selected;
  final int max;
  final FollowingFetcher fetch;

  @override
  State<MentionPicker> createState() => _MentionPickerState();
}

class _MentionPickerState extends State<MentionPicker> {
  final _items = <SocialUser>[];
  final _picked = <SocialUser>[];
  final _scroll = ScrollController();
  final _query = TextEditingController();
  String? _cursor;
  bool _loading = true;
  bool _more = false;
  Object? _error;
  int _pages = 0;
  int _gen = 0;

  /// Arama sürerken eşleşme azsa sonraki sayfalar kendiliğinden çekilir; sonsuz döngüye karşı üst sınır.
  static const _maxAutoPages = 20;

  @override
  void initState() {
    super.initState();
    _picked.addAll(widget.selected);
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await widget.fetch(null);
      if (!mounted || gen != _gen) return;
      setState(() {
        _items
          ..clear()
          ..addAll(p.items.where((u) => u.id != widget.session.userId));
        _cursor = p.hasMore ? p.nextCursor : null;
        _pages = 1;
        _loading = false;
      });
      _autoFill();
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_cursor == null || _more || _loading) return;
    final gen = _gen;
    setState(() => _more = true);
    try {
      final p = await widget.fetch(_cursor);
      if (!mounted || gen != _gen) return;
      setState(() {
        final seen = _items.map((e) => e.id).toSet();
        _items.addAll(p.items.where((u) => u.id != widget.session.userId && seen.add(u.id)));
        _cursor = p.hasMore ? p.nextCursor : null;
        _pages++;
        _more = false;
      });
      _autoFill();
    } catch (_) {
      if (mounted) setState(() => _more = false);
    }
  }

  List<SocialUser> get _shown {
    final q = foldForSearch(_query.text);
    if (q.isEmpty) return _items;
    return [
      for (final u in _items)
        if (foldForSearch(u.displayName).contains(q) || foldForSearch(u.department ?? '').contains(q)) u,
    ];
  }

  /// Süzme sonucu az ve sunucuda sayfa varsa kalanı sessizce çeker ("takip ettiklerimde ara" tüm listeyi kapsasın).
  void _autoFill() {
    if (!mounted || _cursor == null || _more || _pages >= _maxAutoPages) return;
    if (_query.text.trim().isEmpty) return;
    if (_shown.length < 8) _loadMore();
  }

  bool _isPicked(SocialUser u) => _picked.any((e) => e.id == u.id);
  bool get _full => _picked.length >= widget.max;

  void _toggle(SocialUser u) {
    if (_isPicked(u)) {
      setState(() => _picked.removeWhere((e) => e.id == u.id));
    } else if (!_full) {
      setState(() => _picked.add(u));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final shown = _shown;
    Widget body;
    if (_loading) {
      body = const BuSkeletonList(itemCount: 6);
    } else if (_error != null) {
      body = BuErrorState(error: _error, onRetry: _load, compact: true);
    } else if (_items.isEmpty && _cursor == null) {
      body = BuEmptyState(
        key: const ValueKey('mentionEmpty'),
        icon: BuIcons.userPlus,
        title: l.composeMentionEmpty,
        compact: true,
      );
    } else if (shown.isEmpty && _cursor == null) {
      body = BuEmptyState(
        key: const ValueKey('mentionNoMatch'),
        icon: BuIcons.userSearch,
        title: l.composeMentionNoMatch,
        compact: true,
      );
    } else {
      body = ListView.builder(
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: shown.length + (_more || (_cursor != null && shown.isEmpty) ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= shown.length) {
            return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))));
          }
          final u = shown[i];
          final on = _isPicked(u);
          final disabled = !on && _full;
          final dept = context.departmentName((u.department ?? '').trim());
          return Semantics(
            key: ValueKey('mention-${u.id}'),
            button: true,
            selected: on,
            enabled: !disabled,
            label: u.displayName,
            child: InkWell(
              onTap: disabled ? null : () => _toggle(u),
              child: Opacity(
                opacity: disabled ? .45 : 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: BuSpace.page, vertical: 10),
                    child: Row(children: [
                      BuAvatar(name: u.displayName, url: u.avatarUrl, size: 44, headers: postAuthHeaders(widget.session)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text(u.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tx.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w400, color: t.ink)),
                          if (dept.isNotEmpty)
                            Text(dept, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyMedium?.copyWith(fontSize: 13, color: t.mut)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      ExcludeSemantics(
                        child: AnimatedSwitcher(
                          duration: BuMotion.of(context, BuMotion.short),
                          child: on
                              ? Icon(BuIcons.circleCheckFilled, key: const ValueKey('on'), size: 24, color: t.pr)
                              : Container(
                                  key: const ValueKey('off'),
                                  width: 22,
                                  height: 22,
                                  margin: const EdgeInsets.all(1),
                                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.bdStrong, width: 1.5)),
                                ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    final canSearch = !_loading && _error == null && (_items.isNotEmpty || _cursor != null);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (canSearch)
        Padding(
          padding: const EdgeInsets.fromLTRB(BuSpace.page, 0, BuSpace.page, 8),
          child: BuSearchField(
            key: const ValueKey('mentionSearch'),
            controller: _query,
            hint: l.composeMentionSearch,
            onChanged: (_) {
              setState(() {});
              _autoFill();
            },
          ),
        ),
      if (_full)
        Padding(
          padding: const EdgeInsets.fromLTRB(BuSpace.page, 0, BuSpace.page, 6),
          child: Text(l.composeMentionMax(widget.max.toString()),
              key: const ValueKey('mentionMax'), style: tx.bodySmall?.copyWith(color: t.mut)),
        ),
      Expanded(child: body),
      Padding(
        padding: const EdgeInsets.fromLTRB(BuSpace.page, 8, BuSpace.page, 12),
        child: BuButton(
          key: const ValueKey('mentionDone'),
          label: l.composeMentionDone,
          onPressed: () => Navigator.pop(context, List<SocialUser>.of(_picked)),
        ),
      ),
    ]);
  }
}

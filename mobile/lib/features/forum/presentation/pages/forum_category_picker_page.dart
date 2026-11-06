import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../widgets/bu.dart';
import '../../data/forum_api.dart';
import '../../data/forum_category_filter.dart';
import '../../data/forum_models.dart';
import '../widgets/forum_page_bar.dart';
import '../widgets/forum_state_views.dart';

/// Seçicinin sonucu: [category] null = "Tümü" (süzgeç yok).
class ForumCategoryChoice {
  const ForumCategoryChoice(this.category);

  final ForumCategory? category;
}

/// Sunucuya `q` isteği atılmadan önce beklenen süre (yerel süzme anlıktır; sunucu yalnız yerelde sonuç yoksa sorulur).
const Duration kForumCategoryRemoteDebounce = Duration(milliseconds: 350);

/// Kategori seçici sayfası: üstte arama kutusu (anlık, Türkçe karakter duyarsız yerel süzme; yerelde sonuç yoksa
/// sunucu `?q=` desteği), altta gruplara göre bölümlü liste. Seçili satır vurgulu; [allowAll] iken en başta "Tümü".
/// Forumun diğer ikincil sayfaları gibi görünür sayfa başlığı yoktur (ekran okuyucu etiketi vardır).
/// Hem ana sayfa/arama süzgeci (Tümü ile) hem yeni konu kategori alanı (Tümü'süz) bu sayfayı kullanır.
class ForumCategoryPickerPage extends StatefulWidget {
  const ForumCategoryPickerPage({
    super.key,
    required this.api,
    this.categories = const [],
    this.selectedId,
    this.allowAll = true,
  });

  final ForumApi api;

  /// Önceden yüklenmiş liste; boşsa sayfa kendisi yükler.
  final List<ForumCategory> categories;
  final int? selectedId;
  final bool allowAll;

  @override
  State<ForumCategoryPickerPage> createState() => _ForumCategoryPickerPageState();
}

class _ForumCategoryPickerPageState extends State<ForumCategoryPickerPage> {
  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  /// Açılışta seçili kategoriye bir kez yaklaşık kaydırılır (79 satırlık listede seçili satır görünsün).
  bool _jumped = false;

  late List<ForumCategory> _all = widget.categories;
  bool _loading = false;
  Object? _error;

  String _query = '';

  /// Sunucudan gelen sonuç (yalnız [_remoteFor] sorgusu için geçerli).
  List<ForumCategory>? _remote;
  String _remoteFor = '';

  @override
  void initState() {
    super.initState();
    if (_all.isEmpty) _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await widget.api.categories(force: true);
      if (!mounted) return;
      setState(() {
        _all = c;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    setState(() {
      _query = v;
      if (_remoteFor != v.trim()) _remote = null;
    });
    final q = v.trim();
    if (forumCategoryTokens(q).isEmpty || q.runes.length < 2) return;
    if (filterForumCategories(_all, q).isNotEmpty) return; // yerel sonuç var: sunucuya gerek yok
    _debounce = Timer(kForumCategoryRemoteDebounce, () async {
      try {
        final r = await widget.api.categories(q: q);
        if (mounted && _ctl.text.trim() == q) {
          setState(() {
            _remote = r;
            _remoteFor = q;
          });
        }
      } catch (_) {
        // Sunucu araması isteğe bağlıdır; hata olursa yerel "sonuç yok" gösterilir.
      }
    });
  }

  void _pick(ForumCategory? c) {
    buHaptic(BuHaptic.selection);
    Navigator.of(context).pop(ForumCategoryChoice(c));
  }

  List<ForumCategory> get _visible {
    final local = filterForumCategories(_all, _query);
    if (local.isNotEmpty || _remote == null || _remoteFor != _query.trim()) return local;
    return _remote!;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        ForumPageBar(
          semanticTitle: l.forumCatPickerA11y,
          middle: BuSearchField(
            key: const ValueKey('forum-cat-search'),
            controller: _ctl,
            hint: l.forumCatSearchHint,
            onChanged: _onChanged,
          ),
        ),
        Expanded(child: _content(context)),
      ]),
    );
  }

  Widget _content(BuildContext context) {
    final l = context.l10n;
    if (_loading && _all.isEmpty) {
      return const BuSkeletonList(key: ValueKey('forum-cat-loading'), itemCount: 8);
    }
    if (_error != null && _all.isEmpty) {
      return ForumErrorView(key: const ValueKey('forum-cat-error'), error: _error!, onRetry: _load, compact: true);
    }
    final searching = forumCategoryTokens(_query).isNotEmpty;
    final visible = _visible;
    if (searching && visible.isEmpty) {
      return BuEmptyState(
        key: const ValueKey('forum-cat-empty'),
        icon: BuIcons.searchX,
        title: l.forumCatEmptyTitle,
        message: l.forumCatEmptyBody(_query.trim()),
        compact: true,
      );
    }
    final sections = groupForumCategories(visible);
    final rows = <_Row>[
      if (widget.allowAll && !searching) const _Row.all(),
      for (final s in sections) ...[
        if (s.name != null) _Row.header(s.name!),
        for (final c in s.items) _Row.category(c),
      ],
    ];
    final bottom = MediaQuery.paddingOf(context).bottom;
    if (!_jumped && widget.selectedId != null && !searching) {
      _jumped = true;
      final i = rows.indexWhere((r) => r.category?.id == widget.selectedId);
      if (i > 3) {
        // Satır yükseklikleri sabit değil (iki satıra sarılan ad, başlıklar): yaklaşık konum; seçili satır ekranın üst
        // üçte birine gelir, gerisi doğal kaydırmadır.
        final approx = rows.take(i).fold<double>(0, (sum, r) => sum + (r.kind == _RowKind.header ? 54 : 56)) - 120;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) _scroll.jumpTo(approx.clamp(0, _scroll.position.maxScrollExtent));
        });
      }
    }
    return ListView.builder(
      key: const ValueKey('forum-cat-list'),
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(8, 4, 8, 24 + bottom),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final r = rows[i];
        return switch (r.kind) {
          _RowKind.header => _SectionHeader(text: r.title!),
          _RowKind.all => _CategoryTile(
              key: const ValueKey('forum-cat-all'),
              name: l.forumHomeCategoryAll,
              selected: widget.selectedId == null,
              onTap: () => _pick(null),
            ),
          _RowKind.category => _CategoryTile(
              key: ValueKey('forumCategory${r.category!.id}'),
              name: r.category!.name,
              count: r.category!.topicCount,
              selected: r.category!.id == widget.selectedId,
              onTap: () => _pick(r.category),
            ),
        };
      },
    );
  }
}

enum _RowKind { all, header, category }

class _Row {
  const _Row.all()
      : kind = _RowKind.all,
        title = null,
        category = null;
  const _Row.header(String this.title)
      : kind = _RowKind.header,
        category = null;
  const _Row.category(ForumCategory this.category)
      : kind = _RowKind.category,
        title = null;

  final _RowKind kind;
  final String? title;
  final ForumCategory? category;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 20, 12, 6),
        child: Text(text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: t.mut, fontWeight: BuType.emphasisWeight)),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({super.key, required this.name, required this.selected, required this.onTap, this.count = 0});

  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: count > 0 ? '$name, ${l.forumCatTopicCount(count)}' : name,
      excludeSemantics: true,
      child: Material(
        color: selected ? t.soft : Colors.transparent,
        shape: BuRadius.rect(BuRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: BuSize.touch),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                Expanded(
                  child: Text(name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tx.bodyLarge?.copyWith(color: t.ink, fontWeight: BuType.emphasisWeight)),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 12),
                  Text(l.forumCatTopicCount(count), style: tx.bodySmall?.copyWith(color: t.mut)),
                ],
                if (selected) ...[
                  const SizedBox(width: 12),
                  Icon(BuIcons.check, size: 20, color: t.ink),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Seçiciyi açar. Dönüş null = vazgeçildi; aksi halde [ForumCategoryChoice] (kategori null = "Tümü").
Future<ForumCategoryChoice?> openForumCategoryPicker(
  BuildContext context, {
  required ForumApi api,
  List<ForumCategory> categories = const [],
  int? selectedId,
  bool allowAll = true,
}) =>
    Navigator.of(context).push<ForumCategoryChoice>(MaterialPageRoute<ForumCategoryChoice>(
      settings: const RouteSettings(name: 'forum-category-picker'),
      builder: (_) => ForumCategoryPickerPage(api: api, categories: categories, selectedId: selectedId, allowAll: allowAll),
    ));

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'emoji_catalog.dart';
import 'recent_reactions.dart';

/// Tam emoji seçici (alt sayfa): kategoriler, arama, son kullanılanlar. Seçilen emojiyi döndürür.
/// Sunucu her geçerli emojiyi kabul eder; yalnız tek bir emoji grafem kümesi seçilebilir.
Future<String?> showReactionPicker(BuildContext context) =>
    BuSheet.show<String>(
      context,
      title: context.l10n.chatReactionPickerTitle,
      scrollable: false,
      padding: EdgeInsets.zero,
      maxHeightFactor: .82,
      builder: (_) => const _ReactionPicker(),
    );

const _emojiFont = TextStyle(
    fontFamily: 'Apple Color Emoji',
    fontFamilyFallback: ['Noto Color Emoji', 'Segoe UI Emoji']);

String _categoryLabel(EmojiCategory c, AppLocalizations l) => switch (c) {
      EmojiCategory.faces => l.chatReactionCatFaces,
      EmojiCategory.people => l.chatReactionCatPeople,
      EmojiCategory.nature => l.chatReactionCatNature,
      EmojiCategory.food => l.chatReactionCatFood,
      EmojiCategory.activities => l.chatReactionCatActivities,
      EmojiCategory.travel => l.chatReactionCatTravel,
      EmojiCategory.objects => l.chatReactionCatObjects,
      EmojiCategory.symbols => l.chatReactionCatSymbols,
      EmojiCategory.flags => l.chatReactionCatFlags,
    };

class _Section {
  const _Section(this.id, this.title, this.glyph, this.emojis);
  final String id;
  final String title;
  final String glyph;
  final List<String> emojis;
}

class _ReactionPicker extends StatefulWidget {
  const _ReactionPicker();
  @override
  State<_ReactionPicker> createState() => _ReactionPickerState();
}

class _ReactionPickerState extends State<_ReactionPicker> {
  static const _headerH = 36.0;
  static const _hPad = 8.0;
  static const _tabH = 48.0;

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _tabScroll = ScrollController();
  List<String> _recent = const [];
  String _query = '';
  int _active = 0;
  double _cell = 44;
  int _cols = 8;
  List<_Section> _sections = const [];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    RecentReactions.loadRecent().then((r) {
      if (mounted) setState(() => _recent = r);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _tabScroll.dispose();
    super.dispose();
  }

  double _sectionTop(int i) {
    var y = 0.0;
    for (var k = 0; k < i; k++) {
      y += _headerH + (_sections[k].emojis.length / _cols).ceil() * _cell;
    }
    return y;
  }

  void _onScroll() {
    if (_query.trim().isNotEmpty || _sections.isEmpty || !_scroll.hasClients) {
      return;
    }
    final y = _scroll.offset + 1;
    var idx = 0;
    for (var i = 0; i < _sections.length; i++) {
      if (_sectionTop(i) <= y) idx = i;
    }
    if (idx != _active) {
      setState(() => _active = idx);
      _revealTab(idx);
    }
  }

  /// Etkin sekmeyi şeritte görünür tutar.
  void _revealTab(int i) {
    if (!_tabScroll.hasClients) return;
    final p = _tabScroll.position;
    final target = (i * 44.0 - (p.viewportDimension - 44) / 2)
        .clamp(0.0, p.maxScrollExtent);
    _tabScroll.animateTo(target,
        duration: BuMotion.of(context, BuMotion.short),
        curve: BuMotion.standard);
  }

  void _jump(int i) {
    buHaptic(BuHaptic.selection);
    final max = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
    setState(() => _active = i);
    _revealTab(i);
    if (!_scroll.hasClients) return;
    _scroll.animateTo(_sectionTop(i).clamp(0.0, max),
        duration: BuMotion.of(context, BuMotion.medium),
        curve: BuMotion.standard);
  }

  void _choose(String value) {
    final emoji = value.trim();
    if (!RecentReactions.isEmoji(emoji)) return;
    buHaptic(BuHaptic.selection);
    Navigator.pop(context, RecentReactions.display(emoji));
  }

  List<_Section> _buildSections(AppLocalizations l) {
    final used = _recent.isNotEmpty;
    return [
      _Section(
          'recent',
          used ? l.chatReactionRecent : l.chatReactionFrequent,
          used ? '🕘' : '⭐',
          used ? _recent : RecentReactions.defaults),
      for (final c in EmojiCategory.values)
        _Section(c.id, _categoryLabel(c, l), c.glyph,
            [for (final e in EmojiCatalog.all[c]!) e.emoji]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final typed = _query.trim();
    final searching = typed.isNotEmpty;
    // Klavyeden yazılan/yapıştırılan tek emoji doğrudan aday olur.
    final typedOk = RecentReactions.isEmoji(typed);
    final results = <String>[
      if (typedOk) RecentReactions.display(typed),
      if (searching)
        for (final e in EmojiCatalog.search(typed))
          if (!typedOk || e.emoji != typed) e.emoji,
    ];
    _sections = _buildSections(l);

    return Column(children: [
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
        child: BuSearchField(
          key: const ValueKey('reactionEmojiInput'),
          controller: _input,
          hint: l.chatReactionSearchHint,
          onChanged: (v) => setState(() => _query = v),
          onSubmitted: (v) {
            if (RecentReactions.isEmoji(v.trim())) _choose(v);
          },
        ),
      ),
      if (!searching)
        SizedBox(
          height: _tabH,
          child: ListView.builder(
            key: const ValueKey('reactionEmojiTabs'),
            controller: _tabScroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _sections.length,
            itemBuilder: (_, i) {
              final s = _sections[i];
              final on = i == _active;
              return Semantics(
                button: true,
                selected: on,
                label: s.title,
                excludeSemantics: true,
                child: GestureDetector(
                  key: ValueKey('reactionTab_${s.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _jump(i),
                  child: AnimatedContainer(
                    duration: BuMotion.of(context, BuMotion.short),
                    width: 44,
                    height: _tabH,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: on ? t.pr : Colors.transparent,
                              width: 2)),
                    ),
                    child: Text(s.glyph,
                        textScaler: TextScaler.noScaling,
                        style: _emojiFont.copyWith(fontSize: 22)),
                  ),
                ),
              );
            },
          ),
        ),
      Divider(height: 1, thickness: 1, color: t.bd),
      Expanded(
        child: LayoutBuilder(builder: (context, c) {
          // 390 dp'de 8 sütun; 320 dp'de 7 (hücre >= 44 dp dokunma hedefi).
          final cols = ((c.maxWidth - 2 * _hPad) / 44).floor().clamp(6, 8);
          _cols = cols;
          _cell = (c.maxWidth - 2 * _hPad) / cols;
          if (searching) {
            if (results.isEmpty) {
              return Center(
                  child: Text(l.chatReactionNoResults,
                      key: const ValueKey('reactionEmojiEmpty'),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .copyWith(color: t.mut)));
            }
            return CustomScrollView(
              key: const ValueKey('reactionEmojiGrid'),
              slivers: [_grid(results, l, cols)],
            );
          }
          return CustomScrollView(
            key: const ValueKey('reactionEmojiGrid'),
            controller: _scroll,
            slivers: [
              for (final s in _sections) ...[
                SliverToBoxAdapter(
                    child: SizedBox(
                  height: _headerH,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 16),
                      child: Semantics(
                        header: true,
                        child: Text(s.title,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge!
                                .copyWith(
                                    color: t.mut,
                                    fontWeight: FontWeight.w400)),
                      ),
                    ),
                  ),
                )),
                _grid(s.emojis, l, cols),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          );
        }),
      ),
    ]);
  }

  Widget _grid(List<String> emojis, AppLocalizations l, int cols) =>
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: _hPad),
        sliver: SliverGrid(
          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols),
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final emoji = emojis[i];
              return Semantics(
                button: true,
                label: l.chatDetailReactionLabel(emoji),
                excludeSemantics: true,
                child: InkResponse(
                  key: ValueKey('emoji_$emoji'),
                  onTap: () => _choose(emoji),
                  radius: 24,
                  child: Center(
                      child: Text(emoji,
                          textScaler: TextScaler.noScaling,
                          style: _emojiFont.copyWith(fontSize: 28))),
                ),
              );
            },
            childCount: emojis.length,
            addAutomaticKeepAlives: false,
          ),
        ),
      );
}

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../polls/poll_routes.dart';
import '../posts/post_routes.dart';
import '../search/search_page.dart';
import 'discover_masonry.dart';
import 'discover_suggestions.dart';

/// Keşfet sekmesi: yalnız öğrenci gönderileri, tek sütun akış.
/// Başlık + anket/gönderi paylaş düğmeleri, arama kutusu (dokununca arama sayfası), çipler, öneriler, akış.
class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key, required this.session, required this.typeRequest});

  final Session session;

  /// Ana sayfadaki "Tümü" bağlantıları buraya haber türü yazar. Keşfet artık haber göstermediğinden istek
  /// yalnızca tüketilir (null'lanır); haber akışı için ayrı bir giriş gerekir (bkz. rapor).
  final ValueNotifier<String?> typeRequest;

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  final _feedController = DiscoverFeedController();
  String _scope = 'top';

  @override
  void initState() {
    super.initState();
    widget.typeRequest.addListener(_consume);
    _consume();
  }

  @override
  void didUpdateWidget(DiscoverTab old) {
    super.didUpdateWidget(old);
    if (old.typeRequest != widget.typeRequest) {
      old.typeRequest.removeListener(_consume);
      widget.typeRequest.addListener(_consume);
    }
  }

  @override
  void dispose() {
    widget.typeRequest.removeListener(_consume);
    super.dispose();
  }

  void _consume() {
    if (widget.typeRequest.value != null) widget.typeRequest.value = null;
  }

  void _openSearch() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SearchPage(session: widget.session)),
      );

  Future<void> _compose() async {
    final p = await openComposePost(context, widget.session);
    if (p == null || !mounted) return;
    _feedController.insertPost(p);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: DiscoverMasonryFeed(
        session: widget.session,
        controller: _feedController,
        scope: _scope,
        header: _header(context),
        onCompose: _compose,
      ),
    );
  }

  Widget _header(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: MediaQuery.paddingOf(context).top + BuSpace.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: BuSpace.lg),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.navDiscover,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.headlineLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                Text(l.p04DiscoverSub, style: tt.bodySmall?.copyWith(color: t.mut)),
              ]),
            ),
            BuIconButton(
              icon: LucideIcons.vote,
              size: 40,
              tooltip: l.discoverPolls,
              onTap: () => openPollList(context, widget.session),
            ),
            BuGap.w4,
            BuIconButton(
              icon: LucideIcons.plus,
              size: 40,
              tooltip: l.discoverCompose,
              filled: true,
              onTap: _compose,
            ),
          ]),
        ),
        BuGap.h12,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: BuSpace.lg),
          child: Semantics(
            button: true,
            label: l.p04SearchHint,
            excludeSemantics: true,
            onTap: _openSearch,
            child: Material(
              color: t.sf2,
              borderRadius: BorderRadius.circular(BuRadius.sm),
              child: InkWell(
                key: const ValueKey('discoverSearch'),
                borderRadius: BorderRadius.circular(BuRadius.sm),
                onTap: _openSearch,
                child: SizedBox(
                  height: 48,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(children: [
                      Icon(LucideIcons.search, size: 20, color: t.mut),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(l.p04SearchHint,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodyMedium?.copyWith(color: t.mut)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(BuSpace.lg, BuSpace.xs, BuSpace.lg, BuSpace.md),
          child: Row(children: [
            _Chip(
                key: const ValueKey('discoverChipAll'),
                label: l.p04ChipAll,
                selected: _scope == 'top',
                onTap: () => setState(() => _scope = 'top')),
            BuGap.w8,
            _Chip(
                key: const ValueKey('discoverChipPopular'),
                label: l.discoverScopePopular,
                selected: _scope == 'popular',
                onTap: () => setState(() => _scope = 'popular')),
          ]),
        ),
        BuGap.h8,
        DiscoverSuggestions(session: widget.session),
        Padding(
          padding: const EdgeInsets.fromLTRB(BuSpace.lg, 0, BuSpace.lg, BuSpace.md),
          child: Row(children: [
            Icon(Icons.dynamic_feed, size: 18, color: t.pr),
            BuGap.w6,
            Expanded(
              child: Text(l.p04FeedTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ],
    );
  }
}

/// Hızlı süzgeç çipi: seçili = kırmızı dolgu, değilse beyaz hap + hafif gölge (dokunma hedefi 44).
class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: AnimatedContainer(
              duration: BuMotion.of(context, BuMotion.short),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? t.soft : t.sf,
                borderRadius: BorderRadius.circular(BuRadius.pill),
                border: selected ? Border.all(color: t.selectedBorder) : null,
                boxShadow: selected ? const [] : BuElevation.of(context, 1),
              ),
              child: Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: selected ? t.onSoft : t.ink, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }
}

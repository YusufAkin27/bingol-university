import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../posts/post_routes.dart';
import '../search/search_page.dart';
import 'discover_masonry.dart';
import 'discover_suggestions.dart';

/// Keşfet sekmesi: yalnız öğrenci gönderileri, tek sütun, fotoğraf öncelikli akış.
/// Başlık + arama/gönderi paylaş simgeleri, Tümü/Popüler çipleri, akış (öneriler akışın 3. gönderisinden sonra).
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
        inline: DiscoverSuggestions(session: widget.session),
      ),
    );
  }

  /// Sade üst alan: başlık + arama/paylaş simgeleri, altında Tümü / Popüler çipleri. Anketler Ana Sayfa'dadır.
  Widget _header(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: MediaQuery.paddingOf(context).top + BuSpace.md),
        Padding(
          // Sekme başlıkları (Ana Sayfa/Sohbet/Kulüpler/Profil) ile aynı 20 dp kenar boşluğu ve 44 dp düğmeler.
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Expanded(
              child: Text(l.navDiscover,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.headlineMedium?.copyWith(color: t.ink)),
            ),
            BuIconButton(
              key: const ValueKey('discoverSearch'),
              icon: LucideIcons.search,
              tooltip: l.discoverSearch,
              onTap: _openSearch,
            ),
            BuGap.w8,
            BuIconButton(
              icon: LucideIcons.plus,
              tooltip: l.discoverCompose,
              filled: true,
              onTap: _compose,
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, BuSpace.xs, 20, BuSpace.xs),
          child: Row(children: [
            BuChip(
                key: const ValueKey('discoverChipAll'),
                label: l.p04ChipAll,
                selected: _scope == 'top',
                onTap: () => setState(() => _scope = 'top')),
            BuGap.w8,
            BuChip(
                key: const ValueKey('discoverChipPopular'),
                label: l.discoverScopePopular,
                selected: _scope == 'popular',
                onTap: () => setState(() => _scope = 'popular')),
          ]),
        ),
      ],
    );
  }
}

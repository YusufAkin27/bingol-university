import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../forum/forum_routes.dart' show openForumHome;
import '../forum/presentation/widgets/forum_entry_strip.dart';
import '../posts/post_routes.dart';
import '../search/global_search_screen.dart';
import 'discover_masonry.dart';
import 'discover_suggestions.dart';

/// Keşfet sekmesi: öğrenci gönderileri ve videoları TEK karma akışta, iki sütun masonry ızgara.
///
/// Üstte yalnız başlık satırı: "Keşfet" + arama + vurgulu "+" (paylaş); filtre/kapsül YOK. Akış her yenilemede (aşağı
/// çekme, sekmeye uzun süre sonra dönüş) yeniden karışır ve görülmemişleri önce getirir; hepsi görüldüyse kesintisiz
/// baştan karıştırır ([DiscoverMasonryFeed]). Kabuk sekmeyi canlı tuttuğundan profile gidip dönünce ızgara konumu aynen
/// durur. Öneriler masonry'nin ilk 4 kutusundan sonra tam genişlik bant olarak araya girer.
class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key, required this.session, required this.typeRequest, this.tabActive = true});

  final Session session;

  /// Sekme şu an görünür mü (kabuk IndexedStack'te gizli sekmeler canlı kalır; uzun süre sonra dönüşte akış yenilenir).
  final bool tabActive;

  /// Ana sayfadaki "Tümü" bağlantıları buraya haber türü yazar. Keşfet haber göstermediğinden istek yalnızca tüketilir
  /// (null'lanır); haber akışı için ayrı bir giriş gerekir.
  final ValueNotifier<String?> typeRequest;

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  final _controller = DiscoverFeedController();

  /// Öneri yok/yüklenemedi: bant hiç kurulmaz, masonry kesintisiz tek ızgara olur.
  bool _noSuggestions = false;

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

  void _openSearch() => Navigator.push(context, GlobalSearchScreen.route(widget.session));

  Future<void> _compose() async {
    final p = await openComposePost(context, widget.session);
    if (p == null || !mounted) return;
    // Yeni gönderi akışın başına eklenir.
    _controller.insertPost(p);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: DiscoverMasonryFeed(
        session: widget.session,
        controller: _controller,
        tabActive: widget.tabActive,
        header: Column(mainAxisSize: MainAxisSize.min, children: [
          _Header(top: MediaQuery.paddingOf(context).top, onSearch: _openSearch, onCompose: _compose),
          // Kampüs Forum giriş şeridi (alt çubuğa 6. sekme eklenmez).
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(BuSpace.page, 0, BuSpace.page, BuSpace.md),
            child: ForumEntryStrip(onTap: () => openForumHome(context, widget.session)),
          ),
        ]),
        onCompose: _compose,
        inline: _noSuggestions
            ? null
            : DiscoverSuggestions(
                session: widget.session,
                onUnavailable: () {
                  if (mounted && !_noSuggestions) setState(() => _noSuggestions = true);
                }),
      ),
    );
  }
}

/// Başlık satırı: durum çubuğu payı + 44 dp satır (akışla birlikte kayar). Sekme başlıklarıyla aynı 20 dp kenar boşluğu.
class _Header extends StatelessWidget {
  const _Header({required this.top, required this.onSearch, required this.onCompose});

  final double top;
  final VoidCallback onSearch;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(0, top + BuSpace.sm, 0, BuSpace.sm),
      child: Padding(
        padding: BuSpace.pageH,
        child: SizedBox(
          height: 44,
          child: Row(children: [
            Expanded(
              child: Semantics(header: true, label: l.navDiscover, child: const SizedBox.shrink()),
            ),
            BuIconButton(
              key: const ValueKey('discoverSearch'),
              icon: BuIcons.search,
              tooltip: l.discoverSearch,
              size: 44,
              onTap: onSearch,
            ),
            BuGap.w8,
            BuIconButton(icon: BuIcons.plus, tooltip: l.discoverCompose, filled: true, size: 44, onTap: onCompose),
          ]),
        ),
      ),
    );
  }
}

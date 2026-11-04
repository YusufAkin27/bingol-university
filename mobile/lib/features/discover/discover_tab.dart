import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../posts/post_routes.dart';
import '../reels/reels_feed.dart';
import '../search/search_page.dart';
import 'discover_masonry.dart';
import 'discover_suggestions.dart';

/// Keşfet sekmesi: yalnız öğrenci gönderileri (fotoğraf ve video), iki sütun masonry akışı.
/// Başlık + arama/gönderi paylaş simgeleri, altında ince "Gönderiler | Reels" segmenti. Sıralama TEKTİR (popülerlik
/// puanı; seçenek çipi yok); öneriler masonry'nin ilk 4 kutusundan sonra tam genişlik bant olarak araya girer.
/// "Reels": dikey tam ekran video akışı (aynı sekmede, yeni sekme yok).
class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key, required this.session, required this.typeRequest, this.tabActive = true});

  final Session session;

  /// Sekme şu an görünür mü (kabuk IndexedStack'te gizli sekmeler canlı kalır; Reels gizliyken oynamamalı).
  final bool tabActive;

  /// Ana sayfadaki "Tümü" bağlantıları buraya haber türü yazar. Keşfet artık haber göstermediğinden istek
  /// yalnızca tüketilir (null'lanır); haber akışı için ayrı bir giriş gerekir (bkz. rapor).
  final ValueNotifier<String?> typeRequest;

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  final _feedController = DiscoverFeedController();

  /// Tek sıralama: sunucudaki popülerlik puanı (`scope=top`).
  static const _scope = 'top';

  /// Reels görünümü seçili mi; ilk seçimde kurulur, sonra durumu korunur.
  bool _reels = false;
  bool _reelsBuilt = false;

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

  void _openSearch() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SearchPage(session: widget.session)),
      );

  Future<void> _compose() async {
    final p = await openComposePost(context, widget.session);
    if (p == null || !mounted) return;
    _feedController.insertPost(p);
  }

  void _setReels(bool v) {
    if (v == _reels) return;
    setState(() {
      _reels = v;
      if (v) _reelsBuilt = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(children: [
        Offstage(
          offstage: _reels,
          child: DiscoverMasonryFeed(
            session: widget.session,
            controller: _feedController,
            scope: _scope,
            header: _header(context),
            onCompose: _compose,
            inline: _noSuggestions
                ? null
                : DiscoverSuggestions(
                    session: widget.session,
                    onUnavailable: () {
                      if (mounted && !_noSuggestions) setState(() => _noSuggestions = true);
                    }),
          ),
        ),
        if (_reelsBuilt)
          Offstage(
            offstage: !_reels,
            child: ReelsFeed(
              session: widget.session,
              active: _reels && widget.tabActive,
              onCompose: _compose,
              topInset: MediaQuery.paddingOf(context).top + 64,
            ),
          ),
        if (_reels) _reelsOverlay(context),
      ]),
    );
  }

  /// "Gönderiler | Reels" segmenti: yeni sekme eklemeden Keşfet başlık satırında iki görünüm arasında geçiş.
  Widget _segment() => Semantics(
        container: true,
        label: context.l10n.kesSegA11y,
        child: ConstrainedBox(
          key: const ValueKey('discoverSegment'),
          constraints: const BoxConstraints(maxWidth: 260),
          child: BuSegmented(
            items: [context.l10n.kesSegPosts, context.l10n.kesSegReels],
            index: _reels ? 1 : 0,
            onChanged: (i) => _setReels(i == 1),
          ),
        ),
      );

  /// Reels üstünde: koyu degrade üstünde segment + paylaş düğmesi.
  Widget _reelsOverlay(BuildContext context) {
    final t = context.bu;
    final top = MediaQuery.paddingOf(context).top;
    return PositionedDirectional(
      top: 0,
      start: 0,
      end: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.scrim.withValues(alpha: .55), t.scrim.withValues(alpha: 0)],
          ),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(BuSpace.page, top + BuSpace.sm, BuSpace.page, BuSpace.md),
          child: Row(children: [
            Expanded(child: Align(alignment: AlignmentDirectional.centerStart, child: _segment())),
            BuGap.w8,
            BuIconButton(icon: BuIcons.plus, tooltip: context.l10n.discoverCompose, filled: true, size: 44, onTap: _compose),
          ]),
        ),
      ),
    );
  }

  /// Sade üst alan: başlık + arama/paylaş simgeleri, altında Gönderiler | Reels segmenti. Anketler Ana Sayfa'dadır.
  Widget _header(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: MediaQuery.paddingOf(context).top + BuSpace.sm),
        Padding(
          // Sekme başlıkları (Ana Sayfa/Sohbet/Kulüpler/Profil) ile aynı 20 dp kenar boşluğu ve 44 dp düğmeler.
          padding: BuSpace.pageH,
          child: Row(children: [
            Expanded(
              child: Text(l.navDiscover,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.headlineMedium?.copyWith(color: t.ink, fontSize: 28, fontWeight: FontWeight.w700)),
            ),
            BuIconButton(
              key: const ValueKey('discoverSearch'),
              icon: BuIcons.search,
              tooltip: l.discoverSearch,
              size: 44,
              onTap: _openSearch,
            ),
            BuGap.w8,
            BuIconButton(
              icon: BuIcons.plus,
              tooltip: l.discoverCompose,
              filled: true,
              size: 44,
              onTap: _compose,
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(BuSpace.page, BuSpace.xs, BuSpace.page, BuSpace.sm),
          child: _segment(),
        ),
      ],
    );
  }
}

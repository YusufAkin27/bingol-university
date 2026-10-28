import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../polls/poll_routes.dart';
import '../posts/post_routes.dart';
import '../search/search_page.dart';
import 'discover_masonry.dart';

/// Keşfet sekmesi: yalnız öğrenci gönderileri, tek akış (iki sütunlu masonry).
/// Başlık + gönderi paylaş düğmesi, arama kutusu (dokununca arama sayfası), akış.
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
    final l = context.l10n;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(
            title: l.navDiscover,
            subtitle: l.kesfetSubtitle,
            actions: [
              BuIconButton(
                icon: LucideIcons.vote,
                tooltip: l.discoverPolls,
                onTap: () => openPollList(context, widget.session),
              ),
              BuIconButton(
                icon: LucideIcons.plus,
                tooltip: l.discoverCompose,
                filled: true,
                onTap: _compose,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Semantics(
              button: true,
              label: l.kesfetSearchHint,
              excludeSemantics: true,
              onTap: _openSearch,
              child: Material(
                color: t.sf,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: t.bd),
                ),
                child: InkWell(
                  key: const ValueKey('discoverSearch'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: _openSearch,
                  child: SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        Icon(LucideIcons.search, size: 18, color: t.mut),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l.kesfetSearchHint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BuType.body.copyWith(color: t.mut, fontSize: 14),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: DiscoverMasonryFeed(session: widget.session, controller: _feedController)),
        ],
      ),
    );
  }
}

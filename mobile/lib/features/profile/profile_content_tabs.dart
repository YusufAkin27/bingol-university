import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../posts/post_models.dart' show postAuthHeaders, postMediaUrlOrNull;
import '../posts/post_routes.dart';

/// Profil içerik sekmesindeki bir kare (gönderi ya da reel). Ham JSON'dan gevşekçe okunur: yeni video alanları
/// (`type`, `video{posterUrl,durationMs}`, `viewCount`) sunucuda yoksa da çalışır.
class ProfileGridItem {
  const ProfileGridItem({required this.id, this.imageUrl, this.isVideo = false, this.durationMs, this.views, this.text});

  factory ProfileGridItem.fromJson(Map<dynamic, dynamic> j) {
    String? img;
    var video = j['type'] == 'VIDEO';
    int? dur;
    final v = j['video'];
    if (v is Map) {
      video = true;
      img = postMediaUrlOrNull(v['posterUrl'] as String? ?? v['thumbUrl'] as String?);
      dur = (v['durationMs'] as num?)?.toInt();
    }
    final media = j['media'];
    if (img == null && media is List) {
      for (final m in media.whereType<Map>()) {
        final isVid = m['kind'] == 'VIDEO';
        final u = postMediaUrlOrNull((m['thumbUrl'] as String?) ?? (isVid ? null : m['url'] as String?));
        if (isVid) {
          video = true;
          dur ??= (m['durationMs'] as num?)?.toInt();
        }
        if (u != null) {
          img = u;
          break;
        }
      }
    }
    img ??= postMediaUrlOrNull((j['posterUrl'] ?? j['thumbUrl'] ?? j['imageUrl']) as String?);
    final views = j['viewCount'] ?? j['views'];
    return ProfileGridItem(
      id: (j['id'] as num).toInt(),
      imageUrl: img,
      isVideo: video,
      durationMs: dur,
      views: views is num ? views.toInt() : null,
      text: j['text'] as String?,
    );
  }

  final int id;
  final String? imageUrl;
  final bool isVideo;
  final int? durationMs;
  final int? views;
  final String? text;

  /// "0:07" / "1:05".
  String? get durationLabel {
    final d = durationMs;
    if (d == null || d <= 0) return null;
    final s = (d / 1000).round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

/// Profil alt içerik sekmeleri: Gönderiler (3 sütun grid) | Reels (kapak + süre + görüntülenme). Kendi içinde yüklenir
/// ve sayfalar ("Daha fazla göster"); ana kaydırmanın içine yerleştirilir (kendisi kaydırmaz). "Etiketlenenler" yok
/// (sunucuda desteklenmiyor). Gizli hesapta ([locked]) içerik yerine kilit bilgisi gösterilir.
///
/// Entegrasyon (`UserProfilePage`/`ProfileTab`): `ProfileContentTabs(session:, userId:, name:, locked:, postCount:, reelCount:)`.
/// Kendi profilinde `userId == session.userId` (gönderiler `/posts/mine`).
class ProfileContentTabs extends StatefulWidget {
  const ProfileContentTabs({
    super.key,
    required this.session,
    required this.userId,
    this.name,
    this.locked = false,
    this.postCount,
    this.reelCount,
    this.initialIndex = 0,
    this.onOpenReel,
    this.onPostsLoaded,
    this.gutter = 20,
    this.pageSize = 18,
  });

  final Session session;
  final int userId;
  final String? name;

  /// Gizli hesap ve ben takipçi değilim.
  final bool locked;

  /// Profil sayaçları (biliniyorsa sekme etiketinde gösterilir).
  final int? postCount;
  final int? reelCount;
  final int initialIndex;

  /// Reel karosuna dokununca (Reels görüntüleyici entegrasyonu için); verilmezse gönderi ayrıntısı açılır.
  final void Function(ProfileGridItem item, List<ProfileGridItem> all)? onOpenReel;

  /// Gönderiler sekmesinin ilk sayfası yüklenince: bilinen toplam (sunucu `total` verirse) ya da yüklenen sayı + daha var mı.
  /// Üst sayfadaki "Gönderi" sayacı profil yanıtında `postCount` yoksa buradan beslenir.
  final void Function(int count, bool hasMore)? onPostsLoaded;

  /// Yan boşluk (dp): ana sayfa zaten kenar boşluğu veriyorsa 0.
  final double gutter;

  /// Sayfa başına kare sayısı (3 sütunun katı).
  final int pageSize;

  @override
  State<ProfileContentTabs> createState() => _ProfileContentTabsState();
}

class _Col {
  final items = <ProfileGridItem>[];
  String? cursor;
  bool loading = false;
  bool loaded = false;
  bool done = false;
  bool unsupported = false;
  Object? error;
  int gen = 0;
}

class _ProfileContentTabsState extends State<ProfileContentTabs> {
  int get _size => widget.pageSize;
  late int _index = widget.initialIndex.clamp(0, 1);
  final _cols = [_Col(), _Col()];

  @override
  void initState() {
    super.initState();
    if (!widget.locked) _load(_index);
  }

  @override
  void didUpdateWidget(ProfileContentTabs old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId || old.locked != widget.locked) {
      for (var i = 0; i < 2; i++) {
        _cols[i] = _Col();
      }
      if (!widget.locked) _load(_index);
    }
  }

  String get _postsPath => widget.userId == widget.session.userId ? '/posts/mine' : '/users/${widget.userId}/posts';

  Future<void> _load(int i, {bool more = false}) async {
    final c = _cols[i];
    if (c.loading || (more && c.done) || c.unsupported) return;
    final gen = ++c.gen;
    setState(() {
      c.loading = true;
      c.error = null;
    });
    try {
      final path = i == 0 ? _postsPath : '/users/${widget.userId}/reels';
      final cur = more && c.cursor != null ? '&cursor=${Uri.encodeQueryComponent(c.cursor!)}' : '';
      final r = await widget.session.api.get('$path?size=$_size$cur');
      if (!mounted || gen != c.gen) return;
      final fresh = <ProfileGridItem>[
        for (final e in (r is Map ? r['items'] : null) as List? ?? const [])
          if (e is Map && e['id'] is num) ProfileGridItem.fromJson(e),
      ];
      setState(() {
        if (!more) c.items.clear();
        final seen = c.items.map((e) => e.id).toSet();
        c.items.addAll(fresh.where((e) => seen.add(e.id)));
        final next = r is Map ? r['nextCursor'] : null;
        c.cursor = next == null ? null : '$next';
        c.done = c.cursor == null || fresh.isEmpty;
        c.loaded = true;
        c.loading = false;
      });
      if (i == 0 && !more) {
        final total = r is Map ? r['total'] : null;
        widget.onPostsLoaded?.call(total is num ? total.toInt() : c.items.length, total is num ? false : !c.done);
      }
    } catch (e) {
      if (!mounted || gen != c.gen) return;
      setState(() {
        c.loading = false;
        // Reels ucu sunucuda yoksa (404/405): hata değil, boş.
        if (i == 1 && e is ApiError && (e.status == 404 || e.status == 405)) {
          c.unsupported = true;
          c.loaded = true;
          c.done = true;
        } else if (!c.loaded) {
          c.error = e;
        }
      });
    }
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    if (!widget.locked && !_cols[i].loaded) _load(i);
  }

  void _open(ProfileGridItem it, List<ProfileGridItem> all) {
    if (_index == 1 && widget.onOpenReel != null) {
      widget.onOpenReel!(it, all);
    } else {
      openPostDetail(context, widget.session, it.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    String label(String base, int? n) => n == null ? base : '$base $n';
    return Semantics(
      container: true,
      label: l.srProfileTabsLabel,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.gutter),
          child: BuSegmented(
            items: [label(l.srTabPosts, widget.postCount), label(l.srTabReels, widget.reelCount)],
            index: _index,
            onChanged: _select,
          ),
        ),
        const SizedBox(height: 12),
        if (widget.locked)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.gutter, vertical: 24),
            child: Column(children: [
              Icon(BuIcons.lock, size: 28, color: t.mut),
              const SizedBox(height: 8),
              Text(l.frqLockedTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium!.copyWith(color: t.ink)),
              const SizedBox(height: 4),
              Text(l.frqLockedBody, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.mut)),
            ]),
          )
        else
          AnimatedSwitcher(
            duration: BuMotion.of(context, BuMotion.medium),
            child: KeyedSubtree(key: ValueKey(_index), child: _body(context, _index)),
          ),
      ]),
    );
  }

  Widget _body(BuildContext context, int i) {
    final l = context.l10n;
    final t = context.bu;
    final c = _cols[i];
    if (c.error != null && c.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l.p05SearchErrorTitle, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.mut)),
            const SizedBox(height: 8),
            BuButton(label: l.commonRetry, compact: true, kind: BuButtonKind.outline, onPressed: () => _load(i)),
          ]),
        ),
      );
    }
    if (!c.loaded) {
      return BuSkeletonList(variant: BuSkeletonVariant.grid, itemCount: 6, shrinkWrap: true, padding: EdgeInsets.symmetric(horizontal: widget.gutter));
    }
    if (c.items.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.gutter, vertical: 32),
        child: Text(i == 0 ? l.srProfilePostsEmpty : l.srProfileReelsEmpty,
            key: ValueKey('profile-tab-empty-$i'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.mut)),
      );
    }
    final reels = i == 1;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.gutter),
        child: GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
            childAspectRatio: reels ? .62 : 1,
          ),
          itemCount: c.items.length,
          itemBuilder: (_, k) => ProfileGridTile(
            key: ValueKey('profile-${reels ? 'reel' : 'post'}-${c.items[k].id}'),
            item: c.items[k],
            reel: reels,
            headers: postAuthHeaders(widget.session),
            onTap: () => _open(c.items[k], c.items),
          ),
        ),
      ),
      if (!c.done)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(
            child: c.loading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))
                : BuButton(label: l.srLoadMore, compact: true, kind: BuButtonKind.outline, onPressed: () => _load(i, more: true)),
          ),
        ),
    ]);
  }
}

/// Profil grid karosu: kapak/fotoğraf; video için oynat rozeti + süre; reels'te alt solda görüntülenme sayısı.
class ProfileGridTile extends StatelessWidget {
  const ProfileGridTile({super.key, required this.item, required this.reel, required this.onTap, this.headers});

  final ProfileGridItem item;
  final bool reel;
  final VoidCallback onTap;
  final Map<String, String>? headers;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final dur = item.durationLabel;
    final showVideo = item.isVideo || reel;
    return Semantics(
      button: true,
      label: [
        reel || item.isVideo ? l.srVideoBadge : l.icerikOpenPost,
        if (item.views != null && reel) l.srViewCount('${item.views}'),
      ].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: BuPressable(
        scale: .96,
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BuRadius.bXs,
          child: Stack(fit: StackFit.expand, children: [
            ColoredBox(color: t.sf2),
            if (item.imageUrl != null)
              BuImage(item.imageUrl, headers: headers, maxDecodeWidth: 500, placeholderIcon: showVideo ? BuIcons.video : BuIcons.image)
            else if ((item.text ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(item.text!, maxLines: 5, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.ink, height: 1.3)),
              )
            else
              Center(child: Icon(showVideo ? BuIcons.video : BuIcons.image, size: 24, color: t.mut)),
            if (showVideo)
              PositionedDirectional(
                top: 6,
                end: 6,
                child: Icon(BuIcons.playFilled, size: 16, color: t.onMedia, shadows: [Shadow(color: t.scrim.withValues(alpha: .6), blurRadius: 4)]),
              ),
            if (reel && (dur != null || item.views != null))
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [t.scrim.withValues(alpha: 0), t.scrim.withValues(alpha: .62)],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(6, 16, 6, 5),
                    child: Row(children: [
                      if (item.views != null) ...[
                        Icon(BuIcons.eye, size: 13, color: t.onMedia),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text('${item.views}',
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(fontSize: 11, color: t.onMedia)),
                        ),
                      ],
                      const Spacer(),
                      if (dur != null) Text(dur, maxLines: 1, style: tx.labelMedium!.copyWith(fontSize: 11, color: t.onMedia)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

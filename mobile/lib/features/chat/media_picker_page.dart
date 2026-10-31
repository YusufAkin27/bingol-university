import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/locale_controller.dart';
import '../../core/permissions/ensure_permission.dart';
import '../../widgets/bu.dart';
import 'chat_media.dart';
import 'media_camera_page.dart';
import 'media_library.dart';
import 'media_pick.dart';
import 'media_preview_page.dart';
import 'sohbety_sheet.dart';

export 'media_pick.dart' show kMaxPicks, kMaxVideoMs;

typedef EnsureAccess = Future<bool> Function(BuildContext context, AppPermission permission, {String? rationale});

/// Tam ekran galeri seçici (P3-CHAT, modern ızgara): en yeni önce, 3 sütunlu sayfalı ızgara (4 dp aralık, 12 dp köşe),
/// seçilince köşede dolu kırmızı onay (çoklu seçimde sayı), seçili kare hafif küçülüp çerçeve alır; üstte sade çubuk
/// (Kapat, albüm, "Gönder (n)") ve alt çubuk YOK. [showCameraTile] ilk karoda kamera (gönderi oluşturucu); sohbette kamera
/// "+" menüsündedir. "Gönder (n)" önizlemeye gider; önizlemeden [MediaSendPlan] döner; kapatılırsa null.
class MediaPickerPage extends StatefulWidget {
  const MediaPickerPage({super.key, required this.library, this.ensureAccess, this.openCamera, this.pageSize = 60, this.maxItems = kMaxPicks, this.showCameraTile = true});

  final MediaLibrary library;
  final EnsureAccess? ensureAccess;
  final MediaCameraLauncher? openCamera;
  final int pageSize;

  /// En çok seçilebilecek öğe (varsayılan [kMaxPicks]; gönderi oluşturucu kalan hakkı verir).
  final int maxItems;

  /// İlk karoda kamera karosu (sohbette false: kamera "+" menüsünde).
  final bool showCameraTile;

  @override
  State<MediaPickerPage> createState() => _MediaPickerPageState();
}

class _MediaPickerPageState extends State<MediaPickerPage> {
  final _scroll = ScrollController();
  final _items = <GalleryItem>[];
  final _picked = <MediaPick>[];
  List<GalleryAlbum> _albums = const [];
  GalleryAlbum? _album;
  LibraryAccess? _access;
  bool _loading = true;
  bool _more = true;
  bool _busy = false;
  int _page = 0;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  bool _booted = false;

  // Yerelleştirilmiş gerekçe metni için bağlam gerekir: ilk bağımlılık çözümünde başlat.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    _booted = true;
    _boot();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    setState(() => _loading = true);
    try {
      final ensure = widget.ensureAccess ?? ensurePermission;
      final ok = await ensure(context, AppPermission.photos, rationale: context.l10n.chatMiscGalleryRationale);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _access = LibraryAccess.denied;
          _loading = false;
        });
        return;
      }
      final access = await widget.library.requestAccess();
      if (!mounted) return;
      if (access == LibraryAccess.denied) {
        setState(() {
          _access = access;
          _loading = false;
        });
        return;
      }
      final albums = await widget.library.albums();
      if (!mounted) return;
      _albums = albums;
      _album = albums.where((a) => a.isAll).firstOrNull ?? albums.firstOrNull;
      _access = access;
      await _reload();
    } catch (_) {
      if (mounted) {
        setState(() {
          _access = LibraryAccess.denied;
          _loading = false;
        });
      }
    }
  }

  Future<void> _reload() async {
    _gen++;
    _items.clear();
    _page = 0;
    _more = true;
    _busy = false;
    setState(() => _loading = true);
    await _loadMore();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (_busy || !_more) return;
    _busy = true;
    final gen = _gen;
    try {
      final next = await widget.library.items(_album?.id, page: _page, size: widget.pageSize);
      if (!mounted || gen != _gen) return;
      setState(() {
        _items.addAll(next);
        _page++;
        if (next.length < widget.pageSize) _more = false;
      });
    } catch (_) {
      if (mounted && gen == _gen) setState(() => _more = false);
    } finally {
      if (gen == _gen) _busy = false;
    }
    // İlk sayfa ekranı doldurmadıysa kaydırma olmayacağından devamını yükle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _more && _scroll.hasClients && _scroll.position.maxScrollExtent < 400) _loadMore();
    });
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) _loadMore();
  }

  void _toast(String msg) => BuToast.show(context, msg, kind: BuToastKind.warning);

  int _indexOf(String key) => _picked.indexWhere((p) => p.key == key);

  /// Sınırları denetleyip seçime ekler; olmazsa toast gösterir.
  bool _tryAdd(MediaPick p) {
    if (p.isVideo && p.durationMs > kMaxVideoMs + 500) {
      _toast(context.l10n.chatMiscVideoMax60);
      return false;
    }
    if (_picked.length >= widget.maxItems) {
      _toast(context.l10n.chatMiscPickMax(widget.maxItems.toString()));
      return false;
    }
    buHaptic();
    setState(() => _picked.add(p));
    return true;
  }

  MediaPick _pickOf(GalleryItem g) => MediaPick(
        key: g.id,
        isVideo: g.isVideo,
        durationMs: g.durationMs,
        thumb: (s) => widget.library.thumb(g, s),
        imageBytes: g.isVideo ? null : () => widget.library.imageBytes(g),
        videoPath: g.isVideo ? () => widget.library.videoPath(g) : null,
      );

  void _toggle(GalleryItem g) {
    final i = _indexOf(g.id);
    if (i >= 0) {
      buHaptic();
      setState(() => _picked.removeAt(i));
      return;
    }
    _tryAdd(_pickOf(g));
  }

  Future<void> _camera() async {
    final launcher = widget.openCamera;
    final pick = launcher != null ? await launcher(context) : await openMediaCamera(context);
    if (pick == null || !mounted) return;
    if (_tryAdd(pick)) await _preview();
  }

  Future<void> _preview() async {
    if (_picked.isEmpty) return;
    final plan = await Navigator.push<MediaSendPlan>(
      context,
      MaterialPageRoute(builder: (_) => MediaPreviewPage(picks: List.of(_picked))),
    );
    if (plan != null && mounted) Navigator.pop(context, plan);
  }

  Future<void> _chooseAlbum() async {
    final a = await showSohbetySheet<GalleryAlbum>(
      context,
      (c) => _AlbumSheet(library: widget.library, albums: _albums, current: _album),
    );
    if (a == null || a.id == _album?.id || !mounted) return;
    _album = a;
    await _reload();
  }

  Future<void> _manageLimited() async {
    try {
      await widget.library.manageLimited();
    } catch (_) {}
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _header(context),
          Expanded(child: _body(context)),
        ]),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final has = _picked.isNotEmpty;
    final title = _album == null || _album!.isAll ? l.sohbetmedyaRecent : _album!.name;
    return SizedBox(
      height: 56,
      child: Stack(alignment: Alignment.center, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 112),
          child: _albumPill(context, title),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: Semantics(
              button: true,
              label: l.chatMiscClose,
              excludeSemantics: true,
              child: BuPressable(
                key: const ValueKey('pickerClose'),
                onTap: () => Navigator.pop(context),
                child: SizedBox(width: 48, height: 48, child: Icon(LucideIcons.x, size: 24, color: t.ink)),
              ),
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Semantics(
              button: true,
              enabled: has,
              label: has ? l.p67PickerSend(_picked.length.toString()) : l.chatDetailSend,
              excludeSemantics: true,
              child: BuPressable(
                key: const ValueKey('pickerNext'),
                enabled: has,
                onTap: has ? _preview : null,
                haptic: BuHaptic.light,
                child: AnimatedOpacity(
                  opacity: has ? 1 : .45,
                  duration: BuMotion.of(context, BuMotion.short),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: t.pr, borderRadius: BuRadius.bPill),
                    child: Text(has ? l.p67PickerSend(_picked.length.toString()) : l.chatDetailSend,
                        maxLines: 1, style: tx.labelLarge!.copyWith(color: t.onPr, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _albumPill(BuildContext context, String title) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final multi = _albums.length > 1;
    final pill = Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bPill),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tx.labelMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w600, letterSpacing: .2)),
        ),
        if (multi) ...[
          BuGap.w6,
          Icon(LucideIcons.chevronDown, size: 18, color: t.ink),
        ],
      ]),
    );
    if (!multi) return pill;
    return Semantics(
      button: true,
      label: '$title, ${context.l10n.p10AlbumTitle}',
      excludeSemantics: true,
      child: BuPressable(key: const ValueKey('albumButton'), onTap: _chooseAlbum, haptic: BuHaptic.selection, child: pill),
    );
  }

  Widget _body(BuildContext context) {
    final t = context.bu;
    if (_access == LibraryAccess.denied) return _denied(context);
    if (_loading && _items.isEmpty) return _skeleton(context);
    return CustomScrollView(
      key: const ValueKey('galleryGrid'),
      controller: _scroll,
      slivers: [
        if (_access == LibraryAccess.limited) SliverToBoxAdapter(child: _limitedCard(context)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 4, crossAxisSpacing: 4),
            itemCount: _items.length + (widget.showCameraTile ? 1 : 0),
            itemBuilder: (c, i) {
              if (widget.showCameraTile && i == 0) return _cameraTile(t);
              final g = _items[widget.showCameraTile ? i - 1 : i];
              final order = _indexOf(g.id);
              return _GalleryTile(
                key: ValueKey('galleryTile_${g.id}'),
                item: g,
                library: widget.library,
                order: order < 0 ? null : order + 1,
                multi: widget.maxItems > 1,
                onTap: () => _toggle(g),
              );
            },
          ),
        ),
        if (!_loading && _items.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Text(context.l10n.p10GalleryEmpty,
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.mut)),
            ),
          ),
      ],
    );
  }

  /// Sınırlı erişim: bilgi + "Daha fazla seç" / "Ayarlar".
  Widget _limitedCard(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        key: const ValueKey('limitedBanner'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: t.sf, borderRadius: BuRadius.bLg, boxShadow: BuElevation.of(context, 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.sf2,
              borderRadius: BuRadius.bSm,
              border: Border.all(color: t.bd.withValues(alpha: .7)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ExcludeSemantics(child: Padding(padding: const EdgeInsets.only(top: 2), child: Icon(LucideIcons.info, size: 20, color: t.mut))),
              BuGap.w8,
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.chatMiscLimitedNote, style: tx.labelMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
                  BuGap.h2,
                  Text(l.p10LimitedBody, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.3)),
                ]),
              ),
            ]),
          ),
          BuGap.h12,
          Row(children: [
            Expanded(
              child: _ActionPill(
                key: const ValueKey('limitedMore'),
                label: l.chatMiscSelectMore,
                icon: LucideIcons.imagePlus,
                bg: t.sf2,
                fg: t.ink,
                onTap: _manageLimited,
              ),
            ),
            BuGap.w8,
            Expanded(
              child: _ActionPill(
                key: const ValueKey('limitedSettings'),
                label: l.chatMiscSettings,
                icon: LucideIcons.settings,
                bg: t.soft,
                fg: t.onSoft,
                onTap: () => widget.library.openSettings(),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  /// İzin yok: kilitli galeri çizimi + açıklama + "Ayarlardan aç".
  Widget _denied(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          key: const ValueKey('galleryDenied'),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: t.sf, borderRadius: BuRadius.bLg, boxShadow: BuElevation.of(context, 1)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: ExcludeSemantics(
                child: Container(
                  width: 96,
                  height: 96,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                  child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                    Icon(LucideIcons.images, size: 44, color: t.pr),
                    PositionedDirectional(
                      bottom: -8,
                      end: -14,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(color: t.nav, shape: BoxShape.circle, boxShadow: BuElevation.of(context, 2)),
                        child: Icon(LucideIcons.lock, size: 18, color: t.soft),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            BuGap.h12,
            Semantics(
              header: true,
              child: Text(l.chatMiscGalleryDenied,
                  textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
            ),
            BuGap.h8,
            Text(l.p10DeniedBody, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
            BuGap.h20,
            BuButton(
              key: const ValueKey('galleryOpenSettings'),
              label: l.chatMiscOpenSettings,
              icon: LucideIcons.settings,
              onPressed: () => widget.library.openSettings(),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _skeleton(BuildContext context) {
    return BuSkeletonScope(
      child: GridView.builder(
        key: const ValueKey('galleryLoading'),
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 4, crossAxisSpacing: 4),
        itemCount: 18,
        itemBuilder: (c, i) => const BuSkeleton(radius: 12),
      ),
    );
  }

  Widget _cameraTile(BuTokens t) {
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: context.l10n.chatMiscCamera,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('cameraTile'),
        onTap: _camera,
        child: Container(
          decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bSm),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.camera, size: 28, color: t.ink),
            BuGap.h4,
            Text(context.l10n.chatMiscCamera,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tx.labelMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

/// Sınırlı erişim kartındaki 50 dp'lik iki eylem düğmesi.
class _ActionPill extends StatelessWidget {
  const _ActionPill({super.key, required this.label, required this.icon, required this.bg, required this.fg, required this.onTap});

  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: BuPressable(
        onTap: onTap,
        haptic: BuHaptic.selection,
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: BuRadius.bMd),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: fg),
            BuGap.w6,
            Flexible(
              child: Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tx.labelLarge!.copyWith(color: fg, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _GalleryTile extends StatefulWidget {
  const _GalleryTile({super.key, required this.item, required this.library, required this.order, required this.onTap, this.multi = true});

  final GalleryItem item;
  final MediaLibrary library;
  final int? order;
  final VoidCallback onTap;

  /// Çoklu seçim: onay dairesinde sıra sayısı; tekli seçimde onay işareti.
  final bool multi;

  @override
  State<_GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends State<_GalleryTile> {
  late final Future<Uint8List?> _thumb = widget.library.thumb(widget.item, 300);

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final g = widget.item;
    final order = widget.order;
    final label = g.isVideo ? '${l.chatMiscVideo}, ${formatMediaDuration(g.durationMs)}' : l.chatMiscPhoto;
    return Semantics(
      button: true,
      selected: order != null,
      label: order == null ? label : '$label. ${l.p10TileSelected(order.toString())}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          // Seçili kare hafif küçülür ve marka rengi çerçeve alır (yalnız transform).
          scale: order != null ? .94 : 1,
          duration: BuMotion.of(context, BuMotion.short),
          curve: Curves.easeOutCubic,
          child: ClipRRect(
            borderRadius: BuRadius.bSm,
            child: Stack(fit: StackFit.expand, children: [
              ColoredBox(color: t.sf2),
              FutureBuilder<Uint8List?>(
                future: _thumb,
                builder: (c, s) => s.data == null
                    ? const SizedBox.shrink()
                    : Image.memory(s.data!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        cacheWidth: 300,
                        frameBuilder: (c, child, frame, sync) =>
                            sync ? child : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: BuMotion.of(c, BuMotion.medium), child: child)),
              ),
              if (order != null)
                Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: t.pr, width: 3), borderRadius: BuRadius.bSm))),
              PositionedDirectional(
                top: 8,
                end: 8,
                child: AnimatedContainer(
                  duration: BuMotion.of(context, BuMotion.short),
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: order != null ? t.pr : t.scrim.withValues(alpha: .28),
                    border: Border.all(color: order != null ? t.pr : t.onMedia, width: 1.5),
                  ),
                  child: order == null
                      ? null
                      : (widget.multi
                          ? Text('$order', style: tx.labelSmall!.copyWith(color: t.onPr, fontWeight: FontWeight.w700, height: 1, fontFeatures: const [FontFeature.tabularFigures()]))
                          : Icon(LucideIcons.check, size: 14, color: t.onPr)),
                ),
              ),
              if (g.isVideo)
                PositionedDirectional(
                  start: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: t.scrim.withValues(alpha: .65), borderRadius: BorderRadius.circular(6)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.play, size: 10, color: t.onMedia),
                      const SizedBox(width: 2),
                      Text(formatMediaDuration(g.durationMs),
                          style: tx.labelSmall!.copyWith(color: t.onMedia, fontWeight: FontWeight.w700, height: 1.2)),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Albüm alt sayfası (Stitch 25-3): başlık + albüm sayısı, küçük resimli satırlar, seçili olanda onay.
class _AlbumSheet extends StatelessWidget {
  const _AlbumSheet({required this.library, required this.albums, required this.current});

  final MediaLibrary library;
  final List<GalleryAlbum> albums;
  final GalleryAlbum? current;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final h = MediaQuery.sizeOf(context).height * .85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: h),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ExcludeSemantics(
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                decoration: BoxDecoration(color: t.bd, borderRadius: BuRadius.bPill),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
            child: Row(children: [
              Flexible(
                child: Semantics(
                  header: true,
                  child: Text(l.p10AlbumTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tx.headlineSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700, letterSpacing: -.3)),
                ),
              ),
              BuGap.w8,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bPill),
                child: Text(l.p10AlbumCount(albums.length.toString()),
                    maxLines: 1, style: tx.labelSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          Flexible(
            child: ListView.separated(
              key: const ValueKey('albumList'),
              shrinkWrap: true,
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
              itemCount: albums.length,
              separatorBuilder: (_, __) => Divider(height: 9, thickness: 1, color: t.bd.withValues(alpha: .6)),
              itemBuilder: (c, i) => _AlbumRow(
                key: ValueKey('albumRow_${albums[i].id}'),
                library: library,
                album: albums[i],
                selected: albums[i].id == current?.id,
                onTap: () => Navigator.pop(context, albums[i]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _AlbumRow extends StatefulWidget {
  const _AlbumRow({super.key, required this.library, required this.album, required this.selected, required this.onTap});

  final MediaLibrary library;
  final GalleryAlbum album;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_AlbumRow> createState() => _AlbumRowState();
}

class _AlbumRowState extends State<_AlbumRow> {
  late final Future<Uint8List?> _cover = _loadCover();

  Future<Uint8List?> _loadCover() async {
    try {
      final first = await widget.library.items(widget.album.id, page: 0, size: 1);
      if (first.isEmpty) return null;
      return await widget.library.thumb(first.first, 192);
    } catch (_) {
      return null;
    }
  }

  /// Bilinen sistem albümlerine küçük rozet (ad eşleşmesi; bilinmeyende rozet yok).
  IconData? _badge(String name) {
    final n = name.toLowerCase();
    if (n.contains('camera') || n.contains('kamera') || n == 'dcim') return LucideIcons.camera;
    if (n.contains('screenshot') || n.contains('ekran')) return LucideIcons.smartphone;
    if (n.contains('download') || n.contains('indirilen')) return LucideIcons.download;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final a = widget.album;
    final sel = widget.selected;
    final name = a.isAll ? l.sohbetmedyaRecent : a.name;
    final count = NumberFormat.decimalPattern(Localizations.localeOf(context).toString()).format(a.count);
    final badge = a.isAll ? null : _badge(a.name);
    return Semantics(
      button: true,
      selected: sel,
      label: '$name, $count ${l.p10ItemUnit}',
      excludeSemantics: true,
      child: BuPressable(
        onTap: widget.onTap,
        scale: .99,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: sel ? t.soft.withValues(alpha: .55) : t.sf3, borderRadius: BuRadius.bLg),
          child: Row(children: [
            SizedBox(
              width: 64,
              height: 64,
              child: ClipRRect(
                borderRadius: BuRadius.bMd,
                child: Stack(fit: StackFit.expand, children: [
                  ColoredBox(color: t.sf2),
                  FutureBuilder<Uint8List?>(
                    future: _cover,
                    builder: (c, s) => s.data == null
                        ? Icon(LucideIcons.image, size: 24, color: t.mut)
                        : Image.memory(s.data!, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: 192),
                  ),
                  if (badge != null)
                    PositionedDirectional(
                      bottom: 4,
                      end: 4,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(color: t.nav.withValues(alpha: .8), shape: BoxShape.circle),
                        child: Icon(badge, size: 12, color: t.onNav),
                      ),
                    ),
                ]),
              ),
            ),
            BuGap.w16,
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: sel ? FontWeight.w700 : FontWeight.w600)),
                BuGap.h2,
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: sel ? t.sf : t.sf2, borderRadius: BuRadius.bPill),
                    child: Text(count,
                        style: tx.labelMedium!.copyWith(color: sel ? t.pr : t.mut, fontWeight: sel ? FontWeight.w600 : FontWeight.w500)),
                  ),
                  BuGap.w4,
                  Flexible(
                    child: Text(l.p10ItemUnit,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
                  ),
                ]),
              ]),
            ),
            BuGap.w8,
            if (sel)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle),
                child: Icon(LucideIcons.check, size: 20, color: t.onPr),
              )
            else
              const SizedBox(width: 32, height: 32),
          ]),
        ),
      ),
    );
  }
}

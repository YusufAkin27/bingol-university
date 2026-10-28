import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/permissions/ensure_permission.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'chat_media.dart';
import 'media_camera_page.dart';
import 'media_library.dart';
import 'media_pick.dart';
import 'media_preview_page.dart';

typedef EnsureAccess = Future<bool> Function(BuildContext context, AppPermission permission, {String? rationale});

/// Mesaja en çok seçilebilecek öğe sayısı (foto ve video karışık; sunucu kuralı).
const kMaxPicks = 10;
const kMaxVideoMs = 60 * 1000;

// Tasarımdaki sabit koyu kamera karosu (iki temada aynı).
const _kCamTile = Color(0xFF171E33);

/// Tam ekran galeri seçici: en yeni önce, sayfalı kare ızgara, ilk karo kamera, çoklu seçim.
/// "Önizle" ya da "Gönder" ile [MediaSendPlan] döner; kapatılırsa null.
class MediaPickerPage extends StatefulWidget {
  const MediaPickerPage({super.key, required this.library, this.ensureAccess, this.openCamera, this.pageSize = 60, this.maxItems = kMaxPicks});

  final MediaLibrary library;
  final EnsureAccess? ensureAccess;
  final MediaCameraLauncher? openCamera;
  final int pageSize;

  /// En çok seçilebilecek öğe (varsayılan [kMaxPicks]; gönderi oluşturucu kalan hakkı verir).
  final int maxItems;

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
      final ok = await ensure(context, AppPermission.photos,
          rationale: context.l10n.chatMiscGalleryRationale);
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

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

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
      setState(() => _picked.removeAt(i));
      return;
    }
    _tryAdd(_pickOf(g));
  }

  Future<void> _camera() async {
    final pick = await (widget.openCamera ?? openMediaCamera)(context);
    if (pick == null || !mounted) return;
    if (_tryAdd(pick)) await _preview();
  }

  Future<void> _preview() async {
    if (_picked.isEmpty) return;
    final plan = await Navigator.push<MediaSendPlan>(
      context,
      MaterialPageRoute(
        builder: (_) => MediaPreviewPage(
          picks: List.of(_picked),
          onChanged: (list) {
            if (!mounted) return;
            setState(() => _picked
              ..clear()
              ..addAll(list));
          },
        ),
      ),
    );
    if (plan != null && mounted) Navigator.pop(context, plan);
  }

  void _sendNow() {
    if (_picked.isEmpty) return;
    Navigator.pop(context, MediaSendPlan([for (final p in _picked) MediaSendItem(p)], ''));
  }

  Future<void> _chooseAlbum() async {
    final t = context.bu;
    final a = await showModalBottomSheet<GalleryAlbum>(
      context: context,
      backgroundColor: t.sf,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * .7),
          child: ListView(shrinkWrap: true, children: [
            for (final al in _albums)
              BuMenuRow(
                icon: LucideIcons.image,
                label: '${al.isAll ? context.l10n.chatMiscAll : al.name} (${al.count})',
                showChevron: false,
                onTap: () => Navigator.pop(c, al),
              ),
          ]),
        ),
      ),
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
    final l = context.l10n;
    final title = _album == null || _album!.isAll ? l.sohbetmedyaRecent : _album!.name;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Row(children: [
              Semantics(
                button: true,
                label: l.chatMiscClose,
                child: GestureDetector(
                  key: const ValueKey('pickerClose'),
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: t.sf, shape: BoxShape.circle, border: Border.all(color: t.bd)),
                    child: Icon(LucideIcons.x, size: 20, color: t.ink),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(l.chatMiscGallery,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.title.copyWith(color: t.ink)),
                  Text(l.sohbetmedyaSelectedOf(_picked.length.toString(), widget.maxItems.toString()),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.label.copyWith(color: t.mut)),
                ]),
              ),
              if (_picked.isNotEmpty) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  key: const ValueKey('pickerPreview'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _preview,
                  child: Semantics(
                    button: true,
                    label: l.sohbetmedyaNext,
                    excludeSemantics: true,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: t.pr,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [BoxShadow(color: t.pr.withValues(alpha: .35), blurRadius: 20, offset: const Offset(0, 10), spreadRadius: -10)],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(l.sohbetmedyaNext, style: BuType.bodyStrong.copyWith(color: t.onPr, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Icon(Directionality.of(context) == TextDirection.rtl ? LucideIcons.arrowLeft : LucideIcons.arrowRight,
                            size: 16, color: t.onPr),
                      ]),
                    ),
                  ),
                ),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(children: [
              Flexible(child: _albumPill(t, title)),
              const SizedBox(width: 8),
              if (_picked.isEmpty)
                Text(l.sohbetmedyaPhotoVideo, style: BuType.label.copyWith(color: t.mut))
              else
                GestureDetector(
                  key: const ValueKey('pickerSend'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _sendNow,
                  child: Semantics(
                    button: true,
                    label: l.chatMiscSend,
                    excludeSemantics: true,
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(18), border: Border.all(color: t.pr)),
                      child: Text(l.chatMiscSend, style: BuType.bodyStrong.copyWith(color: t.pr, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
            ]),
          ),
          if (_access == LibraryAccess.limited) _limitedBanner(t),
          Expanded(child: _body(t)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(l.sohbetmedyaLimitNote(widget.maxItems.toString()),
                textAlign: TextAlign.center, style: BuType.label.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
          ),
        ]),
      ),
    );
  }

  Widget _albumPill(BuTokens t, String title) {
    final multi = _albums.length > 1;
    final pill = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.bd)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: Text(title,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.bodyStrong.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
        ),
        if (multi) ...[
          const SizedBox(width: 8),
          Icon(LucideIcons.chevronDown, size: 16, color: t.mut),
        ],
      ]),
    );
    if (!multi) return pill;
    return GestureDetector(key: const ValueKey('albumButton'), behavior: HitTestBehavior.opaque, onTap: _chooseAlbum, child: pill);
  }

  Widget _limitedBanner(BuTokens t) => Container(
        key: const ValueKey('limitedBanner'),
        width: double.infinity,
        color: t.sf2,
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
        child: Row(children: [
          Expanded(
            child: Text(context.l10n.chatMiscLimitedNote, style: BuType.caption.copyWith(color: t.mut)),
          ),
          TextButton(
            onPressed: _manageLimited,
            child: Text(context.l10n.chatMiscSelectMore, style: BuType.label.copyWith(color: t.pr)),
          ),
          TextButton(
            onPressed: () => widget.library.openSettings(),
            child: Text(context.l10n.chatMiscSettings, style: BuType.label.copyWith(color: t.pr)),
          ),
        ]),
      );

  Widget _body(BuTokens t) {
    if (_access == LibraryAccess.denied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.image, size: 32.5, color: t.mut),
            const SizedBox(height: 12),
            Text(context.l10n.chatMiscGalleryDenied, textAlign: TextAlign.center, style: BuType.body.copyWith(color: t.mut)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => widget.library.openSettings(),
              child: Text(context.l10n.chatMiscOpenSettings, style: BuType.bodyStrong.copyWith(color: t.pr)),
            ),
          ]),
        ),
      );
    }
    if (_loading && _items.isEmpty) return const Center(child: CircularProgressIndicator());
    return GridView.builder(
      key: const ValueKey('galleryGrid'),
      controller: _scroll,
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 3, crossAxisSpacing: 3),
      itemCount: _items.length + 1,
      itemBuilder: (c, i) {
        if (i == 0) return _cameraTile(t);
        final g = _items[i - 1];
        final order = _indexOf(g.id);
        return _GalleryTile(
          key: ValueKey('galleryTile_${g.id}'),
          item: g,
          library: widget.library,
          order: order < 0 ? null : order + 1,
          onTap: () => _toggle(g),
        );
      },
    );
  }

  Widget _cameraTile(BuTokens t) => Semantics(
        button: true,
        label: context.l10n.chatMiscCamera,
        child: GestureDetector(
          key: const ValueKey('cameraTile'),
          onTap: _camera,
          child: Container(
            color: _kCamTile,
            alignment: Alignment.center,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(LucideIcons.camera, size: 30, color: Colors.white),
              const SizedBox(height: 8),
              Text(context.l10n.chatMiscCamera,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BuType.label.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

class _GalleryTile extends StatefulWidget {
  const _GalleryTile({super.key, required this.item, required this.library, required this.order, required this.onTap});

  final GalleryItem item;
  final MediaLibrary library;
  final int? order;
  final VoidCallback onTap;

  @override
  State<_GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends State<_GalleryTile> {
  late final Future<Uint8List?> _thumb = widget.library.thumb(widget.item, 200);

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final g = widget.item;
    final order = widget.order;
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(fit: StackFit.expand, children: [
        ColoredBox(color: t.sf2),
        FutureBuilder<Uint8List?>(
          future: _thumb,
          builder: (c, s) => s.data == null
              ? const SizedBox.shrink()
              : Image.memory(s.data!, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: 200),
        ),
        if (order != null) ...[
          ColoredBox(color: const Color(0xFF171E33).withValues(alpha: .18)),
          IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: t.pr, width: 3)))),
        ],
        if (g.isVideo)
          PositionedDirectional(
            start: 7,
            bottom: 7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF171E33).withValues(alpha: .66), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.video, size: 12, color: Colors.white),
                const SizedBox(width: 4),
                Text(formatMediaDuration(g.durationMs), style: BuType.micro.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        PositionedDirectional(
          top: 7,
          end: 7,
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: order != null ? t.pr : const Color(0xFF171E33).withValues(alpha: .3),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: order != null ? Text('$order', style: BuType.label.copyWith(color: t.onPr, fontWeight: FontWeight.w800)) : null,
          ),
        ),
      ]),
    );
  }
}

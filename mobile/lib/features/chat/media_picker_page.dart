import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

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
          rationale: 'Galerindeki fotoğraf ve videoları gösterebilmemiz için erişim izni gerekir.');
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
      _toast('Video en fazla 60 saniye olabilir');
      return false;
    }
    if (_picked.length >= widget.maxItems) {
      _toast('En fazla ${widget.maxItems} öğe seçebilirsin');
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
                label: '${al.isAll ? 'Tümü' : al.name} (${al.count})',
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
    final title = _album == null || _album!.isAll ? 'Tümü' : _album!.name;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(children: [
              IconButton(
                key: const ValueKey('pickerClose'),
                tooltip: 'Kapat',
                icon: Icon(LucideIcons.x, color: t.ink),
                onPressed: () => Navigator.pop(context),
              ),
              Text('Galeri', style: BuType.heading.copyWith(color: t.ink)),
              const SizedBox(width: 12),
              if (_albums.length > 1)
                Flexible(
                  child: InkWell(
                    key: const ValueKey('albumButton'),
                    borderRadius: BorderRadius.circular(999),
                    onTap: _chooseAlbum,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BuType.bodyStrong.copyWith(color: t.pr)),
                        ),
                        Icon(LucideIcons.chevronDown, size: 14.5, color: t.pr),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
          if (_access == LibraryAccess.limited) _limitedBanner(t),
          Expanded(child: _body(t)),
          if (_picked.isNotEmpty) _bar(t),
        ]),
      ),
    );
  }

  Widget _limitedBanner(BuTokens t) => Container(
        key: const ValueKey('limitedBanner'),
        width: double.infinity,
        color: t.sf2,
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(children: [
          Expanded(
            child: Text('Yalnızca izin verdiğin öğeler görünüyor.', style: BuType.caption.copyWith(color: t.mut)),
          ),
          TextButton(
            onPressed: _manageLimited,
            child: Text('Daha fazla seç', style: BuType.label.copyWith(color: t.pr)),
          ),
          TextButton(
            onPressed: () => widget.library.openSettings(),
            child: Text('Ayarlar', style: BuType.label.copyWith(color: t.pr)),
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
            Text('Galeriye erişim izni verilmedi.', textAlign: TextAlign.center, style: BuType.body.copyWith(color: t.mut)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => widget.library.openSettings(),
              child: Text('Ayarlardan aç', style: BuType.bodyStrong.copyWith(color: t.pr)),
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
          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
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
        label: 'Kamera',
        child: GestureDetector(
          key: const ValueKey('cameraTile'),
          onTap: _camera,
          child: Container(
            color: t.sf2,
            alignment: Alignment.center,
            child: Icon(LucideIcons.camera, size: 27, color: t.mut),
          ),
        ),
      );

  Widget _bar(BuTokens t) => Container(
        decoration: BoxDecoration(color: t.sf, border: Border(top: BorderSide(color: t.bd))),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          Expanded(
            child: BuButton(
              key: const ValueKey('pickerPreview'),
              label: 'Önizle (${_picked.length})',
              kind: BuButtonKind.outline,
              onPressed: _preview,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: BuButton(key: const ValueKey('pickerSend'), label: 'Gönder', onPressed: _sendNow),
          ),
        ]),
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
        if (order != null) Container(color: Colors.black.withValues(alpha: .25)),
        if (g.isVideo)
          PositionedDirectional(
            start: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.video, size: 10, color: Colors.white),
                const SizedBox(width: 3),
                Text(formatMediaDuration(g.durationMs), style: BuType.micro.copyWith(color: Colors.white)),
              ]),
            ),
          ),
        PositionedDirectional(
          top: 6,
          end: 6,
          child: Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: order != null ? t.pr : Colors.black.withValues(alpha: .15),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: order != null ? Text('$order', style: BuType.micro.copyWith(color: t.onPr, fontWeight: FontWeight.w700)) : null,
          ),
        ),
      ]),
    );
  }
}

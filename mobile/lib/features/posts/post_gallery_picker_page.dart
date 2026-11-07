import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/locale_controller.dart';
import '../../core/permissions/ensure_permission.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../chat/chat_media.dart' show formatMediaDuration;
import '../chat/media_camera_page.dart';
import '../chat/media_library.dart';
import '../chat/media_pick.dart';
import '../chat/media_picker_page.dart' show GalleryAlbumSheet, EnsureAccess;
import '../chat/sohbety_sheet.dart';
import 'compose_post_page.dart';
import 'post_models.dart';

/// Sistem seçicisinden (image_picker) tek fotoğraf/video alır; testlerde sahtesi verilir.
typedef SystemMediaPicker = Future<MediaPick?> Function();

/// Seçilen öğeyle gönderi oluşturucuyu kuran işlev (testlerde API/yükleyici enjekte etmek için).
typedef PostComposeBuilder = Widget Function(Uint8List? photo, String? videoPath);

/// Paylaş (+) girişi: seçenek sayfası YOK, doğrudan galeri ızgarası. Galeriden/kameradan seçilen öğe gönderi
/// oluşturucuya geçer; paylaşılırsa [Post] döner, vazgeçilirse null.
Future<Post?> openPostGalleryPicker(BuildContext context, Session session, {MediaLibrary? library}) =>
    Navigator.of(context).push<Post>(MaterialPageRoute<Post>(
      settings: const RouteSettings(name: 'post_gallery'),
      fullscreenDialog: true,
      builder: (_) => PostGalleryPickerPage(session: session, library: library),
    ));

/// Gönderi galeri seçici (Instagram/WhatsApp galerisi gibi): cihazdaki en yeni fotoğraf ve videolar sıkı kare ızgarada
/// (2 dp aralık, telefonda 4 sütun), ızgaranın mantıksal BAŞ karesi (Türkçede sol üst) kamera karosudur. Dokun = seç +
/// ilerle: önizleme/onay adımı yoktur, öğe hemen gönderi oluşturucuya (fotoğraf: kırpma; video: süre aşıyorsa zorunlu
/// kırpma + kapak) geçer. Tek öğe seçilir. Kamera karosu uygulama içi kamerayı açar (dokun = fotoğraf, basılı tut =
/// video, en çok 60 sn). İzin yoksa açıklama + "Ayarlardan aç" + sistem seçicisine yedek yol.
///
/// Üst çubuk: kapat (X) ve albüm adı hapı ("Son eklenenler" ↔ albümler). "Yeni gönderi" başlığı görünmez (sayfa adı
/// başlığı gizleme kuralı; yalnız ekran okuyucu başlığı), alt eylem çubuğu yoktur.
class PostGalleryPickerPage extends StatefulWidget {
  const PostGalleryPickerPage({
    super.key,
    required this.session,
    this.library,
    this.ensureAccess,
    this.openCamera,
    this.systemPicker,
    this.composeBuilder,
    this.pageSize = 60,
  });

  final Session session;

  /// Galeri sağlayıcısı (üretimde [PhotoManagerLibrary]; testlerde sahte).
  final MediaLibrary? library;
  final EnsureAccess? ensureAccess;
  final MediaCameraLauncher? openCamera;
  final SystemMediaPicker? systemPicker;
  final PostComposeBuilder? composeBuilder;
  final int pageSize;

  @override
  State<PostGalleryPickerPage> createState() => _PostGalleryPickerPageState();
}

class _PostGalleryPickerPageState extends State<PostGalleryPickerPage> with WidgetsBindingObserver {
  late final MediaLibrary _lib = widget.library ?? PhotoManagerLibrary();
  final _scroll = ScrollController();
  final _items = <GalleryItem>[];
  List<GalleryAlbum> _albums = const [];
  GalleryAlbum? _album;
  LibraryAccess? _access;
  bool _loading = true;
  bool _more = true;
  bool _fetching = false;
  int _page = 0;
  int _gen = 0;
  bool _booted = false;

  /// Seçilen öğe çözülürken (HEIC dönüşümü, dosya yolu) ya da oluşturucu açıkken ikinci dokunuşu engeller.
  String? _opening;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
  }

  // Yerelleştirilmiş metin için bağlam gerekir: ilk bağımlılık çözümünde başlat.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    _booted = true;
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Ayarlar'dan izin verilip dönülürse ızgara kendiliğinden dolar.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _access != LibraryAccess.denied) return;
    unawaited(() async {
      final a = await _lib.currentAccess();
      if (mounted && a != null && a != LibraryAccess.denied) await _boot();
    }());
  }

  Future<void> _boot() async {
    setState(() => _loading = true);
    try {
      // Varsayılan: izin YALNIZ photo_manager ile istenir (Android'de görsel + video tek istemde; permission_handler
      // yalnız görsel izni isterdi ve Android 14'te yanlışlıkla "sınırlı" görünürdü). Reddedilince açıklama ekranı çıkar.
      final ensure = widget.ensureAccess ?? (BuildContext c, AppPermission p, {String? rationale}) async => true;
      final ok = await ensure(context, AppPermission.photos, rationale: context.l10n.chatMiscGalleryRationale);
      if (!mounted) return;
      if (!ok) return _deny();
      final access = await _lib.requestAccess();
      if (!mounted) return;
      if (access == LibraryAccess.denied) return _deny();
      final albums = await _lib.albums();
      if (!mounted) return;
      _albums = albums;
      _album = albums.where((a) => a.isAll).firstOrNull ?? albums.firstOrNull;
      _access = access;
      await _reload();
    } catch (_) {
      if (mounted) _deny();
    }
  }

  void _deny() => setState(() {
        _access = LibraryAccess.denied;
        _loading = false;
      });

  Future<void> _reload() async {
    _gen++;
    _items.clear();
    _page = 0;
    _more = true;
    _fetching = false;
    setState(() => _loading = true);
    await _loadMore();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (_fetching || !_more) return;
    _fetching = true;
    final gen = _gen;
    try {
      final next = await _lib.items(_album?.id, page: _page, size: widget.pageSize);
      if (!mounted || gen != _gen) return;
      setState(() {
        _items.addAll(next);
        _page++;
        if (next.length < widget.pageSize) _more = false;
      });
    } catch (_) {
      if (mounted && gen == _gen) setState(() => _more = false);
    } finally {
      if (gen == _gen) _fetching = false;
    }
    // İlk sayfa ekranı doldurmadıysa kaydırma olmayacağından devamını yükle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _more && _scroll.hasClients && _scroll.position.maxScrollExtent < 400) _loadMore();
    });
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 800) _loadMore();
  }

  // ---- Seçim -> gönderi oluşturucu ------------------------------------------------------------------------------------

  MediaPick _pickOf(GalleryItem g) => MediaPick(
        key: g.id,
        isVideo: g.isVideo,
        durationMs: g.durationMs,
        thumb: (s) => _lib.thumb(g, s),
        imageBytes: g.isVideo ? null : () => _lib.imageBytes(g),
        videoPath: g.isVideo ? () => _lib.videoPath(g) : null,
      );

  /// Öğeyi çözüp oluşturucuyu açar; paylaşıldıysa seçiciyi de kapatıp [Post] döndürür. Oluşturucudan vazgeçilirse
  /// (geri / Değiştir) ızgara olduğu yerde kalır, başka öğe seçilebilir.
  Future<void> _open(MediaPick p, {String? id}) async {
    if (_opening != null) return;
    setState(() => _opening = id ?? p.key);
    Post? post;
    try {
      Uint8List? photo;
      String? video;
      if (p.isVideo) {
        video = await p.videoPath?.call();
      } else {
        photo = await p.imageBytes?.call();
      }
      if (!mounted) return;
      if ((photo == null || photo.isEmpty) && (video == null || video.isEmpty)) {
        BuToast.show(context, context.l10n.postComposeErrPrepare, kind: BuToastKind.error);
        return;
      }
      post = await Navigator.of(context).push<Post>(MaterialPageRoute<Post>(
        settings: const RouteSettings(name: 'compose_post'),
        fullscreenDialog: true,
        builder: (_) =>
            widget.composeBuilder?.call(photo, video) ?? ComposePostPage(session: widget.session, initialPhoto: photo, initialVideoPath: video),
      ));
    } catch (_) {
      if (mounted) BuToast.show(context, context.l10n.postComposeErrPrepare, kind: BuToastKind.error);
    } finally {
      if (mounted) setState(() => _opening = null);
    }
    if (post != null && mounted) Navigator.pop(context, post);
  }

  Future<void> _camera() async {
    final launcher = widget.openCamera ?? (c) => openMediaCamera(c, hint: c.l10n.postPickerCameraHint);
    final pick = await launcher(context);
    if (pick == null || !mounted) return;
    await _open(pick);
  }

  Future<void> _system() async {
    final picker = widget.systemPicker ?? _defaultSystemPicker;
    MediaPick? pick;
    try {
      pick = await picker();
    } catch (_) {
      if (mounted) BuToast.show(context, context.l10n.postComposeErrPrepare, kind: BuToastKind.error);
      return;
    }
    if (pick == null || !mounted) return;
    await _open(pick);
  }

  Future<void> _chooseAlbum() async {
    final a = await showSohbetySheet<GalleryAlbum>(
      context,
      (c) => GalleryAlbumSheet(library: _lib, albums: _albums, current: _album),
    );
    if (a == null || a.id == _album?.id || !mounted) return;
    _album = a;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    await _reload();
  }

  Future<void> _manageLimited() async {
    try {
      await _lib.manageLimited();
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
    if (mounted) await _reload();
  }

  // ---- Çizim ----------------------------------------------------------------------------------------------------------

  int _columns(double w) => w >= 600 ? 5 : (w >= 340 ? 4 : 3);

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
    final title = _album == null || _album!.isAll ? l.sohbetmedyaRecent : _album!.name;
    final multi = _albums.length > 1;
    final pill = Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w400))),
        if (multi) ...[
          BuGap.w6,
          Icon(BuIcons.chevronDown, size: 18, color: t.ink),
        ],
      ]),
    );
    return SizedBox(
      height: 52,
      child: Stack(alignment: Alignment.center, children: [
        // Başlık metni görünmez (sayfa adı gizleme kuralı); yalnız ekran okuyucu başlığı.
        Semantics(header: true, label: l.postComposeNewPost, child: const SizedBox.shrink()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 64),
          child: multi
              ? Semantics(
                  button: true,
                  label: '$title, ${l.p10AlbumTitle}',
                  excludeSemantics: true,
                  child: BuPressable(key: const ValueKey('postAlbumButton'), onTap: _chooseAlbum, haptic: BuHaptic.selection, child: pill),
                )
              : pill,
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
                key: const ValueKey('postPickerClose'),
                onTap: () => Navigator.maybePop(context),
                child: SizedBox(width: 48, height: 48, child: Icon(BuIcons.x, size: 24, color: t.ink)),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _body(BuildContext context) {
    final t = context.bu;
    if (_access == LibraryAccess.denied) return _denied(context);
    if (_loading && _items.isEmpty) return _skeleton(context);
    final cols = _columns(MediaQuery.sizeOf(context).width);
    return Stack(children: [
      CustomScrollView(
        key: const ValueKey('postGalleryGrid'),
        controller: _scroll,
        slivers: [
          if (_access == LibraryAccess.limited) SliverToBoxAdapter(child: _limitedCard(context)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(0, 2, 0, 24 + MediaQuery.paddingOf(context).bottom),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 2, crossAxisSpacing: 2),
              itemCount: _items.length + 1,
              itemBuilder: (c, i) {
                if (i == 0) return _cameraTile(t);
                final g = _items[i - 1];
                return _PostTile(
                  key: ValueKey('postTile_${g.id}'),
                  item: g,
                  library: _lib,
                  busy: _opening == g.id,
                  onTap: () => _open(_pickOf(g), id: g.id),
                );
              },
            ),
          ),
          if (!_loading && _items.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: Text(context.l10n.p10GalleryEmpty,
                    key: const ValueKey('postGalleryEmpty'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.mut)),
              ),
            ),
        ],
      ),
      // Öğe çözülürken (büyük fotoğraf dönüşümü) dokunmayı yutan ince ilerleme göstergesi.
      if (_opening != null)
        const Positioned(left: 0, right: 0, top: 0, child: LinearProgressIndicator(key: ValueKey('postPickerBusy'), minHeight: 2)),
    ]);
  }

  /// Sınırlı erişim (iOS 14+ / Android 14): kısa bilgi + "Daha fazla seç" + "Ayarlar".
  Widget _limitedCard(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Padding(
      key: const ValueKey('postLimitedBanner'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bMd, border: Border.all(color: t.bd)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ExcludeSemantics(child: Padding(padding: const EdgeInsets.only(top: 2), child: Icon(BuIcons.info, size: 18, color: t.mut))),
            BuGap.w8,
            Expanded(child: Text(l.postPickerLimitedBody, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.35))),
          ]),
          BuGap.h8,
          Row(children: [
            Expanded(child: _LinkButton(key: const ValueKey('postLimitedMore'), label: l.chatMiscSelectMore, onTap: _manageLimited)),
            Expanded(child: _LinkButton(key: const ValueKey('postLimitedSettings'), label: l.chatMiscSettings, onTap: () => _lib.openSettings())),
          ]),
        ]),
      ),
    );
  }

  /// İzin yok: açıklama + "Ayarlardan aç" + sistem seçicisi (izin gerektirmez) + kamera (kendi izniyle).
  Widget _denied(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: Column(key: const ValueKey('postGalleryDenied'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ExcludeSemantics(
            child: Center(
              child: Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: t.sf2, border: Border.all(color: t.bdSubtle), shape: BoxShape.circle),
                child: Icon(BuIcons.images, size: 34, color: t.ink),
              ),
            ),
          ),
          BuGap.h16,
          Semantics(
            header: true,
            child: Text(l.chatMiscGalleryDenied, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
          ),
          BuGap.h8,
          Text(l.postPickerDeniedBody, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
          BuGap.h20,
          BuButton(key: const ValueKey('postGalleryOpenSettings'), label: l.chatMiscOpenSettings, icon: BuIcons.settings, onPressed: () => _lib.openSettings()),
          BuGap.h4,
          TextButton(
            key: const ValueKey('postPickerSystem'),
            onPressed: _system,
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: t.ink),
            child: Text(l.postPickerUseSystem, style: tx.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
          ),
          TextButton(
            key: const ValueKey('postPickerDeniedCamera'),
            onPressed: _camera,
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: t.ink),
            child: Text(l.chatMiscCamera, style: tx.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
          ),
        ]),
      ),
    );
  }

  Widget _skeleton(BuildContext context) {
    final cols = _columns(MediaQuery.sizeOf(context).width);
    return BuSkeletonScope(
      child: GridView.builder(
        key: const ValueKey('postGalleryLoading'),
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 2),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 2, crossAxisSpacing: 2),
        itemCount: cols * 8,
        itemBuilder: (c, i) => i == 0 ? _cameraTile(context.bu) : const BuSkeleton(radius: 0),
      ),
    );
  }

  /// Izgaranın ilk (mantıksal baş) karesi: kamera. RTL'de sağ üst olur.
  Widget _cameraTile(BuTokens t) {
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: context.l10n.chatMiscCamera,
      excludeSemantics: true,
      child: BuPressable(
        key: const ValueKey('postCameraTile'),
        onTap: _camera,
        scale: .96,
        haptic: BuHaptic.selection,
        child: Container(
          color: t.sf2,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(BuIcons.camera, size: 28, color: t.ink),
            BuGap.h4,
            Text(context.l10n.chatMiscCamera, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
          ]),
        ),
      ),
    );
  }
}

/// image_picker ile tek fotoğraf ya da video (Android Photo Picker / iOS PHPicker: galeri izni gerekmez).
Future<MediaPick?> _defaultSystemPicker() async {
  final f = await ImagePicker().pickMedia(maxWidth: 2048, maxHeight: 2048, imageQuality: 90, requestFullMetadata: false);
  if (f == null) return null;
  final name = f.path.toLowerCase();
  final video = (f.mimeType ?? '').startsWith('video/') ||
      const ['.mp4', '.mov', '.m4v', '.3gp', '.webm', '.mkv', '.avi'].any(name.endsWith);
  final key = 'sys_${DateTime.now().microsecondsSinceEpoch}';
  return video
      ? MediaPick(key: key, isVideo: true, thumb: (_) async => null, videoPath: () async => f.path)
      : MediaPick(key: key, isVideo: false, thumb: (_) async => null, imageBytes: () => f.readAsBytes());
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: BuPressable(
        onTap: onTap,
        haptic: BuHaptic.selection,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400, decoration: TextDecoration.underline)),
          ),
        ),
      ),
    );
  }
}

/// Izgara karesi: küçük resim (300 px, tembel), videoda süre rozeti. Seçim göstergesi yok (dokun = ilerle).
class _PostTile extends StatefulWidget {
  const _PostTile({super.key, required this.item, required this.library, required this.onTap, this.busy = false});

  final GalleryItem item;
  final MediaLibrary library;
  final VoidCallback onTap;
  final bool busy;

  @override
  State<_PostTile> createState() => _PostTileState();
}

class _PostTileState extends State<_PostTile> {
  late final Future<Uint8List?> _thumb = widget.library.thumb(widget.item, 300);

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final g = widget.item;
    final label = g.isVideo ? '${l.chatMiscVideo}, ${formatMediaDuration(g.durationMs)}' : l.chatMiscPhoto;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: BuPressable(
        onTap: widget.onTap,
        scale: .96,
        pressedOpacity: .85,
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
          if (g.isVideo)
            PositionedDirectional(
              start: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: t.scrim.withValues(alpha: .65), borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(BuIcons.play, size: 10, color: t.onMedia),
                  const SizedBox(width: 2),
                  Text(formatMediaDuration(g.durationMs), style: tx.labelSmall!.copyWith(color: t.onMedia, fontWeight: FontWeight.w400, height: 1.2)),
                ]),
              ),
            ),
          if (widget.busy) ColoredBox(color: t.scrim.withValues(alpha: .35)),
        ]),
      ),
    );
  }
}

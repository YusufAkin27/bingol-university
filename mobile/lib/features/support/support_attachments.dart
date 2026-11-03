import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/api.dart';
import '../../core/cache/image_disk_cache.dart';
import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart';
import '../../core/platform/video_service.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../chat/chat_media.dart';
import '../chat/chat_media_viewer.dart';
import '../chat/message_bubble.dart' show DurationPill, PlayBadge;

/// Destek talebi ekleri (Sözleşme B): sunucu sınırlarının istemci aynası. Sunucu yine doğrular; burada amaç,
/// kullanıcıya yüklemeden ÖNCE açıklayıcı hata vermek.
const kSupportMaxAttachments = 4;
const kSupportMaxVideos = 1;
const kSupportImageMaxBytes = 8 * 1024 * 1024;
const kSupportVideoMaxBytes = 50 * 1024 * 1024;
const kSupportVideoMaxMs = 60 * 1000;

/// Sunucudaki `AttachmentView`.
class SupportAttachment {
  const SupportAttachment({
    required this.id,
    required this.kind,
    required this.url,
    this.thumbUrl,
    this.mime,
    this.bytes,
    this.name,
    this.width,
    this.height,
    this.durationMs,
  });

  final int id;

  /// `IMAGE` | `VIDEO`.
  final String kind;
  final String url;
  final String? thumbUrl;
  final String? mime;
  final int? bytes;
  final String? name;
  final int? width;
  final int? height;
  final int? durationMs;

  bool get isVideo => kind.toUpperCase() == 'VIDEO';

  factory SupportAttachment.fromJson(Map<dynamic, dynamic> j) => SupportAttachment(
        id: (j['id'] as num).toInt(),
        kind: '${j['kind'] ?? 'IMAGE'}',
        url: '${j['url'] ?? ''}',
        thumbUrl: j['thumbUrl'] as String?,
        mime: j['mime'] as String?,
        bytes: (j['bytes'] as num?)?.toInt(),
        name: j['name'] as String?,
        width: (j['width'] as num?)?.toInt(),
        height: (j['height'] as num?)?.toInt(),
        durationMs: (j['durationMs'] as num?)?.toInt(),
      );

  /// Mesaj gövdesindeki `attachments` listesinden (bozuk öğeler atlanır).
  static List<SupportAttachment> listFrom(Object? raw) {
    if (raw is! List) return const [];
    final out = <SupportAttachment>[];
    for (final e in raw) {
      if (e is! Map || e['id'] is! num) continue;
      final a = SupportAttachment.fromJson(e);
      if (a.url.isNotEmpty || (a.thumbUrl ?? '').isNotEmpty) out.add(a);
    }
    return out;
  }
}

/// İstemci tarafı ön denetim / hazırlık hataları.
enum SupportAttachError { limit, oneVideo, type, imageSize, videoSize, videoLong, failed }

/// Hata için kullanıcı metni (sunucu hataları kendi yerelleştirilmiş mesajını taşır).
String supportAttachErrorText(BuildContext context, Object e) {
  final l = context.l10n;
  if (e is SupportAttachError) {
    return switch (e) {
      SupportAttachError.limit => l.supAttErrLimit('$kSupportMaxAttachments'),
      SupportAttachError.oneVideo => l.supAttErrOneVideo,
      SupportAttachError.type => l.supAttErrType,
      SupportAttachError.imageSize => l.supAttErrImageSize('${kSupportImageMaxBytes ~/ (1024 * 1024)}'),
      SupportAttachError.videoSize => l.supAttErrVideoSize('${kSupportVideoMaxBytes ~/ (1024 * 1024)}'),
      SupportAttachError.videoLong => l.supAttErrVideoLong('${kSupportVideoMaxMs ~/ 1000}'),
      SupportAttachError.failed => l.supAttErrFailed,
    };
  }
  return errorText(e);
}

/// Yükleme katmanı (testlerde sahtesi verilir).
abstract class SupportAttachmentUploader {
  Future<SupportAttachment> uploadImage(PreparedImage image);
  Future<SupportAttachment> uploadVideo(PreparedVideo video, void Function(double progress) onProgress);
}

/// Üretim yükleyicisi: `POST /api/support/attachments` (multipart `file`).
class SessionAttachmentUploader implements SupportAttachmentUploader {
  SessionAttachmentUploader(this.session, {http.Client? client}) : _client = client;

  final Session session;
  final http.Client? _client;

  static const _path = '/support/attachments';

  SupportAttachment _parse(dynamic json) {
    if (json is Map && json['id'] is num) return SupportAttachment.fromJson(json);
    throw ApiError(500, 'ATTACHMENT_BAD_RESPONSE', '');
  }

  @override
  Future<SupportAttachment> uploadImage(PreparedImage image) async =>
      _parse(await MultipartUploader(session, client: _client).upload(_path, image));

  @override
  Future<SupportAttachment> uploadVideo(PreparedVideo video, void Function(double progress) onProgress) async {
    // Poster yerelde önizleme içindir; sunucu küçük resmi kendisi üretir.
    final bare = PreparedVideo(
      path: video.path,
      bytes: video.bytes,
      sizeBytes: video.sizeBytes,
      durationMs: video.durationMs,
      width: video.width,
      height: video.height,
    );
    return _parse(await VideoUploader(session, client: _client).upload(_path, bare, onProgress: onProgress));
  }
}

enum SupportDraftState { preparing, uploading, ready, failed }

/// Seçilmiş, yüklenmekte olan ya da yüklenmiş tek ek.
class SupportDraft {
  SupportDraft({required this.key, required this.isVideo, this.preview, this.durationMs = 0});

  final int key;
  final bool isVideo;
  Uint8List? preview;
  int durationMs;
  SupportDraftState state = SupportDraftState.uploading;

  /// 0..1; null: belirsiz.
  double? progress;
  SupportAttachment? uploaded;

  /// [SupportAttachError] ya da sunucudan gelen [ApiError].
  Object? error;
  bool removed = false;
  VideoCancel? _cancel;
  Future<void> Function()? _retry;

  bool get busy => state == SupportDraftState.preparing || state == SupportDraftState.uploading;
}

/// Taslak ek listesi: seçim, istemci denetimi, yükleme ve yeniden deneme. Ekran yalnız dinler.
class SupportAttachmentsController extends ChangeNotifier {
  SupportAttachmentsController({
    required this.uploader,
    ImageService? images,
    VideoService? videos,
    this.maxAttachments = kSupportMaxAttachments,
  })  : _images = images ?? ImageService(),
        _videos = videos ?? VideoService();

  final SupportAttachmentUploader uploader;
  final int maxAttachments;
  final ImageService _images;
  final VideoService _videos;

  final List<SupportDraft> items = [];
  int _seq = 0;
  bool _disposed = false;

  bool get isEmpty => items.isEmpty;
  bool get hasVideo => items.any((d) => d.isVideo);
  bool get hasPending => items.any((d) => d.busy);
  bool get hasFailed => items.any((d) => d.state == SupportDraftState.failed);
  bool get canAddMore => items.length < maxAttachments;

  /// Gönderilecek ek kimlikleri (yalnız yüklenmiş olanlar).
  List<int> get ids => [
        for (final d in items)
          if (d.state == SupportDraftState.ready && d.uploaded != null) d.uploaded!.id,
      ];

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final d in items) {
      d.removed = true;
      unawaited(d._cancel?.cancel());
    }
    super.dispose();
  }

  /// Seçimden ÖNCE sayı sınırı denetimi (gereksiz seçici açılmasın).
  SupportAttachError? precheck({required bool video}) {
    if (items.length >= maxAttachments) return SupportAttachError.limit;
    if (video && hasVideo) return SupportAttachError.oneVideo;
    return null;
  }

  Future<SupportAttachError?> pickPhoto(ImageSource source) async {
    final pre = precheck(video: false);
    if (pre != null) return pre;
    try {
      final f = await _images.pick(source);
      if (f == null) return null;
      return await addImage(await f.readAsBytes());
    } catch (_) {
      return SupportAttachError.failed;
    }
  }

  Future<SupportAttachError?> pickVideo(ImageSource source) async {
    final pre = precheck(video: true);
    if (pre != null) return pre;
    try {
      final p = await _videos.pick(source);
      if (p == null) return null;
      return await addVideo(p);
    } catch (_) {
      return SupportAttachError.failed;
    }
  }

  /// Görsel baytlarını doğrular (tür: gerçek içerik imzası, boyut ≤ 8 MB) ve yükler.
  Future<SupportAttachError?> addImage(Uint8List bytes) async {
    final pre = precheck(video: false);
    if (pre != null) return pre;
    if (bytes.isEmpty) return SupportAttachError.type;
    final mime = ImageService.sniffMime(bytes);
    if (mime == null) return SupportAttachError.type;
    if (bytes.length > kSupportImageMaxBytes) return SupportAttachError.imageSize;
    final d = SupportDraft(key: _seq++, isVideo: false, preview: bytes);
    items.add(d);
    final prepared = PreparedImage(bytes, mime);
    d._retry = () => _uploadImage(d, prepared);
    notifyListeners();
    await d._retry!();
    return null;
  }

  /// Videoyu doğrular (süre ≤ 60 sn, boyut ≤ 50 MB), gerekirse sıkıştırır ve yükler.
  Future<SupportAttachError?> addVideo(PickedVideo picked) async {
    final pre = precheck(video: true);
    if (pre != null) return pre;
    final d = SupportDraft(key: _seq++, isVideo: true)
      ..state = SupportDraftState.preparing
      ..progress = null
      .._cancel = VideoCancel();
    items.add(d);
    notifyListeners();
    PreparedVideo prepared;
    try {
      prepared = await _videos.prepare(
        picked,
        maxBytes: kSupportVideoMaxBytes,
        cancel: d._cancel,
        onProgress: (p) {
          if (d.removed) return;
          d.progress = p;
          notifyListeners();
        },
      );
    } on VideoException catch (e) {
      items.remove(d);
      notifyListeners();
      return switch (e.code) {
        'TOO_LONG' => SupportAttachError.videoLong,
        'TOO_LARGE' => SupportAttachError.videoSize,
        'UNSUPPORTED' => SupportAttachError.type,
        'CANCELLED' => null,
        _ => SupportAttachError.failed,
      };
    } catch (_) {
      items.remove(d);
      notifyListeners();
      return SupportAttachError.failed;
    }
    if (d.removed) return null;
    d.preview = prepared.poster;
    d.durationMs = prepared.durationMs;
    d._retry = () => _uploadVideo(d, prepared);
    await d._retry!();
    return null;
  }

  Future<void> _uploadImage(SupportDraft d, PreparedImage img) async {
    d
      ..state = SupportDraftState.uploading
      ..progress = null
      ..error = null;
    notifyListeners();
    try {
      final a = await uploader.uploadImage(img);
      if (d.removed) return;
      d
        ..uploaded = a
        ..state = SupportDraftState.ready
        ..progress = 1;
    } catch (e) {
      if (d.removed) return;
      d
        ..state = SupportDraftState.failed
        ..error = e is ApiError ? e : SupportAttachError.failed;
    }
    notifyListeners();
  }

  Future<void> _uploadVideo(SupportDraft d, PreparedVideo v) async {
    d
      ..state = SupportDraftState.uploading
      ..progress = 0
      ..error = null;
    notifyListeners();
    try {
      final a = await uploader.uploadVideo(v, (p) {
        if (d.removed) return;
        d.progress = p;
        notifyListeners();
      });
      if (d.removed) return;
      d
        ..uploaded = a
        ..state = SupportDraftState.ready
        ..progress = 1;
    } catch (e) {
      if (d.removed) return;
      d
        ..state = SupportDraftState.failed
        ..error = e is ApiError ? e : SupportAttachError.failed;
    }
    notifyListeners();
  }

  /// Başarısız eki yeniden yükler.
  Future<void> retry(SupportDraft d) async {
    if (d.state != SupportDraftState.failed) return;
    await d._retry?.call();
  }

  void remove(SupportDraft d) {
    if (!items.remove(d)) return;
    d.removed = true;
    unawaited(d._cancel?.cancel());
    notifyListeners();
  }

  /// Gönderim başarılı olunca taslakları bırakır (sunucuda artık mesaja bağlıdırlar).
  void clear() {
    for (final d in items) {
      d.removed = true;
    }
    items.clear();
    notifyListeners();
  }
}

/// Ek kaynağı (alt sayfa seçimi).
enum SupportAttachSource { photoGallery, photoCamera, videoGallery, videoCamera }

/// "Ek ekle" alt sayfası: fotoğraf (galeri/kamera) ve video (galeri/kamera). Sınır özeti altta.
Future<SupportAttachSource?> showSupportAttachSheet(BuildContext context, {bool videoAllowed = true}) {
  final l = context.l10n;
  return BuSheet.show<SupportAttachSource>(
    context,
    title: l.supAttSheetTitle,
    subtitle: l.supAttLimits,
    builder: (ctx) {
      final t = ctx.bu;
      final tx = Theme.of(ctx).textTheme;
      Widget row(Key key, IconData icon, String label, SupportAttachSource v, {bool enabled = true}) => Semantics(
            button: true,
            enabled: enabled,
            label: label,
            excludeSemantics: true,
            onTap: enabled ? () => Navigator.pop(ctx, v) : null,
            child: InkWell(
              key: key,
              borderRadius: BorderRadius.circular(BuRadius.md),
              onTap: enabled ? () => Navigator.pop(ctx, v) : null,
              child: Opacity(
                opacity: enabled ? 1 : .45,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 60),
                  child: Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.sm)),
                      child: Icon(icon, size: 22, color: t.ink),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text(label, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700))),
                    Icon(BuIcons.chevronRight, size: 18, color: t.mut),
                  ]),
                ),
              ),
            ),
          );
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        row(const ValueKey('supAttPhotoGallery'), BuIcons.images, l.supAttPhotoGallery, SupportAttachSource.photoGallery),
        Divider(height: 1, color: t.bd),
        row(const ValueKey('supAttPhotoCamera'), BuIcons.camera, l.supAttPhotoCamera, SupportAttachSource.photoCamera),
        Divider(height: 1, color: t.bd),
        row(const ValueKey('supAttVideoGallery'), BuIcons.video, l.supAttVideoGallery, SupportAttachSource.videoGallery, enabled: videoAllowed),
        Divider(height: 1, color: t.bd),
        row(const ValueKey('supAttVideoCamera'), BuIcons.clapperboard, l.supAttVideoCamera, SupportAttachSource.videoCamera, enabled: videoAllowed),
      ]);
    },
  );
}

/// Kaynak seç + ekle akışı; hata metnini [onError]'a verir. Hem form hem yanıt alanı kullanır.
Future<void> runSupportAttachFlow(
  BuildContext context,
  SupportAttachmentsController c, {
  required void Function(String message) onError,
}) async {
  final pre = c.precheck(video: false);
  if (pre != null) {
    onError(supportAttachErrorText(context, pre));
    return;
  }
  final src = await showSupportAttachSheet(context, videoAllowed: !c.hasVideo);
  if (src == null || !context.mounted) return;
  buHaptic(BuHaptic.selection);
  final err = switch (src) {
    SupportAttachSource.photoGallery => await c.pickPhoto(ImageSource.gallery),
    SupportAttachSource.photoCamera => await c.pickPhoto(ImageSource.camera),
    SupportAttachSource.videoGallery => await c.pickVideo(ImageSource.gallery),
    SupportAttachSource.videoCamera => await c.pickVideo(ImageSource.camera),
  };
  if (err != null && context.mounted) onError(supportAttachErrorText(context, err));
}

/// Taslak ek şeridi: kare önizlemeler (yükleniyor halkası, hata + yeniden dene, kaldır). [addTile] true ise
/// sonda kesik çizgili "Ek ekle" karosu (yalnız yer varken). Wrap: dar ekranda alt satıra iner, gizli kayma yok.
class SupportAttachmentStrip extends StatelessWidget {
  const SupportAttachmentStrip({super.key, required this.controller, this.onAdd});

  final SupportAttachmentsController controller;

  /// Verilirse sonda "Ek ekle" karosu görünür.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final items = controller.items;
        if (items.isEmpty && onAdd == null) return const SizedBox.shrink();
        return Wrap(spacing: 4, runSpacing: 2, children: [
          for (final d in items)
            SupportAttachTile(
              key: ValueKey('supDraft${d.key}'),
              draft: d,
              onRemove: () {
                buHaptic(BuHaptic.light);
                controller.remove(d);
              },
              onRetry: () => controller.retry(d),
            ),
          if (onAdd != null && controller.canAddMore) SupportAddTile(onTap: onAdd!),
        ]);
      },
    );
  }
}

const double _kTile = 72;
const double _kTileBox = 80;

/// Kesik çizgili "Ek ekle" karosu (80 dp kutu, 72 dp görünür; en az 48 dp dokunma).
class SupportAddTile extends StatelessWidget {
  const SupportAddTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final label = context.l10n.supAttAdd;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox(
        width: _kTileBox,
        height: _kTileBox,
        child: Align(
          alignment: AlignmentDirectional.bottomStart,
          child: BuPressable(
            scale: .96,
            child: Material(
              color: t.sf2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: t.bdStrong)),
              child: InkWell(
                key: const ValueKey('supAddAttachment'),
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: SizedBox(
                  width: _kTile,
                  height: _kTile,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(BuIcons.imagePlus, size: 22, color: t.onSoft),
                    const SizedBox(height: 4),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelSmall!.copyWith(color: t.onSoft, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tek taslak ek karosu.
class SupportAttachTile extends StatelessWidget {
  const SupportAttachTile({super.key, required this.draft, required this.onRemove, required this.onRetry});

  final SupportDraft draft;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final d = draft;
    final failed = d.state == SupportDraftState.failed;
    final status = switch (d.state) {
      SupportDraftState.preparing => l.supAttPreparing,
      SupportDraftState.uploading => l.supAttUploading,
      SupportDraftState.ready => l.supAttReady,
      SupportDraftState.failed => l.supAttFailed,
    };
    final kind = d.isVideo ? l.supAttVideo : l.supAttPhoto;
    final preview = d.preview;
    final tile = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: _kTile,
        height: _kTile,
        child: Stack(fit: StackFit.expand, children: [
          ColoredBox(color: t.sf2),
          if (preview != null && preview.isNotEmpty)
            Image.memory(preview, fit: BoxFit.cover, cacheWidth: 220, gaplessPlayback: true, errorBuilder: (_, __, ___) => const SizedBox.shrink())
          else
            Center(child: Icon(d.isVideo ? BuIcons.video : BuIcons.image, size: 26, color: t.mut)),
          if (d.isVideo && d.durationMs > 0 && !d.busy && !failed)
            PositionedDirectional(bottom: 4, start: 4, child: DurationPill(ms: d.durationMs)),
          if (d.busy)
            ColoredBox(
              color: t.scrim.withValues(alpha: .5),
              child: Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    value: d.state == SupportDraftState.uploading ? d.progress : (d.isVideo ? d.progress : null),
                    color: t.onMedia,
                    backgroundColor: t.onMedia.withValues(alpha: .25),
                  ),
                ),
              ),
            ),
          if (failed)
            Material(
              color: t.danger.withValues(alpha: .78),
              child: InkWell(
                key: ValueKey('supRetry${d.key}'),
                onTap: onRetry,
                child: Center(child: Icon(BuIcons.refreshCw, size: 24, color: t.onMedia)),
              ),
            ),
        ]),
      ),
    );
    return Semantics(
      container: true,
      label: '$kind, $status',
      child: SizedBox(
        width: _kTileBox,
        height: _kTileBox,
        child: Stack(children: [
          PositionedDirectional(bottom: 0, start: 0, child: ExcludeSemantics(child: tile)),
          // 24 dp görünür, 44 dp dokunma alanı: karonun köşesinden taşar.
          PositionedDirectional(
            top: 0,
            end: 0,
            child: Semantics(
              button: true,
              label: l.supAttRemove,
              excludeSemantics: true,
              onTap: onRemove,
              child: GestureDetector(
                key: ValueKey('supRemove${d.key}'),
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(color: t.ink, shape: BoxShape.circle, border: Border.all(color: t.bg, width: 2)),
                      child: Icon(BuIcons.x, size: 13, color: t.bg),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Oturumun yetkili görsel başlıkları (ekler yalnız talep sahibine ve yöneticiye açıktır).
Map<String, String> supportAuthHeaders(Session s) {
  final tok = s.api.tokens?.access;
  return tok == null ? const {} : {'Authorization': 'Bearer $tok'};
}

/// Mesaj balonundaki ek ızgarası: 1 ek geniş, 2+ ek iki sütun (en çok 4). Dokununca [onOpen](indeks).
class SupportAttachmentGallery extends StatelessWidget {
  const SupportAttachmentGallery({super.key, required this.attachments, required this.headers, required this.maxWidth, required this.onOpen});

  final List<SupportAttachment> attachments;
  final Map<String, String> headers;
  final double maxWidth;
  final void Function(int index) onOpen;

  @override
  Widget build(BuildContext context) {
    final n = attachments.length;
    if (n == 0) return const SizedBox.shrink();
    const gap = 4.0;
    if (n == 1) {
      final a = attachments.first;
      final w = a.width ?? 0;
      final h = a.height ?? 0;
      // Dikey görsel kare sınırına kadar uzar, yatay görsel 4:3'ten yassılaşmaz.
      final ratio = (w > 0 && h > 0) ? (w / h).clamp(.8, 1.6) : 4 / 3;
      final width = maxWidth;
      return SupportAttachmentThumb(attachment: a, headers: headers, width: width, height: width / ratio, index: 0, total: 1, onTap: () => onOpen(0));
    }
    final side = (maxWidth - gap) / 2;
    return Wrap(spacing: gap, runSpacing: gap, children: [
      for (var i = 0; i < n; i++)
        SupportAttachmentThumb(attachment: attachments[i], headers: headers, width: side, height: side, index: i, total: n, onTap: () => onOpen(i)),
    ]);
  }
}

/// Mesajdaki tek ek küçük resmi: görsel ya da video posteri (oynat işareti + süre).
class SupportAttachmentThumb extends StatelessWidget {
  const SupportAttachmentThumb({
    super.key,
    required this.attachment,
    required this.headers,
    required this.width,
    required this.height,
    required this.index,
    required this.total,
    required this.onTap,
  });

  final SupportAttachment attachment;
  final Map<String, String> headers;
  final double width;
  final double height;
  final int index;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final a = attachment;
    final src = a.isVideo ? a.thumbUrl : (a.thumbUrl ?? a.url);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final label = a.isVideo ? l.supAttOpenVideo('${index + 1}', '$total') : l.supAttOpenPhoto('${index + 1}', '$total');
    Widget placeholder(IconData icon) => ColoredBox(color: t.sf2, child: Center(child: Icon(icon, size: 28, color: t.mut)));
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: GestureDetector(
            key: ValueKey('supAtt${a.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Stack(fit: StackFit.expand, children: [
              placeholder(a.isVideo ? BuIcons.video : BuIcons.image),
              if (src != null && src.isNotEmpty)
                Image(
                  image: persistentNetworkImage(chatMediaUrl(src), headers: headers, cacheWidth: (width * dpr).ceil().clamp(160, 1200)),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  frameBuilder: (c, child, frame, sync) => sync
                      ? child
                      : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: BuMotion.of(c, BuMotion.medium), curve: BuMotion.decelerate, child: child),
                  errorBuilder: (c, e, s) => placeholder(BuIcons.imageOff),
                ),
              if (a.isVideo) ...[
                ColoredBox(color: t.scrim.withValues(alpha: .18)),
                const Center(child: PlayBadge(size: 40)),
                if (a.durationMs != null) PositionedDirectional(bottom: 6, start: 6, child: DurationPill(ms: a.durationMs!)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Mesaj eklerini tam ekran görüntüleyicide açar (sohbetin görüntüleyicisi yeniden kullanılır).
void openSupportAttachments(BuildContext context, Session session, List<SupportAttachment> list, int index) {
  final items = <ChatMediaItem>[];
  var start = 0;
  for (var i = 0; i < list.length; i++) {
    final a = list[i];
    final it = ChatMediaItem.tryFromAttachment({'id': a.id, 'kind': a.kind, 'url': a.url, 'thumbUrl': a.thumbUrl, 'durationMs': a.durationMs});
    if (it == null) continue;
    if (i == index) start = items.length;
    items.add(it);
  }
  if (items.isEmpty) return;
  Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => ChatMediaViewer(items: items, headers: supportAuthHeaders(session), initialIndex: start)),
  );
}

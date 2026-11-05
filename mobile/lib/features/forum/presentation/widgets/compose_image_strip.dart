import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../widgets/bu.dart';
import '../../data/forum_draft_store.dart';
import '../../data/forum_models.dart';

enum ComposeImageState { uploading, done, failed }

/// Formdaki bir görsel: yerel bayt (yükleme/önizleme) ya da taslaktan gelen kayıtlı medya.
/// Konu ANCAK tüm görseller [ComposeImageState.done] iken yayınlanır.
class ComposeImage {
  ComposeImage.local(this.bytes)
      : state = ComposeImageState.uploading,
        media = null,
        restored = null;

  ComposeImage.restored(DraftImage d)
      : bytes = null,
        media = null,
        restored = d,
        state = ComposeImageState.done;

  final Key key = UniqueKey();
  final Uint8List? bytes;
  final DraftImage? restored;
  ForumImage? media;
  ComposeImageState state;
  String? error;

  int? get mediaId => media?.id ?? restored?.id;

  /// Taslağa yazılacak kayıt (yalnız yüklenmiş görsel).
  DraftImage? get draft {
    if (state != ComposeImageState.done) return null;
    final m = media;
    if (m != null) return DraftImage(id: m.id, url: m.url, thumbUrl: m.thumbUrl, width: m.width, height: m.height);
    return restored;
  }

  String? get previewUrl => media?.thumbUrl ?? media?.url ?? restored?.thumbUrl ?? restored?.url;
}

/// Görsel kareleri + "ekle" karesi + sayaç. Yüklenen kare yükleme göstergesi, hatalı kare yeniden dene düğmesi gösterir.
class ComposeImageStrip extends StatelessWidget {
  const ComposeImageStrip({
    super.key,
    required this.images,
    required this.max,
    required this.onAdd,
    required this.onRemove,
    required this.onRetry,
    required this.authHeaders,
    this.enabled = true,
  });

  final List<ComposeImage> images;
  final int max;
  final VoidCallback onAdd;
  final ValueChanged<ComposeImage> onRemove;
  final ValueChanged<ComposeImage> onRetry;
  final Map<String, String> authHeaders;
  final bool enabled;

  static const double tile = 88;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final im in images)
          _Tile(
            key: ValueKey('forumImage${images.indexOf(im)}'),
            image: im,
            headers: authHeaders,
            enabled: enabled,
            onRemove: () => onRemove(im),
            onRetry: () => onRetry(im),
          ),
        if (images.length < max)
          Semantics(
            button: true,
            label: l.forumComposeAddImage,
            excludeSemantics: true,
            child: BuPressable(
              enabled: enabled,
              onTap: enabled ? onAdd : null,
              child: Container(
                key: const ValueKey('forumImageAdd'),
                width: tile,
                height: tile,
                decoration: BoxDecoration(
                  color: t.sf2,
                  borderRadius: BorderRadius.circular(BuRadius.sm),
                  border: Border.all(color: t.bd),
                ),
                child: Icon(BuIcons.imagePlus, size: 26, color: t.mut),
              ),
            ),
          ),
      ]),
      if (images.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(l.forumComposeImageCount(images.length, max),
              style: tt.bodySmall?.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
        ),
    ]);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.image, required this.headers, required this.enabled, required this.onRemove, required this.onRetry});

  final ComposeImage image;
  final Map<String, String> headers;
  final bool enabled;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final r = BorderRadius.circular(BuRadius.sm);
    final failed = image.state == ComposeImageState.failed;
    final busy = image.state == ComposeImageState.uploading;
    final Widget pic = image.bytes != null
        ? Image.memory(image.bytes!, fit: BoxFit.cover, cacheWidth: 264, gaplessPlayback: true, errorBuilder: (_, __, ___) => ColoredBox(color: t.sf2))
        : BuImage(image.previewUrl, headers: headers, width: ComposeImageStrip.tile, height: ComposeImageStrip.tile, maxDecodeWidth: 264);
    return SizedBox(
      width: ComposeImageStrip.tile,
      height: ComposeImageStrip.tile,
      child: Stack(children: [
        Positioned.fill(child: ClipRRect(borderRadius: r, child: pic)),
        if (busy)
          Positioned.fill(
            child: Semantics(
              label: l.forumComposeImageUploading,
              child: DecoratedBox(
                decoration: BoxDecoration(color: t.scrim.withValues(alpha: .35), borderRadius: r),
                child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: t.onMedia))),
              ),
            ),
          ),
        if (failed)
          Positioned.fill(
            child: Semantics(
              button: true,
              label: '${image.error ?? ''} ${l.forumComposeImageRetry}'.trim(),
              excludeSemantics: true,
              child: InkWell(
                key: const ValueKey('forumImageRetry'),
                borderRadius: r,
                onTap: enabled ? onRetry : null,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: t.scrim.withValues(alpha: .55), borderRadius: r, border: Border.all(color: t.danger, width: 1.5)),
                  child: Center(child: Icon(BuIcons.refreshCw, size: 24, color: t.onMedia)),
                ),
              ),
            ),
          ),
        // Kaldır: görünür 22 dp, dokunma alanı 44 dp (karenin sağ üst köşesi).
        PositionedDirectional(
          top: 0,
          end: 0,
          child: Semantics(
            button: true,
            label: l.forumComposeImageRemove,
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('forumImageRemove'),
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? onRemove : null,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Align(
                  alignment: AlignmentDirectional.topEnd,
                  child: Container(
                    margin: const EdgeInsetsDirectional.only(top: 4, end: 4),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(color: t.ink, shape: BoxShape.circle, border: Border.all(color: t.bg, width: 1.5)),
                    child: Icon(BuIcons.x, size: 13, color: t.bg),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

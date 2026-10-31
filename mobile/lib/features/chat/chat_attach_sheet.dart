import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/permissions/ensure_permission.dart';
import '../../widgets/bu.dart';
import 'media_library.dart';
import 'media_pick.dart';
import 'media_picker_page.dart' show EnsureAccess;
import 'sohbety_sheet.dart';

/// "+" menüsünün sonucu: galeri, kamera ya da şeritten seçilen tek fotoğraf.
sealed class ChatAttachResult {
  const ChatAttachResult();
}

class ChatAttachGallery extends ChatAttachResult {
  const ChatAttachGallery();
}

class ChatAttachCamera extends ChatAttachResult {
  const ChatAttachCamera();
}

class ChatAttachRecent extends ChatAttachResult {
  const ChatAttachRecent(this.pick);
  final MediaPick pick;
}

/// "+" menüsü (tek yüzey ailesi: sohbet alt sayfası): üstte Galeri ve Kamera karoları, altında son fotoğraflar şeridi
/// (yatay kaydırmalı, sonda "Tümü"). Galeri izni yoksa şerit yerine tek satır "Fotoğraflara erişime izin ver".
/// İzin YALNIZ bu satıra dokunulunca istenir (menü açılırken sistem izin penceresi çıkmaz).
Future<ChatAttachResult?> showChatAttachSheet(BuildContext context, {required MediaLibrary library, EnsureAccess? ensureAccess}) {
  return showSohbetySheet<ChatAttachResult>(context, (c) => ChatAttachSheet(library: library, ensureAccess: ensureAccess));
}

class ChatAttachSheet extends StatefulWidget {
  const ChatAttachSheet({super.key, required this.library, this.ensureAccess, this.stripCount = 10});

  final MediaLibrary library;
  final EnsureAccess? ensureAccess;

  /// Şeritteki en çok fotoğraf sayısı (8-12 arası).
  final int stripCount;

  @override
  State<ChatAttachSheet> createState() => _ChatAttachSheetState();
}

class _ChatAttachSheetState extends State<ChatAttachSheet> {
  List<GalleryItem>? _recent;
  bool _loading = true;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    _loadStrip(ask: false);
  }

  /// [ask] false: yalnız mevcut izne bakar (istemez); true: izin akışını çalıştırır.
  Future<void> _loadStrip({required bool ask}) async {
    try {
      var access = await widget.library.currentAccess();
      if (ask && (access == null || access == LibraryAccess.denied)) {
        if (!mounted) return;
        final ensure = widget.ensureAccess ?? ensurePermission;
        final ok = await ensure(context, AppPermission.photos, rationale: context.l10n.chatMiscGalleryRationale);
        if (!mounted) return;
        access = ok ? await widget.library.requestAccess() : LibraryAccess.denied;
      }
      if (access == LibraryAccess.full || access == LibraryAccess.limited) {
        final items = await widget.library.items(null, page: 0, size: widget.stripCount * 2);
        if (!mounted) return;
        setState(() {
          _recent = items.where((g) => !g.isVideo).take(widget.stripCount).toList();
          _loading = false;
          _asking = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _recent = null;
        _loading = false;
        _asking = false;
      });
    }
  }

  MediaPick _pickOf(GalleryItem g) => MediaPick(
        key: g.id,
        isVideo: g.isVideo,
        durationMs: g.durationMs,
        thumb: (s) => widget.library.thumb(g, s),
        imageBytes: g.isVideo ? null : () => widget.library.imageBytes(g),
        videoPath: g.isVideo ? () => widget.library.videoPath(g) : null,
      );

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ExcludeSemantics(
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 16),
                decoration: BoxDecoration(color: t.bd, borderRadius: BuRadius.bPill),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(child: _Tile(key: const ValueKey('attachGallery'), icon: LucideIcons.images, label: l.chatMiscGallery, onTap: () => Navigator.pop(context, const ChatAttachGallery()))),
              const SizedBox(width: 12),
              Expanded(child: _Tile(key: const ValueKey('attachCamera'), icon: LucideIcons.camera, label: l.chatMiscCamera, onTap: () => Navigator.pop(context, const ChatAttachCamera()))),
            ]),
          ),
          const SizedBox(height: 16),
          _strip(context),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _strip(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final recent = _recent;
    if (_loading) {
      return const SizedBox(height: 84, child: ExcludeSemantics(child: Align(alignment: Alignment.center, child: SizedBox.shrink())));
    }
    if (recent == null) {
      // İzin yok / henüz verilmedi: tek satır.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Semantics(
          button: true,
          label: l.p67AttachAllowPhotos,
          excludeSemantics: true,
          child: BuPressable(
            key: const ValueKey('attachAllowPhotos'),
            onTap: _asking
                ? null
                : () {
                    setState(() => _asking = true);
                    _loadStrip(ask: true);
                  },
            haptic: BuHaptic.selection,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: BuSize.row),
              child: Row(children: [
                Icon(LucideIcons.image, size: 22, color: t.mut),
                const SizedBox(width: 12),
                Expanded(child: Text(l.p67AttachAllowPhotos, style: tx.bodyLarge!.copyWith(color: t.ink))),
                Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut),
              ]),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 84,
      child: ListView.separated(
        key: const ValueKey('attachStrip'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: recent.length + 1,
        separatorBuilder: (c, i) => const SizedBox(width: 8),
        itemBuilder: (c, i) {
          if (i == recent.length) {
            return Semantics(
              button: true,
              label: l.chatMiscAll,
              excludeSemantics: true,
              child: BuPressable(
                key: const ValueKey('attachAll'),
                onTap: () => Navigator.pop(context, const ChatAttachGallery()),
                haptic: BuHaptic.selection,
                child: Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bSm),
                  child: Text(l.chatMiscAll, maxLines: 1, style: tx.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
                ),
              ),
            );
          }
          final g = recent[i];
          return _Thumb(key: ValueKey('attachRecent_${g.id}'), item: g, library: widget.library, onTap: () => Navigator.pop(context, ChatAttachRecent(_pickOf(g))));
        },
      ),
    );
  }
}

/// Büyük yuvarlak köşeli karo: simge + kısa etiket (tek ton).
class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
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
        child: Container(
          height: 88,
          decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bLg),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 26, color: t.ink),
            const SizedBox(height: 8),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _Thumb extends StatefulWidget {
  const _Thumb({super.key, required this.item, required this.library, required this.onTap});

  final GalleryItem item;
  final MediaLibrary library;
  final VoidCallback onTap;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  late final Future<Uint8List?> _data = widget.library.thumb(widget.item, 200);

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: context.l10n.chatMiscPhoto,
      excludeSemantics: true,
      child: BuPressable(
        onTap: widget.onTap,
        haptic: BuHaptic.selection,
        child: ClipRRect(
          borderRadius: BuRadius.bSm,
          child: SizedBox(
            width: 84,
            height: 84,
            child: Stack(fit: StackFit.expand, children: [
              ColoredBox(color: t.sf2),
              FutureBuilder<Uint8List?>(
                future: _data,
                builder: (c, s) => s.data == null
                    ? const SizedBox.shrink()
                    : Image.memory(s.data!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        cacheWidth: 200,
                        frameBuilder: (c, child, frame, sync) => sync ? child : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: BuMotion.of(c, BuMotion.medium), child: child)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

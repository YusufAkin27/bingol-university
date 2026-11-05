import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/cache/image_disk_cache.dart';
import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'chat_media.dart';

/// Keeps the conversation visible behind a blurred, zoomable photo preview.
Future<void> showChatAvatarPreview(
  BuildContext context, {
  required String name,
  required String url,
  Map<String, String>? headers,
}) =>
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: context.bu.scrim.withValues(alpha: .32),
      transitionDuration: BuMotion.of(context, BuMotion.medium),
      pageBuilder: (context, _, __) =>
          _AvatarPreview(name: name, url: url, headers: headers),
      transitionBuilder: (context, animation, _, child) {
        final curve = animation.drive(CurveTween(curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
              scale: Tween<double>(begin: .94, end: 1).animate(curve),
              child: child),
        );
      },
    );

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.name, required this.url, this.headers});

  final String name;
  final String url;
  final Map<String, String>? headers;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return BackdropFilter(
      key: const ValueKey('chatAvatarPreview'),
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Material(
        type: MaterialType.transparency,
        child: Stack(fit: StackFit.expand, children: [
          GestureDetector(
            key: const ValueKey('chatAvatarPreviewBackdrop'),
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: () => Navigator.pop(context),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      context.l10n.avatarSheetTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall!
                          .copyWith(color: t.onMedia),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('chatAvatarPreviewClose'),
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    style: IconButton.styleFrom(
                        backgroundColor: t.scrim.withValues(alpha: .24)),
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(BuIcons.x, color: t.onMedia, size: 22),
                  ),
                ]),
                Expanded(
                  child: LayoutBuilder(builder: (context, constraints) {
                    final side = math
                        .min(
                            460.0,
                            math.min(constraints.maxWidth,
                                constraints.maxHeight - 24))
                        .clamp(0.0, 460.0);
                    return Center(
                      child: SizedBox.square(
                        dimension: side,
                        child: InteractiveViewer(
                          key: const ValueKey('chatAvatarPreviewZoom'),
                          minScale: 1,
                          maxScale: 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: ColoredBox(
                              color: t.sf,
                              child: Image(
                                image: persistentNetworkImage(chatMediaUrl(url),
                                    headers: headers, cacheWidth: 1200),
                                width: side,
                                height: side,
                                fit: BoxFit.contain,
                                semanticLabel: name,
                                errorBuilder: (_, __, ___) => Center(
                                    child: Icon(BuIcons.imageOff,
                                        size: 48, color: t.mut)),
                                loadingBuilder: (_, child, progress) =>
                                    progress == null
                                        ? child
                                        : const Center(
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        color: t.onMedia, fontWeight: FontWeight.w400),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

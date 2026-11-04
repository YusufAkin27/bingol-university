import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/cache/image_disk_cache.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'post_models.dart';

/// GEÇİCİ sarmalayıcı: avatara uzun basınca blur arka planlı büyük fotoğraf önizlemesi.
///
/// Ortak `ProfilePhotoViewer.show(context, imageUrl:, thumbUrl:, heroTag:)` (SR-MB, `lib/widgets/profile_photo_viewer.dart`)
/// birleşince gövde tek satırda ona bağlanır; çağıranlar bu işlevi kullanmaya devam eder. Avatar yoksa hiçbir şey açılmaz
/// (gizlilik: fotoğrafı olmayan/gizlenen avatar önizlenmez).
Future<void> showAvatarPreview(BuildContext context, Session session, {required String? url, String? name}) async {
  if (url == null || url.isEmpty) return;
  buHaptic(BuHaptic.light);
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.kesAvatarPreview,
    barrierColor: Colors.transparent,
    transitionDuration: BuMotion.of(context, const Duration(milliseconds: 240)),
    pageBuilder: (ctx, _, __) => _AvatarPreview(session: session, url: url),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: BuMotion.emphasizedDecelerate);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween<double>(begin: .86, end: 1).animate(curved), child: child),
      );
    },
  );
}

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.session, required this.url});

  final Session session;
  final String url;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final size = MediaQuery.sizeOf(context);
    final side = (size.shortestSide * .82).clamp(200.0, 420.0);
    return Stack(fit: StackFit.expand, children: [
      // Arka plan: Gaussian blur + yarı saydam koyu örtü; dokununca kapanır.
      Positioned.fill(
        child: GestureDetector(
          key: const ValueKey('avatarPreviewBackdrop'),
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: ColoredBox(color: t.scrim.withValues(alpha: .55)),
          ),
        ),
      ),
      Center(
        child: Semantics(
          image: true,
          label: context.l10n.kesAvatarPreview,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BuRadius.lg),
            child: SizedBox(
              width: side,
              height: side,
              child: ColoredBox(
                color: t.sf2,
                child: Image(
                  image: persistentNetworkImage(postMediaUrl(url), headers: postAuthHeaders(session), cacheWidth: 1080),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => Center(child: Icon(BuIcons.user, color: t.mut, size: 48)),
                ),
              ),
            ),
          ),
        ),
      ),
      PositionedDirectional(
        top: MediaQuery.paddingOf(context).top + 8,
        end: 8,
        child: IconButton(
          key: const ValueKey('avatarPreviewClose'),
          tooltip: context.l10n.postComposeClose,
          constraints: const BoxConstraints(minWidth: BuSize.touch, minHeight: BuSize.touch),
          icon: Icon(BuIcons.x, color: t.onMedia, size: 26),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    ]);
  }
}

/// Avatar/ad üzerinde: dokunma = [onTap] (ör. profil), UZUN BASMA = blur önizleme ([url] varsa).
class AvatarPreviewTap extends StatelessWidget {
  const AvatarPreviewTap({super.key, required this.session, required this.url, required this.onTap, required this.child, this.name});

  final Session session;
  final String? url;
  final String? name;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: url == null || url!.isEmpty ? null : () => showAvatarPreview(context, session, url: url, name: name),
        child: child,
      );
}

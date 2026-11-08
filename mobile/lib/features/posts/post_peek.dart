import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/icons/bu_icons.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../chat/emoji_presentation.dart';
import 'post_card.dart';
import 'post_carousel.dart';
import 'post_models.dart';
import 'post_video.dart';

/// Gönderi/Reels ızgarasında uzun basınca açılan ön izleme (Instagram "peek"): bulanık zemin üstünde yuvarlak köşeli
/// kart, video otomatik (sessiz, döngülü) oynar, fotoğraf büyük görünür. Kartın dışına dokununca ya da aşağı kaydırınca
/// kapanır. [onOpen]: gönderiyi tam sayfada açar; [onMenu]: gönderi menüsü (⋯, yetkiliyse). Kart tek yönetilen modal'dır.
Future<void> showPostPeek(
  BuildContext context, {
  required Session session,
  required Post post,
  ValueChanged<Post>? onOpen,
  ValueChanged<Post>? onMenu,
}) {
  HapticFeedback.mediumImpact();
  final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: reduce ? Duration.zero : const Duration(milliseconds: 220),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return AnimatedBuilder(
        animation: curved,
        builder: (_, __) => Stack(children: [
          Positioned.fill(
            child: IgnorePointer(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14 * curved.value, sigmaY: 14 * curved.value),
                child: ColoredBox(color: Colors.black.withValues(alpha: .46 * curved.value)),
              ),
            ),
          ),
          Center(
            child: Opacity(
              opacity: curved.value.clamp(0.0, 1.0),
              child: Transform.scale(scale: .88 + .12 * curved.value, child: child),
            ),
          ),
        ]),
      );
    },
    pageBuilder: (ctx, _, __) => _PostPeekCard(
      key: const ValueKey('postPeek'),
      session: session,
      post: post,
      onOpen: onOpen == null
          ? null
          : (p) {
              Navigator.of(ctx).pop();
              onOpen(p);
            },
      onMenu: onMenu == null
          ? null
          : (p) {
              Navigator.of(ctx).pop();
              onMenu(p);
            },
    ),
  );
}

class _PostPeekCard extends StatelessWidget {
  const _PostPeekCard({super.key, required this.session, required this.post, this.onOpen, this.onMenu});

  final Session session;
  final Post post;
  final ValueChanged<Post>? onOpen;
  final ValueChanged<Post>? onMenu;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final p = post;
    final size = MediaQuery.sizeOf(context);
    final width = (size.width - 40).clamp(240.0, 440.0);
    // Medya oranı: dikey video/foto 4:5, en fazla ekranın %52'si yükseklik.
    final ratio = p.isVideo ? 9 / 14 : 4 / 5;
    final mediaH = (width / ratio).clamp(180.0, size.height * .52);
    final text = (p.text ?? '').trim();
    final name = p.author.displayName;
    return SafeArea(
      child: Center(
        child: Dismissible(
          key: ValueKey('peek-${p.id}'),
          direction: DismissDirection.down,
          onDismissed: (_) => Navigator.of(context).maybePop(),
          child: Material(
            color: t.sf,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: t.bd)),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: width,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 6, 10),
                  child: Row(children: [
                    BuAvatar(name: name, url: p.author.avatarUrl, size: 32, headers: postAuthHeaders(session)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(color: t.ink, fontWeight: BuType.emphasisWeight)),
                    ),
                    if (onMenu != null)
                      IconButton(
                        key: const ValueKey('peekMenu'),
                        tooltip: l.postComposeMore,
                        onPressed: () => onMenu!(p),
                        icon: Icon(BuIcons.ellipsis, color: t.ink),
                      ),
                  ]),
                ),
                SizedBox(
                  height: mediaH,
                  width: width,
                  child: ClipRect(
                    child: p.isVideo && p.video != null
                        ? PostVideoView(
                            key: const ValueKey('peekVideo'),
                            session: session,
                            post: p,
                            active: true,
                            handleTap: false,
                            showFullscreen: false,
                            reportViews: false,
                            fit: BoxFit.cover,
                          )
                        : p.isMulti
                            ? PostPhotoCarousel(session: session, post: p, radius: 0, aspectRatio: width / mediaH)
                            : PostPhoto(session: session, post: p, radius: 0, aspectRatio: width / mediaH),
                  ),
                ),
                if (text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 0),
                    child: Text.rich(
                      emojiAwareSpan(text, (tt.bodyMedium ?? const TextStyle()).copyWith(color: t.ink, height: 1.35)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (onOpen != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(8, 2, 8, 6),
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        key: const ValueKey('peekOpen'),
                        onPressed: () => onOpen!(p),
                        child: Text(l.postPeekOpen, style: tt.labelLarge?.copyWith(color: t.ink)),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 10),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

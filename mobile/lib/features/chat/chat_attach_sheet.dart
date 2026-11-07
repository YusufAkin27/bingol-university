import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'media_pick.dart';

/// "+" menüsünün sonucu: galeri paneli ya da kamera. ([ChatAttachRecent] eski şeritten kalan tek fotoğraf sonucu.)
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

/// "+" menüsü (ChatGPT tarzı): tam ekran modal DEĞİL; "+" düğmesinin hemen üstünde küçük yüzen panel.
/// Satırlar: Kamera, Fotoğraflar (galeri paneli). Dışarı dokununca kapanır. Ses/dosya satırı backend desteği yokken
/// (yalnız IMAGE/VIDEO ek türü var) eklenmez: sahte seçenek gösterilmez.
/// [anchor] "+" düğmesinin ekran dikdörtgenidir; panel onun üst kenarının 8 dp üstüne, düğmeyle aynı başlangıç hizasına
/// açılır (RTL'de ayna). 180 ms solma + hafif ölçek; "animasyonları azalt"ta anında.
Future<ChatAttachResult?> showChatAttachMenu(BuildContext context, {required Rect anchor}) {
  final reduced = BuMotion.reduced(context);
  return showGeneralDialog<ChatAttachResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: reduced ? Duration.zero : const Duration(milliseconds: 180),
    pageBuilder: (c, a, b) => ChatAttachMenu(anchor: anchor),
    transitionBuilder: (c, anim, sec, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: .92, end: 1).animate(curved),
          alignment: AlignmentDirectional.bottomStart.resolve(Directionality.of(c)),
          child: child,
        ),
      );
    },
  );
}

class ChatAttachMenu extends StatelessWidget {
  const ChatAttachMenu({super.key, required this.anchor});

  final Rect anchor;

  static const double width = 232;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final left = rtl ? null : anchor.left.clamp(8.0, mq.size.width - width - 8);
    final right = rtl ? (mq.size.width - anchor.right).clamp(8.0, mq.size.width - width - 8) : null;
    return Stack(children: [
      Positioned(
        left: left,
        right: right,
        bottom: mq.size.height - anchor.top + 8,
        width: width,
        child: ChatAttachCard(onPick: (r) => Navigator.pop(context, r)),
      ),
    ]);
  }
}

/// "+" menüsünün kartı (Kamera, Fotoğraflar). Konumlandırmayı çağıran yapar: sohbet sayfası kartı "+" düğmesine
/// `CompositedTransformFollower` ile bağlar, böylece klavye açılıp kapanırken bile düğmenin hemen üstünde kalır.
class ChatAttachCard extends StatelessWidget {
  const ChatAttachCard({super.key, required this.onPick});

  final ValueChanged<ChatAttachResult> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return SizedBox(
      width: ChatAttachMenu.width,
      child: Semantics(
        explicitChildNodes: true,
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: BuElevation.of(context, 2)),
          child: Material(
            color: t.sf,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: t.bdSubtle)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _Row(
                  key: const ValueKey('attachCamera'),
                  icon: BuIcons.camera,
                  label: l.chatMiscCamera,
                  onTap: () => onPick(const ChatAttachCamera()),
                ),
                _Row(
                  key: const ValueKey('attachGallery'),
                  icon: BuIcons.images,
                  label: l.permPhotosTitle,
                  onTap: () => onPick(const ChatAttachGallery()),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Solda dairesel simge, sağda başlık; 52 dp yüksek dokunma alanı.
class _Row extends StatelessWidget {
  const _Row({super.key, required this.icon, required this.label, required this.onTap});

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
        scale: .98,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 16, 4),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: t.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: t.ink, fontWeight: BuType.emphasisWeight)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

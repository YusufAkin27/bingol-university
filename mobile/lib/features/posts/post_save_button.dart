import 'package:flutter/material.dart';

import '../../core/analytics.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'post_api.dart';
import 'post_models.dart';

/// Gönderiyi kaydet / kayıttan çıkar (PUT|DELETE /posts/{id}/save). İyimser; hata olursa geri alır.
/// Reels'teki kaydet ile aynı uç ve davranış; `savedByMe` null ise (eski yanıt) kapalı sayılır.
/// Hem kart/detay düğmesi hem ⋯ menüsü bu fonksiyonu kullanır.
Future<void> togglePostSaved(BuildContext context, Session session, Post p, ValueChanged<Post> onChanged) async {
  final l = context.l10n;
  final want = !(p.savedByMe ?? false);
  onChanged(p.copyWith(savedByMe: want));
  try {
    final got = await PostApi(session).setSaved(p.id, want);
    onChanged(p.copyWith(savedByMe: got));
    Analytics.instance.action('bookmark', target: got ? 'add' : 'remove');
    if (context.mounted) BuToast.show(context, got ? l.svSavedToast : l.svRemoved, kind: BuToastKind.success);
  } catch (e) {
    onChanged(p.copyWith(savedByMe: !want));
    if (context.mounted) BuToast.show(context, errorText(e), kind: BuToastKind.error);
  }
}

class PostSaveButton extends StatelessWidget {
  const PostSaveButton({super.key, required this.session, required this.post, required this.onChanged});

  final Session session;
  final Post post;
  final ValueChanged<Post> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final saved = post.savedByMe ?? false;
    final tip = saved ? context.l10n.svUnsave : context.l10n.svSave;
    return Semantics(
      button: true,
      label: tip,
      excludeSemantics: true,
      child: Tooltip(
        message: tip,
        child: BuPressable(
          key: const ValueKey('post-save'),
          onTap: () => togglePostSaved(context, session, post, onChanged),
          haptic: BuHaptic.light,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: BuSize.touch, minHeight: BuSize.touch),
            child: Center(child: Icon(saved ? BuIcons.bookmarkFilled : BuIcons.bookmark, size: 22, color: t.ink)),
          ),
        ),
      ),
    );
  }
}

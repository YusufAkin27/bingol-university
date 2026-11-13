import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/icons/bu_icons.dart';
import '../../../../core/locale_controller.dart';
import '../../../../core/theme.dart';
import '../../../../widgets/bu_overlays.dart';
import '../../../../widgets/bu_widgets.dart';
import '../../data/forum_models.dart';
import 'forum_sheet_row.dart';

/// Konu ⋯ menüsü seçenekleri.
enum TopicMenuAction { edit, delete, notifications, share, pin, lock, report, block, modRemove }

/// Gösterilecek seçenekler (yetki yalnız GÖSTERİM; sunucu yine doğrular):
/// sahip → düzenle / sil / bildirim aç-kapa / paylaş; moderatör → sabitle / kilitle; başkası → paylaş / şikâyet / engelle.
List<TopicMenuAction> topicMenuActions(TopicView t) {
  final owner = t.mine;
  return [
    if (owner && t.canEdit) TopicMenuAction.edit,
    if (owner || t.followedByMe) TopicMenuAction.notifications,
    TopicMenuAction.share,
    if (t.canModerate) TopicMenuAction.pin,
    if (t.canModerate) TopicMenuAction.lock,
    if (owner && t.canDelete) TopicMenuAction.delete,
    if (!owner) TopicMenuAction.report,
    if (!owner) TopicMenuAction.block,
    if (t.canModerate && !owner) TopicMenuAction.modRemove,
  ];
}

bool _danger(TopicMenuAction a) =>
    a == TopicMenuAction.delete || a == TopicMenuAction.report || a == TopicMenuAction.block ||
    a == TopicMenuAction.modRemove;

Future<TopicMenuAction?> showTopicMenu(BuildContext context, TopicView topic) {
  final actions = topicMenuActions(topic);
  HapticFeedback.selectionClick();
  return BuSheet.show<TopicMenuAction>(
    context,
    scrollable: true,
    padding: EdgeInsets.zero,
    builder: (ctx) {
      final t = ctx.bu;
      final l = ctx.l10n;
      (IconData, String) spec(TopicMenuAction a) => switch (a) {
            TopicMenuAction.edit => (BuIcons.pencil, l.forumDetailMenuEdit),
            TopicMenuAction.delete => (BuIcons.trash2, l.forumDetailMenuDelete),
            TopicMenuAction.notifications => topic.notificationsEnabled
                ? (BuIcons.bellOff, l.forumDetailMenuNotificationsOff)
                : (BuIcons.bellRing, l.forumDetailMenuNotificationsOn),
            TopicMenuAction.share => (BuIcons.send, l.forumDetailMenuShare),
            TopicMenuAction.pin => topic.pinned ? (BuIcons.pinOff, l.forumDetailMenuUnpin) : (BuIcons.pin, l.forumDetailMenuPin),
            TopicMenuAction.lock => topic.locked ? (BuIcons.lockOpen, l.forumDetailMenuUnlock) : (BuIcons.lock, l.forumDetailMenuLock),
            TopicMenuAction.report => (BuIcons.flag, l.forumDetailMenuReport),
            TopicMenuAction.block => (BuIcons.ban, l.forumDetailMenuBlock),
            TopicMenuAction.modRemove => (BuIcons.shieldAlert, l.forumModRemoveAction),
          };
      final safe = actions.where((a) => !_danger(a)).toList();
      final danger = actions.where(_danger).toList();
      Widget row(TopicMenuAction a) {
        final (icon, label) = spec(a);
        return ForumSheetRow<TopicMenuAction>(
            key: ValueKey('topicMenu-${a.name}'), icon: icon, label: label, value: a, danger: _danger(a));
      }

      return Column(
        key: const ValueKey('topicMenuSheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < safe.length; i++) ...[if (i > 0) Divider(height: 1, color: t.bdSubtle), row(safe[i])],
          if (danger.isNotEmpty) ...[
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Divider(height: 1, color: t.bd)),
            for (var i = 0; i < danger.length; i++) ...[if (i > 0) Divider(height: 1, color: t.bdSubtle), row(danger[i])],
          ],
          SizedBox(height: MediaQuery.paddingOf(ctx).bottom > 0 ? 0 : 8),
        ],
      );
    },
  );
}

/// Konu üst çubuğu: geri + (isteğe bağlı) paylaş + ⋯. SAYFA BAŞLIĞI METNİ YOK (kullanıcı kuralı); ekran
/// okuyucu için gizli başlık etiketi vardır.
class TopicDetailBar extends StatelessWidget {
  const TopicDetailBar({super.key, required this.onBack, this.onMore});

  final VoidCallback onBack;

  /// null: ⋯ gösterilmez (konu henüz yüklenmedi).
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(16, MediaQuery.paddingOf(context).top + 8, 16, 4),
      child: Row(children: [
        BuIconButton(
          key: const ValueKey('topicBack'),
          icon: buBackIcon(context),
          tooltip: l.commonBack,
          onTap: onBack,
        ),
        Semantics(header: true, label: l.forumDetailSemanticTitle, child: const SizedBox.shrink()),
        const Spacer(),
        if (onMore != null)
          BuIconButton(
            key: const ValueKey('topicMore'),
            icon: BuIcons.ellipsis,
            tooltip: l.forumDetailMenu,
            onTap: onMore,
          ),
      ]),
    );
  }
}

/// Yön duyarlı geri simgesi (RTL'de sağa bakar).
IconData buBackIcon(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl ? BuIcons.arrowRight : BuIcons.arrowLeft;

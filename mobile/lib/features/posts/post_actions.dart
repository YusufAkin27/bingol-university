import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart' show ApiError;
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart' show LucideIcons;
import '../../widgets/report_sheet.dart';
import '../profile/user_profile_page.dart';
import 'post_api.dart';
import 'post_models.dart';
import 'post_text_rules.dart';

/// Gönderi ⋯ menüsü (mesaj menüsüyle aynı tasarım dili: karartılmış modal + eylem kartı).
/// Yazara Düzenle/Sil, başkalarına Profili gör / Şikâyet et / Bu kullanıcıyı engelle.
/// [onDeleted] silme ve engelleme sonrası çağrılır (gönderi artık akışta görünmemeli).
Future<void> showPostActions(
  BuildContext context, {
  required Session session,
  required Post post,
  ValueChanged<Post>? onEdited,
  VoidCallback? onDeleted,
}) async {
  final mine = post.mine || post.author.id == session.userId;
  final l = context.l10n;
  final actions = <PostMenuAction>[
    if (post.canEdit) PostMenuAction('edit', l.postComposeEdit, LucideIcons.squarePen),
    if (post.canDelete) PostMenuAction('delete', l.postComposeDelete, LucideIcons.trash2, danger: true),
    if (!mine) ...[
      PostMenuAction('profile', l.postComposeViewProfile, LucideIcons.user),
      PostMenuAction('report', l.postComposeReport, LucideIcons.flag, danger: true),
      PostMenuAction('block', l.postComposeBlockUser, LucideIcons.ban, danger: true),
    ],
  ];
  if (actions.isEmpty) return;
  HapticFeedback.selectionClick();
  final id = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: l.postComposeClose,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    transitionBuilder: (c, a, s, child) => child,
    pageBuilder: (c, animation, _) => _PostMenuOverlay(animation: animation, actions: actions),
  );
  if (id == null || !context.mounted) return;
  switch (id) {
    case 'edit':
      final edited = await showDialog<Post>(
        context: context,
        builder: (_) => _EditDialog(session: session, post: post),
      );
      if (edited != null) onEdited?.call(edited);
    case 'delete':
      await _confirmDelete(context, session, post, onDeleted);
    case 'report':
      await ReportSheet.show(context, session,
          targetType: 'FEED_POST', targetId: post.id, title: l.postComposeReportTitle);
    case 'profile':
      await openUserProfile(context, session,
          userId: post.author.id, name: post.author.displayName, avatarUrl: post.author.avatarUrl);
    case 'block':
      await _confirmBlock(context, session, post, onDeleted);
  }
}

Future<void> _confirmDelete(BuildContext context, Session session, Post post, VoidCallback? onDeleted) async {
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(l.postComposeDeleteTitle),
      content: Text(l.postComposeDeleteBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.postComposeCancel)),
        TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.postComposeDelete, style: TextStyle(color: c.bu.danger))),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await PostApi(session).delete(post.id);
    onDeleted?.call();
    messenger.showSnackBar(SnackBar(content: Text(l.postComposeDeleted)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
  }
}

Future<void> _confirmBlock(BuildContext context, Session session, Post post, VoidCallback? onDeleted) async {
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(l.postComposeBlockTitle),
      content: Text(l.postComposeBlockBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.postComposeCancel)),
        TextButton(onPressed: () => Navigator.pop(c, true), child: Text(l.postComposeBlock)),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await session.api.post('/users/${post.author.id}/block');
    onDeleted?.call();
    messenger.showSnackBar(SnackBar(content: Text(l.postComposeBlocked)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
  }
}

/// Metin düzenleme: en çok 7 kelime (~60 karakter), satır sonu yok; küfür filtresi (422) iletisi diyalogda gösterilir.
class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.session, required this.post});

  final Session session;
  final Post post;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final _c = TextEditingController(text: widget.post.text ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _c.text.trim();
    if (!postTextOk(text)) return;
    if (text == (widget.post.text ?? '').trim()) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await PostApi(widget.session).update(widget.post.id, text);
      if (mounted) Navigator.pop(context, p);
    } catch (e) {
      if (!mounted) return;
      var msg = errorText(e);
      if (e is ApiError && e.code == 'CONTENT_PROFANITY' && e.message.isEmpty) {
        msg = context.l10n.postComposeProfanityFallback;
      }
      setState(() {
        _busy = false;
        _error = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return AlertDialog(
      title: Text(context.l10n.postComposeEditTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              key: const ValueKey('edit-post-text'),
              controller: _c,
              enabled: !_busy,
              autofocus: true,
              maxLines: 2,
              minLines: 1,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
                LengthLimitingTextInputFormatter(kPostMaxChars),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: context.l10n.gonderiTextHint,
                counterText: context.l10n.gonderiWordCount(postWordCount(_c.text).toString(), kPostMaxWords.toString()),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_error!, key: const ValueKey('edit-post-error'), style: BuType.caption.copyWith(color: t.danger)),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(context.l10n.postComposeCancel)),
        TextButton(
          key: const ValueKey('edit-post-save'),
          onPressed: (_busy || !postTextOk(_c.text)) ? null : _save,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(context.l10n.postComposeSave),
        ),
      ],
    );
  }
}

/// Kartın başlığındaki ⋯ düğmesi (PostCard.menuBuilder için). Menüde gösterilecek eylem yoksa boş yer bırakır.
class PostMenuButton extends StatelessWidget {
  const PostMenuButton({
    super.key,
    required this.session,
    required this.post,
    required this.onChanged,
    required this.onDeleted,
  });

  final Session session;
  final Post post;
  final ValueChanged<Post> onChanged;
  final ValueChanged<int> onDeleted;

  @override
  Widget build(BuildContext context) {
    final mine = post.mine || post.author.id == session.userId;
    if (mine && !post.canEdit && !post.canDelete) return const SizedBox(width: 10);
    return IconButton(
      key: const ValueKey('post-menu-button'),
      tooltip: context.l10n.postComposeMore,
      icon: Icon(LucideIcons.ellipsis, size: 20, color: context.bu.mut),
      onPressed: () => showPostActions(context,
          session: session, post: post, onEdited: onChanged, onDeleted: () => onDeleted(post.id)),
    );
  }
}

class PostMenuAction {
  const PostMenuAction(this.id, this.label, this.icon, {this.danger = false});

  final String id;
  final String label;
  final IconData icon;
  final bool danger;
}

class _PostMenuOverlay extends StatelessWidget {
  const _PostMenuOverlay({required this.animation, required this.actions});

  final Animation<double> animation;
  final List<PostMenuAction> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    final scale = Tween<double>(begin: .88, end: 1).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);
    final size = MediaQuery.sizeOf(context);
    final cardW = size.width - 48 > 280 ? 280.0 : size.width - 48;
    final shadow = [
      BoxShadow(color: Colors.black.withValues(alpha: dark ? .25 : .07), blurRadius: 12, offset: const Offset(0, 3)),
    ];
    return Material(
      key: const ValueKey('postMenu.root'),
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: BuType.body.copyWith(color: t.ink, decoration: TextDecoration.none),
        child: Stack(children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: fade,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: ColoredBox(color: Colors.black.withValues(alpha: dark ? .6 : .38)),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: scale,
                child: Container(
                  key: const ValueKey('postMenu.card'),
                  width: cardW,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: t.sf,
                    border: Border.all(color: t.bd),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: shadow,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        for (var i = 0; i < actions.length; i++) _Row(action: actions[i], first: i == 0),
                      ]),
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

class _Row extends StatelessWidget {
  const _Row({required this.action, required this.first});

  final PostMenuAction action;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final color = action.danger ? t.danger : t.ink;
    return InkWell(
      key: ValueKey('post-act-${action.id}'),
      onTap: () => Navigator.of(context).pop(action.id),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
            border: first ? null : Border(top: BorderSide(color: t.bd.withValues(alpha: .5), width: .5))),
        child: Row(children: [
          Expanded(
            child: Text(action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BuType.body.copyWith(color: color, decoration: TextDecoration.none)),
          ),
          const SizedBox(width: 10),
          Icon(action.icon, size: 16, color: action.danger ? t.danger : t.mut),
        ]),
      ),
    );
  }
}

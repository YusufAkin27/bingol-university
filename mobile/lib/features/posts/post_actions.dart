import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart' show ApiError;
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/report_sheet.dart';
import '../profile/user_profile_page.dart';
import 'post_api.dart';
import 'post_models.dart';
import 'post_text_rules.dart';

/// Gönderi ⋯ menüsü (Stitch v3 04/05): alt sayfa, 56 dp satırlar. Yazara Düzenle/Sil, başkalarına Profili gör / Şikâyet et / Bu kullanıcıyı engelle.
/// [anchorContext] ⋯ düğmesinin, [cardContext] kartın bağlamıdır (konum ölçümü için; verilmezse ortada açılır).
/// [onOpenChanged] menü açılıp kapanırken çağrılır (⋯ düğmesinin dolu hali için).
/// [onDeleted] silme ve engelleme sonrası çağrılır (gönderi artık akışta görünmemeli).
Future<void> showPostActions(
  BuildContext context, {
  required Session session,
  required Post post,
  ValueChanged<Post>? onEdited,
  VoidCallback? onDeleted,
  BuildContext? anchorContext,
  BuildContext? cardContext,
  ValueChanged<bool>? onOpenChanged,
}) async {
  final mine = post.mine || post.author.id == session.userId;
  final l = context.l10n;
  final actions = <PostMenuAction>[
    if (post.canEdit) PostMenuAction('edit', l.postComposeEdit, LucideIcons.squarePen),
    if (post.canDelete) PostMenuAction('delete', l.postComposeDelete, LucideIcons.trash2, danger: true),
    if (!mine) ...[
      PostMenuAction('profile', l.postComposeViewProfile, LucideIcons.user),
      PostMenuAction('report', l.postComposeReport, LucideIcons.flag),
      PostMenuAction('block', l.postComposeBlockUser, LucideIcons.ban, danger: true),
    ],
  ];
  if (actions.isEmpty) return;
  HapticFeedback.selectionClick();
  onOpenChanged?.call(true);
  final String? id;
  try {
    // Stitch v3 04/05: alt sayfa, her satır 56 dp, satırlar arası 1 dp bd; başka satır yok.
    id = await BuSheet.show<String>(
      context,
      scrollable: false,
      padding: EdgeInsets.zero,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) Divider(height: 1, color: ctx.bu.bd),
          _SheetRow(action: actions[i]),
        ],
        SizedBox(height: MediaQuery.paddingOf(ctx).bottom > 0 ? 0 : 8),
      ]),
    );
  } finally {
    onOpenChanged?.call(false);
  }
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

/// Ortak diyalog kabuğu: 28 köşe, geniş iç boşluk.
class _DialogShell extends StatelessWidget {
  const _DialogShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: context.bu.sf3,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(padding: const EdgeInsets.all(24), child: child),
      );
}

Widget _dialogButtons(BuildContext c, {required String cancel, required Widget confirm, required VoidCallback onCancel}) {
  final t = c.bu;
  return Row(children: [
    Expanded(
      child: TextButton(
        key: const ValueKey('post-dialog-cancel'),
        onPressed: onCancel,
        style: TextButton.styleFrom(minimumSize: const Size(64, BuSize.button), foregroundColor: t.mut),
        child: Text(cancel, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    ),
    const SizedBox(width: 8),
    Expanded(child: confirm),
  ]);
}

Future<void> _confirmDelete(BuildContext context, Session session, Post post, VoidCallback? onDeleted) async {
  final l = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) {
      final t = c.bu;
      final tt = Theme.of(c).textTheme;
      return _DialogShell(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.postComposeDeleteTitle, style: tt.titleLarge?.copyWith(color: t.ink, fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(l.postComposeDeleteBody, style: tt.bodyMedium?.copyWith(color: t.mut)),
          const SizedBox(height: 24),
          _dialogButtons(c,
              cancel: l.postComposeCancel,
              onCancel: () => Navigator.pop(c, false),
              confirm: BuButton(
                key: const ValueKey('post-dialog-confirm'),
                label: l.postComposeDelete,
                kind: BuButtonKind.danger,
                onPressed: () => Navigator.pop(c, true),
              )),
        ]),
      );
    },
  );
  if (ok != true || !context.mounted) return;
  try {
    await PostApi(session).delete(post.id);
    onDeleted?.call();
    if (context.mounted) BuToast.show(context, l.postComposeDeleted, kind: BuToastKind.success);
  } catch (e) {
    if (context.mounted) BuToast.show(context, errorText(e), kind: BuToastKind.error);
  }
}

Future<void> _confirmBlock(BuildContext context, Session session, Post post, VoidCallback? onDeleted) async {
  final l = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) {
      final t = c.bu;
      final tt = Theme.of(c).textTheme;
      return _DialogShell(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.postComposeBlockTitle, style: tt.titleLarge?.copyWith(color: t.ink, fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(l.postComposeBlockBody, style: tt.bodyMedium?.copyWith(color: t.mut)),
          const SizedBox(height: 24),
          _dialogButtons(c,
              cancel: l.postComposeCancel,
              onCancel: () => Navigator.pop(c, false),
              confirm: BuButton(
                key: const ValueKey('post-dialog-confirm'),
                label: l.postComposeBlock,
                kind: BuButtonKind.danger,
                onPressed: () => Navigator.pop(c, true),
              )),
        ]),
      );
    },
  );
  if (ok != true || !context.mounted) return;
  try {
    await session.api.post('/users/${post.author.id}/block');
    onDeleted?.call();
    if (context.mounted) BuToast.show(context, l.postComposeBlocked, kind: BuToastKind.success);
  } catch (e) {
    if (context.mounted) BuToast.show(context, errorText(e), kind: BuToastKind.error);
  }
}

/// Metin düzenleme (referans 11/3): en çok 7 kelime (~60 karakter), satır sonu yok; boş metin kaydedilmez; küfür filtresi
/// (422) iletisi diyalogda gösterilir.
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

  bool get _empty => _c.text.trim().isEmpty;
  bool get _canSave => !_busy && !_empty && postTextOk(_c.text);

  Future<void> _save() async {
    final text = _c.text.trim();
    if (!_canSave) return;
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
        msg = context.l10n.postComposeErrProfanity;
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
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final over = !postTextOk(_c.text);
    return _DialogShell(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.postComposeEditTitle, style: tt.titleLarge?.copyWith(color: t.ink, fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          // Stitch v3 06: alan 16 köşe, 1 dp bdStrong (hata/aşımda danger), iç 16x14, en az 72 dp; sayaç alanın altında sağda.
          DecoratedBox(
            decoration: BoxDecoration(
              color: t.sf,
              borderRadius: BorderRadius.circular(BuRadius.md),
              border: Border.all(color: over || _error != null ? t.danger : t.bdStrong),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: TextField(
                  key: const ValueKey('edit-post-text'),
                  controller: _c,
                  enabled: !_busy,
                  autofocus: true,
                  maxLines: 3,
                  minLines: 2,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
                    LengthLimitingTextInputFormatter(kPostMaxChars),
                  ],
                  onChanged: (_) => setState(() => _error = null),
                  style: tt.bodyLarge?.copyWith(color: t.ink),
                  decoration: InputDecoration(
                    hintText: l.gonderiTextHint,
                    hintStyle: tt.bodyLarge?.copyWith(color: t.mut),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l.gonderiWordCount(postWordCount(_c.text).toString(), kPostMaxWords.toString()),
                  key: const ValueKey('edit-post-counter'),
                  style: tt.labelSmall?.copyWith(color: over ? t.danger : t.mut, fontSize: 12, fontWeight: over ? FontWeight.w700 : FontWeight.w400)),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, key: const ValueKey('edit-post-error'), style: tt.bodySmall?.copyWith(color: t.danger, fontSize: 13)),
            ),
          if (_empty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(l.postComposeTextEmpty, key: const ValueKey('edit-post-empty'), style: tt.bodySmall?.copyWith(color: t.mut)),
            ),
          const SizedBox(height: 20),
          _dialogButtons(context,
              cancel: l.postComposeCancel,
              onCancel: _busy ? () {} : () => Navigator.pop(context),
              confirm: BuButton(
                key: const ValueKey('edit-post-save'),
                label: l.postComposeSave,
                busy: _busy,
                onPressed: _canSave ? _save : null,
              )),
        ]),
      ),
    );
  }
}

/// Kartın başlığındaki ⋯ düğmesi. Menüde gösterilecek eylem yoksa boş yer bırakır. [active]: menü açıkken tonal daire.
class PostMenuButton extends StatelessWidget {
  const PostMenuButton({
    super.key,
    required this.session,
    required this.post,
    required this.onChanged,
    required this.onDeleted,
    this.active = false,
    this.cardKey,
    this.onOpenChanged,
    this.onMedia = false,
  });

  final Session session;
  final Post post;
  final ValueChanged<Post> onChanged;
  final ValueChanged<int> onDeleted;
  final bool active;
  final GlobalKey? cardKey;
  final ValueChanged<bool>? onOpenChanged;

  /// Görselin üstünde: yarı saydam yuvarlak zemin + `onMedia` simge (48 dp dokunma alanı aynı).
  final bool onMedia;

  @override
  Widget build(BuildContext context) {
    final mine = post.mine || post.author.id == session.userId;
    if (mine && !post.canEdit && !post.canDelete) return const SizedBox(width: 10);
    final t = context.bu;
    // Görünen daire 40 dp; dokunma hedefi 48x48 (erişilebilirlik): daire arkada, düğme üstte tam boyda.
    return SizedBox.square(
      dimension: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: BuMotion.of(context, BuMotion.short),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: onMedia ? t.scrim.withValues(alpha: active ? .55 : .35) : (active ? t.soft : Colors.transparent),
                shape: BoxShape.circle),
          ),
          IconButton(
            key: const ValueKey('post-menu-button'),
            tooltip: context.l10n.postComposeMore,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            icon: Icon(Icons.more_horiz, size: 24, color: onMedia ? t.onMedia : (active ? t.onSoft : t.ink)),
            onPressed: () => showPostActions(context,
                session: session,
                post: post,
                onEdited: onChanged,
                onDeleted: () => onDeleted(post.id),
                anchorContext: context,
                cardContext: cardKey?.currentContext,
                onOpenChanged: onOpenChanged),
          ),
        ],
      ),
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

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.action});

  final PostMenuAction action;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final color = action.danger ? t.danger : t.ink;
    return InkWell(
      key: ValueKey('post-act-${action.id}'),
      onTap: () => Navigator.of(context).pop(action.id),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: BuSize.row),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(children: [
            Icon(action.icon, size: 24, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(action.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: color, fontSize: 16, fontWeight: FontWeight.w500)),
            ),
          ]),
        ),
      ),
    );
  }
}

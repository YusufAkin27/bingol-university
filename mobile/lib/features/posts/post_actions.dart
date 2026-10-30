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

/// Gönderi ⋯ menüsü (referans 11): arka plan karartılır, gönderi kartı karartmanın üstünde kalır, menü kartı ⋯ düğmesinin
/// altında açılır. Yazara Düzenle/Sil, başkalarına Profili gör / Şikâyet et / Bu kullanıcıyı engelle.
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
  final anchor = _rectOf(anchorContext);
  final card = _rectOf(cardContext);
  onOpenChanged?.call(true);
  final String? id;
  try {
    id = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: l.postComposeClose,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (c, a, s, child) => child,
      pageBuilder: (c, animation, _) => _PostMenuOverlay(animation: animation, actions: actions, anchor: anchor, card: card),
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

Rect? _rectOf(BuildContext? c) {
  final o = c?.findRenderObject();
  if (o is! RenderBox || !o.attached || !o.hasSize) return null;
  return o.localToGlobal(Offset.zero) & o.size;
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 20), child: child),
      );
}

Widget _dialogButtons(BuildContext c, {required String cancel, required Widget confirm, required VoidCallback onCancel}) {
  final t = c.bu;
  return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
    TextButton(
      key: const ValueKey('post-dialog-cancel'),
      onPressed: onCancel,
      style: TextButton.styleFrom(minimumSize: const Size(64, 48), foregroundColor: t.mut),
      child: Text(cancel, style: const TextStyle(fontWeight: FontWeight.w700)),
    ),
    const SizedBox(width: 8),
    confirm,
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: t.danger.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)),
            child: Icon(LucideIcons.trash2, size: 22, color: t.danger),
          ),
          const SizedBox(height: 16),
          Text(l.postComposeDeleteTitle, style: tt.titleLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(l.postComposeDeleteBody, style: tt.bodyMedium?.copyWith(color: t.mut)),
          const SizedBox(height: 24),
          _dialogButtons(c,
              cancel: l.postComposeCancel,
              onCancel: () => Navigator.pop(c, false),
              confirm: BuButton(
                key: const ValueKey('post-dialog-confirm'),
                label: l.postComposeDelete,
                icon: LucideIcons.trash2,
                kind: BuButtonKind.danger,
                compact: true,
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: t.danger.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)),
            child: Icon(LucideIcons.ban, size: 22, color: t.danger),
          ),
          const SizedBox(height: 16),
          Text(l.postComposeBlockTitle, style: tt.titleLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(l.postComposeBlockBody, style: tt.bodyMedium?.copyWith(color: t.mut)),
          const SizedBox(height: 24),
          _dialogButtons(c,
              cancel: l.postComposeCancel,
              onCancel: () => Navigator.pop(c, false),
              confirm: BuButton(
                key: const ValueKey('post-dialog-confirm'),
                label: l.postComposeBlock,
                icon: LucideIcons.ban,
                kind: BuButtonKind.danger,
                compact: true,
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
          Row(children: [
            Expanded(child: Text(l.postComposeEditTitle, style: tt.titleLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w700))),
            Tooltip(
              message: l.postComposeClose,
              child: Material(
                color: t.sf2,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _busy ? null : () => Navigator.pop(context),
                  child: SizedBox.square(dimension: 44, child: Icon(LucideIcons.x, size: 20, color: t.ink)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: t.sf2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: over || _error != null ? t.danger : t.bd),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
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
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(l.gonderiWordCount(postWordCount(_c.text).toString(), kPostMaxWords.toString()),
                      key: const ValueKey('edit-post-counter'),
                      style: tt.labelMedium?.copyWith(color: over ? t.danger : t.mut, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.error, size: 18, color: t.danger),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, key: const ValueKey('edit-post-error'), style: tt.bodySmall?.copyWith(color: t.danger))),
              ]),
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
                compact: true,
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
  });

  final Session session;
  final Post post;
  final ValueChanged<Post> onChanged;
  final ValueChanged<int> onDeleted;
  final bool active;
  final GlobalKey? cardKey;
  final ValueChanged<bool>? onOpenChanged;

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
            decoration: BoxDecoration(color: active ? t.soft : Colors.transparent, shape: BoxShape.circle),
          ),
          IconButton(
            key: const ValueKey('post-menu-button'),
            tooltip: context.l10n.postComposeMore,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            icon: Icon(Icons.more_horiz, size: 24, color: active ? t.onSoft : t.ink),
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

class _PostMenuOverlay extends StatelessWidget {
  const _PostMenuOverlay({required this.animation, required this.actions, this.anchor, this.card});

  final Animation<double> animation;
  final List<PostMenuAction> actions;
  final Rect? anchor;
  final Rect? card;

  static const _w = 236.0;
  static const _row = 52.0;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    final size = MediaQuery.sizeOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final menuH = actions.length * _row + 12;
    final w = _w.clamp(0.0, size.width - 32);

    // Konum: ⋯ düğmesinin altında, düğmenin dış kenarına hizalı; sığmazsa üstünde. Ölçüm yoksa ortada.
    double? top, left;
    var alignment = AlignmentDirectional.topEnd.resolve(Directionality.of(context));
    if (anchor != null) {
      final below = anchor!.bottom + 6;
      final fits = below + menuH <= size.height - MediaQuery.paddingOf(context).bottom - 12;
      top = fits ? below : (anchor!.top - 6 - menuH).clamp(12.0, size.height);
      left = rtl ? anchor!.left : anchor!.right - w;
      left = left.clamp(16.0, size.width - w - 16);
      alignment = fits ? (rtl ? Alignment.topLeft : Alignment.topRight) : (rtl ? Alignment.bottomLeft : Alignment.bottomRight);
    }
    final menu = ScaleTransition(
      scale: Tween<double>(begin: .9, end: 1).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
      alignment: alignment,
      child: FadeTransition(
        opacity: fade,
        child: Container(
          key: const ValueKey('postMenu.card'),
          width: w,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: t.sf3,
            borderRadius: BorderRadius.circular(20),
            border: dark ? Border.all(color: t.bd) : null,
            boxShadow: BuElevation.of(context, 3),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              type: MaterialType.transparency,
              child: Column(mainAxisSize: MainAxisSize.min, children: [for (final a in actions) _Row(action: a)]),
            ),
          ),
        ),
      ),
    );
    return Material(
      key: const ValueKey('postMenu.root'),
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.ink, decoration: TextDecoration.none),
        child: Stack(children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: fade,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                // Gönderi kartı karartmanın üstünde kalır (karttan sonra delik bırakılır).
                child: CustomPaint(painter: _ScrimPainter(hole: card, color: t.scrim.withValues(alpha: dark ? .62 : .42))),
              ),
            ),
          ),
          if (anchor != null) Positioned(top: top, left: left, child: menu) else Center(child: menu),
        ]),
      ),
    );
  }
}

class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({required this.hole, required this.color});

  final Rect? hole;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final all = Path()..addRect(Offset.zero & size);
    final h = hole;
    final path = h == null
        ? all
        : Path.combine(PathOperation.difference, all, Path()..addRRect(RRect.fromRectAndRadius(h, const Radius.circular(BuRadius.lg))));
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ScrimPainter o) => o.hole != hole || o.color != color;
}

class _Row extends StatelessWidget {
  const _Row({required this.action});

  final PostMenuAction action;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final color = action.danger ? t.danger : t.ink;
    return InkWell(
      key: ValueKey('post-act-${action.id}'),
      onTap: () => Navigator.of(context).pop(action.id),
      child: SizedBox(
        height: _PostMenuOverlay._row,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Icon(action.icon, size: 20, color: action.danger ? t.danger : t.mut),
            const SizedBox(width: 14),
            Expanded(
              child: Text(action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
            ),
          ]),
        ),
      ),
    );
  }
}

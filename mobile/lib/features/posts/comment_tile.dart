import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/report_sheet.dart';
import '../profile/user_profile_page.dart';
import 'comment_controller.dart';
import 'comment_models.dart';
import 'rich_text.dart';

const kCommentMax = 1000;

/// Seviyeye göre avatar boyutu (0..3): iç içe indikçe küçülür.
double commentAvatarSize(int depth) => const [34.0, 28.0, 24.0, 22.0][depth.clamp(0, 3)];

/// Tek yorum satırı: avatar, ad, zaman, metin (@yanıtlanan mavi), Yanıtla ve ⋯ menüsü.
class CommentTile extends StatefulWidget {
  const CommentTile({
    super.key,
    required this.node,
    required this.controller,
    required this.session,
    required this.onReply,
    this.highlighted = false,
  });

  final CNode node;
  final CommentsController controller;
  final Session session;
  final void Function(CNode) onReply;
  final bool highlighted;

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  bool _editing = false;
  bool _saving = false;
  String? _editError;
  TextEditingController? _edit;

  Comment get c => widget.node.c;

  @override
  void dispose() {
    _edit?.dispose();
    super.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _profile(CommentUser u) {
    if (u.id == 0) return;
    openUserProfile(context, widget.session, userId: u.id, name: u.displayName, avatarUrl: u.avatarUrl);
  }

  Future<void> _menu() async {
    final t = context.bu;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: t.sf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: t.bd, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 8),
            if (c.canEdit)
              ListTile(
                leading: Icon(LucideIcons.pencil, color: t.ink, size: 20),
                title: Text('Düzenle', style: BuType.bodyStrong.copyWith(color: t.ink)),
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
            if (c.canDelete)
              ListTile(
                leading: Icon(LucideIcons.trash2, color: t.danger, size: 20),
                title: Text('Sil', style: BuType.bodyStrong.copyWith(color: t.danger)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            if (!c.mine)
              ListTile(
                leading: Icon(LucideIcons.flag, color: t.ink, size: 20),
                title: Text('Şikâyet et', style: BuType.bodyStrong.copyWith(color: t.ink)),
                onTap: () => Navigator.pop(ctx, 'report'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        setState(() {
          _editing = true;
          _editError = null;
          _edit = TextEditingController(text: c.text ?? '');
        });
      case 'delete':
        await _confirmDelete();
      case 'report':
        await ReportSheet.show(context, widget.session,
            targetType: 'FEED_COMMENT', targetId: c.id, title: 'Yorumu şikâyet et');
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yorum silinsin mi?'),
        content: const Text('Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.controller.remove(widget.node);
    } catch (e) {
      _snack(errorText(e));
    }
  }

  Future<void> _saveEdit() async {
    final text = _edit?.text.trim() ?? '';
    if (text.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _editError = null;
    });
    try {
      await widget.controller.edit(widget.node, text);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editError = errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final n = widget.node;
    final size = commentAvatarSize(c.depth);
    final base = BuType.body.copyWith(color: t.ink);

    Widget content;
    if (c.deleted) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text('Bu yorum silindi', style: BuType.body.copyWith(color: t.mut, fontStyle: FontStyle.italic)),
      );
      return _frame(t, Padding(padding: EdgeInsets.only(left: size + 8), child: content));
    }

    final meta = [shortAgo(c.createdAt), if (c.editedAt != null) 'düzenlendi'].where((s) => s.isNotEmpty).join(' · ');

    content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true, // profil düğmesi avatarda
                onTap: () => _profile(c.author),
                child: Text(c.author.displayName,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.bodyStrong.copyWith(color: t.ink)),
              ),
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(meta, maxLines: 1, style: BuType.caption.copyWith(color: t.mut)),
            ],
          ],
        ),
        if (_editing)
          _editor(t)
        else ...[
          const SizedBox(height: 2),
          RichPostText(
            c.text ?? '',
            style: base,
            session: widget.session,
            prefix: c.replyToUser == null
                ? null
                : TextSpan(
                    text: '@${c.replyToUser!.displayName} ',
                    style: base.copyWith(color: t.pr, fontWeight: FontWeight.w600),
                  ),
          ),
          const SizedBox(height: 4),
          _actions(t),
        ],
      ],
    );

    return _frame(
      t,
      Opacity(
        opacity: n.pending ? .6 : 1,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dokunma alanı en az 44 dp: küçük avatar ortalanır.
            Semantics(
              label: '${c.author.displayName} profili',
              button: true,
              excludeSemantics: true,
              onTap: () => _profile(c.author),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _profile(c.author),
                child: SizedBox(
                  width: size < 44 ? 44 : size,
                  height: size < 44 ? 44 : size,
                  child: Align(
                      alignment: AlignmentDirectional.topStart,
                      child: BuAvatar(name: c.author.displayName, url: c.author.avatarUrl, size: size)),
                ),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget _frame(BuTokens t, Widget child) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: widget.highlighted ? t.soft : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      );

  Widget _actions(BuTokens t) {
    final n = widget.node;
    if (n.failed) {
      return Semantics(
        button: true,
        label: 'Gönderilemedi, yeniden dene',
        child: Row(
          children: [
            Flexible(
              child: InkWell(
                onTap: () async {
                  final r = await widget.controller.retry(n);
                  if (!r.ok) _snack(r.error!);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('Gönderilemedi · Yeniden dene',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.label.copyWith(color: t.danger)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () => widget.controller.discard(n),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('Kaldır', style: BuType.label.copyWith(color: t.mut)),
              ),
            ),
          ],
        ),
      );
    }
    if (n.pending) return Text('Gönderiliyor…', style: BuType.caption.copyWith(color: t.mut));
    return Row(
      children: [
        Semantics(
          button: true,
          label: '${c.author.displayName} kişisine yanıt ver',
          excludeSemantics: true,
          onTap: () => widget.onReply(n),
          child: InkWell(
            onTap: () => widget.onReply(n),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: 1,
                child: Text('Yanıtla', style: BuType.label.copyWith(color: t.mut, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
        const Spacer(),
        if (!n.c.isTemp)
          Semantics(
            button: true,
            label: 'Yorum seçenekleri',
            excludeSemantics: true,
            onTap: _menu,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _menu,
              child: SizedBox(width: 44, height: 44, child: Icon(LucideIcons.ellipsis, size: 18, color: t.mut)),
            ),
          ),
      ],
    );
  }

  Widget _editor(BuTokens t) {
    final ctl = _edit!;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: ctl,
            autofocus: true,
            minLines: 1,
            maxLines: 6,
            enabled: !_saving,
            inputFormatters: [LengthLimitingTextInputFormatter(kCommentMax)],
            style: BuType.body.copyWith(color: t.ink),
            decoration: const InputDecoration(isDense: true, hintText: 'Yorumu düzenle'),
          ),
          if (_editError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_editError!, style: BuType.caption.copyWith(color: t.danger)),
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => setState(() => _editing = false),
                child: const Text('İptal'),
              ),
              const SizedBox(width: 4),
              BuButton(label: 'Kaydet', compact: true, busy: _saving, onPressed: _saveEdit),
            ],
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'chatlist_widgets.dart';

/// Aynı anda yalnız bir satır açık kalır: yeni satır açılınca diğeri kapanır.
final ValueNotifier<Object?> _openSwipeRow = ValueNotifier<Object?>(null);

/// Sohbet satırı kaydırma eylemleri: satır başlangıçtan sona doğru (LTR'de sağdan sola, RTL'de tersi) çekilince
/// yan yana iki düğme açılır: "Arşivle" ve "Daha fazla" (3 nokta). Kaydırma KENDİLİĞİNDEN eylem çalıştırmaz;
/// yalnız düğmeleri açar. Açıkken satıra dokunmak önce kapatır.
class ConversationSwipeRow extends StatefulWidget {
  const ConversationSwipeRow({
    super.key,
    required this.child,
    required this.archived,
    required this.onArchive,
    required this.onMore,
  });

  final Widget child;

  /// Arşiv görünümünde ilk düğme "Çıkar" olur.
  final bool archived;
  final VoidCallback onArchive;
  final VoidCallback onMore;

  static const double buttonWidth = 84;

  @override
  State<ConversationSwipeRow> createState() => _ConversationSwipeRowState();
}

class _ConversationSwipeRowState extends State<ConversationSwipeRow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  static const double _total = ConversationSwipeRow.buttonWidth * 2;

  @override
  void initState() {
    super.initState();
    _openSwipeRow.addListener(_onOtherOpened);
  }

  void _onOtherOpened() {
    if (_openSwipeRow.value != this && _c.value > 0) _settle(false);
  }

  @override
  void dispose() {
    _openSwipeRow.removeListener(_onOtherOpened);
    if (_openSwipeRow.value == this) _openSwipeRow.value = null;
    _c.dispose();
    super.dispose();
  }

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  void _settle(bool open) {
    final d = BuMotion.of(context, const Duration(milliseconds: 200));
    if (open) _openSwipeRow.value = this;
    if (!open && _openSwipeRow.value == this) _openSwipeRow.value = null;
    if (d == Duration.zero) {
      _c.value = open ? 1 : 0;
    } else {
      _c.animateTo(open ? 1 : 0, duration: d, curve: Curves.easeOutCubic);
    }
  }

  void _onUpdate(DragUpdateDetails d) {
    // Başlangıç->son yönündeki çekme pozitiftir (LTR'de sola, RTL'de sağa).
    final toward = _rtl ? d.delta.dx : -d.delta.dx;
    _c.value = (_c.value + toward / _total).clamp(0.0, 1.0);
  }

  void _onEnd(DragEndDetails d) {
    final v = _rtl ? d.velocity.pixelsPerSecond.dx : -d.velocity.pixelsPerSecond.dx;
    if (v.abs() > 400) {
      _settle(v > 0);
    } else {
      _settle(_c.value > .4);
    }
    if (_c.value > 0 && v > 0) HapticFeedback.selectionClick();
  }

  void _run(VoidCallback cb) {
    _settle(false);
    cb();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final shift = _c.value * _total;
        final sign = _rtl ? 1.0 : -1.0;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: _onUpdate,
          onHorizontalDragEnd: _onEnd,
          onHorizontalDragCancel: () => _settle(_c.value > .5),
          child: Stack(children: [
            if (_c.value > 0)
              Positioned.fill(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: SizedBox(
                    width: _total,
                    child: Row(children: [
                      _SwipeButton(
                        key: const ValueKey('swipe-archive'),
                        icon: widget.archived ? BuIcons.archiveRestore : BuIcons.archive,
                        label: widget.archived ? l.chatMiscUnarchiveAction : l.chatMiscArchiveAction,
                        bg: t.sf2,
                        fg: t.ink,
                        onTap: () => _run(widget.onArchive),
                      ),
                      _SwipeButton(
                        key: const ValueKey('swipe-more'),
                        icon: BuIcons.ellipsis,
                        label: l.chatMiscMoreAction,
                        bg: t.bd,
                        fg: t.ink,
                        onTap: () => _run(widget.onMore),
                      ),
                    ]),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(sign * shift, 0),
              child: _c.value > 0
                  ? DecoratedBox(
                      decoration: BoxDecoration(color: t.bg),
                      child: AbsorbPointer(
                        // Açıkken satır içi dokunuşlar yutulur; dokunma satırı kapatır.
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _settle(false),
                          child: widget.child,
                        ),
                      ),
                    )
                  : widget.child,
            ),
          ]),
        );
      },
    );
  }
}

class _SwipeButton extends StatelessWidget {
  const _SwipeButton({super.key, required this.icon, required this.label, required this.bg, required this.fg, required this.onTap});

  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ColoredBox(
            color: bg,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 22, color: fg),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium!.copyWith(color: fg, fontWeight: FontWeight.w400)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Uzun basınca açılan SALT OKUNUR sohbet önizlemesi: bulanık arka plan + kayan kart (ad + son mesajlar).
/// Mesajlar yalnız `GET /conversations/{id}/messages?size=N` ile çekilir; okundu/teslim bildirimi
/// (`POST .../read`, `.../delivered`, STOMP `chat.read`) ve okunmamış sayacı sıfırlama ASLA çağrılmaz.
/// Dönüş: `true` = "Aç"; null = kapatıldı.
Future<bool?> showConversationPeek(
  BuildContext context, {
  required Session session,
  required int conversationId,
  required String title,
  String? avatarUrl,
  bool group = false,
  required int? myId,
  required String Function(BuildContext, Map<String, dynamic>) describe,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: BuMotion.of(context, const Duration(milliseconds: 220)),
    pageBuilder: (c, _, __) => ConversationPeek(
      session: session,
      conversationId: conversationId,
      title: title,
      avatarUrl: avatarUrl,
      group: group,
      myId: myId,
      describe: describe,
    ),
    transitionBuilder: (c, a, _, child) {
      final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween<double>(begin: .94, end: 1).animate(curved), child: child),
      );
    },
  );
}

class ConversationPeek extends StatefulWidget {
  const ConversationPeek({
    super.key,
    required this.session,
    required this.conversationId,
    required this.title,
    required this.myId,
    required this.describe,
    this.avatarUrl,
    this.group = false,
  });

  final Session session;
  final int conversationId;
  final String title;
  final String? avatarUrl;
  final bool group;
  final int? myId;
  final String Function(BuildContext, Map<String, dynamic>) describe;

  @override
  State<ConversationPeek> createState() => _ConversationPeekState();
}

class _ConversationPeekState extends State<ConversationPeek> {
  List<Map<String, dynamic>>? _msgs; // eski -> yeni
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      // Salt okunur: yalnız mesaj listesi; okundu göndermez.
      final page = await widget.session.api.get('/conversations/${widget.conversationId}/messages?size=12');
      final raw = page is Map ? (page['items'] as List? ?? const []) : const [];
      final list = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      list.sort((a, b) => ((a['id'] as num?) ?? 0).compareTo((b['id'] as num?) ?? 0));
      if (!mounted) return;
      setState(() => _msgs = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);
    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.pop(context),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: ColoredBox(color: t.bg.withValues(alpha: .55)),
          ),
        ),
      ),
      SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 440, maxHeight: size.height * .72),
              child: Material(
                key: const ValueKey('conversation-peek'),
                color: t.bg.withValues(alpha: .96),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BuRadius.bLg, side: BorderSide(color: t.bd)),
                clipBehavior: Clip.antiAlias,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(children: [
                      ChatlistAvatar(name: widget.title, url: widget.avatarUrl, group: widget.group, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(color: t.ink)),
                        ),
                      ),
                    ]),
                  ),
                  Divider(height: 1, color: t.bd),
                  Flexible(child: _body(context, t, tx, l)),
                  Divider(height: 1, color: t.bd),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: BuButton(
                      label: l.chatMiscPeekOpen,
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _body(BuildContext context, BuTokens t, TextTheme tx, AppLocalizations l) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(l.chatMiscPeekError, style: tx.bodyMedium!.copyWith(color: t.mut), textAlign: TextAlign.center)),
      );
    }
    final msgs = _msgs;
    if (msgs == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
      );
    }
    if (msgs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(l.chatMiscPeekEmpty, style: tx.bodyMedium!.copyWith(color: t.mut))),
      );
    }
    return ListView.builder(
      key: const ValueKey('peek-messages'),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: msgs.length,
      itemBuilder: (c, i) => _PeekBubble(message: msgs[i], mine: widget.myId != null && (msgs[i]['senderId'] as num?)?.toInt() == widget.myId, text: widget.describe(c, msgs[i])),
    );
  }
}

class _PeekBubble extends StatelessWidget {
  const _PeekBubble({required this.message, required this.mine, required this.text});

  final Map<String, dynamic> message;
  final bool mine;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    if (text.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: mine ? t.pr : t.sf2, borderRadius: BuRadius.bMd),
        child: Text(text, maxLines: 6, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(color: mine ? t.onPr : t.ink)),
      ),
    );
  }
}

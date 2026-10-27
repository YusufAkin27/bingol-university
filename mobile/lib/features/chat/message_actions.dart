import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../core/typography.dart';

/// Eylem listesindeki tek satır.
class MessageAction {
  const MessageAction(this.id, this.label, this.icon, {this.danger = false});

  final String id;
  final String label;
  final IconData icon;
  final bool danger;
}

/// Mesaja uzun basınca açılan WhatsApp tarzı menü: arka plan hafif kararır, basılan mesaj yerinde öne çıkar,
/// üstünde tepki hapı, altında eylem kartı. Dönüş: `react:<emoji>` ya da seçilen eylemin `id`'si; kapatılırsa null.
///
/// [anchor] mesajın ekrandaki (global) dikdörtgenidir; [preview] aynı baloncuğun etkileşimsiz kopyasıdır.
/// Ekrana sığmıyorsa küme otomatik kaydırılır, çok uzun mesaj önizlemesi kırpılır (taşma olmaz).
Future<String?> showMessageActions(
  BuildContext context, {
  required Rect anchor,
  required Widget preview,
  required bool mine,
  required List<MessageAction> actions,
  List<String> emojis = const [],
  String? myReaction,
}) {
  HapticFeedback.selectionClick();
  // Modal: bariyer dokunuşu yakalar ve kapatır, geri tuşu kapatır, alttaki liste etkileşmez.
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Kapat',
    barrierColor:
        Colors.transparent, // karartmayı kendimiz çiziyoruz (animasyonlu)
    transitionDuration: const Duration(milliseconds: 180),
    transitionBuilder: (c, a, s, child) => child,
    pageBuilder: (c, animation, _) => _MessageActionsOverlay(
      animation: animation,
      anchor: anchor,
      preview: preview,
      mine: mine,
      actions: actions,
      emojis: emojis,
      myReaction: myReaction,
    ),
  );
}

/// Emoji için sistem yedeği (Inter emoji içermez).
const _emojiFallback = [
  'Apple Color Emoji',
  'Noto Color Emoji',
  'Segoe UI Emoji'
];

class _MessageActionsOverlay extends StatelessWidget {
  const _MessageActionsOverlay({
    required this.animation,
    required this.anchor,
    required this.preview,
    required this.mine,
    required this.actions,
    required this.emojis,
    required this.myReaction,
  });

  final Animation<double> animation;
  final Rect anchor;
  final Widget preview;
  final bool mine;
  final List<MessageAction> actions;
  final List<String> emojis;
  final String? myReaction;

  static const _barH = 52.0;
  static const _gap = 8.0;
  static const _rowH = 44.0;
  static const _cardPad = 6.0;
  static const _chip = 44.0;
  static const _edge = 12.0;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    // Baloncuk fiziksel olarak sağda mı: giden mesaj sağdan sola düzende solda durur.
    final right = Directionality.of(context) == TextDirection.rtl ? !mine : mine;

    final hasBar = emojis.isNotEmpty;
    final hasCard = actions.isNotEmpty;
    final barBlock = hasBar ? _barH + _gap : 0.0;
    final cardH = hasCard ? actions.length * _rowH + _cardPad * 2 + 2 : 0.0;
    final cardBlock = hasCard ? _gap + cardH : 0.0;

    final topLimit = pad.top + 8;
    final bottomLimit = size.height - pad.bottom - 8;
    final avail = math.max(0.0, bottomLimit - topLimit);
    final maxPreview = math.max(48.0, avail - barBlock - cardBlock);
    final prevH = math.min(anchor.height, maxPreview);
    final total = barBlock + prevH + cardBlock;
    final top = (anchor.top - barBlock)
        .clamp(topLimit, math.max(topLimit, bottomLimit - total))
        .toDouble();

    final prevW = math.min(anchor.width, size.width - _edge * 2);
    final prevLeft = (right ? anchor.right - prevW : anchor.left)
        .clamp(_edge, math.max(_edge, size.width - _edge - prevW))
        .toDouble();

    double clampX(double w, bool alignEnd) =>
        ((alignEnd ? prevLeft + prevW - w : prevLeft))
            .clamp(_edge, math.max(_edge, size.width - _edge - w))
            .toDouble();

    final barW = math.min(emojis.length * _chip + 8.0, size.width - _edge * 2);
    final cardW = math.min(232.0, size.width - _edge * 2);

    final scale = Tween<double>(begin: .86, end: 1)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(animation);
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    final slide =
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);

    void close([String? v]) => Navigator.of(context).pop(v);

    final shadow = [
      BoxShadow(
          color: Colors.black.withValues(alpha: dark ? .25 : .07),
          blurRadius: 12,
          offset: const Offset(0, 3)),
    ];

    // Rota Material/DefaultTextStyle atası taşımaz: olmazsa metinlerin altında sarı çift çizgi çıkar.
    return Material(
      key: const ValueKey('msgActions.root'),
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style:
            BuType.body.copyWith(color: t.ink, decoration: TextDecoration.none),
        child: Stack(children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: fade,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: close,
                child: ColoredBox(
                    color: Colors.black.withValues(alpha: dark ? .6 : .38)),
              ),
            ),
          ),
          // Basılan mesaj: asıl konumundan, sığması için gereken konuma yumuşakça kayar.
          AnimatedBuilder(
            animation: slide,
            builder: (c, child) {
              final previewTop = top + barBlock;
              final y = anchor.top + (previewTop - anchor.top) * slide.value;
              return Positioned(
                  left: prevLeft,
                  top: y,
                  width: prevW,
                  height: prevH,
                  child: child!);
            },
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20), boxShadow: shadow),
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: prevW,
                    maxWidth: prevW,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: preview,
                  ),
                ),
              ),
            ),
          ),
          if (hasBar)
            Positioned(
              left: clampX(barW, right),
              top: top,
              width: barW,
              height: _barH,
              child: FadeTransition(
                opacity: fade,
                child: ScaleTransition(
                  scale: scale,
                  alignment:
                      right ? Alignment.bottomRight : Alignment.bottomLeft,
                  child: Container(
                    key: const ValueKey('msgActions.reactions'),
                    decoration: BoxDecoration(
                      color: t.sf,
                      border: Border.all(color: t.bd),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: shadow,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        for (final e in emojis)
                          _EmojiChip(
                              emoji: e,
                              selected: myReaction == e,
                              onTap: () => close('react:$e')),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          if (hasCard)
            Positioned(
              left: clampX(cardW, right),
              top: top + barBlock + prevH + _gap,
              width: cardW,
              height: cardH,
              child: FadeTransition(
                opacity: fade,
                child: ScaleTransition(
                  scale: scale,
                  alignment: right ? Alignment.topRight : Alignment.topLeft,
                  child: Container(
                    key: const ValueKey('msgActions.card'),
                    padding: const EdgeInsets.symmetric(vertical: _cardPad),
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
                        child: Column(children: [
                          for (var i = 0; i < actions.length; i++)
                            _ActionRow(
                                action: actions[i],
                                first: i == 0,
                                onTap: () => close(actions[i].id)),
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

class _EmojiChip extends StatelessWidget {
  const _EmojiChip(
      {required this.emoji, required this.selected, required this.onTap});

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Tepki $emoji',
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('react-$emoji${selected ? '-on' : ''}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: _MessageActionsOverlay._chip,
          height: _MessageActionsOverlay._chip,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? t.pr.withValues(alpha: .14) : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text(emoji,
              style: BuType.title.copyWith(
                  height: 1.1,
                  decoration: TextDecoration.none,
                  fontFamilyFallback: _emojiFallback)),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow(
      {required this.action, required this.first, required this.onTap});

  final MessageAction action;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final color = action.danger ? t.danger : t.ink;
    return InkWell(
      key: ValueKey('act-${action.id}'),
      onTap: onTap,
      child: Container(
        height: _MessageActionsOverlay._rowH,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
            border: first
                ? null
                : Border(
                    top: BorderSide(
                        color: t.bd.withValues(alpha: .5), width: .5))),
        child: Row(children: [
          Expanded(
            child: Text(action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BuType.body
                    .copyWith(color: color, decoration: TextDecoration.none)),
          ),
          const SizedBox(width: 10),
          Icon(action.icon, size: 16, color: action.danger ? t.danger : t.mut),
        ]),
      ),
    );
  }
}

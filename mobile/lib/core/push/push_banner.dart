import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/bu.dart';
import '../locale_controller.dart' show L10nContext;
import '../nav.dart';

/// Ön plandaki uygulama içi bildirim şeridi: üstten inen ince kart, 4 sn sonra kaybolur;
/// aynı konuşmadan art arda gelenler tek kartta birleşir ("3 yeni mesaj").
class BannerItem {
  BannerItem({required this.key, required this.title, required this.body, required this.data, this.count = 1});
  final String key;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final int count;
}

/// Birleştirme kararı (saf): aynı anahtar ise sayacı artırıp yeni içeriği alır.
BannerItem mergeBanner(BannerItem? current, BannerItem incoming) {
  if (current == null || current.key != incoming.key) return incoming;
  return BannerItem(
      key: incoming.key, title: incoming.title, body: incoming.body, data: incoming.data, count: current.count + 1);
}

/// Birleşme anahtarı: sohbet > hedef türü+kimlik > başlık.
String bannerKey(Map<String, dynamic> data, String title) {
  final c = '${data['conversationId'] ?? ''}';
  if (c.isNotEmpty) return 'conv-$c';
  final t = '${data['targetType'] ?? data['target'] ?? ''}';
  final id = '${data['targetId'] ?? data['value'] ?? ''}';
  if (t.isNotEmpty && id.isNotEmpty) return '$t-$id';
  return 'title-$title';
}

class PushBannerCenter {
  PushBannerCenter({this.duration = const Duration(seconds: 4)});

  static final PushBannerCenter instance = PushBannerCenter();

  final Duration duration;
  final ValueNotifier<BannerItem?> current = ValueNotifier(null);
  OverlayEntry? _entry;
  Timer? _timer;
  void Function(Map<String, dynamic>)? _onTap;

  /// [onTap] kart tıklanınca çağrılır (sohbete git vb.).
  void show(BannerItem item, {required void Function(Map<String, dynamic>) onTap, OverlayState? overlay}) {
    _onTap = onTap;
    current.value = mergeBanner(current.value, item);
    _timer?.cancel();
    _timer = Timer(duration, hide);
    if (_entry == null) {
      final o = overlay ?? rootNavigatorKey.currentState?.overlay;
      if (o == null) {
        current.value = null;
        return;
      }
      _entry = OverlayEntry(builder: (_) => _BannerHost(center: this));
      o.insert(_entry!);
    }
  }

  void hide() {
    _timer?.cancel();
    _timer = null;
    current.value = null;
    _entry?.remove();
    _entry = null;
  }

  void _tap() {
    final d = current.value?.data;
    final cb = _onTap;
    hide();
    if (d != null && cb != null) cb(d);
  }
}

class _BannerHost extends StatelessWidget {
  const _BannerHost({required this.center});
  final PushBannerCenter center;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BannerItem?>(
      valueListenable: center.current,
      builder: (context, item, _) {
        if (item == null) return const SizedBox.shrink();
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: -1, end: 0),
                duration: BuMotion.reduced(context) ? Duration.zero : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (_, v, child) => Transform.translate(offset: Offset(0, v * 40), child: Opacity(opacity: 1 + v, child: child)),
                child: Dismissible(
                  key: const ValueKey('push-banner'),
                  direction: DismissDirection.up,
                  onDismissed: (_) => center.hide(),
                  child: _BannerCard(item: item, onTap: center._tap, onClose: center.hide),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Ön plan bildirim kartı (05/4): avatar, başlık + zaman, gövde, altta birleşmiş mesaj sayısı ve yanıt ipucu.
/// Aynı sohbetten art arda gelenler birleşince kartın altında ikinci bir kart kenarı görünür.
class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.item, required this.onTap, required this.onClose});

  final BannerItem item;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final chat = '${item.data['conversationId'] ?? ''}'.isNotEmpty;
    final merged = item.count > 1;
    final showFooter = merged || chat;
    final card = Material(
      color: t.sf3,
      elevation: 8,
      shadowColor: t.shadow.withValues(alpha: .4),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 4, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          BuAvatar(name: item.title, size: 44),
                          if (chat)
                            PositionedDirectional(
                              end: -2,
                              bottom: -2,
                              child: Container(
                                width: 18,
                                height: 18,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle, border: Border.all(color: t.sf3, width: 2)),
                                child: Icon(LucideIcons.messageCircle, size: 9, color: t.onPr),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (item.title.isNotEmpty)
                              Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(color: t.ink)))
                            else
                              const Spacer(),
                            const SizedBox(width: 8),
                            Text(l.p01PushNow, maxLines: 1, style: tx.labelSmall!.copyWith(color: t.mut)),
                          ],
                        ),
                        if (item.body.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(item.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(color: t.mut)),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l.commonClose,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    icon: Icon(LucideIcons.x, size: 18, color: t.mut),
                    onPressed: onClose,
                  ),
                ],
              ),
              if (showFooter)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 8, end: 10),
                  child: Row(
                    children: [
                      if (merged)
                        Text(l.p01PushMore('${item.count - 1}'),
                            maxLines: 1, style: tx.labelMedium!.copyWith(color: t.pr, fontWeight: FontWeight.w700)),
                      if (chat)
                        Expanded(
                          child: Text(l.p01PushReply,
                              maxLines: 1,
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                              style: tx.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w500)),
                        )
                      else
                        const Spacer(),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (!merged) return card;
    // Birleşmiş kart görünümü: ana kartın altından taşan ikinci kart kenarı.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PositionedDirectional(
          start: 14,
          end: 14,
          bottom: -6,
          child: ExcludeSemantics(
            child: Container(
              height: 20,
              decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(20), boxShadow: BuElevation.of(context, 1)),
            ),
          ),
        ),
        card,
      ],
    );
  }
}

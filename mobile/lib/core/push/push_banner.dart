import 'dart:async';

import 'package:flutter/material.dart';

import '../nav.dart';
import '../theme.dart';

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
        final bu = context.bu;
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: -1, end: 0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (_, v, child) => Transform.translate(offset: Offset(0, v * 40), child: Opacity(opacity: 1 + v, child: child)),
                child: Dismissible(
                  key: const ValueKey('push-banner'),
                  direction: DismissDirection.up,
                  onDismissed: (_) => center.hide(),
                  child: Material(
                    color: bu.sf,
                    elevation: 6,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: center._tap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.title.isNotEmpty)
                                  Text(item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontWeight: FontWeight.w700, color: bu.ink, fontSize: 14)),
                                if (item.body.isNotEmpty)
                                  Text(item.body,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: bu.ink, fontSize: 13)),
                              ],
                            ),
                          ),
                          if (item.count > 1)
                            Container(
                              margin: const EdgeInsetsDirectional.only(start: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: bu.pr, borderRadius: BorderRadius.circular(10)),
                              child: Text('${item.count}',
                                  style: TextStyle(color: bu.onPr, fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

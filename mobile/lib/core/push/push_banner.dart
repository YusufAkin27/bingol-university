import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/bu.dart';
import '../nav.dart';
import 'push_targets.dart';
import 'notification_push_card.dart';

/// Ön plandaki uygulama içi bildirim şeridi: üstten inen ince kart, 4 sn sonra kaybolur;
/// aynı konuşmadan art arda gelenler tek kartta birleşir ("3 yeni mesaj").
class BannerItem {
  BannerItem(
      {required this.key,
      required this.title,
      required this.body,
      required this.data,
      this.count = 1});
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
      key: incoming.key,
      title: incoming.title,
      body: incoming.body,
      data: incoming.data,
      count: current.count + 1);
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

/// Sohbet dışı bildirimin şerit simgesi (hedef türünden): kişi görseli yalnız sohbet için anlamlıdır; etkinlik/haber/anket
/// için kişi silueti yanıltıcı olurdu. Saf fonksiyon (test edilir); bilinmeyen/bozuk yük çan simgesine düşer.
IconData bannerIcon(Map<String, dynamic> data) {
  switch (resolvePushTarget(data).dest) {
    case PushDest.conversation:
    case PushDest.chatList:
      return BuIcons.messageCircle;
    case PushDest.event:
      return BuIcons.calendarDays;
    case PushDest.community:
      return BuIcons.users;
    case PushDest.news:
      return BuIcons.megaphone;
    case PushDest.post:
      return switch ('${data['type'] ?? ''}'.toUpperCase()) {
        'POST_LIKE' => BuIcons.heart,
        'POST_MENTION' => BuIcons.atSign,
        _ => BuIcons.image,
      };
    case PushDest.poll:
      return BuIcons.clipboardList;
    case PushDest.user:
      return BuIcons.user;
    case PushDest.followRequests:
      return BuIcons.userPlus;
    case PushDest.meal:
      return Icons.restaurant;
    case PushDest.accountSecurity:
      return Icons.shield_outlined;
    case PushDest.devices:
      return BuIcons.smartphone;
    case PushDest.ticket:
    case PushDest.feedback:
      return Icons.support_agent;
    case PushDest.timetable:
    case PushDest.exams:
      return BuIcons.graduationCap;
    default:
      return BuIcons.bell;
  }
}

class PushBannerCenter {
  PushBannerCenter({this.duration = const Duration(seconds: 4)});
  static final PushBannerCenter instance = PushBannerCenter();
  final Duration duration;
  final ValueNotifier<BannerItem?> current = ValueNotifier(null);
  final ValueNotifier<List<BannerItem>> items = ValueNotifier(const []);
  final _timers = <String, Timer>{};
  final _open = <String, void Function(Map<String, dynamic>)>{};
  final _actions = <String, void Function(String, Map<String, dynamic>)>{};
  OverlayEntry? _entry;

  void show(
    BannerItem item, {
    required void Function(Map<String, dynamic>) onTap,
    void Function(String action, Map<String, dynamic> data)? onAction,
    OverlayState? overlay,
  }) {
    final previous = items.value.where((e) => e.key == item.key).firstOrNull;
    final merged = mergeBanner(previous, item);
    final next = [merged, ...items.value.where((e) => e.key != item.key)];
    for (final removed in next.skip(3)) {
      _timers.remove(removed.key)?.cancel();
      _open.remove(removed.key);
      _actions.remove(removed.key);
    }
    _open[item.key] = onTap;
    if (onAction != null) _actions[item.key] = onAction;
    items.value = List.unmodifiable(next.take(3));
    current.value = merged;
    _timers.remove(item.key)?.cancel();
    _timers[item.key] = Timer(duration, () => dismiss(item.key));
    if (_entry == null) {
      final host = overlay ?? rootNavigatorKey.currentState?.overlay;
      if (host == null) {
        hide();
        return;
      }
      _entry = OverlayEntry(builder: (_) => _BannerHost(center: this));
      host.insert(_entry!);
    }
  }

  void dismiss(String key) {
    _timers.remove(key)?.cancel();
    _open.remove(key);
    _actions.remove(key);
    items.value = List.unmodifiable(items.value.where((e) => e.key != key));
    current.value = items.value.firstOrNull;
    if (items.value.isEmpty) {
      _entry?.remove();
      _entry = null;
    }
  }

  void hide() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _open.clear();
    _actions.clear();
    items.value = const [];
    current.value = null;
    _entry?.remove();
    _entry = null;
  }

  void tap(BannerItem item) {
    final callback = _open[item.key];
    dismiss(item.key);
    callback?.call(item.data);
  }

  void action(BannerItem item, String action) {
    final callback = _actions[item.key];
    final fallback = _open[item.key];
    dismiss(item.key);
    // "Anladım": yalnız şeridi kapatır; işlev yok, yönlendirme yok.
    if (action == 'ack') return;
    if (callback != null) {
      callback(action, item.data);
    } else {
      fallback?.call(item.data);
    }
  }
}

class _BannerHost extends StatelessWidget {
  const _BannerHost({required this.center});
  final PushBannerCenter center;
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<List<BannerItem>>(
        valueListenable: center.items,
        builder: (context, items, _) {
          if (items.isEmpty) return const SizedBox.shrink();
          return Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                  child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .65),
                  child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final item in items)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Dismissible(
                            key: ValueKey('push-banner-' + item.key),
                            direction: DismissDirection.up,
                            onDismissed: (_) => center.dismiss(item.key),
                            child: NotificationPushCard(
                                title: item.title,
                                body: item.body,
                                data: item.data,
                                compact: items.length > 1,
                                count: item.count,
                                onTap: () => center.tap(item),
                                onClose: () => center.dismiss(item.key),
                                onAction: (action) =>
                                    center.action(item, action)),
                          )),
                  ])),
                ),
              )));
        },
      );
}

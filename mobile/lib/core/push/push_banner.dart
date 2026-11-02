import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/news/news_tile.dart' show newsMonthName;
import '../../widgets/bu.dart';
import '../locale_controller.dart' show L10nContext;
import '../nav.dart';
import 'push_targets.dart';

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
    case PushDest.deptAnnouncement:
      return BuIcons.megaphone;
    case PushDest.post:
      return '${data['type'] ?? ''}'.toUpperCase() == 'POST_LIKE' ? BuIcons.heart : BuIcons.image;
    case PushDest.poll:
      return BuIcons.clipboardList;
    case PushDest.user:
      return BuIcons.user;
    case PushDest.followRequests:
      return BuIcons.userPlus;
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

/// Şerit başı görünümü: sol görsel + sağ eylem hapı (tasarım 08 üst kısım).
enum BannerLead {
  /// Kişi avatarı (sohbet, sosyal): sohbette sağ altta mesaj rozeti.
  avatar,

  /// Etkinlik: tarih karosu (`startsAt` yoksa takvim simgesi).
  dateTile,

  /// Duyuru/haber: megafon karosu.
  megaphone,

  /// Diğer: hedefe uygun simge karosu ([bannerIcon]).
  icon,
}

enum BannerCta { reply, detail, none }

/// Yükten şerit görünümü (SAF; test edilir). Sohbet = avatar + "Yanıtla", etkinlik = tarih karosu + "Detay",
/// duyuru/haber = megafon karosu; bilinmeyen yük simge karosuna düşer.
({BannerLead lead, BannerCta cta}) bannerPresentation(Map<String, dynamic> data) {
  final type = '${data['type'] ?? ''}'.toUpperCase();
  final chat = '${data['conversationId'] ?? ''}'.isNotEmpty || type == 'MESSAGE';
  if (chat) return (lead: BannerLead.avatar, cta: BannerCta.reply);
  final dest = resolvePushTarget(data).dest;
  if (dest == PushDest.event || type == 'EVENT') return (lead: BannerLead.dateTile, cta: BannerCta.detail);
  if (dest == PushDest.news || dest == PushDest.deptAnnouncement || type == 'ANNOUNCEMENT' || type == 'NEWS') {
    return (lead: BannerLead.megaphone, cta: BannerCta.none);
  }
  if ('${data['senderAvatarUrl'] ?? ''}'.isNotEmpty) return (lead: BannerLead.avatar, cta: BannerCta.none);
  return (lead: BannerLead.icon, cta: BannerCta.none);
}

/// Ön plan bildirim kartı (tasarım 08): üstte marka satırı (BU Kampüs · şimdi · kapat), altta görsel + başlık/gövde +
/// eylem hapı. Aynı sohbetten art arda gelenler birleşince kartın altında ikinci bir kart kenarı görünür.
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
    final merged = item.count > 1;
    final pres = bannerPresentation(item.data);
    final cta = switch (pres.cta) {
      BannerCta.reply => l.notifActReply,
      BannerCta.detail => l.notifActDetail,
      BannerCta.none => null,
    };
    final card = Material(
      color: t.sf3,
      elevation: 8,
      shadowColor: t.shadow.withValues(alpha: .4),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 4, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Marka satırı: (B) BU KAMPÜS · şimdi            X
              Row(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle),
                      child: Text('B', style: tx.labelSmall!.copyWith(color: t.onPr, fontSize: 10, fontWeight: FontWeight.w800, height: 1)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(l.notifBrandCaption, maxLines: 1, style: tx.labelSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w700, letterSpacing: .4)),
                  const SizedBox(width: 6),
                  Text('·', style: tx.labelSmall!.copyWith(color: t.mut)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(l.p01PushNow, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelSmall!.copyWith(color: t.mut))),
                  IconButton(
                    tooltip: l.commonClose,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
                    icon: Icon(BuIcons.x, size: 18, color: t.mut),
                    onPressed: onClose,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ExcludeSemantics(child: _BannerLead(item: item, lead: pres.lead)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.title.isNotEmpty)
                            Text(item.title,
                                maxLines: item.body.isEmpty ? 2 : 1, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(color: t.ink)),
                          if (item.body.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(item.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(color: t.mut)),
                            ),
                        ],
                      ),
                    ),
                    if (cta != null) ...[
                      const SizedBox(width: 8),
                      _BannerPill(
                        key: const ValueKey('banner-cta'),
                        label: cta,
                        reply: pres.cta == BannerCta.reply,
                        onTap: onTap,
                      ),
                    ],
                  ],
                ),
              ),
              if (merged)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 8, end: 10),
                  child: Text(l.p01PushMore('${item.count - 1}'),
                      maxLines: 1, style: tx.labelMedium!.copyWith(color: t.pr, fontWeight: FontWeight.w700)),
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

/// Şerit eylem hapı: sohbette açık zeminli "Yanıtla" (ok simgesi), etkinlikte koyu "Detay".
class _BannerPill extends StatelessWidget {
  const _BannerPill({super.key, required this.label, required this.reply, required this.onTap});

  final String label;
  final bool reply;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final bg = reply ? t.sf2 : t.ink;
    final fg = reply ? t.ink : t.bg;
    return Semantics(
      button: true,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(BuRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(BuRadius.pill),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (reply) ...[Icon(BuIcons.reply, size: 14, color: fg), const SizedBox(width: 6)],
                  Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelLarge!.copyWith(color: fg, fontWeight: FontWeight.w700))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerLead extends StatelessWidget {
  const _BannerLead({required this.item, required this.lead});

  final BannerItem item;
  final BannerLead lead;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    switch (lead) {
      case BannerLead.avatar:
        final chat = '${item.data['conversationId'] ?? ''}'.isNotEmpty;
        final url = '${item.data['senderAvatarUrl'] ?? ''}';
        return SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              BuAvatar(name: item.title, url: url.isEmpty ? null : url, size: 46),
              if (chat)
                PositionedDirectional(
                  end: -2,
                  bottom: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle, border: Border.all(color: t.sf3, width: 2)),
                    child: Icon(BuIcons.messageCircle, size: 9, color: t.onPr),
                  ),
                ),
            ],
          ),
        );
      case BannerLead.dateTile:
        final d = DateTime.tryParse('${item.data['startsAt'] ?? item.data['eventStartsAt'] ?? ''}')?.toLocal();
        if (d == null) return _tile(t, BuIcons.calendarDays);
        final month = trUpper(newsMonthName(context, d.month));
        return Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(14)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(month.length > 3 ? month.substring(0, 3) : month,
                  maxLines: 1, style: BuType.caption.copyWith(fontSize: 10, height: 1.1, fontWeight: FontWeight.w700, color: t.onSoft)),
              Text('${d.day}', maxLines: 1, style: BuType.caption.copyWith(fontSize: 18, height: 1.1, fontWeight: FontWeight.w800, color: t.onSoft)),
            ],
          ),
        );
      case BannerLead.megaphone:
        return _tile(t, BuIcons.megaphone);
      case BannerLead.icon:
        return _tile(t, bannerIcon(item.data));
    }
  }

  Widget _tile(BuTokens t, IconData icon) => Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, size: 22, color: t.onSoft),
      );
}

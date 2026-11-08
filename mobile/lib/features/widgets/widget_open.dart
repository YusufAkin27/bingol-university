import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/nav.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../academic/academic_calendar_page.dart';
import '../academic/exams_page.dart';
import '../academic/timetable_page.dart';
import '../clubs/club_detail_page.dart';
import '../events/events_page.dart';
import '../menu/menu_page.dart';
import '../news/news_list_page.dart';
import '../notifications/notifications_page.dart';
import '../polls/poll_detail_page.dart';
import '../search/search_page.dart';
import '../share/share_models.dart';
import '../share/share_open.dart';
import '../shell/app_shell.dart' show AppTab;
import 'widget_link.dart';

/// Ana ekran widget'ından gelen bağlantıyı uygulamada açar (soğuk ve sıcak açılış aynı yoldan: `ShareLinkHost`).
/// Önce açık rotalar kapanır (widget dokunuşu temiz bir bağlamdır), sonra sekme değişir ya da sayfa açılır. Hata
/// çökme değil, anlaşılır bir bildirimdir.
Future<void> openWidgetLink(BuildContext context, Session session, WidgetLink link) async {
  try {
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst);
    void push(Widget page, String name) =>
        nav.push(MaterialPageRoute<void>(settings: RouteSettings(name: name), builder: (_) => page));
    switch (link.dest) {
      case WidgetDest.home:
        shellTabRequest.value = AppTab.home;
      case WidgetDest.discover:
        shellTabRequest.value = AppTab.discover;
      case WidgetDest.chat:
        shellTabRequest.value = AppTab.chat;
      case WidgetDest.clubs:
        shellTabRequest.value = AppTab.clubs;
      case WidgetDest.menu:
        push(MenuPage(session: session), 'menu');
      case WidgetDest.timetable:
        push(TimetablePage(session: session), 'timetable');
      case WidgetDest.exams:
        push(ExamsPage(session: session), 'exams');
      case WidgetDest.academic:
        push(AcademicCalendarPage(session: session), 'academic_calendar');
      case WidgetDest.events:
        push(EventsPage(session: session), 'events');
      case WidgetDest.qr:
        // "QR Kodum": biletlerin/QR'ın bulunduğu Etkinliklerim sekmesi.
        push(EventsPage(session: session, initialTab: 1), 'events');
      case WidgetDest.news:
        push(NewsListPage(session: session), 'news_list');
      case WidgetDest.search:
        push(SearchPage(session: session), 'search');
      case WidgetDest.notifications:
        push(NotificationsPage(session: session), 'notifications');
      case WidgetDest.event:
        await openShared(context, session, ShareTarget(ShareType.event, link.id!));
      case WidgetDest.club:
        push(ClubDetailPage(session: session, communityId: link.id!), 'club_detail');
      case WidgetDest.newsItem:
        await openShared(context, session, ShareTarget(ShareType.news, link.id!));
      case WidgetDest.poll:
        await showModalBottomSheet<void>(
          context: context,
          useRootNavigator: true,
          useSafeArea: true,
          isScrollControlled: true,
          showDragHandle: true,
          clipBehavior: Clip.antiAlias,
          builder: (_) => FractionallySizedBox(heightFactor: .9, child: PollDetailPage(session: session, pollId: link.id!)),
        );
    }
  } catch (_) {
    if (context.mounted) BuToast.show(context, context.l10n.shareNotFoundTitle, kind: BuToastKind.error);
  }
}

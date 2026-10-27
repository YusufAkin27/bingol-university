import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../events/events_page.dart';

/// Etkinliklerim: Etkinlikler sayfasının "Etkinliklerim" sekmesine açılan ince sarmalayıcı
/// (liste, "Katılımdan ayrıl" ve sayfalama tek yerde: `EventsPage`).
class MyEventsPage extends StatelessWidget {
  const MyEventsPage({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) => EventsPage(session: session, initialTab: 1);
}

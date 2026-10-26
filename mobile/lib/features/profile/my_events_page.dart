import 'package:flutter/material.dart';

import '../../core/theme.dart';

import '../../core/session.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../events/event_detail_page.dart';
import 'profile_paged_list.dart';

/// Katıldığım / ilgilendiğim etkinlikler (GET /me/events).
class MyEventsPage extends StatelessWidget {
  const MyEventsPage({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return ProfilePagedList(
      session: session,
      title: 'Etkinliklerim',
      path: '/me/events',
      emptyIcon: LucideIcons.calendar,
      emptyText: 'Henüz bir etkinliğe katılmadınız.',
      itemBuilder: (context, e) {
        final t = context.bu;
        final rsvp = e['myRsvp'];
        final rsvpText = rsvp == 'GOING' ? 'Katılıyorum' : (rsvp == 'INTERESTED' ? 'İlgileniyorum' : null);
        final loc = (e['location'] as String?) ?? '';
        return BuCard(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventDetailPage(session: session, eventId: (e['id'] as num).toInt()),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(16)),
                child: Icon(LucideIcons.calendar, size: 24, color: t.onSoft),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((e['title'] as String?) ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: t.ink)),
                    const SizedBox(height: 3),
                    Text(
                      [niceDate(e['startsAt'] as String?), if (loc.isNotEmpty) loc].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: t.mut),
                    ),
                  ],
                ),
              ),
              if (rsvpText != null) BuBadge(rsvpText, soft: true),
            ],
          ),
        );
      },
    );
  }
}

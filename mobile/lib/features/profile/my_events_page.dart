import 'package:flutter/material.dart';

import '../../core/theme.dart';

import '../../core/session.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../events/event_detail_page.dart';
import 'profile_paged_list.dart';

/// Etkinliklerim: yaklaşan (GET /me/events?mode=attending) ve düzenlediklerim (mode=organizing).
/// Sunucu "attending" modunda yalnızca bitmemiş etkinlikleri döndürür; geçmiş olanlar
/// düzenlediklerim listesinde "Geçmiş" rozetiyle ayrışır.
class MyEventsPage extends StatefulWidget {
  const MyEventsPage({super.key, required this.session});

  final Session session;

  @override
  State<MyEventsPage> createState() => _MyEventsPageState();
}

class _MyEventsPageState extends State<MyEventsPage> {
  bool _organizing = false;

  void _set(bool organizing) {
    if (_organizing != organizing) setState(() => _organizing = organizing);
  }

  static bool _isPast(Map<String, dynamic> e) {
    final end = DateTime.tryParse((e['endsAt'] ?? e['startsAt']) as String? ?? '');
    return end != null && end.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return ProfilePagedList(
      session: widget.session,
      title: 'Etkinliklerim',
      path: '/me/events?mode=${_organizing ? 'organizing' : 'attending'}',
      emptyIcon: LucideIcons.calendar,
      emptyText: _organizing ? 'Henüz bir etkinlik düzenlemediniz.' : 'Yaklaşan bir etkinliğiniz yok.',
      header: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        // Wrap: 320 px genişlikte iki çip yan yana sığmazsa alta iner.
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            BuChip(label: 'Yaklaşan', selected: !_organizing, onTap: () => _set(false)),
            BuChip(label: 'Düzenlediklerim', selected: _organizing, onTap: () => _set(true)),
          ],
        ),
      ),
      itemBuilder: (context, e) => _EventCard(session: widget.session, event: e, past: _isPast(e)),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.session, required this.event, required this.past});

  final Session session;
  final Map<String, dynamic> event;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final rsvp = event['myRsvp'];
    final badge = past
        ? 'Geçmiş'
        : rsvp == 'GOING'
            ? 'Katılıyorum'
            : (rsvp == 'INTERESTED' ? 'İlgileniyorum' : null);
    final loc = (event['location'] as String?) ?? '';
    return BuCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailPage(session: session, eventId: (event['id'] as num).toInt()),
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
                Text((event['title'] as String?) ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: t.ink)),
                const SizedBox(height: 3),
                Text(
                  [niceDate(event['startsAt'] as String?), if (loc.isNotEmpty) loc].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: t.mut),
                ),
                // Dar ekranda satırı taşırmamak için rozet başlığın altında durur.
                if (badge != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: BuBadge(badge, soft: !past),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

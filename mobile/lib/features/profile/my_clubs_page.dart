import 'package:flutter/material.dart';

import '../../core/theme.dart';

import '../../core/session.dart';
import '../../widgets/bu_widgets.dart';
import '../clubs/club_detail_page.dart';
import 'profile_paged_list.dart';

/// Üyesi olunan topluluklar (GET /me/communities).
class MyClubsPage extends StatelessWidget {
  const MyClubsPage({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return ProfilePagedList(
      session: session,
      title: 'Kulüplerim',
      path: '/me/communities',
      emptyIcon: LucideIcons.users,
      emptyText: 'Henüz bir kulübe üye değilsiniz.',
      itemBuilder: (context, c) {
        final t = context.bu;
        final members = (c['memberCount'] as num?)?.toInt();
        final sub = [
          if ((c['category'] as String?)?.isNotEmpty == true) c['category'] as String,
          if (members != null) '$members üye',
        ].join(' · ');
        final pending = c['myStatus'] == 'PENDING';
        return BuCard(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClubDetailPage(session: session, communityId: (c['id'] as num).toInt()),
            ),
          ),
          child: Row(
            children: [
              BuAvatar(name: c['name'] as String?, url: c['coverUrl'] as String?, size: 52, square: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((c['name'] as String?) ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: t.ink)),
                    if (sub.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(sub, style: TextStyle(fontSize: 12, color: t.mut)),
                      ),
                    // Dar ekranda satırı taşırmamak için rozet adın altında durur.
                    if (pending)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: BuBadge('Onay bekliyor', soft: true),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(LucideIcons.chevronRight, size: 18, color: t.mut),
            ],
          ),
        );
      },
    );
  }
}

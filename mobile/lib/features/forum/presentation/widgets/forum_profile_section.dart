import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../core/session.dart';
import '../../../../widgets/bu.dart';
import '../../../profile/profil_widgets.dart';
import '../../data/forum_api.dart';
import '../../data/forum_models.dart';
import '../pages/forum_activity_page.dart';

/// Başkasının profilinde "Forum" bölümü: yalnız herkese açık (anonim olmayan) konu ve yorum sayıları.
/// Sayaçlar alınamazsa ya da ikisi de sıfırsa bölüm HİÇ çizilmez (profil sessizce aynı kalır). Gizli hesap /
/// engel durumunda profil sayfası bu bölümü zaten kurmaz; sunucu da bu durumlarda içerik vermez.
class ForumProfileSection extends StatefulWidget {
  const ForumProfileSection({super.key, required this.session, required this.userId, this.name});

  final Session session;
  final int userId;
  final String? name;

  @override
  State<ForumProfileSection> createState() => _ForumProfileSectionState();
}

class _ForumProfileSectionState extends State<ForumProfileSection> {
  ForumUserSummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ForumProfileSection old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId) {
      _summary = null;
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.userId;
    try {
      final s = await ForumApi(widget.session).userSummary(id);
      if (mounted && id == widget.userId) setState(() => _summary = s);
    } catch (_) {
      // Forum bölümü isteğe bağlıdır: hata profili bozmaz.
    }
  }

  void _open(int tab) => Navigator.of(context).push<void>(MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'forum_user_activity'),
        builder: (_) => ForumUserActivityPage(session: widget.session, userId: widget.userId, name: widget.name, initialTab: tab),
      ));

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    if (s == null || (s.topicCount <= 0 && s.commentCount <= 0)) return const SizedBox.shrink();
    final l = context.l10n;
    return Column(
      key: const ValueKey('forum-profile-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        ProfilSection(l.forumActivitySection, top: 0),
        ProfilCard(children: [
          if (s.topicCount > 0)
            ProfilRow(
              key: const ValueKey('forum-profile-topics'),
              icon: BuIcons.messageSquareText,
              label: l.forumActivityTabTopicsPublic,
              value: '${s.topicCount}',
              onTap: () => _open(0),
            ),
          if (s.commentCount > 0)
            ProfilRow(
              key: const ValueKey('forum-profile-comments'),
              icon: BuIcons.messageCircle,
              label: l.forumActivityTabCommentsPublic,
              value: '${s.commentCount}',
              onTap: () => _open(1),
            ),
        ]),
      ],
    );
  }
}

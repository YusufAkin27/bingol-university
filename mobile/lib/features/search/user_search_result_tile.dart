import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/profile_photo_viewer.dart';
import '../follow/follow_widgets.dart' show FollowRowButton;
import '../posts/post_models.dart' show postAuthHeaders;
import '../posts/social_models.dart' show FollowState, followStateOf;
import '../profile/user_profile_page.dart';
import 'search_fold.dart';

/// Kullanıcı arama sonucu (`GET /api/users/search` öğesi). @kullaniciadi YOK: sunucuda kullanıcı adı alanı yoktur,
/// satırda yalnız ad soyad + bölüm/sınıf gösterilir.
class SearchUser {
  const SearchUser({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.faculty,
    this.department,
    this.classYear,
    this.followState = FollowState.none,
    this.isPrivate = false,
  });

  /// Tüm alanlar null-güvenli; `followState` yoksa eski `followedByMe` bayrağından türetilir.
  factory SearchUser.fromJson(Map<dynamic, dynamic> j) {
    final fs = j['followState'];
    final state = fs is String ? followStateOf(fs) : (j['followedByMe'] == true ? FollowState.following : FollowState.none);
    final cy = j['classYear'];
    return SearchUser(
      id: (j['id'] as num).toInt(),
      name: '${j['displayName'] ?? ''}'.trim(),
      avatarUrl: (j['avatarUrl'] is String && (j['avatarUrl'] as String).isNotEmpty) ? j['avatarUrl'] as String : null,
      faculty: j['faculty'] as String?,
      department: j['department'] as String?,
      classYear: cy is num ? cy.toInt() : null,
      followState: state,
      isPrivate: j['isPrivate'] == true,
    );
  }

  final int id;
  final String name;
  final String? avatarUrl;
  final String? faculty;
  final String? department;
  final int? classYear;
  final FollowState followState;
  final bool isPrivate;

  /// "Bilgisayar Mühendisliği · 2. sınıf" (bölüm yoksa fakülte; ikisi de yoksa boş).
  String subtitle(BuildContext context) {
    final l = context.l10n;
    final dept = (department ?? '').trim();
    final fac = (faculty ?? '').trim();
    final place = dept.isNotEmpty ? context.departmentName(dept, faculty: faculty) : (fac.isNotEmpty ? context.facultyName(fac) : '');
    return [if (place.isNotEmpty) place, if (classYear != null && classYear! > 0) l.searchClassYear('$classYear')].join(' · ');
  }
}

/// Arama sonucu kullanıcı satırı: avatar (uzun basma = blur önizleme), ad soyad (eşleşme vurgulu), bölüm/sınıf,
/// takip düğmesi (kendisi değilse). Satıra dokunma = profil ([onOpen] verilmezse `openUserProfile`).
class UserSearchResultTile extends StatelessWidget {
  const UserSearchResultTile({
    super.key,
    required this.session,
    required this.user,
    this.query = '',
    this.onOpen,
  });

  final Session session;
  final SearchUser user;

  /// Vurgulanacak arama metni.
  final String query;

  /// Profil açılmadan hemen önce (örn. arama geçmişine yazmak için).
  final VoidCallback? onOpen;

  void _open(BuildContext context) {
    onOpen?.call();
    openUserProfile(context, session, userId: user.id, name: user.name, avatarUrl: user.avatarUrl);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final self = user.id == session.userId || user.followState == FollowState.self;
    final sub = user.subtitle(context);
    final name = user.name.isEmpty ? l.searchUserDefault : user.name;
    return Semantics(
      container: true,
      label: l.srOpenProfileOf(name),
      child: InkWell(
        key: ValueKey('user-search-${user.id}'),
        onTap: () => _open(context),
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 12, 10),
          child: Row(children: [
            AvatarLongPress(
              key: ValueKey('user-search-avatar-${user.id}'),
              imageUrl: user.avatarUrl,
              headers: postAuthHeaders(session),
              title: name,
              child: BuAvatar(name: name, url: user.avatarUrl, size: 48, headers: postAuthHeaders(session)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Flexible(
                    child: Text.rich(
                      searchHighlight(context, name, query, tx.titleMedium!.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: t.ink)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (user.isPrivate) ...[
                    const SizedBox(width: 6),
                    Semantics(label: l.srPrivateAccount, child: Icon(BuIcons.lock, size: 14, color: t.mut)),
                  ],
                ]),
                if (sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.mut)),
                  ),
              ]),
            ),
            if (!self)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: FollowRowButton(session: session, userId: user.id, state: user.followState, isPrivate: user.isPrivate),
              ),
          ]),
        ),
      ),
    );
  }
}

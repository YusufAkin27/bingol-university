import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/profile_photo_viewer.dart';
import '../posts/post_models.dart' show postAuthHeaders;
import '../posts/social_models.dart';
import '../profile/user_profile_page.dart';
import 'follow_button.dart';
import '../../core/academic_catalog.dart';

/// Takip listeleri / öneriler (Stitch 48) ortak parçaları: sekme hapı, tek beyaz kart, kişi satırı,
/// durum kartları, "Takip et / Takipte" düğmesi.

/// Satırın altındaki durum satırı türü.
enum FollowRelation { none, followsYou, mutual, following }

/// Takipçiler | Takip edilenler: düz iki sekme (Stitch v3); seçili ink 15/600 + 2 dp marka alt çizgisi, sayı kırmızı hap
/// DEĞİL, aynı satırda mut 13. Altta 1 dp bd çizgisi.
class FollowTabs extends StatelessWidget {
  const FollowTabs({super.key, required this.labels, required this.counts, required this.index, required this.onChanged});

  final List<String> labels;
  final List<int?> counts;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++) Expanded(child: _tab(context, i)),
      ]),
    );
  }

  Widget _tab(BuildContext context, int i) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final sel = i == index;
    final n = counts[i];
    return Semantics(
      button: true,
      selected: sel,
      inMutuallyExclusiveGroup: true,
      label: n == null ? labels[i] : '${labels[i]} $n',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!sel) buHaptic(BuHaptic.selection);
          onChanged(i);
        },
        child: AnimatedContainer(
          duration: BuMotion.of(context, BuMotion.short),
          curve: BuMotion.standard,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: sel ? t.pr : Colors.transparent, width: 2)),
          ),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: Text(labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: tx.labelLarge!.copyWith(fontSize: 15, fontWeight: sel ? FontWeight.w400 : FontWeight.w400, color: sel ? t.ink : t.mut)),
            ),
            if (n != null) ...[
              const SizedBox(width: 6),
              Text('$n', style: tx.labelMedium!.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: t.mut)),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Liste üstündeki küçük büyük harfli başlık ("TÜM TAKİPÇİLER (128)").
class FollowSectionLabel extends StatelessWidget {
  const FollowSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 8),
        child: Semantics(
          header: true,
          child: Text(trUpper(text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium!
                  .copyWith(fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: .8, color: context.bu.mut)),
        ),
      );
}

/// Satırları tek beyaz kartta toplayan sarmalayıcı (aralarında ince ayırıcı).
class FollowCard extends StatelessWidget {
  const FollowCard({super.key, required this.children, this.dividerIndent = 72});

  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return BuCard(
      padding: EdgeInsets.zero,
      radius: 24,
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, indent: dividerIndent, endIndent: 16, color: t.bd),
          children[i],
        ],
      ]),
    );
  }
}

/// Kişi satırı: avatar, ad, bölüm (· sınıf), isteğe bağlı durum satırı / neden satırı, sağda düğme.
class FollowPersonRow extends StatelessWidget {
  const FollowPersonRow({
    super.key,
    required this.session,
    required this.user,
    this.relation = FollowRelation.none,
    this.classLabel,
    this.reason,
    this.showButton = true,
  });

  final Session session;
  final SocialUser user;
  final FollowRelation relation;

  /// "3. Sınıf" gibi; yoksa yalnız bölüm yazılır.
  final String? classLabel;

  /// Öneri nedeni (örn. "Aynı bölümden 14 ortak..."); yoksa satır çizilmez.
  final String? reason;
  final bool showButton;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final dept = context.departmentName((user.department ?? '').trim());
    final sub = [if (dept.isNotEmpty) dept, if ((classLabel ?? '').isNotEmpty) classLabel!].join(' · ');
    final self = user.id == session.userId;

    Widget? status;
    switch (relation) {
      case FollowRelation.followsYou:
        status = _statusLine(context, const SizedBox.shrink(), l.profilyardFollowsYou, t.mut);
      case FollowRelation.mutual:
        status = _statusLine(context, Icon(BuIcons.repeat2, size: 14, color: t.mut), l.profilyardFollowMutual, t.mut);
      case FollowRelation.following:
        status = _statusLine(context, Icon(BuIcons.check, size: 14, color: t.mut), l.profilyardFollowingYou, t.mut);
      case FollowRelation.none:
        status = null;
    }
    if (reason != null && reason!.isNotEmpty) {
      status = Row(children: [
        Icon(BuIcons.users, size: 14, color: t.mut),
        const SizedBox(width: 5),
        Expanded(
          child: Text(reason!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w400, color: t.mut)),
        ),
      ]);
    }

    return Semantics(
      container: true,
      label: user.displayName,
      child: InkWell(
        onTap: () => openUserProfile(context, session, userId: user.id, name: user.displayName, avatarUrl: user.avatarUrl),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
          child: Row(children: [
            AvatarLongPress(
              imageUrl: user.avatarUrl,
              headers: postAuthHeaders(session),
              title: user.displayName,
              child: BuAvatar(name: user.displayName, url: user.avatarUrl, size: 44, headers: postAuthHeaders(session)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tx.titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w400, color: t.ink)),
                if (sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tx.bodyMedium!.copyWith(fontSize: 13, color: t.mut)),
                  ),
                if (status != null) Padding(padding: const EdgeInsets.only(top: 3), child: status),
              ]),
            ),
            if (showButton && !self && user.followState != FollowState.self)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 10),
                child: FollowRowButton(session: session, userId: user.id, state: user.followState, isPrivate: user.isPrivate),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _statusLine(BuildContext context, Widget lead, String text, Color color) => Row(children: [
        if (lead is! SizedBox) ...[ExcludeSemantics(child: lead), const SizedBox(width: 6)],
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium!.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: color)),
        ),
      ]);
}

/// Liste satırı takip düğmesi: üç durumlu ([FollowStateButton], görünüm `row`). Eski çağrılar `followed` verir;
/// `state` verilirse o geçerlidir (gizli hesapta "İstek gönderildi").
class FollowRowButton extends StatelessWidget {
  const FollowRowButton({
    super.key,
    required this.session,
    required this.userId,
    this.followed = false,
    this.state,
    this.isPrivate = false,
    this.onChanged,
  });

  final Session session;
  final int userId;
  final bool followed;
  final FollowState? state;
  final bool isPrivate;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => FollowStateButton(
        session: session,
        userId: userId,
        state: state ?? (followed ? FollowState.following : FollowState.none),
        isPrivate: isPrivate,
        look: FollowLook.row,
        onChanged: onChanged,
      );
}

/// Boş / hata kartı: dairesel simge, başlık, açıklama (+ "Yeniden dene").
class FollowStatusCard extends StatelessWidget {
  const FollowStatusCard({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.error = false,
    this.onRetry,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  /// Boş durumdaki ikincil eylem (örn. "Aramayı temizle").
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  final IconData icon;
  final String title;
  final String? message;
  final bool error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final circle = Container(
      width: error ? 48 : 64,
      height: error ? 48 : 64,
      decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
      child: Icon(icon, size: error ? 22 : 28, color: t.onSoft),
    );
    if (error) {
      return BuCard(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          ExcludeSemantics(child: circle),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w400, color: t.ink)),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(message!, maxLines: 3, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
                ),
            ]),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 10),
            BuButton(label: context.l10n.profileRetry, icon: BuIcons.refreshCw, compact: true, onPressed: onRetry),
          ],
        ]),
      );
    }
    return SizedBox(
        width: double.infinity,
        child: BuCard(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ExcludeSemantics(child: circle),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: Text(title, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w400, color: t.ink)),
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(message!, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.45)),
          ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          BuButton(key: const ValueKey('follow-action'), label: actionLabel!, icon: actionIcon, kind: BuButtonKind.soft, compact: true, onPressed: onAction),
        ],
      ]),
    ));
  }
}

/// Satır iskeleti (avatar + iki çizgi + düğme) tek kartta.
class FollowSkeletonCard extends StatelessWidget {
  const FollowSkeletonCard({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) => BuSkeletonScope(
        child: FollowCard(children: [
          for (var i = 0; i < count; i++)
            const Padding(
              padding: EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
              child: Row(children: [
                BuSkeleton.circle(44),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    BuSkeleton.line(width: 120, height: 14),
                    SizedBox(height: 8),
                    BuSkeleton.line(width: 160),
                    SizedBox(height: 6),
                    BuSkeleton.line(width: 90, height: 10),
                  ]),
                ),
                SizedBox(width: 12),
                BuSkeleton(width: 76, height: 40, radius: 14),
              ]),
            ),
        ]),
      );
}

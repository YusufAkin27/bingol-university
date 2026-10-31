import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../posts/post_models.dart' show postAuthHeaders;
import '../posts/social_api.dart';
import '../posts/social_models.dart';
import '../profile/user_profile_page.dart';
import '../../core/academic_catalog.dart';

/// Takip listeleri / öneriler (Stitch 48) ortak parçaları: sekme hapı, tek beyaz kart, kişi satırı,
/// durum kartları, "Takip et / Takipte" düğmesi.

/// Satırın altındaki durum satırı türü.
enum FollowRelation { none, followsYou, mutual, following }

/// Takipçiler | Takip edilenler sekmesi: gri hap kutu, seçili parça beyaz, sayaç rozeti (seçiliyken kırmızı).
class FollowTabs extends StatelessWidget {
  const FollowTabs({super.key, required this.labels, required this.counts, required this.index, required this.onChanged});

  final List<String> labels;
  final List<int?> counts;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.md), border: Border.all(color: t.bd)),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(child: _tab(context, i)),
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
        onTap: () => onChanged(i),
        child: AnimatedContainer(
          duration: BuMotion.of(context, BuMotion.short),
          curve: BuMotion.standard,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? t.sf : Colors.transparent,
            borderRadius: BorderRadius.circular(BuRadius.sm),
            boxShadow: sel ? BuElevation.of(context, 1) : const [],
          ),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: Text(labels[i],
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: sel ? t.ink : t.mut)),
            ),
            if (n != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(color: sel ? t.soft : t.bd, borderRadius: BuRadius.bPill),
                child: Text('$n',
                    style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: sel ? t.onSoft : t.ink)),
              ),
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
                  .copyWith(fontWeight: FontWeight.w700, letterSpacing: .4, color: context.bu.mut)),
        ),
      );
}

/// Satırları tek beyaz kartta toplayan sarmalayıcı (aralarında ince ayırıcı).
class FollowCard extends StatelessWidget {
  const FollowCard({super.key, required this.children, this.dividerIndent = 76});

  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return BuCard(
      padding: EdgeInsets.zero,
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
        status = _statusLine(context, Icon(LucideIcons.repeat2, size: 13, color: t.mut), l.profilyardFollowMutual, t.mut);
      case FollowRelation.following:
        status = _statusLine(context, Icon(LucideIcons.check, size: 13, color: t.mut), l.profilyardFollowingYou, t.mut);
      case FollowRelation.none:
        status = null;
    }
    if (reason != null && reason!.isNotEmpty) {
      status = Row(children: [
        Icon(LucideIcons.users, size: 13, color: t.mut),
        const SizedBox(width: 5),
        Expanded(
          child: Text(reason!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w600, color: t.mut)),
        ),
      ]);
    }

    return Semantics(
      container: true,
      label: user.displayName,
      child: InkWell(
        onTap: () => openUserProfile(context, session, userId: user.id, name: user.displayName, avatarUrl: user.avatarUrl),
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
          child: Row(children: [
            BuAvatar(name: user.displayName, url: user.avatarUrl, size: 48, headers: postAuthHeaders(session)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                if (sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tx.bodyMedium!.copyWith(color: t.mut)),
                  ),
                if (status != null) Padding(padding: const EdgeInsets.only(top: 3), child: status),
              ]),
            ),
            if (showButton && !self)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 10),
                child: FollowRowButton(session: session, userId: user.id, followed: user.followedByMe),
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
              style: Theme.of(context).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w600, color: color)),
        ),
      ]);
}

/// "Takip et" (soluk marka zemini; listede dolgulu kırmızı düğme yığılmaz) / "Takipte" (çizgili, sakin) düğmesi; iyimser günceller, hata olursa geri alır.
class FollowRowButton extends StatefulWidget {
  const FollowRowButton({super.key, required this.session, required this.userId, required this.followed, this.onChanged});

  final Session session;
  final int userId;
  final bool followed;
  final ValueChanged<bool>? onChanged;

  @override
  State<FollowRowButton> createState() => _FollowRowButtonState();
}

class _FollowRowButtonState extends State<FollowRowButton> {
  late bool _followed = widget.followed;
  bool _busy = false;

  @override
  void didUpdateWidget(FollowRowButton old) {
    super.didUpdateWidget(old);
    if (old.followed != widget.followed && !_busy) _followed = widget.followed;
  }

  Future<void> _toggle() async {
    if (_busy) return;
    final want = !_followed;
    buHaptic(want ? BuHaptic.light : BuHaptic.selection);
    setState(() {
      _busy = true;
      _followed = want;
    });
    widget.onChanged?.call(want);
    final api = SocialApi(widget.session);
    try {
      await (want ? api.follow(widget.userId) : api.unfollow(widget.userId));
    } catch (e) {
      if (mounted) {
        setState(() => _followed = !want);
        BuToast.show(context, errorText(e), kind: BuToastKind.error);
      }
      widget.onChanged?.call(!want);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final on = !_followed;
    return Semantics(
      button: true,
      toggled: _followed,
      label: _followed ? l.followButtonUnfollow : l.followButtonFollow,
      excludeSemantics: true,
      child: AnimatedContainer(
        key: const ValueKey('followButton'),
        duration: BuMotion.of(context, BuMotion.short),
        curve: BuMotion.standard,
        decoration: BoxDecoration(
            color: on ? t.soft : Colors.transparent,
            border: Border.all(color: on ? Colors.transparent : t.bd),
            borderRadius: BorderRadius.circular(BuRadius.sm + 2)),
        child: InkWell(
          borderRadius: BorderRadius.circular(BuRadius.sm + 2),
          onTap: _busy ? null : _toggle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 76),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                widthFactor: 1,
                child: Text(_followed ? l.followButtonFollowing : l.followButtonFollow,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge!
                        .copyWith(fontWeight: FontWeight.w700, color: on ? t.onSoft : t.mut)),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(message!, maxLines: 3, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
                ),
            ]),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 10),
            BuButton(label: context.l10n.profileRetry, icon: LucideIcons.refreshCw, compact: true, onPressed: onRetry),
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
          child: Text(title, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
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
                BuSkeleton.circle(48),
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

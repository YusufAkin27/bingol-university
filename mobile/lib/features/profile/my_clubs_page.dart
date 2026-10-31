import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart' show relativeTime;
import '../clubs/club_actions.dart';
import '../clubs/club_detail_page.dart';
import '../clubs/club_form_page.dart';
import '../clubs/club_members_page.dart';
import '../clubs/club_ref_widgets.dart';
import '../clubs/club_requests_page.dart';
import '../clubs/clubs_tab.dart';

/// Kulüplerim (GET /me/communities): kurduklarım / üye olduklarım / bekleyen başvurular (referans 30-01..03).
class MyClubsPage extends StatefulWidget {
  const MyClubsPage({super.key, required this.session});

  final Session session;

  @override
  State<MyClubsPage> createState() => _MyClubsPageState();
}

class _MyClubsPageState extends State<MyClubsPage> {
  final _items = <Map<String, dynamic>>[];
  bool _loading = true;
  Object? _error;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Tüm sayfaları (en çok 10) çeker: bölümlere ayırmak için liste bütün olmalı.
  Future<void> _load({bool silent = false}) async {
    final gen = ++_gen;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final all = <Map<String, dynamic>>[];
      int? cursor;
      for (var page = 0; page < 10; page++) {
        final c = cursor == null ? '' : '&cursor=$cursor';
        final r = await widget.session.api.get('/me/communities?size=20$c') as Map;
        all.addAll((r['items'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
        cursor = (r['nextCursor'] as num?)?.toInt();
        if (cursor == null) break;
      }
      if (!mounted || gen != _gen) return;
      setState(() {
        _items
          ..clear()
          ..addAll(all);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted && gen == _gen) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  void _snack(String m) => BuToast.show(context, m, kind: BuToastKind.error);

  int _id(Map<String, dynamic> c) => (c['id'] as num).toInt();

  Future<void> _open(Map<String, dynamic> c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClubDetailPage(session: widget.session, communityId: _id(c))),
    );
    if (mounted) _load(silent: true);
  }

  Future<void> _leave(Map<String, dynamic> c) async {
    final left = await leaveClubFlow(
      context,
      widget.session,
      communityId: _id(c),
      clubName: (c['name'] ?? '').toString(),
      isOwner: c['myRole'] == 'OWNER',
    );
    if (left && mounted) {
      setState(() => _items.remove(c));
      BuToast.show(context, context.l10n.profilePrefsClubLeft, kind: BuToastKind.success);
    }
  }

  Future<void> _withdraw(Map<String, dynamic> c) async {
    final ok = await confirmDialog(context,
        title: context.l10n.profilePrefsWithdrawTitle,
        message: context.l10n.profilePrefsWithdrawBody,
        confirmLabel: context.l10n.profilePrefsWithdrawConfirm,
        icon: LucideIcons.undo2);
    if (!ok || !mounted) return;
    try {
      await widget.session.api.delete('/communities/${_id(c)}/membership');
      if (mounted) setState(() => _items.remove(c));
    } catch (e) {
      if (mounted) _snack(errorText(e));
    }
  }

  Future<void> _edit(Map<String, dynamic> c) async {
    // Listede tam alanlar olmayabilir: formu güncel kulüp verisiyle açar.
    Map<String, dynamic> club = c;
    try {
      final r = await widget.session.api.get('/communities/${_id(c)}');
      if (r is Map) club = Map<String, dynamic>.from(r);
    } catch (_) {}
    if (!mounted) return;
    final res = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => ClubFormPage(session: widget.session, club: club)),
    );
    if (res != null && mounted) _load(silent: true);
  }

  Future<void> _requests(Map<String, dynamic> c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClubRequestsPage(session: widget.session, communityId: _id(c))),
    );
    if (mounted) _load(silent: true);
  }

  Future<void> _members(Map<String, dynamic> c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClubMembersPage(
          session: widget.session,
          communityId: _id(c),
          myRole: c['myRole']?.toString(),
          clubName: (c['name'] ?? '').toString(),
          memberCount: (c['memberCount'] as num?)?.toInt(),
        ),
      ),
    );
    if (mounted) _load(silent: true);
  }

  Future<void> _discover() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Scaffold(body: ClubsTab(session: widget.session))),
    );
    if (mounted) _load(silent: true);
  }

  Future<void> _create() async {
    if (await openCreateClub(context, widget.session) && mounted) _load(silent: true);
  }

  /// Satır seçenekleri (referans 30-02): kulüp özeti + yönet/aç/ayrıl.
  Future<void> _options(Map<String, dynamic> c) async {
    final l = context.l10n;
    final manager = isClubManagerRole(c['myRole']?.toString());
    final v = await BuSheet.show<String>(
      context,
      builder: (ctx) {
        final t = ctx.bu;
        void pick(String v) => Navigator.of(ctx).pop(v);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  _ClubLogo(club: c, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text((c['name'] ?? '').toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(ctx).textTheme.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            Divider(height: 16, color: t.bd),
            if (manager) ...[
              ClubSheetRow(icon: LucideIcons.pencil, title: l.profilePrefsManageEdit, onTap: () => pick('edit')),
              ClubSheetRow(icon: LucideIcons.userPlus, title: l.profilePrefsManageRequests, onTap: () => pick('requests')),
              ClubSheetRow(icon: LucideIcons.users, title: l.profilePrefsManageMembers, onTap: () => pick('members')),
            ],
            ClubSheetRow(icon: LucideIcons.squareArrowOutUpRight, title: l.profilePrefsOpen, onTap: () => pick('open')),
            Divider(height: 16, color: t.bd),
            ClubSheetRow(icon: LucideIcons.logOut, title: l.profilePrefsLeaveClub, danger: true, onTap: () => pick('leave')),
            const SizedBox(height: 8),
          ],
        );
      },
    );
    if (v == null || !mounted) return;
    switch (v) {
      case 'edit':
        await _edit(c);
      case 'requests':
        await _requests(c);
      case 'members':
        await _members(c);
      case 'open':
        await _open(c);
      case 'leave':
        await _leave(c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final owned = _items.where((c) => c['myStatus'] != 'PENDING' && c['myRole'] == 'OWNER').toList();
    final member = _items.where((c) => c['myStatus'] != 'PENDING' && c['myRole'] != 'OWNER').toList();
    final pending = _items.where((c) => c['myStatus'] == 'PENDING').toList();

    Widget body;
    if (_loading && _items.isEmpty) {
      body = const BuSkeletonList(variant: BuSkeletonVariant.row, itemCount: 5);
    } else if (_error != null && _items.isEmpty) {
      body = BuErrorState(error: _error, onRetry: _load);
    } else if (_items.isEmpty) {
      body = RefreshIndicator(
        color: t.pr,
        onRefresh: () => _load(silent: true),
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const BuIllustrationView(BuIllustration.club, size: 140),
                    const SizedBox(height: 20),
                    Text(l.profilyardClubsEmptyTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(l.profilyardClubsEmptyBody,
                        textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.mut, height: 1.45)),
                    const SizedBox(height: 28),
                    BuButton(label: l.profilyardClubsDiscover, icon: LucideIcons.compass, onPressed: _discover),
                    const SizedBox(height: 12),
                    BuButton(label: l.profilePrefsCreateClub, icon: LucideIcons.plus, kind: BuButtonKind.soft, onPressed: _create),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        color: t.pr,
        onRefresh: () => _load(silent: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (owned.isNotEmpty) ...[
              _SectionHead(title: l.profilePrefsClubsOwned, count: l.p12CountClubs('${owned.length}')),
              for (final c in owned) Padding(padding: const EdgeInsets.only(bottom: 12), child: _ownedCard(c)),
            ],
            if (member.isNotEmpty) ...[
              _SectionHead(title: l.profilePrefsClubsMember, count: l.p12CountClubs('${member.length}')),
              BuCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < member.length; i++) ...[
                      if (i > 0) Divider(height: 1, indent: 78, endIndent: 16, color: t.bd),
                      _memberRow(member[i]),
                    ],
                  ],
                ),
              ),
            ],
            if (pending.isNotEmpty) ...[
              _SectionHead(title: l.profilePrefsClubsPending, count: l.p12CountRequests('${pending.length}')),
              for (final c in pending) Padding(padding: const EdgeInsets.only(bottom: 12), child: _pendingCard(c)),
            ],
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(
            title: l.profilePrefsMyClubs,
            onBack: () => Navigator.pop(context),
            actions: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 16),
                child: BuButton(label: l.profilePrefsCreateClub, icon: LucideIcons.plus, kind: BuButtonKind.soft, compact: true, onPressed: _create),
              ),
            ],
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _ownedCard(Map<String, dynamic> c) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final members = (c['memberCount'] as num?)?.toInt();
    final inReview = c['status'] == 'PENDING_REVIEW' || c['status'] == 'PENDING';
    final cat = (c['category'] as String?) ?? '';
    return BuCard(
      onTap: () => _open(c),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _ClubLogo(club: c, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((c['name'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Pill(label: l.profilyardRoleOwner, icon: LucideIcons.shield, ink: true),
                    if (inReview) _Pill(label: l.profilePrefsAwaitingPublish, icon: LucideIcons.clock, warn: true),
                    if (members != null || cat.isNotEmpty)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        if (members != null) ...[
                          ExcludeSemantics(child: Icon(LucideIcons.users, size: 14, color: t.mut)),
                          const SizedBox(width: 4),
                          Text(l.profilePrefsMembersCount('$members'), style: tx.bodySmall!.copyWith(color: t.mut)),
                        ],
                      ]),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          BuButton(label: l.profilePrefsManage, icon: LucideIcons.slidersHorizontal, compact: true, onPressed: () => _options(c)),
        ],
      ),
    );
  }

  Widget _memberRow(Map<String, dynamic> c) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final members = (c['memberCount'] as num?)?.toInt();
    final (roleLabel, mod) = switch (c['myRole']) {
      'ADMIN' => (l.profilyardRoleAdmin, true),
      'MODERATOR' => (l.profilyardRoleModerator, true),
      _ => (l.profilyardRoleMember, false),
    };
    return InkWell(
      onTap: () => _open(c),
      onLongPress: () => _options(c),
      borderRadius: BorderRadius.circular(BuRadius.lg),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 14),
        child: Row(
          children: [
            _ClubLogo(club: c, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((c['name'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Pill(label: roleLabel, icon: mod ? LucideIcons.shield : null),
                      if (members != null) Text(l.profilePrefsMembersCount('$members'), style: tx.bodySmall!.copyWith(color: t.mut)),
                    ],
                  ),
                ],
              ),
            ),
            ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 20, color: t.mut)),
          ],
        ),
      ),
    );
  }

  Widget _pendingCard(Map<String, dynamic> c) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final when = relativeTime((c['requestedAt'] ?? c['joinedAt'])?.toString(), context: context);
    return BuCard(
      onTap: () => _open(c),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Row(
              children: [
                _ClubLogo(club: c, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((c['name'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _Pill(label: l.profilePrefsAwaitingApproval, warn: true, dot: true),
                          if (when.isNotEmpty) Text(when, style: tx.bodySmall!.copyWith(color: t.mut)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 8, indent: 62, color: t.bd),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Semantics(
              button: true,
              label: l.profilePrefsWithdrawTitle,
              child: InkWell(
                onTap: () => _withdraw(c),
                borderRadius: BuRadius.bPill,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.undo2, size: 16, color: t.pr),
                          const SizedBox(width: 6),
                          Text(l.profilePrefsWithdrawTitle, style: tx.labelLarge!.copyWith(color: t.pr, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Küçük hap etiketi: [ink] koyu (rol), [warn] kehribar (durum), varsayılan gri.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.icon, this.ink = false, this.warn = false, this.dot = false});

  final String label;
  final IconData? icon;
  final bool ink;
  final bool warn;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final (bg, fg) = ink ? (t.ink, t.bg) : (warn ? (t.warnSoft, t.onWarnSoft) : (t.sf2, t.mut));
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BuRadius.bPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[Container(width: 7, height: 7, decoration: BoxDecoration(color: t.warn, shape: BoxShape.circle)), const SizedBox(width: 6)],
          if (icon != null) ...[ExcludeSemantics(child: Icon(icon, size: 12, color: fg)), const SizedBox(width: 4)],
          Flexible(
            child: Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall!.copyWith(color: fg, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

/// Bölüm başlığı: solda büyük harfli ad, sağda sayaç.
class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.title, required this.count});

  final String title;
  final String count;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 16, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(trUpper(title), maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w800, letterSpacing: .6)),
            ),
          ),
          Text(count, style: tx.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Kulüp logosu: yüklenmişse görsel, yoksa kategori tonlu baş harfler; yuvarlatılmış kare.
class _ClubLogo extends StatelessWidget {
  const _ClubLogo({required this.club, required this.size});

  final Map<String, dynamic> club;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final name = (club['name'] ?? '').toString();
    final url = (club['logoUrl'] ?? club['coverUrl'])?.toString();
    // Kategori/kimlik başına renk yok: tek nötr ton.
    final tint = BuTint(t.sf2, t.ink);
    if (fileUrl(url) != null) {
      return ClipRRect(borderRadius: BorderRadius.circular(size * .3), child: BuImage(url, width: size, height: size));
    }
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: tint.bg, borderRadius: BorderRadius.circular(size * .3)),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(initialsOf(name), style: Theme.of(context).textTheme.titleMedium!.copyWith(color: tint.fg, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}

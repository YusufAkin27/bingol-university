import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/academic_catalog.dart' show gradeLabelL;
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
import 'akad_widgets.dart';

String _audience(AppLocalizations l, Announcement a) {
  final p = [if (a.department != null) a.department!, if (a.faculty != null) a.faculty!, if (a.grade != null) gradeLabelL(l, a.grade)];
  return p.isEmpty ? l.acadAnnAudienceAll : p.join(' · ');
}

/// Kısa kapsam etiketi (çip kesilmesin): Bölüm / Fakülte / sınıf.
String _shortScope(AppLocalizations l, Announcement a) => a.department != null
    ? l.profileDepartment
    : (a.faculty != null ? l.profileFaculty : _audience(l, a));

/// "Bugün, 14:20" / "Dün, 09:45" / "12 Ekim 2026" (İstanbul saati).
String _when(AppLocalizations l, DateTime? at) {
  if (at == null) return '';
  final w = istanbulWall(at);
  final n = istanbulWall(academicClock());
  final d = DateTime.utc(w.year, w.month, w.day);
  final today = DateTime.utc(n.year, n.month, n.day);
  final time = hhmm(w.hour * 60 + w.minute);
  final diff = today.difference(d).inDays;
  if (diff == 0) return '${l.acadTimeToday}, $time';
  if (diff == 1) return '${l.p20Yesterday}, $time';
  return fmtWallDateL(l, d);
}

/// Bölüm duyuruları (Stitch 45): "Bölümüm | Tümü" sekmeleri, sabitlenmiş/okunmamış etiketli kartlar, imleçli akış.
class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key, required this.session});

  final Session session;

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  late final AcademicApi _api = AcademicApi(widget.session);
  final _scroll = ScrollController();
  final List<Announcement> _items = [];
  bool _mine = true;
  String? _cursor;
  bool _loading = true, _more = false, _hasMore = false;
  Object? _error;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _api.announcements(mine: _mine);
      if (!mounted || gen != _gen) return;
      setState(() {
        _items
          ..clear()
          ..addAll(r.items);
        _cursor = r.next;
        _hasMore = r.next != null;
        _loading = false;
      });
      _fillIfShort();
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// İlk sayfa ekranı doldurmuyorsa kaydırma olayı gelmez: sonraki sayfayı kendimiz iste.
  void _fillIfShort() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (_scroll.position.maxScrollExtent <= 300) _loadMore();
    });
  }

  Future<void> _loadMore() async {
    if (_more || !_hasMore || _loading || _cursor == null) return;
    final gen = _gen;
    setState(() => _more = true);
    try {
      final r = await _api.announcements(mine: _mine, cursor: _cursor);
      if (!mounted || gen != _gen) return;
      setState(() {
        _items.addAll(r.items);
        _cursor = r.next;
        _hasMore = r.next != null;
        _more = false;
      });
      _fillIfShort();
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _more = false;
        _hasMore = false;
      });
      academicToast(context, errorText(e));
    }
  }

  Future<void> _open(Announcement a) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AnnouncementDetailPage(session: widget.session, id: a.id, preview: a)));
    if (!mounted) return;
    final i = _items.indexWhere((x) => x.id == a.id);
    if (i >= 0 && !_items[i].read) setState(() => _items[i] = _items[i].asRead());
  }

  Future<void> _readAll() async {
    try {
      await _api.readAll();
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          _items[i] = _items[i].asRead();
        }
      });
    } catch (e) {
      if (mounted) academicToast(context, errorText(e));
    }
  }

  void _setMine(bool v) {
    if (_mine == v) return;
    setState(() => _mine = v);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((a) => !a.read).length;
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return AcademicScaffold(
      title: l.acadAnnTitle,
      child: Column(children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 0),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48)),
              onPressed: unread == 0 ? null : _readAll,
              icon: Icon(LucideIcons.checkCheck, size: 18, color: unread == 0 ? t.mut : t.pr),
              label: Text(l.acadAnnReadAll, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w800, color: unread == 0 ? t.mut : t.pr)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            _TabChip(label: l.acadMyDept, icon: LucideIcons.graduationCap, selected: _mine, badge: _mine ? unread : 0, onTap: () => _setMine(true)),
            const SizedBox(width: 10),
            _TabChip(label: l.acadAll, icon: LucideIcons.globe, selected: !_mine, onTap: () => _setMine(false)),
          ]),
        ),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    final l = context.l10n;
    final t = context.bu;
    if (_loading && _items.isEmpty) {
      return Semantics(
        label: l.commonLoading,
        liveRegion: true,
        child: const BuSkeletonScope(
          child: SingleChildScrollView(
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(children: [
              BuSkeleton(height: 150, radius: 20),
              SizedBox(height: 14),
              BuSkeleton(height: 150, radius: 20),
              SizedBox(height: 14),
              BuSkeleton(height: 150, radius: 20),
            ]),
          ),
        ),
      );
    }
    if (_error != null && _items.isEmpty) {
      return ListView(padding: const EdgeInsets.all(16), children: [AcademicErrorViewCard(error: _error!, onRetry: _reload)]);
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
        children: [
          for (final a in _items) Padding(padding: const EdgeInsets.only(bottom: 14), child: _tile(t, a)),
          if (_more) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          if (!_hasMore && !_more) _footer(t, l),
        ],
      ),
    );
  }

  /// Liste sonu / boş durum: zil simgeli bilgi kartı.
  Widget _footer(BuTokens t, AppLocalizations l) {
    final tx = Theme.of(context).textTheme;
    final empty = _items.isEmpty;
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: t.sf2.withValues(alpha: .7), borderRadius: BuRadius.bLg),
        child: Column(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: t.sf, shape: BoxShape.circle), child: Icon(LucideIcons.bell, size: 22, color: t.mut)),
          const SizedBox(height: 12),
          Text(empty ? (_mine ? l.acadAnnEmptyMine : l.acadAnnEmptyAll) : l.p20AnnFooterTitle,
              textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
          if (!empty) ...[
            const SizedBox(height: 4),
            Text(l.p20AnnFooterBody, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut)),
          ],
        ]),
      ),
    );
  }

  Widget _tile(BuTokens t, Announcement a) {
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final audience = _audience(l, a);
    final unit = a.faculty ?? a.department;
    return Semantics(
      container: true,
      button: true,
      label: [if (!a.read) l.acadAnnUnread, if (a.pinned) l.acadAnnPinned, a.title, audience].join('. '),
      excludeSemantics: true,
      onTap: () => _open(a),
      child: AkadCard(
        onTap: () => _open(a),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _tags(t, a, audience)),
            const SizedBox(width: 8),
            Icon(LucideIcons.clock, size: 14, color: t.mut),
            const SizedBox(width: 4),
            Text(_when(l, a.publishAt), style: tx.labelMedium!.copyWith(color: t.mut)),
          ]),
          const SizedBox(height: 12),
          Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, fontSize: 17, color: t.ink)),
          if (a.body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(a.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(color: t.mut)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            if (unit != null) ...[
              Icon(LucideIcons.building2, size: 16, color: t.ink),
              const SizedBox(width: 8),
              Expanded(child: Text(unit, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w600, color: t.ink))),
            ] else if (a.attachmentUrl != null) ...[
              Icon(LucideIcons.paperclip, size: 16, color: t.pr),
              const SizedBox(width: 8),
              Expanded(child: Text(l.akademik2Attachment, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.pr))),
            ] else
              const Spacer(),
            Icon(buDirIcon(context, LucideIcons.chevronRight), size: 20, color: t.ink),
          ]),
        ]),
      ),
    );
  }

  Widget _tags(BuTokens t, Announcement a, String audience) {
    final l = context.l10n;
    final all = a.department == null && a.faculty == null && a.grade == null;
    return Wrap(spacing: 6, runSpacing: 6, children: [
      if (a.pinned) AkadPill(l.acadAnnPinned, bg: t.tint(1).bg, fg: t.tint(1).fg, icon: LucideIcons.pin),
      if (!a.read) AkadPill(l.acadAnnUnread, bg: t.soft, fg: t.onSoft, dot: true),
      if (all) AkadPill(audience, bg: t.tint(1).bg, fg: t.tint(1).fg, icon: LucideIcons.building2) else if (a.read && !a.pinned) AkadPill(_shortScope(l, a), bg: t.sf2, fg: t.mut, icon: LucideIcons.folder),
    ]);
  }
}

/// Üst sekme hapı: simge + etiket (+ okunmamış sayısı balonu); seçili = koyu.
class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.icon, required this.selected, required this.onTap, this.badge = 0});

  final String label;
  final IconData icon;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final fg = selected ? t.bg : t.mut;
    return Flexible(
      child: Semantics(
        button: true,
        selected: selected,
        label: badge > 0 ? '$label, $badge' : label,
        excludeSemantics: true,
        onTap: onTap,
        child: BuPressable(
          onTap: onTap,
          haptic: BuHaptic.selection,
          scale: .96,
          child: AnimatedContainer(
            duration: BuMotion.of(context, BuMotion.short),
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: ShapeDecoration(color: selected ? t.ink : t.sf2, shape: const StadiumBorder()),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: fg))),
                if (badge > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: t.pr, borderRadius: BuRadius.bPill),
                    child: Text(badge > 99 ? '99+' : '$badge', style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w800, color: t.onPr)),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Duyuru ayrıntısı: açılınca sunucu okundu işaretler.
class AnnouncementDetailPage extends StatefulWidget {
  const AnnouncementDetailPage({super.key, required this.session, required this.id, this.preview});

  final Session session;
  final int id;
  final Announcement? preview;

  @override
  State<AnnouncementDetailPage> createState() => _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState extends State<AnnouncementDetailPage> {
  late final AcademicApi _api = AcademicApi(widget.session);
  Announcement? _a;
  Object? _error;
  String? _failedUrl; // açılamayan ek (hata kartı için)

  @override
  void initState() {
    super.initState();
    _a = null;
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final a = await _api.announcement(widget.id);
      if (mounted) setState(() => _a = a);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _openLink(String url) async {
    final u = Uri.tryParse(url);
    var ok = false;
    if (u != null && u.scheme == 'https') {
      try {
        ok = await launchUrl(u, mode: LaunchMode.externalApplication);
      } catch (_) {
        ok = false;
      }
    }
    if (mounted) setState(() => _failedUrl = ok ? null : url);
  }

  /// Ek adı: URL yolunun son parçası.
  String _fileName(String url) {
    final seg = Uri.tryParse(url)?.pathSegments.where((s) => s.isNotEmpty).lastOrNull;
    return seg == null ? url : Uri.decodeComponent(seg);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final a = _a;
    Widget body;
    if (a == null && _error != null) {
      body = ListView(padding: const EdgeInsets.all(16), children: [AcademicErrorViewCard(error: _error!, onRetry: _load)]);
    } else if (a == null) {
      body = Semantics(
        label: l.commonLoading,
        liveRegion: true,
        child: const BuSkeletonScope(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(children: [BuSkeleton(height: 420, radius: 20)]),
          ),
        ),
      );
    } else {
      final all = a.department == null && a.faculty == null && a.grade == null;
      final file = a.attachmentUrl == null ? null : _fileName(a.attachmentUrl!);
      final ext = file != null && file.contains('.') ? file.split('.').last.toUpperCase() : null;
      body = ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
        AkadCard(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (a.pinned) AkadPill(l.acadAnnPinned, bg: t.soft, fg: t.onSoft, icon: LucideIcons.pin),
              AkadPill(_audience(l, a), bg: all ? t.tint(1).bg : t.sf2, fg: all ? t.tint(1).fg : t.mut),
            ]),
            if ((a.faculty ?? a.department) != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                Icon(LucideIcons.graduationCap, size: 16, color: t.mut),
                const SizedBox(width: 6),
                Flexible(child: Text((a.faculty ?? a.department)!, style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: t.ink))),
              ]),
            ],
            if (a.publishAt != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                Icon(LucideIcons.clock, size: 16, color: t.mut),
                const SizedBox(width: 6),
                Flexible(child: Text(fmtInstantL(l, a.publishAt!), style: tx.bodyMedium!.copyWith(color: t.mut))),
              ]),
            ],
            const SizedBox(height: 16),
            Semantics(header: true, child: Text(a.title, style: tx.headlineSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
            const SizedBox(height: 16),
            SelectableText(a.body, style: tx.bodyLarge!.copyWith(color: t.ink, height: 1.6)),
            if (a.attachmentUrl != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bMd),
                child: Row(children: [
                  AkadIconTile(icon: LucideIcons.paperclip, bg: t.soft, fg: t.pr, size: 48, radius: 14, iconSize: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(file ?? l.akademik2Attachment, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                      if (ext != null && ext.length <= 5) Text(ext, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w800, color: t.pr)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: t.ink, foregroundColor: t.bg, minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 14)),
                    onPressed: () => _openLink(a.attachmentUrl!),
                    icon: const Icon(LucideIcons.externalLink, size: 16),
                    label: Text(l.acadAnnOpenAttachment),
                  ),
                ]),
              ),
            ],
          ]),
        ),
        if (_failedUrl != null) ...[const SizedBox(height: 16), _linkError(t, tx, l)],
      ]);
    }
    return AcademicScaffold(title: l.acadAnnDetailTitle, child: body);
  }

  /// Bağlantı açılamadı: pembe kart (yeniden dene + kapat).
  Widget _linkError(BuTokens t, TextTheme tx, AppLocalizations l) => Semantics(
        container: true,
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: t.soft, borderRadius: BuRadius.bLg),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle), child: Icon(LucideIcons.circleAlert, size: 20, color: t.onPr)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.acadAnnLinkError, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.onSoft)),
                const SizedBox(height: 2),
                Text(l.p20AnnLinkErrBody, style: tx.bodySmall!.copyWith(color: t.onSoft)),
                const SizedBox(height: 10),
                BuButton(label: l.acadRetry, icon: LucideIcons.rotateCw, compact: true, onPressed: () => _openLink(_failedUrl!)),
              ]),
            ),
            IconButton(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              tooltip: l.acadTimeClose,
              icon: Icon(LucideIcons.x, size: 20, color: t.onSoft),
              onPressed: () => setState(() => _failedUrl = null),
            ),
          ]),
        ),
      );
}

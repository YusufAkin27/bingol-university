import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/academic_catalog.dart' show gradeLabelL;
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
import 'akad_widgets.dart';

String _audience(AppLocalizations l, Announcement a) {
  final p = [if (a.department != null) a.department!, if (a.faculty != null) a.faculty!, if (a.grade != null) gradeLabelL(l, a.grade)];
  return p.isEmpty ? l.acadAnnAudienceAll : p.join(' · ');
}

/// Bölüm duyuruları: imleçli akış, okunmamış rozeti, sabitlenmişler, "Bölümüm | Tümü".
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

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((a) => !a.read).length;
    final l = context.l10n;
    return AcademicScaffold(
      title: l.acadAnnTitle,
      actions: [BuIconButton(icon: LucideIcons.checkCheck, tooltip: l.acadAnnReadAll, onTap: unread == 0 ? null : _readAll)],
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 2),
          child: Row(children: [
            AkadChip(
              label: l.acadMyDept,
              selected: _mine,
              onTap: () {
                if (_mine) return;
                setState(() => _mine = true);
                _reload();
              },
            ),
            const SizedBox(width: 8),
            AkadChip(
              label: l.acadAll,
              selected: !_mine,
              onTap: () {
                if (!_mine) return;
                setState(() => _mine = false);
                _reload();
              },
            ),
          ]),
        ),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty) return const LoadingView();
    if (_error != null && _items.isEmpty) return AcademicErrorView(error: _error!, onRetry: _reload);
    final l = context.l10n;
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(children: [
          SizedBox(
            height: 300,
            child: EmptyView(
                icon: LucideIcons.megaphone, text: _mine ? l.acadAnnEmptyMine : l.acadAnnEmptyAll),
          ),
        ]),
      );
    }
    final t = context.bu;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 32),
        itemCount: _items.length + (_more ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= _items.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
          final a = _items[i];
          return Padding(padding: const EdgeInsets.only(bottom: 12), child: _tile(t, a));
        },
      ),
    );
  }

  Widget _tile(BuTokens t, Announcement a) {
    final l = context.l10n;
    final audience = _audience(l, a);
    const amber = Color(0xFF8A5200);
    return Semantics(
      container: true,
      button: true,
      label: [if (!a.read) l.acadAnnUnread, if (a.pinned) l.acadAnnPinned, a.title, audience].join('. '),
      excludeSemantics: true,
      onTap: () => _open(a),
      child: AkadCard(
        onTap: () => _open(a),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderColor: !a.read || a.pinned ? t.pr.withValues(alpha: .3) : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _pills(t, a, audience, amber),
          const SizedBox(height: 8),
          Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.heading.copyWith(fontSize: 15, fontWeight: FontWeight.w800, color: t.ink)),
          if (a.body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(a.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: BuType.body.copyWith(fontSize: 13, height: 1.45, color: t.mut)),
          ],
          if (a.attachmentUrl != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(LucideIcons.paperclip, size: 14, color: t.pr),
              const SizedBox(width: 6),
              Flexible(child: Text(l.akademik2Attachment, style: BuType.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, color: t.pr))),
            ]),
          ],
          const SizedBox(height: 8),
          Text(relativeTime(a.publishAt?.toIso8601String()), style: BuType.caption.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500, color: t.mut)),
        ]),
      ),
    );
  }

  Widget _pills(BuTokens t, Announcement a, String audience, Color amber) {
    final l = context.l10n;
    return Wrap(spacing: 6, runSpacing: 6, children: [
      if (a.pinned) AkadPill(l.acadAnnPinned, bg: akadTint(context, amber), fg: akadOnTint(context, amber), icon: LucideIcons.pin),
      if (!a.read) AkadPill(l.akademik2NewTag, bg: t.soft, fg: t.danger),
      AkadPill(audience, bg: t.sf2, fg: t.mut),
    ]);
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
    if (u == null || u.scheme != 'https') return;
    try {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) academicToast(context, context.l10n.acadAnnLinkError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final a = _a;
    Widget body;
    if (a == null && _error != null) {
      body = AcademicErrorView(error: _error!, onRetry: _load);
    } else if (a == null) {
      body = const LoadingView();
    } else {
      const amber = Color(0xFF8A5200);
      body = ListView(padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 32), children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (a.pinned) AkadPill(l.acadAnnPinned, bg: akadTint(context, amber), fg: akadOnTint(context, amber), icon: LucideIcons.pin),
          AkadPill(_audience(l, a), bg: t.sf2, fg: t.mut),
        ]),
        const SizedBox(height: 10),
        Semantics(header: true, child: Text(a.title, style: BuType.title.copyWith(fontSize: 20, fontWeight: FontWeight.w800, color: t.ink))),
        const SizedBox(height: 4),
        Text(a.publishAt == null ? '' : fmtInstantL(l, a.publishAt!), style: BuType.caption.copyWith(fontSize: 12.5, color: t.mut)),
        const SizedBox(height: 14),
        SelectableText(a.body, style: BuType.body.copyWith(fontSize: 14, color: t.ink, height: 1.5)),
        if (a.attachmentUrl != null) ...[
          const SizedBox(height: 18),
          AkadButton(label: l.acadAnnOpenAttachment, icon: LucideIcons.paperclip, outlined: true, onPressed: () => _openLink(a.attachmentUrl!)),
        ],
      ]);
    }
    return AcademicScaffold(title: l.acadAnnDetailTitle, child: body);
  }
}

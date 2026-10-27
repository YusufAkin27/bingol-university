import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';

String _audience(Announcement a) {
  final p = [if (a.department != null) a.department!, if (a.faculty != null) a.faculty!, if (a.grade != null) '${a.grade}. sınıf'];
  return p.isEmpty ? 'Tüm üniversite' : p.join(' · ');
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
    return AcademicScaffold(
      title: 'Bölüm duyuruları',
      actions: [BuIconButton(icon: LucideIcons.checkCheck, tooltip: 'Tümünü okundu işaretle', onTap: unread == 0 ? null : _readAll)],
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: BuSegmented(
            items: const ['Bölümüm', 'Tümü'],
            index: _mine ? 0 : 1,
            onChanged: (i) {
              if ((i == 0) == _mine) return;
              setState(() => _mine = i == 0);
              _reload();
            },
          ),
        ),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty) return const LoadingView();
    if (_error != null && _items.isEmpty) return AcademicErrorView(error: _error!, onRetry: _reload);
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(children: [
          SizedBox(
            height: 300,
            child: EmptyView(
                icon: LucideIcons.megaphone, text: _mine ? 'Bölümünle ilgili duyuru yok.\nTüm duyurulara "Tümü" sekmesinden bakabilirsin.' : 'Henüz duyuru yok.'),
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
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 32),
        itemCount: _items.length + (_more ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= _items.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
          final a = _items[i];
          return Padding(padding: const EdgeInsets.only(bottom: 10), child: _tile(t, a));
        },
      ),
    );
  }

  Widget _tile(BuTokens t, Announcement a) => Semantics(
        container: true,
        button: true,
        label: '${a.read ? '' : 'Okunmamış. '}${a.pinned ? 'Sabitlenmiş. ' : ''}${a.title}. ${_audience(a)}',
        excludeSemantics: true,
        onTap: () => _open(a),
        child: BuCard(
          onTap: () => _open(a),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (!a.read) Container(width: 9, height: 9, margin: const EdgeInsetsDirectional.only(end: 8), decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle)),
              if (a.pinned) Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: Icon(LucideIcons.pin, size: 14, color: t.pr)),
              Expanded(
                child: Text(a.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: (a.read ? BuType.bodyStrong : BuType.heading).copyWith(color: t.ink)),
              ),
            ]),
            if (a.body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(a.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: BuType.body.copyWith(color: t.mut)),
            ],
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text(_audience(a), maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(color: t.mut))),
              if (a.attachmentUrl != null) Icon(LucideIcons.paperclip, size: 13, color: t.mut),
              const SizedBox(width: 6),
              Text(relativeTime(a.publishAt?.toIso8601String()), style: BuType.caption.copyWith(color: t.mut)),
            ]),
          ]),
        ),
      );
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
      if (mounted) academicToast(context, 'Bağlantı açılamadı.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final a = _a;
    Widget body;
    if (a == null && _error != null) {
      body = AcademicErrorView(error: _error!, onRetry: _load);
    } else if (a == null) {
      body = const LoadingView();
    } else {
      body = ListView(padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 32), children: [
        Row(children: [
          if (a.pinned) ...[const BuBadge('Sabitlenmiş', soft: true), const SizedBox(width: 6)],
          Expanded(child: Text(_audience(a), style: BuType.label.copyWith(color: t.mut))),
        ]),
        const SizedBox(height: 10),
        Semantics(header: true, child: Text(a.title, style: BuType.title.copyWith(color: t.ink))),
        const SizedBox(height: 4),
        Text(a.publishAt == null ? '' : fmtInstant(a.publishAt!), style: BuType.caption.copyWith(color: t.mut)),
        const SizedBox(height: 14),
        SelectableText(a.body, style: BuType.body.copyWith(color: t.ink, height: 1.5)),
        if (a.attachmentUrl != null) ...[
          const SizedBox(height: 18),
          BuButton(label: 'Eki aç', icon: LucideIcons.paperclip, kind: BuButtonKind.outline, onPressed: () => _openLink(a.attachmentUrl!)),
        ],
      ]);
    }
    return AcademicScaffold(title: 'Duyuru', child: body);
  }
}

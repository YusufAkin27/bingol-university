import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/academic_catalog.dart' show AcademicLabels, gradeLabelL;
import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'acad_ref_widgets.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';

String _audience(BuildContext context, AppLocalizations l, Announcement a) {
  final p = [
    if (a.department != null) context.departmentName(a.department, faculty: a.faculty),
    if (a.faculty != null) context.facultyName(a.faculty),
    if (a.grade != null) gradeLabelL(l, a.grade)
  ];
  return p.isEmpty ? l.acadAnnAudienceAll : p.join(' · ');
}

/// Birim adı (fakülte/bölüm); yoksa kapsam metni ("Tüm üniversite" vb.).
String _unit(BuildContext context, AppLocalizations l, Announcement a) {
  if (a.faculty != null) return context.facultyName(a.faculty);
  if (a.department != null) return context.departmentName(a.department);
  return _audience(context, l, a);
}

/// "2 gün önce" / "3 saat önce"; bir haftadan eskiyse tarih (İstanbul saati, academicClock'a göre).
String _ago(AppLocalizations l, DateTime? at) {
  if (at == null) return '';
  final diff = academicClock().difference(at);
  if (diff.inMinutes < 1) return l.commonJustNow;
  if (diff.inMinutes < 60) return l.commonMinutesAgo(diff.inMinutes.toString());
  if (diff.inHours < 24) return l.commonHoursAgo(diff.inHours.toString());
  if (diff.inDays < 7) return l.commonDaysAgo(diff.inDays.toString());
  if (diff.inDays < 30) return l.p69WeeksAgo((diff.inDays ~/ 7).toString());
  final w = istanbulWall(at);
  return fmtWallDateL(l, DateTime.utc(w.year, w.month, w.day));
}

/// Bölüm duyuruları (Stitch v3 06): "Bölümüm | Tümü" metin sekmeleri, kartsız satırlar (okunmamışta `pr` nokta + kalın
/// başlık, sabitlenmişte sağda "Sabitlenmiş"), imleçli akış.
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
    return AcademicScaffold(
      title: l.acadAnnTitle,
      actions: [if (unread > 0) BuIconButton(icon: LucideIcons.checkCheck, tooltip: l.acadAnnReadAll, onTap: _readAll)],
      child: Column(children: [
        const SizedBox(height: 2),
        AcadTabs(labels: [l.acadMyDept, l.acadAll], index: _mine ? 0 : 1, onChanged: (i) => _setMine(i == 0)),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    final l = context.l10n;
    if (_loading && _items.isEmpty) return const SingleChildScrollView(physics: NeverScrollableScrollPhysics(), child: AcadRowsSkeleton(count: 5));
    if (_error != null && _items.isEmpty) {
      final e = _error!;
      return ListView(padding: const EdgeInsets.only(top: 16), children: [
        if (e is ApiError && e.status == 503)
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 0), child: AcadAmberNote(text: e.message.isNotEmpty ? e.message : l.acadMaintenance))
        else
          AcadStateText(text: '${l.sistemuiErrorTitle}\n${errorText(e)}', top: 12),
        AcadStateText(text: '', actionLabel: l.acadRetry, onAction: _reload, top: 0),
      ]);
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (_items.isEmpty) AcadStateText(text: _mine ? l.acadAnnEmptyMine : l.acadAnnEmptyAll, top: 36),
          BuStaggerScope(
            child: Column(children: [
              for (var i = 0; i < _items.length; i++) BuStaggerItem(index: i, child: _tile(_items[i])),
            ]),
          ),
          if (_more) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _tile(Announcement a) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final unit = _unit(context, l, a);
    final ago = _ago(l, a.publishAt);
    return AcadRow(
      minHeight: 75,
      onTap: () => _open(a),
      semanticLabel: [if (!a.read) l.acadAnnUnread, if (a.pinned) l.acadAnnPinned, a.title, unit].join('. '),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!a.read) const Padding(padding: EdgeInsets.only(top: 9, right: 12), child: AcadDot()),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(a.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tx.bodyLarge!.copyWith(fontSize: 16, fontWeight: a.read ? FontWeight.w400 : FontWeight.w700, color: t.ink)),
            const SizedBox(height: 1),
            Text(ago.isEmpty ? unit : l.p69AnnUnitDate(unit, ago), maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.mut)),
          ]),
        ),
        const SizedBox(width: 12),
        if (a.pinned)
          Flexible(flex: 0, child: Padding(padding: const EdgeInsets.only(top: 4), child: Text(l.acadAnnPinned, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 12, color: t.mut))))
        else
          Padding(padding: const EdgeInsets.only(top: 3), child: ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut.withValues(alpha: .6)))),
      ]),
    );
  }
}

/// Duyuru ayrıntısı (Stitch v3 09): başlık 24 sp/700, muted "birim · tarih", ayraç, gövde 16 sp/1.6 (madde işaretli
/// satırlar liste olur), `pr` "Ekli belgeyi aç". Açılınca sunucu okundu işaretler.
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
  String? _failedUrl; // açılamayan ek (not için)

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
      final e = _error!;
      body = ListView(padding: const EdgeInsets.only(top: 16), children: [
        if (e is ApiError && e.status == 503)
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 0), child: AcadAmberNote(text: e.message.isNotEmpty ? e.message : l.acadMaintenance))
        else
          AcadStateText(text: '${l.sistemuiErrorTitle}\n${errorText(e)}', top: 12),
        AcadStateText(text: '', actionLabel: l.acadRetry, onAction: _load, top: 0),
      ]);
    } else if (a == null) {
      body = Semantics(
        label: l.commonLoading,
        liveRegion: true,
        child: const BuSkeletonScope(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              BuSkeleton.line(width: 240, height: 24),
              SizedBox(height: 14),
              BuSkeleton.line(width: 170, height: 14),
              SizedBox(height: 40),
              BuSkeleton.line(height: 16),
              SizedBox(height: 10),
              BuSkeleton.line(height: 16),
              SizedBox(height: 10),
              BuSkeleton.line(width: 200, height: 16),
            ]),
          ),
        ),
      );
    } else {
      final w = a.publishAt == null ? null : istanbulWall(a.publishAt!);
      final meta = [_unit(context, l, a), if (w != null) fmtWallDateL(l, DateTime.utc(w.year, w.month, w.day))].join(' · ');
      final file = a.attachmentUrl == null ? null : _fileName(a.attachmentUrl!);
      body = ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 32), children: [
        Semantics(header: true, child: Text(a.title, style: tx.headlineMedium!.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0, color: t.ink))),
        const SizedBox(height: 10),
        Text(meta, style: tx.bodyMedium!.copyWith(color: t.mut)),
        const SizedBox(height: 16),
        const AcadRule(),
        const SizedBox(height: 14),
        _AnnBody(text: a.body),
        if (a.attachmentUrl != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AcadTextAction(l.p69OpenAttachment, onTap: () => _openLink(a.attachmentUrl!), size: 16, weight: FontWeight.w700, semanticLabel: file == null ? l.p69OpenAttachment : '${l.p69OpenAttachment}: $file'),
          ),
        ],
        if (_failedUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AcadAmberNote(text: '${l.acadAnnLinkError} ${l.p20AnnLinkErrBody}', actionLabel: l.acadRetry, onAction: () => _openLink(_failedUrl!)),
          ),
      ]);
    }
    return AcademicScaffold(title: l.acadAnnDetailTitle, child: body);
  }
}

/// Duyuru gövdesi: boş satırla ayrılan paragraflar (16 dp aralık), "- ", "* " ya da "• " ile başlayan satırlar madde
/// işaretli liste (8 dp aralık). Metin seçilebilir.
class _AnnBody extends StatelessWidget {
  const _AnnBody({required this.text});

  final String text;

  static final _bullet = RegExp(r'^\s*(?:[-*\u2022])\s+');

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final style = Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 16, height: 1.6, color: t.ink);
    final out = <Widget>[];
    final para = <String>[];
    var lastBullet = false;
    void flush() {
      if (para.isEmpty) return;
      if (out.isNotEmpty) out.add(const SizedBox(height: 16));
      out.add(SelectableText(para.join('\n'), style: style));
      para.clear();
      lastBullet = false;
    }

    for (final raw in text.split(RegExp(r'\r?\n'))) {
      if (raw.trim().isEmpty) {
        flush();
      } else if (_bullet.hasMatch(raw)) {
        flush();
        if (out.isNotEmpty) out.add(SizedBox(height: lastBullet ? 8 : 16));
        out.add(_Bullet(text: raw.replaceFirst(_bullet, ''), style: style));
        lastBullet = true;
      } else {
        para.add(raw.trim());
      }
    }
    flush();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: out);
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(width: 2),
      Padding(
        padding: EdgeInsets.only(top: (style.fontSize ?? 16) * (style.height ?? 1.6) / 2 - 2),
        child: ExcludeSemantics(child: Container(width: 4, height: 4, decoration: BoxDecoration(color: t.mut, shape: BoxShape.circle))),
      ),
      const SizedBox(width: 10),
      Expanded(child: SelectableText(text, style: style)),
    ]);
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart';
import '../../widgets/linkified_text.dart';
import 'news_tile.dart';

/// "Bölümüm" duyuruları: `GET /news/unit?limit=` (giriş gerekli). Sunucu kuralı: kullanıcının bölümüyle eşleşme yoksa
/// ya da akış boşsa `[]` döner; bu durumda, ayrıca hata/ağ sorununda, istemci HİÇBİR ŞEY çizmez (yer tutucu, boş durum,
/// "bulunamadı" yazısı yok).
List<Map<String, dynamic>> parseUnitNews(Object? raw) => [
      for (final e in (raw is List ? raw : const []))
        if (e is Map && e['id'] is num && '${e['title'] ?? ''}'.trim().isNotEmpty) Map<String, dynamic>.from(e),
    ];

/// Birim duyurusunu ortak haber kartının beklediği biçime çevirir (tür: DUYURU, görsel yok).
Map<String, dynamic> unitNewsAsTile(Map<String, dynamic> u) => {
      'id': u['id'],
      'type': 'DUYURU',
      'title': u['title'],
      'publishedDate': u['publishedDate'],
      'url': u['url'],
    };

/// Haber listesinin üstünde duran kısa "Bölümüm" şeridi. Boş/hatalı/yüklenirken görünmez.
class UnitNewsStrip extends StatefulWidget {
  const UnitNewsStrip({super.key, required this.session, this.refresh = 0, this.limit = 5});

  final Session session;

  /// Değişince şerit yeniden yüklenir (üst sayfanın çekerek yenilemesi).
  final int refresh;
  final int limit;

  @override
  State<UnitNewsStrip> createState() => _UnitNewsStripState();
}

class _UnitNewsStripState extends State<UnitNewsStrip> {
  List<Map<String, dynamic>> _items = const [];
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant UnitNewsStrip old) {
    super.didUpdateWidget(old);
    if (old.refresh != widget.refresh) _load();
  }

  Future<void> _load() async {
    final gen = ++_gen;
    List<Map<String, dynamic>> items;
    try {
      items = parseUnitNews(await widget.session.api.get('/news/unit?limit=${widget.limit}'));
    } catch (_) {
      items = const []; // hata: şerit gizlenir
    }
    if (mounted && gen == _gen) setState(() => _items = items);
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final t = context.bu;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Semantics(
        container: true,
        label: l.unitNewsSemantic,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(l.unitNewsTitle, style: BuType.caption.copyWith(fontSize: 14, height: 1.3, color: t.mut)),
            ),
          ),
          for (final u in _items)
            NewsTile(
              key: ValueKey('unit-news-${u['id']}'),
              item: unitNewsAsTile(u),
              showSource: false,
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: 'unit_news_detail'),
                  builder: (_) => UnitNewsDetailPage(session: widget.session, item: u),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Birim duyurusu detayı: `GET /news/unit/{id}` (gövde düz metin; ekler dış bağlantı olarak açılır).
class UnitNewsDetailPage extends StatefulWidget {
  const UnitNewsDetailPage({super.key, required this.session, required this.item});

  final Session session;
  final Map<String, dynamic> item;

  @override
  State<UnitNewsDetailPage> createState() => _UnitNewsDetailPageState();
}

class _UnitNewsDetailPageState extends State<UnitNewsDetailPage> {
  Map<String, dynamic>? _detail;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.session.api.get('/news/unit/${widget.item['id']}');
      if (!mounted) return;
      setState(() {
        _detail = r is Map ? Map<String, dynamic>.from(r) : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _open(String? url) async {
    final u = url == null ? null : Uri.tryParse(url);
    if (u == null || u.scheme != 'https') return; // yalnız https
    var ok = false;
    try {
      ok = await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
    if (!ok && mounted) BuToast.show(context, context.l10n.newsLinkOpenFailed, kind: BuToastKind.error);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final d = _detail ?? widget.item;
    final title = '${d['title'] ?? widget.item['title'] ?? ''}';
    final unit = '${d['unitName'] ?? d['sourceName'] ?? ''}'.trim();
    final date = newsLocalDate(context, (d['publishedDate'] ?? widget.item['publishedDate']) as String?);
    final body = '${_detail?['body'] ?? ''}'
        .split(RegExp(r'[\r\n]+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final atts = [
      for (final a in (d['attachments'] is List ? d['attachments'] as List : const []))
        if (a is Map && '${a['url'] ?? ''}'.startsWith('https://')) Map<String, dynamic>.from(a),
    ];
    final url = d['url'] as String?;
    final bodyStyle = Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, color: t.ink);
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: l.unitNewsTitle, onBack: () => Navigator.maybePop(context)),
        Expanded(
          child: _error != null
              ? ErrorView(error: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.headlineSmall!.copyWith(fontSize: 24, fontWeight: FontWeight.w400, height: 1.25, color: t.ink)),
                    const SizedBox(height: 8),
                    Text([if (unit.isNotEmpty) unit, date].join(' · '),
                        style: BuType.caption.copyWith(fontSize: 13, height: 1.4, color: t.mut)),
                    const SizedBox(height: 20),
                    if (_loading)
                      const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                    else ...[
                      for (final p in body)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: LinkifiedText(p, style: bodyStyle),
                        ),
                      if (atts.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Semantics(header: true, child: Text(l.unitNewsAttachments, style: BuType.caption.copyWith(fontSize: 14, color: t.mut))),
                        const SizedBox(height: 8),
                        for (final a in atts)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: BuButton(
                              key: ValueKey('unit-att-${a['url']}'),
                              label: '${a['name'] ?? a['type'] ?? l.unitNewsAttachments}',
                              kind: BuButtonKind.outline,
                              icon: BuIcons.arrowUpRight,
                              onPressed: () => _open(a['url'] as String?),
                            ),
                          ),
                      ],
                      if (url != null && url.startsWith('https://') && atts.isEmpty && body.isEmpty)
                        BuButton(label: newsSourceHost({'url': url}), kind: BuButtonKind.outline, icon: BuIcons.arrowUpRight, onPressed: () => _open(url)),
                    ],
                  ],
                ),
        ),
      ]),
    );
  }
}

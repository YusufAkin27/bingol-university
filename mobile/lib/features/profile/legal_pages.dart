import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../../widgets/simple_markdown.dart';
import '../../core/typography.dart';
import '../support/destek_widgets.dart';

/// Sözleşme listesi (kullanım koşulları, gizlilik, KVKK, topluluk kuralları).
class LegalListPage extends StatefulWidget {
  const LegalListPage({super.key, required this.session});

  final Session session;

  @override
  State<LegalListPage> createState() => _LegalListPageState();
}

class _LegalListPageState extends State<LegalListPage> {
  late Future<List<Map<String, dynamic>>> _future = _fetch();

  Future<List<Map<String, dynamic>>> _fetch() async =>
      List<Map<String, dynamic>>.from(await widget.session.api.get('/legal') as List);

  Future<void> _refresh() async {
    setState(() {
      _future = _fetch();
    });
    try {
      await _future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: context.l10n.profileLegalTitle, onBack: () => Navigator.pop(context)),
          Expanded(
            child: FutureBuilder(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const LoadingView();
                if (snap.hasError) {
                  return ErrorView(error: snap.error!, onRetry: () => setState(() {
                    _future = _fetch();
                  }));
                }
                final docs = snap.data!;
                if (docs.isEmpty) {
                  return EmptyView(icon: LucideIcons.fileText, text: context.l10n.profileLegalEmpty);
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    children: [
                      BuGroup(children: [
                        for (final d in docs)
                          InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LegalDocPage(session: widget.session, type: d['type'] as String),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(children: [
                                Icon(LucideIcons.fileText, size: 20, color: t.pr),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text((d['title'] as String?) ?? (d['type'] as String? ?? ''),
                                        style: BuType.bodyStrong.copyWith(color: t.ink)),
                                    const SizedBox(height: 2),
                                    Text(_versionLine(context, d),
                                        style: BuType.caption.copyWith(color: t.mut)),
                                  ]),
                                ),
                                Icon(buDirIcon(context, LucideIcons.chevronRight), size: 16, color: t.mut),
                              ]),
                            ),
                          ),
                      ]),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// "Sürüm 2 · 1 Ocak 2026"; yayın tarihi yoksa yalnız "Sürüm 2" (sondaki " ·" kalmaz).
String _versionLine(BuildContext context, Map<String, dynamic> d) {
  final date = niceDate(d['publishedAt'] as String?);
  final v = '${d['version']}';
  return date.isEmpty ? context.l10n.profileVersion(v) : context.l10n.profileVersionDate(v, date);
}

class LegalDocPage extends StatefulWidget {
  const LegalDocPage({super.key, required this.session, required this.type});

  final Session session;
  final String type;

  @override
  State<LegalDocPage> createState() => _LegalDocPageState();
}

class _LegalDocPageState extends State<LegalDocPage> {
  late String _type = widget.type;
  late Future<Map<String, dynamic>> _future = _fetch();
  // Sekmeler için belge listesi; alınamazsa sekme çubuğu gizlenir (sayfa yine çalışır).
  List<Map<String, dynamic>> _tabs = [];

  @override
  void initState() {
    super.initState();
    _loadTabs();
  }

  Future<void> _loadTabs() async {
    try {
      final r = await widget.session.api.get('/legal');
      if (!mounted || r is! List) return;
      setState(() => _tabs = r.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList());
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _fetch() async =>
      await widget.session.api.get('/legal/$_type') as Map<String, dynamic>;

  void _select(String type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _future = _fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          final d = snap.data;
          return Column(
            children: [
              BuHeader(title: context.l10n.profileLegalTitle, onBack: () => Navigator.pop(context)),
              if (_tabs.length > 1) ...[
                DestekChipRow(children: [
                  for (final d in _tabs)
                    DestekChip(
                      label: (d['title'] as String?) ?? (d['type'] as String? ?? ''),
                      selected: d['type'] == _type,
                      onTap: () => _select(d['type'] as String),
                    ),
                ]),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: snap.connectionState != ConnectionState.done
                    ? const LoadingView()
                    : snap.hasError
                        ? ErrorView(error: snap.error!, onRetry: () => setState(() {
                    _future = _fetch();
                  }))
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                            children: [
                              _meta(context, d!),
                              Padding(
                                padding: const EdgeInsets.only(top: 14, bottom: 6),
                                child: Text((d['title'] as String?) ?? context.l10n.profileLegalDocFallback,
                                    style: BuType.title.copyWith(color: t.ink, fontSize: 22, letterSpacing: -.4)),
                              ),
                              // Başlık/alıntı/tablo/kalın destekli Markdown; HTML yorumlanmaz.
                              SimpleMarkdown((d['content'] as String?) ?? ''),
                            ],
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Sürüm rozeti + yürürlük tarihi.
  Widget _meta(BuildContext context, Map<String, dynamic> d) {
    final t = context.bu;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final date = niceDate((d['effectiveAt'] ?? d['publishedAt']) as String?);
    return Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Container(
        constraints: const BoxConstraints(minHeight: 24),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          // Tasarımdaki mavi sürüm rozeti (.p-blue).
          color: dark ? const Color(0xFF1F2B4D) : const Color(0xFFE6ECFA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(context.l10n.profileVersion('${d['version']}'),
            style: BuType.micro.copyWith(
                color: dark ? const Color(0xFF9DB4F0) : const Color(0xFF2F4FA8), fontWeight: FontWeight.w700)),
      ),
      if (date.isNotEmpty)
        Text(context.l10n.destekEffective(date), style: BuType.caption.copyWith(color: t.mut)),
    ]);
  }
}

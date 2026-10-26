import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';

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
    setState(() => _future = _fetch());
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
          BuHeader(title: 'Sözleşmeler', onBack: () => Navigator.pop(context)),
          Expanded(
            child: FutureBuilder(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const LoadingView();
                if (snap.hasError) {
                  return ErrorView(error: snap.error!, onRetry: () => setState(() => _future = _fetch()));
                }
                final docs = snap.data!;
                if (docs.isEmpty) {
                  return const EmptyView(icon: LucideIcons.fileText, text: 'Yayımlanmış sözleşme yok.');
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
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(children: [
                                Icon(LucideIcons.fileText, size: 22, color: t.pr),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text((d['title'] as String?) ?? (d['type'] as String? ?? ''),
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.ink)),
                                    const SizedBox(height: 2),
                                    Text('Sürüm ${d['version']} · ${niceDate(d['publishedAt'] as String?)}',
                                        style: TextStyle(fontSize: 12, color: t.mut)),
                                  ]),
                                ),
                                Icon(LucideIcons.chevronRight, size: 18, color: t.mut),
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

class LegalDocPage extends StatefulWidget {
  const LegalDocPage({super.key, required this.session, required this.type});

  final Session session;
  final String type;

  @override
  State<LegalDocPage> createState() => _LegalDocPageState();
}

class _LegalDocPageState extends State<LegalDocPage> {
  late Future<Map<String, dynamic>> _future = _fetch();

  Future<Map<String, dynamic>> _fetch() async =>
      await widget.session.api.get('/legal/${widget.type}') as Map<String, dynamic>;

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
              BuHeader(title: (d?['title'] as String?) ?? 'Sözleşme', onBack: () => Navigator.pop(context)),
              Expanded(
                child: snap.connectionState != ConnectionState.done
                    ? const LoadingView()
                    : snap.hasError
                        ? ErrorView(error: snap.error!, onRetry: () => setState(() => _future = _fetch()))
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                            children: [
                              Text('Sürüm ${d!['version']} · ${niceDate(d['publishedAt'] as String?)}',
                                  style: TextStyle(fontSize: 13, color: t.mut)),
                              const SizedBox(height: 14),
                              BuCard(
                                padding: const EdgeInsets.all(18),
                                // Düz metin olarak çizilir: HTML/Markdown yorumlanmaz.
                                child: SelectableText((d['content'] as String?) ?? '',
                                    style: TextStyle(fontSize: 15, height: 1.6, color: t.ink)),
                              ),
                            ],
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

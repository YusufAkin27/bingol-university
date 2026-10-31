import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart';
import '../../widgets/simple_markdown.dart';

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
    final l = context.l10n;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: l.profileLegalTitle, onBack: () => Navigator.pop(context)),
          Expanded(
            child: FutureBuilder(
              future: _future,
              // Durum başına anahtarlı gövde: yükleniyor -> içerik geçişi yumuşak solmayla olur.
              builder: (context, snap) => BuFadeThrough(child: _body(context, snap)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, AsyncSnapshot<List<Map<String, dynamic>>> snap) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    if (snap.connectionState != ConnectionState.done) return const LoadingView(key: ValueKey('legal-loading'));
    if (snap.hasError) {
      // Yüklenemedi: satır kartı + "Yeniden dene".
      return ListView(
        key: const ValueKey('legal-error'),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [_FailedRow(onRetry: _refresh)],
      );
    }
    final docs = snap.data!;
    if (docs.isEmpty) {
      return ListView(
        key: const ValueKey('legal-empty'),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 64),
            child: Text(l.profileLegalEmpty, textAlign: TextAlign.center, style: tx.bodyLarge!.copyWith(color: t.mut)),
          ),
        ],
      );
    }
    return RefreshIndicator(
      key: const ValueKey('legal-list'),
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          // Stitch v3 "16": kart/ikon yok; düz satırlar + ince ayırıcı.
          for (var i = 0; i < docs.length; i++) ...[
            if (i > 0) Divider(height: 1, color: t.bd),
            _DocRow(
              doc: docs[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LegalDocPage(session: widget.session, type: docs[i]['type'] as String)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc, required this.onTap});

  final Map<String, dynamic> doc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((doc['title'] as String?) ?? (doc['type'] as String? ?? ''),
                        style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(_versionLine(context, doc), style: tx.bodySmall!.copyWith(color: t.mut)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(buDirIcon(context, LucideIcons.chevronRight), size: 20, color: t.mut),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Yüklenemedi, tekrar dene": kartsız, simgesiz tek muted cümle + metin düğmesi (Stitch v3 "16").
class _FailedRow extends StatelessWidget {
  const _FailedRow({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Text(context.l10n.p01LgLoadFailed, textAlign: TextAlign.center, style: tx.bodyLarge!.copyWith(color: t.mut)),
          const SizedBox(height: 8),
          BuButton(label: context.l10n.pickRetry, kind: BuButtonKind.text, compact: true, onPressed: onRetry),
        ],
      ),
    );
  }
}

String _ltr(String s) => s.isEmpty ? s : '\u2066$s\u2069';

/// "Sürüm 2 · 1 Ocak 2026"; yayın tarihi yoksa yalnız "Sürüm 2" (sondaki " ·" kalmaz).
String _versionLine(BuildContext context, Map<String, dynamic> d) {
  // Tarih parçası her dilde soldan sağa (LRI ... PDI): Arapça satırda bidi sırası bozulmasın.
  final date = _ltr(niceDate(d['publishedAt'] as String?));
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
  late Future<Map<String, dynamic>> _future = _fetch();

  Future<Map<String, dynamic>> _fetch() async =>
      await widget.session.api.get('/legal/${widget.type}') as Map<String, dynamic>;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Scaffold(
      backgroundColor: t.bg,
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          final d = snap.data;
          final date = d == null ? '' : _ltr(niceDate((d['effectiveAt'] ?? d['publishedAt']) as String?));
          return Column(
            children: [
              BuHeader(
                title: (d?['title'] as String?) ?? l.profileLegalTitle,
                subtitle: d == null
                    ? null
                    : (date.isEmpty ? l.profileVersion('${d['version']}') : l.p01LgMetaLine('${d['version']}', date)),
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: BuFadeThrough(
                  child: snap.connectionState != ConnectionState.done
                    ? const LoadingView(key: ValueKey('doc-loading'))
                    : snap.hasError
                        ? ListView(
                            key: const ValueKey('doc-error'),
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                            children: [
                              _FailedRow(onRetry: () => setState(() {
                                _future = _fetch();
                              })),
                            ],
                          )
                        : ListView(
                            key: const ValueKey('doc-ok'),
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                            children: [
                              // Kart yok (Stitch v3 "17"): metin doğrudan zeminde. Başlık/alıntı/tablo/kalın destekli Markdown; HTML yorumlanmaz.
                              SimpleMarkdown((d!['content'] as String?) ?? ''),
                            ],
                          ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

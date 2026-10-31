import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart';
import '../../widgets/simple_markdown.dart';

/// Belge türüne göre simge ve kategori rengi (Stitch 07 listesi: Kullanım Koşulları, Gizlilik, KVKK, Topluluk Kuralları).
(IconData, BuTint) _legalLook(BuildContext context, String type) {
  final t = context.bu;
  return switch (type) {
    'TERMS' => (LucideIcons.gavel, t.tint(BuTintId.blue)),
    'PRIVACY' => (LucideIcons.shield, t.tint(BuTintId.aqua)),
    'KVKK' => (LucideIcons.lockKeyhole, t.tint(BuTintId.aqua)),
    'COMMUNITY_RULES' => (LucideIcons.users, t.tint(BuTintId.green)),
    _ => (LucideIcons.fileText, t.tint(BuTintId.slate)),
  };
}

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
    final tx = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: l.profileLegalTitle, onBack: () => Navigator.pop(context)),
          Expanded(
            child: FutureBuilder(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const LoadingView();
                if (snap.hasError) {
                  // Yüklenemedi: satır kartı + "Yeniden dene".
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    children: [
                      _FailedRow(onRetry: _refresh),
                    ],
                  );
                }
                final docs = snap.data!;
                if (docs.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
                        decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(28), boxShadow: BuElevation.of(context, 1)),
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(24)),
                              child: Icon(LucideIcons.fileX, size: 36, color: t.mut),
                            ),
                            const SizedBox(height: 20),
                            Text(l.profileLegalEmpty,
                                textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    children: [
                      Container(
                        decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(28), boxShadow: BuElevation.of(context, 1)),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (var i = 0; i < docs.length; i++) ...[
                              if (i > 0) Divider(height: 1, indent: 20, endIndent: 20, color: t.bd),
                              _DocRow(
                                doc: docs[i],
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LegalDocPage(session: widget.session, type: docs[i]['type'] as String),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
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

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc, required this.onTap});

  final Map<String, dynamic> doc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final (icon, tint) = _legalLook(context, (doc['type'] as String?) ?? '');
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 88),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: tint.bg, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, size: 24, color: tint.fg),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((doc['title'] as String?) ?? (doc['type'] as String? ?? ''),
                        style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
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

/// "Yüklenemedi, tekrar dene" satır kartı.
class _FailedRow extends StatelessWidget {
  const _FailedRow({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    // Büyük yazı ölçeğinde düğme alt satıra iner (kelime ortadan bölünmesin).
    final large = MediaQuery.textScalerOf(context).scale(14) > 16;
    final icon = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
      child: Icon(LucideIcons.cloudOff, size: 22, color: t.pr),
    );
    final text = Text(context.l10n.p01LgLoadFailed, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700));
    final retry = BuButton(label: context.l10n.pickRetry, icon: LucideIcons.refreshCw, compact: true, onPressed: onRetry);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(24), boxShadow: BuElevation.of(context, 1)),
      child: large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [icon, const SizedBox(width: 12), Expanded(child: text)]),
                const SizedBox(height: 12),
                Align(alignment: AlignmentDirectional.centerEnd, child: retry),
              ],
            )
          : Row(children: [icon, const SizedBox(width: 12), Expanded(child: text), const SizedBox(width: 8), retry]),
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
                child: snap.connectionState != ConnectionState.done
                    ? const LoadingView()
                    : snap.hasError
                        ? ListView(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                            children: [
                              _FailedRow(onRetry: () => setState(() {
                                _future = _fetch();
                              })),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                            children: [
                              Container(
                                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                                decoration: BoxDecoration(
                                  color: t.sf,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: BuElevation.of(context, 1),
                                ),
                                // Başlık/alıntı/tablo/kalın destekli Markdown; HTML yorumlanmaz.
                                child: SimpleMarkdown((d!['content'] as String?) ?? ''),
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

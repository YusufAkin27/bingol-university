import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../home/home_parts.dart';
import 'icerik_parts.dart';
import 'news_tile.dart' show newsLocalDate;
import 'unit_news_models.dart';

/// Dış bağlantı açıcı (testlerde değiştirilir); açılabildiyse true.
typedef UnitNewsLinkOpener = Future<bool> Function(Uri uri);

Future<bool> _defaultOpener(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

/// Birim haberi detayı (`GET /news/unit/{id}`): kaynak adı, başlık, tarih, düz metin gövde (paragraflar), "Ekler" listesi
/// ve "Kaynakta aç". Ekler ve kaynak yalnız `https` dış bağlantı olarak açılır; dosya indirilmez/kopyalanmaz.
/// Liste satırındaki bilgiler (başlık, tarih, ekler) hemen gösterilir; gövde yüklenirken iskelet çıkar.
class UnitNewsDetailPage extends StatefulWidget {
  const UnitNewsDetailPage({super.key, required this.session, required this.item, this.opener = _defaultOpener});

  final Session session;
  final UnitNewsItem item;
  final UnitNewsLinkOpener opener;

  @override
  State<UnitNewsDetailPage> createState() => _UnitNewsDetailPageState();
}

class _UnitNewsDetailPageState extends State<UnitNewsDetailPage> {
  late Future<UnitNewsItem> _detail = UnitNewsApi(widget.session).detail(widget.item.id);

  Future<void> _open(String url) async {
    final l = context.l10n;
    final uri = Uri.tryParse(url);
    var ok = false;
    if (uri != null && uri.scheme == 'https') {
      try {
        ok = await widget.opener(uri);
      } catch (_) {
        ok = false;
      }
    }
    if (!ok && mounted) BuToast.show(context, l.unitNewsLinkFailed, kind: BuToastKind.error);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              IcerikIconButton(icon: buDirIcon(context, BuIcons.arrowLeft), label: l.commonBack, onTap: () => Navigator.pop(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l.unitNewsTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(color: t.ink)),
                ),
              ),
            ]),
          ),
          Expanded(
            child: FutureBuilder<UnitNewsItem>(
              future: _detail,
              builder: (context, snap) {
                final done = snap.connectionState == ConnectionState.done;
                final d = snap.data;
                // Detay gelince listedeki alanların üstüne yazar; ekler/URL gelmediyse listedekiler korunur.
                final n = widget.item;
                final attachments = (d != null && d.attachments.isNotEmpty) ? d.attachments : n.attachments;
                final url = d?.url ?? n.url;
                final source = d?.sourceName ?? n.sourceName;
                final unit = d?.unitName ?? n.unitName;
                final date = newsLocalDate(context, d?.publishedDate ?? n.publishedDate);
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.paddingOf(context).bottom + 32),
                  child: Align(
                    alignment: AlignmentDirectional.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if ((source ?? '').isNotEmpty)
                          Text(trUpper(source!), style: tx.labelMedium!.copyWith(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: .6, color: t.mut)),
                        if ((source ?? '').isNotEmpty) const SizedBox(height: 8),
                        Semantics(
                          header: true,
                          child: Text(d?.title ?? n.title, style: tx.headlineSmall!.copyWith(fontSize: 26, fontWeight: FontWeight.w700, height: 1.25, color: t.ink)),
                        ),
                        const SizedBox(height: 8),
                        Text([date, if ((unit ?? '').isNotEmpty) unit!].join(' · '), style: tx.bodySmall!.copyWith(fontSize: 13, color: t.mut)),
                        const SizedBox(height: 24),
                        if (!done)
                          const _BodySkeleton()
                        else if (snap.hasError)
                          IcerikErrorCard(
                            title: l.p05NewsErrorTitle,
                            retryLabel: l.commonRetry,
                            onRetry: () => setState(() {
                              _detail = UnitNewsApi(widget.session).detail(widget.item.id);
                            }),
                          )
                        else
                          _Body(text: d?.body ?? d?.summary ?? n.summary),
                        if (attachments.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Semantics(
                            header: true,
                            child: Text(l.unitNewsAttachments, style: BuType.title.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: t.ink)),
                          ),
                          const SizedBox(height: 8),
                          for (final a in attachments) ...[
                            _AttachmentRow(key: ValueKey('unit-attachment-${a.url}'), attachment: a, onTap: () => _open(a.url)),
                            const SizedBox(height: 8),
                          ],
                        ],
                        if (url != null && Uri.tryParse(url)?.scheme == 'https') ...[
                          const SizedBox(height: 16),
                          _SourceButton(key: const ValueKey('unit-open-source'), label: l.unitNewsOpenSource, onPressed: () => _open(url)),
                        ],
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

/// Düz metni paragraf paragraf gösterir (`\n\n` ile ayrılmış bloklar); metin yoksa boş kalır.
class _Body extends StatelessWidget {
  const _Body({required this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final paragraphs = (text ?? '').split(RegExp(r'\n\s*\n')).map((p) => p.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim()).where((p) => p.isNotEmpty).toList();
    if (paragraphs.isEmpty) return const SizedBox.shrink();
    final style = Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, color: t.ink);
    return SelectionArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < paragraphs.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == paragraphs.length - 1 ? 0 : 16),
            child: Text(paragraphs[i], style: style),
          ),
      ]),
    );
  }
}

class _BodySkeleton extends StatelessWidget {
  const _BodySkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: context.l10n.commonLoading,
      child: const ExcludeSemantics(
        child: BuSkeletonScope(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            BuSkeleton.line(height: 14),
            SizedBox(height: 10),
            BuSkeleton.line(height: 14),
            SizedBox(height: 10),
            BuSkeleton.line(width: 220, height: 14),
          ]),
        ),
      ),
    );
  }
}

/// Ek satırı: dosya simgesi + ad (en çok 2 satır) + tür etiketi + dış bağlantı simgesi; en az 56 dp, tümü dokunulur.
class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({super.key, required this.attachment, required this.onTap});

  final UnitNewsAttachment attachment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final a = attachment;
    return Semantics(
      button: true,
      label: l.unitNewsAttachmentOpen(a.name),
      excludeSemantics: true,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: HomeSurface(
          onTap: () {
            buHaptic(BuHaptic.selection);
            onTap();
          },
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Icon(BuIcons.fileText, size: 22, color: t.pr),
            const SizedBox(width: 12),
            Expanded(child: Text(a.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.body.copyWith(fontWeight: FontWeight.w500, color: t.ink))),
            if (a.type != 'OTHER') ...[
              const SizedBox(width: 8),
              Text(a.type, style: BuType.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: t.mut)),
            ],
            const SizedBox(width: 8),
            Icon(BuIcons.squareArrowOutUpRight, size: 18, color: t.mut),
          ]),
        ),
      ),
    );
  }
}

/// "Kaynakta aç": 48 dp, yüzey rengi, 1 dp çerçeve, ortalı metin (haber detayındaki düğmeyle aynı görünüm).
class _SourceButton extends StatelessWidget {
  const _SourceButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: BuPressable(
        scale: .98,
        onTap: () {
          buHaptic(BuHaptic.selection);
          onPressed();
        },
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: t.sf,
            borderRadius: BorderRadius.circular(BuRadius.md),
            border: Border.all(color: t.bdStrong),
          ),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: t.ink)),
        ),
      ),
    );
  }
}

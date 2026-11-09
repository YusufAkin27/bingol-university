import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/transfers/transfer_hub.dart';
import '../../core/transfers/transfer_job.dart';
import '../../core/transfers/transfer_queue.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import '../../widgets/bu_overlays.dart';
import 'compose_post_page.dart';
import 'post_api.dart';
import 'post_models.dart';
import 'post_transfer.dart';

/// Bekleyen gönderilerim: kuyruktaki (yükleniyor / sırada / bağlantı bekleniyor / paylaşılıyor) ve başarısız paylaşımlar
/// sahibinin ekranında sade bir durum satırı olarak görünür. Başkaları bu gönderileri GÖRMEZ: gönderi sunucuda yalnız
/// yükleme bitip yayımlanınca oluşur. "Paylaşıldı" yalnız sunucu sonucu (iş `published`) gelince gösterilir; o anda
/// [onPublished] gönderiyle çağrılır (akışa/profile eklemek için). Hata: yeniden dene / düzenle (metin ve dosyalar
/// kaybolmaz) / sil.
class PendingPostsStrip extends StatefulWidget {
  const PendingPostsStrip({super.key, required this.session, this.onPublished, this.queue});

  final Session session;
  final void Function(Post post)? onPublished;

  /// Testler için: kuyruk enjeksiyonu (varsayılan [TransferHub] kuyruğu).
  final TransferQueue? queue;

  @override
  State<PendingPostsStrip> createState() => _PendingPostsStripState();
}

class _PendingPostsStripState extends State<PendingPostsStrip> {
  /// Aynı yayımlanan iş için tek gönderi çekimi + tek "Paylaşıldı" bildirimi (Keşfet ve Profil şeritleri birlikte açıkken).
  static final Map<String, Future<Post?>> _handled = {};
  static final Set<String> _toasted = {};

  TransferQueue? _q;
  StreamSubscription<List<TransferJob>>? _sub;
  Timer? _poll;
  List<TransferJob> _jobs = const [];

  @override
  void initState() {
    super.initState();
    _bind();
    if (_q == null) {
      // Kuyruk oturum açılırken eşzamansız kurulur: hazır olunca bağlan.
      _poll = Timer.periodic(const Duration(seconds: 1), (t) {
        _bind();
        if (_q != null) t.cancel();
      });
    }
  }

  void _bind() {
    final q = widget.queue ?? TransferHub.instance.queue;
    if (q == null || identical(q, _q)) return;
    _sub?.cancel();
    _q = q;
    _jobs = q.jobsFor(targetKey: kPostTransferTarget);
    _sub = q.watch(targetKey: kPostTransferTarget).listen(_onJobs);
    _scan(_jobs);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _poll?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  void _onJobs(List<TransferJob> jobs) {
    if (!mounted) return;
    _scan(jobs);
    setState(() => _jobs = jobs);
  }

  void _scan(List<TransferJob> jobs) {
    for (final j in jobs) {
      if (j.status != TransferStatus.published) continue;
      final fut = _handled.putIfAbsent(j.id, () => _fetch(j));
      unawaited(fut.then((p) {
        if (p != null && mounted) widget.onPublished?.call(p);
      }));
    }
  }

  Future<Post?> _fetch(TransferJob j) async {
    Post? post;
    final id = int.tryParse(j.publishedRef ?? '');
    if (id != null) {
      try {
        post = await PostApi(widget.session).get(id);
      } catch (_) {
        post = null; // gönderi yayımlandı; yalnız akışa eklenemedi (bir sonraki yenilemede gelir)
      }
    }
    if (mounted && _toasted.add(j.id)) BuToast.show(context, context.l10n.postComposeShared);
    // Diğer şeritler de görsün diye kısa süre sonra kayıt kaldırılır.
    Future<void>.delayed(const Duration(seconds: 4), () => _q?.dismiss(j.id));
    return post;
  }

  Future<void> _confirmRemove(TransferJob j) async {
    final l = context.l10n;
    final ok = await BuConfirmSheet.show(context,
        title: l.g2PostRemoveTitle, message: l.g2PostRemoveBody, confirmLabel: l.g2PostRemove, cancelLabel: l.commonCancel, destructive: true);
    if (!ok) return;
    final q = _q;
    if (q == null) return;
    if (j.status.isLive) {
      await q.cancel(j.id);
    }
    await q.dismiss(j.id);
  }

  void _edit(TransferJob j) {
    Navigator.of(context).push<Object?>(MaterialPageRoute(
      settings: const RouteSettings(name: 'compose_post'),
      fullscreenDialog: true,
      builder: (_) => ComposePostPage(session: widget.session, restoreJobId: j.id, transferQueue: _q),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final shown = [for (final j in _jobs) if (j.status.isLive || j.status == TransferStatus.failed) j];
    if (shown.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(BuSpace.page, 0, BuSpace.page, BuSpace.md),
      child: Column(
        key: const ValueKey('pendingPosts'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final j in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PendingRow(
                key: ValueKey('pending-${j.id}'),
                job: j,
                onCancel: () => _confirmRemove(j),
                onRetry: () => _q?.retry(j.id),
                onEdit: () => _edit(j),
              ),
            ),
        ],
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({super.key, required this.job, required this.onCancel, required this.onRetry, required this.onEdit});

  final TransferJob job;
  final VoidCallback onCancel, onRetry, onEdit;

  String _status(AppLocalizations l) {
    switch (job.status) {
      case TransferStatus.active:
        final f = job.fraction;
        return l.g2PostUploading(f == null ? '' : '${(f * 100).round()}%').trim();
      case TransferStatus.waitingNetwork:
        return l.g2PostWaiting;
      case TransferStatus.processing:
        return l.g2PostPublishing;
      case TransferStatus.failed:
        return l.g2PostFailed;
      default:
        return l.g2PostQueued;
    }
  }

  Widget _thumb(BuTokens t) {
    File? f;
    try {
      final dir = PostPayload.dirOf(job).path;
      final poster = File('$dir${Platform.pathSeparator}poster.jpg');
      if (poster.existsSync()) {
        f = poster;
      } else if (job.mime.startsWith('image/')) {
        f = File(job.localPath);
      }
    } catch (_) {
      f = null;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(BuRadius.sm),
      child: SizedBox(
        width: 48,
        height: 48,
        child: f == null || !f.existsSync()
            ? ColoredBox(color: t.sf2, child: Icon(job.mime.startsWith('video/') ? BuIcons.video : BuIcons.image, color: t.mut, size: 22))
            : Image.file(f, fit: BoxFit.cover, cacheWidth: 144, gaplessPlayback: true, excludeFromSemantics: true, errorBuilder: (_, __, ___) => ColoredBox(color: t.sf2)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final failed = job.status == TransferStatus.failed;
    final frac = job.status == TransferStatus.active ? job.fraction : null;
    final showBar = !failed;
    // Sunucu açıkça reddetti (ör. uygunsuz ifade): aynı içerikle yeniden denemek anlamsız, önce düzenlenir.
    final editFirst = failed && !job.lastRetryable;
    return Semantics(
      container: true,
      liveRegion: true,
      label: _status(l),
      child: DecoratedBox(
        decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.md), border: Border.all(color: t.bd)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              _thumb(t),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (failed) ...[Icon(BuIcons.circleAlert, size: 16, color: t.danger), const SizedBox(width: 6)],
                    Flexible(child: Text(_status(l), style: tx.bodyMedium?.copyWith(color: failed ? t.danger : t.ink))),
                  ]),
                  if (failed) ...[
                    const SizedBox(height: 2),
                    Text(postFailureText(job, l), key: const ValueKey('pendingError'), style: tx.bodySmall?.copyWith(color: t.mut)),
                  ],
                  if (showBar)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        // value null = belirsiz ilerleme (toplam bilinmiyor / sunucu işliyor / bekleniyor): yüzde uydurulmaz
                        child: LinearProgressIndicator(value: frac, minHeight: 3, color: t.ink, backgroundColor: t.bd),
                      ),
                    ),
                ]),
              ),
            ]),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(spacing: 4, children: [
                if (!failed) _action(t, 'pendingCancel', l.g2PostCancel, onCancel),
                if (failed && !editFirst) _action(t, 'pendingRetry', l.g2PostRetry, onRetry),
                if (failed) _action(t, 'pendingEdit', l.g2PostEdit, onEdit),
                if (failed) _action(t, 'pendingRemove', l.g2PostRemove, onCancel),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _action(BuTokens t, String key, String label, VoidCallback onTap) => TextButton(
        key: ValueKey(key),
        onPressed: onTap,
        style: TextButton.styleFrom(minimumSize: const Size(BuSize.touch, BuSize.touch), foregroundColor: t.ink),
        child: Text(label),
      );
}

import 'package:flutter/material.dart';

import '../theme.dart';
import 'transfer_job.dart';
import 'transfer_queue.dart';

/// Durum metinleri (çağıran yerelleştirir; varsayılan Türkçe). Durumlar ayrıdır: "Gönderildi/Paylaşıldı" yalnız
/// [published] için (sunucu doğruladı) gösterilir.
class TransferTexts {
  const TransferTexts({
    this.title = 'Aktarımlar',
    this.preparing = 'Hazırlanıyor',
    this.queued = 'Sırada',
    this.uploading = 'Yükleniyor',
    this.downloading = 'İndiriliyor',
    this.waiting = 'Bağlantı bekleniyor',
    this.processing = 'Sunucuda işleniyor',
    this.published = 'Yayımlandı',
    this.failed = 'Hata',
    this.canceled = 'İptal edildi',
    this.cancel = 'İptal',
    this.retry = 'Yeniden dene',
    this.dismiss = 'Kaldır',
    this.empty = 'Aktif aktarım yok',
  });

  final String title, preparing, queued, uploading, downloading, waiting, processing, published, failed, canceled;
  final String cancel, retry, dismiss, empty;

  String statusOf(TransferJob j) {
    switch (j.status) {
      case TransferStatus.preparing:
        return preparing;
      case TransferStatus.queued:
        return queued;
      case TransferStatus.active:
        return j.direction == TransferDirection.download ? downloading : uploading;
      case TransferStatus.waitingNetwork:
        return waiting;
      case TransferStatus.processing:
        return processing;
      case TransferStatus.published:
        return published;
      case TransferStatus.failed:
        return failed;
      case TransferStatus.canceled:
        return canceled;
    }
  }
}

/// "Aktarımlar" alanı: aktif iş sayısı, her işin durumu, iptal / yeniden dene. Veri TEK kaynaktan ([TransferQueue.watch]).
/// Yüzde yalnız toplam bayt biliniyorsa gösterilir; aksi halde belirsiz ilerleme çizgisi.
class TransfersList extends StatelessWidget {
  const TransfersList({super.key, required this.queue, this.targetKey, this.texts = const TransferTexts()});

  final TransferQueue queue;
  final String? targetKey;
  final TransferTexts texts;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TransferJob>>(
      stream: queue.watch(targetKey: targetKey),
      initialData: queue.jobsFor(targetKey: targetKey),
      builder: (context, snap) {
        final jobs = snap.data ?? const <TransferJob>[];
        final live = jobs.where((j) => j.status.isLive).length;
        final bu = context.bu;
        final theme = Theme.of(context).textTheme;
        if (jobs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(texts.empty, style: theme.bodyMedium?.copyWith(color: bu.mut)),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('${texts.title} ($live)', style: theme.titleSmall?.copyWith(color: bu.ink)),
            ),
            for (final j in jobs) _Row(job: j, queue: queue, texts: texts),
          ],
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.job, required this.queue, required this.texts});
  final TransferJob job;
  final TransferQueue queue;
  final TransferTexts texts;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final theme = Theme.of(context).textTheme;
    final s = job.status;
    final frac = s == TransferStatus.active ? job.fraction : null;
    final pct = frac == null ? '' : ' ${(frac * 100).round()}%';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${texts.statusOf(job)}$pct',
                    style: theme.bodyMedium?.copyWith(color: s == TransferStatus.failed ? bu.danger : bu.ink)),
                if (s == TransferStatus.active || s == TransferStatus.processing || s == TransferStatus.waitingNetwork)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    // value null = belirsiz ilerleme: toplam bilinmiyor / sunucu işliyor -> yüzde uydurulmaz
                    child: LinearProgressIndicator(value: s == TransferStatus.active ? frac : null, minHeight: 3),
                  ),
              ],
            ),
          ),
          if (s.isLive)
            TextButton(onPressed: () => queue.cancel(job.id), child: Text(texts.cancel))
          else if (s == TransferStatus.failed) ...[
            TextButton(onPressed: () => queue.retry(job.id), child: Text(texts.retry)),
            TextButton(onPressed: () => queue.dismiss(job.id), child: Text(texts.dismiss)),
          ] else
            TextButton(onPressed: () => queue.dismiss(job.id), child: Text(texts.dismiss)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/typography.dart';

/// 2026-10-26 -> 26.10.2026
String fmtDate(String? iso) {
  if (iso == null) return '';
  final d = iso.length >= 10 ? iso.substring(0, 10) : iso;
  final p = d.split('-');
  return p.length == 3 ? '${p[2]}.${p[1]}.${p[0]}' : iso;
}

const _months = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];
const _weekdays = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];

/// "26 Ekim, Pazartesi"
String longDate(DateTime d) => '${d.day} ${_months[d.month - 1]}, ${_weekdays[d.weekday - 1]}';

/// "26 Ekim 2026" (ISO tarih ya da zaman damgasından)
String niceDate(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  return d == null ? fmtDate(iso) : '${d.day} ${_months[d.month - 1]} ${d.year}';
}

String relativeTime(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'şimdi';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
  if (diff.inHours < 24) return '${diff.inHours} sa önce';
  if (diff.inDays < 7) return '${diff.inDays} gün önce';
  return niceDate(iso);
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

/// Hata durumu + yeniden dene. Ağ hatası da sunucu hatası da aynı kalıp.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(errorText(error),
                textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(160, 44)),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Yeniden dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Kaynak site bakımdaysa listenin üstünde gösterilen uyarı (hata ekranı değil: eski veri sunulur).
class StaleBanner extends StatelessWidget {
  const StaleBanner({super.key, required this.text, this.icon = Icons.construction});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: cs.primaryContainer,
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: BuType.caption.copyWith(color: cs.onPrimaryContainer, height: 1.3)),
          ),
        ],
      ),
    );
  }
}

/// Haber/duyuru/etkinlik rozeti: koyu zemin, açık yazı (web `--badge`).
class TypeBadge extends StatelessWidget {
  const TypeBadge(this.type, {super.key});

  final String? type;

  static String label(String? t) => switch (t) {
        'HABER' => 'Haber',
        'DUYURU' => 'Duyuru',
        'ETKINLIK' => 'Etkinlik',
        _ => t ?? '',
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEvent = type == 'ETKINLIK';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isEvent ? cs.primaryContainer : cs.secondary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label(type),
        style: BuType.micro.copyWith(color: isEvent ? cs.onPrimaryContainer : cs.onSecondary),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// Haber küçük resmi; yüklenemezse sessizce boş kutu.
class NewsThumb extends StatelessWidget {
  const NewsThumb(this.url, {super.key, this.width = 84, this.height = 84, this.radius = 10});

  final String? url;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(Icons.image_outlined, color: cs.onSurfaceVariant),
    );
    if (url == null || url!.isEmpty) return box;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => box,
        loadingBuilder: (_, child, p) => p == null ? child : box,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/locale_controller.dart';
import '../l10n/app_localizations.dart';
import '../core/session.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/typography.dart';
import 'bu_widgets.dart' show LucideIcons;
import 'sistem_widgets.dart';

/// 2026-10-26 -> 26.10.2026
String fmtDate(String? iso) {
  if (iso == null) return '';
  final d = iso.length >= 10 ? iso.substring(0, 10) : iso;
  final p = d.split('-');
  return p.length == 3 ? '${p[2]}.${p[1]}.${p[0]}' : iso;
}

AppLocalizations _loc(BuildContext? c) => c?.l10n ?? lookupAppLocalizations(const Locale('tr'));

List<String> _monthNames(AppLocalizations l) => [
      l.commonMonth1, l.commonMonth2, l.commonMonth3, l.commonMonth4, l.commonMonth5, l.commonMonth6,
      l.commonMonth7, l.commonMonth8, l.commonMonth9, l.commonMonth10, l.commonMonth11, l.commonMonth12,
    ];

List<String> _weekdayNames(AppLocalizations l) => [
      l.commonWeekday1, l.commonWeekday2, l.commonWeekday3, l.commonWeekday4,
      l.commonWeekday5, l.commonWeekday6, l.commonWeekday7,
    ];

/// "26 Ekim, Pazartesi" ([context] verilirse dile göre; yoksa Türkçe)
String longDate(DateTime d, {BuildContext? context}) {
  final l = _loc(context);
  return l.commonLongDate(d.day.toString(), _monthNames(l)[d.month - 1], _weekdayNames(l)[d.weekday - 1]);
}

/// "26 Ekim 2026" (ISO tarih ya da zaman damgasından)
String niceDate(String? iso, {BuildContext? context}) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  return d == null ? fmtDate(iso) : '${d.day} ${_monthNames(_loc(context))[d.month - 1]} ${d.year}';
}

String relativeTime(String? iso, {BuildContext? context}) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  final l = _loc(context);
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return l.commonJustNow;
  if (diff.inMinutes < 60) return l.commonMinutesAgo(diff.inMinutes.toString());
  if (diff.inHours < 24) return l.commonHoursAgo(diff.inHours.toString());
  if (diff.inDays < 7) return l.commonDaysAgo(diff.inDays.toString());
  return niceDate(iso, context: context);
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => Center(
      child: Semantics(
          label: context.l10n.commonLoading, child: const CircularProgressIndicator()));
}

/// Hata/boş görünümü: sınırlı yükseklikte ortalar, sığmazsa (320 dp + büyük yazı) kaydırır;
/// sınırsız yükseklikte (ListView içinde) düz ortalar.
class _FitCenter extends StatelessWidget {
  const _FitCenter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => c.hasBoundedHeight
            ? SingleChildScrollView(
                child: ConstrainedBox(constraints: BoxConstraints(minHeight: c.maxHeight), child: Center(child: child)))
            : Center(child: child),
      );
}

/// Hata durumu + yeniden dene (Sm3 / Sm8). Ağ hatası "Bağlantı yok", diğerleri "Bir şeyler ters gitti" başlığı alır.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final net = error is ApiError && (error as ApiError).isNetwork;
    return _FitCenter(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SistemTile(icon: net ? LucideIcons.wifiOff : LucideIcons.triangleAlert, size: 64, radius: 22, iconSize: 28),
            const SizedBox(height: 12),
            Text(net ? context.l10n.sistemuiOfflineTitle : context.l10n.sistemuiErrorTitle,
                textAlign: TextAlign.center, style: BuType.title.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(errorText(error),
                  textAlign: TextAlign.center, style: BuType.body.copyWith(color: t.mut, height: 1.5)),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 180),
              child: IntrinsicWidth(
                child: SistemButton(label: context.l10n.commonRetry, height: 48, radius: 16, onPressed: onRetry),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Boş durum (Sm7): ikon karosu + başlık. [title] verilirse [text] açıklama olur; [actionLabel] ile eylem düğmesi.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.text,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return _FitCenter(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SistemTile(icon: icon, size: 64, radius: 22, iconSize: 28),
            const SizedBox(height: 12),
            if (title != null) ...[
              Text(title!,
                  textAlign: TextAlign.center, style: BuType.heading.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(text, textAlign: TextAlign.center, style: BuType.body.copyWith(color: t.mut, height: 1.45)),
            ] else
              Text(text, textAlign: TextAlign.center, style: BuType.body.copyWith(color: t.mut, height: 1.45)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              SistemButton(label: actionLabel!, height: 44, radius: 14, onPressed: onAction),
            ],
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
  Widget build(BuildContext context) => MaintenanceBand(text: text, icon: icon);
}

/// Haber/duyuru/etkinlik rozeti: koyu zemin, açık yazı (web `--badge`).
class TypeBadge extends StatelessWidget {
  const TypeBadge(this.type, {super.key});

  final String? type;

  static String label(String? t, [BuildContext? context]) => switch (t) {
        'HABER' => _loc(context).commonTypeNews,
        'DUYURU' => _loc(context).commonTypeAnnouncement,
        'ETKINLIK' => _loc(context).commonTypeEvent,
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
        label(type, context),
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
        cacheWidth: width.isFinite ? (width * MediaQuery.devicePixelRatioOf(context)).ceil() : 800,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => box,
        loadingBuilder: (_, child, p) => p == null ? child : box,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/locale_controller.dart';
import '../l10n/app_localizations.dart';
import '../core/typography.dart';
import 'bu_illustrations.dart';
import 'bu_state.dart';
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

/// Hata durumu + yeniden dene (Sm3 / Sm8). Ağ hatası "Bağlantı yok", diğerleri "Bir şeyler ters gitti" başlığı alır.
/// P0: `BuErrorState` (çizili illüstrasyon + M3 düğme) için ince sarmalayıcı; imza korunur.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => BuErrorState(error: error, onRetry: onRetry);
}

/// Boş durum (Sm7): [icon] anlamına göre çizili illüstrasyon + başlık. [title] verilirse [text] açıklama olur;
/// [actionLabel] ile eylem düğmesi. P0: `BuEmptyState` için ince sarmalayıcı; imza korunur.
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

  static final Map<IconData, BuIllustration> _art = {
    LucideIcons.messageCircle: BuIllustration.message,
    LucideIcons.messageSquare: BuIllustration.message,
    LucideIcons.search: BuIllustration.search,
    LucideIcons.calendar: BuIllustration.calendar,
    LucideIcons.calendarDays: BuIllustration.calendar,
    LucideIcons.users: BuIllustration.club,
    LucideIcons.bell: BuIllustration.bell,
    LucideIcons.bellOff: BuIllustration.bell,
    LucideIcons.heart: BuIllustration.heart,
    LucideIcons.bookmark: BuIllustration.heart,
    LucideIcons.image: BuIllustration.image,
    LucideIcons.fileText: BuIllustration.document,
    LucideIcons.wifiOff: BuIllustration.wifiOff,
    LucideIcons.lock: BuIllustration.lock,
  };

  @override
  Widget build(BuildContext context) => BuEmptyState(
        illustration: _art[icon] ?? BuIllustration.box,
        title: title ?? text,
        message: title == null ? null : text,
        actionLabel: actionLabel,
        onAction: onAction,
      );
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

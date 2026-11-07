import '../l10n/app_localizations.dart';

/// Göreli zaman birimi.
enum RelUnit { now, minutes, hours, days, weeks, months, years }

/// Göreli yaş: birim + adet. Saat dilimi bağımsızdır (yalnız mutlak fark).
class RelAge {
  const RelAge(this.unit, this.n);
  final RelUnit unit;
  final int n;

  /// Eşikler: <1 dk şimdi, 1-59 dk, 1-23 sa, 1-6 gün, 1-4 hafta (<30 gün), 1-11 ay, 1+ yıl (>=365 gün).
  factory RelAge.between(DateTime then, DateTime now) {
    final d = now.difference(then);
    if (d.inMinutes < 1) return const RelAge(RelUnit.now, 0);
    if (d.inMinutes < 60) return RelAge(RelUnit.minutes, d.inMinutes);
    if (d.inHours < 24) return RelAge(RelUnit.hours, d.inHours);
    final days = d.inDays;
    if (days < 7) return RelAge(RelUnit.days, days);
    if (days < 30) return RelAge(RelUnit.weeks, days ~/ 7);
    if (days < 365) return RelAge(RelUnit.months, (days ~/ 30).clamp(1, 11));
    return RelAge(RelUnit.years, days ~/ 365);
  }
}

/// "25 dakika önce" / "1 hafta önce" (dile göre, çoğul ICU).
String relativeAgo(AppLocalizations l, DateTime then, {DateTime? now}) {
  final a = RelAge.between(then, now ?? DateTime.now());
  return switch (a.unit) {
    RelUnit.now => l.chatSeenAgoNow,
    RelUnit.minutes => l.chatSeenAgoMinutes(a.n),
    RelUnit.hours => l.chatSeenAgoHours(a.n),
    RelUnit.days => l.chatSeenAgoDays(a.n),
    RelUnit.weeks => l.chatSeenAgoWeeks(a.n),
    RelUnit.months => l.chatSeenAgoMonths(a.n),
    RelUnit.years => l.chatSeenAgoYears(a.n),
  };
}

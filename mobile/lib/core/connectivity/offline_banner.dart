import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/system/gate_views.dart' show TopStrip;
import '../../widgets/bu_widgets.dart' show LucideIcons;
import '../locale_controller.dart' show L10nContext;
import '../theme.dart';
import '../outbox/outbox.dart';
import 'connectivity_service.dart';

/// Uygulama kökü sarmalayıcısı: bekleyen (çevrimdışı kuyruğa alınmış) mesaj varsa ince bir şerit gösterir.
/// "Çevrimdışısınız" şeridi zaten [AppGate]'te vardır; burada tekrarlanmaz.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.outbox, required this.connectivity, required this.child});

  final Outbox outbox;
  final ConnectivityService connectivity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([outbox, connectivity]),
      builder: (context, _) {
        final pending = outbox.pendingCount;
        if (pending == 0) return child;
        final l = context.l10n;
        final offline = !connectivity.online;
        final text = offline
            ? l.cevrimdisiBekleyenMesaj(pending.toString())
            : l.cevrimdisiGonderiliyor(pending.toString());
        return Column(
          children: [
            Material(
              color: Colors.transparent,
              child: SafeArea(
                bottom: false,
                child: TopStrip(
                  icon: LucideIcons.refreshCw,
                  text: text,
                  actionLabel: offline ? l.cevrimdisiYenidenDene : null,
                  onAction: offline ? outbox.drain : null,
                ),
              ),
            ),
            Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: child)),
          ],
        );
      },
    );
  }
}

/// Bayat veri etiketi: yalnızca [cachedAt] verilmişse (yanıt önbellekten geldiyse) "Son güncelleme: …" gösterir.
/// Aynı gün saat (14:32), eski veride gün + saat. Kullanım: `StaleLabel(cachedAt: res.fromCache ? res.cachedAt : null)`.
class StaleLabel extends StatelessWidget {
  const StaleLabel({super.key, required this.cachedAt, this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 4)});

  final DateTime? cachedAt;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final at = cachedAt?.toLocal();
    if (at == null) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final sameDay = at.year == now.year && at.month == now.month && at.day == now.day;
    final f = sameDay ? DateFormat.Hm(locale) : DateFormat.MMMd(locale).add_Hm();
    return Padding(
      padding: padding,
      child: Text(
        context.l10n.cevrimdisiSonGuncelleme(f.format(at)),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.bu.mut, fontWeight: FontWeight.w500),
      ),
    );
  }
}

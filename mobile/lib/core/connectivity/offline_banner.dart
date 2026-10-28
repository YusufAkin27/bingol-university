import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/system/gate_views.dart' show TopStrip;
import '../locale_controller.dart' show L10nContext;
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
                child: TopStrip(icon: offline ? Icons.schedule : Icons.send, text: text),
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
/// Kullanım: `StaleLabel(cachedAt: res.fromCache ? res.cachedAt : null)`.
class StaleLabel extends StatelessWidget {
  const StaleLabel({super.key, required this.cachedAt, this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 4)});

  final DateTime? cachedAt;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final at = cachedAt;
    if (at == null) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context).toString();
    final f = DateFormat.MMMd(locale).add_Hm();
    return Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 13, color: Theme.of(context).hintColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              context.l10n.cevrimdisiSonGuncelleme(f.format(at.toLocal())),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
            ),
          ),
        ],
      ),
    );
  }
}

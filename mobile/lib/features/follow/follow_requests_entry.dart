import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/requests_entry_row.dart';
import 'follow_requests_api.dart';
import 'follow_requests_page.dart';

/// Bildirimler ekranının üstündeki "Takip istekleri (n)" satırı. Sayıyı kendisi yükler; bekleyen istek yoksa ya da sayı
/// alınamazsa hiçbir şey çizmez. Ekrandan dönünce sayı yenilenir; [refresh] değişirse (çekerek yenile) yeniden yüklenir.
class FollowRequestsEntry extends StatefulWidget {
  const FollowRequestsEntry({super.key, required this.session, this.refresh = 0});

  final Session session;
  final int refresh;

  @override
  State<FollowRequestsEntry> createState() => _FollowRequestsEntryState();
}

class _FollowRequestsEntryState extends State<FollowRequestsEntry> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(FollowRequestsEntry old) {
    super.didUpdateWidget(old);
    if (old.refresh != widget.refresh) _load();
  }

  Future<void> _load() async {
    try {
      final n = await FollowRequestsApi(widget.session).count();
      if (mounted && n != null && n != _count) setState(() => _count = n);
    } catch (_) {
      // Sayı alınamazsa satır gizli kalır; bildirimler çalışmaya devam eder.
    }
  }

  Future<void> _open() async {
    await openFollowRequests(context, widget.session);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_count <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RequestsEntryRow(
        key: const ValueKey('follow-requests-entry'),
        icon: BuIcons.userPlus,
        label: context.l10n.frqReqRow('$_count'),
        onTap: _open,
      ),
    );
  }
}

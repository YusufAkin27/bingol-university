import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../clubs/clubs_widgets.dart' show ClubPageHeader, ClubsLogo;
import 'etkinlik2_qr_page.dart';
import 'etkinlik2_widgets.dart';
import '../../core/academic_catalog.dart';

enum _Filter { all, present, absent }

/// Katılımcılar ve yoklama (organizatör): özet, Hepsi/Geldi/Gelmedi süzgeci, elle yoklama anahtarı.
class Etkinlik2AttendancePage extends StatefulWidget {
  const Etkinlik2AttendancePage({super.key, required this.session, required this.event, this.fromQr = false});

  /// QR sayfasından açıldıysa QR düğmesi geri döner; değilse QR sayfasını açar.
  final bool fromQr;

  final Session session;
  final Map<String, dynamic> event;

  @override
  State<Etkinlik2AttendancePage> createState() => _Etkinlik2AttendancePageState();
}

class _Etkinlik2AttendancePageState extends State<Etkinlik2AttendancePage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  Object? _error;
  _Filter _filter = _Filter.all;
  final _busy = <int>{};

  int get _id => (widget.event['id'] as num).toInt();

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// [silent]: çekerek yenilemede iskelet göstermeden arka planda yükler.
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final r = await widget.session.api.get('/events/$_id/attendance');
      if (!mounted) return;
      setState(() {
        _rows = (r is List ? r : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent && _rows.isNotEmpty) {
        BuToast.show(context, errorText(e), kind: BuToastKind.error);
        return;
      }
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  int _uid(Map<String, dynamic> r) => (r['userId'] as num).toInt();

  /// İyimser güncelleme; hata olursa geri alınır. Başarıda alt bildirim ("... yoklamaya eklendi (Elle)").
  Future<void> _mark(Map<String, dynamic> r, bool present) async {
    final id = _uid(r);
    if (_busy.contains(id)) return;
    final before = r['present'] == true;
    final beforeMethod = r['method'];
    final l = context.l10n;
    final name = '${r['displayName'] ?? ''}';
    setState(() {
      _busy.add(id);
      r['present'] = present;
      r['method'] = present ? 'MANUAL' : null;
    });
    try {
      await widget.session.api.put('/events/$_id/attendance/$id', {'present': present});
      if (mounted) {
        BuToast.show(context, present ? l.p16AttMarkedToast(name, l.etkinlik2MethodManual) : l.p16AttUnmarkedToast(name),
            kind: BuToastKind.success);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        r['present'] = before;
        r['method'] = beforeMethod;
      });
      BuToast.show(context, errorText(e), kind: BuToastKind.error);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  void _showQr() {
    if (widget.fromQr) {
      Navigator.pop(context);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => Etkinlik2QrPage(session: widget.session, event: widget.event)));
    }
  }

  List<Map<String, dynamic>> get _shown => _rows.where((r) {
        final p = r['present'] == true;
        return switch (_filter) {
          _Filter.all => true,
          _Filter.present => p,
          _Filter.absent => !p,
        };
      }).toList();

  String _sub(Map<String, dynamic> r) {
    final l = context.l10n;
    final parts = <String>[];
    final dep = r['department'] as String?;
    if (dep != null && dep.isNotEmpty) parts.add(context.departmentName(dep, faculty: r['faculty'] as String?));
    if ((widget.event['createdBy'] as num?)?.toInt() == _uid(r)) parts.add(l.etkinlik2Organizer);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final hasData = _rows.isNotEmpty;
    final shown = _shown;
    final total = _rows.length;
    final present = _rows.where((r) => r['present'] == true).length;
    final Widget body;
    if (_error != null && !hasData) {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Et2ErrorRow(key: const ValueKey('et2-att-error'), title: l.etkinlik2MarkFailed, sub: errorText(_error!), retryLabel: l.commonRetry, onRetry: _load),
      );
    } else if (!hasData) {
      body = Padding(
        key: const ValueKey('et2-att-empty'),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.etkinlik2AttendanceEmpty, style: tx.titleMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: t.ink)),
          const SizedBox(height: 4),
          Text(l.p16AttEmptyBody, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.4)),
        ]),
      );
    } else {
      body = BuStaggerScope(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(children: [
              Expanded(
                child: Text(l.p51EvPresentAbsent('$present', '${total - present}'),
                    key: const ValueKey('et2-att-summary'), style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: t.mut)),
              ),
              Text(l.p51EvTotalPeople('$total'), style: tx.bodySmall!.copyWith(color: t.mut)),
            ]),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Et2ErrorRow(key: const ValueKey('et2-att-error'), title: l.etkinlik2MarkFailed, sub: errorText(_error!), retryLabel: l.commonRetry, onRetry: _load),
            ),
          _filters(context),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(l.p16AttFilterEmptyBody, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.4)),
            ),
          for (var i = 0; i < shown.length; i++) BuStaggerItem(index: i, child: _row(context, shown[i])),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, top: 8),
              child: TextButton(
                key: const ValueKey('et2-show-qr'),
                style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48)),
                onPressed: _showQr,
                child: Text(l.etkinlik2ShowQrSem, style: tx.bodyLarge!.copyWith(color: t.pr, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ]),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        ClubPageHeader(title: l.etkinlik2AttendanceLabel),
        Expanded(
          child: BuSwapIn(
            loading: _loading,
            skeleton: const SingleChildScrollView(primary: false, physics: NeverScrollableScrollPhysics(), child: _AttendanceSkeleton()),
            child: RefreshIndicator(
              onRefresh: () => _load(silent: true),
              child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 32), children: [body]),
            ),
          ),
        ),
      ]),
    );
  }

  /// Süzgeç çipleri (Hepsi | Geldi | Gelmedi): ortak çip biçimi, yatay kayar.
  Widget _filters(BuildContext context) {
    final l = context.l10n;
    final items = <(_Filter, String, String)>[
      (_Filter.all, l.etkinlik2FilterAll, 'et2-filter-all'),
      (_Filter.present, l.etkinlik2FilterPresent, 'et2-filter-present'),
      (_Filter.absent, l.etkinlik2FilterAbsent, 'et2-filter-absent'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (c, i) => BuChip(key: ValueKey(items[i].$3), label: items[i].$2, selected: _filter == items[i].$1, onTap: () => setState(() => _filter = items[i].$1)),
        ),
      ),
    );
  }

  /// Yoklama satırı (kartsız): baş harf dairesi, ad, muted "15:12 · QR" / "Gelmedi", sağda anahtar (açık = marka).
  Widget _row(BuildContext context, Map<String, dynamic> r) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final name = '${r['displayName'] ?? ''}';
    final extra = _sub(r);
    final present = r['present'] == true;
    final method = r['method'];
    final uid = _uid(r);
    final at = DateTime.tryParse('${r['checkedInAt'] ?? r['presentAt'] ?? ''}')?.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final how = !present
        ? '— · ${l.etkinlik2FilterAbsent}'
        : [if (at != null) '${two(at.hour)}:${two(at.minute)}', if (method == 'QR') l.etkinlik2MethodQr else l.etkinlik2MethodManual].join(' · ');
    final sub = [how, if (extra.isNotEmpty) extra].join(' · ');
    return Container(
      key: ValueKey('et2-att-$uid'),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsetsDirectional.fromSTEB(0, 10, 0, 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
      child: Row(children: [
        ClubsLogo(name: name, id: uid, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w500, color: present ? t.ink : t.mut)),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 13)),
          ]),
        ),
        Et2Toggle(
          key: ValueKey('et2-mark-$uid'),
          thumbCheck: false,
          value: present,
          label: l.etkinlik2MarkSem(name),
          onChanged: _busy.contains(uid) ? null : (v) => _mark(r, v),
        ),
      ]),
    );
  }
}

/// Yoklama iskeleti (kartsız): özet satırı + satırlar.
class _AttendanceSkeleton extends StatelessWidget {
  const _AttendanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return BuSkeletonScope(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const BuSkeleton.line(width: 180, height: 14),
          const SizedBox(height: 20),
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Row(children: [
                BuSkeleton.circle(40),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    BuSkeleton.line(width: 130),
                    SizedBox(height: 8),
                    BuSkeleton.line(width: 90, height: 10),
                  ]),
                ),
                BuSkeleton(width: 48, height: 28, radius: 14),
              ]),
            ),
        ]),
      ),
    );
  }
}

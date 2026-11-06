import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/analytics.dart';
import '../../core/academic_catalog.dart';
import '../../core/locale_controller.dart';
import '../../core/permissions/ensure_permission.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../clubs/clubs_widgets.dart' show ClubOutlineButton, ClubPageHeader, ClubTextTabs;
import 'etkinlik2_widgets.dart';
import 'etkinlik3_scan_page.dart';

/// Yoklama satırının durumu: PRESENT (geldi) | ABSENT (gelmedi) | NONE (bekliyor).
/// Yeni sunucu `status` döner; eski biçimde (`present` + `method`) türetilir.
String attendanceStatusOf(Map<String, dynamic> r) {
  final s = r['status'];
  if (s == 'PRESENT' || s == 'ABSENT' || s == 'NONE') return s as String;
  if (r['present'] == true) return 'PRESENT';
  return r['method'] != null ? 'ABSENT' : 'NONE';
}

enum _Filter { all, pending, present, absent }

/// Yoklama aracı (sahip / `TAKE_ATTENDANCE` ya da `VIEW_ATTENDEES` moderatör): tek ekranda QR okutma girişi,
/// onaylı katılımcıların yoklama listesi (Bekliyor / Geldi / Gelmedi), elle işaretleme, toplu işlem ve canlı sayaç.
/// Birden çok okutucu aynı anda çalışabilir; liste 15 sn'de bir sessizce, çekerek de yenilenir.
class Etkinlik2AttendancePage extends StatefulWidget {
  const Etkinlik2AttendancePage({
    super.key,
    required this.session,
    required this.event,
    this.canTake = true,
    this.refreshEvery = const Duration(seconds: 15),
    this.scannerBuilder,
    this.permissionService,
  });

  final Session session;
  final Map<String, dynamic> event;

  /// false: yalnız `VIEW_ATTENDEES` (listeyi görür; okutamaz, işaretleyemez).
  final bool canTake;

  /// Sessiz yenileme aralığı (testte kısaltılır).
  final Duration refreshEvery;

  /// Yalnız test: okutma sayfasına iletilir.
  @visibleForTesting
  final Widget Function(BuildContext context, void Function(String code) onCode)? scannerBuilder;

  @visibleForTesting
  final PermissionService? permissionService;

  @override
  State<Etkinlik2AttendancePage> createState() => _Etkinlik2AttendancePageState();
}

class _Etkinlik2AttendancePageState extends State<Etkinlik2AttendancePage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  Object? _error;
  _Filter _filter = _Filter.all;
  String _query = '';
  final _search = TextEditingController();
  final _busy = <int>{};
  bool _bulkBusy = false;
  Timer? _timer;

  int get _id => (widget.event['id'] as num).toInt();

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(widget.refreshEvery, (_) {
      if (mounted && !_loading && _busy.isEmpty && !_bulkBusy) _load(silent: true, quiet: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// [silent]: iskelet göstermeden arka planda yükler. [quiet]: hata olursa uyarı göstermez (periyodik yenileme).
  Future<void> _load({bool silent = false, bool quiet = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final r = await widget.session.api.get('/events/$_id/attendance/roster');
      if (!mounted) return;
      final raw = r is Map ? r['rows'] : r;
      setState(() {
        _rows = (raw is List ? raw : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent && _rows.isNotEmpty) {
        if (!quiet) BuToast.show(context, errorText(e), kind: BuToastKind.error);
        return;
      }
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  int _uid(Map<String, dynamic> r) => (r['userId'] as num).toInt();

  /// Sayaç kapsamı: onaylı katılımcılar (RSVP'siz, kaydı olmayan satır sayılmaz).
  Iterable<Map<String, dynamic>> get _counted => _rows.where((r) {
        final rsvp = r['rsvpStatus'];
        return rsvp == null || rsvp == 'GOING' || attendanceStatusOf(r) != 'NONE';
      });

  int _count(String st) => _counted.where((r) => attendanceStatusOf(r) == st).length;

  /// İyimser güncelleme; hata olursa geri alınır.
  Future<void> _mark(Map<String, dynamic> r, String status) async {
    final id = _uid(r);
    if (_busy.contains(id) || !widget.canTake) return;
    final before = Map<String, dynamic>.from(r);
    final l = context.l10n;
    final name = '${r['displayName'] ?? ''}';
    setState(() {
      _busy.add(id);
      r['status'] = status;
      r['present'] = status == 'PRESENT';
      r['method'] = status == 'NONE' ? null : 'MANUAL';
      r['markedAt'] = status == 'NONE' ? null : DateTime.now().toUtc().toIso8601String();
      r['markedByName'] = null;
    });
    try {
      await widget.session.api.put('/events/$_id/attendance/$id', {'status': status});
      if (mounted) {
        BuToast.show(
            context,
            switch (status) {
              'PRESENT' => l.evtAtt2ToastPresent(name),
              'ABSENT' => l.evtAtt2ToastAbsent(name),
              _ => l.evtAtt2ToastReset(name),
            },
            kind: BuToastKind.success);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        r
          ..clear()
          ..addAll(before);
      });
      BuToast.show(context, errorText(e), kind: BuToastKind.error);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _pickStatus(Map<String, dynamic> r) async {
    if (!widget.canTake) return;
    final l = context.l10n;
    final name = '${r['displayName'] ?? ''}';
    final current = attendanceStatusOf(r);
    final choice = await BuSheet.show<String>(
      context,
      title: l.evtAtt2SheetTitle(name),
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _SheetOption(key: const ValueKey('att-opt-present'), icon: BuIcons.check, label: l.evtAtt2MarkPresent, selected: current == 'PRESENT', onTap: () => Navigator.pop(ctx, 'PRESENT')),
        _SheetOption(key: const ValueKey('att-opt-absent'), icon: BuIcons.circleX, label: l.evtAtt2MarkAbsent, selected: current == 'ABSENT', onTap: () => Navigator.pop(ctx, 'ABSENT')),
        _SheetOption(key: const ValueKey('att-opt-reset'), icon: BuIcons.rotateCcw, label: l.evtAtt2MarkReset, selected: current == 'NONE', onTap: () => Navigator.pop(ctx, 'NONE')),
      ]),
    );
    if (choice == null || choice == current || !mounted) return;
    await _mark(r, choice);
  }

  Future<void> _bulkRest() async {
    if (_bulkBusy || !widget.canTake) return;
    final pending = _count('NONE');
    if (pending == 0) return;
    final l = context.l10n;
    final ok = await BuConfirmSheet.show(
      context,
      title: l.evtAtt2BulkTitle,
      message: l.evtAtt2BulkBody('$pending'),
      confirmLabel: l.evtAtt2BulkRest,
      icon: BuIcons.userX,
    );
    if (!ok || !mounted) return;
    setState(() => _bulkBusy = true);
    try {
      final r = await widget.session.api.post('/events/$_id/attendance/bulk', {'status': 'ABSENT', 'rest': true});
      final n = r is Map ? (r['updated'] as num?)?.toInt() ?? pending : pending;
      if (!mounted) return;
      BuToast.show(context, l.evtAtt2BulkDone('$n'), kind: BuToastKind.success);
      await _load(silent: true);
    } catch (e) {
      if (mounted) BuToast.show(context, errorText(e), kind: BuToastKind.error);
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  Future<void> _openScanner() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'etkinlik3_scan'),
        builder: (_) => Etkinlik3ScanPage(
          session: widget.session,
          event: widget.event,
          fromList: true,
          scannerBuilder: widget.scannerBuilder,
          permissionService: widget.permissionService,
        ),
      ),
    );
    if (mounted) _load(silent: true, quiet: true);
  }

  List<Map<String, dynamic>> get _shown {
    final q = _query.trim().toLowerCase();
    return _rows.where((r) {
      final st = attendanceStatusOf(r);
      final okFilter = switch (_filter) {
        _Filter.all => true,
        _Filter.pending => st == 'NONE',
        _Filter.present => st == 'PRESENT',
        _Filter.absent => st == 'ABSENT',
      };
      if (!okFilter) return false;
      if (q.isEmpty) return true;
      return '${r['displayName'] ?? ''}'.toLowerCase().contains(q);
    }).toList();
  }

  String _sub(Map<String, dynamic> r) {
    final l = context.l10n;
    final parts = <String>[];
    final dep = r['department'] as String?;
    if (dep != null && dep.isNotEmpty) parts.add(context.departmentName(dep, faculty: r['faculty'] as String?));
    final st = attendanceStatusOf(r);
    if (st != 'NONE') {
      final at = DateTime.tryParse('${r['markedAt'] ?? ''}')?.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      final isQr = r['method'] == 'QR';
      if (st == 'PRESENT' && at != null) parts.add('${two(at.hour)}:${two(at.minute)}');
      parts.add(isQr ? l.evtAtt2SrcQr : l.evtAtt2SrcManual);
      final by = '${r['markedByName'] ?? ''}'.trim();
      if (by.isNotEmpty) parts.add(isQr ? l.evtAtt2ByScanner(by) : l.evtAtt2ByMarker(by));
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final hasData = _rows.isNotEmpty;
    final shown = _shown;
    final present = _count('PRESENT');
    final absent = _count('ABSENT');
    final pending = _count('NONE');
    final total = present + absent + pending;

    Widget header() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (hasData)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Semantics(
                  liveRegion: true,
                  child: Text(l.evtAtt2Counter('$present', '$absent', '$pending'),
                      key: const ValueKey('att-counter'), style: tx.bodyMedium!.copyWith(color: t.mut)),
                ),
                const SizedBox(height: 8),
                Et2Progress(fraction: total == 0 ? 0 : present / total, height: 4),
              ]),
            ),
          if (widget.canTake)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: BuButton(key: const ValueKey('att-scan'), label: l.evtAtt2ScanQr, icon: BuIcons.qrCode, onPressed: _openScanner),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(l.evtAtt2ViewOnly, key: const ValueKey('att-view-only'), style: tx.bodySmall!.copyWith(color: t.mut, height: 1.4)),
            ),
          if (hasData) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _SearchBox(
                key: const ValueKey('att-search'),
                controller: _search,
                hint: l.evtAtt2Search,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            _filters(context),
          ],
          if (_error != null && hasData)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Et2ErrorRow(key: const ValueKey('et2-att-error'), title: l.etkinlik2MarkFailed, sub: errorText(_error!), retryLabel: l.commonRetry, onRetry: _load),
            ),
          if (hasData && shown.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(_query.trim().isNotEmpty ? l.evtAtt2NoMatch : l.p16AttFilterEmptyBody,
                  key: const ValueKey('att-no-match'), style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.4)),
            ),
        ]);

    final Widget body;
    if (_error != null && !hasData) {
      body = ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), children: [
        Et2ErrorRow(key: const ValueKey('et2-att-error'), title: l.etkinlik2MarkFailed, sub: errorText(_error!), retryLabel: l.commonRetry, onRetry: _load),
      ]);
    } else if (!hasData) {
      body = ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
        header(),
        Padding(
          key: const ValueKey('et2-att-empty'),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.evtAtt2ListEmpty, style: tx.titleMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w400, color: t.ink)),
            const SizedBox(height: 4),
            Text(l.p16AttEmptyBody, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.4)),
          ]),
        ),
      ]);
    } else {
      body = CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: header()),
          SliverList.builder(itemCount: shown.length, itemBuilder: (c, i) => _row(c, shown[i])),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: widget.canTake && pending > 0
                  ? ClubOutlineButton(key: const ValueKey('att-bulk'), label: l.evtAtt2BulkRest, busy: _bulkBusy, onPressed: _bulkRest)
                  : null,
            ),
          ),
        ],
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        ClubPageHeader(title: l.evtAtt2ToolTitle),
        Expanded(
          child: BuSwapIn(
            loading: _loading,
            skeleton: const SingleChildScrollView(primary: false, physics: NeverScrollableScrollPhysics(), child: _AttendanceSkeleton()),
            child: RefreshIndicator(onRefresh: Analytics.pullRefresh(() => _load(silent: true)), child: body),
          ),
        ),
      ]),
    );
  }

  /// Süzgeç çipleri (Hepsi | Bekliyor | Geldi | Gelmedi): yatay kayar.
  Widget _filters(BuildContext context) {
    final l = context.l10n;
    const order = [_Filter.all, _Filter.pending, _Filter.present, _Filter.absent];
    // Metin sekmeleri (tasarım sistemi): seçili = marka metni + alt çizgi; dar ekranda yatay kayar.
    return Padding(
      key: const ValueKey('att-filters'),
      padding: const EdgeInsets.only(top: 8),
      child: ClubTextTabs(
        labels: [l.etkinlik2FilterAll, l.evtAtt2Pending, l.evtAtt2MarkPresent, l.evtAtt2MarkAbsent],
        index: order.indexOf(_filter),
        onChanged: (i) => setState(() => _filter = order[i]),
      ),
    );
  }

  /// Yoklama satırı: avatar, ad + ikincil bilgi (bölüm · saat · kaynak · kim), sağda nötr durum rozeti. Dokununca durum seçilir.
  Widget _row(BuildContext context, Map<String, dynamic> r) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final name = '${r['displayName'] ?? ''}';
    final st = attendanceStatusOf(r);
    final uid = _uid(r);
    final sub = _sub(r);
    final content = Container(
      constraints: const BoxConstraints(minHeight: 64),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsetsDirectional.fromSTEB(0, 10, 0, 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
      child: Row(children: [
        BuAvatar(name: name, url: r['avatarUrl']?.toString(), size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontWeight: BuType.emphasisWeight, color: st == 'ABSENT' ? t.mut : t.ink)),
            if (sub.isNotEmpty) Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 13)),
          ]),
        ),
        const SizedBox(width: 8),
        _StatusBadge(key: ValueKey('att-badge-$uid'), status: st, busy: _busy.contains(uid)),
      ]),
    );
    if (!widget.canTake) return KeyedSubtree(key: ValueKey('att-row-$uid'), child: content);
    return Semantics(
      key: ValueKey('att-row-$uid'),
      button: true,
      label: name,
      child: InkWell(onTap: _busy.contains(uid) ? null : () => _pickStatus(r), child: content),
    );
  }
}

/// Arama kutusu: 48 dp yükseklikte dokunma hedefi (alanın tamamı yazılabilir), 16 dp köşe.
class _SearchBox extends StatelessWidget {
  const _SearchBox({super.key, required this.controller, required this.hint, required this.onChanged});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
      decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.bd)),
      child: Row(children: [
        ExcludeSemantics(child: Icon(BuIcons.search, size: 18, color: t.mut)),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: BuType.body.copyWith(color: t.ink),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: BuType.body.copyWith(color: t.mut),
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Nötr durum rozeti: simge + etiket (renk yok; ayrım simge ve metinle).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({super.key, required this.status, this.busy = false});

  final String status;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final (icon, label, strong) = switch (status) {
      'PRESENT' => (BuIcons.check, l.evtAtt2MarkPresent, true),
      'ABSENT' => (BuIcons.circleX, l.evtAtt2MarkAbsent, false),
      _ => (BuIcons.clock, l.evtAtt2Pending, false),
    };
    final fg = strong ? t.ink : t.mut;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: strong ? t.sf2 : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: strong ? t.bdStrong : t.bd),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          busy
              ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              : ExcludeSemantics(child: Icon(icon, size: 14, color: fg)),
          const SizedBox(width: 6),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(color: fg, fontWeight: FontWeight.w400))),
        ]),
      ),
    );
  }
}

/// Durum seçim satırı (alt sayfa): simge + etiket, seçili olanda onay işareti.
class _SheetOption extends StatelessWidget {
  const _SheetOption({super.key, required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: () {
          buHaptic(BuHaptic.selection);
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(children: [
            Icon(icon, size: 20, color: t.ink),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: tx.bodyLarge!.copyWith(color: t.ink))),
            if (selected) Icon(BuIcons.check, size: 18, color: t.mut),
          ]),
        ),
      ),
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
                BuSkeleton(width: 80, height: 28, radius: 14),
              ]),
            ),
        ]),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'etkinlik2_qr_page.dart';
import 'etkinlik2_widgets.dart';

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

  /// İyimser güncelleme; hata olursa geri alınır.
  Future<void> _mark(Map<String, dynamic> r, bool present) async {
    final id = _uid(r);
    if (_busy.contains(id)) return;
    final before = r['present'] == true;
    setState(() {
      _busy.add(id);
      r['present'] = present;
    });
    try {
      await widget.session.api.put('/events/$_id/attendance/$id', {'present': present});
    } catch (e) {
      if (!mounted) return;
      setState(() => r['present'] = before);
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
    if (dep != null && dep.isNotEmpty) parts.add(dep);
    if (r['present'] == true) {
      final m = r['method'];
      if (m == 'QR') parts.add(l.etkinlik2MethodQr);
      if (m == 'MANUAL') parts.add(l.etkinlik2MethodManual);
      final at = DateTime.tryParse('${r['markedAt']}')?.toLocal();
      if (m == 'QR' && at != null) {
        parts.add('${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}');
      }
    }
    if ((widget.event['createdBy'] as num?)?.toInt() == _uid(r)) parts.add(l.etkinlik2Organizer);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = _loading
        ? BuViewState.loading
        : _error != null
            ? BuViewState.error
            : _rows.isEmpty
                ? BuViewState.empty
                : BuViewState.ready;
    final shown = _shown;
    return BuStaggerScope(
      child: BuPageScaffold(
        title: l.eventFormAttendees,
        state: state,
        error: _error,
        onRetry: _load,
        onRefresh: () => _load(silent: true),
        loading: const _AttendanceSkeleton(),
        empty: BuEmptyState(
          illustration: BuIllustration.club,
          title: l.etkinlik2AttendanceEmpty,
          message: l.p16AttEmptyBody,
        ),
        bottomInset: 32,
        slivers: [
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 0),
            sliver: SliverList.list(children: [
              Et2EventStrip(event: widget.event),
              const SizedBox(height: 12),
              _summary(context),
              const SizedBox(height: 14),
              BuChipRow(
                padding: EdgeInsets.zero,
                labels: [l.etkinlik2FilterAll, l.etkinlik2FilterPresent, l.etkinlik2FilterAbsent],
                selected: _filter.index,
                onSelected: (i) => setState(() => _filter = _Filter.values[i]),
              ),
              const SizedBox(height: 14),
            ]),
          ),
          if (shown.isEmpty)
            SliverToBoxAdapter(
              child: BuEmptyState(
                compact: true,
                illustration: BuIllustration.search,
                title: l.p16AttFilterEmpty,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
              sliver: DecoratedSliver(
                decoration: BoxDecoration(
                  color: context.bu.sf,
                  borderRadius: BorderRadius.circular(BuRadius.lg),
                  border: Border.all(color: context.bu.bd),
                ),
                sliver: SliverList.builder(
                  itemCount: shown.length,
                  itemBuilder: (c, i) => BuStaggerItem(index: i, child: _row(c, shown[i], top: i > 0)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summary(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final total = _rows.length;
    final present = _rows.where((r) => r['present'] == true).length;
    final qr = _rows.where((r) => r['present'] == true && r['method'] == 'QR').length;
    final manual = _rows.where((r) => r['present'] == true && r['method'] == 'MANUAL').length;
    final frac = total == 0 ? 0.0 : present / total;
    return BuCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      child: Row(children: [
        _Donut(fraction: frac),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(l.etkinlik2AttendanceLabel, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w600, color: t.mut)),
            const SizedBox(height: 2),
            Text(l.etkinlik2PresentOf('$present', '$total'),
                key: const ValueKey('et2-att-summary'), style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
            if (qr > 0 || manual > 0) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (qr > 0) Et2Tag('${l.etkinlik2MethodQr} · $qr', icon: LucideIcons.qrCode),
                if (manual > 0) Et2Tag('${l.etkinlik2MethodManual} · $manual', muted: true, icon: LucideIcons.userCheck),
              ]),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: l.etkinlik2ShowQrSem,
          excludeSemantics: true,
          onTap: _showQr,
          child: BuPressable(
            onTap: _showQr,
            haptic: BuHaptic.selection,
            scale: .94,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(BuRadius.md)),
              child: Icon(LucideIcons.qrCode, size: 24, color: t.onSoft),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> r, {required bool top}) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final name = '${r['displayName'] ?? ''}';
    final sub = _sub(r);
    final present = r['present'] == true;
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      decoration: BoxDecoration(border: top ? Border(top: BorderSide(color: t.bd)) : null),
      padding: const EdgeInsetsDirectional.only(start: 14, end: 6, top: 10, bottom: 10),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          BuAvatar(name: name, size: 44),
          PositionedDirectional(
            end: -3,
            bottom: -3,
            child: AnimatedScale(
              scale: present ? 1 : 0,
              duration: BuMotion.of(context, BuMotion.medium),
              curve: BuMotion.emphasized,
              child: ExcludeSemantics(
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(color: t.ok, shape: BoxShape.circle, border: Border.all(color: t.sf, width: 2)),
                  child: Icon(LucideIcons.check, size: 11, color: t.onPr),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
            if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
          ]),
        ),
        Et2Toggle(
          key: ValueKey('et2-mark-${_uid(r)}'),
          value: present,
          label: context.l10n.etkinlik2MarkSem(name),
          onChanged: _busy.contains(_uid(r)) ? null : (v) => _mark(r, v),
        ),
      ]),
    );
  }
}

/// Yoklama oranı halkası: ortada yüzde.
class _Donut extends StatelessWidget {
  const _Donut({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final pct = (fraction * 100).round();
    return ExcludeSemantics(
      child: SizedBox(
        width: 72,
        height: 72,
        child: RepaintBoundary(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: fraction.clamp(0.0, 1.0)),
            duration: BuMotion.of(context, BuMotion.long),
            curve: BuMotion.emphasizedDecelerate,
            builder: (context, v, _) => CustomPaint(
              painter: _DonutPainter(v, t.bd, t.ok),
              child: Center(
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.2,
                  child: Text('$pct%', style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.value, this.track, this.color);

  final double value;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    if (value <= 0) return;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, fg);
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.value != value || old.track != track || old.color != color;
}

/// Yoklama sayfası iskeleti: etkinlik şeridi + özet kartı + çipler + satırlar.
class _AttendanceSkeleton extends StatelessWidget {
  const _AttendanceSkeleton();

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return BuSkeletonScope(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const BuSkeleton(height: 60, radius: BuRadius.md),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.lg), border: Border.all(color: t.bd)),
            child: const Row(children: [
              BuSkeleton.circle(72),
              SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [BuSkeleton.line(width: 70), SizedBox(height: 10), BuSkeleton.line(width: 140, height: 18)])),
            ]),
          ),
          const SizedBox(height: 14),
          const Row(children: [BuSkeleton(width: 70, height: 40, radius: BuRadius.pill), SizedBox(width: 8), BuSkeleton(width: 78, height: 40, radius: BuRadius.pill), SizedBox(width: 8), BuSkeleton(width: 90, height: 40, radius: BuRadius.pill)]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.lg), border: Border.all(color: t.bd)),
            child: Column(children: [
              for (var i = 0; i < 5; i++)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 9),
                  child: Row(children: [
                    BuSkeleton.circle(44),
                    SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [BuSkeleton.line(width: 120), SizedBox(height: 8), BuSkeleton.line(width: 170)])),
                    SizedBox(width: 12),
                    BuSkeleton(width: 52, height: 32, radius: 16),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'etkinlik2_attendance_page.dart';
import 'etkinlik2_widgets.dart';
import 'qr_painter.dart';

/// Organizatör yoklama kodu: QR + elle kod + yenilenme sayacı + "N / M kişi geldi".
/// Kod kısa ömürlüdür; süresi dolmadan kendiliğinden yenilenir (sayfa kapanınca zamanlayıcılar iptal).
class Etkinlik2QrPage extends StatefulWidget {
  const Etkinlik2QrPage({super.key, required this.session, required this.event, this.now});

  final Session session;
  final Map<String, dynamic> event;

  /// Yalnız test: saat kaynağı (süre dolumunu sahte saatle denemek için).
  @visibleForTesting
  final DateTime Function()? now;

  @override
  State<Etkinlik2QrPage> createState() => _Etkinlik2QrPageState();
}

class _Etkinlik2QrPageState extends State<Etkinlik2QrPage> {
  Map<String, dynamic>? _code;
  bool _busy = false;
  String? _failed;
  int _present = 0;
  int _total = 0;
  Timer? _refresh;
  Timer? _tick;
  DateTime? _expires;
  int _validFor = 30;

  /// Kalan saniye: yalnız sayaç parçaları dinler (sayfanın tamamı her saniye yeniden kurulmaz).
  final _left = ValueNotifier<int>(0);

  int get _id => (widget.event['id'] as num).toInt();

  @override
  void initState() {
    super.initState();
    _loadCode();
    _loadCounts();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _expires != null) _left.value = _secsLeft;
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _tick?.cancel();
    _left.dispose();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    try {
      final r = await widget.session.api.get('/events/$_id/attendance');
      if (!mounted || r is! List) return;
      setState(() {
        _total = r.length;
        _present = r.whereType<Map>().where((e) => e['present'] == true).length;
      });
    } catch (_) {}
  }

  Future<void> _loadCode() async {
    if (!mounted || _busy) return;
    setState(() => _busy = true);
    try {
      final r = await widget.session.api.get('/events/$_id/checkin-code');
      if (!mounted) return;
      final m = Map<String, dynamic>.from(r as Map);
      final secs = ((m['validForSeconds'] as num?)?.toInt() ?? 30).clamp(10, 120);
      setState(() {
        _code = m;
        _failed = null;
        _validFor = secs;
        _expires = _now().add(Duration(seconds: secs));
      });
      _left.value = secs;
      _refresh?.cancel();
      _refresh = Timer(Duration(seconds: secs > 5 ? secs - 3 : secs), () {
        if (mounted) {
          _loadCode();
          _loadCounts();
        }
      });
    } catch (e) {
      if (mounted) setState(() => _failed = errorText(e));
      // Yenileme hatasında zamanlayıcı yeniden kurulur: kod sessizce bayatlamasın.
      _refresh?.cancel();
      _refresh = Timer(const Duration(seconds: 5), () {
        if (mounted) _loadCode();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Etkinlik2AttendancePage(session: widget.session, event: widget.event, fromQr: true)),
    );
    if (mounted) _loadCounts();
  }

  Future<void> _copy(String code) async {
    buHaptic(BuHaptic.light);
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) BuToast.show(context, context.l10n.p16QrCopied, kind: BuToastKind.success);
  }

  DateTime _now() => (widget.now ?? DateTime.now)();

  int get _secsLeft {
    final e = _expires;
    if (e == null) return 0;
    final s = e.difference(_now()).inSeconds;
    return s < 0 ? 0 : s;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return BuPageScaffold(
      title: l.eventFormCheckInCode,
      large: false,
      bottomInset: 20,
      bottomBar: Et2BottomBar(child: _bottom(context)),
      slivers: [
        SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 0),
          sliver: SliverList.list(children: [
            Et2EventStrip(event: widget.event),
            const SizedBox(height: 14),
            _ticket(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: ExcludeSemantics(child: Icon(LucideIcons.scanLine, size: 16, color: t.mut)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${l.eventFormQrHelp} ${l.eventFormCodeShortLived}',
                      style: tx.bodyMedium!.copyWith(height: 1.45, color: t.mut)),
                ),
              ]),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _ticket(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final code = _code?['code'] as String?;
    final qr = _code?['qrPayload'] as String?;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(BuRadius.xl),
        border: Border.all(color: t.bd),
      ),
      child: code == null ? _noCode(context) : Column(children: [
        if (_failed != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              liveRegion: true,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.triangleAlert, size: 16, color: t.danger),
                const SizedBox(width: 6),
                Flexible(child: Text(_failed!, style: tx.labelLarge!.copyWith(color: t.danger))),
              ]),
            ),
          ),
        ValueListenableBuilder<int>(
          valueListenable: _left,
          builder: (context, left, _) => _CountdownFrame(
            progress: _validFor == 0 ? 0 : left / _validFor,
            expired: left == 0,
            low: left <= 5,
            child: Semantics(
              label: l.eventFormCheckInCode,
              child: QrView(
                data: qr ?? code,
                size: 200,
                radius: BuRadius.sm,
                fallback: SelectableText(code, textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(color: t.pr)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(l.etkinlik2QrManualCaption,
            textAlign: TextAlign.center,
            style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: t.mut, letterSpacing: ar ? 0 : .8)),
        const SizedBox(height: 6),
        Semantics(
          button: true,
          label: '${l.p16QrCopy}: $code',
          excludeSemantics: true,
          onTap: () => _copy(code),
          child: BuPressable(
            onTap: () => _copy(code),
            scale: .97,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    code,
                    style: tx.headlineMedium!.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: ar ? 0 : 3,
                        color: t.ink,
                        fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                  const SizedBox(width: 10),
                  Icon(LucideIcons.copy, size: 20, color: t.mut),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<int>(
          valueListenable: _left,
          builder: (context, left, _) {
            final low = left <= 5;
            final bg = left == 0 ? t.danger.withValues(alpha: .12) : (low ? t.warnSoft : t.soft);
            final fg = left == 0 ? t.danger : (low ? t.onWarnSoft : t.onSoft);
            return AnimatedContainer(
              duration: BuMotion.of(context, BuMotion.medium),
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(BuRadius.pill)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(left == 0 ? LucideIcons.refreshCw : LucideIcons.clock, size: 16, color: fg),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(left == 0 ? l.etkinlik2QrExpired : l.etkinlik2QrRenewsIn('$left'),
                      textAlign: TextAlign.center, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: fg)),
                ),
              ]),
            );
          },
        ),
      ]),
    );
  }

  /// Kod henüz yok: yüklenirken QR iskeleti, hatada yeniden dene.
  Widget _noCode(BuildContext context) {
    final l = context.l10n;
    if (_busy) {
      return Semantics(
        label: l.eventFormCodePreparing,
        liveRegion: true,
        child: const BuSkeletonScope(
          child: Column(children: [
            BuSkeleton(width: 248, height: 248, radius: BuRadius.lg),
            SizedBox(height: 22),
            BuSkeleton.line(width: 120),
            SizedBox(height: 12),
            BuSkeleton(width: 220, height: 34, radius: 10),
            SizedBox(height: 16),
            BuSkeleton(width: 190, height: 40, radius: BuRadius.pill),
          ]),
        ),
      );
    }
    return BuErrorState(compact: true, message: _failed ?? l.eventFormCodeFailed, onRetry: _loadCode);
  }

  Widget _bottom(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        ExcludeSemantics(child: Icon(LucideIcons.userCheck, size: 18, color: t.mut)),
        const SizedBox(width: 8),
        Text(l.etkinlik2AttendanceLabel, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(l.etkinlik2PresentOf('$_present', '$_total'),
              key: const ValueKey('et2-present-count'),
              textAlign: TextAlign.end,
              style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.pr)),
        ),
      ]),
      const SizedBox(height: 8),
      Et2Progress(fraction: _total == 0 ? 0 : _present / _total, height: 6),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: BuButton(
            label: l.eventFormRefreshCode,
            icon: LucideIcons.refreshCw,
            busy: _busy,
            onPressed: _busy ? null : _loadCode,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: BuButton(label: l.eventFormAttendees, icon: LucideIcons.users, kind: BuButtonKind.outline, onPressed: _openList),
        ),
      ]),
    ]);
  }
}

/// QR çerçevesi: açık kâğıt zemin + çevresinde kalan süreyi gösteren halka (süre bitince soluk + yenileniyor katmanı).
class _CountdownFrame extends StatelessWidget {
  const _CountdownFrame({required this.progress, required this.expired, required this.low, required this.child});

  final double progress;
  final bool expired;
  final bool low;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final ringColor = expired ? t.danger : (low ? t.warn : t.pr);
    return SizedBox(
      width: 248,
      height: 248,
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: progress, end: progress),
          duration: BuMotion.of(context, const Duration(milliseconds: 1000)),
          curve: Curves.linear,
          builder: (context, v, _) => CustomPaint(
            foregroundPainter: _RingPainter(progress: v, track: t.bd, color: ringColor, radius: BuRadius.lg + 4),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(color: t.qrPaper, borderRadius: BorderRadius.circular(BuRadius.md), border: Border.all(color: t.bd)),
                  alignment: Alignment.center,
                  child: AnimatedOpacity(
                    duration: BuMotion.of(context, BuMotion.medium),
                    opacity: expired ? .12 : 1,
                    child: child,
                  ),
                ),
                if (expired)
                  ExcludeSemantics(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(color: t.qrPaper, shape: BoxShape.circle, border: Border.all(color: t.bd)),
                      child: Icon(LucideIcons.refreshCw, size: 28, color: t.qrInk),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Yuvarlatılmış dikdörtgen çevresinde ilerleme çizgisi.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.track, required this.color, required this.radius});

  final double progress;
  final Color track;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 4.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawRRect(rrect, base);
    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;
    final path = Path()..addRRect(rrect);
    final metric = path.computeMetrics().first;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = color;
    canvas.drawPath(metric.extractPath(0, metric.length * p), fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.color != color || old.radius != radius;
}

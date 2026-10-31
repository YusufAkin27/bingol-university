import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

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
    final failed = _failed != null;
    return BuPageScaffold(
      title: l.eventFormCheckInCode,
      large: false,
      bottomInset: 24,
      slivers: [
        SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
          sliver: SliverList.list(children: [
            _strip(context),
            const SizedBox(height: 12),
            _qrCard(context),
            if (failed) ...[
              const SizedBox(height: 12),
              _errorCard(context),
            ],
            const SizedBox(height: 12),
            failed || _code == null ? _compactStatus(context) : _statusCard(context),
          ]),
        ),
      ],
    );
  }

  /// Etkinlik şeridi: kulüp adı (varsa, küçük harf büyütülmüş) + etkinlik başlığı.
  Widget _strip(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final club = (widget.event['communityName'] as String?)?.trim() ?? '';
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 14, 10),
      decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.md), border: Border.all(color: t.bd)),
      child: Row(children: [
        Et2IconBox(club.isEmpty ? LucideIcons.calendarDays : LucideIcons.users, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (club.isNotEmpty)
              Text(club.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: t.pr, letterSpacing: ar ? 0 : .6)),
            Text('${widget.event['title'] ?? ''}',
                maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
          ]),
        ),
      ]),
    );
  }

  /// "Kod 4 sn sonra yenilenir" gibi metinde [token] (sayı) vurgulanır.
  Widget _emph(String text, String token, TextStyle base, TextStyle emph) {
    final i = token.isEmpty ? -1 : text.indexOf(token);
    if (i < 0) return Text(text, textAlign: TextAlign.center, style: base);
    return Text.rich(
      TextSpan(style: base, children: [
        TextSpan(text: text.substring(0, i)),
        TextSpan(text: token, style: emph),
        TextSpan(text: text.substring(i + token.length)),
      ]),
      textAlign: TextAlign.center,
    );
  }

  Widget _qrCard(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final code = _code?['code'] as String?;
    final qr = _code?['qrPayload'] as String?;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.lg), border: Border.all(color: t.bd)),
      child: code == null
          ? _noCode(context)
          : Column(children: [
              ValueListenableBuilder<int>(
                valueListenable: _left,
                builder: (context, left, _) => _QrFrame(
                  expired: left == 0,
                  child: Semantics(
                    label: l.eventFormCheckInCode,
                    child: QrView(
                      data: qr ?? code,
                      size: 192,
                      radius: BuRadius.xs,
                      fallback: SelectableText(code, textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(color: t.pr)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<int>(
                valueListenable: _left,
                builder: (context, left, _) {
                  final expired = left == 0;
                  final base = tx.labelLarge!.copyWith(fontWeight: FontWeight.w600, color: t.ink);
                  return AnimatedContainer(
                    duration: BuMotion.of(context, BuMotion.medium),
                    constraints: const BoxConstraints(minHeight: 40),
                    padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 16, 8),
                    decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.pill)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      ExcludeSemantics(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CustomPaint(
                            painter: _MiniRing(progress: _validFor == 0 ? 0 : left / _validFor, track: t.bd, color: expired ? t.danger : t.pr),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: expired
                            ? Text(l.etkinlik2QrExpired, style: base)
                            : _emph(l.etkinlik2QrRenewsIn('$left'), '$left', base, base.copyWith(fontWeight: FontWeight.w800, color: t.pr)),
                      ),
                    ]),
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(l.eventFormQrHelp, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(height: 1.45, color: t.mut)),
              const SizedBox(height: 14),
              Divider(height: 1, color: t.bd),
              const SizedBox(height: 14),
              Text(l.etkinlik2QrManualCaption,
                  textAlign: TextAlign.center,
                  style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: t.mut, letterSpacing: ar ? 0 : .8)),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 8, 6),
                decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.md)),
                child: Row(children: [
                  ExcludeSemantics(child: Icon(LucideIcons.keyRound, size: 18, color: t.mut)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: SelectableText(
                          code,
                          key: const ValueKey('et2-manual-code'),
                          maxLines: 1,
                          style: tx.titleLarge!.copyWith(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                              color: t.ink,
                              fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: '${l.p16QrCopy}: $code',
                    excludeSemantics: true,
                    onTap: () => _copy(code),
                    child: BuPressable(
                      onTap: () => _copy(code),
                      scale: .96,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.sm)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(LucideIcons.copy, size: 16, color: t.ink),
                            const SizedBox(width: 6),
                            Text(l.p16QrCopyBtn, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
    );
  }

  /// Kod henüz yok: yükleniyorsa QR iskeleti; hatadaysa bulanık yer tutucu + "Kod kısa süre geçerlidir".
  Widget _noCode(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    if (_busy) {
      return Semantics(
        label: l.eventFormCodePreparing,
        liveRegion: true,
        child: const BuSkeletonScope(
          child: Column(children: [
            BuSkeleton(width: 232, height: 232, radius: BuRadius.lg),
            SizedBox(height: 16),
            BuSkeleton(width: 200, height: 40, radius: BuRadius.pill),
            SizedBox(height: 14),
            BuSkeleton.line(width: 220),
            SizedBox(height: 18),
            BuSkeleton(height: 56, radius: BuRadius.md),
          ]),
        ),
      );
    }
    return Column(children: [
      const _QrFrame(expired: true, child: SizedBox.shrink()),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ExcludeSemantics(child: Icon(LucideIcons.timer, size: 14, color: t.mut)),
        const SizedBox(width: 6),
        Flexible(child: Text(l.eventFormCodeShortLived, style: tx.bodySmall!.copyWith(color: t.mut))),
      ]),
    ]);
  }

  Widget _errorCard(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        key: const ValueKey('et2-qr-error'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: t.danger.withValues(alpha: .12), borderRadius: BorderRadius.circular(BuRadius.lg)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ExcludeSemantics(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: t.danger.withValues(alpha: .14), shape: BoxShape.circle),
                child: Icon(LucideIcons.wifiOff, size: 20, color: t.danger),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(l.eventFormCodeFailed, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                ),
                const SizedBox(height: 6),
                Text(l.p16QrErrBody, style: tx.bodyMedium!.copyWith(height: 1.45, color: t.mut)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          BuButton(label: l.eventFormRefreshCode, icon: LucideIcons.refreshCw, busy: _busy, onPressed: _busy ? null : _loadCode),
          const SizedBox(height: 8),
          BuButton(label: l.commonRetry, icon: LucideIcons.refreshCcw, kind: BuButtonKind.outline, onPressed: _busy ? null : _loadCode),
        ]),
      ),
    );
  }

  /// "18 / 42 kişi geldi": sayı ([present]) vurgulu.
  Widget _presentText(BuildContext context, {TextStyle? style}) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final base = style ?? tx.labelLarge!.copyWith(fontWeight: FontWeight.w600, color: t.mut);
    final text = l.etkinlik2PresentOf('$_present', '$_total');
    final i = text.indexOf('$_present');
    if (i < 0) return Text(text, key: const ValueKey('et2-present-count'), style: base);
    return Directionality(
      textDirection: Directionality.of(context),
      child: Text.rich(
        TextSpan(style: base, children: [
          TextSpan(text: text.substring(0, i)),
          TextSpan(text: '$_present', style: base.copyWith(fontWeight: FontWeight.w800, color: t.pr)),
          TextSpan(text: text.substring(i + '$_present'.length)),
        ]),
        key: const ValueKey('et2-present-count'),
      ),
    );
  }

  Widget _statusCard(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return BuCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Et2IconBox(LucideIcons.userCheck, size: 40, tint: t.tint(1)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(l.p16QrStatusTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
              Text(l.p16QrStatusSub, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
            ]),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.pill)),
              child: _presentText(context, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w600, color: t.mut)),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Et2Progress(fraction: _total == 0 ? 0 : _present / _total, height: 8),
        const SizedBox(height: 14),
        Semantics(
          button: true,
          label: l.p16QrList,
          excludeSemantics: true,
          onTap: _openList,
          child: BuPressable(
            key: const ValueKey('et2-open-list'),
            onTap: _openList,
            haptic: BuHaptic.selection,
            scale: .98,
            child: Container(
              constraints: const BoxConstraints(minHeight: BuSize.button),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(BuRadius.md)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(LucideIcons.users, size: 18, color: t.onSoft),
                const SizedBox(width: 8),
                Flexible(child: Text(l.p16QrList, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: t.onSoft))),
                const SizedBox(width: 6),
                Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.onSoft),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  /// Hata/yükleme durumunda sade yoklama satırı: "• Yoklama: 18 / 42 kişi geldi  [Katılımcılar >]".
  Widget _compactStatus(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return BuCard(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 10, 10),
      radius: 20,
      child: Row(children: [
        ExcludeSemantics(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle))),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${l.etkinlik2AttendanceLabel}: ${l.etkinlik2PresentOf('$_present', '$_total')}',
            key: const ValueKey('et2-present-count'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: l.eventFormAttendees,
          excludeSemantics: true,
          onTap: _openList,
          child: BuPressable(
            key: const ValueKey('et2-open-list'),
            onTap: _openList,
            haptic: BuHaptic.selection,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.sm)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(l.eventFormAttendees, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                  const SizedBox(width: 4),
                  Icon(buDirIcon(context, LucideIcons.chevronRight), size: 16, color: t.ink),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// QR çerçevesi: yüksek kontrast kâğıt zemin; [expired] iken QR bulanıklaşır ve "Süresi doldu / Yenileniyor…" kartı çıkar.
class _QrFrame extends StatelessWidget {
  const _QrFrame({required this.expired, required this.child});

  final bool expired;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return SizedBox(
      width: 232,
      height: 232,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          width: 232,
          height: 232,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.qrPaper,
            borderRadius: BorderRadius.circular(BuRadius.lg),
            border: Border.all(color: t.bd),
            boxShadow: [BoxShadow(color: t.shadow.withValues(alpha: .12), blurRadius: 18, offset: const Offset(0, 6), spreadRadius: -8)],
          ),
          child: expired
              ? ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Opacity(opacity: .55, child: child is SizedBox ? const _PlaceholderQr() : child),
                )
              : child,
        ),
        if (expired)
          Semantics(
            liveRegion: true,
            label: '${l.p16QrExpiredTitle}. ${l.p16QrRefreshing}',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: t.sf,
                borderRadius: BorderRadius.circular(BuRadius.md),
                boxShadow: [BoxShadow(color: t.shadow.withValues(alpha: .18), blurRadius: 16, offset: const Offset(0, 6), spreadRadius: -6)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: t.pr, backgroundColor: t.soft)),
                const SizedBox(height: 6),
                Text(l.p16QrExpiredTitle, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                Text(l.p16QrRefreshing, style: tx.bodySmall!.copyWith(color: t.mut)),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Kod yokken QR'ı andıran süs deseni (gerçek veri içermez; bulanık çizilir).
class _PlaceholderQr extends StatelessWidget {
  const _PlaceholderQr();

  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(192, 192), painter: _PlaceholderPainter(context.bu.mut));
}

class _PlaceholderPainter extends CustomPainter {
  _PlaceholderPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    const f = 52.0;
    for (final o in [Offset.zero, Offset(size.width - f, 0), Offset(0, size.height - f)]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.dx, o.dy, f, f), const Radius.circular(8)), p);
    }
    const cells = [(80, 8), (104, 8), (88, 32), (128, 40), (64, 72), (96, 80), (124, 96), (72, 112), (100, 124), (150, 128), (130, 150), (88, 160), (170, 90)];
    for (final c in cells) {
      canvas.drawRect(Rect.fromLTWH(c.$1.toDouble(), c.$2.toDouble(), 16, 16), p);
    }
  }

  @override
  bool shouldRepaint(_PlaceholderPainter old) => old.color != color;
}

/// Küçük geri sayım halkası (kalan süre oranı kadar dolu yay).
class _MiniRing extends CustomPainter {
  _MiniRing({required this.progress, required this.track, required this.color});

  final double progress;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = track);
    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;
    canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * p,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke
          ..color = color);
  }

  @override
  bool shouldRepaint(_MiniRing old) => old.progress != progress || old.track != track || old.color != color;
}

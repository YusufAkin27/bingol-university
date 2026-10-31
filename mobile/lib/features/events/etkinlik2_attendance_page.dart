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
    if (dep != null && dep.isNotEmpty) parts.add(dep);
    if ((widget.event['createdBy'] as num?)?.toInt() == _uid(r)) parts.add(l.etkinlik2Organizer);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final hasData = _rows.isNotEmpty;
    final state = _loading
        ? BuViewState.loading
        : (_error == null && !hasData)
            ? BuViewState.empty
            : BuViewState.ready;
    final shown = _shown;
    return BuStaggerScope(
      child: BuPageScaffold(
        title: l.p16AttTitle,
        large: false,
        state: state,
        onRefresh: () => _load(silent: true),
        loading: const _AttendanceSkeleton(),
        empty: BuEmptyState(
          illustration: BuIllustration.club,
          title: l.etkinlik2AttendanceEmpty,
          message: l.p16AttEmptyBody,
        ),
        bottomInset: 24,
        bottomBar: state == BuViewState.loading
            ? null
            : DecoratedBox(
                decoration: BoxDecoration(color: t.bg),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 12),
                    child: BuButton(
                      key: const ValueKey('et2-show-qr'),
                      label: l.etkinlik2ShowQrSem,
                      icon: LucideIcons.qrCode,
                      onPressed: _showQr,
                    ),
                  ),
                ),
              ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            sliver: SliverList.list(children: [
              if (hasData) _summary(context),
              if (_error != null) ...[
                if (hasData) const SizedBox(height: 12),
                Et2ErrorRow(
                  key: const ValueKey('et2-att-error'),
                  title: l.etkinlik2MarkFailed,
                  sub: errorText(_error!),
                  retryLabel: l.commonRetry,
                  onRetry: _load,
                ),
              ],
              if (hasData) ...[
                const SizedBox(height: 14),
                _filters(context),
                const SizedBox(height: 14),
              ],
            ]),
          ),
          if (hasData && shown.isEmpty)
            SliverPadding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: BuCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  radius: 20,
                  child: BuEmptyState(
                    compact: true,
                    illustration: BuIllustration.search,
                    title: l.etkinlik2AttendanceEmpty,
                    message: l.p16AttFilterEmptyBody,
                  ),
                ),
              ),
            )
          else if (hasData)
            SliverPadding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: shown.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (c, i) => BuStaggerItem(index: i, child: _row(c, shown[i])),
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
    final frac = total == 0 ? 0.0 : present / total;
    Widget stat(String label, int n, Color dot) => Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.sm)),
            child: Row(children: [
              ExcludeSemantics(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle))),
              const SizedBox(width: 8),
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(color: t.mut))),
              const SizedBox(width: 6),
              Text('$n', style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
            ]),
          ),
        );
    return BuCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Et2IconBox(LucideIcons.userCheck, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Text(l.etkinlik2PresentOf('$present', '$total'),
                key: const ValueKey('et2-att-summary'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
          ),
        ]),
        const SizedBox(height: 14),
        Et2Progress(fraction: frac, height: 8),
        const SizedBox(height: 14),
        Row(children: [
          stat(l.etkinlik2FilterPresent, present, t.pr),
          const SizedBox(width: 10),
          stat(l.etkinlik2FilterAbsent, total - present, t.pr.withValues(alpha: .3)),
        ]),
      ]),
    );
  }

  /// Süzgeç çipleri: seçili olan koyu mürekkep dolgulu hap, yanında sayı.
  Widget _filters(BuildContext context) {
    final l = context.l10n;
    final total = _rows.length;
    final present = _rows.where((r) => r['present'] == true).length;
    final items = <(_Filter, String, int, String)>[
      (_Filter.all, l.etkinlik2FilterAll, total, 'et2-filter-all'),
      (_Filter.present, l.etkinlik2FilterPresent, present, 'et2-filter-present'),
      (_Filter.absent, l.etkinlik2FilterAbsent, total - present, 'et2-filter-absent'),
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (c, i) {
          final it = items[i];
          return _FilterChip(
            key: ValueKey(it.$4),
            label: it.$2,
            count: it.$3,
            selected: _filter == it.$1,
            onTap: () => setState(() => _filter = it.$1),
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> r) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final name = '${r['displayName'] ?? ''}';
    final sub = _sub(r);
    final present = r['present'] == true;
    final method = r['method'];
    final uid = _uid(r);
    final (tagLabel, tagIcon, tagBlue) = !present
        ? (l.p16AttWaiting, LucideIcons.clock, false)
        : method == 'QR'
            ? (l.etkinlik2MethodQr, LucideIcons.qrCode, false)
            : (l.etkinlik2MethodManual, LucideIcons.userCheck, true);
    final tag = t.tint(1);
    return BuCard(
      key: ValueKey('et2-att-$uid'),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 6, 10),
      radius: 20,
      child: Row(children: [
        Et2Initials(
          name: name,
          size: 48,
          tint: present ? BuTint(t.soft, t.onSoft) : BuTint(t.sf2, t.mut),
          url: null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Flexible(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: present ? t.ink : t.mut)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: tagBlue ? tag.bg : t.mut.withValues(alpha: .12), borderRadius: BorderRadius.circular(BuRadius.pill)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  ExcludeSemantics(child: Icon(tagIcon, size: 12, color: tagBlue ? tag.fg : t.mut)),
                  const SizedBox(width: 4),
                  Text(tagLabel, style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w600, color: tagBlue ? tag.fg : t.mut)),
                ]),
              ),
            ]),
            if (sub.isNotEmpty)
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
          ]),
        ),
        Et2Toggle(
          key: ValueKey('et2-mark-$uid'),
          thumbCheck: true,
          value: present,
          label: l.etkinlik2MarkSem(name),
          onChanged: _busy.contains(uid) ? null : (v) => _mark(r, v),
        ),
      ]),
    );
  }
}

/// Süzgeç çipi: etiket + sayı rozeti; seçiliyken koyu dolgu.
class _FilterChip extends StatelessWidget {
  const _FilterChip({super.key, required this.label, required this.count, required this.selected, required this.onTap});

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final bg = selected ? t.soft : t.sf;
    final fg = selected ? t.onSoft : t.mut;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count',
      excludeSemantics: true,
      onTap: onTap,
      child: BuPressable(
        onTap: onTap,
        haptic: BuHaptic.selection,
        scale: .96,
        child: AnimatedContainer(
          duration: BuMotion.of(context, BuMotion.short),
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: BuMotion.of(context, BuMotion.short),
            padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(BuRadius.pill),
              border: Border.all(color: selected ? t.selectedBorder : t.bd),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: fg)),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 24),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? t.pr.withValues(alpha: .14) : t.sf2,
                  borderRadius: BorderRadius.circular(BuRadius.pill),
                ),
                child: Text('$count', textAlign: TextAlign.center, style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: fg)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Yoklama sayfası iskeleti: özet kartı + çipler + satır kartları.
class _AttendanceSkeleton extends StatelessWidget {
  const _AttendanceSkeleton();

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    Widget card(Widget child) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.bd)),
          child: child,
        );
    return BuSkeletonScope(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          card(const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [BuSkeleton(width: 44, height: 44, radius: 14), SizedBox(width: 12), BuSkeleton.line(width: 150, height: 20)]),
            SizedBox(height: 14),
            BuSkeleton(height: 8, radius: 4),
            SizedBox(height: 14),
            Row(children: [Expanded(child: BuSkeleton(height: 44, radius: 12)), SizedBox(width: 10), Expanded(child: BuSkeleton(height: 44, radius: 12))]),
          ])),
          const SizedBox(height: 14),
          const Row(children: [
            BuSkeleton(width: 84, height: 40, radius: BuRadius.pill),
            SizedBox(width: 8),
            BuSkeleton(width: 84, height: 40, radius: BuRadius.pill),
            SizedBox(width: 8),
            BuSkeleton(width: 96, height: 40, radius: BuRadius.pill),
          ]),
          const SizedBox(height: 14),
          for (var i = 0; i < 4; i++) ...[
            card(const Row(children: [
              BuSkeleton(width: 48, height: 48, radius: 16),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  BuSkeleton.line(width: 120),
                  SizedBox(height: 8),
                  BuSkeleton.line(width: 170),
                ]),
              ),
              SizedBox(width: 12),
              BuSkeleton(width: 52, height: 32, radius: 16),
            ])),
            const SizedBox(height: 8),
          ],
        ]),
      ),
    );
  }
}

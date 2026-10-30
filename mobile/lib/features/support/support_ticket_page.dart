import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart' show niceDate;
import 'support_common.dart';

/// Talep detayı: mesajlar, yanıt yazma, kapatma. Değişiklik olduysa `true` ile döner.
class SupportTicketPage extends StatefulWidget {
  const SupportTicketPage({super.key, required this.session, required this.ticketId});

  final Session session;
  final int ticketId;

  @override
  State<SupportTicketPage> createState() => _SupportTicketPageState();
}

class _SupportTicketPageState extends State<SupportTicketPage> {
  final _reply = TextEditingController();
  final _scroll = ScrollController();
  Map<String, dynamic>? _ticket;
  List<Map<String, dynamic>> _messages = [];
  Object? _error;
  bool _loading = true;
  bool _sending = false;
  bool _closing = false;
  bool _changed = false;

  String get _path => '/support/tickets/${widget.ticketId}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final r = await widget.session.api.get(_path) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _ticket = (r['ticket'] as Map?)?.cast<String, dynamic>();
        _messages = ((r['messages'] as List?) ?? []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: BuMotion.of(context, BuMotion.long), curve: BuMotion.emphasizedDecelerate);
    });
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.session.api.post('$_path/messages', {'text': text});
      _reply.clear();
      _changed = true;
      await _load(silent: true);
      _toEnd();
    } catch (e) {
      if (mounted) supportSnack(context, supportError(context, e), BuToastKind.error);
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _close() async {
    final l = context.l10n;
    final ok = await BuDialog.show<bool>(
      context,
      builder: (ctx) {
        final t = ctx.bu;
        final tx = Theme.of(ctx).textTheme;
        return Dialog(
          backgroundColor: t.sf3,
          surfaceTintColor: t.sf3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 28, 24, 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(
                child: ExcludeSemantics(
                  child: Container(
                    width: 76,
                    height: 76,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: t.soft.withValues(alpha: .55), shape: BoxShape.circle),
                    child: Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                      child: Icon(LucideIcons.lock, size: 24, color: t.pr),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(l.supportCloseTicketTitle, textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Text(l.supportCloseTicketBody, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
              const SizedBox(height: 20),
              BuButton(label: l.supportClose, icon: LucideIcons.circleCheck, onPressed: () => Navigator.of(ctx).pop(true)),
              const SizedBox(height: 8),
              Material(
                color: t.sf2,
                borderRadius: BuRadius.bMd,
                child: InkWell(
                  borderRadius: BuRadius.bMd,
                  onTap: () => Navigator.of(ctx).pop(false),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: Center(child: Text(l.supportCancel, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w700))),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
    if (ok != true || !mounted) return;
    setState(() => _closing = true);
    try {
      await widget.session.api.post('$_path/close');
      _changed = true;
      await _load(silent: true);
    } catch (e) {
      if (mounted) supportSnack(context, supportError(context, e), BuToastKind.error);
    }
    if (mounted) setState(() => _closing = false);
  }

  @override
  Widget build(BuildContext context) {
    final closed = _ticket?['status'] == 'CLOSED';
    final state = _loading
        ? BuViewState.loading
        : (_error != null && _ticket == null ? BuViewState.error : BuViewState.ready);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: BuPageScaffold(
        title: context.l10n.supportTicketTitle,
        large: false,
        state: state,
        error: _error,
        onRetry: _load,
        onRefresh: () => _load(silent: true),
        controller: _scroll,
        loading: const _TicketSkeleton(),
        actions: _ticket == null ? null : _actions(closed),
        bottomInset: 20,
        bottomBar: _ticket != null && !closed ? _composer() : null,
        slivers: [
          SliverToBoxAdapter(child: _header()),
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 0),
            sliver: SliverList.builder(
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final day = _dayOf(_messages[i]);
                final newDay = i == 0 || day != _dayOf(_messages[i - 1]);
                return BuStaggerItem(
                  index: i,
                  child: Column(children: [
                    if (newDay && day.isNotEmpty) _dayChip(_messages[i]),
                    _bubble(_messages[i]),
                  ]),
                );
              },
            ),
          ),
          if (closed) SliverToBoxAdapter(child: _closedNote()),
        ],
      ),
    );
  }

  List<Widget> _actions(bool closed) {
    final l = context.l10n;
    final t = context.bu;
    final st = _ticket?['status'] as String?;
    return [
      Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: Center(child: SupportStatusPill(st, dot: true)),
      ),
      if (!closed)
        PopupMenuButton<String>(
          tooltip: l.supportCloseTicketTitle,
          enabled: !_closing,
          icon: Icon(LucideIcons.ellipsisVertical, color: t.ink),
          onSelected: (_) => _close(),
          itemBuilder: (_) => [
            PopupMenuItem<String>(
              value: 'close',
              child: Row(children: [
                Icon(LucideIcons.lock, size: 18, color: t.danger),
                const SizedBox(width: 12),
                Text(l.supportCloseTicketTitle),
              ]),
            ),
          ],
        )
      else
        const SizedBox(width: 8),
    ];
  }

  /// Konu kartı: konu, kategori ve açılış tarihi-saati.
  Widget _header() {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final tk = _ticket ?? const <String, dynamic>{};
    final cat = supportTicketCategories(context.l10n)[tk['category']] ?? context.l10n.supportCatOther;
    final d = DateTime.tryParse('${tk['createdAt'] ?? ''}')?.toLocal();
    final when = d == null
        ? niceDate(tk['createdAt'] as String?, context: context)
        : '${niceDate(tk['createdAt'] as String?, context: context)}, ${DateFormat('HH:mm').format(d)}';
    Widget meta(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          ExcludeSemantics(child: Icon(icon, size: 16, color: t.mut)),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: tx.bodySmall!.copyWith(color: t.mut))),
        ]);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 0),
      child: BuCard(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
        child: SizedBox(
          width: double.infinity,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(
              header: true,
              child: Text('${tk['subject'] ?? ''}',
                  maxLines: 3, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800, height: 1.3)),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 16, runSpacing: 6, children: [meta(LucideIcons.folder, cat), meta(LucideIcons.calendarCheck, when)]),
          ]),
        ),
      ),
    );
  }

  Widget _closedNote() {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bMd),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ExcludeSemantics(child: Icon(LucideIcons.lock, size: 18, color: t.mut)),
          const SizedBox(width: 10),
          Flexible(child: Text(context.l10n.supportTicketClosedNote, textAlign: TextAlign.center, style: tx.titleSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w700))),
        ]),
      ),
    );
  }

  String _dayOf(Map<String, dynamic> m) {
    final d = DateTime.tryParse('${m['createdAt'] ?? ''}')?.toLocal();
    return d == null ? '' : '${d.year}-${d.month}-${d.day}';
  }

  /// Ayıraç metni: bugünse "Bugün, 14 Mayıs", değilse "14 Mayıs 2024".
  String _dayLabel(Map<String, dynamic> m) {
    final d = DateTime.tryParse('${m['createdAt'] ?? ''}')?.toLocal();
    if (d == null) return niceDate(m['createdAt'] as String?, context: context);
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      final loc = Localizations.localeOf(context).toString();
      return '${context.l10n.p13SuppToday}, ${DateFormat('d MMMM', loc).format(d)}';
    }
    return niceDate(m['createdAt'] as String?, context: context);
  }

  /// Gün ayırıcı hap ("14 Mayıs 2024").
  Widget _dayChip(Map<String, dynamic> m) {
    final t = context.bu;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bPill),
          child: Text(_dayLabel(m),
              style: Theme.of(context).textTheme.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> m) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final staff = m['fromStaff'] == true;
    const big = Radius.circular(22), small = Radius.circular(6);
    final d = DateTime.tryParse('${m['createdAt'] ?? ''}')?.toLocal();
    final time = d == null ? '' : DateFormat('HH:mm').format(d);
    final maxW = MediaQuery.sizeOf(context).width * .8;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: staff ? t.sf : t.pr,
        border: staff ? Border.all(color: t.bd.withValues(alpha: .7)) : null,
        borderRadius: BorderRadiusDirectional.only(
          topStart: big,
          topEnd: big,
          bottomStart: staff ? small : big,
          bottomEnd: staff ? big : small,
        ),
      ),
      child: Text('${m['text'] ?? ''}', style: tx.bodyLarge!.copyWith(height: 1.5, color: staff ? t.ink : t.onPr)),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Semantics(
        container: true,
        child: Column(
          crossAxisAlignment: staff ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            if (staff)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle),
                    child: ExcludeSemantics(child: Icon(LucideIcons.headset, size: 14, color: t.onPr)),
                  ),
                  const SizedBox(width: 8),
                  Text(context.l10n.supportStaff, style: tx.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                ]),
              ),
            bubble,
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(6, 4, 6, 0),
              child: Text(time, style: tx.labelMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, 12 + MediaQuery.paddingOf(context).bottom),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: TextField(
            controller: _reply,
            minLines: 1,
            maxLines: 4,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            style: tx.bodyLarge!.copyWith(color: t.ink),
            decoration: InputDecoration(
              hintText: context.l10n.supportHintReply,
              counterText: '',
              filled: true,
              fillColor: t.sf,
              contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 16),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: t.bd.withValues(alpha: .6))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: t.pr, width: 2)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: t.bd.withValues(alpha: .6))),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filled(
          tooltip: context.l10n.supportSend,
          onPressed: _sending ? null : _send,
          style: IconButton.styleFrom(minimumSize: const Size(54, 54), fixedSize: const Size(54, 54), foregroundColor: t.onPr, backgroundColor: t.pr),
          icon: _sending
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: t.onPr))
              : const Icon(LucideIcons.send, size: 22),
        ),
      ]),
    );
  }
}

/// Talep iskeleti: başlık kartı + üç baloncuk.
class _TicketSkeleton extends StatelessWidget {
  const _TicketSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.l10n.commonLoading,
        liveRegion: true,
        container: true,
        child: const BuSkeletonScope(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20, 4, 20, 20),
            child: Column(children: [
              BuSkeleton(height: 112, radius: 20),
              SizedBox(height: 22),
              Align(alignment: AlignmentDirectional.centerEnd, child: BuSkeleton(width: 220, height: 64, radius: 20)),
              SizedBox(height: 14),
              Align(alignment: AlignmentDirectional.centerStart, child: BuSkeleton(width: 250, height: 88, radius: 20)),
              SizedBox(height: 14),
              Align(alignment: AlignmentDirectional.centerEnd, child: BuSkeleton(width: 180, height: 48, radius: 20)),
            ]),
          ),
        ),
      );
}

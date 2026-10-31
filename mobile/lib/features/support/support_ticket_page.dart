import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart' show niceDate;
import '../polls/anket_flat.dart';
import 'support_common.dart';

/// Talep yazışması (Stitch v3 02): başlık = talep konusu; "● Yanıtlandı · Bilet #n" durum satırı + sağda "Talebi kapat";
/// gün ayracı; destek yanıtı solda beyaz + ince çizgili balon ("Destek" etiketi), benim mesajım sağda `sf2` balon;
/// altta "Yanıtını yaz" alanı + `pr` yuvarlak gönder. Değişiklik olduysa `true` ile döner.
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
    final ok = await BuDialog.confirm(
      context,
      title: l.supportCloseTicketTitle,
      message: l.supportCloseTicketBody,
      confirmLabel: l.supportClose,
      cancelLabel: l.supportCancel,
    );
    if (!ok || !mounted) return;
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
    final subject = '${_ticket?['subject'] ?? ''}'.trim();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: BuPageScaffold(
        title: subject.isEmpty ? context.l10n.supportTicketTitle : subject,
        large: false,
        state: state,
        error: _error,
        onRetry: _load,
        onRefresh: () => _load(silent: true),
        controller: _scroll,
        loading: const _TicketSkeleton(),
        bottomInset: 20,
        bottomBar: _ticket != null && !closed ? _composer() : null,
        slivers: [
          SliverToBoxAdapter(child: _statusRow(closed)),
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 8, kAnketPad, 0),
            sliver: SliverList.builder(
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final day = _dayOf(_messages[i]);
                final newDay = i == 0 || day != _dayOf(_messages[i - 1]);
                return BuStaggerItem(
                  index: i,
                  child: Column(children: [
                    if (newDay && day.isNotEmpty) _daySeparator(_messages[i]),
                    _bubble(_messages[i]),
                  ]),
                );
              },
            ),
          ),
          if (closed)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 8, kAnketPad, 0),
                child: Center(
                  child: Text(context.l10n.supportTicketClosedNote,
                      textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: context.bu.mut)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// "● Yanıtlandı · Bilet #3812" + sağda muted "Talebi kapat" (kapalıysa yalnız sol taraf).
  Widget _statusRow(bool closed) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final st = _ticket?['status'] as String?;
    final style = supportTicketStatusStyle(context, st);
    final color = switch (st) {
      'ANSWERED' => t.ok,
      'CLOSED' => t.mut,
      _ => t.onWarnSoft,
    };
    final no = (_ticket?['id'] as num?)?.toInt() ?? widget.ticketId;
    return Transform.translate(
      offset: const Offset(0, -2.5), // 48 dp dokunma satırı referanstaki 44 dp'lik satıra hizalanır
      child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 0, 8, 0),
      child: Row(children: [
        Expanded(
          child: Semantics(
            container: true,
            child: Row(children: [
              ExcludeSemantics(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle))),
              const SizedBox(width: 6),
              Flexible(
                child: Text.rich(
                  TextSpan(style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 13, height: 1.3), children: [
                    TextSpan(text: style.label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                    TextSpan(text: ' · ${l.p68TicketNo('$no')}'),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
        ),
        if (!closed)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: t.mut, minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 12)),
            onPressed: _closing ? null : _close,
            child: Text(l.supportCloseTicketTitle, style: tx.bodyMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
          ),
      ]),
    ));
  }

  String _dayOf(Map<String, dynamic> m) {
    final d = DateTime.tryParse('${m['createdAt'] ?? ''}')?.toLocal();
    return d == null ? '' : '${d.year}-${d.month}-${d.day}';
  }

  /// Ayıraç metni: bugünse "Bugün, 11 Ekim", değilse "14 Mayıs 2024" (büyük harf).
  String _dayLabel(Map<String, dynamic> m) {
    final d = DateTime.tryParse('${m['createdAt'] ?? ''}')?.toLocal();
    final lang = Localizations.localeOf(context).languageCode;
    String up(String s) => lang == 'tr' ? trUpper(s) : (lang == 'ar' ? s : s.toUpperCase());
    if (d == null) return up(niceDate(m['createdAt'] as String?, context: context));
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return up('${context.l10n.p13SuppToday}, ${anketDayLabel(context, d)}');
    }
    return up(niceDate(m['createdAt'] as String?, context: context));
  }

  /// Gün ayırıcı: ortada soluk büyük harf metin, iki yanda ince çizgi.
  Widget _daySeparator(Map<String, dynamic> m) {
    final t = context.bu;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 17),
      child: Semantics(
        header: true,
        child: Row(children: [
          Expanded(child: Container(height: 1, color: t.bd)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_dayLabel(m),
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall!.copyWith(color: t.mut, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: Localizations.localeOf(context).languageCode == 'ar' ? 0 : .5)),
          ),
          Expanded(child: Container(height: 1, color: t.bd)),
        ]),
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> m) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final staff = m['fromStaff'] == true;
    final d = DateTime.tryParse('${m['createdAt'] ?? ''}')?.toLocal();
    final time = d == null ? '' : DateFormat('HH:mm').format(d);
    final maxW = (MediaQuery.sizeOf(context).width - 2 * kAnketPad) * .85;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsetsDirectional.fromSTEB(15, 14, 15, 8),
      decoration: BoxDecoration(
        color: staff ? t.sf : t.sf2,
        border: staff ? Border.all(color: t.bd) : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${m['text'] ?? ''}', style: tx.bodyLarge!.copyWith(fontSize: 16, height: 1.45, color: t.ink)),
        const SizedBox(height: 2),
        Align(alignment: AlignmentDirectional.centerEnd, child: Text(time, style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 11.5, height: 1.2))),
      ]),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        container: true,
        child: Column(
          crossAxisAlignment: staff ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            if (staff)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4, bottom: 4),
                child: Text(context.l10n.p68Staff, style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 12, height: 1.3)),
              ),
            bubble,
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.bg, border: Border(top: BorderSide(color: t.bd))),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(kAnketPad, 12, kAnketPad, 12 + MediaQuery.paddingOf(context).bottom),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: _reply,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              style: tx.bodyLarge!.copyWith(color: t.ink),
              decoration: anketFieldDeco(context, hint: context.l10n.p68ReplyHint),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            tooltip: context.l10n.supportSend,
            onPressed: _sending ? null : _send,
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 44),
              fixedSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.padded,
              foregroundColor: t.onPr,
              backgroundColor: t.pr,
            ),
            icon: _sending
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: t.onPr))
                : const Icon(LucideIcons.arrowUp, size: 22),
          ),
        ]),
      ),
    );
  }
}

/// Talep iskeleti: durum satırı + üç balon.
class _TicketSkeleton extends StatelessWidget {
  const _TicketSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.l10n.commonLoading,
        liveRegion: true,
        container: true,
        child: const BuSkeletonScope(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(kAnketPad, 12, kAnketPad, 20),
            child: Column(children: [
              Align(alignment: AlignmentDirectional.centerStart, child: BuSkeleton.line(width: 160, height: 13)),
              SizedBox(height: 28),
              Align(alignment: AlignmentDirectional.centerStart, child: BuSkeleton(width: 250, height: 100, radius: 16)),
              SizedBox(height: 16),
              Align(alignment: AlignmentDirectional.centerEnd, child: BuSkeleton(width: 240, height: 80, radius: 16)),
              SizedBox(height: 16),
              Align(alignment: AlignmentDirectional.centerStart, child: BuSkeleton(width: 250, height: 90, radius: 16)),
            ]),
          ),
        ),
      );
}

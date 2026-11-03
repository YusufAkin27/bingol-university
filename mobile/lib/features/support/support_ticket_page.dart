import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart' show niceDate;
import '../polls/anket_flat.dart';
import 'support_attachments.dart';
import 'support_common.dart';
import 'support_list_widgets.dart';

/// Talep yazışması: üstte talep kartı (konu, kategori, "Bilet #n", durum, "Talebi kapat"), gün ayracı, destek yanıtı
/// solda avatarlı beyaz balon, benim mesajım sağda `sf2` balon (ekler balon içinde küçük resim ızgarası; dokununca
/// sohbetin tam ekran görüntüleyicisi), altta ek şeritli yanıt alanı. Değişiklik olduysa `true` ile döner.
class SupportTicketPage extends StatefulWidget {
  const SupportTicketPage({super.key, required this.session, required this.ticketId, this.attachmentUploader, this.attachments});

  final Session session;
  final int ticketId;

  /// Testlerde sahte yükleyici.
  final SupportAttachmentUploader? attachmentUploader;

  /// Testlerde hazır denetleyici.
  final SupportAttachmentsController? attachments;

  @override
  State<SupportTicketPage> createState() => _SupportTicketPageState();
}

class _SupportTicketPageState extends State<SupportTicketPage> {
  final _reply = TextEditingController();
  final _scroll = ScrollController();
  late final SupportAttachmentsController _att =
      widget.attachments ?? SupportAttachmentsController(uploader: widget.attachmentUploader ?? SessionAttachmentUploader(widget.session));
  Map<String, dynamic>? _ticket;
  List<Map<String, dynamic>> _messages = [];
  Object? _error;
  String? _composeError;
  bool _loading = true;
  bool _sending = false;
  bool _closing = false;
  bool _changed = false;
  bool _firstLoad = true;

  String get _path => '/support/tickets/${widget.ticketId}';

  @override
  void initState() {
    super.initState();
    _att.addListener(_onAtt);
    _reply.addListener(_onAtt);
    _load();
  }

  void _onAtt() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _att.removeListener(_onAtt);
    _reply.removeListener(_onAtt);
    if (widget.attachments == null) _att.dispose();
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
      // Son yanıt görüldü: listede "Yeni yanıt" vurgusu kalkar.
      final tk = _ticket;
      if (tk != null) SupportSeenStore.mark(widget.ticketId, '${tk['updatedAt'] ?? tk['createdAt'] ?? ''}');
      if (_firstLoad) {
        _firstLoad = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
      }
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
      _scroll.animateTo(_scroll.position.maxScrollExtent, duration: BuMotion.of(context, BuMotion.long), curve: BuMotion.emphasizedDecelerate);
    });
  }

  Future<void> _addAttachment() async {
    if (_sending) return;
    setState(() => _composeError = null);
    await runSupportAttachFlow(context, _att, onError: (m) {
      if (mounted) setState(() => _composeError = m);
    });
  }

  Future<void> _send() async {
    final l = context.l10n;
    final text = _reply.text.trim();
    if (_sending) return;
    if (text.isEmpty) {
      // Sunucu boş metni kabul etmez; ek varsa kısa bir not da istenir.
      setState(() => _composeError = _att.isEmpty ? null : l.supReplyNeedsText);
      return;
    }
    if (_att.hasPending) {
      setState(() => _composeError = l.supAttWaitUpload);
      return;
    }
    if (_att.hasFailed) {
      setState(() => _composeError = l.supAttFailedPending);
      buHaptic(BuHaptic.light);
      return;
    }
    setState(() {
      _sending = true;
      _composeError = null;
    });
    try {
      final ids = _att.ids;
      await widget.session.api.post('$_path/messages', {'text': text, if (ids.isNotEmpty) 'attachmentIds': ids});
      _reply.clear();
      _att.clear();
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
    final state = _loading ? BuViewState.loading : (_error != null && _ticket == null ? BuViewState.error : BuViewState.ready);
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
        bottomInset: 20,
        bottomBar: _ticket != null && !closed ? _composer() : null,
        slivers: [
          SliverToBoxAdapter(child: _headerCard(closed)),
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 4, kAnketPad, 0),
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
                child: Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
                  decoration: BoxDecoration(color: context.bu.sf2, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    ExcludeSemantics(child: Icon(BuIcons.lock, size: 18, color: context.bu.mut)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(context.l10n.supportTicketClosedNote, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: context.bu.mut))),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Talep özeti kartı: kategori karosu, konu (tam), "Durum · Bilet #n" ve sağda "Talebi kapat".
  Widget _headerCard(bool closed) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final tk = _ticket;
    final st = tk?['status'] as String?;
    final no = (tk?['id'] as num?)?.toInt() ?? widget.ticketId;
    final cat = tk?['category'] as String?;
    final catLabel = supportTicketCategories(l)[cat];
    final subject = '${tk?['subject'] ?? ''}'.trim();
    final created = tk?['createdAt'] as String?;
    final style = supportTicketStatusStyle(context, st);
    final dotColor = switch (st) {
      'ANSWERED' => t.ok,
      'CLOSED' => t.mut,
      _ => t.onWarnSoft,
    };
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 4, kAnketPad, 14),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 12),
        decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.bd), boxShadow: BuElevation.of(context, 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(13)),
              child: ExcludeSemantics(child: Icon(supportTicketCategoryIcons[cat] ?? BuIcons.messageCircle, size: 20, color: t.onSoft)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Semantics(
                  header: true,
                  child: Text(subject,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800, height: 1.3)),
                ),
                const SizedBox(height: 4),
                Text(
                  [if (catLabel != null) catLabel, if (created != null) niceDate(created, context: context)].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tx.bodySmall!.copyWith(color: t.mut),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Semantics(
                container: true,
                child: Row(children: [
                  ExcludeSemantics(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle))),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text.rich(
                      TextSpan(style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 13, height: 1.3), children: [
                        TextSpan(text: style.label, style: TextStyle(color: dotColor, fontWeight: FontWeight.w700)),
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
                style: TextButton.styleFrom(foregroundColor: t.mut, minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 10)),
                onPressed: _closing ? null : _close,
                child: Text(l.supportCloseTicketTitle, style: tx.bodyMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w600)),
              ),
          ]),
        ]),
      ),
    );
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
      padding: const EdgeInsets.only(top: 6, bottom: 14),
      child: Semantics(
        header: true,
        child: Row(children: [
          Expanded(child: Container(height: 1, color: t.bd)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_dayLabel(m),
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: t.mut, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: Localizations.localeOf(context).languageCode == 'ar' ? 0 : .5)),
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
    final atts = SupportAttachment.listFrom(m['attachments']);
    final text = '${m['text'] ?? ''}'.trim();
    final contentW = MediaQuery.sizeOf(context).width - 2 * kAnketPad;
    final avatar = staff ? 36.0 : 0.0;
    final maxW = (contentW - avatar) * .86;
    // Kuyruk köşesi: balonun konuştuğu tarafa bakan köşe sivri.
    const r = Radius.circular(20);
    const tail = Radius.circular(6);
    final radius = staff
        ? const BorderRadiusDirectional.only(topStart: tail, topEnd: r, bottomStart: r, bottomEnd: r)
        : const BorderRadiusDirectional.only(topStart: r, topEnd: tail, bottomStart: r, bottomEnd: r);
    final inner = maxW - 28;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: staff ? t.sf : t.sf2,
        border: staff ? Border.all(color: t.bd) : null,
        borderRadius: radius,
        boxShadow: staff ? BuElevation.of(context, 1) : null,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (atts.isNotEmpty) ...[
          SupportAttachmentGallery(
            attachments: atts,
            headers: supportAuthHeaders(widget.session),
            maxWidth: inner,
            onOpen: (i) => openSupportAttachments(context, widget.session, atts, i),
          ),
          if (text.isNotEmpty) const SizedBox(height: 8),
        ],
        if (text.isNotEmpty) Text(text, style: tx.bodyLarge!.copyWith(fontSize: 16, height: 1.45, color: t.ink)),
        const SizedBox(height: 2),
        Align(alignment: AlignmentDirectional.centerEnd, child: Text(time, style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 11.5, height: 1.2))),
      ]),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Semantics(
        container: true,
        child: staff
            ? Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                ExcludeSemantics(
                  child: Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsetsDirectional.only(end: 8),
                    decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                    child: Icon(BuIcons.headset, size: 15, color: t.onSoft),
                  ),
                ),
                Flexible(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 4),
                      child: Text(context.l10n.p68Staff, style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 12, fontWeight: FontWeight.w600, height: 1.3)),
                    ),
                    bubble,
                  ]),
                ),
              ])
            : Align(alignment: AlignmentDirectional.centerEnd, child: bubble),
      ),
    );
  }

  Widget _composer() {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final blocked = _sending || _att.hasPending;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.bg, border: Border(top: BorderSide(color: t.bd))),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(kAnketPad, 10, kAnketPad - 4, 10 + MediaQuery.paddingOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!_att.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 6, end: 4),
              child: SupportAttachmentStrip(controller: _att),
            ),
          AnimatedSize(
            duration: BuMotion.of(context, BuMotion.medium),
            curve: BuMotion.emphasized,
            alignment: Alignment.topCenter,
            child: _composeError == null
                ? const SizedBox(width: double.infinity)
                : Padding(padding: const EdgeInsetsDirectional.only(bottom: 8, end: 4), child: AnketFieldError(_composeError!)),
          ),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Semantics(
              button: true,
              label: l.supAttAdd,
              excludeSemantics: true,
              onTap: _addAttachment,
              child: IconButton(
                key: const ValueKey('supComposerAttach'),
                tooltip: l.supAttAdd,
                onPressed: _sending ? null : _addAttachment,
                style: IconButton.styleFrom(minimumSize: const Size(44, 44), fixedSize: const Size(44, 44), tapTargetSize: MaterialTapTargetSize.padded),
                icon: Icon(BuIcons.imagePlus, size: 24, color: t.mut),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _reply,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                style: tx.bodyLarge!.copyWith(color: t.ink),
                decoration: anketFieldDeco(context, hint: l.p68ReplyHint),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              tooltip: l.supportSend,
              onPressed: blocked ? null : _send,
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                fixedSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.padded,
                foregroundColor: t.onPr,
                backgroundColor: t.pr,
              ),
              icon: blocked
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: t.onPr))
                  : const Icon(BuIcons.arrowUp, size: 22),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Talep iskeleti: özet kartı + üç balon.
class _TicketSkeleton extends StatelessWidget {
  const _TicketSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.l10n.commonLoading,
        liveRegion: true,
        container: true,
        child: const BuSkeletonScope(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(kAnketPad, 4, kAnketPad, 20),
            child: Column(children: [
              BuSkeleton(height: 104, radius: 20),
              SizedBox(height: 24),
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

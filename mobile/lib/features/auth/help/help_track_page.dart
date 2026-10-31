import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/locale_controller.dart';
import '../../../core/session.dart';
import '../../../widgets/bu.dart';
import '../../../widgets/common.dart';
import 'public_support_api.dart';

/// Talep durumu / yazışma (Stitch v3 "26"): jeton yalnız cihazın güvenli deposundadır; ekran aynı cihazdan yeniden
/// açılabilir. Balon yok: her mesaj muted etiket (kim · tarih) + metin; mesajlar ince çizgiyle ayrılır. Altta sabit
/// yanıt çubuğu ("Gönder" metin düğmesi); talep kapalıysa çubuk yerine "Bu talep kapatıldı.". Mesaj metni loglanmaz.
class HelpTrackPage extends StatefulWidget {
  const HelpTrackPage({super.key, required this.session, required this.token});

  final Session session;
  final String token;

  @override
  State<HelpTrackPage> createState() => _HelpTrackPageState();
}

class _HelpTrackPageState extends State<HelpTrackPage> {
  final _text = TextEditingController();
  late final PublicSupportApi _api = PublicSupportApi(widget.session.api);
  Map<String, dynamic>? _detail;
  bool _loading = true;
  bool _failed = false;
  bool _sending = false;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final d = await _api.track(widget.token);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Jeton geçersiz/süresi dolmuşsa cihazdaki kayıt da silinir.
      if (e is ApiError && (e.status == 404 || e.status == 400 || e.status == 401)) await TrackTokenStore.clear();
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _send() async {
    final txt = _text.text.trim();
    if (_sending || txt.isEmpty) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final d = await _api.reply(widget.token, txt);
      if (!mounted) return;
      _text.clear();
      buHaptic(BuHaptic.light);
      setState(() {
        _detail = d;
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      final l = context.l10n;
      setState(() {
        _sending = false;
        _sendError = e is ApiError && e.status == 429 ? (e.message.isNotEmpty ? e.message : l.coreErrTooMany) : errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: l.p66TrackTitle, onBack: () => Navigator.pop(context)),
          Expanded(child: BuFadeThrough(child: _body(context))),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    if (_loading) return const LoadingView(key: ValueKey('track-loading'));
    final d = _detail;
    if (_failed || d == null) {
      return Padding(
        key: const ValueKey('track-error'),
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
        child: Column(
          children: [
            Text(l.p01LgLoadFailed, textAlign: TextAlign.center, style: tx.bodyLarge!.copyWith(color: t.mut)),
            const SizedBox(height: 8),
            BuButton(label: l.pickRetry, kind: BuButtonKind.text, compact: true, onPressed: _load),
          ],
        ),
      );
    }
    final ticket = (d['ticket'] as Map?)?.cast<String, dynamic>() ?? const {};
    final status = (ticket['status'] as String?) ?? 'OPEN';
    final messages = ((d['messages'] as List?) ?? const []).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    final closed = status == 'CLOSED';
    return Column(
      key: const ValueKey('track-ok'),
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text((ticket['subject'] as String?) ?? '', style: tx.bodyMedium!.copyWith(color: t.mut), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 12),
                  _StatusPill(status: status),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < messages.length; i++) ...[
                if (i > 0) Divider(height: 1, color: t.bd),
                _MessageRow(message: messages[i]),
              ],
            ],
          ),
        ),
        if (closed)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Text(l.p66TrackClosed, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut)),
            ),
          )
        else
          _ReplyBar(controller: _text, sending: _sending, error: _sendError, onSend: _send),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final (label, bg, fg) = switch (status) {
      'ANSWERED' => (l.supportStatusAnswered, t.okSoft, t.onOkSoft),
      'CLOSED' => (l.supportStatusClosed, t.sf2, t.mut),
      _ => (l.supportStatusOpen, t.soft, t.onSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BuRadius.bPill),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message});

  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final staff = message['fromStaff'] == true;
    final who = staff ? l.p66TrackStaff : l.p66TrackYou;
    final when = niceDate(message['createdAt'] as String?, context: context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(when.isEmpty ? who : '$who · $when', style: tx.bodySmall!.copyWith(color: t.mut)),
          const SizedBox(height: 4),
          Text((message['text'] as String?) ?? '', style: tx.bodyLarge!.copyWith(color: t.ink, height: 1.5)),
        ],
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({required this.controller, required this.sending, required this.error, required this.onSend});

  final TextEditingController controller;
  final bool sending;
  final String? error;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.bg, border: Border(top: BorderSide(color: t.bd))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(error!, style: tx.bodySmall!.copyWith(color: t.danger)),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: t.sf, borderRadius: BuRadius.bControl, border: Border.all(color: t.bdStrong)),
                      child: TextField(
                        controller: controller,
                        enabled: !sending,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: PublicSupportApi.messageMax,
                        keyboardType: TextInputType.multiline,
                        style: tx.bodyLarge!.copyWith(color: t.ink),
                        cursorColor: t.pr,
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          counterText: '',
                          hintText: l.p66TrackHint,
                          hintStyle: tx.bodyLarge!.copyWith(color: t.mut.withValues(alpha: .7)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (_, v, __) => TextButton(
                      onPressed: (sending || v.text.trim().isEmpty) ? null : onSend,
                      style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 12)),
                      child: Text(l.p66TrackSend, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

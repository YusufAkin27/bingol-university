import 'package:flutter/material.dart';

import '../core/locale_controller.dart';
import '../core/session.dart';
import '../l10n/app_localizations.dart';
import 'bu.dart';

/// İçerik/kullanıcı raporlama alt sayfası. Sayfalar yalnızca [ReportSheet.show] çağırır.
/// Hedef türleri backend `ReportTargetHandler` ile aynı: USER, POST, COMMUNITY, EVENT (mesajlar için
/// `POST /messages/{id}/report` kullanılır: [ReportSheet.showForMessage]).
/// Görünüm (Stitch 51): tutamaç, başlık + kapat, 5 nedenli simgeli radyo satırları, ek açıklama (250), "Gönder".
abstract final class ReportSheet {
  static const reasons = [
    ('SPAM', 'Spam veya reklam'),
    ('HARASSMENT', 'Taciz veya zorbalık'),
    ('INAPPROPRIATE', 'Uygunsuz içerik'),
    ('IMPERSONATION', 'Başkasını taklit'),
    ('OTHER', 'Diğer'),
  ];

  /// Sebep kodunun dile göre adı.
  static String reasonLabel(AppLocalizations l, String code) => switch (code) {
        'SPAM' => l.reportReasonSpam,
        'HARASSMENT' => l.reportReasonHarassment,
        'INAPPROPRIATE' => l.reportReasonInappropriate,
        'IMPERSONATION' => l.reportReasonImpersonation,
        'OTHER' => l.reportReasonOther,
        _ => code,
      };

  static IconData reasonIcon(String code) => switch (code) {
        'SPAM' => LucideIcons.megaphone,
        'HARASSMENT' => LucideIcons.shieldAlert,
        'INAPPROPRIATE' => LucideIcons.eyeOff,
        'IMPERSONATION' => LucideIcons.idCard,
        _ => LucideIcons.ellipsis,
      };

  static Future<void> show(
    BuildContext context,
    Session session, {
    required String targetType,
    required int targetId,
    String? title,
  }) =>
      _open(context, session, title, false, null, (reason, details) => session.api.post(
            '/reports',
            {'targetType': targetType, 'targetId': targetId, 'reason': reason, if (details.isNotEmpty) 'note': details},
          ));

  /// [messageText] verilirse şikâyet edilen mesaj alıntı kartı olarak gösterilir.
  static Future<void> showForMessage(BuildContext context, Session session, {required int messageId, String? messageText}) =>
      _open(context, session, null, true, messageText, (reason, details) => session.api.post(
            '/messages/$messageId/report',
            {'reason': reason, if (details.isNotEmpty) 'note': details},
          ));

  /// Engelleme onayı (Stitch 51): simge, başlık, kısa metin, bilgi kutusu; `true` = engelle.
  static Future<bool> confirmBlock(BuildContext context) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = ctx.bu;
        final l = ctx.l10n;
        final tx = Theme.of(ctx).textTheme;
        return Dialog(
          backgroundColor: t.sf3,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                child: ExcludeSemantics(child: Icon(LucideIcons.ban, size: 22, color: t.pr)),
              ),
              const SizedBox(height: 16),
              Semantics(header: true, child: Text(l.profileBlockTitle, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
              const SizedBox(height: 6),
              Text(l.profileBlockBody, style: tx.bodyMedium!.copyWith(color: t.ink)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bMd),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: 1), child: Icon(LucideIcons.info, size: 16, color: t.mut)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(l.p20BlockInfo, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.4))),
                ]),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: BuButton(label: l.profileCancel, kind: BuButtonKind.soft, onPressed: () => Navigator.pop(ctx, false))),
                const SizedBox(width: 10),
                Expanded(child: BuButton(label: l.profileBlock, kind: BuButtonKind.danger, onPressed: () => Navigator.pop(ctx, true))),
              ]),
            ]),
          ),
        );
      },
    );
    return r == true;
  }

  static Future<void> _open(
    BuildContext context,
    Session session,
    String? title,
    bool forMessage,
    String? quote,
    Future<dynamic> Function(String reason, String details) send,
  ) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bu.sf3,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _SheetBody(title: title, forMessage: forMessage, quote: quote, send: send),
    );
    if (done == true && context.mounted) {
      BuToast.show(context, context.l10n.reportThanks, kind: BuToastKind.success);
    }
  }
}

class _SheetBody extends StatefulWidget {
  const _SheetBody({required this.title, required this.forMessage, required this.send, this.quote});

  final String? title;
  final bool forMessage;
  final String? quote;
  final Future<dynamic> Function(String reason, String details) send;

  @override
  State<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<_SheetBody> {
  String _reason = ReportSheet.reasons.first.$1;
  final _details = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.send(_reason, _details.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final title = widget.title ?? (widget.forMessage ? l.reportMessageTitle : l.reportTitle);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: t.bd, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Semantics(header: true, child: Text(title, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink)))),
              IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                tooltip: l.commonCancel,
                style: IconButton.styleFrom(backgroundColor: t.sf2),
                icon: Icon(LucideIcons.x, size: 18, color: t.ink),
                onPressed: _busy ? null : () => Navigator.pop(context),
              ),
            ]),
            if (widget.quote != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16)),
                child: Text('"${widget.quote}"', maxLines: 4, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(fontStyle: FontStyle.italic, color: t.ink)),
              ),
              const SizedBox(height: 10),
            ],
            Text(l.reportPrompt, style: tx.bodyMedium!.copyWith(color: t.mut)),
            const SizedBox(height: 12),
            for (final r in ReportSheet.reasons) ...[
              _reasonRow(t, tx, l, r.$1),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 2, bottom: 8),
              child: Text(l.reportDetailsHint, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
            ),
            TextField(
              controller: _details,
              maxLength: 250,
              maxLines: 3,
              enabled: !_busy,
              onChanged: (_) => setState(() {}),
              style: tx.bodyMedium!.copyWith(color: t.ink),
              decoration: InputDecoration(
                hintText: l.p20ReportSendHint,
                counterText: '${_details.text.length}/250',
                filled: true,
                fillColor: t.sf2,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: t.pr, width: 2)),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: tx.bodySmall!.copyWith(color: t.danger)),
              ),
            const SizedBox(height: 14),
            BuButton(label: l.reportSend, icon: LucideIcons.send, busy: _busy, onPressed: _busy ? null : _submit),
          ],
        ),
      ),
    );
  }

  Widget _reasonRow(BuTokens t, TextTheme tx, AppLocalizations l, String code) {
    final sel = _reason == code;
    final label = ReportSheet.reasonLabel(l, code);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: sel,
      button: true,
      enabled: !_busy,
      excludeSemantics: true,
      label: label,
      onTap: _busy ? null : () => setState(() => _reason = code),
      child: Material(
        color: sel ? t.soft : t.sf2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _busy ? null : () => setState(() => _reason = code),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                Icon(ReportSheet.reasonIcon(code), size: 18, color: sel ? t.onSoft : t.ink),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: tx.titleSmall!.copyWith(fontWeight: sel ? FontWeight.w800 : FontWeight.w600, color: sel ? t.onSoft : t.ink))),
                const SizedBox(width: 12),
                _Radio(selected: sel),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// 22 dp radyo halkası: seçiliyken marka halkası + iç nokta.
class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.sf,
        shape: BoxShape.circle,
        border: Border.all(color: selected ? t.pr : t.bd, width: 2),
      ),
      child: selected ? Container(width: 10, height: 10, decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle)) : null,
    );
  }
}

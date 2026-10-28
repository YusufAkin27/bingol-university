import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import 'destek_widgets.dart';

Map<String, String> supportTicketCategories(AppLocalizations l) => {
      'ACCOUNT': l.supportCatAccount,
      'TECHNICAL': l.supportCatTechnical,
      'CONTENT': l.supportCatContent,
      'OTHER': l.supportCatOther,
    };

Map<String, String> supportFeedbackCategories(AppLocalizations l) => {
      'BUG': l.supportFbBug,
      'SUGGESTION': l.supportFbSuggestion,
      'COMPLAINT': l.supportFbComplaint,
      'PRAISE': l.supportFbPraise,
      'OTHER': l.supportCatOther,
    };

Map<String, String> supportFeedbackStatuses(AppLocalizations l) => {
      'NEW': l.supportStNew,
      'IN_REVIEW': l.supportStInReview,
      'PLANNED': l.supportStPlanned,
      'DONE': l.supportStDone,
      'REJECTED': l.supportStRejected,
    };

/// Talep durum rozeti: Açık / Yanıtlandı / Kapalı (tasarımdaki .st sınıfları).
class SupportStatusPill extends StatelessWidget {
  const SupportStatusPill(this.status, {super.key});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final (label, bg, fg) = switch (status) {
      'ANSWERED' => (context.l10n.supportStatusAnswered, t.okSoft, t.ok),
      'CLOSED' => (context.l10n.supportStatusClosed, t.sf2, t.mut),
      _ => (context.l10n.supportStatusOpen, t.soft, t.onSoft),
    };
    return _pill(label, bg, fg);
  }
}

/// Geri bildirim/öneri durum rozeti.
class SupportFeedbackPill extends StatelessWidget {
  const SupportFeedbackPill(this.status, {super.key});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final label = supportFeedbackStatuses(context.l10n)[status] ?? context.l10n.supportStNew;
    final (bg, fg) = switch (status) {
      'DONE' => (t.okSoft, t.ok),
      // Tasarımdaki mavi ton (.p-blue).
      'PLANNED' => (_planBg(context), _planFg(context)),
      'IN_REVIEW' => (t.soft, t.onSoft),
      _ => (t.sf2, t.mut),
    };
    return _pill(label, bg, fg);
  }
}

Color _planBg(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? const Color(0xFF1F2B4D) : const Color(0xFFE6ECFA);
Color _planFg(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? const Color(0xFF9DB4F0) : const Color(0xFF2F4FA8);

Widget _pill(String label, Color bg, Color fg) => Container(
      constraints: const BoxConstraints(minHeight: 24),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: BuType.micro.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );

/// Küçük büyük harfli bölüm etiketi (tasarımdaki .lb). Form sayfalarında [form] ile yatay boşluk 4 px olur.
class SupportLabel extends StatelessWidget {
  const SupportLabel(this.text, {super.key, this.form = false});

  final String text;
  final bool form;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsetsDirectional.fromSTEB(form ? 4 : 26, form ? 16 : 20, form ? 4 : 26, form ? 6 : 8),
        child: Text(text,
            style: form
                ? BuType.label.copyWith(color: context.bu.ink, fontWeight: FontWeight.w700)
                : BuType.label.copyWith(letterSpacing: .6, color: context.bu.mut)),
      );
}

/// Tek/çok satırlı yazı alanı, tasarım dilinde.
class SupportField extends StatelessWidget {
  const SupportField({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final int? maxLength;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    OutlineInputBorder b(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: 1.5));
    return TextField(
      controller: controller,
      maxLength: maxLength,
      minLines: minLines,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      style: BuType.body.copyWith(color: t.ink),
      decoration: InputDecoration(
        hintText: hint,
        alignLabelWithHint: true,
        hintStyle: BuType.body.copyWith(color: t.mut),
        filled: true,
        fillColor: t.sf,
        counterStyle: BuType.caption.copyWith(color: t.mut),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: b(t.bd),
        focusedBorder: b(t.pr),
        border: b(t.bd),
      ),
    );
  }
}

/// Seçenek çipleri (kategori seçimi).
class SupportChoices extends StatelessWidget {
  const SupportChoices({super.key, required this.options, required this.value, required this.onChanged});

  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in options.entries)
            DestekChip(label: e.value, selected: e.key == value, onTap: () => onChanged(e.key)),
        ],
      );
}

void supportSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// Hata metni; 429'da sunucu mesajı yoksa bekleme uyarısı verir (Retry-After başlığına ApiError taşımıyor).
String supportError(BuildContext context, Object e) {
  if (e is ApiError && e.status == 429 && e.message.isEmpty) {
    return context.l10n.supportTooManyRequests;
  }
  return errorText(e);
}

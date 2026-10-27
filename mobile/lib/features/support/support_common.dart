import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../core/typography.dart';

const supportTicketCategories = {
  'ACCOUNT': 'Hesap',
  'TECHNICAL': 'Teknik',
  'CONTENT': 'İçerik',
  'OTHER': 'Diğer',
};

const supportFeedbackCategories = {
  'BUG': 'Hata',
  'SUGGESTION': 'Öneri',
  'COMPLAINT': 'Şikâyet',
  'PRAISE': 'Teşekkür',
  'OTHER': 'Diğer',
};

const supportFeedbackStatuses = {
  'NEW': 'Yeni',
  'IN_REVIEW': 'İnceleniyor',
  'PLANNED': 'Planlandı',
  'DONE': 'Tamamlandı',
  'REJECTED': 'Reddedildi',
};

/// Talep durum rozeti: Açık / Yanıtlandı / Kapalı (tasarımdaki .st sınıfları).
class SupportStatusPill extends StatelessWidget {
  const SupportStatusPill(this.status, {super.key});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final (label, bg, fg) = switch (status) {
      'ANSWERED' => ('Yanıtlandı', t.okSoft, t.ok),
      'CLOSED' => ('Kapalı', t.sf2, t.mut),
      _ => ('Açık', t.soft, t.onSoft),
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
    final label = supportFeedbackStatuses[status] ?? 'Yeni';
    final (bg, fg) = switch (status) {
      'DONE' || 'PLANNED' => (t.okSoft, t.ok),
      'IN_REVIEW' => (t.soft, t.onSoft),
      _ => (t.sf2, t.mut),
    };
    return _pill(label, bg, fg);
  }
}

Widget _pill(String label, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: BuType.micro.copyWith(color: fg)),
    );

/// Küçük büyük harfli bölüm etiketi (tasarımdaki .lb). Form sayfalarında [form] ile yatay boşluk 4 px olur.
class SupportLabel extends StatelessWidget {
  const SupportLabel(this.text, {super.key, this.form = false});

  final String text;
  final bool form;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(form ? 4 : 24, 20, form ? 4 : 24, 8),
        child: Text(text,
            style: BuType.label.copyWith(letterSpacing: .5, color: context.bu.mut)),
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
        OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c));
    return TextField(
      controller: controller,
      maxLength: maxLength,
      minLines: minLines,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      style: BuType.body.copyWith(color: t.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: t.mut),
        filled: true,
        fillColor: t.sf,
        counterStyle: TextStyle(color: t.mut),
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
            BuChip(label: e.value, selected: e.key == value, onTap: () => onChanged(e.key)),
        ],
      );
}

void supportSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// Hata metni; 429'da sunucu mesajı yoksa bekleme uyarısı verir (Retry-After başlığına ApiError taşımıyor).
String supportError(Object e) {
  if (e is ApiError && e.status == 429 && e.message.isEmpty) {
    return 'Çok fazla istek gönderdiniz. Lütfen biraz bekleyip tekrar deneyin.';
  }
  return errorText(e);
}

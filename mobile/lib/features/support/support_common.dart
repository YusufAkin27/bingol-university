import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import '../polls/anket_style.dart';

Map<String, String> supportTicketCategories(AppLocalizations l) => {
      'ACCOUNT': l.supportCatAccount,
      'TECHNICAL': l.supportCatTechnical,
      'CONTENT': l.supportCatContent,
      'OTHER': l.supportCatOther,
    };

/// Talep kategorisi simgeleri (form çipleri ve liste).
const Map<String, IconData> supportTicketCategoryIcons = {
  'ACCOUNT': LucideIcons.user,
  'TECHNICAL': LucideIcons.wrench,
  'CONTENT': LucideIcons.fileText,
  'OTHER': LucideIcons.ellipsis,
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

/// Talep durumu için (simge, zemin, yazı, etiket): Açık / Yanıtlandı / Kapalı.
({IconData icon, Color bg, Color fg, String label}) supportTicketStatusStyle(BuildContext context, String? status) {
  final t = context.bu;
  final l = context.l10n;
  return switch (status) {
    'ANSWERED' => (icon: LucideIcons.circleCheck, bg: t.tint(1).bg, fg: t.tint(1).fg, label: l.supportStatusAnswered),
    'CLOSED' => (icon: LucideIcons.lock, bg: t.bd, fg: t.mut, label: l.supportStatusClosed),
    _ => (icon: LucideIcons.messageCircle, bg: t.soft, fg: t.onSoft, label: l.supportStatusOpen),
  };
}

/// Talep durum rozeti: Açık / Yanıtlandı / Kapalı. [dot] true ise solda küçük nokta (başlık hapı), değilse yalın hap (liste).
class SupportStatusPill extends StatelessWidget {
  const SupportStatusPill(this.status, {super.key, this.dot = false});

  final String? status;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final s = supportTicketStatusStyle(context, status);
    if (!dot) return AnketPill(s.label, bg: s.bg, fg: s.fg, small: true);
    final tx = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: s.bg, borderRadius: BuRadius.bPill),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: s.fg, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(s.label, style: tx.labelMedium!.copyWith(color: s.fg, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Liste satırı durum noktası: Açık kırmızı, Yanıtlandı koyu mavi, Kapalı gri.
Color supportStatusDotColor(BuildContext context, String? status) {
  final t = context.bu;
  return switch (status) {
    'ANSWERED' => t.tint(1).fg,
    'CLOSED' => t.mut.withValues(alpha: .5),
    _ => t.pr,
  };
}

/// Geri bildirim/öneri durum rozeti. [dark] true: geri bildirim listesi (Planlandı/Tamamlandı koyu dolgu), false: öneri panosu.
class SupportFeedbackPill extends StatelessWidget {
  const SupportFeedbackPill(this.status, {super.key, this.dark = false});

  final String? status;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final label = supportFeedbackStatuses(context.l10n)[status] ?? context.l10n.supportStNew;
    final cs = Theme.of(context).colorScheme;
    switch (status) {
      case 'DONE':
        return dark ? AnketPill(label, bg: t.ink, fg: t.bg, small: true) : AnketPill(label, bg: t.okSoft, fg: t.ok, icon: LucideIcons.circleCheck, small: true);
      case 'PLANNED':
        return dark
            ? AnketPill(label, bg: t.mut, fg: t.bg, small: true)
            : AnketPill(label, bg: t.tint(1).bg, fg: t.tint(1).fg, icon: LucideIcons.calendarCheck, small: true);
      case 'IN_REVIEW':
        return dark
            ? AnketPill(label, bg: t.tint(1).bg, fg: t.tint(1).fg, small: true)
            : AnketPill(label, bg: t.sf2, fg: t.ink, icon: LucideIcons.search, small: true);
      case 'REJECTED':
        return AnketPill(label, bg: dark ? t.sf2 : cs.errorContainer, fg: dark ? t.mut : t.danger, small: true);
      default:
        return SupportDotPill(label, bg: t.soft, fg: t.onSoft, dot: t.pr);
    }
  }
}

/// Küçük bölüm etiketi (tasarımdaki .lb). Form sayfalarında [form] ile yatay boşluk 4 px olur.
class SupportLabel extends StatelessWidget {
  const SupportLabel(this.text, {super.key, this.form = false});

  final String text;
  final bool form;

  @override
  Widget build(BuildContext context) {
    final tx = Theme.of(context).textTheme;
    final t = context.bu;
    final ar = Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(form ? 4 : 26, form ? 20 : 20, form ? 4 : 26, form ? 8 : 8),
      child: Semantics(
        header: true,
        child: Text(text,
            style: form
                ? tx.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w700)
                : tx.labelMedium!.copyWith(letterSpacing: ar ? 0 : .6, color: t.mut)),
      ),
    );
  }
}

/// Tek/çok satırlı yazı alanı (tema girdisi). [counter] true ise sağ altta "n / max" sayacı.
class SupportField extends StatelessWidget {
  const SupportField({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    this.counter = false,
    this.label,
    this.soft = false,
  });

  final TextEditingController controller;
  final String hint;
  final int? maxLength;
  final int minLines;
  final int maxLines;
  final bool counter;

  /// Ekran okuyucu etiketi.
  final String? label;

  /// true: çerçevesiz dolu (sf2) alan (tasarım 34 formu).
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      label: label,
      textField: true,
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        minLines: minLines,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
        style: tx.bodyLarge!.copyWith(height: 1.45, color: t.ink),
        buildCounter: (ctx, {required currentLength, required isFocused, maxLength}) => counter && maxLength != null
            ? Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(ctx.l10n.profilyardFbCounter('$currentLength', '$maxLength'),
                    style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w600, color: t.mut)),
              )
            : const SizedBox.shrink(),
        decoration: soft
            ? InputDecoration(
                hintText: hint,
                alignLabelWithHint: true,
                filled: true,
                fillColor: t.sf2,
                constraints: BoxConstraints(minHeight: maxLines > 1 ? 150 : 52),
                contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 14),
                border: const OutlineInputBorder(borderRadius: BuRadius.bMd, borderSide: BorderSide.none),
                enabledBorder: const OutlineInputBorder(borderRadius: BuRadius.bMd, borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BuRadius.bMd, borderSide: BorderSide(color: t.pr, width: 2)),
              )
            : InputDecoration(
                hintText: hint,
                alignLabelWithHint: true,
                constraints: BoxConstraints(minHeight: maxLines > 1 ? 150 : 56),
              ),
      ),
    );
  }
}

/// Seçenek çipleri (kategori seçimi): hap çipler, seçili marka tonu, isteğe bağlı simge.
class SupportChoices extends StatelessWidget {
  const SupportChoices({super.key, required this.options, required this.value, required this.onChanged, this.icons});

  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;
  final Map<String, IconData>? icons;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        children: [
          for (final e in options.entries)
            BuChip(label: e.value, selected: e.key == value, icon: icons?[e.key], onTap: () => onChanged(e.key)),
        ],
      );
}

/// Kategori çipleri (tasarım 34): yatay kayar; seçili çip yumuşak marka tonu + onay işareti, diğerleri gri.
class SupportCategoryChips extends StatelessWidget {
  const SupportCategoryChips({super.key, required this.options, required this.value, required this.onChanged});

  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final e in options.entries)
        Semantics(
          button: true,
          selected: e.key == value,
          label: e.value,
          excludeSemantics: true,
          onTap: () => onChanged(e.key),
          child: Material(
            color: e.key == value ? t.soft : t.sf2,
            borderRadius: BuRadius.bPill,
            child: InkWell(
              borderRadius: BuRadius.bPill,
              onTap: () {
                if (e.key != value) buHaptic(BuHaptic.selection);
                onChanged(e.key);
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (e.key == value) ...[Icon(LucideIcons.check, size: 15, color: t.onSoft), const SizedBox(width: 4)],
                    Text(e.value, style: tx.labelMedium!.copyWith(color: e.key == value ? t.onSoft : t.ink, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// Form hatası kutusu: hata zemini + simge + metin (sesli okunur).
class SupportErrorNote extends StatelessWidget {
  const SupportErrorNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 14, 12),
        decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BuRadius.bMd),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(LucideIcons.circleAlert, size: 18, color: t.danger)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: cs.onErrorContainer, height: 1.4))),
        ]),
      ),
    );
  }
}

void supportSnack(BuildContext context, String text, [BuToastKind kind = BuToastKind.info]) =>
    BuToast.show(context, text, kind: kind);

/// Hata metni; 429'da sunucu mesajı yoksa bekleme uyarısı verir (Retry-After başlığına ApiError taşımıyor).
String supportError(BuildContext context, Object e) {
  if (e is ApiError && e.status == 429 && e.message.isEmpty) {
    return context.l10n.supportTooManyRequests;
  }
  return errorText(e);
}

/// Yönetici/destek ekibi yanıtı: marka tonlu kutu, başta kalın çizgi ve "Destek ekibi" etiketi.
class SupportStaffReply extends StatelessWidget {
  const SupportStaffReply({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 12, 12),
      decoration: BoxDecoration(
        color: t.soft,
        borderRadius: BuRadius.bSm,
        border: BorderDirectional(start: BorderSide(color: t.pr, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(LucideIcons.headset, size: 14, color: t.onSoft),
          const SizedBox(width: 6),
          Text(context.l10n.supportStaff, style: tx.labelMedium!.copyWith(color: t.onSoft, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        Text(text, style: tx.bodyMedium!.copyWith(height: 1.45, color: t.onSoft)),
      ]),
    );
  }
}

/// Bilgi/uyarı şeridi (tasarım 34): yuvarlak simge karosu + metin; hata zeminli (hız sınırı vb.).
class SupportNote extends StatelessWidget {
  const SupportNote({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 16, 14),
        decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: t.danger.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)),
            child: ExcludeSemantics(child: Icon(icon, size: 22, color: t.danger)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.ink, height: 1.4))),
        ]),
      ),
    );
  }
}

/// Bölüm başlığı: küçük, kalın, büyük harfli (tasarım 34/35); tek satırda kalır, sığmazsa küçülür.
class SupportHeading extends StatelessWidget {
  const SupportHeading(this.text, {super.key, this.padding = const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 10)});

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final lang = Localizations.localeOf(context).languageCode;
    final up = lang == 'tr' ? trUpper(text) : (lang == 'ar' ? text : text.toUpperCase());
    return Padding(
      padding: padding,
      child: Semantics(
        header: true,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(up,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800, letterSpacing: lang == 'ar' ? 0 : .8)),
        ),
      ),
    );
  }
}

/// Boş durum kartı: gri simge karosu + kalın başlık + açıklama.
class SupportEmptyCard extends StatelessWidget {
  const SupportEmptyCard({super.key, required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return BuCard(
      padding: const EdgeInsetsDirectional.all(16),
      child: SizedBox(
        width: double.infinity,
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16)),
            child: ExcludeSemantics(child: Icon(icon, size: 24, color: t.ink)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(header: true, child: Text(title, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800, height: 1.3))),
              const SizedBox(height: 2),
              Text(body, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.4)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Noktalı hap ("● Yeni").
class SupportDotPill extends StatelessWidget {
  const SupportDotPill(this.label, {super.key, required this.bg, required this.fg, required this.dot});

  final String label;
  final Color bg;
  final Color fg;
  final Color dot;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BuRadius.bPill),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: fg, fontWeight: FontWeight.w700))),
        ]),
      );
}

/// Yükleme hatası satırı (tasarım 34/35): kırmızı zemin, başlık + açıklama, beyaz "Yeniden dene" düğmesi.
class SupportLoadError extends StatelessWidget {
  const SupportLoadError({super.key, required this.title, required this.body, required this.retryLabel, required this.onRetry});

  final String title;
  final String body;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
        decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: t.danger.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)),
            child: ExcludeSemantics(child: Icon(LucideIcons.circleAlert, size: 22, color: t.danger)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: tx.titleSmall!.copyWith(color: t.danger, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(body, maxLines: 3, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.danger.withValues(alpha: .85), height: 1.35)),
            ]),
          ),
          const SizedBox(width: 10),
          Material(
            color: t.sf,
            borderRadius: BuRadius.bPill,
            child: InkWell(
              borderRadius: BuRadius.bPill,
              onTap: onRetry,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(LucideIcons.refreshCw, size: 16, color: t.danger),
                    const SizedBox(width: 6),
                    Text(retryLabel, style: tx.labelLarge!.copyWith(color: t.danger, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

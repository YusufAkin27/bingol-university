import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../widgets/bu.dart';
import '../../data/forum_api.dart';
import '../../data/forum_models.dart';
import '../pages/forum_category_picker_page.dart';

/// Forum formlarında ortak giriş kutusu: yüzey zemini + ince çizgi; odakta/hatada çizgi vurgulanır.
/// İçine çıplak (kenarlıksız) bir `TextField` konur ([composeInputDecoration]).
class ComposeBox extends StatelessWidget {
  const ComposeBox({super.key, required this.child, this.error = false, this.minHeight = BuSize.field, this.trailing});

  final Widget child;
  final bool error;
  final double minHeight;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return AnimatedContainer(
      duration: BuMotion.of(context, BuMotion.short),
      curve: BuMotion.standard,
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(BuRadius.lg),
        border: Border.all(color: error ? t.danger : t.bdStrong, width: error ? 1.5 : 1),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 8, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: child),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// Kenarlıksız, sayaçsız giriş süsü ([ComposeBox] içindir).
InputDecoration composeInputDecoration(BuildContext context, {String? hint, EdgeInsetsGeometry? padding}) {
  final t = context.bu;
  final tt = Theme.of(context).textTheme;
  return InputDecoration(
    hintText: hint,
    hintStyle: tt.bodyLarge?.copyWith(color: t.mut, fontWeight: FontWeight.w400),
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    isDense: true,
    counterText: '',
    contentPadding: padding ?? const EdgeInsets.symmetric(vertical: 14),
  );
}

/// Başlık + (isteğe bağlı) alt açıklama + sağda anahtar; satırın tamamı dokunulur (en az 48 dp).
class ComposeSwitchRow extends StatelessWidget {
  const ComposeSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.note,
    this.icon,
  });

  final String label;
  final String? hint;
  final String? note;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      toggled: value,
      label: label,
      child: InkWell(
        borderRadius: BuRadius.bMd,
        onTap: onChanged == null
            ? null
            : () {
                buHaptic(BuHaptic.selection);
                onChanged!(!value);
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BuSize.touch),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              if (icon != null) ...[Icon(icon, size: 20, color: t.ink), const SizedBox(width: 12)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  ExcludeSemantics(
                    child: Text(label, style: tt.bodyLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
                  ),
                  if (hint != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(hint!, style: tt.bodySmall?.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
                    ),
                  if (note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(note!, style: tt.bodySmall?.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
                    ),
                ]),
              ),
              const SizedBox(width: 8),
              ExcludeSemantics(child: Switch(value: value, onChanged: onChanged)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Kategori seçici satırı: seçili ad (ya da "Kategori seç") + aşağı ok; dokununca alt sayfa listesi.
/// Yüklenirken / hata durumunda satır kendi durumunu gösterir ([onRetry] ile yeniden dener).
class CategoryPickerRow extends StatelessWidget {
  const CategoryPickerRow({
    super.key,
    required this.api,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    this.loading = false,
    this.failed = false,
    this.onRetry,
    this.fallbackName,
    this.enabled = true,
  });

  /// Seçici sunucu aramasını (`?q=`) ve gerekirse yüklemeyi bu uçla yapar.
  final ForumApi api;
  final List<ForumCategory> categories;
  final int? selectedId;
  final ValueChanged<ForumCategory> onSelected;
  final bool loading;
  final bool failed;
  final VoidCallback? onRetry;

  /// Kategori listesi gelmeden gösterilecek ad (düzenlemede mevcut kategori).
  final String? fallbackName;
  final bool enabled;

  String? get _selectedName {
    for (final c in categories) {
      if (c.id == selectedId) return c.name;
    }
    return selectedId == null ? null : fallbackName;
  }

  /// Aramalı, gruplu kategori seçicisini açar (tam sayfa; "Tümü" satırı yok: konu bir kategoriye aittir).
  Future<void> _open(BuildContext context) async {
    final picked =
        await openForumCategoryPicker(context, api: api, categories: categories, selectedId: selectedId, allowAll: false);
    final c = picked?.category;
    if (c != null) onSelected(c);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final name = _selectedName;
    final String text;
    final Color color;
    if (loading && name == null) {
      text = l.forumComposeCategoryLoading;
      color = t.mut;
    } else if (failed && categories.isEmpty && name == null) {
      text = l.forumComposeCategoryError;
      color = t.danger;
    } else {
      text = name ?? l.forumComposeCategoryPick;
      color = name == null ? t.mut : t.ink;
    }
    final canRetry = failed && categories.isEmpty;
    return Semantics(
      button: true,
      label: '${l.forumComposeCategoryLabel}: $text',
      excludeSemantics: true,
      child: Material(
        color: t.sf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.md), side: BorderSide(color: t.bd)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('forumCategoryField'),
          onTap: !enabled
              ? null
              : canRetry
                  ? onRetry
                  : (categories.isEmpty ? null : () => _open(context)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: BuSize.field),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8),
              child: Row(children: [
                Icon(BuIcons.hash, size: 18, color: t.mut),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: tt.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.w400))),
                if (loading && categories.isEmpty)
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: t.mut))
                else if (canRetry)
                  Icon(BuIcons.refreshCw, size: 18, color: t.mut)
                else
                  Icon(BuIcons.chevronDown, size: 18, color: t.mut),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

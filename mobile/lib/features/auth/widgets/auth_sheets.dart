import 'package:flutter/material.dart';

import '../../../core/locale_controller.dart';
import '../../../core/theme.dart';
import '../../../core/typography.dart';
import '../../../widgets/bu_widgets.dart';
import 'auth_motion.dart';

/// Seçici satırı verisi.
class AuthPickerItem<T> {
  const AuthPickerItem(this.value, this.title, {this.subtitle});

  final T value;
  final String title;
  final String? subtitle;
}

/// Sürüklenebilir, arama destekli alt sayfa. [itemsFor] sorguya göre listeyi üretir (aksan duyarsız süzme çağıranda).
Future<T?> showAuthPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<AuthPickerItem<T>> Function(String query) itemsFor,
  required bool Function(T value) isSelected,
  bool searchable = true,
  String? searchHint,
  String? emptyText,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .45),
    builder: (_) => _PickerSheet<T>(
      title: title,
      itemsFor: itemsFor,
      isSelected: isSelected,
      searchable: searchable,
      searchHint: searchHint,
      emptyText: emptyText,
    ),
  );
}

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.itemsFor,
    required this.isSelected,
    required this.searchable,
    this.searchHint,
    this.emptyText,
  });

  final String title;
  final List<AuthPickerItem<T>> Function(String query) itemsFor;
  final bool Function(T value) isSelected;
  final bool searchable;
  final String? searchHint;
  final String? emptyText;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final items = widget.itemsFor(_q.text);
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: kb),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: widget.searchable ? .86 : .62,
        minChildSize: .45,
        maxChildSize: .95,
        snap: true,
        builder: (context, scroll) => DecoratedBox(
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: t.bd)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: t.bd, borderRadius: BorderRadius.circular(3)),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 14, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(widget.title,
                            style: BuType.display.copyWith(color: t.ink, fontSize: 21, letterSpacing: -.3, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.commonClose,
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: Icon(LucideIcons.x, size: 20, color: t.mut),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ],
                ),
              ),
              if (widget.searchable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: BuSearchField(hint: widget.searchHint ?? context.l10n.pickSearch, controller: _q, onChanged: (_) => setState(() {})),
                ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.searchX, size: 34, color: t.mut.withValues(alpha: .6)),
                              const SizedBox(height: 10),
                              Text(widget.emptyText ?? context.l10n.pickNoResults,
                                  textAlign: TextAlign.center, style: BuType.body.copyWith(color: t.mut)),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scroll,
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(12, 4, 12, 16 + MediaQuery.viewPaddingOf(context).bottom),
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final it = items[i];
                          return _PickerRow(
                            title: it.title,
                            subtitle: it.subtitle,
                            selected: widget.isSelected(it.value),
                            onTap: () {
                              authHaptic(AuthHaptic.tap);
                              Navigator.pop(context, it.value);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({required this.title, this.subtitle, required this.selected, required this.onTap});

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? t.soft : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: BuType.bodyStrong.copyWith(
                              color: selected ? t.onSoft : t.ink, fontSize: 15, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: BuType.caption.copyWith(color: selected ? t.onSoft.withValues(alpha: .8) : t.mut, fontSize: 12.5)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: t.pr),
                    child: Icon(LucideIcons.check, size: 15, color: t.onPr),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Üst köşede küçük dil düğmesi: globe + TR/EN/ع; dokununca dil sayfası. Dil denetleyicisi yoksa görünmez.
class AuthLanguageButton extends StatelessWidget {
  const AuthLanguageButton({super.key, this.onDark = false});

  /// Kırmızı zemin üstünde (açılış ekranı) açık renkli görünüm.
  final bool onDark;

  static const _names = {'tr': 'Türkçe', 'en': 'English', 'ar': 'العربية'};
  static const _codes = {'tr': 'TR', 'en': 'EN', 'ar': 'AR'};

  @override
  Widget build(BuildContext context) {
    final lc = LocaleController.current;
    if (lc == null) return const SizedBox.shrink();
    final t = context.bu;
    final code = Localizations.localeOf(context).languageCode;
    final fg = onDark ? Colors.white : t.ink;
    return Semantics(
      button: true,
      label: context.l10n.welcomeLanguage,
      child: Material(
        color: onDark ? Colors.white.withValues(alpha: .16) : t.sf,
        shape: StadiumBorder(side: BorderSide(color: onDark ? Colors.white.withValues(alpha: .28) : t.bd)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () async {
            final r = await showAuthPickerSheet<String>(
              context,
              title: context.l10n.authLangTitle,
              searchable: false,
              itemsFor: (_) => [for (final e in _names.entries) AuthPickerItem(e.key, e.value)],
              isSelected: (v) => v == code,
            );
            if (r != null && r != code) lc.set(r);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.globe, size: 17, color: fg),
                  const SizedBox(width: 7),
                  Text(_codes[code] ?? code.toUpperCase(),
                      style: BuType.label.copyWith(color: fg, fontWeight: FontWeight.w800, fontSize: 13.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

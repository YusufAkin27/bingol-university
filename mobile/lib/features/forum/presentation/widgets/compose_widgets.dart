import 'package:flutter/material.dart';

import '../../../../widgets/bu.dart';

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
        borderRadius: BorderRadius.circular(BuRadius.md),
        border: Border.all(color: error ? t.danger : t.bd, width: error ? 1.5 : 1),
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

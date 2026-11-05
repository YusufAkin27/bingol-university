import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../widgets/bu_pressable.dart';

/// Forum alt sayfalarının ortak satırı: simge + metin, 56 dp, tehlikeli eylemde uyarı rengi. Seçilince [value] ile
/// kapatır (`Navigator.pop(value)`).
class ForumSheetRow<T> extends StatelessWidget {
  const ForumSheetRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.danger = false,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final T value;
  final bool danger;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: BuPressable(
        onTap: () => Navigator.of(context).pop(value),
        scale: .99,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Icon(icon, size: 22, color: iconColor ?? (danger ? t.danger : t.mut)),
              const SizedBox(width: 16),
              Expanded(child: Text(label, style: tx.bodyLarge!.copyWith(color: danger ? t.danger : t.ink))),
            ]),
          ),
        ),
      ),
    );
  }
}

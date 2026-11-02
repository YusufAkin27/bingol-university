import 'package:flutter/material.dart';

import 'bu.dart';

/// Liste üstündeki "Takip istekleri (n)" / "Mesaj istekleri (n)" giriş satırı: 56 dp, solda yumuşak daire içinde simge,
/// ortada tek satır etiket (büyük yazıda 2 satır), sağda yön oku. Altında 1 dp çizgi. Dokununca [onTap].
class RequestsEntryRow extends StatelessWidget {
  const RequestsEntryRow({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: BuPressable(
        scale: .99,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () {
              buHaptic(BuHaptic.selection);
              onTap();
            },
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 16, 8),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                      child: Icon(icon, size: 20, color: t.onSoft),
                    ),
                    BuGap.w14,
                    Expanded(
                      child: Text(label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tx.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: t.ink)),
                    ),
                    const SizedBox(width: 8),
                    Icon(buDirIcon(context, BuIcons.chevronRight), size: 20, color: t.mut),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

/// Kulüp logosu: yüklenmişse görsel, yoksa kategori tonlu baş harfler; yuvarlatılmış kare.
class ClubLogoBox extends StatelessWidget {
  const ClubLogoBox({super.key, required this.club, required this.size});

  final Map<String, dynamic> club;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final name = (club['name'] ?? '').toString();
    final url = (club['logoUrl'] ?? club['coverUrl'])?.toString();
    // Kategori/kimlik başına renk yok: tek nötr ton.
    final tint = BuTint(t.sf2, t.ink);
    if (fileUrl(url) != null) {
      return ClipRRect(borderRadius: BorderRadius.circular(size * .3), child: BuImage(url, width: size, height: size));
    }
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: tint.bg, borderRadius: BorderRadius.circular(size * .3)),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(initialsOf(name), style: Theme.of(context).textTheme.titleMedium!.copyWith(color: tint.fg, fontWeight: FontWeight.w400)),
          ),
        ),
      ),
    );
  }
}

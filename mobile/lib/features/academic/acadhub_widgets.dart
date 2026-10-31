import 'package:flutter/material.dart';

import '../../widgets/bu.dart';
import 'acad_ref_widgets.dart';
import 'akad_widgets.dart';

/// Akademik giriş sayfasının parçaları (Stitch v3 01): "Sıradaki sınav" bloğu ve kartsız gezinme satırları.

/// "Sıradaki sınav": etiket (muted, büyük harf), ad 20 sp/700 + sağda geri sayım, muted "tarih · saat · derslik".
class AcadhubNextExam extends StatelessWidget {
  const AcadhubNextExam({super.key, required this.label, required this.title, required this.detail, this.countdown, this.onTap});

  final String label, title, detail;
  final String? countdown;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      button: onTap != null,
      excludeSemantics: true,
      label: '$label. $title. $detail${countdown == null ? '' : '. $countdown'}',
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(akadUpper(context, label), maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelSmall!.copyWith(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: .6, color: t.mut)),
            const SizedBox(height: 2),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.headlineSmall!.copyWith(fontWeight: FontWeight.w700, color: t.ink))),
              if (countdown != null) ...[
                const SizedBox(width: 12),
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 140), child: Text(countdown!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w500, color: t.mut))),
              ],
            ]),
            const SizedBox(height: 5),
            Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.mut)),
          ]),
        ),
      ),
    );
  }
}

/// Kartsız gezinme satırı: başlık 17 sp/600 + muted tek satır + chevron; altta 1 dp ayraç.
class AcadhubNavRow extends StatelessWidget {
  const AcadhubNavRow({super.key, required this.title, required this.sub, this.onTap});

  final String title, sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return AcadRow(
      onTap: onTap,
      semanticLabel: '$title. $sub',
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: t.ink)),
            const SizedBox(height: 3),
            Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.mut)),
          ]),
        ),
        const SizedBox(width: 12),
        ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 20, color: t.mut)),
      ]),
    );
  }
}

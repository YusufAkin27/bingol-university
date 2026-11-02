import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

/// Bildirim kartı: okunmamışta marka çerçevesi ve nokta, okunduğunda nötr yüzey.
/// Dekoratif ikon aynı font ailesinden gelir; tür, zaman ve okunmamış semantiği korunur.
class NotifRow extends StatelessWidget {
  const NotifRow({
    super.key,
    required this.title,
    required this.typeLabel,
    required this.time,
    required this.unread,
    required this.onTap,
    this.body = '',
    this.unreadLabel,
  });

  final String title, typeLabel, time, body;
  final bool unread;
  final VoidCallback onTap;
  final String? unreadLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final small = BuType.caption.copyWith(fontSize: 12, height: 1.4, color: t.mut);
    return Semantics(
      button: true,
      // Okunmamış bilgisi + tür + zaman tek okuma: "Okunmamış, Duyuru, 5 dk".
      label: [if (unread && unreadLabel != null) unreadLabel!, typeLabel, time].where((s) => s.isNotEmpty).join(', '),
      // Basılı tutunca hafif küçülür (dokunmayı içerideki InkWell yakalar).
      child: BuPressable(
        scale: .985,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DecoratedBox(
          decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(20), border: Border.all(color: unread ? t.selectedBorder : t.bd)),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ExcludeSemantics(child: Container(
                    width: 36, height: 40,
                    decoration: BoxDecoration(color: unread ? t.soft : t.sf2, borderRadius: BorderRadius.circular(12)),
                    child: Icon(BuIcons.bell, size: 21, color: unread ? t.onSoft : t.mut),
                  )),
                  const SizedBox(width: 8),
                  // Okunmamış noktası okunduğunda solar; mevcut erişilebilirlik korunur.
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: SizedBox(
                      width: 8,
                      height: 8,
                      child: AnimatedScale(
                        key: const ValueKey('notif-unread-dot'),
                        scale: unread ? 1 : 0,
                        duration: BuMotion.of(context, BuMotion.medium),
                        curve: BuMotion.settle, // rozet yerleşmesi (~%3 taşma)
                        child: AnimatedOpacity(
                          opacity: unread ? 1 : 0,
                          duration: BuMotion.of(context, BuMotion.short),
                          child: DecoratedBox(decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                        Expanded(child: Text(typeLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: small)),
                        const SizedBox(width: 8),
                        Text(time, maxLines: 1, style: small.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                      ]),
                      const SizedBox(height: 2),
                      // Gövde yoksa başlık iki satıra kadar okunur (mesajın kendisi); gövde varsa tek satır.
                      // Okundu olunca başlık yumuşakça hafifler (ton, 250 ms).
                      AnimatedDefaultTextStyle(
                        duration: BuMotion.of(context, BuMotion.medium),
                        maxLines: body.isEmpty ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: BuType.caption.copyWith(
                            fontSize: 15, height: 1.4, fontWeight: FontWeight.w600, color: unread ? t.ink : Color.lerp(t.ink, t.mut, .3)),
                        child: Text(title, maxLines: body.isEmpty ? 2 : 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (body.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(body, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(fontSize: 14, height: 1.4, color: t.mut)),
                        ),
                    ]),
                  ),
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

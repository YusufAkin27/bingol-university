import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

/// Bildirim satırı (Stitch v3): kart yok; satır sayfa zemininde, altında 1 dp `bd` çizgi. Solda 8 dp `pr`
/// okunmamış noktası (okunmuşta yeri boş kalır, hizalama sabit), yanında: üstte tür etiketi + zaman (12 sp
/// soluk), başlık (16 sp/600; gövdesizse 2 satır), gövde (14 sp soluk, tek satır). Dikey iç 14 dp, nokta
/// ile metin arası 12 dp. Yatay 20 dp kenar boşluğu satırın dışındadır (çizgi 20 dp içeriden başlar).
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
        child: DecoratedBox(
          decoration: BoxDecoration(color: t.bg, border: Border(bottom: BorderSide(color: t.bd))),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Okunmamış noktası: okundu olunca küçülerek solar (yer korunur; yalnız transform + opaklık).
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: SizedBox(
                      width: 8,
                      height: 8,
                      child: AnimatedScale(
                        key: const ValueKey('notif-unread-dot'),
                        scale: unread ? 1 : 0,
                        duration: BuMotion.of(context, BuMotion.medium),
                        curve: BuMotion.emphasizedDecelerate,
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
    );
  }
}

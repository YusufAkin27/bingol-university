import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

/// Bildirim satırı (tur 3, minimal): solda tek tonlu (mavi) simge kutusu, yanında başlık + en çok iki satır gövde,
/// sağ üstte kısa zaman. Okunmamışta simge kutusunun köşesinde tek vurgu noktası (marka kırmızısı) ve kalın başlık.
/// Tür etiketi ekranda çizilmez; ekran okuyucu için anlamsal etikette yer alır.
class NotifRow extends StatelessWidget {
  const NotifRow({
    super.key,
    required this.icon,
    required this.title,
    required this.typeLabel,
    required this.time,
    required this.unread,
    required this.onTap,
    this.body = '',
    this.unreadLabel,
  });

  final IconData icon;
  final String title, typeLabel, time, body;
  final bool unread;
  final VoidCallback onTap;
  final String? unreadLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    const radius = BuRadius.bLg;
    return Semantics(
      button: true,
      // Okunmamış bilgisi + tür + zaman tek okuma: "Okunmamış, Duyuru, 5 dk".
      label: [if (unread && unreadLabel != null) unreadLabel!, typeLabel, time].where((s) => s.isNotEmpty).join(', '),
      // Basılı tutunca hafif küçülür (dokunmayı içerideki InkWell yakalar).
      child: BuPressable(
        scale: .985,
        child: Container(
          decoration: BoxDecoration(
            color: t.sf,
            borderRadius: radius,
            border: Border.all(color: t.bd.withValues(alpha: .6)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.only(top: 2, bottom: 2, left: 2, right: 2),
                        decoration: BoxDecoration(color: t.infoSoft, borderRadius: BuRadius.bSm),
                        child: Icon(icon, size: 22, color: t.onInfoSoft),
                      ),
                      // Okundu olunca nokta küçülerek solar (ağaçta kalır; yalnız transform + opaklık).
                      PositionedDirectional(
                        end: -2,
                        top: -2,
                        child: AnimatedScale(
                          key: const ValueKey('notif-unread-dot'),
                          scale: unread ? 1 : 0,
                          duration: BuMotion.of(context, BuMotion.medium),
                          curve: BuMotion.emphasizedDecelerate,
                          child: AnimatedOpacity(
                            opacity: unread ? 1 : 0,
                            duration: BuMotion.of(context, BuMotion.short),
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                  color: t.pr, shape: BoxShape.circle, border: Border.all(color: t.sf, width: 2)),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            // Gövde yoksa başlık iki satıra kadar okunur (mesajın kendisi); gövde varsa tek satır.
                            // Okundu olunca başlık yumuşakça hafifler (kalınlık + ton, 250 ms).
                            Expanded(
                              child: AnimatedDefaultTextStyle(
                                duration: BuMotion.of(context, BuMotion.medium),
                                maxLines: body.isEmpty ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: tx.titleMedium!.copyWith(
                                    height: 1.25,
                                    color: unread ? t.ink : Color.lerp(t.ink, t.mut, .3),
                                    fontWeight: unread ? FontWeight.w800 : FontWeight.w600),
                                child: Text(title, maxLines: body.isEmpty ? 2 : 1, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(time,
                                  maxLines: 1,
                                  style: tx.labelMedium!.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: t.mut,
                                      fontFeatures: const [FontFeature.tabularFigures()])),
                            ),
                          ]),
                          if (body.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: tx.bodyMedium!.copyWith(height: 1.4, color: t.mut)),
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

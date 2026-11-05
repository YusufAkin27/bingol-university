import 'package:flutter/material.dart';

/// Varsayılan profil görseli: kullanıcının profil fotoğrafı YOKSA, yüklenirken ya da yüklenemezse HER avatarın
/// yerinde durur (sohbet, arama, Keşfet, takipçi, yorum, öneri, bildirim...). Baş harf ya da ikon silueti çizilmez.
///
/// Tek varlık dosyası (`assets/branding/default_avatar.png`, 512 px, koyu zemin + gri disk + açık baş-omuz silueti).
/// Görsel temadan bağımsızdır; şekli/kenarı çağıran belirler (`BuAvatar` yuvarlak ya da yuvarlatılmış kare kırpar),
/// burada yalnız kareyi `BoxFit.cover` ile doldurur. Çözümleme boyutu `size x dpr` ile sınırlıdır ve `ImageCache`
/// aynı boyutlu çözümü paylaşır: çok satırlı listede görsel BİR kez çözülür (`gaplessPlayback`).
///
/// [group] true: kişi değil grup/kulüp/etkinlik yedeği (`default_group.png`). Görsel dekoratiftir (anlamsal etiketi
/// yok; kişi adı çağıranın `Semantics`/`Text`inde durur).
class BuDefaultAvatar extends StatelessWidget {
  const BuDefaultAvatar({super.key, this.size = 48, this.group = false});

  static const String personAsset = 'assets/branding/default_avatar.png';
  static const String groupAsset = 'assets/branding/default_group.png';

  final double size;

  /// true: grup/kulüp/etkinlik yedek görseli (kişi avatarı değildir).
  final bool group;

  @override
  Widget build(BuildContext context) {
    final px = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return ExcludeSemantics(
      child: Image.asset(
        group ? groupAsset : personAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: px,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../widgets/bu.dart';

/// Yer tutucu ekran: MB-A `forum_routes.dart`'ı ilk yayınlarken henüz yazılmamış ekranlar için kullanır.
/// Gerçek ekranı yazan ajan KENDİ dosyasında sayfayı tamamlayıp `forum_routes.dart` içindeki ilgili satırı değiştirir.
/// Görünür başlık yok (kullanıcı kuralı); geri düğmesi + tanım etiketi (ekran okuyucu) kalır.
class ForumPlaceholderPage extends StatelessWidget {
  const ForumPlaceholderPage({super.key, required this.name});

  /// Yalnız ekran okuyucu etiketi ve testler için (kullanıcıya metin olarak çizilmez).
  final String name;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(backgroundColor: t.bg, scrolledUnderElevation: 0),
      body: Semantics(
        label: name,
        child: Center(child: Icon(BuIcons.messageSquare, size: 32, color: t.mut)),
      ),
    );
  }
}

// W1-G / T-090: Keşfet, etkinlik, haber küçük resmi, menü ve profil görselleri artık diske yazan
// `persistentNetworkImage` (DiskNetworkImage) ile yüklenir; `Image.network` (diske yazmaz, keep-alive yok) kalmadı.
import 'package:bu_kampus/core/cache/image_disk_cache.dart';
import 'package:bu_kampus/features/events/event_cover.dart';
import 'package:bu_kampus/features/menu/menu_photo.dart';
import 'package:bu_kampus/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Image widget'ının asıl sağlayıcısı (ResizeImage sarmalayıcısı açılır).
ImageProvider _inner(WidgetTester t, Finder f) {
  var p = t.widget<Image>(f).image;
  while (p is ResizeImage) {
    p = p.imageProvider;
  }
  return p;
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('EventCoverImage: DiskNetworkImage (Image.network değil)', (tester) async {
    await tester.pumpWidget(buildApp(const SizedBox(width: 200, height: 100, child: EventCoverImage(url: 'https://x.test/files/cover.jpg'))));
    expect(_inner(tester, find.byType(Image)), isA<DiskNetworkImage>());
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('NewsThumb: DiskNetworkImage', (tester) async {
    await tester.pumpWidget(buildApp(const NewsThumb('https://x.test/files/n.jpg', width: 80, height: 80, radius: 8)));
    expect(_inner(tester, find.byType(Image)), isA<DiskNetworkImage>());
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('MenuPhotoGate: DiskNetworkImage ve ekran genişliğine göre küçültülmüş çözümleme (ResizeImage)', (tester) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(MenuPhotoGate(url: 'https://x.test/files/menu.jpg', builder: (c, photo) => SizedBox(width: 300, height: 200, child: photo)), size: kPhoneMedium));
    final img = tester.widget<Image>(find.byType(Image));
    expect(img.image, isA<ResizeImage>(), reason: 'menü fotoğrafı tam çözünürlükte belleğe açılmamalı');
    expect(_inner(tester, find.byType(Image)), isA<DiskNetworkImage>());
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('persist:false (tek gösterimlik vb.) NetworkImage kalır, diske yazmaz', (tester) async {
    final p = persistentNetworkImage('https://x.test/files/once.jpg', persist: false);
    var inner = p;
    while (inner is ResizeImage) {
      inner = inner.imageProvider;
    }
    expect(inner, isA<NetworkImage>());
  });
}

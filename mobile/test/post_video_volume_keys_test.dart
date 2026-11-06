import 'package:bu_kampus/features/posts/post_video.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    postVideoMuted.value = false;
    PostVideoVolumeKeys.reset();
  });

  test('varsayilan ses ACIK', () {
    expect(postVideoMuted.value, isFalse);
  });

  test('ses artirma tusu: ilk bildirim yalniz baslangic seviyesidir, sesi degistirmez', () {
    postVideoMuted.value = true;
    PostVideoVolumeKeys.onVolume(0.4);
    expect(postVideoMuted.value, isTrue);
  });

  test('sistem sesi YUKSELINCE sessizdeki video sesi acilir', () {
    PostVideoVolumeKeys.onVolume(0.4);
    postVideoMuted.value = true;
    PostVideoVolumeKeys.onVolume(0.45);
    expect(postVideoMuted.value, isFalse);
  });

  test('ses ALCALINCA veya ayni kalinca sessiz video acilmaz', () {
    PostVideoVolumeKeys.onVolume(0.5);
    postVideoMuted.value = true;
    PostVideoVolumeKeys.onVolume(0.4);
    expect(postVideoMuted.value, isTrue);
    PostVideoVolumeKeys.onVolume(0.4);
    expect(postVideoMuted.value, isTrue);
  });
}

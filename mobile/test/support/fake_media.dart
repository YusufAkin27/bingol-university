import 'dart:typed_data';

import 'package:bu_kampus/features/chat/media_library.dart';
import 'package:bu_kampus/features/chat/media_pick.dart';

/// 1x1 PNG (küçük resim ve fotoğraf baytı olarak).
final fakePng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, //
  0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, 0x00, 0x05, 0xFE, 0x02, 0xFE, 0xA7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Platform kanalı kullanmayan sahte galeri.
class FakeMediaLibrary implements MediaLibrary {
  FakeMediaLibrary(this.all, {this.access = LibraryAccess.full, this.albumList = const []});

  /// En yeni önce.
  final List<GalleryItem> all;
  final LibraryAccess access;
  final List<GalleryAlbum> albumList;

  final pagesRequested = <int>[];
  int settingsOpened = 0;
  int limitedOpened = 0;

  /// n adet fotoğraf (`p1`..`pn`) ve isteğe bağlı videolar.
  static FakeMediaLibrary photos(int n, {List<GalleryItem> videos = const []}) => FakeMediaLibrary([
        ...videos,
        for (var i = 1; i <= n; i++) GalleryItem(id: 'p$i', isVideo: false),
      ]);

  static GalleryItem video(String id, {int ms = 12000}) => GalleryItem(id: id, isVideo: true, durationMs: ms);

  @override
  Future<LibraryAccess> requestAccess() async => access;

  @override
  Future<List<GalleryAlbum>> albums() async => albumList;

  @override
  Future<List<GalleryItem>> items(String? albumId, {required int page, required int size}) async {
    pagesRequested.add(page);
    final from = page * size;
    if (from >= all.length) return const [];
    return all.sublist(from, (from + size).clamp(0, all.length));
  }

  @override
  Future<Uint8List?> thumb(GalleryItem item, int size) async => fakePng;

  @override
  Future<Uint8List?> imageBytes(GalleryItem item) async => fakePng;

  @override
  Future<String?> videoPath(GalleryItem item) async => '/orig.mp4';

  @override
  Future<void> manageLimited() async => limitedOpened++;

  @override
  Future<void> openSettings() async => settingsOpened++;
}

/// Kamera sahtesi için hazır fotoğraf/video öğesi.
MediaPick fakePhotoPick(String key) => MediaPick(
      key: key,
      isVideo: false,
      thumb: (_) async => fakePng,
      imageBytes: () async => fakePng,
    );

MediaPick fakeVideoPick(String key, {int ms = 8000}) => MediaPick(
      key: key,
      isVideo: true,
      durationMs: ms,
      thumb: (_) async => fakePng,
      videoPath: () async => '/orig.mp4',
    );

import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart' as pm;

/// Galeri erişim düzeyi (iOS 14+ "sınırlı erişim" ve Android 14 kısmi erişim dahil).
enum LibraryAccess { full, limited, denied }

/// Galerideki albüm (ilki "Tümü" olur).
class GalleryAlbum {
  const GalleryAlbum({required this.id, required this.name, this.count = 0, this.isAll = false});
  final String id;
  final String name;
  final int count;
  final bool isAll;
}

/// Izgaradaki tek öğe (fotoğraf ya da video). [ref] sağlayıcıya özgü kimliktir.
class GalleryItem {
  const GalleryItem({required this.id, required this.isVideo, this.durationMs = 0, this.ref});
  final String id;
  final bool isVideo;
  final int durationMs;
  final Object? ref;
}

/// Galeri sağlayıcısı. Üretimde [PhotoManagerLibrary]; testlerde sahtesi verilir (platform kanalı yok).
abstract class MediaLibrary {
  /// Sistem izni/erişimi ister.
  Future<LibraryAccess> requestAccess();

  /// Albüm listesi (ilk eleman "Tümü").
  Future<List<GalleryAlbum>> albums();

  /// En yeni önce, sayfa sayfa. [albumId] null ise tümü.
  Future<List<GalleryItem>> items(String? albumId, {required int page, required int size});

  /// Kare küçük resim (JPEG).
  Future<Uint8List?> thumb(GalleryItem item, int size);

  /// Gönderim için fotoğraf baytı (JPEG, uzun kenar en çok 1600 px; HEIC de JPEG'e çevrilir).
  Future<Uint8List?> imageBytes(GalleryItem item);

  /// Videonun dosya yolu.
  Future<String?> videoPath(GalleryItem item);

  /// iOS sınırlı erişimde "daha fazla seç" sayfasını açar.
  Future<void> manageLimited();

  /// Sistem ayarlarını açar.
  Future<void> openSettings();
}

/// `photo_manager` ile (Android MediaStore, iOS PhotoKit; iOS SwiftPM destekli).
class PhotoManagerLibrary implements MediaLibrary {
  final _paths = <String, pm.AssetPathEntity>{};

  pm.AssetEntity? _asset(GalleryItem i) => i.ref is pm.AssetEntity ? i.ref as pm.AssetEntity : null;

  @override
  Future<LibraryAccess> requestAccess() async {
    final st = await pm.PhotoManager.requestPermissionExtend();
    if (st.isAuth) return LibraryAccess.full;
    if (st.hasAccess) return LibraryAccess.limited;
    return LibraryAccess.denied;
  }

  @override
  Future<List<GalleryAlbum>> albums() async {
    final list = await pm.PhotoManager.getAssetPathList(
      type: pm.RequestType.common,
      filterOption: pm.FilterOptionGroup(orders: const [pm.OrderOption()]),
    );
    _paths.clear();
    final out = <GalleryAlbum>[];
    for (final p in list) {
      _paths[p.id] = p;
      out.add(GalleryAlbum(id: p.id, name: p.name, count: await p.assetCountAsync, isAll: p.isAll));
    }
    out.sort((a, b) => a.isAll == b.isAll ? 0 : (a.isAll ? -1 : 1));
    return out;
  }

  @override
  Future<List<GalleryItem>> items(String? albumId, {required int page, required int size}) async {
    if (_paths.isEmpty) await albums();
    final path = albumId != null
        ? _paths[albumId]
        : (_paths.values.where((p) => p.isAll).firstOrNull ?? _paths.values.firstOrNull);
    if (path == null) return const [];
    final assets = await path.getAssetListPaged(page: page, size: size);
    return [
      for (final a in assets)
        GalleryItem(
          id: a.id,
          isVideo: a.type == pm.AssetType.video,
          durationMs: a.type == pm.AssetType.video ? a.duration * 1000 : 0,
          ref: a,
        ),
    ];
  }

  @override
  Future<Uint8List?> thumb(GalleryItem item, int size) async =>
      _asset(item)?.thumbnailDataWithSize(pm.ThumbnailSize.square(size), quality: 80);

  @override
  Future<Uint8List?> imageBytes(GalleryItem item) async =>
      _asset(item)?.thumbnailDataWithSize(const pm.ThumbnailSize(1600, 1600), quality: 85);

  @override
  Future<String?> videoPath(GalleryItem item) async => (await _asset(item)?.originFile)?.path;

  @override
  Future<void> manageLimited() => pm.PhotoManager.presentLimited();

  @override
  Future<void> openSettings() => pm.PhotoManager.openSetting();
}

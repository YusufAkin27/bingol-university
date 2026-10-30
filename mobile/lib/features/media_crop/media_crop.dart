import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart';
import '../../widgets/bu.dart';
import 'crop_page.dart';
import 'crop_spec.dart';

export 'crop_spec.dart';

/// Elinizdeki fotoğraf baytlarını kırpma sayfasında açar. Kullanıcı kaydederse [CropOutcome.cropped] (JPEG),
/// yan eylem seçerse [CropOutcome.removed]/[CropOutcome.change]; vazgeçerse null döner.
Future<CropOutcome?> cropImage(BuildContext context, Uint8List bytes, CropSpec spec) =>
    Navigator.of(context).push<CropOutcome>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => CropPage(bytes: bytes, spec: spec)),
    );

/// Galeriden ya da kameradan tek fotoğraf baytı döndürür (iptalde null); testlerde sahtesi verilir.
typedef CropPhotoPicker = Future<Uint8List?> Function(ImageSource source);

Future<Uint8List?> _defaultPick(ImageSource source) async {
  final f = await ImageService().pick(source);
  return f?.readAsBytes();
}

/// Seç + kırp tek çağrıda: fotoğrafı [source]'tan seçtirir, [spec] biçiminde kırpma sayfasını açar ve kırpılmış
/// JPEG baytlarını döndürür (seçim ya da kırpma iptal edilirse null). "Fotoğrafı değiştir" seçilirse seçici yeniden
/// açılır. Yan eylemler ("Kapağı kaldır") için [cropImage] kullanın.
Future<Uint8List?> pickAndCrop(
  BuildContext context,
  CropSpec spec, {
  ImageSource source = ImageSource.gallery,
  CropPhotoPicker? pick,
}) async {
  final picker = pick ?? _defaultPick;
  var src = source;
  while (true) {
    final bytes = await picker(src);
    if (bytes == null || !context.mounted) return null;
    final out = await cropImage(context, bytes, spec);
    if (out == null || !context.mounted) return null;
    if (out.changeRequested) {
      src = ImageSource.gallery;
      continue;
    }
    return out.bytes;
  }
}

/// [showPhotoSourceSheet] sonucu.
enum PhotoSource { gallery, camera, remove }

/// "Fotoğraf" kaynak alt sayfası: Galeriden seç / Fotoğraf çek / (isteğe bağlı) Fotoğrafı kaldır. [error] verilirse
/// altta kırmızı bir uyarı kartı gösterilir (örn. boyut hatası). İptalde null.
Future<PhotoSource?> showPhotoSourceSheet(BuildContext context, {bool removable = false, String? error}) {
  final l = context.l10n;
  return BuSheet.show<PhotoSource>(
    context,
    title: l.p04SrcTitle,
    builder: (ctx) {
      final t = ctx.bu;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        BuListTile(
          key: const ValueKey('photoSrcGallery'),
          title: l.p04SrcGallery,
          leading: const Icon(LucideIcons.images),
          showChevron: true,
          onTap: () => Navigator.pop(ctx, PhotoSource.gallery),
        ),
        BuListTile(
          key: const ValueKey('photoSrcCamera'),
          title: l.p04SrcCamera,
          leading: const Icon(LucideIcons.camera),
          showChevron: true,
          onTap: () => Navigator.pop(ctx, PhotoSource.camera),
        ),
        if (removable)
          BuListTile(
            key: const ValueKey('photoSrcRemove'),
            title: l.p04SrcRemove,
            leading: Icon(LucideIcons.trash2, color: t.danger),
            danger: true,
            onTap: () => Navigator.pop(ctx, PhotoSource.remove),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DecoratedBox(
              key: const ValueKey('photoSrcError'),
              decoration: BoxDecoration(color: t.danger.withValues(alpha: .12), borderRadius: BorderRadius.circular(BuRadius.md)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(LucideIcons.circleAlert, size: 20, color: t.danger),
                  const SizedBox(width: 10),
                  Expanded(child: Text(error, style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: t.danger))),
                ]),
              ),
            ),
          ),
      ]);
    },
  );
}

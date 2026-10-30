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

/// "Fotoğraf" kaynak alt sayfası (referans 09/6): Galeriden seç / Fotoğraf çek / (isteğe bağlı) Fotoğrafı kaldır, sağ üstte
/// kapat düğmesi. [error] verilirse altta kırmızı uyarı kartı (başlık [errorTitle], örn. "Dosya boyutu yüksek" + 2 MB metni).
/// İptalde null.
Future<PhotoSource?> showPhotoSourceSheet(BuildContext context, {bool removable = false, String? error, String? errorTitle}) {
  final l = context.l10n;
  return BuSheet.show<PhotoSource>(
    context,
    builder: (ctx) {
      final t = ctx.bu;
      final tt = Theme.of(ctx).textTheme;
      Widget row(Key key, IconData icon, String label, PhotoSource v, {bool danger = false, bool chevron = true}) => InkWell(
            key: key,
            borderRadius: BorderRadius.circular(BuRadius.md),
            onTap: () => Navigator.pop(ctx, v),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: danger ? t.danger.withValues(alpha: .12) : t.sf2, borderRadius: BorderRadius.circular(BuRadius.sm)),
                  child: Icon(icon, size: 22, color: danger ? t.danger : t.ink),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Text(label, style: tt.titleSmall?.copyWith(color: danger ? t.danger : t.ink, fontWeight: FontWeight.w700))),
                Icon(danger ? LucideIcons.x : LucideIcons.chevronRight, size: 18, color: danger ? t.danger : t.mut),
              ]),
            ),
          );
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(l.p04SrcTitle, style: tt.titleLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w700))),
          Tooltip(
            message: l.postComposeClose,
            child: Material(
              color: t.sf2,
              shape: const CircleBorder(),
              child: InkWell(
                key: const ValueKey('photoSrcClose'),
                customBorder: const CircleBorder(),
                onTap: () => Navigator.pop(ctx),
                child: SizedBox.square(dimension: 44, child: Icon(LucideIcons.x, size: 20, color: t.ink)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        row(const ValueKey('photoSrcGallery'), LucideIcons.images, l.p04SrcGallery, PhotoSource.gallery),
        Divider(height: 1, color: t.bd),
        row(const ValueKey('photoSrcCamera'), LucideIcons.camera, l.p04SrcCamera, PhotoSource.camera),
        if (removable) ...[
          Divider(height: 1, color: t.bd),
          row(const ValueKey('photoSrcRemove'), LucideIcons.trash2, l.p04SrcRemove, PhotoSource.remove, danger: true),
        ],
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DecoratedBox(
              key: const ValueKey('photoSrcError'),
              decoration: BoxDecoration(color: t.danger.withValues(alpha: .12), borderRadius: BorderRadius.circular(BuRadius.md)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(LucideIcons.circleAlert, size: 20, color: t.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (errorTitle != null) Text(errorTitle, style: tt.titleSmall?.copyWith(color: t.danger, fontWeight: FontWeight.w700)),
                      Text(error, style: tt.bodySmall?.copyWith(color: t.danger)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
      ]);
    },
  );
}

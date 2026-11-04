import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart';
import '../../widgets/bu.dart';
import 'avatar_editor_page.dart';
import 'crop_page.dart';
import 'crop_spec.dart';

export 'crop_spec.dart';

/// Profil fotoğrafı düzenleyicisini ([AvatarEditorPage]) tam ekran açar; "Bitti" -> [CropOutcome.cropped], iptal -> null.
Future<CropOutcome?> openAvatarEditor(BuildContext context, Uint8List bytes) => Navigator.of(context)
    .push<CropOutcome>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => AvatarEditorPage(bytes: bytes)));

/// Fotoğraf düzenleyicisini ([AvatarEditorPage]) [spec] biçiminde açar: aynı gelişmiş araçlar (yakınlaştır/uzaklaştır + zemin,
/// açı, döndür, aynala, filtre, ayarlar, geri al/yinele) her kullanım yerinde; çerçeve oranı ve en-boy seçenekleri [spec]'ten
/// gelir (gönderi: 4:5 + 1:1/3:4/16:9/serbest, kapak: 16:9, sohbet: serbest + diğerleri; logo/profil: daire maske).
/// Sonuç [cropImage] ile aynıdır: [CropOutcome.cropped] (JPEG), yan eylem ya da vazgeçilirse null.
///
/// Profil fotoğrafı ([CropKind.profile]) değişmeden 1024x1024 kare çıktı veren profil düzenleyicisini açar.
Future<CropOutcome?> editPhoto(BuildContext context, Uint8List bytes, CropSpec spec) {
  if (spec.kind == CropKind.profile) return openAvatarEditor(context, bytes);
  return Navigator.of(context).push<CropOutcome>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => AvatarEditorPage(bytes: bytes, spec: spec)));
}

/// ESKİ kırpma sayfasını ([CropPage]) açar; geriye dönük uyum içindir (testler, eski çağıranlar). Yeni kod [editPhoto]
/// kullanmalıdır: uygulamadaki tüm fotoğraf akışları (gönderi, kulüp logosu/kapağı, etkinlik kapağı, sohbet) artık onu açar.
///
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
    // Tüm türler tek gelişmiş düzenleyiciyi kullanır (uzaklaştırma + zemin, açı, filtre...); oran/maske [spec]'ten.
    final out = await editPhoto(context, bytes, spec);
    if (out == null || !context.mounted) return null;
    if (out.changeRequested) {
      src = ImageSource.gallery;
      continue;
    }
    return out.bytes;
  }
}

/// [showPhotoSourceSheet] sonucu.
enum PhotoSource { gallery, camera, remove, edit }

/// "Fotoğraf" kaynak alt sayfası (referans 09/6): Galeriden seç / Fotoğraf çek / (isteğe bağlı) Fotoğrafı kaldır, sağ üstte
/// kapat düğmesi. [error] verilirse altta kırmızı uyarı kartı (başlık [errorTitle], örn. "Dosya boyutu yüksek" + 2 MB metni).
/// İptalde null.
///
/// Profil fotoğrafı sayfası için: [title] başlığı değiştirir, [cameraFirst] kamerayı üste alır, [editable] "Mevcut fotoğrafı
/// düzenle" satırını ([PhotoSource.edit]) ekler.
Future<PhotoSource?> showPhotoSourceSheet(BuildContext context,
    {bool removable = false, String? error, String? errorTitle, bool simple = false, String? title, bool cameraFirst = false, bool editable = false}) {
  final l = context.l10n;
  if (simple) return _showSimpleSourceSheet(context);
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
                    child: Text(label, style: tt.titleSmall?.copyWith(fontSize: 16, color: danger ? t.danger : t.ink, fontWeight: FontWeight.w600))),
                Icon(danger ? BuIcons.x : BuIcons.chevronRight, size: 20, color: danger ? t.danger : t.mut),
              ]),
            ),
          );
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(title ?? l.p04SrcTitle, style: tt.titleLarge?.copyWith(fontSize: 22, color: t.ink, fontWeight: FontWeight.w700))),
          Tooltip(
            message: l.postComposeClose,
            child: Material(
              color: t.sf2,
              shape: const CircleBorder(),
              child: InkWell(
                key: const ValueKey('photoSrcClose'),
                customBorder: const CircleBorder(),
                onTap: () => Navigator.pop(ctx),
                child: SizedBox.square(dimension: 44, child: Icon(BuIcons.x, size: 20, color: t.ink)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        if (cameraFirst) ...[
          row(const ValueKey('photoSrcCamera'), BuIcons.camera, l.p04SrcCamera, PhotoSource.camera),
          Divider(height: 1, color: t.bd),
          row(const ValueKey('photoSrcGallery'), BuIcons.images, l.p04SrcGallery, PhotoSource.gallery),
        ] else ...[
          row(const ValueKey('photoSrcGallery'), BuIcons.images, l.p04SrcGallery, PhotoSource.gallery),
          Divider(height: 1, color: t.bd),
          row(const ValueKey('photoSrcCamera'), BuIcons.camera, l.p04SrcCamera, PhotoSource.camera),
        ],
        if (editable) ...[
          Divider(height: 1, color: t.bd),
          row(const ValueKey('photoSrcEdit'), BuIcons.pencil, l.avatarSheetEdit, PhotoSource.edit),
        ],
        if (removable) ...[
          Divider(height: 1, color: t.bd),
          row(const ValueKey('photoSrcRemove'), BuIcons.trash2, l.p04SrcRemove, PhotoSource.remove, danger: true),
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
                  Icon(BuIcons.circleAlert, size: 20, color: t.danger),
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

/// Sade kaynak sayfası (Stitch v3 02): tutamaç + iki satır (56 dp, 24 dp ince çizgi simge, 1 dp ayırıcı); başlık/açıklama/kapat yok.
Future<PhotoSource?> _showSimpleSourceSheet(BuildContext context) {
  final l = context.l10n;
  return BuSheet.show<PhotoSource>(
    context,
    scrollable: false,
    padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
    builder: (ctx) {
      final t = ctx.bu;
      final tt = Theme.of(ctx).textTheme;
      Widget row(Key key, IconData icon, String label, PhotoSource v) => InkWell(
            key: key,
            onTap: () => Navigator.pop(ctx, v),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: BuSize.row),
              child: Row(children: [
                Icon(icon, size: 24, color: t.ink),
                const SizedBox(width: 16),
                Expanded(child: Text(label, style: tt.bodyLarge?.copyWith(color: t.ink, fontSize: 16, fontWeight: FontWeight.w500))),
              ]),
            ),
          );
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        row(const ValueKey('photoSrcGallery'), BuIcons.images, l.p04SrcGallery, PhotoSource.gallery),
        Divider(height: 1, color: t.bd),
        row(const ValueKey('photoSrcCamera'), BuIcons.camera, l.p04SrcCamera, PhotoSource.camera),
      ]);
    },
  );
}

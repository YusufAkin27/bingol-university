import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../media_crop/media_crop.dart';

/// Başarılı avatar yüklemesi: sunucunun döndürdüğü [url] (yanıtta yoksa null) ve yüklenen (düzenlenmiş, sıkıştırılmış)
/// [bytes] (anında önizleme için).
class AvatarUploadResult {
  const AvatarUploadResult(this.url, this.bytes);

  final String? url;
  final Uint8List bytes;
}

/// Test kancaları (üretimde hepsi null): seç/kırp, mevcut fotoğrafı düzenle, indirme, yükleyici, görsel servisi.
class AvatarHooks {
  const AvatarHooks({this.cropPhoto, this.editPhoto, this.fetchBytes, this.uploader, this.images});

  /// Kaynaktan seç + düzenle (kırpılmış bayt; null = vazgeçildi).
  final CropPhotoPicker? cropPhoto;

  /// Mevcut fotoğrafın baytlarını düzenleyiciden geçirir (null = vazgeçildi).
  final Future<Uint8List?> Function(Uint8List bytes)? editPhoto;

  /// Mevcut avatarın baytlarını indirir.
  final Future<Uint8List> Function(String url)? fetchBytes;
  final MultipartUploader? uploader;
  final ImageService? images;
}

/// Profil fotoğrafı hattı (profil düzenleme, kayıt sonrası fotoğraf adımı ve Profil sekmesi ortak kullanır):
/// seç -> profil fotoğrafı düzenleyicisi (kırp/filtre) -> doğrula/sıkıştır -> `POST /users/me/avatar`.
///
/// Kullanıcı seçimden ya da düzenlemeden vazgeçerse null döner; hata olursa istisna fırlatır ([ImageException],
/// [ApiError]); metne çevirmek için [avatarUploadErrorText].
Future<AvatarUploadResult?> uploadAvatarFrom(
  BuildContext context,
  Session session,
  ImageSource source, {
  String previewName = '',
  CropPhotoPicker? cropPhoto,
  ImageService? images,
  MultipartUploader? uploader,
}) async {
  final bytes = cropPhoto != null
      ? await cropPhoto(source)
      : await pickAndCrop(context, CropSpec.profile(previewName: previewName), source: source);
  if (bytes == null) return null; // kullanıcı vazgeçti
  return _prepareAndUpload(session, bytes, images, uploader);
}

/// Mevcut avatarı indirir, düzenleyicide açar ve düzenlenmiş hâlini yükler (null = vazgeçildi).
Future<AvatarUploadResult?> editExistingAvatar(
  BuildContext context,
  Session session,
  String url, {
  AvatarHooks hooks = const AvatarHooks(),
}) async {
  final full = fileUrl(url);
  if (full == null) return null;
  // /api/ altındaki (korumalı) avatar adresleri Authorization ister; /files/** herkese açıktır.
  final token = url.startsWith('/api/') ? session.api.tokens?.access : null;
  final src = await (hooks.fetchBytes ?? (u) => _fetch(u, token))(full);
  if (!context.mounted) return null;
  final edited = hooks.editPhoto != null ? await hooks.editPhoto!(src) : (await openAvatarEditor(context, src))?.bytes;
  if (edited == null) return null;
  return _prepareAndUpload(session, edited, hooks.images, hooks.uploader);
}

/// `DELETE /users/me/avatar` (varsayılan görsele döner) ve profil önbelleğini bayatlatır.
Future<void> removeAvatar(Session session) async {
  await session.api.delete('/users/me/avatar');
  session.api.invalidate('/users/me');
}

Future<AvatarUploadResult> _prepareAndUpload(Session session, Uint8List bytes, ImageService? images, MultipartUploader? uploader) async {
  final prepared = await (images ?? ImageService()).prepare(bytes, avatar: true);
  final r = await (uploader ?? MultipartUploader(session)).upload('/users/me/avatar', prepared);
  session.api.invalidate('/users/me'); // çok parçalı yükleme api katmanından geçmez: profil yanıtı bayat sayılır
  final url = r is Map && r['avatarUrl'] is String ? r['avatarUrl'] as String : null;
  return AvatarUploadResult(url, prepared.bytes);
}

Future<Uint8List> _fetch(String url, [String? token]) async {
  try {
    final res = await http
        .get(Uri.parse(url), headers: token == null ? null : {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) throw ApiError(res.statusCode, 'HTTP_${res.statusCode}', '');
    return res.bodyBytes;
  } on ApiError {
    rethrow;
  } catch (_) {
    throw ApiError(0, 'NETWORK', '');
  }
}

/// [uploadAvatarFrom] hatasını kullanıcıya gösterilecek metne çevirir (boyut/tür/okunamadı/413/ağ).
String avatarUploadErrorText(BuildContext context, Object e) {
  final l = context.l10n;
  if (e is ImageException) {
    switch (e.code) {
      case 'TOO_LARGE':
        return l.profilePhotoTooLargeHint;
      case 'UNSUPPORTED_TYPE':
        return l.profilePhotoUnsupported;
      default:
        return l.profilePhotoUnreadable;
    }
  }
  if (e is ApiError && e.status == 413) return l.profilePhotoTooLarge;
  return errorText(e);
}

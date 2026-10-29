// Sohbet ekleri için ortak yardımcılar (galeri süzmesi, tek gösterimlik ek tanıma, video).

import 'dart:ui' show Locale;

import '../../core/api.dart' show apiOrigin;
import '../../l10n/app_localizations.dart';

/// Sohbet medyası adresi: tam adres olduğu gibi, sunucu yolu API kökü ile birleştirilir.
String chatMediaUrl(String path) => path.startsWith('http') ? path : '$apiOrigin$path';

/// Ek tek gösterimlik mi.
bool isViewOnceAttachment(Map a) => a['viewOnce'] == true;

/// Ek video mu (`kind: "VIDEO"`).
bool isVideoAttachment(Map a) => '${a['kind'] ?? ''}'.toUpperCase() == 'VIDEO';

/// Milisaniyeyi "0:42" / "1:05:09" biçimine çevirir.
String formatMediaDuration(int ms) {
  final s = (ms / 1000).round();
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '$m:${two(sec)}';
}

/// Mesajın galeriye/medya ızgarasına girebilecek ekleri: silinmiş/kaldırılmış mesaj ve ekler,
/// URL'si olmayanlar ve TEK GÖSTERİMLİK ekler hariç (onlar asla listelenmez). Videolar listelenir
/// (`isVideoAttachment` ile ayırt edilir). Bilgi sayfası ve görüntüleyici bu süzmeyi kullanmalı.
List<Map<String, dynamic>> galleryAttachments(Map message) {
  if (message['deleted'] == true || message['removed'] == true) return const [];
  return (message['attachments'] as List? ?? const [])
      .whereType<Map>()
      .where((a) =>
          !isViewOnceAttachment(a) &&
          a['removed'] != true &&
          (a['url'] ?? a['thumbUrl']) != null)
      .map((a) => Map<String, dynamic>.from(a))
      .toList();
}

/// Mesajın ilk tek gösterimlik eki (yoksa null).
Map<String, dynamic>? viewOnceAttachment(Map message) {
  for (final a
      in (message['attachments'] as List? ?? const []).whereType<Map>()) {
    if (isViewOnceAttachment(a)) return Map<String, dynamic>.from(a);
  }
  return null;
}

/// Sohbet listesi önizleme metni (ek varsa): tek gösterimlik -> "Fotoğraf (tek gösterimlik)",
/// video -> "Video", diğer -> "Fotoğraf". Ek yoksa boş metin.
/// [l10n] verilmezse Türkçe kullanılır (eski çağıranlar için).
String attachmentPreviewLabel(Map message, [AppLocalizations? l10n]) {
  final atts = (message['attachments'] as List? ?? const []).whereType<Map>().toList();
  if (atts.isEmpty) return '';
  final l = l10n ?? lookupAppLocalizations(const Locale('tr'));
  if (atts.any(isViewOnceAttachment)) return l.chatMiscOnceText;
  if (atts.any(isVideoAttachment)) return l.chatMiscVideo;
  return l.chatMiscPhoto;
}

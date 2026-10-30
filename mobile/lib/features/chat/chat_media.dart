// Sohbet ekleri için ortak yardımcılar (galeri süzmesi, tek gösterimlik ek tanıma, video).

import 'dart:math' as math;
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

/// Sohbet balonundaki görsel/video kenarı (dp). SABİT KARE: ~224 dp; dar ekranda mesaj alanının (~%78) en çok
/// %90'ı ([maxW] = ekran genişliğinin %78'i). dp olduğu için yazı ölçeğinden etkilenmez.
double chatMediaSide(double maxW) => math.min(224.0, maxW * .9);

/// Balonda çizilecek görsel kaynağı: yol + çözülecek genişlik (px).
class ChatImageSource {
  const ChatImageSource(this.path, this.decodeWidth, {required this.full});

  /// `thumbUrl` ya da `url` (sunucu yolu).
  final String path;

  /// `Image.network(cacheWidth:)`: kutu x DPR'ye (en çok 1600) denk.
  final int decodeWidth;

  /// Ana görsel (<=1600 px) mi seçildi (küçük resim yetmedi).
  final bool full;
}

/// Eski (thumbEdge'siz) kayıtlarda küçük resmin uzun kenarı.
const legacyChatThumbEdge = 320;

/// Balon kutusu ([boxW] x [boxH] dp, BoxFit.cover) için yeterli çözünürlükte kaynağı seçer:
/// küçük resim kutu x DPR'nin en az %85'ini karşılıyorsa o (az veri), yoksa ana görsel (bulanıklık yok).
/// Alanlar: `thumbEdge` (küçük resmin gerçek uzun kenarı; yoksa eski kayıt = 320), `width`/`height`.
/// Videoda yalnız `thumbUrl` (poster). Hiç adres yoksa null.
ChatImageSource? pickChatImageSource(Map a, {required double boxW, required double boxH, required double dpr}) {
  final thumb = a['thumbUrl'] as String?;
  final url = a['url'] as String?;
  final video = isVideoAttachment(a);
  final w = (a['width'] as num?)?.toDouble() ?? 0;
  final h = (a['height'] as num?)?.toDouble() ?? 0;
  final known = w > 0 && h > 0;
  // cover: kutuyu dolduran ölçek (kaynak px başına ekran px); 1'den büyüğüne gerek yok
  final need = known ? math.min(1.0, math.max(boxW * dpr / w, boxH * dpr / h)) : 1.0;
  final decode = (known ? w * need : boxW * dpr).round().clamp(160, 1600);
  if (video) return thumb == null ? null : ChatImageSource(thumb, decode, full: false);
  if (url == null) return thumb == null ? null : ChatImageSource(thumb, decode, full: false);
  if (thumb == null) return ChatImageSource(url, decode, full: true);
  var edge = (a['thumbEdge'] as num?)?.toDouble() ?? legacyChatThumbEdge.toDouble();
  final long = math.max(w, h);
  if (known) edge = math.min(edge, long); // küçük kaynak: küçük resim kaynakla aynı
  final enough = known ? edge / long >= need * .85 : edge >= boxW * dpr * .85;
  return enough ? ChatImageSource(thumb, decode, full: false) : ChatImageSource(url, decode, full: true);
}

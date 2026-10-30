import 'dart:typed_data';

/// Sohbete gönderilmek üzere seçilmiş tek öğe (galeriden ya da kameradan).
/// Baytlar/yol tembel okunur: seçim anında dosya işlenmez.
class MediaPick {
  MediaPick({
    required this.key,
    required this.isVideo,
    this.durationMs = 0,
    required this.thumb,
    this.imageBytes,
    this.videoPath,
  });

  /// Benzersiz kimlik (galeride varlık kimliği; kamerada üretilir).
  final String key;
  final bool isVideo;
  final int durationMs;

  /// Küçük resim (JPEG). Video için poster karesi.
  final Future<Uint8List?> Function(int size) thumb;

  /// Fotoğraf baytı (JPEG/PNG/WebP, uzun kenar ~1600 px). Yalnız fotoğraf.
  final Future<Uint8List?> Function()? imageBytes;

  /// Video dosya yolu. Yalnız video.
  final Future<String?> Function()? videoPath;
}

/// Önizlemede işaretlenmiş öğe: [once] true ise yalnız fotoğraf için "tek gönderimlik".
class MediaSendItem {
  MediaSendItem(this.pick, {this.once = false});
  final MediaPick pick;
  final bool once;
}

/// Önizlemeden dönen gönderim isteği: sıralı öğeler + açıklama metni.
class MediaSendPlan {
  const MediaSendPlan(this.items, this.caption);
  final List<MediaSendItem> items;
  final String caption;
}

/// Planın tek bir sohbet mesajına karşılık gelen parçası.
class PlannedMessage {
  PlannedMessage(this.picks, {this.once = false, this.caption = ''});
  final List<MediaPick> picks;
  final bool once;
  String caption;
}

const maxAttachmentsPerMessage = 10;

/// Mesaja en çok seçilebilecek öğe sayısı (foto ve video karışık; sunucu kuralı).
const kMaxPicks = 10;

/// Videonun en uzun süresi (ms); sunucu kuralıyla aynı.
const kMaxVideoMs = 60 * 1000;

/// Mesaj başına video bayt toplamı sınırı (sunucu kuralı: 120 MB).
const maxVideoBytesPerMessage = 120 * 1024 * 1024;

/// Planı mesajlara böler (sunucu kuralları: mesajda en çok 10 ek, foto+video karışık olabilir,
/// tek gönderimlikte 1 ek):
///  - tek gönderimlik işaretli her fotoğraf ayrı mesaj (`once`);
///  - işaretsiz öğeler (video dahil) 10'arlı gruplanır (grup ilk öğesinin yerinde durur);
///  - açıklama ilk işaretsiz mesaja, yoksa ilk mesaja eklenir; sıra korunur.
/// Video bayt toplamı hazırlıktan sonra bilinir: bkz. [splitByVideoBytes].
List<PlannedMessage> planMessages(MediaSendPlan plan) {
  final out = <PlannedMessage>[];
  PlannedMessage? open;
  for (final it in plan.items) {
    final p = it.pick;
    if (!p.isVideo && it.once) {
      out.add(PlannedMessage([p], once: true));
    } else {
      if (open == null || open.picks.length >= maxAttachmentsPerMessage) {
        open = PlannedMessage([]);
        out.add(open);
      }
      open.picks.add(p);
    }
  }
  final caption = plan.caption.trim();
  if (caption.isNotEmpty && out.isNotEmpty) {
    final target = out.where((m) => !m.once).firstOrNull ?? out.first;
    target.caption = caption;
  }
  return out;
}

/// Hazırlanmış öğeleri sırayı bozmadan, her parçada video bayt toplamı [max]'ı aşmayacak şekilde böler.
/// [videoBytes] fotoğraf için 0 döner.
List<List<T>> splitByVideoBytes<T>(List<T> items, int Function(T) videoBytes,
    {int max = maxVideoBytesPerMessage}) {
  final out = <List<T>>[];
  var cur = <T>[];
  var sum = 0;
  for (final it in items) {
    final b = videoBytes(it);
    if (cur.isNotEmpty && sum + b > max) {
      out.add(cur);
      cur = <T>[];
      sum = 0;
    }
    cur.add(it);
    sum += b;
  }
  if (cur.isNotEmpty) out.add(cur);
  return out;
}

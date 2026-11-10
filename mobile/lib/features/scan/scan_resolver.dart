/// Tek QR tarayıcının çözümleme tablosu: saf Dart (UI'siz test edilir).
///
/// Taranan metin ASLA açılmaz/çalıştırılmaz: yalnız kendi alan adımız (`bukampus.com.tr`) ve `bukampus://` şeması
/// [parseShareLink] ile, etkinlik yoklama yükü ise katı biçimle (`bingol-checkin:{id}.{pencere}.{imza}`) tanınır.
/// Geri kalan her şey (yabancı alan adı, başka şema, uzun/kontrol karakterli/boşluklu metin) [ScanKind.invalid].
library;

import '../share/share_models.dart';

enum ScanKind {
  /// Başka kullanıcının profil kodu.
  profile,

  /// Kendi profil kodu.
  ownProfile,

  /// Kulüp / anket / etkinlik / haber / gönderi / forum bağlantısı: `ShareTarget` ile açılır.
  content,

  /// Etkinlik yoklama yükü: görevliyse yoklama alınır (yetki ve hız sınırı sunucudadır).
  checkin,

  /// BÜ Kampüs kodu değil.
  invalid,
}

class ScanResult {
  const ScanResult(this.kind, {this.target, this.eventId, this.code});

  final ScanKind kind;
  final ShareTarget? target;
  final int? eventId;

  /// Sunucuya gönderilecek yoklama kodu (önek dahil/değil: ham yük).
  final String? code;

  bool get valid => kind != ScanKind.invalid;
}

const int kScanMaxLength = 300;

final RegExp _checkin = RegExp(r'^bingol-checkin:([0-9]{1,18})\.([A-Za-z0-9_\-.]{1,250})$');
final RegExp _bad = RegExp(r'[\s\u0000-\u001f\u007f]');

ScanResult resolveScan(String? raw, {int? selfId}) {
  const invalid = ScanResult(ScanKind.invalid);
  final text = (raw ?? '').trim();
  if (text.isEmpty || text.length > kScanMaxLength || _bad.hasMatch(text)) return invalid;
  final m = _checkin.firstMatch(text);
  if (m != null) {
    final id = int.tryParse(m.group(1)!);
    if (id == null || id <= 0) return invalid;
    return ScanResult(ScanKind.checkin, eventId: id, code: text);
  }
  final t = parseShareLink(text);
  if (t == null) return invalid;
  if (t.type == ShareType.user) {
    return ScanResult(selfId != null && selfId == t.id ? ScanKind.ownProfile : ScanKind.profile, target: t);
  }
  return ScanResult(ScanKind.content, target: t);
}

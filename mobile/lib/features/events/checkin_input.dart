/// Yoklama kodu girdisi: iki biçim vardır (backend `CheckinCodeService`).
///  * QR yükü / uzun jeton: `bingol-checkin:{etkinlikId}.{pencere}.{imza}`; etkinlik kimliği kodun içindedir.
///  * Kısa elle giriş kodu (`manualCode`, 6 karakter, ör. `K7M4QX`): etkinlik kimliği taşımaz; hangi etkinlik
///    olduğu bağlamdan (etkinlik sayfası) bilinmelidir.
class CheckinInput {
  const CheckinInput._(this.code, this.eventId);

  /// Sunucuya gönderilecek kod (önek ve boşluklar temizlenmiş; kısa kod büyük harf).
  final String code;

  /// Uzun jetonda kodun taşıdığı etkinlik kimliği; kısa kodda null.
  final int? eventId;

  bool get isShort => eventId == null;

  static const _prefix = 'bingol-checkin:';

  /// Yazım farkları (küçük harf, boşluk, tire) tolere edilir. Tanınmayan girdide null.
  static CheckinInput? parse(String raw) {
    var s = raw.trim();
    if (s.startsWith(_prefix)) s = s.substring(_prefix.length).trim();
    if (s.isEmpty) return null;
    if (s.contains('.')) {
      final id = int.tryParse(s.split('.').first);
      return id == null ? null : CheckinInput._(s, id);
    }
    final n = s.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    if (RegExp(r'^[A-Z0-9]{6}$').hasMatch(n)) return CheckinInput._(n, null);
    return null;
  }
}

/// "K7M4QX" -> "K7M 4QX" (6 karakterli elle kod okunaklı gösterilir; başka uzunlukta olduğu gibi).
String spacedManualCode(String c) => c.length == 6 ? '${c.substring(0, 3)} ${c.substring(3)}' : c;

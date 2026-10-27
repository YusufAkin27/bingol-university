/// Kimlik alanı: okul numarası (6-12 rakam) ya da tam e-posta.
const kEmailDomain = 'bingol.edu.tr';

final _digitsRe = RegExp(r'^\d+$');
final _emailRe = RegExp(r'^[a-z0-9._%+\-]+@([a-z0-9\-]+\.)*bingol\.edu\.tr$');

/// Boşluk ve tireleri temizler, küçük harfe çevirir. '@' içermeyen girdide nokta da atılır
/// (numara yapıştırılırken `226.051.015` gibi gelebilir) yalnız rakam kalıyorsa.
String normalizeIdentifier(String? raw) {
  var s = (raw ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s'), '');
  if (!s.contains('@')) {
    final cleaned = s.replaceAll('-', '').replaceAll('.', '');
    if (_digitsRe.hasMatch(cleaned)) return cleaned;
  }
  return s;
}

/// Yalnız rakamlardan oluşuyorsa (okul numarası yazılıyor).
bool isStudentNumberInput(String? raw) {
  final s = normalizeIdentifier(raw);
  return s.isNotEmpty && _digitsRe.hasMatch(s);
}

/// Numarayı `<numara>@bingol.edu.tr`'ye çevirir; e-posta olduğu gibi kalır.
String fullEmail(String identifier) {
  final s = normalizeIdentifier(identifier);
  return _digitsRe.hasMatch(s) ? '$s@$kEmailDomain' : s;
}

String? validateIdentifier(String? v) {
  final s = normalizeIdentifier(v);
  if (s.isEmpty) return 'Okul numaranızı veya e-posta adresinizi girin.';
  if (s.contains('@')) {
    return _emailRe.hasMatch(s) ? null : 'Yalnızca bingol.edu.tr uzantılı adres kullanılabilir.';
  }
  if (_digitsRe.hasMatch(s) && s.length >= 6 && s.length <= 12) return null;
  return 'Okul numarasını kontrol edin.';
}

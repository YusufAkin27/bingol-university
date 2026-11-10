/// Profil QR kodu / bağlantısı: saf Dart (UI'siz test edilir).
///
/// QR içeriği = herkese açık profil bağlantısı (`https://bukampus.com.tr/s/u/{kimlik}`): telefonun kendi kamerası da
/// açar. Taranan metin ASLA çalıştırılmaz/açılmaz: yalnız [parseShareLink]'in kabul ettiği kendi alan adımız ve
/// `bukampus://` şeması çözülür, geri kalanı "profil kodu değil" sayılır (açık yönlendirme/phishing yok).
library;

import '../share/share_models.dart';

/// Bir kullanıcının herkese açık profil bağlantısı.
String profileLinkFor(int userId) => ShareTarget(ShareType.user, userId).url;

/// Taranan değerin sonucu.
enum ProfileQrKind {
  /// Başka bir kullanıcının profil kodu.
  other,

  /// Kullanıcının kendi kodu.
  own,

  /// Profil kodu değil (başka içerik türü, yabancı alan adı, bozuk metin).
  invalid,
}

class ProfileQrResult {
  const ProfileQrResult(this.kind, [this.userId]);

  final ProfileQrKind kind;
  final int? userId;

  bool get valid => kind != ProfileQrKind.invalid;
}

/// Tarama üst sınırı: tanıdığımız bağlantılar çok kısadır; uzun metin doğrudan reddedilir.
const int kProfileQrMaxLength = 300;

/// [raw] bir profil kodu mu; [selfId] verilirse kendi kodunu `own` olarak ayırır. Exception fırlatmaz.
ProfileQrResult resolveProfileQr(String? raw, {int? selfId}) {
  final text = (raw ?? '').trim();
  if (text.isEmpty || text.length > kProfileQrMaxLength) return const ProfileQrResult(ProfileQrKind.invalid);
  final target = parseShareLink(text);
  if (target == null || target.type != ShareType.user) return const ProfileQrResult(ProfileQrKind.invalid);
  return ProfileQrResult(selfId != null && selfId == target.id ? ProfileQrKind.own : ProfileQrKind.other, target.id);
}

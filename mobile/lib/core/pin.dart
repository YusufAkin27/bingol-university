/// Kullanıcı şifresi (PIN) kuralı. Sunucudaki `PasswordPolicy` ile BİREBİR aynıdır:
/// tam 6 rakam; tüm rakamlar aynı (000000), düz artan/azalan dizi (123456, 654321) ve iki rakamlı
/// tekrar (121212) reddedilir.
const int kPinLength = 6;

final _digitsOnly = RegExp(r'^[0-9]+$');

/// Yalnız rakamlardan ve tam [kPinLength] uzunluğunda mı (zayıflık denetlenmez).
bool isPinFormat(String s) => s.length == kPinLength && _digitsOnly.hasMatch(s);

/// Kolay tahmin edilen PIN mi (yalnız 6 rakamlı girdiler için anlamlıdır).
bool isWeakPin(String s) {
  if (!isPinFormat(s)) return false;
  final d = [for (var i = 0; i < s.length; i++) s.codeUnitAt(i) - 0x30];
  var allSame = true;
  var asc = true;
  var desc = true;
  var pair = true;
  for (var i = 1; i < d.length; i++) {
    if (d[i] != d[0]) allSame = false;
    if (d[i] != d[i - 1] + 1) asc = false;
    if (d[i] != d[i - 1] - 1) desc = false;
    if (i >= 2 && d[i] != d[i - 2]) pair = false;
  }
  // `pair` aynı zamanda tüm-aynı durumunu kapsar (aaaaaa = ababab, a == b).
  return allSame || asc || desc || pair;
}

/// Giriş doğrulaması sonucu (yeni şifre için).
enum PinCheck { ok, format, weak }

PinCheck checkNewPin(String s) {
  if (!isPinFormat(s)) return PinCheck.format;
  if (isWeakPin(s)) return PinCheck.weak;
  return PinCheck.ok;
}

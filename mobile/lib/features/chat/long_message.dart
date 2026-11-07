import 'package:flutter/widgets.dart' show Characters, StringCharacters;

/// Sohbet mesajı üst sınırı (Unicode kod noktası; sunucu `MessageService.MAX_LENGTH` ile aynı).
const int kChatMaxLen = 10000;

/// Sayaç bu değerden itibaren görünür (üst sınırın %75'i).
const int kChatCounterFrom = 7500;

/// Uzun mesaj balonu: ilk görünen karakter sayısı ve her "Devamını gör" basışında eklenen miktar.
const int kLongMsgBase = 400;
const int kLongMsgStep = 700;

/// Kelime sınırına geri çekilirken bakılan en fazla grafem sayısı (daha uzun boşluksuz bloklar aynen kesilir).
const int _kWordSlack = 48;

/// Mesaj uzunluğu tek ölçüyle sayılır: Unicode kod noktası; sunucu da kod noktası sayar.
int chatMsgLen(String s) => s.runes.length;

/// Uzun mesajın görünen hali: [shown] metnin görünen kısmı, [truncated] devamı var mı.
class LongMsgView {
  const LongMsgView(this.shown, this.truncated, this.canCollapse);

  final String shown;

  /// Hâlâ gizli kısım var ("Devamını gör").
  final bool truncated;

  /// Tamamı açıldı ve kullanıcı taban üzerine genişletmişti: "Daha az göster" gösterilir.
  final bool canCollapse;
}

/// [text] için görünen kısmı hesaplar. [limit] görünür grafem üst sınırı (null/≤0: [kLongMsgBase]).
/// Kesim emoji/birleşik işaret (grafem) içinden olmaz; mümkünse son 48 grafem içindeki boşlukta bitirilir.
/// [keepVisible]: arama eşleşmesi gibi görünür kalması gereken UTF-16 ofseti (null: yok).
LongMsgView longMsgView(String text, {int? limit, int? keepVisible}) {
  // UTF-16 uzunluğu grafem sayısından küçük olamaz: kısa metinde pahalı grafem taramasına girme.
  if (text.length <= kLongMsgBase) return LongMsgView(text, false, false);
  final chars = text.characters;
  final total = chars.length;
  var lim = (limit == null || limit < kLongMsgBase) ? kLongMsgBase : limit;
  if (keepVisible != null && keepVisible > 0 && keepVisible < text.length) {
    final upTo = text.substring(0, keepVisible).characters.length + _kWordSlack;
    if (upTo > lim) lim = upTo;
  }
  if (total <= lim) return LongMsgView(text, false, limit != null && limit > kLongMsgBase);
  return LongMsgView(_cut(chars, lim), true, false);
}

String _cut(Characters chars, int n) {
  final head = chars.take(n);
  final nextIsSpace = _isSpace(chars.skip(n).first);
  var out = head.toString();
  if (!nextIsSpace) {
    final hc = head.toList();
    final from = hc.length - 1;
    final stop = hc.length - _kWordSlack < 1 ? 1 : hc.length - _kWordSlack;
    for (var i = from; i >= stop; i--) {
      if (_isSpace(hc[i])) {
        out = hc.take(i).join();
        break;
      }
    }
  }
  return out.trimRight();
}

bool _isSpace(String g) => g.trim().isEmpty;

/// Bir sonraki "Devamını gör" sınırı: önceki görünür sınır + 700.
int nextLongMsgLimit(int? current) => (current == null || current < kLongMsgBase ? kLongMsgBase : current) + kLongMsgStep;

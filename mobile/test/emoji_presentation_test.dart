import 'package:bu_kampus/features/chat/emoji_presentation.dart';
import 'package:bu_kampus/features/chat/recent_reactions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('goruntu secicisi eksik kalp renkli emojiye tamamlanir', () {
    expect(withEmojiPresentation('❤'), '❤️');
    expect(withEmojiPresentation('seni ❤ seviyorum'),
        'seni ❤️ seviyorum');
  });

  test('secici zaten varsa ya da yazi bicimi (FE0E) istenmisse dokunulmaz', () {
    expect(withEmojiPresentation('❤️'), '❤️');
    expect(withEmojiPresentation('❤︎'), '❤︎');
  });

  test('duz metin, rakam ve diger emojiler degismez; bos metin guvenli', () {
    expect(withEmojiPresentation('Merhaba 123 \u{1F602}'), 'Merhaba 123 \u{1F602}');
    expect(withEmojiPresentation(''), '');
  });

  test('tepki gorunumu: ❤ ve ❤️ ayni renkli kalbe donusur', () {
    expect(RecentReactions.display('❤'), '❤️');
    expect(RecentReactions.display('❤️'), '❤️');
    expect(RecentReactions.display('\u{1F44D}'), '\u{1F44D}');
  });
}

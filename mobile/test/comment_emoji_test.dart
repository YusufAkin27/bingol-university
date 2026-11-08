import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bu_kampus/features/chat/emoji_presentation.dart';

void main() {
  controllerTests();
  test('yorumda kalp renkli emoji sunumu ve chat ile ayni 1.7 kat', () {
    const base = TextStyle(fontSize: 10);
    final span = emojiAwareSpan('a ❤ b', base);
    final kids = span.children!.cast<TextSpan>();
    final heart = kids.firstWhere((s) => s.text!.contains('❤'));
    expect(heart.text, contains('\u{FE0F}'));
    expect(heart.style!.fontSize, closeTo(17, 0.001));
    expect(heart.style!.fontFamily, kEmojiFontStyle.fontFamily);
  });
}

void controllerTests() {
  test('EmojiTextEditingController: IME kalbi renkli sunum secicisiyle tamamlar, imlec kayar', () {
    final c = EmojiTextEditingController();
    c.value = const TextEditingValue(text: 'a❤', selection: TextSelection.collapsed(offset: 2));
    expect(c.text, 'a❤\u{FE0F}');
    expect(c.selection.baseOffset, 3);
    c.value = const TextEditingValue(text: 'a❤\u{FE0F}b', selection: TextSelection.collapsed(offset: 4));
    expect(c.text, 'a❤\u{FE0F}b');
    expect(c.selection.baseOffset, 4);
  });
}

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bu_kampus/features/chat/emoji_presentation.dart';

void main() {
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

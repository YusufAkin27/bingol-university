import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/chat_bubble_colors.dart';
import 'package:bu_kampus/features/chat/chat_wallpaper.dart';

/// Premium monochrome sohbet: balon / saat / tik / giriş alanı kontrastları (iki tema) ve ham renk yasağı.
double _cr(Color a, Color b) {
  // Yarı saydam ön rengi önce zeminle birleştir (gerçek ekran kontrastı).
  final fg = Color.alphaBlend(a, b);
  final la = fg.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + .05) / (lo + .05);
}

void main() {
  final themes = <String, BuTokens>{'Premium White': BuTokens.light, 'Premium Black': BuTokens.dark};

  for (final e in themes.entries) {
    final t = e.value;
    final bc = ChatBubbleColors.of(t);

    group('balonlar ${e.key}', () {
      test('gelen balon: koyu/açık gri yüzey (sf2), yazı ve saat AA', () {
        expect(bc.incoming, t.sf2);
        expect(_cr(bc.onIncoming, bc.incoming), greaterThanOrEqualTo(7));
        expect(_cr(bc.metaIncoming, bc.incoming), greaterThanOrEqualTo(4.5));
        expect(_cr(bc.readOnIncoming, bc.incoming), greaterThanOrEqualTo(3));
      });

      test('giden balon: birincil ton, yazı / saat / okundu tiki okunur', () {
        expect(bc.outgoing, t.pr);
        expect(_cr(bc.onOutgoing, bc.outgoing), greaterThanOrEqualTo(7));
        expect(_cr(bc.metaOutgoing, bc.outgoing), greaterThanOrEqualTo(4.5));
        // Okundu mavi çift tik: balon zemininde >= 4.5 (küçük simge, AA metin eşiği ile ölçülür).
        expect(_cr(bc.readOnOutgoing, bc.outgoing), greaterThanOrEqualTo(4.5));
      });

      test('gelen ve giden balon birbirinden belirgin ayrışır', () {
        expect(_cr(bc.incoming, bc.outgoing), greaterThanOrEqualTo(4.5));
      });

      test('balonlar sohbet zemininden ayırt edilir (giden >= 3:1, gelen kenarlıkla)', () {
        expect(_cr(bc.outgoing, t.bg), greaterThanOrEqualTo(3));
        // Gelen balon zemine yakın ton: ayrım ton farkı + ince kenarlık ile yapılır (kenarlık görünür).
        expect(_cr(t.bd, t.bg), greaterThan(1.1));
        expect(bc.incoming == t.bg, isFalse);
      });

      test('giriş alanı: yüzey + kenarlık, yazı ve ipucu okunur; kenarlık zeminden ayrılır', () {
        expect(_cr(t.ink, t.sf), greaterThanOrEqualTo(7));
        expect(_cr(t.mut, t.sf), greaterThanOrEqualTo(4.5));
        expect(_cr(t.bd, t.sf), greaterThan(1.05));
        // Gönder düğmesi: birincil + ters ok.
        expect(_cr(t.onPr, t.pr), greaterThanOrEqualTo(7));
      });

      test('okunmamış rozeti: pr zemin + onPr yazı AA', () {
        expect(_cr(t.onPr, t.pr), greaterThanOrEqualTo(4.5));
      });
    });
  }

  test('okundu tiki giden balonun parlaklığına göre seçilir', () {
    // Açık temada giden balon koyu -> gök mavisi; koyu temada giden balon açık -> koyu mavi.
    expect(ChatBubbleColors.of(BuTokens.light).readOnOutgoing, BuTokens.light.readSky);
    expect(ChatBubbleColors.of(BuTokens.dark).readOnOutgoing, BuTokens.dark.readDeep);
  });

  test('duvar kağıdı örtüsü yüksek (desen çok silik) ve gri matris nötr', () {
    expect(kChatWallpaperVeil, greaterThanOrEqualTo(.5));
    expect(kChatWallpaperVeil, lessThan(1));
    // Her çıkış kanalı aynı katsayılar: R=G=B (renk tonu yok).
    expect(kChatWallpaperGray.sublist(0, 5), kChatWallpaperGray.sublist(5, 10));
    expect(kChatWallpaperGray.sublist(0, 5), kChatWallpaperGray.sublist(10, 15));
  });
}

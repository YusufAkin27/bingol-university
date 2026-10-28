import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/typography.dart';

// Anket ekranları (An1-An4) ortak görsel parçaları. Sabit ton renkleri tasarımdan; diğerleri context.bu.

/// Tasarımdaki sabit tonlar (açık, koyu).
class AnketTone {
  const AnketTone(this.bg, this.fg);
  final Color bg;
  final Color fg;

  static AnketTone general(BuildContext c) => _dark(c)
      ? const AnketTone(Color(0xFF232C44), Color(0xFF9DB4F0))
      : const AnketTone(Color(0xFFE8EDF8), Color(0xFF2F4FA8));
  static AnketTone club(BuildContext c) => _dark(c)
      ? const AnketTone(Color(0xFF1E3A2B), Color(0xFF7FD6A4))
      : const AnketTone(Color(0xFFE6F2EA), Color(0xFF1F7A4A));
  static AnketTone meal(BuildContext c) => _dark(c)
      ? const AnketTone(Color(0xFF42330F), Color(0xFFF0C377))
      : const AnketTone(Color(0xFFFBEFD9), Color(0xFF8A5200));
}

bool _dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// Yıldız ve puan dağılımı rengi.
const anketGold = Color(0xFFE8A317);

/// Uyarı kutusu renkleri (Oyunuz gizli notu).
({Color bg, Color bd, Color fg}) anketNoteColors(BuildContext c) => _dark(c)
    ? (bg: const Color(0xFF3A2D18), bd: const Color(0xFF5A4524), fg: const Color(0xFFF2D9B0))
    : (bg: const Color(0xFFFFF3E3), bd: const Color(0xFFF3DDBF), fg: const Color(0xFF5B3B0E));

TextStyle anketText(double size, FontWeight w, Color color, {double? height, double? ls}) =>
    TextStyle(fontFamily: BuType.family, fontSize: size, fontWeight: w, color: color, height: height, letterSpacing: ls);

/// 24 dp yüksekliğinde hap rozet.
class AnketPill extends StatelessWidget {
  const AnketPill(this.label, {super.key, required this.bg, required this.fg, this.icon, this.small = false});

  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final h = small ? 20.0 : 24.0;
    return Container(
      constraints: BoxConstraints(minHeight: h),
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12.5, color: fg), const SizedBox(width: 4)],
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: anketText(small ? 10.5 : 11.5, FontWeight.w700, fg, height: 1.2)),
        ),
      ]),
    );
  }
}

/// Beyaz kart: 20 dp köşe, ince çizgi, yumuşak gölge.
BoxDecoration anketCardDeco(BuTokens t, {Color? border, double borderWidth = 1}) => BoxDecoration(
      color: t.sf,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border ?? t.bd, width: borderWidth),
      boxShadow: const [BoxShadow(color: Color(0x40171E33), blurRadius: 18, offset: Offset(0, 6), spreadRadius: -12)],
    );

/// Sabit alt çubuk: üstte geçişli zemin, altta birincil düğme (An2/An4).
class AnketBottomBar extends StatelessWidget {
  const AnketBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: const [0.62, 1],
          colors: [t.bg, t.bg.withValues(alpha: 0)],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 24, 20, 16 + MediaQuery.of(context).padding.bottom),
        child: child,
      ),
    );
  }
}

/// 56 dp kırmızı birincil düğme (yükleniyor ve pasif durumlu).
class AnketPrimaryButton extends StatelessWidget {
  const AnketPrimaryButton({super.key, required this.label, this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final enabled = onPressed != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: Opacity(
        opacity: onPressed == null ? .5 : 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: onPressed == null
                ? null
                : const [BoxShadow(color: Color(0x99C62A20), blurRadius: 26, offset: Offset(0, 14), spreadRadius: -12)],
          ),
          child: Material(
            color: t.pr,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: enabled ? onPressed : null,
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: Center(
                  child: busy
                      ? SizedBox(
                          width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: t.onPr))
                      : Text(label, style: anketText(15, FontWeight.w700, t.onPr)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Seçenek satırı için kare/yuvarlak işaret (radyo ya da onay kutusu); seçiliyken dolu.
class AnketMark extends StatelessWidget {
  const AnketMark({super.key, required this.on, required this.square});

  final bool on;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: on ? t.pr : Colors.transparent,
        borderRadius: BorderRadius.circular(square ? 7 : 11),
        border: Border.all(color: on ? t.pr : t.mut.withValues(alpha: .55), width: 2),
      ),
      child: on
          ? Center(
              child: square
                  ? Icon(Icons.check, size: 14, color: t.onPr)
                  : Container(width: 8, height: 8, decoration: BoxDecoration(color: t.onPr, shape: BoxShape.circle)))
          : null,
    );
  }
}

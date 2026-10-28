import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';

/// Sohbet listesi: tasarım (P3-Sohbetler) bileşenleri.

/// "Yeni sohbet" kırmızı yuvarlak düğme (44 px, yumuşak kırmızı gölge).
class ChatlistNewButton extends StatelessWidget {
  const ChatlistNewButton({super.key, required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.pr,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: t.pr.withValues(alpha: .45),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                    spreadRadius: -10),
              ],
            ),
            child: Icon(LucideIcons.plus, size: 20, color: t.onPr),
          ),
        ),
      ),
    );
  }
}

/// Arama kutusu: 48 px, 16 px köşe, yüzey rengi + ince çizgi.
class ChatlistSearch extends StatelessWidget {
  const ChatlistSearch({super.key, required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      height: 48,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.bd),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 18, color: t.mut),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: BuType.body.copyWith(color: t.ink, fontSize: 14),
              cursorColor: t.pr,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: hint,
                hintStyle: BuType.body.copyWith(color: t.mut, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Segment: sf2 zemin, 16 px köşe, seçili öğe yüzey rengi + gölge.
class ChatlistSegment extends StatelessWidget {
  const ChatlistSegment(
      {super.key, required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      key: const ValueKey('chat-segment'),
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration:
          BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16)),
      // Sabit yükseklikli denetim: yazı ölçeği sınırlanır.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.1,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == selected,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(i),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i == selected ? t.sf : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: i == selected
                            ? [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: .12),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                    spreadRadius: -2)
                              ]
                            : null,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(labels[i],
                            maxLines: 1,
                            softWrap: false,
                            style: BuType.label.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: i == selected ? t.ink : t.mut)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Fotoğrafsız avatar tonları (tasarımdaki sabit renkler).
const _tones = <Color>[
  Color(0xFF2F4FA8), // mavi
  Color(0xFF8A5200), // kehribar
  Color(0xFF1F7A4A), // yeşil
  Color(0xFF8A2F7A), // mor
  Color(0xFF0E6B7A), // petrol
];

/// 52 px avatar: fotoğraf varsa yuvarlak foto, yoksa baş harfli renkli daire.
class ChatlistAvatar extends StatelessWidget {
  const ChatlistAvatar(
      {super.key, required this.name, this.url, this.group = false, this.size = 52});

  final String name;
  final String? url;
  final bool group;
  final double size;

  static String initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final a = String.fromCharCode(parts.first.runes.first);
    final b = parts.length > 1 ? String.fromCharCode(parts.last.runes.first) : '';
    return (a + b).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return BuAvatar(name: name, url: url, size: size, group: group);
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    var fg = _tones[name.runes.fold<int>(0, (a, r) => (a + r) % 9973) %
        _tones.length];
    if (dark) fg = Color.lerp(fg, Colors.white, .5)!;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: fg.withValues(alpha: dark ? .22 : .14), shape: BoxShape.circle),
        child: Text(initials(name),
            style: BuType.bodyStrong
                .copyWith(color: fg, fontSize: 17, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

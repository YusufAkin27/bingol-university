import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../core/icons/bu_icons.dart';
import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import '../../widgets/peek_dialog.dart';

/// "Bugün kampüste" satırının ön izleme içeriği: başlık, (etiket, değer) satırları ve isteğe bağlı rozet
/// (örn. toplam kalori). Veriyi satırı kuran taraf hazırlar; ön izleme yalnızca çizer.
class HomeTodayPeek {
  const HomeTodayPeek({
    required this.title,
    this.subtitle,
    this.lines = const [],
    this.badge,
  });

  final String title;
  final String? subtitle;

  /// `label` boşsa değer tek başına (sol) çizilir; doluysa sağda soluk değer olarak gösterilir.
  final List<({String label, String value})> lines;
  final String? badge;
}

/// Satır uzun basılınca ortak peek kabuğunda ön izleme açar. [onOpen]: ilgili sayfaya git (önce ön izleme kapanır).
Future<void> showHomeTodayPeek(
  BuildContext context, {
  required IconData icon,
  required String label,
  required HomeTodayPeek peek,
  required VoidCallback onOpen,
}) {
  return showPeekDialog(
    context,
    builder: (ctx, close) => _HomeTodayPeekCard(
      key: const ValueKey('homeTodayPeek'),
      icon: icon,
      label: label,
      peek: peek,
      onOpen: () {
        close();
        onOpen();
      },
    ),
  );
}

class _HomeTodayPeekCard extends StatelessWidget {
  const _HomeTodayPeekCard(
      {super.key,
      required this.icon,
      required this.label,
      required this.peek,
      required this.onOpen});

  final IconData icon;
  final String label;
  final HomeTodayPeek peek;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final size = MediaQuery.sizeOf(context);
    final width = (size.width - 40).clamp(240.0, 440.0);
    const tab = [FontFeature.tabularFigures()];
    return SafeArea(
      child: Center(
        child: Dismissible(
          key: const ValueKey('home-today-peek-dismiss'),
          direction: DismissDirection.down,
          onDismissed: (_) => Navigator.of(context).maybePop(),
          child: Material(
            color: t.sf,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: t.bd)),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: width, maxHeight: size.height * .7),
              child: SizedBox(
                width: width,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: t.soft,
                                borderRadius: BorderRadius.circular(13)),
                            child: Icon(icon, size: 20, color: t.onSoft),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.labelMedium?.copyWith(
                                    color: t.mut,
                                    fontWeight: FontWeight.w400)),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        Text(peek.title,
                            style: tt.titleMedium?.copyWith(
                                color: t.ink,
                                fontWeight: FontWeight.w400,
                                height: 1.3)),
                        if ((peek.subtitle ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(peek.subtitle!,
                              style: tt.bodyMedium
                                  ?.copyWith(color: t.mut, height: 1.35)),
                        ],
                        for (final ln in peek.lines) ...[
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                      ln.label.isEmpty ? ln.value : ln.label,
                                      style: tt.bodyMedium?.copyWith(
                                          color: ln.label.isEmpty
                                              ? t.ink
                                              : t.mut,
                                          height: 1.3)),
                                ),
                                if (ln.label.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(ln.value,
                                        textAlign: TextAlign.end,
                                        style: tt.bodyMedium?.copyWith(
                                            color: t.ink,
                                            height: 1.3,
                                            fontFeatures: tab)),
                                  ),
                                ],
                              ]),
                        ],
                        if ((peek.badge ?? '').isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                                color: t.soft,
                                borderRadius:
                                    BorderRadius.circular(BuRadius.pill)),
                            child: Text(peek.badge!,
                                style: tt.labelLarge?.copyWith(
                                    color: t.onSoft,
                                    fontWeight: FontWeight.w400,
                                    fontFeatures: tab)),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton.icon(
                            key: const ValueKey('homeTodayPeekOpen'),
                            onPressed: onOpen,
                            icon: Icon(
                                Directionality.of(context) == TextDirection.rtl
                                    ? BuIcons.chevronLeft
                                    : BuIcons.chevronRight,
                                size: 18,
                                color: t.ink),
                            iconAlignment: IconAlignment.end,
                            label: Text(l.homeTodayPeekOpen,
                                style: tt.labelLarge?.copyWith(
                                    color: t.ink,
                                    fontWeight: FontWeight.w400)),
                          ),
                        ),
                      ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

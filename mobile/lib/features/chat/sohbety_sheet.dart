import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';

/// Alt sayfa kabuğu (İlet, Üye ekle): tutamaç, başlık + kapat, arama, liste, alt eylem çubuğu.
/// Tasarım: krem zemin, üst köşeler 28 px, ekranın ~%78'i.
Future<T?> showSohbetySheet<T>(BuildContext context, WidgetBuilder builder) {
  final t = context.bu;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: t.bg,
    barrierColor: const Color(0x80171E33),
    isScrollControlled: true,
    showDragHandle: false,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: builder,
  );
}

class SohbetySheetFrame extends StatelessWidget {
  const SohbetySheetFrame({
    super.key,
    required this.title,
    required this.search,
    required this.body,
    required this.footer,
    this.note,
  });

  final String title;
  final Widget search;
  final Widget body;
  final Widget footer;

  /// Arama altında kısa uyarı (sınır aşıldı vb.).
  final Widget? note;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final mq = MediaQuery.of(context);
    final kb = mq.viewInsets.bottom;
    final h = (mq.size.height * .78).clamp(0.0, mq.size.height - kb - mq.padding.top - 8);
    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: SizedBox(
        height: h,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(top: 10),
              decoration:
                  BoxDecoration(color: t.bd, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: t.ink)),
                ),
              ),
              const SizedBox(width: 12),
              BuIconButton(
                  icon: LucideIcons.x,
                  tooltip: context.l10n.chatMiscClose,
                  onTap: () => Navigator.maybePop(context)),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: search),
          if (note != null)
            Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 6), child: note),
          Expanded(child: body),
          Container(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, 12 + (kb > 0 ? 0 : mq.padding.bottom)),
            decoration: BoxDecoration(
              color: t.sf,
              border: Border(top: BorderSide(color: t.bd)),
            ),
            child: footer,
          ),
        ]),
      ),
    );
  }
}

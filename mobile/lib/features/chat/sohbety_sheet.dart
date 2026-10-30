import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';

/// Alt sayfa kabuğu (İlet, Üye ekle): M3 alt sayfa zemini, 28 dp üst köşe, tonal katman.
/// Elle çizilen tutamaç [SohbetySheetFrame] içindedir (tema `showDragHandle: false`).
Future<T?> showSohbetySheet<T>(BuildContext context, WidgetBuilder builder) {
  final t = context.bu;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: t.sf3,
    barrierColor: t.scrim.withValues(alpha: .5),
    isScrollControlled: true,
    showDragHandle: false,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(borderRadius: BuRadius.topXl),
    builder: builder,
  );
}

/// Alt sayfa gövdesi (İlet, Üye ekle): tutamaç, başlık + kapat, arama, liste, alt eylem çubuğu. Ekranın ~%78'i.
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
          ExcludeSemantics(
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(color: t.bd, borderRadius: BuRadius.bPill),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 8, 8),
            child: Row(children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(color: t.ink)),
                ),
              ),
              BuGap.w8,
              BuIconButton(
                  icon: LucideIcons.x, tooltip: context.l10n.chatMiscClose, onTap: () => Navigator.maybePop(context)),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: search),
          if (note != null) Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 6), child: note),
          Expanded(child: body),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + (kb > 0 ? 0 : mq.padding.bottom)),
            decoration: BoxDecoration(color: t.sf3, border: Border(top: BorderSide(color: t.bd))),
            child: footer,
          ),
        ]),
      ),
    );
  }
}

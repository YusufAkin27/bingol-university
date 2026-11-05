import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';

/// Yemekhane kartı bakiye yükleme sitesi (yalnız https; harici tarayıcıda açılır).
final Uri menuTopUpUri = Uri.parse('https://yukle.al/');

/// Yemek sayfasında: bakiyesi biten öğrenciyi yukle.al'a yönlendiren kart. Menü dolu ya da boş fark etmez görünür.
class MenuTopUpCard extends StatefulWidget {
  const MenuTopUpCard({super.key});

  @override
  State<MenuTopUpCard> createState() => _MenuTopUpCardState();
}

class _MenuTopUpCardState extends State<MenuTopUpCard> {
  bool _busy = false;

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await launchUrl(menuTopUpUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) BuToast.show(context, context.l10n.menuTopUpFailed, kind: BuToastKind.error);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.sf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.bd),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: t.infoSoft, borderRadius: BorderRadius.circular(14)),
                child: Icon(BuIcons.idCard, size: 22, color: t.onInfoSoft),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l.menuTopUpTitle,
                      style: BuType.caption.copyWith(fontSize: 17, height: 1.3, fontWeight: FontWeight.w400, color: t.ink)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Text(l.menuTopUpBody, style: BuType.caption.copyWith(fontSize: 14, height: 1.5, color: t.mut)),
            const SizedBox(height: 16),
            BuButton(label: l.menuTopUpAction, icon: BuIcons.arrowUpRight, busy: _busy, onPressed: _open),
          ]),
        ),
      ),
    );
  }
}

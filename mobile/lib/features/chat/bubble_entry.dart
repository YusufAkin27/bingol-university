import 'package:flutter/material.dart';

import '../../core/theme/bu_motion.dart';

/// Yeni mesaj balonunun girişi: gönderilen balon alttan hafifçe yükselerek, alınan balon yalnız solarak belirir.
///
/// Yalnız "taze" balonda oynar ([fresh]): bu oturumda yerelde eklenen (bekleyen/başarısız) ya da saniyeler önce
/// oluşmuş mesaj. Geçmiş yüklenirken, yukarı kaydırıp geri dönerken ve yenilemede balon statiktir (animasyon yok,
/// controller yok). Durum, satır anahtarıyla (clientId/id) korunur: yerelden sunucu mesajına geçişte tekrar oynamaz.
/// Yalnız opacity + transform; "animasyonları azalt" açıkken anında.
class BubbleEntry extends StatefulWidget {
  const BubbleEntry({super.key, required this.mine, required this.fresh, required this.child});

  final bool mine;
  final bool fresh;
  final Widget child;

  /// Mesaj haritasından tazelik: yerel (`_state`) ya da [window] içinde oluşmuş.
  static bool isFresh(Map<String, dynamic> m, {Duration window = const Duration(seconds: 3)}) {
    if (m['_state'] != null) return true;
    final d = DateTime.tryParse((m['createdAt'] as String?) ?? '');
    return d != null && DateTime.now().difference(d).abs() <= window;
  }

  @override
  State<BubbleEntry> createState() => _BubbleEntryState();
}

class _BubbleEntryState extends State<BubbleEntry> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  Animation<double>? _curve;
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    if (!widget.fresh || BuMotion.reduced(context)) return;
    final c = AnimationController(
      vsync: this,
      duration: widget.mine ? BuMotion.medium : BuMotion.short,
    );
    _curve = CurvedAnimation(parent: c, curve: BuMotion.emphasizedDecelerate);
    _c = c..forward();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_c == null) return widget.child;
    // Bitince de aynı ağaç şekli korunur (çocuğun alt durumu/görseli yeniden kurulmasın); opacity 1, öteleme 0.
    final curve = _curve!;
    if (!widget.mine) return FadeTransition(opacity: curve, child: widget.child);
    return FadeTransition(
      opacity: curve,
      child: AnimatedBuilder(
        animation: curve,
        child: widget.child,
        builder: (_, child) => Transform.translate(offset: Offset(0, 14 * (1 - curve.value)), child: child),
      ),
    );
  }
}

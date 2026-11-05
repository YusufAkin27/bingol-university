import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../academic/akad_widgets.dart' show AkadTonalButton;
import '../posts/social_api.dart';
import '../posts/social_models.dart';
import 'follow_sheets.dart';

/// Takip düğmesinin görünümü (davranış aynı: [FollowStateButton]).
enum FollowLook {
  /// Tam genişlik (profil sayfası): Takip et (birincil) / İstek gönderildi (çizgili) / Takiptesin (tonal).
  block,

  /// Liste satırı (takipçi/takip, öneri, arama): 36 dp hap, 48 dp dokunma alanı.
  row,

  /// Kişi kutucuğu: dolu marka "Takip et" hapı.
  pill,

  /// Keşfet öneri kartı: tam genişlik ince çerçeveli hap.
  chip,

  /// Koyu video üstü (Reels): şeffaf, ince açık çerçeveli küçük hap (30 dp görünür, 44 dp dokunma alanı).
  media,
}

/// Üç durumlu takip düğmesi (`followState` TEK kaynak): "Takip et" -> GİZLİ hesapta "İstek gönderildi" -> "Takiptesin".
/// Dokununca: NONE iyimser ilerler (gizli hesap -> REQUESTED, açık hesap -> FOLLOWING; `POST /users/{id}/follow`),
/// REQUESTED "İsteği geri çek" onayı, FOLLOWING "Takibi bırak" onayı sonrası `DELETE /users/{id}/follow` yollar.
/// İstek hata verirse önceki duruma döner ve hata bildirimi çıkar. Sunucunun kesin `followState` yanıtı iyimser tahminin
/// yerini alır (örn. hesap bu arada gizli olduysa).
class FollowStateButton extends StatefulWidget {
  const FollowStateButton({
    super.key,
    required this.session,
    required this.userId,
    required this.state,
    this.isPrivate = false,
    this.look = FollowLook.row,
    this.compact = true,
    this.tapKey = const ValueKey('followButton'),
    this.onChanged,
    this.onState,
  });

  final Session session;
  final int userId;

  /// Dıştan gelen durum (liste/profil verisi); sonraki yüklemede değişirse düğme eşitlenir.
  final FollowState state;

  /// Hedef hesap gizli mi (NONE'dan hangi duruma iyimser geçileceğini belirler).
  final bool isPrivate;
  final FollowLook look;

  /// [FollowLook.block] için düğme yüksekliği (true: 34 dp).
  final bool compact;
  final Key tapKey;

  /// Yeni durum "takipte" mi (eski arayüz sözleşmesi: iyimser, geri alma ve sunucu düzeltmesinde çağrılır).
  final ValueChanged<bool>? onChanged;

  /// Her durum değişiminde (iyimser: `result == null`; sunucu yanıtı: `result` dolu; hata geri alması: `result == null`).
  final void Function(FollowState state, FollowResult? result)? onState;

  @override
  State<FollowStateButton> createState() => _FollowStateButtonState();
}

class _FollowStateButtonState extends State<FollowStateButton> {
  late FollowState _state = widget.state;
  bool _busy = false;

  @override
  void didUpdateWidget(FollowStateButton old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state && !_busy) _state = widget.state;
  }

  void _emit(FollowState s, FollowResult? r) {
    widget.onChanged?.call(s == FollowState.following);
    widget.onState?.call(s, r);
  }

  Future<void> _tap() async {
    if (_busy) return;
    final prev = _state;
    if (prev == FollowState.self) return;
    _busy = true;
    FollowState next;
    switch (prev) {
      case FollowState.none:
        next = widget.isPrivate ? FollowState.requested : FollowState.following;
      case FollowState.requested:
        final ok = await confirmCancelRequest(context);
        if (!ok || !mounted) {
          _busy = false;
          return;
        }
        next = FollowState.none;
      case FollowState.following:
        final ok = await confirmUnfollow(context, isPrivate: widget.isPrivate);
        if (!ok || !mounted) {
          _busy = false;
          return;
        }
        next = FollowState.none;
      case FollowState.self:
        _busy = false;
        return;
    }
    buHaptic(next == FollowState.none ? BuHaptic.selection : BuHaptic.light);
    setState(() => _state = next);
    _emit(next, null);
    final api = SocialApi(widget.session);
    try {
      final res = await (prev == FollowState.none ? api.follow(widget.userId) : api.unfollow(widget.userId));
      final fin = res.followState ?? next;
      if (mounted && fin != next && fin != FollowState.self) setState(() => _state = fin);
      if (fin != FollowState.self) _emit(fin, res);
    } catch (e) {
      if (mounted) {
        setState(() => _state = prev);
        BuToast.show(context, errorText(e), kind: BuToastKind.error);
      }
      _emit(prev, null);
    } finally {
      _busy = false;
    }
  }

  String _semLabel(BuildContext context) {
    final l = context.l10n;
    return switch (_state) {
      FollowState.requested => l.frqSemRequested,
      FollowState.following => l.followButtonUnfollow,
      _ => l.followButtonFollow,
    };
  }

  /// Liste satırında "Takipte" kalır: satırın altındaki ilişki satırı zaten "Takiptesin" der (tekrar etmesin).
  String _text(BuildContext context, {bool chip = false, bool row = false}) {
    final l = context.l10n;
    return switch (_state) {
      FollowState.requested => l.frqFollowRequested,
      FollowState.following => chip ? l.p04FollowingState : (row ? l.followButtonFollowing : l.profilyardFollowingYou),
      _ => chip ? l.p04FollowAction : l.followButtonFollow,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_state == FollowState.self) return const SizedBox.shrink();
    final child = switch (widget.look) {
      FollowLook.block => _block(context),
      FollowLook.row => _row(context),
      FollowLook.pill => _pill(context),
      FollowLook.chip => _chip(context),
      FollowLook.media => _media(context),
    };
    return Semantics(
      button: true,
      toggled: _state == FollowState.following,
      label: _semLabel(context),
      excludeSemantics: true,
      onTap: _busy ? null : _tap,
      child: child,
    );
  }

  Widget _block(BuildContext context) {
    final label = _text(context);
    switch (_state) {
      case FollowState.following:
        return AkadTonalButton(
          key: widget.tapKey,
          label: label,
          icon: BuIcons.check,
          height: widget.compact ? BuSize.buttonCompact : BuSize.button,
          onPressed: _tap,
        );
      case FollowState.requested:
        return BuButton(
          key: widget.tapKey,
          label: label,
          icon: BuIcons.clock,
          kind: BuButtonKind.outline,
          compact: widget.compact,
          onPressed: _tap,
        );
      default:
        return BuButton(
          key: widget.tapKey,
          label: label,
          icon: BuIcons.userPlus,
          compact: widget.compact,
          background: context.bu.prPressed, // Stitch profil-v4: #B93833
          onPressed: _tap,
        );
    }
  }

  /// Liste satırı: Takip et = dolu (prPressed); İstek gönderildi = çizgili (bd, soluk); Takiptesin = tonal (soft).
  Widget _row(BuildContext context) {
    final t = context.bu;
    final none = _state == FollowState.none;
    final req = _state == FollowState.requested;
    final r = BorderRadius.circular(BuRadius.pill);
    return BuPressable(
      onTap: _busy ? null : _tap,
      child: ConstrainedBox(
        key: widget.tapKey,
        // Uzun etiket ("İstek gönderildi") satırdaki adı ezmesin: genişliğin yarısı ile sınırlı, metin kısalır.
        constraints: BoxConstraints(minHeight: 48, minWidth: 76, maxWidth: MediaQuery.sizeOf(context).width * .5),
        child: Center(
          widthFactor: 1,
          // 36 dp görünür hap, 48 dp dokunma alanı.
          child: AnimatedContainer(
            duration: BuMotion.of(context, BuMotion.short),
            curve: BuMotion.standard,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // Stitch profil-v4: Takip et = dolu (prPressed, beyaz yazı AA), Takipte = tonal soft, istek = çizgili.
            decoration: BoxDecoration(
              color: none ? t.prPressed : (req ? Colors.transparent : t.soft),
              border: req ? Border.all(color: t.bd) : null,
              borderRadius: r,
            ),
            // alignment yerine Center(widthFactor): kapta genişliğe yayılmasın, metin kadar olsun.
            child: Center(
              widthFactor: 1,
              child: Text(_text(context, row: true),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge!
                      .copyWith(fontSize: 14, fontWeight: FontWeight.w400, color: none ? t.onPr : (req ? t.mut : t.onSoft))),
            ),
          ),
        ),
      ),
    );
  }

  /// Kişi kutucuğu hapı: Takip et = dolu marka; İstek gönderildi / Takiptesin = tonal.
  Widget _pill(BuildContext context) {
    final t = context.bu;
    final on = _state == FollowState.none;
    final req = _state == FollowState.requested;
    final icon = req ? BuIcons.clock : (on ? BuIcons.userPlus : BuIcons.userCheck);
    return AnimatedContainer(
      key: widget.tapKey,
      duration: BuMotion.of(context, BuMotion.short),
      curve: BuMotion.standard,
      decoration: ShapeDecoration(
        color: on ? t.pr : t.sf2,
        shape: StadiumBorder(side: on ? BorderSide.none : BorderSide(color: t.bd)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: _busy ? null : _tap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 96),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              widthFactor: 1,
              child: AnimatedSwitcher(
                duration: BuMotion.of(context, BuMotion.short),
                child: Row(
                  key: ValueKey(_state),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: on ? t.onPr : t.ink),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _text(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge!
                            .copyWith(fontWeight: FontWeight.w400, color: on ? t.onPr : t.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Reels: video üstünde şeffaf hap; Takip et = belirgin açık çerçeve, İstek/Takipte = soluk.
  Widget _media(BuildContext context) {
    final t = context.bu;
    final none = _state == FollowState.none;
    return GestureDetector(
      key: widget.tapKey,
      behavior: HitTestBehavior.opaque,
      onTap: _busy ? null : _tap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Center(
          widthFactor: 1,
          child: AnimatedContainer(
            duration: BuMotion.of(context, BuMotion.short),
            curve: BuMotion.standard,
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(BuRadius.pill),
              border: Border.all(color: t.onMedia.withValues(alpha: none ? .9 : .45)),
            ),
            child: Text(_text(context, row: true),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: none ? t.onMedia : t.onMedia.withValues(alpha: .8), fontSize: 13, fontWeight: FontWeight.w400)),
          ),
        ),
      ),
    );
  }

  /// Keşfet öneri kartı: ince çerçeveli hap (dolgu yok); Takip Et = bdStrong, diğerleri bd + soluk metin.
  Widget _chip(BuildContext context) {
    final t = context.bu;
    final none = _state == FollowState.none;
    return GestureDetector(
      key: widget.tapKey,
      behavior: HitTestBehavior.opaque,
      onTap: _busy ? null : _tap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(
          child: AnimatedContainer(
            duration: BuMotion.of(context, BuMotion.short),
            curve: BuMotion.standard,
            width: double.infinity,
            height: 36,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(BuRadius.pill),
              border: Border.all(color: none ? t.bdStrong : t.bd),
            ),
            child: Text(_text(context, chip: true),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: none ? t.ink : t.mut, fontSize: 13, fontWeight: FontWeight.w400)),
          ),
        ),
      ),
    );
  }
}

/// Eski ad: tam genişlik/kompakt düğme (profil sayaçları altında). Yeni kod [FollowStateButton] kullanır.
class FollowButton extends StatelessWidget {
  const FollowButton({
    super.key,
    required this.session,
    required this.userId,
    this.followed = false,
    this.state,
    this.isPrivate = false,
    this.onChanged,
    this.compact = true,
  });

  final Session session;
  final int userId;
  final bool followed;
  final FollowState? state;
  final bool isPrivate;
  final ValueChanged<bool>? onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) => FollowStateButton(
        session: session,
        userId: userId,
        state: state ?? (followed ? FollowState.following : FollowState.none),
        isPrivate: isPrivate,
        look: FollowLook.block,
        compact: compact,
        onChanged: onChanged,
      );
}

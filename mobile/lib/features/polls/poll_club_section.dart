import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'anket_flat.dart';
import 'poll_api.dart';
import 'poll_models.dart';
import 'poll_parts.dart';
import 'poll_routes.dart';

/// Kullanıcının kulüpteki üyelik durumu: kulüp anketleri yalnız ACTIVE üyelere açıktır (sunucu aksi halde
/// 403 `POLL_NOT_ELIGIBLE` döner), bu yüzden üye değilken sunucuya hiç istek atılmaz.
enum ClubPollAccess {
  member,
  pending,
  none;

  /// Kulüp ayrıntısındaki `myStatus` değerinden ('ACTIVE' | 'PENDING' | 'NONE' | 'BANNED').
  static ClubPollAccess fromStatus(String? status) => switch (status) {
        'ACTIVE' => ClubPollAccess.member,
        'PENDING' => ClubPollAccess.pending,
        _ => ClubPollAccess.none,
      };
}

/// Kulüp detayındaki "Anketler" bölümü (Stitch v3 kartsız satırlar): başlık + (yönetici ise) `pr` "+ Yeni", altında
/// kulübün anketleri satır olarak. [canCreate] false ise oluşturma düğmesi hiç gösterilmez.
///
/// Durumlar: üye değil -> kilit ("Anketleri görmek için kulübe katıl" + Katıl düğmesi, istek YOK); katılma isteği
/// beklemede -> kilit ("Üyelik isteğin onay bekliyor"); üye -> liste / boş durum / hata + yeniden dene.
/// Üye iken sunucu yine de 403 `POLL_NOT_ELIGIBLE` derse hata değil, aynı kilit görünür.
class PollClubSection extends StatefulWidget {
  const PollClubSection({
    super.key,
    required this.session,
    required this.communityId,
    required this.canCreate,
    this.hideWhenEmpty = false,
    this.access = ClubPollAccess.member,
    this.needsApproval = false,
    this.onJoin,
    this.joinBusy = false,
  });

  final Session session;
  final int communityId;
  final bool canCreate;

  /// true: anket yoksa (ve oluşturma yetkisi yoksa) bölüm hiç çizilmez.
  final bool hideWhenEmpty;

  /// Üyelik durumu; üye değilse anketler istenmez, kilit gösterilir.
  final ClubPollAccess access;

  /// Kulüp katılım isteği gerektiriyor mu (düğme etiketi "İstek gönder" olur).
  final bool needsApproval;

  /// Kilit durumundaki "Katıl" düğmesi (kulüp detayındaki katılma akışı). Null ise düğme çizilmez.
  final VoidCallback? onJoin;
  final bool joinBusy;

  @override
  State<PollClubSection> createState() => _PollClubSectionState();
}

class _PollClubSectionState extends State<PollClubSection> {
  late final PollApi _api = PollApi(widget.session);
  List<Poll>? _items;
  bool _more = false;
  Object? _error;

  /// Sunucu üye olmayan/uygun olmayan kullanıcıya 403 POLL_NOT_ELIGIBLE döndü.
  bool _forbidden = false;
  int _gen = 0;

  bool get _isMember => widget.access == ClubPollAccess.member;

  @override
  void initState() {
    super.initState();
    if (_isMember) _load();
  }

  @override
  void didUpdateWidget(PollClubSection old) {
    super.didUpdateWidget(old);
    // Katılma onaylandı / üye oldu: anketler şimdi istenir. Üyelik düştüyse eski liste atılır.
    if (old.access != widget.access) {
      if (_isMember) {
        _forbidden = false;
        _load();
      } else {
        _gen++;
        _items = null;
        _error = null;
      }
    }
  }

  Future<void> _load() async {
    final gen = ++_gen;
    setState(() {
      _error = null;
      _forbidden = false;
    });
    try {
      final r = await _api.list(scope: 'community:${widget.communityId}', size: 5);
      if (mounted && gen == _gen) {
        setState(() {
          _items = r.items;
          _more = r.hasMore;
        });
      }
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        if (isPollNotEligible(e)) {
          _forbidden = true;
        } else {
          _error = e;
        }
      });
    }
  }

  Future<void> _create() async {
    final p = await openPollForm(context, widget.session, communityId: widget.communityId);
    if (p != null && mounted) _load();
  }

  Future<void> _open(Poll p) async {
    await openPollDetail(context, widget.session, p.id, initial: p);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final locked = !_isMember || _forbidden;
    final items = _items;
    if (!locked && widget.hideWhenEmpty && !widget.canCreate && (items == null ? _error == null : items.isEmpty)) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    void seeAll() =>
        openPollList(context, widget.session, communityId: widget.communityId, title: l.pollClubPolls, canCreate: widget.canCreate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l.pollClubPolls, style: tx.titleMedium!.copyWith(color: t.ink, fontSize: 18, fontWeight: FontWeight.w400)),
                ),
              ),
              if (widget.canCreate && !locked)
                Semantics(
                  button: true,
                  label: l.pollCreate,
                  excludeSemantics: true,
                  onTap: _create,
                  child: TextButton(
                    style: TextButton.styleFrom(foregroundColor: t.prText, minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 12)),
                    onPressed: _create,
                    child: Text('+ ${l.p68New}', style: tx.titleSmall!.copyWith(color: t.prText, fontWeight: FontWeight.w400)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const AnketRule(),
        if (locked)
          PollLockedState(
            pending: widget.access == ClubPollAccess.pending,
            needsApproval: widget.needsApproval,
            // Üye olduğu halde 403 alan kullanıcıya "katıl" düğmesi sunulmaz.
            onJoin: _isMember ? null : widget.onJoin,
            busy: widget.joinBusy,
          )
        else if (_error != null && items == null)
          AnketStateLine(text: l.pollLoadFailedRetry, actionLabel: l.commonRetry, onAction: _load)
        else if (items == null)
          const BuSkeletonScope(child: Column(children: [AnketSkeletonRow(titleWidth: 230), AnketSkeletonRow(titleWidth: 190)]))
        else if (items.isEmpty)
          PollEmptyState(onCreate: widget.canCreate ? _create : null)
        else ...[
          BuStaggerScope(
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  BuStaggerItem(index: i, child: PollCard(poll: items[i], first: i == 0, onTap: () => _open(items[i]))),
              ],
            ),
          ),
          if (_more)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: kAnketPad),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: t.prText, minimumSize: const Size(48, 48), padding: EdgeInsets.zero),
                  onPressed: seeAll,
                  child: Text(l.pollSeeAll, style: tx.titleSmall!.copyWith(color: t.prText, fontWeight: FontWeight.w400)),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Kilit durumu: kilit simgesi + kısa açıklama + (üye değilse) katılma eylemi. Bekleyen istekte düğme yok.
class PollLockedState extends StatelessWidget {
  const PollLockedState({super.key, required this.pending, required this.needsApproval, this.onJoin, this.busy = false});

  final bool pending;
  final bool needsApproval;
  final VoidCallback? onJoin;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final title = pending ? l.cplPendingTitle : l.cplLockTitle;
    final body = pending ? l.cplPendingBody : (needsApproval ? l.cplLockBodyApproval : l.cplLockBody);
    return Semantics(
      container: true,
      label: '$title. $body',
      child: Padding(
        key: const ValueKey('pollLocked'),
        padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 20, kAnketPad, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle, border: Border.all(color: t.bd)),
                child: Icon(pending ? BuIcons.hourglass : BuIcons.lock, size: 20, color: t.ink),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  ExcludeSemantics(child: Text(title, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w400, height: 1.3))),
                  const SizedBox(height: 4),
                  ExcludeSemantics(child: Text(body, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.45))),
                  if (!pending && onJoin != null) ...[
                    const SizedBox(height: 12),
                    BuButton(
                      key: const ValueKey('pollLockedJoin'),
                      label: needsApproval ? l.cplSendRequest : l.clubJoin,
                      compact: true,
                      busy: busy,
                      onPressed: busy ? null : onJoin,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Anket yok: kısa boş durum; yönetici için "Anket oluştur" eylemi.
class PollEmptyState extends StatelessWidget {
  const PollEmptyState({super.key, this.onCreate});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      child: Padding(
        key: const ValueKey('pollEmpty'),
        padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 20, kAnketPad, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.pollClubEmpty, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
            if (onCreate != null) ...[
              const SizedBox(height: 4),
              Text(l.cplEmptyManagerBody, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.45)),
              const SizedBox(height: 8),
              BuButton(key: const ValueKey('pollEmptyCreate'), label: l.pollCreate, compact: true, onPressed: onCreate),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/accounts/account_store.dart';
import '../../core/locale_controller.dart';
import '../../core/nav.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../auth/auth_landing_page.dart';

/// Hesap değiştirme alt sayfası (Instagram benzeri, monokrom): hesap listesi (52 dp avatar, etkin hesapta onay simgesi),
/// "Hesap ekle" ve her satırda ⋯ ile "Bu cihazdan kaldır". Oturumu dolmuş hesap "Oturum süresi doldu" ile işaretlenir.
Future<void> showAccountSheet(BuildContext context, Session session) {
  return BuSheet.show<void>(
    context,
    title: context.l10n.accTitle,
    builder: (ctx) => AccountSheetBody(session: session),
  );
}

/// Giriş ekranını "hesap ekleme" kipinde açar (geri düğmesi iptal eder; başarılı girişte yeni hesap etkin olur).
/// [account]: oturumu dolmuş bir hesap için yeniden giriş (bilinen tam e-posta önceden doldurulur, yoksa maskeli ipucu).
Future<void> openAddAccount(Session session, {StoredAccount? account}) async {
  final nav = rootNavigatorKey.currentState;
  if (nav == null) return;
  await nav.push(MaterialPageRoute<void>(
    settings: const RouteSettings(name: 'add_account'),
    builder: (_) => AuthLandingPage(
      session: session,
      addAccount: true,
      prefillEmail: account == null ? null : session.knownEmailOf(account.userId),
      reloginHint: account?.emailMasked,
    ),
  ));
}

class AccountSheetBody extends StatefulWidget {
  const AccountSheetBody({super.key, required this.session});

  final Session session;

  @override
  State<AccountSheetBody> createState() => _AccountSheetBodyState();
}

class _AccountSheetBodyState extends State<AccountSheetBody> {
  bool _busy = false;

  Session get s => widget.session;

  Future<void> _tap(StoredAccount a) async {
    if (_busy) return;
    final nav = Navigator.of(context);
    if (a.userId == s.userId) {
      nav.pop();
      return;
    }
    final l = context.l10n;
    final name = a.displayName ?? a.username ?? l.accAccountNoName;
    if (a.expired) {
      nav.pop();
      await openAddAccount(s, account: a);
      return;
    }
    setState(() => _busy = true);
    final r = await s.switchAccount(a.userId);
    if (!mounted) {
      if (r == SwitchResult.switched) _announce(l.accSwitchedTo(name));
      return;
    }
    setState(() => _busy = false);
    switch (r) {
      case SwitchResult.switched:
        _announce(l.accSwitchedTo(name));
      case SwitchResult.needsLogin:
        nav.pop();
        await openAddAccount(s, account: a);
      case SwitchResult.busy:
        BuToast.show(context, l.accBusy, kind: BuToastKind.warning);
      case SwitchResult.same:
        nav.pop();
    }
  }

  void _announce(String text) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    final view = View.maybeOf(ctx);
    if (view == null) return;
    SemanticsService.sendAnnouncement(view, text, Directionality.of(ctx));
  }

  Future<void> _add() async {
    if (_busy) return;
    Navigator.of(context).pop();
    await openAddAccount(s);
  }

  Future<void> _remove(StoredAccount a) async {
    final l = context.l10n;
    final name = a.displayName ?? a.username ?? l.accAccountNoName;
    final nav = Navigator.of(context);
    final ok = await BuConfirmSheet.show(
      context,
      title: l.accRemoveTitle,
      message: l.accRemoveBody(name),
      confirmLabel: l.accRemoveConfirm,
      cancelLabel: l.commonCancel,
      destructive: true,
      icon: BuIcons.logOut,
    );
    if (!ok || !mounted) return;
    final wasActive = a.userId == s.userId;
    if (wasActive) nav.pop(); // etkin hesap kaldırılınca oturum değişir/kapanır: sayfa kapanır
    await s.removeAccount(a.userId);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: s.accounts,
      builder: (context, _) {
        final list = s.accounts.accounts;
        final full = s.accounts.isFull;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final a in list)
              _AccountRow(
                key: ValueKey('account-row-${a.userId}'),
                account: a,
                active: a.userId == s.userId,
                busy: _busy,
                onTap: () => _tap(a),
                onRemove: () => _remove(a),
              ),
            Semantics(
              button: true,
              enabled: !full,
              child: InkWell(
                key: const ValueKey('account-add'),
                onTap: full ? null : _add,
                borderRadius: BorderRadius.circular(BuRadius.md),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: full ? t.bd : t.ink.withValues(alpha: .6))),
                        child: Icon(BuIcons.plus, size: 22, color: full ? t.mut : t.ink),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(l.accAdd, style: tx.bodyLarge!.copyWith(color: full ? t.mut : t.ink, fontWeight: BuType.emphasisWeight)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            if (full)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(l.accLimit, key: const ValueKey('account-limit'), style: tx.bodySmall!.copyWith(color: t.mut, height: 1.4)),
              ),
            const SizedBox(height: 12),
            Text(l.accPushNote, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.4)),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    super.key,
    required this.account,
    required this.active,
    required this.busy,
    required this.onTap,
    required this.onRemove,
  });

  final StoredAccount account;
  final bool active;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final name = account.displayName ?? account.username ?? l.accAccountNoName;
    final sub = account.expired
        ? l.accExpired
        : (account.username != null ? '@${account.username}' : account.emailMasked);
    final label = [name, if (sub != null) sub, if (active) l.accActive].join(', ');
    return Row(children: [
        Expanded(
          child: Semantics(
            button: true,
            selected: active,
            label: label,
            excludeSemantics: true,
            onTap: onTap,
            child: InkWell(
            onTap: busy ? null : onTap,
            borderRadius: BorderRadius.circular(BuRadius.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Opacity(opacity: account.expired ? .55 : 1, child: BuAvatar(name: name, url: account.avatarUrl, size: 52)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: BuType.emphasisWeight)),
                        if (sub != null)
                          Text(sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tx.bodySmall!.copyWith(color: account.expired ? t.warn : t.mut)),
                      ],
                    ),
                  ),
                  if (active)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
                      child: Icon(BuIcons.check, key: ValueKey('account-active-${account.userId}'), size: 20, color: t.ink),
                    ),
                ]),
              ),
            ),
          ),
          ),
        ),
        PopupMenuButton<int>(
          key: ValueKey('account-more-${account.userId}'),
          tooltip: l.accOptions,
          color: t.sf,
          constraints: const BoxConstraints(minWidth: 200),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.md), side: BorderSide(color: t.bd)),
          icon: Icon(BuIcons.ellipsis, size: 22, color: t.mut),
          style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
          onSelected: (_) => onRemove(),
          itemBuilder: (_) => [
            PopupMenuItem<int>(
              key: ValueKey('account-remove-${account.userId}'),
              value: 1,
              height: 48,
              child: Text(l.accRemove, style: tx.bodyMedium!.copyWith(color: t.danger, fontWeight: BuType.emphasisWeight)),
            ),
          ],
        ),
    ]);
  }
}

import 'package:flutter/material.dart';

import '../../core/contacts/contacts_service.dart';
import '../../core/locale_controller.dart';
import '../../core/permissions/ensure_permission.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../profile/user_profile_page.dart';
import 'chat_detail_page.dart';
import 'chat_new_parts.dart';

/// "Rehberden kişi bul" giriş kartı (yeni sohbet ekranı ve ayarlar).
class ContactsEntryRow extends StatelessWidget {
  const ContactsEntryRow({super.key, required this.session, this.padding = EdgeInsets.zero});

  final Session session;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tint = t.tint(1);
    return Padding(
      padding: padding,
      child: NcActionCard(
        cardKey: const ValueKey('contacts-entry'),
        tile: NcTile(icon: LucideIcons.contact, bg: tint.bg, fg: tint.fg),
        title: context.l10n.chatMiscContactsFind,
        subtitle: context.l10n.chatMiscContactsSubtitle,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContactsMatchPage(session: session))),
      ),
    );
  }
}

enum _Phase { loading, needPermission, ready, error }

/// Telefon rehberindeki Bingöl Üniversitesi kişilerini bulur; yalnız e-posta özetleri (SHA-256) sunucuya gider.
/// Telefon numarası gösterilmez ve davet/SMS yoktur.
class ContactsMatchPage extends StatefulWidget {
  const ContactsMatchPage({super.key, required this.session, this.provider, this.permissions});

  final Session session;

  /// Rehber kaynağı (testte sahte).
  final ContactsProvider? provider;
  final PermissionService? permissions;

  @override
  State<ContactsMatchPage> createState() => _ContactsMatchPageState();
}

class _ContactsMatchPageState extends State<ContactsMatchPage> {
  final _search = TextEditingController();
  _Phase _phase = _Phase.loading;
  Object? _error;
  List<ContactMatch> _all = [];
  bool _truncated = false;
  String _q = '';
  int? _opening;
  String? _openError;

  ContactsProvider get _provider => widget.provider ?? DeviceContactsProvider();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });
    final ok = await ensurePermission(
      context,
      AppPermission.contacts,
      service: widget.permissions,
      rationale: context.l10n.chatMiscContactsRationale,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _phase = _Phase.needPermission);
      return;
    }
    try {
      final matcher = ContactsMatcher(widget.session.api, ownEmail: widget.session.email);
      final emails = matcher.campusEmails(await _provider.readEmails());
      final res = emails.isEmpty ? ContactsMatchResult([], candidates: 0, truncated: false) : await matcher.match(emails);
      if (!mounted) return;
      setState(() {
        _all = res.matches;
        _truncated = res.truncated;
        _phase = _Phase.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _phase = _Phase.error;
      });
    }
  }

  List<ContactMatch> get _visible {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((m) => m.displayName.toLowerCase().contains(q) || m.sub.toLowerCase().contains(q)).toList();
  }

  Future<void> _message(ContactMatch m) async {
    if (_opening != null) return;
    setState(() {
      _opening = m.userId;
      _openError = null;
    });
    try {
      final res = await widget.session.api.post('/conversations', {'userId': m.userId});
      if (!mounted) return;
      final conv = Map<String, dynamic>.from(res as Map);
      setState(() => _opening = null);
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailPage(session: widget.session, conversation: conv)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _opening = null;
        _openError = errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          NcHeader(title: context.l10n.chatMiscContactsFind, onBack: () => Navigator.pop(context)),
          Expanded(child: _body(t)),
        ],
      ),
    );
  }

  Widget _body(BuTokens t) {
    final l = context.l10n;
    switch (_phase) {
      case _Phase.loading:
        return _scroll([_searchField(t, enabled: false), const SizedBox(height: 12), _skeleton()]);
      case _Phase.error:
        return _scroll([
          NcCard(
            radius: 24,
            child: Row(children: [
              NcTile(icon: LucideIcons.refreshCcw, bg: t.soft, fg: t.pr, size: 44),
              const SizedBox(width: 12),
              Expanded(child: Text(l.p06LoadFailedTitle, style: Theme.of(context).textTheme.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              BuButton(label: l.chatMiscRetry, icon: LucideIcons.refreshCw, kind: BuButtonKind.soft, compact: true, onPressed: _load),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(errorText(_error!), style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.mut)),
          ],
        ]);
      case _Phase.needPermission:
        return _scroll([
          NcStateCard(
            icon: LucideIcons.userSearch,
            title: l.chatMiscContactsPermTitle,
            text: l.chatMiscContactsPermText,
            children: [
              const SizedBox(height: 20),
              NcNote(icon: LucideIcons.lock, text: l.p23PrivacyShort),
              const SizedBox(height: 16),
              BuButton(label: l.chatMiscContactsPermAction, icon: LucideIcons.userCheck, onPressed: _load),
              const SizedBox(height: 10),
              BuButton(label: l.chatMiscOpenSettings, icon: LucideIcons.settings, kind: BuButtonKind.outline, onPressed: () => (widget.permissions ?? PermissionService.instance).openSettings()),
            ],
          ),
        ]);
      case _Phase.ready:
        break;
    }
    final list = _visible;
    final searching = _q.trim().isNotEmpty;
    return _scroll([
      if (_all.isNotEmpty) ...[
        NcCard(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(LucideIcons.users, size: 20, color: t.pr),
              const SizedBox(width: 10),
              Expanded(child: Text(l.chatMiscContactsSubtitle, style: Theme.of(context).textTheme.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 14),
            _searchField(t),
          ]),
        ),
        const SizedBox(height: 12),
      ],
      if (_truncated) ...[
        NcNote(icon: LucideIcons.info, warn: true, text: l.chatMiscContactsTruncated),
        const SizedBox(height: 12),
      ],
      if (_openError != null) ...[
        NcNote(icon: LucideIcons.circleAlert, text: _openError!),
        const SizedBox(height: 12),
      ],
      if (_all.isEmpty)
        NcStateCard(icon: LucideIcons.userSearch, title: l.chatMiscContactsNoneTitle, text: l.chatMiscContactsNoneText)
      else if (list.isEmpty && searching)
        NcStateCard(icon: LucideIcons.userSearch, title: l.chatMiscContactsNoSearchMatch)
      else ...[
        NcLabel(trUpper(l.chatMiscContactsCount(list.length.toString()))),
        for (final m in list) ...[_row(t, m), const SizedBox(height: 12)],
      ],
      const SizedBox(height: 4),
      _PrivacyNote(),
    ]);
  }

  Widget _scroll(List<Widget> children) => ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + MediaQuery.paddingOf(context).bottom),
        children: children,
      );

  Widget _searchField(BuTokens t, {bool enabled = true}) {
    final tx = Theme.of(context).textTheme;
    return TextField(
      controller: _search,
      enabled: enabled,
      onChanged: (v) => setState(() => _q = v),
      cursorColor: t.pr,
      style: tx.bodyLarge!.copyWith(color: t.ink),
      decoration: InputDecoration(
        hintText: context.l10n.chatMiscContactsSearchHint,
        hintStyle: tx.bodyLarge!.copyWith(color: t.mut),
        prefixIcon: Icon(LucideIcons.search, size: 18, color: t.mut),
        suffixIcon: _q.isEmpty
            ? null
            : IconButton(
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                onPressed: () {
                  _search.clear();
                  setState(() => _q = '');
                },
                icon: Icon(LucideIcons.x, size: 16, color: t.mut)),
        isDense: true,
        filled: true,
        fillColor: t.sf2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: t.pr, width: 2)),
      ),
    );
  }

  Widget _skeleton() => NcCard(
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ExcludeSemantics(
          child: BuSkeletonScope(
            child: Column(children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    const BuSkeleton.circle(48),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [BuSkeleton.line(width: 120 + i * 18.0, height: 14), const SizedBox(height: 8), BuSkeleton.line(width: 190 - i * 24.0, height: 12)])),
                    const SizedBox(width: 12),
                    const BuSkeleton(width: 56, height: 32, radius: 16),
                  ]),
                ),
            ]),
          ),
        ),
      );

  Widget _row(BuTokens t, ContactMatch m) {
    return NcPersonRow(
      name: m.displayName,
      sub: m.sub,
      avatarUrl: m.avatarUrl,
      onAvatarTap: () => openUserProfile(context, widget.session, userId: m.userId, name: m.displayName, avatarUrl: m.avatarUrl),
      trailing: NcPillButton(label: context.l10n.chatMiscMessage, soft: false, busy: _opening == m.userId, onTap: () => _message(m)),
    );
  }
}

/// Gizlilik notu: kilit simgesi + "rehber sunucuya gönderilmez; yalnızca e-posta özetleri eşleştirilir".
class _PrivacyNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: t.sf, shape: BoxShape.circle), child: Icon(LucideIcons.lock, size: 16, color: t.mut)),
        const SizedBox(width: 12),
        Expanded(child: Text(context.l10n.chatMiscContactsPrivacy, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.mut, height: 1.4))),
      ]),
    );
  }
}

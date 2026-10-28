import 'package:flutter/material.dart';

import '../../core/contacts/contacts_service.dart';
import '../../core/locale_controller.dart';
import '../../core/permissions/ensure_permission.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../profile/user_profile_page.dart';
import 'chat_detail_page.dart';
import 'sohbety_widgets.dart';

/// "Rehberden kişi bul" giriş satırı (yeni sohbet ekranı ve ayarlar).
class ContactsEntryRow extends StatelessWidget {
  const ContactsEntryRow(
      {super.key,
      required this.session,
      this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 0)});

  final Session session;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: padding,
      child: SohbetyCard(children: [
        SohbetyRow(
          key: const ValueKey('contacts-entry'),
          minHeight: 64,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => ContactsMatchPage(session: session))),
          child: Row(children: [
            const SohbetyTile(icon: LucideIcons.contact, size: 40),
            const SizedBox(width: 12),
            Expanded(
                child: SohbetyTexts(
                    title: context.l10n.chatMiscContactsFind,
                    sub: context.l10n.chatMiscContactsSubtitle)),
            Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut),
          ]),
        ),
      ]),
    );
  }
}

enum _Phase { loading, needPermission, ready, error }

/// Telefon rehberindeki Bingöl Üniversitesi kişilerini bulur; yalnız e-posta özetleri (SHA-256) sunucuya gider.
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
    return _all
        .where((m) => m.displayName.toLowerCase().contains(q) || m.sub.toLowerCase().contains(q))
        .toList();
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
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => ChatDetailPage(session: widget.session, conversation: conv)));
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
          SohbetyHeader(
            title: context.l10n.chatMiscContactsFind,
            onBack: () => Navigator.pop(context),
          ),
          Expanded(child: _body(t)),
        ],
      ),
    );
  }

  Widget _body(BuTokens t) {
    switch (_phase) {
      case _Phase.loading:
        return const LoadingView();
      case _Phase.error:
        return ErrorView(error: _error!, onRetry: _load);
      case _Phase.needPermission:
        return Column(children: [
          Expanded(
            child: _StateCard(
              icon: LucideIcons.contact,
              title: context.l10n.chatMiscContactsPermTitle,
              text: context.l10n.chatMiscContactsRationale,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 32 + MediaQuery.paddingOf(context).bottom - 16),
            child: SohbetyButton(
                label: context.l10n.chatMiscContactsPermAction, onPressed: _load),
          ),
        ]);
      case _Phase.ready:
        break;
    }
    if (_all.isEmpty) {
      return Column(children: [
        Expanded(
          child: _StateCard(
            icon: LucideIcons.userSearch,
            title: context.l10n.chatMiscContactsNoneTitle,
            text: context.l10n.chatMiscContactsNoneText,
          ),
        ),
        _PrivacyNote(color: t.mut),
      ]);
    }
    final list = _visible;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: SohbetyField(
            hint: context.l10n.chatMiscContactsSearchHint,
            controller: _search,
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        if (_truncated)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Text(context.l10n.chatMiscContactsTruncated,
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: t.mut)),
          ),
        if (_openError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Text(_openError!,
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: t.danger)),
          ),
        Expanded(
          child: list.isEmpty
              ? EmptyView(icon: LucideIcons.userX, text: context.l10n.chatMiscContactsNoSearchMatch)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  children: [
                    SohbetyLabel(sohbetyUpper(
                        context, context.l10n.chatMiscContactsCount(list.length.toString()))),
                    SohbetyCard(children: [for (final m in list) _row(t, m)]),
                  ],
                ),
        ),
        _PrivacyNote(color: t.mut),
      ],
    );
  }

  Widget _row(BuTokens t, ContactMatch m) {
    return SohbetyRow(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => openUserProfile(context, widget.session,
                  userId: m.userId, name: m.displayName, avatarUrl: m.avatarUrl),
              child: Row(children: [
                SohbetyAvatar(name: m.displayName, url: m.avatarUrl, size: 48),
                const SizedBox(width: 12),
                Expanded(child: SohbetyTexts(title: m.displayName, sub: m.sub)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          _MessageButton(
            label: context.l10n.chatMiscMessage,
            busy: _opening == m.userId,
            onTap: () => _message(m),
          ),
        ],
      ),
    );
  }
}

/// Satır sonu "Mesaj" düğmesi: 44 px, yumuşak kırmızı zemin, kırmızı yazı.
class _MessageButton extends StatelessWidget {
  const _MessageButton({required this.label, required this.busy, required this.onTap});

  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: t.soft,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: busy ? null : onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: t.onSoft))
                : Text(label,
                    maxLines: 1,
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: t.onSoft)),
          ),
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 16 + MediaQuery.of(context).padding.bottom),
      child: Text(context.l10n.chatMiscContactsPrivacy,
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.4, color: color)),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
              child: Icon(icon, size: 38, color: t.onSoft),
            ),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: t.ink)),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Inter', fontSize: 15, height: 1.5, color: t.mut)),
          ],
        ),
      ),
    );
  }
}

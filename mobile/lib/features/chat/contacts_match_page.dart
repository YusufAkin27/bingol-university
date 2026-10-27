import 'package:flutter/material.dart';

import '../../core/contacts/contacts_service.dart';
import '../../core/permissions/ensure_permission.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'chat_detail_page.dart';

/// "Rehberden kişi bul" giriş satırı (yeni sohbet ekranı ve ayarlar).
class ContactsEntryRow extends StatelessWidget {
  const ContactsEntryRow({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: BuCard(
        padding: EdgeInsets.zero,
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => ContactsMatchPage(session: session))),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 14),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                child: Icon(LucideIcons.contact, size: 18, color: t.onSoft),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Rehberden kişi bul',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.bodyStrong.copyWith(color: t.ink)),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: t.mut),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
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
      rationale: 'Rehberinizdeki Bingöl Üniversitesi kişilerini bulabilmemiz için rehbere erişmemiz gerekir. '
          'Rehberiniz sunucuya gönderilmez; yalnızca e-posta özetleri eşleştirilir.',
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
          BuHeader(
            title: 'Rehberden kişi bul',
            subtitle: 'Bingöl Üniversitesi kişileri',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(child: _body(t)),
          _PrivacyNote(color: t.mut),
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
        return _StateCard(
          icon: LucideIcons.contact,
          title: 'Rehber izni gerekli',
          text: 'Rehberinizdeki kampüs kişilerini bulabilmemiz için rehbere erişim izni vermeniz gerekir.',
          action: 'İzin ver',
          onAction: _load,
        );
      case _Phase.ready:
        break;
    }
    if (_all.isEmpty) {
      return const _StateCard(
        icon: LucideIcons.userSearch,
        title: 'Eşleşen kişi yok',
        text: 'Rehberindeki kişilerden Bingöl Üniversitesi e-postasıyla uygulamayı kullanan kimse bulunamadı. '
            'Arkadaşların katıldıkça burada görünür.',
      );
    }
    final list = _visible;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: BuSearchField(
            hint: 'Kişilerde ara',
            controller: _search,
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        if (_truncated)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Text('Saatlik istek sınırına ulaşıldı; kalan kişiler daha sonra eşleştirilecek.',
                style: BuType.caption.copyWith(color: t.mut)),
          ),
        if (_openError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Text(_openError!, style: BuType.caption.copyWith(color: t.danger)),
          ),
        Expanded(
          child: list.isEmpty
              ? const EmptyView(icon: LucideIcons.userX, text: 'Aramanla eşleşen kişi yok.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  itemCount: list.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 2),
                        child: Text('${list.length} KİŞİ',
                            style: BuType.label.copyWith(letterSpacing: .5, color: t.mut)),
                      );
                    }
                    return _row(t, list[i - 1]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _row(BuTokens t, ContactMatch m) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          BuAvatar(name: m.displayName, url: m.avatarUrl, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.displayName,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.bodyStrong.copyWith(color: t.ink)),
                if (m.sub.isNotEmpty)
                  Text(m.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(color: t.mut)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          BuButton(
            label: 'Mesaj',
            icon: LucideIcons.messageCircle,
            compact: true,
            busy: _opening == m.userId,
            onPressed: () => _message(m),
          ),
        ],
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
      padding: EdgeInsets.fromLTRB(24, 8, 24, 10 + MediaQuery.of(context).padding.bottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.lock, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Rehberin sunucuya gönderilmez; yalnızca e-posta özetleri eşleştirilir.',
                style: BuType.caption.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.icon, required this.title, required this.text, this.action, this.onAction});

  final IconData icon;
  final String title;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: t.onSoft),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: BuType.heading.copyWith(color: t.ink)),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: BuType.body.copyWith(color: t.mut)),
            if (action != null) ...[
              const SizedBox(height: 20),
              BuButton(label: action!, compact: true, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

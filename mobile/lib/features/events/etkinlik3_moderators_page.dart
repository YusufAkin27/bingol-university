import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../clubs/clubs_widgets.dart' show ClubOutlineButton, ClubPageHeader;
import '../../l10n/app_localizations.dart';

/// Moderatöre verilebilen yetkiler (sunucudaki `EventModerator.Perm` adlarıyla birebir). Sahip-özel işlemler
/// (kapatma, iptal, yoklamayı açıp kapatma, moderatör yönetimi) burada YOKTUR.
const kEventPerms = <String>[
  'TAKE_ATTENDANCE',
  'MANAGE_REQUESTS',
  'VIEW_ATTENDEES',
  'SEND_ANNOUNCEMENT',
  'EDIT_INFO',
  'EDIT_SCHEDULE',
];

String eventPermTitle(AppLocalizations l, String p) => switch (p) {
      'TAKE_ATTENDANCE' => l.evtPermTakeAttendance,
      'MANAGE_REQUESTS' => l.evtPermManageRequests,
      'VIEW_ATTENDEES' => l.evtPermViewAttendees,
      'SEND_ANNOUNCEMENT' => l.evtPermSendAnnouncement,
      'EDIT_INFO' => l.evtPermEditInfo,
      _ => l.evtPermEditSchedule,
    };

String eventPermSub(AppLocalizations l, String p) => switch (p) {
      'TAKE_ATTENDANCE' => l.evtPermTakeAttendanceSub,
      'MANAGE_REQUESTS' => l.evtPermManageRequestsSub,
      'VIEW_ATTENDEES' => l.evtPermViewAttendeesSub,
      'SEND_ANNOUNCEMENT' => l.evtPermSendAnnouncementSub,
      'EDIT_INFO' => l.evtPermEditInfoSub,
      _ => l.evtPermEditScheduleSub,
    };

/// Etkinlik sahibi: moderatör ekle/çıkar ve her kişinin yetkilerini tek tek aç/kapat.
class Etkinlik3ModeratorsPage extends StatefulWidget {
  const Etkinlik3ModeratorsPage(
      {super.key, required this.session, required this.event});

  final Session session;
  final Map<String, dynamic> event;

  @override
  State<Etkinlik3ModeratorsPage> createState() =>
      _Etkinlik3ModeratorsPageState();
}

class _Etkinlik3ModeratorsPageState extends State<Etkinlik3ModeratorsPage> {
  List<Map<String, dynamic>>? _mods;
  Object? _error;
  final _busy = <int>{};

  int get _id => (widget.event['id'] as num).toInt();
  int? get _cid => (widget.event['communityId'] as num?)?.toInt();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.session.api.get('/events/$_id/moderators');
      if (!mounted) return;
      setState(() {
        _mods = [
          for (final m in (r as List).whereType<Map>())
            Map<String, dynamic>.from(m)
        ];
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _save(Map<String, dynamic> m, Set<String> perms) async {
    final uid = (m['userId'] as num).toInt();
    if (_busy.contains(uid)) return;
    final before = List<String>.from(m['permissions'] as List? ?? const []);
    setState(() {
      _busy.add(uid);
      m['permissions'] = perms.toList();
    });
    try {
      await widget.session.api
          .put('/events/$_id/moderators/$uid', {'permissions': perms.toList()});
    } catch (e) {
      if (mounted) {
        setState(() => m['permissions'] = before);
        BuToast.show(context, errorText(e), kind: BuToastKind.error);
      }
    } finally {
      if (mounted) setState(() => _busy.remove(uid));
    }
  }

  Future<void> _remove(Map<String, dynamic> m) async {
    final uid = (m['userId'] as num).toInt();
    try {
      await widget.session.api.delete('/events/$_id/moderators/$uid');
      if (mounted)
        setState(() => _mods!.removeWhere((x) => x['userId'] == m['userId']));
    } catch (e) {
      if (mounted) BuToast.show(context, errorText(e), kind: BuToastKind.error);
    }
  }

  Future<void> _add() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bu.sf,
      builder: (_) => _MemberPicker(
          session: widget.session,
          communityId: _cid,
          exclude: {
            for (final m in _mods ?? const []) (m['userId'] as num).toInt()
          }),
    );
    if (picked == null || !mounted) return;
    final uid = (picked['userId'] as num).toInt();
    try {
      final r = await widget.session.api
          .put('/events/$_id/moderators/$uid', {'permissions': <String>[]});
      if (!mounted) return;
      setState(() => _mods = [...?_mods, Map<String, dynamic>.from(r as Map)]);
    } catch (e) {
      if (mounted) BuToast.show(context, errorText(e), kind: BuToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final mods = _mods;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        ClubPageHeader(title: l.evtModTitle),
        Expanded(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(l.evtModSub, style: tx.bodyMedium!.copyWith(color: t.mut)),
                const SizedBox(height: 16),
                ClubOutlineButton(
                    key: const ValueKey('et3-mod-add'),
                    label: l.evtModAdd,
                    onPressed: _add),
                const SizedBox(height: 16),
                if (_error != null)
                  Text(errorText(_error!),
                      style: tx.bodyLarge!.copyWith(color: t.ink))
                else if (mods == null)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator()))
                else if (mods.isEmpty)
                  Text(l.evtModEmpty,
                      key: const ValueKey('et3-mod-empty'),
                      style: tx.bodyLarge!.copyWith(color: t.mut))
                else
                  for (final m in mods) _row(context, m),
                const SizedBox(height: 20),
                Text(l.evtModOwnerNote,
                    style: tx.bodySmall!.copyWith(color: t.mut, height: 1.4)),
              ]),
        ),
      ]),
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> m) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final perms = Set<String>.from(m['permissions'] as List? ?? const []);
    final uid = (m['userId'] as num).toInt();
    return Padding(
      key: ValueKey('et3-mod-$uid'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: t.sf2,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                  child: Text('${m['displayName'] ?? ''}',
                      style: tx.titleSmall!.copyWith(color: t.ink))),
              TextButton(
                key: ValueKey('et3-mod-remove-$uid'),
                style: TextButton.styleFrom(
                    foregroundColor: t.danger, minimumSize: const Size(48, 48)),
                onPressed: () => _remove(m),
                child: Text(l.evtModRemove),
              ),
            ]),
            for (final p in kEventPerms)
              SwitchListTile(
                key: ValueKey('et3-perm-$uid-$p'),
                contentPadding: EdgeInsets.zero,
                title: Text(eventPermTitle(l, p),
                    style: tx.bodyLarge!.copyWith(color: t.ink)),
                subtitle: Text(eventPermSub(l, p),
                    style: tx.bodySmall!.copyWith(color: t.mut)),
                value: perms.contains(p),
                onChanged: _busy.contains(uid)
                    ? null
                    : (v) {
                        final next = Set<String>.from(perms);
                        v ? next.add(p) : next.remove(p);
                        _save(m, next);
                      },
              ),
          ]),
        ),
      ),
    );
  }
}

/// Kulüp üyeleri arasında arama; seçilen üye `Navigator.pop` ile döner.
class _MemberPicker extends StatefulWidget {
  const _MemberPicker(
      {required this.session,
      required this.communityId,
      required this.exclude});

  final Session session;
  final int? communityId;
  final Set<int> exclude;

  @override
  State<_MemberPicker> createState() => _MemberPickerState();
}

class _MemberPickerState extends State<_MemberPicker> {
  final _q = TextEditingController();
  final _items = <Map<String, dynamic>>[];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _q.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cid = widget.communityId;
    if (cid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      int? cursor;
      for (var page = 0; page < 10; page++) {
        final r = await widget.session.api.get(
                '/communities/$cid/members?size=50${cursor == null ? '' : '&cursor=$cursor'}')
            as Map;
        _items.addAll((r['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)));
        cursor = (r['nextCursor'] as num?)?.toInt();
        if (cursor == null) break;
      }
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final q = _q.text.trim().toLowerCase();
    final shown = [
      for (final m in _items)
        if (!widget.exclude.contains((m['userId'] as num?)?.toInt()) &&
            m['role'] != 'OWNER' &&
            (q.isEmpty ||
                '${m['displayName'] ?? ''}'.toLowerCase().contains(q)))
          m,
    ];
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .7,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                  key: const ValueKey('et3-mod-search'),
                  controller: _q,
                  decoration: InputDecoration(hintText: l.evtModSearch)),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(errorText(_error!),
                              style: tx.bodyLarge!.copyWith(color: t.ink)))
                      : shown.isEmpty
                          ? Center(
                              child: Text(l.evtModNoMembers,
                                  style: tx.bodyLarge!.copyWith(color: t.mut)))
                          : ListView(children: [
                              for (final m in shown)
                                ListTile(
                                  key: ValueKey('et3-pick-${m['userId']}'),
                                  title: Text('${m['displayName'] ?? ''}',
                                      style:
                                          tx.bodyLarge!.copyWith(color: t.ink)),
                                  onTap: () => Navigator.pop(context, m),
                                ),
                            ]),
            ),
          ]),
        ),
      ),
    );
  }
}

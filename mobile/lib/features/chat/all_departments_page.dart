import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'department_chat_entry.dart';

/// "Tüm bölümler": fakülteye göre gruplanmış bölüm kanalları, arama, üye sayısı ve katıl/ayrıl düğmesi. Kendi bölümün
/// üstte "Senin bölümün" etiketiyle. Katılma/ayrılma iyimser güncellenir, hatada geri alınır; ayrılırken onay istenmez.
class AllDepartmentsPage extends StatefulWidget {
  const AllDepartmentsPage({super.key, required this.session});

  final Session session;

  @override
  State<AllDepartmentsPage> createState() => _AllDepartmentsPageState();
}

/// Aksan/harf-boyutu duyarsız arama anahtarı (tr/en; Arapça aynen).
String foldDeptSearch(String s) {
  const map = {
    'ı': 'i', 'İ': 'i', 'ş': 's', 'Ş': 's', 'ğ': 'g', 'Ğ': 'g', 'ü': 'u', 'Ü': 'u', 'ö': 'o', 'Ö': 'o', 'ç': 'c', 'Ç': 'c',
  };
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    b.write(map[ch] ?? ch.toLowerCase());
  }
  return b.toString().replaceAll('̇', '').trim();
}

class _AllDepartmentsPageState extends State<AllDepartmentsPage> {
  final _items = <Map<String, dynamic>>[];
  final _search = TextEditingController();
  final _busy = <String>{};
  bool _loading = true;
  Object? _error;
  String _query = '';

  DepartmentChannelsApi get _api => DepartmentChannelsApi(widget.session);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_items.isEmpty) setState(() => _loading = true);
    try {
      final all = await _api.all();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(all);
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _items.isEmpty ? e : null;
        _loading = false;
      });
    }
  }

  int _indexOf(String key) => _items.indexWhere((e) => e['key'] == key);

  Future<void> _toggle(Map<String, dynamic> c) async {
    final key = c['key'] as String;
    if (_busy.contains(key)) return;
    final i = _indexOf(key);
    if (i < 0) return;
    final before = _items[i];
    final wasJoined = before['joined'] == true;
    final count = (before['memberCount'] as num?)?.toInt() ?? 0;
    final l = context.l10n;
    final name = deptChannelName(context, before);
    setState(() {
      _busy.add(key);
      _items[i] = {
        ...before,
        'joined': !wasJoined,
        'memberCount': wasJoined ? (count > 0 ? count - 1 : 0) : count + 1,
      };
    });
    try {
      if (wasJoined) {
        await _api.leave(key);
        if (mounted) BuToast.show(context, l.deptChanLeftHint);
      } else {
        final r = await _api.join(key);
        if (!mounted) return;
        final j = _indexOf(key);
        if (j >= 0) {
          setState(() => _items[j] = {..._items[j], ...r, 'joined': true});
        }
        BuToast.show(context, l.deptChanJoinedToast(name), kind: BuToastKind.success);
      }
    } catch (e) {
      if (!mounted) return;
      final j = _indexOf(key);
      if (j >= 0) setState(() => _items[j] = before); // iyimser güncellemeyi geri al
      BuToast.show(context, errorText(e), kind: BuToastKind.error);
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _open(Map<String, dynamic> c) async {
    final cid = (c['conversationId'] as num?)?.toInt();
    if (c['joined'] != true || cid == null) return;
    await openDepartmentChannel(
      context,
      widget.session,
      {'id': cid, 'memberCount': c['memberCount']},
      title: deptChannelName(context, c),
    );
    if (mounted) _load();
  }

  /// Süzülmüş düz liste: ("Senin bölümün" başlığı + kendi bölüm), sonra fakülte başlığı + bölümler.
  List<Object> _rows(BuildContext context) {
    final l = context.l10n;
    final q = foldDeptSearch(_query);
    bool hit(Map<String, dynamic> c) {
      if (q.isEmpty) return true;
      return [c['name'], c['nameEn'], c['nameAr'], c['faculty'], c['facultyEn'], c['facultyAr']]
          .any((v) => v is String && foldDeptSearch(v).contains(q));
    }

    final rows = <Object>[];
    final own = _items.where((c) => c['own'] == true && hit(c)).toList();
    if (own.isNotEmpty) {
      rows.add(l.deptChanYours);
      rows.addAll(own);
    }
    String? faculty;
    for (final c in _items) {
      if (c['own'] == true || !hit(c)) continue;
      final f = deptChannelFaculty(context, c);
      if (f != faculty) {
        faculty = f;
        rows.add(f);
      }
      rows.add(c);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rows = _loading || _error != null ? const <Object>[] : _rows(context);
    final state = _loading
        ? BuViewState.loading
        : _error != null
            ? BuViewState.error
            : BuViewState.ready;
    return BuPageScaffold(
      title: l.deptChanAll,
      state: state,
      error: _error,
      onRetry: _load,
      onRefresh: _load,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: BuSearchField(
              key: const ValueKey('department-channels-search'),
              hint: l.deptChanSearchHint,
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
        if (rows.isEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 320,
              child: BuEmptyState(
                key: const ValueKey('department-channels-empty'),
                icon: BuIcons.searchX,
                title: l.deptChanNoMatchTitle,
                message: l.deptChanNoMatchBody,
                compact: true,
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              if (r is String) return _Header(r);
              final c = r as Map<String, dynamic>;
              return _DeptRow(
                channel: c,
                busy: _busy.contains(c['key']),
                onToggle: () => _toggle(c),
                onOpen: () => _open(c),
              );
            },
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 4),
        child: Text(text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
      ),
    );
  }
}

class _DeptRow extends StatelessWidget {
  const _DeptRow({required this.channel, required this.busy, required this.onToggle, required this.onOpen});

  final Map<String, dynamic> channel;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final joined = channel['joined'] == true;
    final closed = channel['closed'] == true;
    final count = (channel['memberCount'] as num?)?.toInt() ?? 0;
    final name = deptChannelName(context, channel);
    final sub = closed ? l.deptChanClosed : l.deptChanMembers(count);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: joined ? onOpen : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 8, 8),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                  child: Icon(BuIcons.graduationCap, size: 20, color: t.onSoft),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400, height: 1.25)),
                    const SizedBox(height: 2),
                    Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
                  ]),
                ),
                const SizedBox(width: 8),
                BuButton(
                  key: ValueKey('dept-toggle-${channel['key']}'),
                  label: joined ? l.deptChanLeave : l.deptChanJoin,
                  kind: joined ? BuButtonKind.outline : BuButtonKind.primary,
                  compact: true,
                  busy: busy,
                  onPressed: closed && !joined ? null : onToggle,
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

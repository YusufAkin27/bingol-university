import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'chat_detail_page.dart';
import 'department_chat_entry.dart';

class DepartmentChatsPage extends StatefulWidget {
  const DepartmentChatsPage({super.key, required this.session});

  final Session session;

  @override
  State<DepartmentChatsPage> createState() => _DepartmentChatsPageState();
}

class _DepartmentChatsPageState extends State<DepartmentChatsPage> {
  List<Map<String, dynamic>> _rooms = [];
  final _search = TextEditingController();
  final _busy = <String>{};
  bool _loading = true;
  Object? _error;

  DepartmentChatApi get _api => DepartmentChatApi(widget.session);

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
    try {
      final rooms = await _api.rooms();
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _open(Map<String, dynamic> room) async {
    final name = room['departmentName'] as String;
    if (_busy.contains(name)) return;
    setState(() => _busy.add(name));
    try {
      final joined = room['joined'] == true ? room : await _api.join(name);
      if (!mounted) return;
      final id = (joined['conversationId'] as num?)?.toInt();
      widget.session.badges.conversationsDirty.value++;
      await _load();
      if (!mounted || id == null) return;
      await Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'chat_detail'),
            builder: (_) =>
                ChatDetailPage(session: widget.session, conversation: {
              'id': id,
              'type': 'DEPARTMENT',
              'title': joined['departmentName'] ?? name,
              'memberCount': joined['memberCount'],
            }),
          ));
      if (mounted) await _load();
    } catch (e) {
      if (mounted) BuToast.show(context, errorText(e), kind: BuToastKind.error);
    } finally {
      if (mounted) setState(() => _busy.remove(name));
    }
  }

  Future<void> _leave(Map<String, dynamic> room) async {
    final name = room['departmentName'] as String;
    final id = (room['conversationId'] as num?)?.toInt();
    if (id == null || _busy.contains(name)) return;
    setState(() => _busy.add(name));
    try {
      await _api.leave(id);
      widget.session.badges.conversationsDirty.value++;
      if (mounted) await _load();
    } catch (e) {
      if (mounted) BuToast.show(context, errorText(e), kind: BuToastKind.error);
    } finally {
      if (mounted) setState(() => _busy.remove(name));
    }
  }

  String _fold(String s) => s
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final query = _fold(_search.text.trim());
    final rooms = _rooms
        .where((r) => _fold('${r['departmentName']}').contains(query))
        .toList();
    return Scaffold(
      backgroundColor: context.bu.bg,
      body: SafeArea(
          child: Column(children: [
        BuHeader(title: l.deptChatBrowse, onBack: () => Navigator.pop(context)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(l.deptChatBrowseSubtitle,
              style: TextStyle(color: context.bu.mut)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: l.deptChatSearch,
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(l.authDepartmentsLoadFailed),
                        TextButton(
                            onPressed: _load, child: Text(l.commonRetry)),
                      ]))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: rooms.isEmpty ? 1 : rooms.length,
                          itemBuilder: (context, i) {
                            if (rooms.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(l.chatMiscEmptyNoMatch),
                              );
                            }
                            final room = rooms[i];
                            final name = room['departmentName'] as String;
                            final closed = room['closed'] == true;
                            final joined = room['joined'] == true;
                            final busy = _busy.contains(name);
                            return ListTile(
                              key: ValueKey('department-$name'),
                              leading: const Icon(BuIcons.graduationCap),
                              title: Text(name),
                              subtitle: closed ? Text(l.chatInfoClosed) : null,
                              onTap: closed || busy ? null : () => _open(room),
                              trailing: busy
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : TextButton(
                                      onPressed: closed
                                          ? null
                                          : () => joined
                                              ? _leave(room)
                                              : _open(room),
                                      child: Text(joined
                                          ? l.chatInfoLeave
                                          : l.clubJoin),
                                    ),
                            );
                          },
                        ),
                      )),
      ])),
    );
  }
}

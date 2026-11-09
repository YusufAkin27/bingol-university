import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/requests_entry_row.dart';
import 'chat_detail_page.dart';

/// Bölüm sohbet grubu uçları: `GET /department-chat`, `POST /department-chat/join`, `DELETE /department-chat/membership`.
/// Yanıt: `{available, departmentName, closed, joined, memberCount, conversationId}`.
class DepartmentChatApi {
  DepartmentChatApi(this.session);

  final Session session;

  Future<Map<String, dynamic>> state() async {
    final r = await session.api.get('/department-chat', force: true);
    return r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> join([String? department]) async {
    final query = department == null ? '' : '?department=${Uri.encodeComponent(department)}';
    final r = await session.api.post('/department-chat/join$query');
    return r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> rooms() async {
    final r = await session.api.get('/department-chat/rooms', force: true);
    return r is List ? r.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  Future<void> leave(int conversationId) async {
    await session.api.delete('/department-chat/membership?conversationId=$conversationId');
  }
}

/// Sohbet listesinin üstündeki "Bölüm grubuna katıl" satırı. Yalnız profilde bölüm varsa, oda açıksa ve kullanıcı
/// henüz üye değilse çizilir (ayrılanlar ve eski hesaplar yeniden katılabilir). Hata/yükleme sessizdir.
class DepartmentChatEntry extends StatefulWidget {
  const DepartmentChatEntry({super.key, required this.session, this.onJoined});

  final Session session;
  final VoidCallback? onJoined;

  @override
  State<DepartmentChatEntry> createState() => DepartmentChatEntryState();
}

class DepartmentChatEntryState extends State<DepartmentChatEntry> {
  String? _name;
  bool _show = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final r = await DepartmentChatApi(widget.session).state();
      if (!mounted) return;
      final name = (r['departmentName'] as String?)?.trim();
      final show = r['available'] == true && r['closed'] != true && r['joined'] != true && name != null && name.isNotEmpty;
      if (show != _show || name != _name) {
        setState(() {
          _show = show;
          _name = name;
        });
      }
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, sohbet listesini etkilemez.
    }
  }

  Future<void> _join() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await DepartmentChatApi(widget.session).join();
      if (!mounted) return;
      final cid = (r['conversationId'] as num?)?.toInt();
      setState(() {
        _show = false;
        _busy = false;
      });
      widget.onJoined?.call();
      if (cid == null) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'chat_detail'),
          builder: (_) => ChatDetailPage(
            session: widget.session,
            conversation: {
              'id': cid,
              'type': 'DEPARTMENT',
              'title': _name ?? context.l10n.deptChatTag,
              'memberCount': r['memberCount'],
            },
          ),
        ),
      );
      if (mounted) widget.onJoined?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      BuToast.show(context, errorText(e), kind: BuToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_show || _name == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: RequestsEntryRow(
        key: const ValueKey('department-chat-entry'),
        icon: BuIcons.graduationCap,
        label: context.l10n.deptChatJoinRow(_name!),
        onTap: _join,
      ),
    );
  }
}

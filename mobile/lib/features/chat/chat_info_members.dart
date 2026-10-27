import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../core/api.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';

bool isAdminRole(Map<String, dynamic> m) =>
    m['role'] == 'ADMIN' || m['role'] == 'OWNER';

/// Üye satırı: avatar, ad, "Sen" / "Yönetici" etiketi, isteğe bağlı çıkarma düğmesi.
class ChatMemberRow extends StatelessWidget {
  const ChatMemberRow(
      {super.key,
      required this.member,
      required this.selfId,
      this.onRemove,
      this.onTap});

  final Map<String, dynamic> member;
  final int? selfId;
  final VoidCallback? onRemove;

  /// Satıra dokunma (profil); kendi satırında çağıran null verir.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final me = (member['userId'] as num?)?.toInt() == selfId;
    final name = (member['displayName'] as String?) ?? 'Kullanıcı';
    final sub =
        (member['department'] ?? member['faculty'] ?? '').toString().trim();
    return InkWell(
      onTap: me ? null : onTap,
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(children: [
        BuAvatar(name: name, url: member['avatarUrl'] as String?, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BuType.bodyStrong.copyWith(color: t.ink)),
                if (sub.isNotEmpty)
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BuType.caption.copyWith(color: t.mut)),
              ]),
        ),
        if (me) ...[
          const SizedBox(width: 8),
          Text('Sen', style: BuType.label.copyWith(color: t.mut))
        ],
        if (isAdminRole(member)) ...[
          const SizedBox(width: 8),
          const BuBadge('Yönetici', soft: true)
        ],
        if (onRemove != null)
          IconButton(
            tooltip: 'Gruptan çıkar',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: Icon(LucideIcons.userMinus, size: 16, color: t.mut),
          ),
      ]),
    ));
  }
}

/// Tüm üyeler: aramalı tam sayfa.
class ChatMembersPage extends StatefulWidget {
  const ChatMembersPage(
      {super.key, required this.members, required this.selfId, this.onRemove});

  final List<Map<String, dynamic>> members;
  final int? selfId;

  /// Yönetici için çıkarma; true dönerse üye listeden düşer. Null ise düğme yok.
  final Future<bool> Function(Map<String, dynamic> member)? onRemove;

  @override
  State<ChatMembersPage> createState() => _ChatMembersPageState();
}

class _ChatMembersPageState extends State<ChatMembersPage> {
  late final List<Map<String, dynamic>> _all = List.of(widget.members);
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? _all
        : _all
            .where((m) =>
                ((m['displayName'] as String?) ?? '').toLowerCase().contains(q))
            .toList();
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        foregroundColor: t.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Üyeler (${_all.length})',
            style: BuType.heading.copyWith(color: t.ink)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: BuSearchField(
              hint: 'Üye ara', onChanged: (v) => setState(() => _q = v)),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text('Sonuç yok.',
                      style: BuType.body.copyWith(color: t.mut)))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (c, i) {
                    final m = list[i];
                    final removable = widget.onRemove != null &&
                        (m['userId'] as num?)?.toInt() != widget.selfId &&
                        !isAdminRole(m);
                    return ChatMemberRow(
                      member: m,
                      selfId: widget.selfId,
                      onRemove: removable
                          ? () async {
                              if (await widget.onRemove!(m) && mounted) {
                                setState(() => _all.remove(m));
                              }
                            }
                          : null,
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

/// `PUT {path}` ile multipart (`file`) yükleme; [MultipartUploader] yalnız POST yapar.
Future<dynamic> putMultipartImage(
    Session session, String path, PreparedImage image) async {
  Future<dynamic> send(bool retried) async {
    final api = session.api;
    final req = http.MultipartRequest('PUT', Uri.parse('$apiBase$path'));
    req.headers['Accept-Language'] = api.lang;
    req.headers['Accept'] = 'application/json';
    final tok = api.tokens;
    if (tok != null) req.headers['Authorization'] = 'Bearer ${tok.access}';
    req.files.add(http.MultipartFile.fromBytes('file', image.bytes,
        filename: image.fileName, contentType: MediaType.parse(image.mime)));
    http.Response res;
    try {
      res = await http.Response.fromStream(
          await req.send().timeout(const Duration(seconds: 60)));
    } catch (_) {
      throw ApiError(0, 'NETWORK', '');
    }
    if (res.statusCode == 401 && tok != null && !retried) {
      await api.refresh();
      return send(true);
    }
    dynamic json;
    final text = utf8.decode(res.bodyBytes);
    if (text.isNotEmpty) {
      try {
        json = jsonDecode(text);
      } catch (_) {}
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return json;
    if (json is Map && json['code'] is String) {
      throw ApiError(res.statusCode, json['code'] as String,
          (json['message'] as String?) ?? '');
    }
    throw ApiError(res.statusCode, 'HTTP_${res.statusCode}', '');
  }

  return send(false);
}

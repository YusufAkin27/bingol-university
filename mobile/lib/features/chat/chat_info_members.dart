import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'sohbety_widgets.dart';

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
    final name = (member['displayName'] as String?) ?? context.l10n.chatInfoUser;
    final dept =
        (member['department'] ?? member['faculty'] ?? '').toString().trim();
    // Tasarım: "Yönetici · Bölüm" tek alt satır.
    final sub = [
      if (isAdminRole(member)) context.l10n.chatInfoAdmin,
      if (dept.isNotEmpty) dept,
    ].join(' · ');
    return SohbetyRow(
      onTap: me ? null : onTap,
      child: Row(children: [
        SohbetyAvatar(name: name, url: member['avatarUrl'] as String?, size: 48),
        const SizedBox(width: 12),
        Expanded(child: SohbetyTexts(title: name, sub: sub)),
        if (me) ...[
          const SizedBox(width: 8),
          Text(context.l10n.chatInfoYou,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: t.mut))
        ],
        if (onRemove != null)
          IconButton(
            tooltip: context.l10n.chatInfoRemoveFromGroup,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: onRemove,
            icon: Icon(LucideIcons.userMinus, size: 18, color: t.mut),
          ),
      ]),
    );
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
      body: Column(children: [
        SohbetyHeader(
            title: context.l10n.chatInfoMembersCount(_all.length.toString()),
            onBack: () => Navigator.maybePop(context)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: SohbetyField(
              hint: context.l10n.chatInfoSearchMember,
              height: 48,
              onChanged: (v) => setState(() => _q = v)),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text(context.l10n.chatInfoNoResults,
                      style: BuType.body.copyWith(color: t.mut)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    SohbetyCard(children: [
                      for (final m in list)
                        ChatMemberRow(
                          member: m,
                          selfId: widget.selfId,
                          onRemove: widget.onRemove != null &&
                                  (m['userId'] as num?)?.toInt() != widget.selfId &&
                                  !isAdminRole(m)
                              ? () async {
                                  if (await widget.onRemove!(m) && mounted) {
                                    setState(() => _all.remove(m));
                                  }
                                }
                              : null,
                        ),
                    ]),
                  ],
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

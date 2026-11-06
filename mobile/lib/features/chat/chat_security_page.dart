import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../profile/legal_pages.dart';
import 'chat_info_parts.dart';

/// Sohbetin türüne göre güvenlik bilgisi alt metni: birebir, grup, kulüp/etkinlik odası.
enum ChatSecurityKind { direct, group, room }

/// Konuşma türünden ([ConversationView.type]) bilgi türü: DIRECT, CLUB/EVENT, diğeri grup.
ChatSecurityKind chatSecurityKindOf(String type) => switch (type) {
      'DIRECT' => ChatSecurityKind.direct,
      'CLUB' || 'EVENT' => ChatSecurityKind.room,
      _ => ChatSecurityKind.group,
    };

String _noticeText(BuildContext context, ChatSecurityKind kind) {
  final l = context.l10n;
  return switch (kind) {
    ChatSecurityKind.direct => l.chatEncNoticeDirect,
    ChatSecurityKind.group => l.chatEncNoticeGroup,
    ChatSecurityKind.room => l.chatEncNoticeRoom,
  };
}

/// Konuşmanın en üstündeki sistem bildirimi (WhatsApp'taki "mesajların şifreli" kutusunun sade karşılığı):
/// kilit simgesi + tek cümle + dokunulabilir "Daha fazla bilgi". Tüm kart 48 dp üstü dokunma alanıdır.
///
/// DÜRÜSTLÜK: ifade yalnız doğrulanmış korumaları söyler (aktarımda TLS/WSS, sunucuda AES-256-GCM). Uygulama
/// uçtan uca şifreli DEĞİLDİR; bu metne "uçtan uca", "kimse okuyamaz" gibi iddialar EKLENMEZ (docs/ENCRYPTION.md).
class ChatEncryptionNotice extends StatelessWidget {
  const ChatEncryptionNotice({super.key, required this.kind, required this.onTap});

  final ChatSecurityKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final text = _noticeText(context, kind);
    final style = chatInfoBody12(context, color: t.mut).copyWith(fontSize: 13, height: 1.4);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Semantics(
            button: true,
            label: '$text ${l.chatEncMore}',
            excludeSemantics: true,
            onTap: onTap,
            child: Material(
              key: const ValueKey('chatEncryptionNotice'),
              color: t.sf,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: t.bdSubtle),
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 14, 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: 2),
                        child: Icon(BuIcons.lock, size: 16, color: t.mut),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(style: style, children: [
                            TextSpan(text: '$text '),
                            TextSpan(
                              text: l.chatEncMore,
                              style: style.copyWith(color: t.ink, decoration: TextDecoration.underline, decorationColor: t.ink),
                            ),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Liste/yeni sohbet ekranlarında gürültüsüz tek satır alt bilgi: kilit + "Mesajların ... şifrelenir."
class ChatEncryptionFootnote extends StatelessWidget {
  const ChatEncryptionFootnote({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final text = context.l10n.chatEncFootnote;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(BuIcons.lock, size: 14, color: t.mut),
          const SizedBox(width: 6),
          Flexible(child: Text(text, textAlign: TextAlign.center, style: chatInfoBody12(context, color: t.mut))),
        ]),
      ),
    );
    return Semantics(
      container: true,
      label: text,
      excludeSemantics: true,
      button: onTap != null,
      onTap: onTap,
      child: onTap == null ? row : InkWell(key: const ValueKey('chatEncryptionFootnote'), onTap: onTap, child: row),
    );
  }
}

/// "Sohbet güvenliği": neyin nasıl korunduğunu ve (dürüstçe) neyin korunmadığını anlatır.
/// Kaynaklar: docs/ENCRYPTION.md, docs/legal/privacy_tr.md bölüm 3, docs/changes/messaging.md, docs/MEDIA_PIPELINE.md.
class ChatSecurityPage extends StatelessWidget {
  const ChatSecurityPage({super.key, required this.session});

  final Session session;

  void _openLegal(BuildContext context, String type) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'legal_doc'),
        builder: (_) => LegalDocPage(session: session, type: type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final how = <_Item>[
      _Item(BuIcons.lock, l.chatEncTlsTitle, l.chatEncTlsBody),
      _Item(BuIcons.shieldCheck, l.chatEncRestTitle, l.chatEncRestBody),
      _Item(BuIcons.fileSearch, l.chatEncAuditTitle, l.chatEncAuditBody),
      _Item(BuIcons.ban, l.chatEncBlockTitle, l.chatEncBlockBody),
      _Item(BuIcons.eye, l.chatEncOnceTitle, l.chatEncOnceBody),
      _Item(BuIcons.trash2, l.chatEncDeleteTitle, l.chatEncDeleteBody),
      _Item(BuIcons.image, l.chatEncExifTitle, l.chatEncExifBody),
      _Item(BuIcons.download, l.chatEncDataTitle, l.chatEncDataBody),
      _Item(BuIcons.shield, l.chatEncNoSellTitle, l.chatEncNoSellBody),
    ];
    final know = <_Item>[
      _Item(BuIcons.info, l.chatEncNotE2eeTitle, l.chatEncNotE2eeBody),
      _Item(BuIcons.history, l.chatEncRetainTitle, l.chatEncRetainBody),
      _Item(BuIcons.users, l.chatEncMembersTitle, l.chatEncMembersBody),
      _Item(BuIcons.camera, l.chatEncScreenshotTitle, l.chatEncScreenshotBody),
      _Item(BuIcons.userX, l.chatEncAccountTitle, l.chatEncAccountBody),
    ];
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: l.chatEncPageTitle, onBack: () => Navigator.maybePop(context)),
        Expanded(
          child: ListView(
            key: const ValueKey('chatSecurityList'),
            padding: EdgeInsets.fromLTRB(kChatInfoMargin, 8, kChatInfoMargin, 24 + MediaQuery.paddingOf(context).bottom),
            children: [
              _hero(context),
              const SizedBox(height: 24),
              _section(context, l.chatEncSecHow),
              ChatInfoRows(children: [for (final i in how) _ItemRow(item: i)]),
              const SizedBox(height: 24),
              _section(context, l.chatEncSecKnow),
              ChatInfoRows(children: [for (final i in know) _ItemRow(item: i)]),
              const SizedBox(height: 24),
              _section(context, l.chatEncSecHelp),
              ChatInfoCard(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(l.chatEncHelpMessage(l.chatDetailReport), style: chatInfoBody14(context)),
                  const SizedBox(height: 10),
                  Text(l.chatEncHelpPerson(l.chatInfoBlock, l.chatInfoReportUser), style: chatInfoBody14(context)),
                ]),
              ),
              const SizedBox(height: 24),
              _section(context, l.chatEncSecRead),
              ChatInfoRows(children: [
                ChatInfoRow(
                  key: const ValueKey('chatSecPrivacy'),
                  icon: BuIcons.fileText,
                  label: l.chatEncPrivacyLink,
                  minHeight: 56,
                  onTap: () => _openLegal(context, 'PRIVACY'),
                ),
                ChatInfoRow(
                  key: const ValueKey('chatSecRules'),
                  icon: BuIcons.fileText,
                  label: l.chatEncRulesLink,
                  minHeight: 56,
                  onTap: () => _openLegal(context, 'COMMUNITY_RULES'),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _hero(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(children: [
        Container(
          key: const ValueKey('chatSecurityLock'),
          width: 80,
          height: 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: t.sf, shape: BoxShape.circle, border: Border.all(color: t.bd)),
          child: Icon(BuIcons.lock, size: 36, color: t.ink),
        ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            l.chatEncHeroTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall!.copyWith(color: t.ink, fontWeight: BuType.emphasisWeight),
          ),
        ),
        const SizedBox(height: 8),
        Text(l.chatEncHeroBody, textAlign: TextAlign.center, style: chatInfoBody14(context)),
      ]),
    );
  }

  Widget _section(BuildContext context, String text) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
        child: Semantics(header: true, child: Text(text, style: chatInfoLabel14(context, color: context.bu.mut))),
      );
}

class _Item {
  const _Item(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final _Item item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '${item.title}. ${item.body}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ChatInfoIconDot(icon: item.icon, size: 40, iconSize: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: chatInfoTitle16(context)),
              const SizedBox(height: 2),
              Text(item.body, style: chatInfoBody14(context)),
            ]),
          ),
        ]),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/analytics.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'profile_qr_logic.dart';
import 'profile_qr_style.dart';
import 'profile_qr_widgets.dart';
import 'profile_share.dart';

/// Sistem paylaşım çağrısı (testlerde değiştirilir).
@visibleForTesting
Future<void> Function(ShareParams)? debugQrExternalShare;

/// "QR kodum": avatar + ad + @kullanıcı adı + büyük QR (içerik = herkese açık profil bağlantısı), paylaş / bağlantıyı
/// kopyala / görsel olarak paylaş / QR tara. QR her temada siyah-beyazdır (koyu temada beyaz zemin kutusunda).
class ProfileQrPage extends StatefulWidget {
  const ProfileQrPage({super.key, required this.session, this.profile});

  final Session session;

  /// Zaten yüklü kendi profil yanıtı (`GET /users/me`); yoksa sayfa kendisi getirir.
  final Map<String, dynamic>? profile;

  @override
  State<ProfileQrPage> createState() => _ProfileQrPageState();
}

class _ProfileQrPageState extends State<ProfileQrPage> {
  Map<String, dynamic>? _p;
  bool _failed = false;
  bool _busyImage = false;

  Session get _s => widget.session;
  int? get _id => (_p?['id'] as num?)?.toInt() ?? _s.userId;
  String? _str(String k) {
    final v = _p?[k];
    return v is String && v.trim().isNotEmpty ? v.trim() : null;
  }

  String? get _name => _str('displayName') ?? _s.displayName;
  String? get _username => _str('username');
  String? get _avatar => _str('avatarUrl') ?? _s.avatarUrl.value;
  String? get _link => _id == null ? null : profileLinkFor(_id!);

  @override
  void initState() {
    super.initState();
    _p = widget.profile;
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final r = await _s.api.get('/users/me');
      if (!mounted) return;
      if (r is Map) setState(() => _p = Map<String, dynamic>.from(r));
    } catch (_) {
      if (mounted && _id == null) setState(() => _failed = true);
    }
  }

  Future<void> _copy() async {
    final link = _link;
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link));
    Analytics.instance.action('profile_qr', target: 'copy_link');
    if (mounted) BuToast.show(context, context.l10n.shareLinkCopied, kind: BuToastKind.success);
  }

  Future<void> _share() async {
    final id = _id;
    if (id == null) return;
    await shareUserProfile(context, _s, id: id, displayName: _name, username: _username, avatarUrl: _avatar);
  }

  Future<void> _shareImage(BuildContext btn) async {
    final link = _link;
    if (link == null || _busyImage) return;
    final l = context.l10n;
    final box = btn.findRenderObject();
    final origin = box is RenderBox && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;
    setState(() => _busyImage = true);
    try {
      final rtl = Directionality.of(context) == TextDirection.rtl;
      final png = await renderProfileCardPng(
        link,
        ProfileCardTexts(
          brand: 'BÜ Kampüs',
          name: _name ?? '',
          username: _username == null ? null : '@$_username',
          findMe: l.profileQrFindMe,
          link: link,
          rtl: rtl,
        ),
      );
      if (png == null) throw StateError('qr');
      final params = ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png', name: 'bu-kampus-qr.png')],
        fileNameOverrides: const ['bu-kampus-qr.png'],
        text: link,
        sharePositionOrigin: origin,
      );
      await (debugQrExternalShare ?? (p) => SharePlus.instance.share(p))(params);
      Analytics.instance.action('profile_qr', target: 'share_image');
    } catch (_) {
      if (mounted) BuToast.show(context, l.profileQrImageFailed, kind: BuToastKind.error);
    } finally {
      if (mounted) setState(() => _busyImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final link = _link;
    final width = MediaQuery.sizeOf(context).width;
    final qrSize = (width - 40 - 24).clamp(220.0, 320.0);
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: l.profileQrMyCode, onBack: () => Navigator.maybePop(context)),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.paddingOf(context).bottom + 24),
            children: [
              // Marka satırı: küçük, soluk, harf aralıklı (Arapçada aralıksız: harf bağlantısı kopmasın).
              Center(
                child: Text(
                  Directionality.of(context) == TextDirection.rtl ? 'BÜ Kampüs' : 'BÜ KAMPÜS',
                  key: const ValueKey('qr-brand'),
                  style: tx.labelMedium!.copyWith(
                      color: t.mut, letterSpacing: Directionality.of(context) == TextDirection.rtl ? 0 : 3, fontWeight: FontWeight.w400),
                ),
              ),
              const SizedBox(height: 20),
              Center(child: BuAvatar(name: _name, url: _avatar, size: 80)),
              const SizedBox(height: 14),
              if (_name != null)
                Text(_name!,
                    key: const ValueKey('qr-name'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tx.headlineSmall!.copyWith(color: t.ink, fontWeight: BuType.emphasisWeight)),
              if (_username != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('@$_username',
                      key: const ValueKey('qr-username'),
                      textAlign: TextAlign.center,
                      style: tx.bodyLarge!.copyWith(color: t.mut)),
                ),
              const SizedBox(height: 24),
              Center(
                child: link == null
                    ? SizedBox(
                        width: qrSize,
                        height: qrSize,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: kQrPaper, borderRadius: BorderRadius.circular(28)),
                          child: Center(
                            child: _failed
                                ? Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(l.profileQrLoadFailed,
                                        textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: kQrInk)),
                                  )
                                : SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: kQrInk)),
                          ),
                        ),
                      )
                    : ProfileQrPlate(key: const ValueKey('qr-code'), data: link, size: qrSize, semanticLabel: l.profileQrMyCode),
              ),
              const SizedBox(height: 16),
              Text(l.profileQrHint, textAlign: TextAlign.center, style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 13, height: 1.4)),
              const SizedBox(height: 24),
              BuButton(
                key: const ValueKey('qr-share'),
                label: l.profileShareAction,
                icon: BuIcons.share2,
                onPressed: link == null ? null : _share,
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: BuButton(
                    key: const ValueKey('qr-copy'),
                    label: l.shareCopyLink,
                    icon: BuIcons.copy,
                    kind: BuButtonKind.soft,
                    onPressed: link == null ? null : _copy,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Builder(
                    builder: (bc) => BuButton(
                      key: const ValueKey('qr-image'),
                      label: l.profileQrShareImage,
                      icon: BuIcons.image,
                      kind: BuButtonKind.soft,
                      busy: _busyImage,
                      onPressed: link == null ? null : () => _shareImage(bc),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              BuButton(
                key: const ValueKey('qr-scan'),
                label: l.profileQrScan,
                icon: BuIcons.qrCode,
                kind: BuButtonKind.outline,
                onPressed: () => openProfileScanner(context, _s),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

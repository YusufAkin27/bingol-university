import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../chat/photo_autosave.dart';
import 'blocked_users_page.dart';
import 'profil2_my_data_page.dart';
import 'profil2_widgets.dart';

/// Gizlilik değerleri (sunucu sözleşmesi: EVERYONE | SHARED_CONTEXT | ONLY_ME).
const kPrivacyValues = ['EVERYONE', 'SHARED_CONTEXT', 'ONLY_ME'];

/// Gizlilik ve engellenenler (Stitch 49-3): alan bazlı profil görünürlüğü (3 parçalı seçici), e-posta anahtarı,
/// engellenenler satırı, Verilerim ve hesap. Veri indirme ve hesap silme [MyDataPage] altındadır.
class PrivacyDataPage extends StatefulWidget {
  const PrivacyDataPage({super.key, required this.session});

  final Session session;

  @override
  State<PrivacyDataPage> createState() => _PrivacyDataPageState();
}

class _PrivacyDataPageState extends State<PrivacyDataPage> {
  static const _fields = ['avatar', 'bio', 'faculty', 'department', 'classYear'];
  static const _icons = {
    'avatar': LucideIcons.circleUser,
    'bio': LucideIcons.fileText,
    'faculty': LucideIcons.landmark,
    'department': LucideIcons.graduationCap,
    'classYear': LucideIcons.columns3,
  };

  final Map<String, String> _vis = {for (final f in _fields) f: 'EVERYONE'};
  final Set<String> _saving = {};
  bool _showEmail = false;

  /// Sohbet fotoğraflarını galeriye otomatik kaydet (cihazda saklanır; varsayılan KAPALI, rıza ile açılır).
  bool _saveGallery = false;
  bool _avatarHidden = false;
  bool _loaded = false;
  Object? _error;
  String? _blockedCount;

  @override
  void initState() {
    super.initState();
    PhotoAutoSave.instance.enabled().then((v) {
      if (mounted) setState(() => _saveGallery = v);
    });
    _load();
  }

  /// Açarken rıza metni gösterilir (varsayılan kapalı); kapatmak onaysızdır.
  Future<void> _setSaveGallery(bool v) async {
    if (v) {
      final l = context.l10n;
      final ok = await BuConfirmSheet.show(
        context,
        title: l.p30AutosaveConsentTitle,
        message: l.p30AutosaveConsentBody,
        confirmLabel: l.p30AutosaveConsentOk,
        icon: LucideIcons.imageDown,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _saveGallery = v);
    await PhotoAutoSave.instance.setEnabled(v);
  }

  /// Kompakt hata bildirimi: kırmızı simge + başlık/alt başlık + "Tekrar dene" + kapat.
  void _saveFailed(VoidCallback retry) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      key: const ValueKey('privacy-save-failed'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.ink,
      duration: const Duration(seconds: 6),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: const RoundedRectangleBorder(borderRadius: BuRadius.bMd),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 6, 10),
      content: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: t.danger.withValues(alpha: .25), shape: BoxShape.circle),
          child: Icon(LucideIcons.triangleAlert, size: 18, color: t.danger),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(l.profil2SaveFailed,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(color: t.bg, fontWeight: FontWeight.w700)),
            Text(l.p19SaveFailedSub, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.bg.withValues(alpha: .75))),
          ]),
        ),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: t.bg, minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 10)),
          onPressed: () {
            m.hideCurrentSnackBar();
            retry();
          },
          icon: const Icon(LucideIcons.refreshCw, size: 16),
          label: Text(l.profileRetry),
        ),
        IconButton(
          tooltip: l.commonClose,
          onPressed: m.hideCurrentSnackBar,
          icon: Icon(LucideIcons.x, size: 18, color: t.bg.withValues(alpha: .8)),
        ),
      ]),
    ));
  }

  void _push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await widget.session.api.get('/users/me/privacy');
      if (r is Map) {
        for (final f in _fields) {
          final v = r[f];
          if (v is String && kPrivacyValues.contains(v)) _vis[f] = v;
        }
        _avatarHidden = r['avatarHiddenByModeration'] == true;
      }
      try {
        final me = await widget.session.api.get('/users/me');
        if (me is Map) _showEmail = me['showEmail'] == true;
      } catch (_) {
        // E-posta tercihi okunamazsa varsayılanla devam edilir.
      }
      if (mounted) setState(() => _loaded = true);
      _loadBlockedCount();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Engellenen sayısı: tek sayfa (100) yeterliyse tam sayı, devamı varsa "100+"; alınamazsa gösterilmez.
  Future<void> _loadBlockedCount() async {
    try {
      final r = await widget.session.api.getResponse('/users/me/blocks?limit=100');
      final body = r.body;
      final list = body is List ? body : (body is Map ? (body['items'] as List? ?? const []) : const []);
      final next = r.headers['x-next-cursor'];
      if (mounted) setState(() => _blockedCount = (next == null || next.isEmpty) ? '${list.length}' : '${list.length}+');
    } catch (_) {
      // Sayı opsiyoneldir.
    }
  }

  /// Seçim anında kaydedilir; hata olursa eski değere dönülür ve "Tekrar dene" sunulur.
  Future<void> _setVis(String field, String value) async {
    final old = _vis[field]!;
    if (old == value) return;
    setState(() {
      _vis[field] = value;
      _saving.add(field);
    });
    try {
      await widget.session.api.patch('/users/me/privacy', {field: value});
    } catch (_) {
      if (!mounted) return;
      setState(() => _vis[field] = old);
      _saveFailed(() => _setVis(field, value));
    } finally {
      if (mounted) setState(() => _saving.remove(field));
    }
  }

  Future<void> _setEmail(bool v) async {
    final old = _showEmail;
    setState(() => _showEmail = v);
    try {
      await widget.session.api.patch('/users/me', {'showEmail': v});
    } catch (_) {
      if (!mounted) return;
      setState(() => _showEmail = old);
      _saveFailed(() => _setEmail(v));
    }
  }

  String _visLabel(String v) {
    final l = context.l10n;
    return switch (v) {
      'SHARED_CONTEXT' => l.profil2VisShared,
      'ONLY_ME' => l.profil2VisOnlyMe,
      _ => l.profil2VisEveryone,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    Widget body;
    if (_error != null) {
      body = BuErrorState(error: _error, onRetry: _load);
    } else if (!_loaded) {
      body = const BuSkeletonList(itemCount: 5, padding: EdgeInsets.fromLTRB(20, 12, 20, 20));
    } else {
      final labels = {
        'avatar': l.profil2FieldAvatar,
        'bio': l.profil2FieldBio,
        'faculty': l.profil2FieldFaculty,
        'department': l.profil2FieldDepartment,
        'classYear': l.profil2FieldClassYear,
      };
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(l.profil2PrivacyIntro, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.45)),
          ),
          const SizedBox(height: 16),
          P2SectionLabel(l.profil2VisibilitySection),
          BuGroup(children: [
            for (final f in _fields)
              Padding(
                key: ValueKey('privacy-row-$f'),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    P2IconTile(icon: _icons[f]!, tint: t.tint(1)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(labels[f]!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  P2Segment3(
                    key: ValueKey('privacy-select-$f'),
                    label: labels[f],
                    labels: [for (final v in kPrivacyValues) _visLabel(v)],
                    index: kPrivacyValues.indexOf(_vis[f]!),
                    onChanged: (i) => _setVis(f, kPrivacyValues[i]),
                  ),
                ]),
              ),
          ]),
          if (_avatarHidden) ...[
            const SizedBox(height: 12),
            P2NoticeCard(
              key: const ValueKey('privacy-avatar-moderated'),
              lines: [l.profil2AvatarModerated],
              icon: LucideIcons.triangleAlert,
              compact: true,
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: ExcludeSemantics(child: Icon(LucideIcons.info, size: 16, color: t.mut)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${l.profil2SharedHintLead} ', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
                    TextSpan(text: l.profil2SharedHintBody),
                  ]),
                  style: tx.bodySmall!.copyWith(color: t.mut, height: 1.45),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          BuGroup(children: [
            BuSettingsTile.toggle(
              key: const ValueKey('privacy-email-switch'),
              icon: LucideIcons.atSign,
              title: l.profil2ShowEmail,
              subtitle: l.profil2ShowEmailSub,
              value: _showEmail,
              tint: t.tint(1),
              onChanged: _setEmail,
            ),
          ]),
          const SizedBox(height: 16),
          BuGroup(children: [
            BuSettingsTile.toggle(
              key: const ValueKey('privacy-save-gallery-switch'),
              icon: LucideIcons.imageDown,
              title: l.p22SaveGalleryTitle,
              subtitle: l.p22SaveGalleryDesc,
              value: _saveGallery,
              tint: t.tint(1),
              onChanged: _setSaveGallery,
            ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
            child: Text(l.p22SaveGalleryCloud, key: const ValueKey('privacy-save-gallery-note'), style: tx.bodySmall!.copyWith(color: t.mut)),
          ),
          P2SectionLabel(l.profil2BlockedSection, top: 20),
          BuGroup(dividerIndent: 66, children: [
            BuSettingsTile(
              icon: LucideIcons.ban,
              title: l.profil2BlockedSection,
              value: _blockedCount,
              tint: t.tint(1),
              onTap: () => _push(BlockedUsersPage(session: widget.session)),
            ),
            BuSettingsTile(
              icon: LucideIcons.download,
              title: l.profil2MyDataRow,
              tint: t.tint(1),
              onTap: () => _push(MyDataPage(session: widget.session)),
            ),
          ]),
        ],
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: l.profil2PrivacyTitle, onBack: () => Navigator.pop(context)),
          Expanded(child: body),
        ],
      ),
    );
  }
}

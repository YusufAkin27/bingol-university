import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'blocked_users_page.dart';
import 'profil2_my_data_page.dart';
import 'profil2_widgets.dart';

/// Gizlilik değerleri (sunucu sözleşmesi: EVERYONE | SHARED_CONTEXT | ONLY_ME).
const kPrivacyValues = ['EVERYONE', 'SHARED_CONTEXT', 'ONLY_ME'];

/// Ayarlar > Gizlilik: alan bazlı profil görünürlüğü, e-posta anahtarı, engellenenler.
/// Veri indirme ve hesap silme [MyDataPage] altındadır.
class PrivacyDataPage extends StatefulWidget {
  const PrivacyDataPage({super.key, required this.session});

  final Session session;

  @override
  State<PrivacyDataPage> createState() => _PrivacyDataPageState();
}

class _PrivacyDataPageState extends State<PrivacyDataPage> {
  static const _fields = ['avatar', 'bio', 'faculty', 'department', 'classYear'];

  final Map<String, String> _vis = {for (final f in _fields) f: 'EVERYONE'};
  final Set<String> _saving = {};
  bool _showEmail = false;
  bool _avatarHidden = false;
  bool _loaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

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
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Seçim anında kaydedilir; hata olursa eski değere dönülür.
  Future<void> _setVis(String field, String value) async {
    final old = _vis[field]!;
    if (old == value) return;
    setState(() {
      _vis[field] = value;
      _saving.add(field);
    });
    try {
      await widget.session.api.patch('/users/me/privacy', {field: value});
    } catch (e) {
      if (!mounted) return;
      setState(() => _vis[field] = old);
      _toast(errorText(e));
    } finally {
      if (mounted) setState(() => _saving.remove(field));
    }
  }

  Future<void> _setEmail(bool v) async {
    final old = _showEmail;
    setState(() => _showEmail = v);
    try {
      await widget.session.api.patch('/users/me', {'showEmail': v});
    } catch (e) {
      if (!mounted) return;
      setState(() => _showEmail = old);
      _toast(errorText(e));
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
    Widget body;
    if (_error != null) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else if (!_loaded) {
      body = const LoadingView();
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
          Text(l.profil2PrivacyIntro, style: BuType.body.copyWith(color: t.mut, height: 1.45)),
          const SizedBox(height: 12),
          P2SectionLabel(l.profil2VisibilitySection),
          BuGroup(children: [
            for (final f in _fields)
              _VisibilityRow(
                key: ValueKey('privacy-row-$f'),
                fieldKey: f,
                label: labels[f]!,
                value: _vis[f]!,
                options: [for (final v in kPrivacyValues) (v, _visLabel(v))],
                busy: _saving.contains(f),
                onChanged: (v) => _setVis(f, v),
              ),
          ]),
          if (_avatarHidden)
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 4, right: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(LucideIcons.triangleAlert, size: 16, color: P2Tones.of(context).dng),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l.profil2AvatarModerated,
                        key: const ValueKey('privacy-avatar-moderated'),
                        style: BuType.label.copyWith(color: P2Tones.of(context).dng, fontWeight: FontWeight.w500, height: 1.45)),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 4, right: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: ExcludeSemantics(child: Icon(LucideIcons.info, size: 16, color: t.mut)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '${l.profil2SharedHintLead} ', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
                      TextSpan(text: l.profil2SharedHintBody),
                    ]),
                    style: BuType.label.copyWith(color: t.mut, fontWeight: FontWeight.w500, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          BuGroup(children: [
            MergeSemantics(
              child: P2Row(
                icon: LucideIcons.mail,
                title: l.profil2ShowEmail,
                subtitle: l.profil2ShowEmailSub,
                onTap: () => _setEmail(!_showEmail),
                trailing: ExcludeSemantics(
                  child: P2Switch(key: const ValueKey('privacy-email-switch'), value: _showEmail, onChanged: _setEmail),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          P2SectionLabel(l.profil2BlockedSection),
          BuGroup(children: [
            P2Row(
              icon: LucideIcons.ban,
              title: l.profilePrefsBlockedUsers,
              chevron: true,
              onTap: () => _push(BlockedUsersPage(session: widget.session)),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
            child: Text(l.profil2BlockedHint, style: BuType.label.copyWith(color: t.mut, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 18),
          BuGroup(children: [
            P2Row(
              icon: LucideIcons.download,
              title: l.profil2MyDataRow,
              chevron: true,
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

/// Etiket + açılır seçici (150 px); büyük yazıda seçici etiketin altına iner.
class _VisibilityRow extends StatelessWidget {
  const _VisibilityRow({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.busy = false,
  });

  final String fieldKey;
  final String label;
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final current = options.firstWhere((o) => o.$1 == value, orElse: () => options.first).$2;
    final selector = PopupMenuButton<String>(
      key: ValueKey('privacy-select-$fieldKey'),
      tooltip: label,
      onSelected: onChanged,
      color: t.sf,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: t.bd)),
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem<String>(
            value: o.$1,
            child: Row(
              children: [
                Expanded(child: Text(o.$2, style: BuType.bodyStrong.copyWith(color: t.ink))),
                if (o.$1 == value) Icon(LucideIcons.check, size: 16, color: t.pr),
              ],
            ),
          ),
      ],
      child: Semantics(
        button: true,
        label: label,
        value: current,
        child: ExcludeSemantics(
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 110, maxWidth: 150),
            padding: const EdgeInsetsDirectional.only(start: 12, end: 10),
            decoration: BoxDecoration(
              color: t.sf,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.bd, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(current,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.bodyStrong.copyWith(color: t.ink)),
                ),
                const SizedBox(width: 6),
                busy
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(LucideIcons.chevronDown, size: 18, color: t.mut),
              ],
            ),
          ),
        ),
      ),
    );
    final labelText = Text(label, style: BuType.bodyStrong.copyWith(color: t.ink));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: p2BigText(context)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [labelText, const SizedBox(height: 6), selector],
              )
            : Row(children: [Expanded(child: labelText), const SizedBox(width: 12), selector]),
      ),
    );
  }
}

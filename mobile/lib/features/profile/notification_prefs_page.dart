import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/push/push_service.dart';
import '../../core/session.dart';
import '../academic/reminder_settings_page.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'profil_widgets.dart';
import '../../core/typography.dart';

/// Tasarımdaki aç/kapat anahtarı (46x28, beyaz topuz).
class PrefSwitch extends StatelessWidget {
  const PrefSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    // Kapalı: çerçeveli iz + koyu topuz (iz/topuz kontrastı >= 3:1); açık: kırmızı iz + onPr topuz.
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: SizedBox(
          width: 52,
          height: 44, // dokunma alanı
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 46,
              height: 28,
              padding: const EdgeInsets.all(3),
              alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
              decoration: BoxDecoration(
                color: value ? t.pr : t.sf2,
                borderRadius: BorderRadius.circular(14),
                border: value ? null : Border.all(color: t.mut, width: 1.5),
              ),
              child: Container(
                width: value ? 22 : 18,
                height: value ? 22 : 18,
                margin: EdgeInsets.all(value ? 0 : 2),
                decoration: BoxDecoration(color: value ? t.onPr : t.mut, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Anahtar satırı (etiket + sağda anahtar).
class PrefSwitchRow extends StatelessWidget {
  const PrefSwitchRow({super.key, required this.label, required this.value, this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    // Tüm satır dokunulabilir; ekran okuyucu "etiket, anahtar, açık/kapalı" okur.
    return MergeSemantics(
      child: Semantics(
        child: InkWell(
          onTap: onChanged == null ? null : () => onChanged!(!value),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 10, 4),
            child: Row(
              children: [
                Expanded(child: Text(label, style: BuType.bodyStrong.copyWith(color: t.ink))),
                const SizedBox(width: 8),
                PrefSwitch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sunucunun ana bayrakları (her zaman gösterilir); tasarımdaki 5 ana anahtar.
const _prefRows = ['news', 'announcements', 'events', 'messages', 'communities'];

/// Sunucu yanıtında anahtar varsa gösterilen ek ana bayraklar (backend eklenene kadar gizli kalır).
const _optionalRows = ['polls', 'academicAnnouncements', 'stories'];

/// Alt türler (`subtypes`): yalnızca sunucu yanıtında bulunanlar gösterilir; bilinmeyen anahtar gönderilmez (400).
const _subtypeRows = [
  'MESSAGE_DIRECT',
  'MESSAGE_GROUP',
  'EVENT_REMINDER',
  'EVENT_UPDATE',
  'EVENT_ADMISSION',
  'COMMUNITY_POST',
  'COMMUNITY_ROLE',
  'COMMUNITY_JOIN',
  'POST_MENTION',
  'USER_FOLLOW',
  'POST_LIKE',
  'POST_COMMENT',
  'COMMENT_REPLY',
];

/// Alt türün bağlı olduğu ana bayrak: o kapalıysa alt tür etkisizdir (sunucu da böyle uygular).
String _parentFlag(String sub) {
  if (sub.startsWith('MESSAGE_')) return 'messages';
  if (sub.startsWith('EVENT_')) return 'events';
  return 'communities';
}

/// Sunucu bayrak/alt tür kodunun ekrandaki adı (istek diline göre).
String _prefLabel(BuildContext context, String key) {
  final l = context.l10n;
  return switch (key) {
    'news' => l.profilePrefsNotifNews,
    'announcements' => l.profilePrefsNotifAnnouncements,
    'events' => l.profilePrefsNotifEvents,
    'communities' => l.profil1NotifClubs,
    'messages' => l.profilePrefsNotifMessages,
    'polls' => l.profilePrefsNotifPolls,
    'academicAnnouncements' => l.profilePrefsNotifAcademic,
    'stories' => l.profilePrefsNotifStories,
    'MESSAGE_DIRECT' => l.profil1SubMsgDirect,
    'MESSAGE_GROUP' => l.profil1SubMsgGroup,
    'EVENT_REMINDER' => l.profil1SubEventReminder,
    'EVENT_UPDATE' => l.profil1SubEventUpdate,
    'EVENT_ADMISSION' => l.profil1SubEventAdmission,
    'COMMUNITY_POST' => l.profil1SubClubPost,
    'COMMUNITY_ROLE' => l.profil1SubClubRole,
    'COMMUNITY_JOIN' => l.profil1SubClubJoin,
    'POST_MENTION' => l.profilePrefsNotifMention,
    'USER_FOLLOW' => l.profilePrefsNotifFollow,
    'POST_LIKE' => l.profilePrefsNotifLike,
    'POST_COMMENT' => l.profilePrefsNotifComment,
    'COMMENT_REPLY' => l.profilePrefsNotifReply,
    _ => key,
  };
}

/// Ana anahtarın kısa açıklaması (yalnız tasarımdaki 5 anahtarda).
String? _prefSub(BuildContext context, String key) {
  final l = context.l10n;
  return switch (key) {
    'news' => l.profil1NewsSub,
    'announcements' => l.profil1AnnSub,
    'events' => l.profil1EventsSub,
    'messages' => l.profil1MsgSub,
    'communities' => l.profil1ClubsSub,
    _ => null,
  };
}

/// Bu cihazın push izin durumu: 'notConfigured' | 'on' | 'off' | 'notGranted'.
Future<String> _readPushStatus(PushService? push) async {
  try {
    final configured = (push?.enabled ?? false) || Firebase.apps.isNotEmpty;
    if (configured) {
      final st = await FirebaseMessaging.instance.getNotificationSettings();
      return switch (st.authorizationStatus) {
        AuthorizationStatus.authorized || AuthorizationStatus.provisional => 'on',
        AuthorizationStatus.denied => 'off',
        _ => 'notGranted',
      };
    }
  } catch (_) {}
  return 'notConfigured';
}

/// Bildirim tercihleri gövdesi: push durumu, ana anahtarlar, ayrıntılı tercihler, sessiz saatler.
/// Yüklenir, her değişiklik anında kaydedilir, hatada geri alınır. Ayarlar sayfasında ve tek başına
/// sayfada kullanılır (Ayarlar'ın kendi push satırı olduğundan orada [showPushCard] kapalıdır).
class NotificationPrefsGroup extends StatefulWidget {
  const NotificationPrefsGroup({super.key, required this.session, this.push, this.showPushCard = false});

  final Session session;

  /// Verilirse push durumu buradan okunur; yoksa Firebase başlatılmış mı diye bakılır.
  final PushService? push;
  final bool showPushCard;

  @override
  State<NotificationPrefsGroup> createState() => _NotificationPrefsGroupState();
}

class _NotificationPrefsGroupState extends State<NotificationPrefsGroup> {
  Map<String, dynamic>? _prefs;
  Object? _error;
  bool _detailOpen = false;
  String _pushStatus = '...';

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.showPushCard) {
      _readPushStatus(widget.push).then((s) {
        if (mounted) setState(() => _pushStatus = s);
      });
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await widget.session.api.get('/notifications/preferences') as Map<String, dynamic>;
      if (mounted) setState(() => _prefs = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Map<String, dynamic> get _subs =>
      (_prefs?['subtypes'] is Map) ? (_prefs!['subtypes'] as Map).cast<String, dynamic>() : {};

  Map<String, dynamic>? get _quiet =>
      (_prefs?['quietHours'] is Map) ? (_prefs!['quietHours'] as Map).cast<String, dynamic>() : null;

  /// Yalnız değişen alan gönderilir (kısmi güncelleme); hatada eski değere dönülür.
  Future<void> _save(Map<String, dynamic> body, void Function() apply) async {
    final old = jsonDecode(jsonEncode(_prefs)) as Map<String, dynamic>;
    setState(apply);
    try {
      final r = await widget.session.api.put('/notifications/preferences', body);
      if (mounted && r is Map<String, dynamic>) setState(() => _prefs = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _prefs = old);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  Future<void> _set(String key, bool value) => _save({key: value}, () => _prefs![key] = value);

  Future<void> _setSub(String key, bool value) => _save({
        'subtypes': {key: value}
      }, () {
        final m = Map<String, dynamic>.from(_subs)..[key] = value;
        _prefs!['subtypes'] = m;
      });

  /// Sessiz saat güncellemesi: `enabled` her istekte gönderilir (sunucuda zorunlu bayrak).
  Future<void> _setQuiet({bool? enabled, String? start, String? end}) {
    final q = _quiet ?? const <String, dynamic>{};
    final en = enabled ?? (q['enabled'] == true);
    return _save({
      'quietHours': {
        'enabled': en,
        if (start != null) 'start': start,
        if (end != null) 'end': end,
      }
    }, () {
      _prefs!['quietHours'] = {
        ...q,
        'enabled': en,
        if (start != null) 'start': start,
        if (end != null) 'end': end,
      };
    });
  }

  static TimeOfDay _parse(String? s, TimeOfDay fallback) {
    final m = RegExp(r'^(\d{2}):(\d{2})').firstMatch(s ?? '');
    if (m == null) return fallback;
    return TimeOfDay(hour: int.parse(m.group(1)!), minute: int.parse(m.group(2)!));
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isStart) async {
    final q = _quiet ?? const <String, dynamic>{};
    final cur = isStart
        ? _parse(q['start'] as String?, const TimeOfDay(hour: 23, minute: 0))
        : _parse(q['end'] as String?, const TimeOfDay(hour: 7, minute: 0));
    final r = await showTimePicker(
      context: context,
      initialTime: cur,
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (r == null || !mounted) return;
    await _setQuiet(start: isStart ? _fmt(r) : null, end: isStart ? null : _fmt(r));
  }

  Widget _pushCard(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final on = _pushStatus == 'on';
    final sub = switch (_pushStatus) {
      'on' => l.profil1PushGranted,
      'off' => l.pushOff,
      'notGranted' => l.pushNotGranted,
      'notConfigured' => l.pushNotConfigured,
      _ => '',
    };
    final pill = Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: on ? t.okSoft : t.sf2, borderRadius: BorderRadius.circular(12)),
      child: Text(on ? l.pushOn : l.profil1PillOff,
          style: BuType.label.copyWith(fontWeight: FontWeight.w700, color: on ? t.ok : t.mut)),
    );
    return ProfilCard(children: [
      ProfilRow(
        icon: LucideIcons.bellRing,
        label: l.profil1PushTitle,
        sub: sub,
        trailing: pill,
        chevron: false,
      ),
    ]);
  }

  Widget _timeField(BuildContext context, {required String label, required String value, required bool isStart}) {
    final t = context.bu;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
            child: Text(label, style: BuType.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, color: t.ink)),
          ),
          Semantics(
            button: true,
            label: '$label $value',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _pickTime(isStart),
              child: Container(
                height: 48,
                alignment: AlignmentDirectional.centerStart,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: t.sf,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.bd, width: 1.5),
                ),
                child: Text(value, style: BuType.heading.copyWith(fontSize: 15, color: t.ink)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    if (_error != null) {
      return BuCard(
        onTap: _load,
        child: Row(children: [
          Icon(LucideIcons.refreshCw, size: 16, color: t.pr),
          const SizedBox(width: 10),
          Expanded(
              child: Text(l.profilePrefsTapToRetry(errorText(_error!)),
                  style: BuType.caption.copyWith(color: t.mut))),
        ]),
      );
    }
    if (_prefs == null) {
      return const BuCard(child: SizedBox(height: 52, child: LoadingView()));
    }
    final subs = _subs;
    final subRows = [for (final r in _subtypeRows) if (subs.containsKey(r)) r];
    final optional = [for (final r in _optionalRows) if (_prefs!.containsKey(r)) r];
    final quiet = _quiet;
    final quietOn = quiet?['enabled'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showPushCard) _pushCard(context),
        ProfilSection(l.profil1WhatSection, top: widget.showPushCard ? 16 : 0),
        ProfilCard(children: [
          for (final r in [..._prefRows, ...optional])
            ProfilToggleRow(
              label: _prefLabel(context, r),
              sub: _prefSub(context, r),
              value: _prefs![r] == true,
              onChanged: (v) => _set(r, v),
            ),
        ]),
        if (subRows.isNotEmpty) ...[
          const SizedBox(height: 10),
          ProfilCard(children: [
            ProfilRow(
              icon: LucideIcons.bell,
              label: l.profil1Detailed,
              chevron: false,
              trailing: Icon(_detailOpen ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 18, color: t.mut),
              onTap: () => setState(() => _detailOpen = !_detailOpen),
            ),
            if (_detailOpen)
              for (final r in subRows)
                ProfilToggleRow(
                  // Üst bayrak kapalıysa alt tür etkisizdir.
                  label: _prefLabel(context, r),
                  value: subs[r] == true && _prefs![_parentFlag(r)] == true,
                  onChanged: _prefs![_parentFlag(r)] == true ? (v) => _setSub(r, v) : null,
                ),
          ]),
        ],
        if (quiet != null) ...[
          ProfilSection(l.profil1QuietTitle),
          ProfilCard(children: [
            ProfilToggleRow(
              icon: LucideIcons.moon,
              label: l.profil1QuietToggle,
              sub: l.profil1QuietSub,
              value: quietOn,
              onChanged: (v) => _setQuiet(enabled: v),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Row(
                children: [
                  _timeField(context,
                      label: l.profil1QuietStart, value: (quiet['start'] as String?) ?? '23:00', isStart: true),
                  const SizedBox(width: 10),
                  _timeField(context,
                      label: l.profil1QuietEnd, value: (quiet['end'] as String?) ?? '07:00', isStart: false),
                ],
              ),
            ),
          ]),
        ],
        ProfilSection(l.profilePrefsOnThisDevice),
        ProfilCard(children: [
          ProfilRow(
            icon: LucideIcons.alarmClock,
            label: l.profilePrefsReminders,
            onTap: () => Navigator.push<void>(
                context, MaterialPageRoute<void>(builder: (_) => ReminderSettingsPage(session: widget.session))),
          ),
        ]),
      ],
    );
  }
}

/// Bildirim tercihleri sayfası (P9e).
class NotificationPrefsPage extends StatelessWidget {
  const NotificationPrefsPage({super.key, required this.session, this.push});

  final Session session;
  final PushService? push;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bu.bg,
      body: Column(
        children: [
          BuHeader(title: context.l10n.profil1Notifications, onBack: () => Navigator.pop(context)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [NotificationPrefsGroup(session: session, push: push, showPushCard: true)],
            ),
          ),
        ],
      ),
    );
  }
}

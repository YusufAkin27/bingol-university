import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/push/push_service.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../academic/academic_widgets.dart';
import '../academic/akad_widgets.dart';
import '../academic/reminder_settings_page.dart';
import '../academic/reminders.dart';

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
                Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: t.ink))),
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
const _optionalRows = ['polls', 'academicAnnouncements'];

/// Alt türler (`subtypes`): yalnızca sunucu yanıtında bulunanlar gösterilir; bilinmeyen anahtar gönderilmez (400).
/// Kaldırılan türler (beğeni, yorum, bahsetme, takip) çizilmez.
const _subtypeGroups = <String, List<String>>{
  'messages': ['MESSAGE_DIRECT', 'MESSAGE_GROUP'],
  'events': ['EVENT_REMINDER', 'EVENT_UPDATE', 'EVENT_ADMISSION'],
  'communities': ['COMMUNITY_POST', 'COMMUNITY_ROLE', 'COMMUNITY_JOIN'],
};

IconData _prefIcon(String key) => switch (key) {
      'news' => LucideIcons.newspaper,
      'announcements' => LucideIcons.megaphone,
      'events' => LucideIcons.calendarCheck,
      'messages' => LucideIcons.messagesSquare,
      'communities' => LucideIcons.users,
      'polls' => LucideIcons.chartColumn,
      'academicAnnouncements' => LucideIcons.graduationCap,
      _ => LucideIcons.bell,
    };

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
    'MESSAGE_DIRECT' => l.profil1SubMsgDirect,
    'MESSAGE_GROUP' => l.profil1SubMsgGroup,
    'EVENT_REMINDER' => l.profil1SubEventReminder,
    'EVENT_UPDATE' => l.profil1SubEventUpdate,
    'EVENT_ADMISSION' => l.profil1SubEventAdmission,
    'COMMUNITY_POST' => l.profil1SubClubPost,
    'COMMUNITY_ROLE' => l.profil1SubClubRole,
    'COMMUNITY_JOIN' => l.profil1SubClubJoin,
    _ => key,
  };
}

/// Ana anahtarın kısa açıklaması.
String? _prefSub(BuildContext context, String key) {
  final l = context.l10n;
  return switch (key) {
    'news' => l.profil1NewsSub,
    'announcements' => l.profil1AnnSub,
    'events' => l.profil1EventsSub,
    'messages' => l.profil1MsgSub,
    'communities' => l.profil1ClubsSub,
    'polls' => l.p20PrefPollsSub,
    'academicAnnouncements' => l.p20PrefAcademicSub,
    _ => null,
  };
}

String? _subSub(BuildContext context, String key) {
  final l = context.l10n;
  return switch (key) {
    'MESSAGE_DIRECT' => l.p20PrefSubDirect,
    'MESSAGE_GROUP' => l.p20PrefSubGroup,
    'EVENT_REMINDER' => l.p20PrefSubEventReminder,
    'EVENT_UPDATE' => l.p20PrefSubEventUpdate,
    'EVENT_ADMISSION' => l.p20PrefSubEventAdmission,
    'COMMUNITY_POST' => l.p20PrefSubClubPost,
    'COMMUNITY_ROLE' => l.p20PrefSubClubRole,
    'COMMUNITY_JOIN' => l.p20PrefSubClubJoin,
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

/// Tercih verisi + kaydetme (iyimser güncelleme, hatada geri alma). Ana liste ve ayrıntı sayfası paylaşır.
class _PrefsStore extends ChangeNotifier {
  _PrefsStore(this.session);

  final Session session;
  Map<String, dynamic>? prefs;
  Object? error;
  String? saveError;

  Map<String, dynamic> get subs => (prefs?['subtypes'] is Map) ? (prefs!['subtypes'] as Map).cast<String, dynamic>() : {};

  Map<String, dynamic>? get quiet => (prefs?['quietHours'] is Map) ? (prefs!['quietHours'] as Map).cast<String, dynamic>() : null;

  Future<void> load() async {
    error = null;
    notifyListeners();
    try {
      prefs = await session.api.get('/notifications/preferences') as Map<String, dynamic>;
    } catch (e) {
      error = e;
    }
    notifyListeners();
  }

  /// Yalnız değişen alan gönderilir (kısmi güncelleme); hatada eski değere dönülür.
  Future<void> _save(Map<String, dynamic> body, void Function() apply) async {
    final old = jsonDecode(jsonEncode(prefs)) as Map<String, dynamic>;
    saveError = null;
    apply();
    notifyListeners();
    try {
      final r = await session.api.put('/notifications/preferences', body);
      if (r is Map<String, dynamic>) prefs = r;
    } catch (e) {
      prefs = old;
      saveError = errorText(e);
    }
    notifyListeners();
  }

  Future<void> set(String key, bool value) => _save({key: value}, () => prefs![key] = value);

  Future<void> setSub(String key, bool value) => _save({
        'subtypes': {key: value}
      }, () {
        prefs!['subtypes'] = Map<String, dynamic>.from(subs)..[key] = value;
      });

  /// Sessiz saat güncellemesi: `enabled` her istekte gönderilir (sunucuda zorunlu bayrak).
  Future<void> setQuiet({bool? enabled, String? start, String? end}) {
    final q = quiet ?? const <String, dynamic>{};
    final en = enabled ?? (q['enabled'] == true);
    return _save({
      'quietHours': {'enabled': en, if (start != null) 'start': start, if (end != null) 'end': end}
    }, () {
      prefs!['quietHours'] = {...q, 'enabled': en, if (start != null) 'start': start, if (end != null) 'end': end};
    });
  }
}

/// Bildirim tercihleri gövdesi (Stitch 50): push durumu, ana anahtarlar, ayrıntılı tercihler, sessiz saatler,
/// "Bu cihazda". Yüklenir, her değişiklik anında kaydedilir, hatada geri alınır.
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
  late final _PrefsStore _store = _PrefsStore(widget.session)..addListener(_onChange);
  String _pushStatus = '...';
  int? _leadMin;

  void _onChange() {
    if (!mounted) return;
    final e = _store.saveError;
    if (e != null) {
      _store.saveError = null;
      BuToast.show(context, e, kind: BuToastKind.error);
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _store.load();
    if (widget.showPushCard) {
      _readPushStatus(widget.push).then((s) {
        if (mounted) setState(() => _pushStatus = s);
      });
    }
    ReminderService.store.load().then((v) {
      if (mounted) setState(() => _leadMin = v.classLeadMin);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  static TimeOfDay _parse(String? s, TimeOfDay fallback) {
    final m = RegExp(r'^(\d{2}):(\d{2})').firstMatch(s ?? '');
    if (m == null) return fallback;
    return TimeOfDay(hour: int.parse(m.group(1)!), minute: int.parse(m.group(2)!));
  }

  static String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isStart) async {
    final q = _store.quiet ?? const <String, dynamic>{};
    final cur = isStart
        ? _parse(q['start'] as String?, const TimeOfDay(hour: 23, minute: 0))
        : _parse(q['end'] as String?, const TimeOfDay(hour: 7, minute: 0));
    final m = await pickAcadTime(context, cur.hour * 60 + cur.minute, help: context.l10n.p20QuietPickHelp);
    if (m == null || !mounted) return;
    final r = TimeOfDay(hour: m ~/ 60, minute: m % 60);
    await _store.setQuiet(start: isStart ? _fmt(r) : null, end: isStart ? null : _fmt(r));
  }

  Widget _card({required Widget child, Color? bar}) {
    final t = context.bu;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(20), boxShadow: BuElevation.of(context, 1)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(children: [
          Padding(padding: EdgeInsets.only(left: bar == null ? 0 : 5), child: child),
          if (bar != null) PositionedDirectional(start: 0, top: 0, bottom: 0, width: 5, child: ColoredBox(color: bar)),
        ]),
      ),
    );
  }

  Widget _label(String text, {double top = 20}) {
    final t = context.bu;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: 6, top: top, bottom: 10),
      child: Semantics(header: true, child: Text(akadUpper(context, text), style: Theme.of(context).textTheme.labelSmall!.copyWith(fontWeight: FontWeight.w700, letterSpacing: .6, color: t.mut))),
    );
  }

  Widget _pushCard() {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final on = _pushStatus == 'on';
    final loading = _pushStatus == '...';
    final pill = AkadPill(on ? l.pushOn : l.profil1PillOff, bg: on ? t.sf2 : t.soft, fg: on ? t.ink : t.onSoft, dot: true);
    if (on || loading) {
      return _card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            AkadIconTile(icon: LucideIcons.bellRing, bg: t.sf2, fg: t.ink, size: 48, radius: 14, iconSize: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.profil1PushTitle, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                if (on) Text(l.profil1PushGranted, style: tx.bodySmall!.copyWith(color: t.mut)),
              ]),
            ),
            if (on) ...[pill, const SizedBox(width: 6), Switch(value: true, onChanged: (_) => PermissionService.instance.openSettings())],
          ]),
        ),
      );
    }
    final note = '${l.pushNotGranted} • ${l.pushNotConfigured}';
    return _card(
      bar: t.pr,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(LucideIcons.bellOff, size: 22, color: t.pr),
            const SizedBox(width: 10),
            Expanded(child: Text(l.profil1PushTitle, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
            pill,
          ]),
          const SizedBox(height: 6),
          Text(l.pushOff, style: tx.bodySmall!.copyWith(color: t.mut)),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BuButton(label: l.p20RemOpenSettings, icon: LucideIcons.settings, compact: true, onPressed: () => PermissionService.instance.openSettings()),
          ),
          const SizedBox(height: 10),
          Text(note, style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: t.mut)),
        ]),
      ),
    );
  }

  Widget _toggleRow(String key, {bool last = false}) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final sub = _prefSub(context, key);
    final on = _store.prefs![key] == true;
    return Column(children: [
      MergeSemantics(
        child: InkWell(
          onTap: () => _store.set(key, !on),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
            child: Row(children: [
              AkadIconTile(icon: _prefIcon(key), bg: t.sf2, fg: t.mut, size: 40, radius: 12, iconSize: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_prefLabel(context, key), style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                  if (sub != null) Text(sub, style: tx.bodySmall!.copyWith(color: t.mut)),
                ]),
              ),
              Switch(value: on, onChanged: (v) => _store.set(key, v)),
            ]),
          ),
        ),
      ),
      if (!last) const AkadDivider(),
    ]);
  }

  Widget _timeBox({required String label, required String value, required bool isStart, required bool active}) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Expanded(
      child: Semantics(
        button: true,
        label: '$label $value',
        excludeSemantics: true,
        onTap: () => _pickTime(isStart),
        child: BuPressable(
          onTap: () => _pickTime(isStart),
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: t.sf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: active ? t.pr : t.bd, width: active ? 2 : 1.5),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(akadUpper(context, label), style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w800, letterSpacing: .6, color: active ? t.pr : t.mut)),
              const SizedBox(height: 2),
              Text(value, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final err = _store.error;
    final prefs = _store.prefs;
    final children = <Widget>[];
    // Yukleme hatasinda push karti cizilmez (referans: yalniz hata satiri + "Bu cihazda").
    if (widget.showPushCard && !(err != null && prefs == null)) children.add(_pushCard());
    if (err != null && prefs == null) {
      children.add(Padding(
        padding: EdgeInsets.zero,
        child: Semantics(
          button: true,
          container: true,
          child: Material(
            color: t.soft,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _store.load,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(LucideIcons.circleAlert, size: 22, color: t.pr),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.p20PrefLoadFail, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: t.onSoft)),
                      Text(l.p20PrefTapRetry, style: tx.bodySmall!.copyWith(color: t.onSoft)),
                    ]),
                  ),
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: t.sf.withValues(alpha: .6), shape: BoxShape.circle), child: Icon(LucideIcons.rotateCw, size: 18, color: t.pr)),
                ]),
              ),
            ),
          ),
        ),
      ));
    } else if (prefs == null) {
      children.add(Padding(
        padding: EdgeInsets.only(top: widget.showPushCard ? 14 : 0),
        child: Semantics(label: l.commonLoading, liveRegion: true, child: const BuSkeletonScope(child: BuSkeleton(height: 220, radius: 20))),
      ));
    } else {
      final optional = [for (final r in _optionalRows) if (prefs.containsKey(r)) r];
      final rows = [..._prefRows, ...optional];
      final subs = _store.subs;
      final hasSubs = [for (final g in _subtypeGroups.values) ...g].any(subs.containsKey);
      final quiet = _store.quiet;
      final quietOn = quiet?['enabled'] == true;
      children
        ..add(_label(l.profil1WhatSection, top: widget.showPushCard ? 22 : 0))
        ..add(Opacity(
          opacity: widget.showPushCard && _pushStatus != 'on' && _pushStatus != '...' ? .5 : 1,
          child: _card(child: Column(children: [for (var i = 0; i < rows.length; i++) _toggleRow(rows[i], last: i == rows.length - 1)])),
        ));
      if (hasSubs) {
        children
          ..add(const SizedBox(height: 14))
          ..add(_card(
            child: Semantics(
              button: true,
              child: InkWell(
                onTap: () => Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => _DetailedPrefsPage(store: _store))),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    AkadIconTile(icon: LucideIcons.slidersHorizontal, bg: t.soft, fg: t.pr, size: 40, radius: 12, iconSize: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.profil1Detailed, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                        Text(l.p20PrefDetailSub, style: tx.bodySmall!.copyWith(color: t.mut)),
                      ]),
                    ),
                    Icon(buDirIcon(context, LucideIcons.chevronRight), size: 20, color: t.mut),
                  ]),
                ),
              ),
            ),
          ));
      }
      if (quiet != null) {
        children
          ..add(_label(l.profil1QuietTitle))
          ..add(_card(
            child: Column(children: [
              InkWell(
                onTap: () => _store.setQuiet(enabled: !quietOn),
                child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 4),
                child: Row(children: [
                  AkadIconTile(icon: LucideIcons.moon, bg: t.sf2, fg: t.mut, size: 40, radius: 12, iconSize: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.profil1QuietToggle, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                      Text(l.profil1QuietSub, style: tx.bodySmall!.copyWith(color: t.mut)),
                    ]),
                  ),
                  Switch(value: quietOn, onChanged: (v) => _store.setQuiet(enabled: v)),
                ]),
              )),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                child: Row(children: [
                  _timeBox(label: l.profil1QuietStart, value: (quiet['start'] as String?) ?? '23:00', isStart: true, active: quietOn),
                  const SizedBox(width: 10),
                  _timeBox(label: l.profil1QuietEnd, value: (quiet['end'] as String?) ?? '07:00', isStart: false, active: false),
                ]),
              ),
            ]),
          ));
      }
    }
    children
      ..add(_label(l.profilePrefsOnThisDevice))
      ..add(_card(
        child: Semantics(
          button: true,
          child: InkWell(
            onTap: () => Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => ReminderSettingsPage(session: widget.session))),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                AkadIconTile(icon: LucideIcons.alarmClock, bg: t.sf2, fg: t.ink, size: 40, radius: 12, iconSize: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.profilePrefsReminders, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                    if (_leadMin != null) Text(l.p20PrefRemSub(_leadMin.toString()), style: tx.bodySmall!.copyWith(color: t.mut)),
                  ]),
                ),
                Icon(buDirIcon(context, LucideIcons.chevronRight), size: 20, color: t.mut),
              ]),
            ),
          ),
        ),
      ));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

/// Ayrıntılı tercihler (Stitch 50-03): grup kartları, iç içe alt anahtarlar; üst kapalıyken alt anahtarlar pasif.
class _DetailedPrefsPage extends StatefulWidget {
  const _DetailedPrefsPage({required this.store});

  final _PrefsStore store;

  @override
  State<_DetailedPrefsPage> createState() => _DetailedPrefsPageState();
}

class _DetailedPrefsPageState extends State<_DetailedPrefsPage> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.store.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Widget _group(String parent) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final store = widget.store;
    final subs = store.subs;
    final kids = [for (final k in _subtypeGroups[parent]!) if (subs.containsKey(k)) k];
    if (kids.isEmpty) return const SizedBox.shrink();
    final on = store.prefs?[parent] == true;
    final groupSub = switch (parent) {
      'messages' => l.p20PrefMsgGroupSub,
      'events' => l.p20PrefEventsGroupSub,
      _ => l.p20PrefClubsGroupSub,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(20), boxShadow: BuElevation.of(context, 1)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              AkadIconTile(icon: _prefIcon(parent), bg: on ? t.ink : t.sf2, fg: on ? t.bg : t.mut, size: 40, radius: 12, iconSize: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(_prefLabel(context, parent), style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                    if (!on) AkadPill(l.p20PrefOffTag, bg: t.sf2, fg: t.mut),
                  ]),
                  Text(groupSub, style: tx.bodySmall!.copyWith(color: t.mut)),
                ]),
              ),
              Switch(value: on, onChanged: (v) => store.set(parent, v)),
            ]),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsetsDirectional.only(start: 18),
              padding: const EdgeInsetsDirectional.only(start: 12),
              decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: t.bd, width: 2))),
              child: Column(children: [
                for (final k in kids)
                  Opacity(
                    opacity: on ? 1 : .45,
                    child: MergeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_prefLabel(context, k), style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                              Text(_subSub(context, k) ?? '', style: tx.bodySmall!.copyWith(color: t.mut)),
                            ]),
                          ),
                          Switch(value: on && subs[k] == true, onChanged: on ? (v) => store.setSub(k, v) : null),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return AcademicScaffold(
      title: l.profil1Notifications,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(20), boxShadow: BuElevation.of(context, 1)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AkadIconTile(icon: LucideIcons.slidersHorizontal, bg: t.soft, fg: t.pr, size: 40, radius: 12, iconSize: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.profil1Detailed, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                  const SizedBox(height: 2),
                  Text(l.p20PrefDetailHead, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.4)),
                ]),
              ),
            ]),
          ),
          for (final g in _subtypeGroups.keys) _group(g),
        ],
      ),
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
    return AcademicScaffold(
      title: context.l10n.profil1Notifications,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [NotificationPrefsGroup(session: session, push: push, showPushCard: true)],
      ),
    );
  }
}

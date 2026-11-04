import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/push/push_health.dart';
import '../../core/push/push_service.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../academic/academic_api.dart';
import '../academic/academic_widgets.dart';
import '../academic/reminder_settings_page.dart';
import '../academic/reminders.dart';
import '../notifications/push_help_page.dart';

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
        onTap: onChanged == null
            ? null
            : () {
                buHaptic(BuHaptic.selection);
                onChanged!(!value);
              },
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
    'messagePreview' => l.p21PreviewTitle,
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
    'messagePreview' => l.p21PreviewSub,
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

class _NotificationPrefsGroupState extends State<NotificationPrefsGroup> with WidgetsBindingObserver {
  late final _PrefsStore _store = _PrefsStore(widget.session)..addListener(_onChange);
  String _pushStatus = '...';
  ReminderSettings? _rem;

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
    WidgetsBinding.instance.addObserver(this);
    _store.load();
    _refreshPushStatus();
    ReminderService.store.load().then((v) {
      if (mounted) setState(() => _rem = v);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.dispose();
    super.dispose();
  }

  void _refreshPushStatus() {
    if (!widget.showPushCard) return;
    _readPushStatus(widget.push).then((s) {
      if (mounted) setState(() => _pushStatus = s);
    });
  }

  /// Sistem ayarlarından dönünce push kartı güncellenir (izin açılmış/kapatılmış olabilir).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPushStatus();
  }

  void _openPushHelp() => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => PushHelpPage(source: SystemPushHealthSource(widget.push))),
      );

  Widget _helpLink() {
    final t = context.bu;
    // İkincil eylem: simgesiz, soluk metin bağlantısı (vurgu rengi yalnız anahtarlarda).
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: _openPushHelp,
        style: TextButton.styleFrom(minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 4)),
        child: Text(context.l10n.p21HelpLink, style: BuType.caption.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: t.mut)),
      ),
    );
  }

  /// Tek yüzey (Stitch v3): beyaz zemin + 1 dp `bd` çerçeve, 16 köşe, gölge yok.
  Widget _card({required Widget child}) => _PrefCard(child: child);

  /// Bölüm başlığı: 17 sp/600, büyük harf/simge yok.
  Widget _section(String text, {double top = 24}) {
    final t = context.bu;
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 12),
      child: Semantics(header: true, child: Text(text, style: BuType.caption.copyWith(fontSize: 17, height: 1.3, fontWeight: FontWeight.w600, color: t.ink))),
    );
  }

  /// Küçük soluk etiket ("Bu cihazda"): 13 sp/500.
  Widget _caption(String text) {
    final t = context.bu;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, top: 24, bottom: 8),
      child: Semantics(header: true, child: Text(text, style: BuType.caption.copyWith(fontSize: 13, height: 1.3, fontWeight: FontWeight.w500, color: t.mut))),
    );
  }

  Widget _chevron() => Icon(buDirIcon(context, BuIcons.chevronRight), size: 20, color: context.bu.mut);

  Widget _pushCard() {
    final l = context.l10n;
    final on = _pushStatus == 'on';
    final loading = _pushStatus == '...';
    if (on || loading) {
      return _card(
        child: _PrefRow(
          title: l.profil1PushTitle,
          sub: on ? l.profil1PushGranted : null,
          strong: true,
          // İzin işletim sistemindedir: uygulama açıp kapatamaz. Sahte anahtar yerine durum + sistem ayarına geçiş.
          onTap: on ? () => PermissionService.instance.openSettings() : null,
          trailing: on
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(l.pushOn, style: BuType.caption.copyWith(fontSize: 14, color: context.bu.mut)),
                  const SizedBox(width: 4),
                  _chevron(),
                ])
              : const SizedBox(height: 28),
        ),
      );
    }
    // Kapalı: tek açıklama + `pr` metin eylemi.
    final t = context.bu;
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.profil1PushTitle, style: BuType.caption.copyWith(fontSize: 16, height: 1.3, fontWeight: FontWeight.w600, color: t.ink)),
          const SizedBox(height: 2),
          Text(_pushStatus == 'notConfigured' ? l.pushNotConfigured : l.pushOff, style: BuType.caption.copyWith(fontSize: 13, height: 1.4, color: t.mut)),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => PermissionService.instance.openSettings(),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48), padding: EdgeInsets.zero),
              child: Text(l.p20RemOpenSettings, style: BuType.caption.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: t.pr)),
            ),
          ),
        ]),
      ),
    );
  }

  /// Ana bayrağa bağlı satırlar (backend kuralı): "Duyurular" kapalıyken genel anket ve akademik duyuru
  /// bildirimi gelmez; kulüp anketi için ayrıca "Topluluklar" gerekir.
  bool _lockedByParent(String key) => (key == 'polls' || key == 'academicAnnouncements') && _store.prefs?['announcements'] != true;

  /// Bağımlılık notu: satır pasifken (ya da anket için Topluluklar kapalıyken) açıklamanın yerine geçer.
  String? _dependencyNote(String key) {
    final l = context.l10n;
    if (key == 'academicAnnouncements' && _lockedByParent(key)) return l.p26PrefNeedsAnnouncements;
    if (key == 'polls' && (_lockedByParent(key) || _store.prefs?['communities'] != true)) return l.p26PrefPollsNeedsParents;
    return null;
  }

  Widget _toggleRow(String key, {bool last = false}) {
    final locked = _lockedByParent(key);
    final on = _store.prefs![key] == true;
    // Anketler / Akademik duyurular tek satırdır (açıklama yok); yalnız bağımlılık notu çıkar.
    final plain = key == 'polls' || key == 'academicAnnouncements';
    return Column(children: [
      // Pasif satır: soluk, dokunulamaz (anahtar da kapalı gibi tepki vermez).
      _PrefRow(
        title: _prefLabel(context, key),
        sub: _dependencyNote(key) ?? (plain ? null : _prefSub(context, key)),
        onTap: locked ? null : () => _store.set(key, !on),
        dim: locked,
        trailing: _PrefSwitch(value: on, onChanged: locked ? null : (v) => _store.set(key, v)),
      ),
      if (!last) const _PrefDivider(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final err = _store.error;
    final prefs = _store.prefs;
    final children = <Widget>[];
    // Yukleme hatasinda push karti cizilmez (referans: yalniz hata satiri + "Bu cihazda").
    if (widget.showPushCard && !(err != null && prefs == null)) {
      children
        ..add(_pushCard())
        ..add(_helpLink());
    }
    if (err != null && prefs == null) {
      // Hata: tek cümle + tek eylem (tüm satır dokunulur).
      children.add(_card(
        child: Semantics(
          button: true,
          container: true,
          child: _PrefRow(title: l.p20PrefLoadFail, sub: l.p20PrefTapRetry, onTap: _store.load, trailing: Icon(BuIcons.rotateCw, size: 20, color: t.mut)),
        ),
      ));
    } else if (prefs == null) {
      children.add(Padding(
        padding: EdgeInsets.only(top: widget.showPushCard ? 16 : 0),
        child: Semantics(label: l.commonLoading, liveRegion: true, child: const BuSkeletonScope(child: BuSkeleton(height: 220, radius: BuRadius.md))),
      ));
    } else {
      final optional = [for (final r in _optionalRows) if (prefs.containsKey(r)) r];
      final rows = [..._prefRows, ...optional];
      final subs = _store.subs;
      final hasSubs = [for (final g in _subtypeGroups.values) ...g].any(subs.containsKey);
      final quiet = _store.quiet;
      final quietOn = quiet?['enabled'] == true;
      children
        ..add(_section(l.profil1WhatSection, top: widget.showPushCard ? 24 : 0))
        ..add(Opacity(
          opacity: widget.showPushCard && _pushStatus != 'on' && _pushStatus != '...' ? .5 : 1,
          child: _card(child: Column(children: [for (var i = 0; i < rows.length; i++) _toggleRow(rows[i], last: i == rows.length - 1)])),
        ));
      // Kilit ekranında mesaj metni (KVKK: varsayılan kapalı; yalnız sunucu `messagePreview` gönderdiyse görünür).
      if (prefs.containsKey('messagePreview')) {
        children
          ..add(const SizedBox(height: 16))
          ..add(_card(child: _toggleRow('messagePreview', last: true)));
      }
      if (hasSubs || quiet != null) {
        children
          ..add(const SizedBox(height: 24))
          ..add(_card(
            child: Column(children: [
              if (hasSubs)
                _PrefRow(
                  title: l.profil1Detailed,
                  trailing: _chevron(),
                  onTap: () => Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => _DetailedPrefsPage(store: _store))),
                ),
              if (hasSubs && quiet != null) const _PrefDivider(),
              if (quiet != null)
                _PrefRow(
                  title: l.profil1QuietTitle,
                  onTap: () => Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => _QuietHoursPage(store: _store))),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(quietOn ? '${(quiet['start'] as String?) ?? '23:00'} – ${(quiet['end'] as String?) ?? '07:00'}' : l.profil1PillOff,
                        style: BuType.caption.copyWith(fontSize: 13, height: 1.4, color: t.mut, fontFeatures: const [FontFeature.tabularFigures()])),
                    const SizedBox(width: 6),
                    _chevron(),
                  ]),
                ),
            ]),
          ));
      }
    }
    // "Bu cihazda": ders ve sınav hatırlatması anahtarı (yerel). Satıra dokunmak ayrıntı sayfasını açar.
    final rem = _rem;
    final remOn = rem != null && (rem.classEnabled || rem.examDayBefore);
    children
      ..add(_caption(l.profilePrefsOnThisDevice))
      ..add(_card(
        child: _PrefRow(
          title: l.profilePrefsReminders,
          onTap: () => Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => ReminderSettingsPage(session: widget.session))),
          trailing: _PrefSwitch(value: remOn, onChanged: rem == null ? null : _setReminders),
        ),
      ));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  /// Ders + sınav hatırlatmalarını birlikte açar/kapatır (ayrıntı: Akademik > Hatırlatmalar sayfası).
  void _setReminders(bool v) {
    final cur = _rem;
    if (cur == null) return;
    final s = cur.copyWith(classEnabled: v, examDayBefore: v);
    setState(() => _rem = s);
    ReminderService.store.save(s);
    unawaited(ReminderService.sync(AcademicApi(widget.session), settings: s));
  }
}

TimeOfDay _parseTime(String? s, TimeOfDay fallback) {
  final m = RegExp(r'^(\d{2}):(\d{2})').firstMatch(s ?? '');
  if (m == null) return fallback;
  return TimeOfDay(hour: int.parse(m.group(1)!), minute: int.parse(m.group(2)!));
}

String _fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

Future<void> _pickQuietTime(BuildContext context, _PrefsStore store, bool isStart) async {
  final q = store.quiet ?? const <String, dynamic>{};
  final cur = isStart
      ? _parseTime(q['start'] as String?, const TimeOfDay(hour: 23, minute: 0))
      : _parseTime(q['end'] as String?, const TimeOfDay(hour: 7, minute: 0));
  final m = await pickAcadTime(context, cur.hour * 60 + cur.minute, help: context.l10n.p20QuietPickHelp);
  if (m == null) return;
  final r = TimeOfDay(hour: m ~/ 60, minute: m % 60);
  await store.setQuiet(start: isStart ? _fmtTime(r) : null, end: isStart ? null : _fmtTime(r));
}

/// Tercih yüzeyi: beyaz + 1 dp `bd` çerçeve, 16 köşe, gölge yok; içerik köşede kırpılır.
class _PrefCard extends StatelessWidget {
  const _PrefCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => BuCard(
        radius: 22,
        style: BuCardStyle.elevated,
        padding: EdgeInsets.zero,
        child: child,
      );
}

class _PrefDivider extends StatelessWidget {
  const _PrefDivider();

  @override
  Widget build(BuildContext context) => Divider(height: 1, thickness: 1, color: context.bu.bd);
}

/// Ortak tercih satırı (iç 16 dp): başlık 15 sp/500 (+ 13 sp soluk açıklama) solda, kontrol sağda.
class _PrefRow extends StatelessWidget {
  const _PrefRow({required this.title, required this.trailing, this.sub, this.onTap, this.dim = false, this.strong = false});

  final String title;
  final String? sub;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool dim;

  /// Üst "Anlık bildirimler" satırı: 16 sp/600.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Opacity(
      opacity: dim ? .5 : 1,
      child: MergeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 28),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(title,
                        style: BuType.caption.copyWith(
                            fontSize: strong ? 16 : 15, height: 1.5, fontWeight: strong ? FontWeight.w600 : FontWeight.w500, color: t.ink)),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(sub!, style: BuType.caption.copyWith(fontSize: 13, height: 1.5, color: t.mut)),
                    ],
                  ]),
                ),
                const SizedBox(width: 12),
                trailing,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Anahtar (Stitch v3): 48 x 28 dp, 24 dp beyaz topuz; açık = `pr` iz, kapalı = `bd` iz (çerçevesiz).
/// Malzeme `Switch` (erişilebilirlik/test aynı) küçültülerek çizilir.
class _PrefSwitch extends StatelessWidget {
  const _PrefSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final theme = Theme.of(context).copyWith(
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(t.onPr),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.pr : t.bd),
        trackOutlineColor: WidgetStatePropertyAll(t.bd.withValues(alpha: 0)),
        // Simge verilince Material 3 kapalı topuzu da 24 dp çizer (Stitch: iki durumda aynı topuz).
        thumbIcon: const WidgetStatePropertyAll(Icon(null)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
    return SizedBox(
      width: 48,
      height: 28,
      child: OverflowBox(
        maxWidth: 52,
        maxHeight: 32,
        child: Transform.scale(
          scale: 48 / 52,
          child: Theme(data: theme, child: Switch(value: value, onChanged: onChanged)),
        ),
      ),
    );
  }
}

/// Ayrıntılı tercihler: ana bayrak başına bir yüzey; üstte ana anahtar, altında 1 dp çizgili alt anahtarlar
/// (üst kapalıyken soluk ve pasif).
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
    final store = widget.store;
    final subs = store.subs;
    final kids = [for (final k in _subtypeGroups[parent]!) if (subs.containsKey(k)) k];
    if (kids.isEmpty) return const SizedBox.shrink();
    final on = store.prefs?[parent] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _PrefCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Ana anahtar: grup başlığı.
          _PrefRow(title: _prefLabel(context, parent), strong: true, trailing: _PrefSwitch(value: on, onChanged: (v) => store.set(parent, v))),
          for (final k in kids) ...[
            const _PrefDivider(),
            _PrefRow(
              title: _prefLabel(context, k),
              sub: _subSub(context, k),
              dim: !on,
              trailing: _PrefSwitch(value: on && subs[k] == true, onChanged: on ? (v) => store.setSub(k, v) : null),
            ),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: l.profil1Detailed, onBack: () => Navigator.pop(context)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [for (final g in _subtypeGroups.keys) _group(g)],
          ),
        ),
      ]),
    );
  }
}

/// Sessiz saatler sayfası: aç/kapat + başlangıç/bitiş saati (yerel saat seçici; istek biçimi değişmedi).
class _QuietHoursPage extends StatefulWidget {
  const _QuietHoursPage({required this.store});

  final _PrefsStore store;

  @override
  State<_QuietHoursPage> createState() => _QuietHoursPageState();
}

class _QuietHoursPageState extends State<_QuietHoursPage> {
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

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final quiet = widget.store.quiet ?? const <String, dynamic>{};
    final on = quiet['enabled'] == true;
    final time = BuType.caption.copyWith(fontSize: 15, height: 1.3, color: t.mut, fontFeatures: const [FontFeature.tabularFigures()]);
    Widget timeRow(String label, String value, bool isStart) => _PrefRow(
          title: label,
          dim: !on,
          onTap: () => _pickQuietTime(context, widget.store, isStart),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(value, style: time),
            const SizedBox(width: 6),
            Icon(buDirIcon(context, BuIcons.chevronRight), size: 20, color: t.mut),
          ]),
        );
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: l.profil1QuietTitle, onBack: () => Navigator.pop(context)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _PrefCard(
                child: Column(children: [
                  _PrefRow(
                    title: l.profil1QuietToggle,
                    sub: l.profil1QuietSub,
                    onTap: () => widget.store.setQuiet(enabled: !on),
                    trailing: _PrefSwitch(value: on, onChanged: (v) => widget.store.setQuiet(enabled: v)),
                  ),
                  const _PrefDivider(),
                  timeRow(l.profil1QuietStart, (quiet['start'] as String?) ?? '23:00', true),
                  const _PrefDivider(),
                  timeRow(l.profil1QuietEnd, (quiet['end'] as String?) ?? '07:00', false),
                ]),
              ),
            ],
          ),
        ),
      ]),
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
      body: Column(children: [
        BuHeader(title: context.l10n.profil1Notifications, onBack: () => Navigator.pop(context)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [NotificationPrefsGroup(session: session, push: push, showPushCard: true)],
          ),
        ),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../l10n/app_localizations.dart';
import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../clubs/clubs_tab.dart';
import 'etkinlik2_widgets.dart';
import 'event_cover.dart';
import 'event_detail_page.dart';
import 'event_parts.dart';

/// Görsel seçici: kaynak verilir, hazırlanmış görsel (ya da iptalde null) döner. Testte değiştirilebilir.
typedef CoverPicker = Future<PreparedImage?> Function(ImageSource source);

/// Kapak yükleyici: `PUT /events/{id}/cover`. Testte değiştirilebilir.
typedef CoverUploader = Future<dynamic> Function(String path, PreparedImage image);

/// Kapağı yükler; başarısızsa "Tekrar dene" eylemli bildirim gösterir (sessizce yutmaz). Başarıyı döner.
Future<bool> uploadEventCover({
  required ScaffoldMessengerState messenger,
  required Session session,
  required int eventId,
  required PreparedImage image,
  required bool eventAlreadyCreated,
  CoverUploader? uploader,
}) async {
  final up = uploader ??
      (path, img) => MultipartUploader(session).upload(path, img, method: 'PUT');
  final l10n = messenger.context.l10n; // await'ten önce al: sayfa kapanmış olabilir
  try {
    await up('/events/$eventId/cover', image);
    return true;
  } catch (e) {
    final reason = e is ApiError && !e.isNetwork && e.message.isNotEmpty ? ' ${e.message}' : '';
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(eventAlreadyCreated
            ? l10n.eventFormCoverCreatedFail(reason)
            : l10n.eventFormCoverFail(reason)),
        action: SnackBarAction(
          label: l10n.eventFormRetry,
          onPressed: () => uploadEventCover(
            messenger: messenger,
            session: session,
            eventId: eventId,
            image: image,
            eventAlreadyCreated: eventAlreadyCreated,
            uploader: uploader,
          ),
        ),
      ));
    return false;
  }
}

/// Kulüp etkinlik oluşturabilir mi? Yönetici (OWNER/ADMIN/MODERATOR) doğrudan yayınlar;
/// `MANAGE_EVENTS` izinli üye onaya gönderir; diğerleri oluşturamaz (null).
/// Dönüş: true = hemen yayınlanır, false = admin onayına gider, null = oluşturamaz.
bool? eventClubPublishMode(Map<String, dynamic> club) {
  final st = club['myStatus'];
  if (st != null && st != 'ACTIVE') return null;
  final role = club['myRole'];
  if (role == 'OWNER' || role == 'ADMIN' || role == 'MODERATOR') return true;
  final perms = club['myPermissions'] ?? club['permissions'];
  if (club['canManageEvents'] == true || (perms is List && perms.contains('MANAGE_EVENTS'))) {
    return false;
  }
  return null;
}

/// Etkinlik oluşturma / düzenleme. [event] verilirse düzenleme (PATCH), yoksa oluşturma (POST).
/// Kapak, etkinlik kaydedildikten SONRA ayrı uçla yüklenir. Kaydedilirse `true` ile kapanır.
class EventFormPage extends StatefulWidget {
  const EventFormPage({
    super.key,
    required this.session,
    this.event,
    this.communityId,
    this.pickCover,
    this.uploadCover,
    this.now,
  });

  final Session session;
  final Map<String, dynamic>? event;
  final int? communityId;
  final CoverPicker? pickCover;
  final CoverUploader? uploadCover;

  /// Yalnız test amaçlı: "şimdi" kaynağı (varsayılan DateTime.now); zamana bağlı varsayılanları sabitler.
  final DateTime Function()? now;

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<EventFormPage> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _place = TextEditingController();
  final _cap = TextEditingController();
  late DateTime _start;
  late DateTime _end;
  DateTime? _origStart; // düzenlemede: başlangıç değişmediyse geçmiş kuralı uygulanmaz
  bool _endAdjusted = false;
  static const _descMax = 1000; // backend ile aynı
  static const _titleMax = 100;
  PreparedImage? _picked; // yeni seçilen kapak
  bool _removeCover = false;
  String? _existingCover;
  bool _busy = false;
  String? _error;
  String _policy = 'OPEN'; // OPEN | APPROVAL
  int? _clubId;
  String? _clubName;
  List<Map<String, dynamic>>? _clubs; // etkinlik açabileceğim kulüpler (oluşturmada açılışta yüklenir)
  Object? _clubsError;
  bool _clubInstant = true; // seçili kulüpte etkinlik hemen yayınlanır mı
  bool _clubErr = false; // kaydet denendi ama kulüp seçilmedi

  late final ImageService _images = ImageService();

  bool get _editing => widget.event != null;
  int? get _id => (widget.event?['id'] as num?)?.toInt();

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    if (e != null) {
      _title.text = '${e['title'] ?? ''}';
      _desc.text = '${e['description'] ?? ''}';
      _place.text = '${e['location'] ?? ''}';
      final cap = (e['capacity'] as num?)?.toInt();
      if (cap != null) _cap.text = '$cap';
      _existingCover = fileUrl(e['coverUrl'] as String?);
      _policy = e['joinPolicy'] == 'APPROVAL' ? 'APPROVAL' : 'OPEN';
      _clubId = (e['communityId'] as num?)?.toInt();
      _clubName = e['communityName'] as String?;
    } else {
      _loadClubs();
    }
    final base = _nextRoundHour();
    _start = DateTime.tryParse('${e?['startsAt']}')?.toLocal() ?? base;
    _end = DateTime.tryParse('${e?['endsAt']}')?.toLocal() ?? _start.add(const Duration(hours: 2));
    _origStart = e == null ? null : _start;
    _desc.addListener(() => setState(() {})); // canlı sayaç
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _place.dispose();
    _cap.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  // ---- kapak ----

  Future<PreparedImage?> _pick(ImageSource s) =>
      widget.pickCover != null ? widget.pickCover!(s) : _images.pickPrepared(s);

  Future<void> _chooseCover() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.bu.sf,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          BuMenuRow(
              icon: LucideIcons.image,
              label: c.l10n.eventFormPickGallery,
              showChevron: false,
              onTap: () => Navigator.pop(c, ImageSource.gallery)),
          BuMenuRow(
              icon: LucideIcons.camera,
              label: c.l10n.eventFormTakePhoto,
              showChevron: false,
              onTap: () => Navigator.pop(c, ImageSource.camera)),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final img = await _pick(source);
      if (img != null && mounted) {
        setState(() {
          _picked = img;
          _removeCover = false;
        });
      }
    } on ImageException catch (e) {
      if (!mounted) return;
      final l = context.l10n;
      _toast(e.code == 'TOO_LARGE'
          ? l.eventFormImgTooLarge
          : e.code == 'UNSUPPORTED_TYPE'
              ? l.eventFormImgUnsupported
              : l.eventFormImgUnreadable);
    } catch (_) {
      if (!mounted) return;
      _toast(context.l10n.eventFormImgPickFail);
    }
  }

  void _clearCover() => setState(() {
        if (_picked != null) {
          _picked = null;
        } else {
          _removeCover = true;
        }
      });

  // ---- tarih ----

  DateTime _now() => (widget.now ?? DateTime.now)();

  DateTime _nextRoundHour() {
    final n = _now();
    return DateTime(n.year, n.month, n.day, n.hour + 1);
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Satır içi tarih hatası (yoksa null). Düzenlemede başlangıç değişmediyse geçmiş kuralı yok.
  String? get _dateError {
    final l = context.l10n;
    final changed = !_editing || _origStart != _start;
    if (changed && _start.isBefore(_now().subtract(const Duration(minutes: 1)))) {
      return l.evdErrStartPast;
    }
    if (!_end.isAfter(_start)) return l.evdErrEndBeforeStart;
    return null;
  }

  /// Başlangıcı değiştirir; süre korunur, bitiş geçersiz kalırsa başlangıç+1 sa'e çekilir ve bildirilir.
  void _setStart(DateTime v) {
    final len = _end.difference(_start);
    _start = v;
    if (len <= Duration.zero) {
      _end = v.add(const Duration(hours: 1));
      _endAdjusted = true;
    } else {
      _end = v.add(len);
      _endAdjusted = false;
    }
  }

  void _setStartDate(DateTime d) {
    var v = DateTime(d.year, d.month, d.day, _start.hour, _start.minute);
    // Bugünün geçmiş saatine düşerse sıradaki yuvarlak saate al.
    if (v.isBefore(_now())) {
      final r = _nextRoundHour();
      v = _day(r) == _day(v) ? r : DateTime(d.year, d.month, d.day, 9);
    }
    setState(() => _setStart(v));
  }

  void _setStartTime(int h, int m) =>
      setState(() => _setStart(DateTime(_start.year, _start.month, _start.day, h, m)));

  void _setDuration(Duration d) => setState(() {
        _end = _start.add(d);
        _endAdjusted = false;
      });

  Future<void> _pickStartDate() async {
    final today = _day(_now());
    final first = _start.isBefore(today) ? _day(_start) : today;
    final d = await showDatePicker(
      context: context,
      initialDate: _start.isBefore(first) ? first : _start,
      firstDate: first,
      lastDate: DateTime(_now().year + 3),
    );
    if (d == null || !mounted) return;
    _setStartDate(d);
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) => showTimePicker(
        context: context,
        initialTime: initial,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        ),
      );

  Future<void> _pickCustomTime() async {
    final t = await _pickTime(TimeOfDay.fromDateTime(_start));
    if (t == null || !mounted) return;
    _setStartTime(t.hour, t.minute);
  }

  /// Çok günlü etkinlik: bitiş tarihi (ve saati) ayrı seçilir; en erken başlangıç günü.
  Future<void> _pickEnd() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _end.isBefore(_start) ? _start : _end,
      firstDate: _day(_start),
      lastDate: DateTime(_now().year + 3),
    );
    if (d == null || !mounted) return;
    final t = await _pickTime(TimeOfDay.fromDateTime(_end));
    if (t == null || !mounted) return;
    setState(() {
      _end = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      _endAdjusted = false;
    });
  }

  String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _dayText(DateTime d) {
    final loc = Localizations.localeOf(context).toString();
    try {
      return DateFormat('E, d MMMM', loc).format(d);
    } catch (_) {
      return DateFormat('E, d MMMM').format(d);
    }
  }

  /// 'Cum, 31 Ekim · 14:00 – 16:00' (çok günlüde iki tarih).
  String get _summary => _day(_start) == _day(_end)
      ? '${_dayText(_start)} · ${_hm(_start)} – ${_hm(_end)}'
      : '${_dayText(_start)} ${_hm(_start)} – ${_dayText(_end)} ${_hm(_end)}';

  Widget _chip(BuTokens t, String label, bool on, VoidCallback? onTap) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      selected: on,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: on ? t.pr : t.sf,
        shape: StadiumBorder(side: BorderSide(color: on ? t.pr : t.bd)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                widthFactor: 1,
                child: Text(label,
                    style: BuType.label.copyWith(
                        fontWeight: FontWeight.w700,
                        color: !enabled ? t.mut.withValues(alpha: .5) : (on ? t.onPr : t.ink))),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateSection(BuTokens t, AppLocalizations l) {
    final today = _day(_now());
    final tomorrow = today.add(const Duration(days: 1));
    final wd = today.weekday; // Pzt=1 .. Paz=7
    final weekend = today.add(Duration(days: wd >= 6 ? 0 : 6 - wd));
    final nextWeek = today.add(Duration(days: 8 - wd));
    final sd = _day(_start);
    final dur = _end.difference(_start);
    final presetDate = [today, tomorrow, weekend, nextWeek].contains(sd);
    const hours = [(9, 0), (12, 0), (14, 0), (18, 0), (20, 0)];
    final presetTime = hours.any((h) => h.$1 == _start.hour && h.$2 == _start.minute);
    final locked = _busy;
    final err = _dateError;
    final dayChips = <(String, DateTime)>[
      (l.evdChipToday, today),
      (l.evdChipTomorrow, tomorrow),
      (l.evdChipWeekend, weekend),
      (l.evdChipNextWeek, nextWeek),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(t, l.evdLabelDate),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in dayChips)
          _chip(t, c.$1, sd == c.$2, locked ? null : () => _setStartDate(c.$2)),
        _chip(t, l.evdChipPickDate, !presetDate, locked ? null : _pickStartDate),
      ]),
      const SizedBox(height: 14),
      _label(t, l.evdLabelTime),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final h in hours)
          _chip(
            t,
            '${h.$1.toString().padLeft(2, '0')}:${h.$2.toString().padLeft(2, '0')}',
            _start.hour == h.$1 && _start.minute == h.$2,
            // Bugünse geçmiş saat seçilemez.
            (locked || DateTime(sd.year, sd.month, sd.day, h.$1, h.$2).isBefore(_now()))
                ? null
                : () => _setStartTime(h.$1, h.$2),
          ),
        _chip(t, l.evdChipCustomTime, !presetTime, locked ? null : _pickCustomTime),
      ]),
      const SizedBox(height: 14),
      _label(t, l.evdLabelDuration),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _chip(t, l.evdDur1h, dur == const Duration(hours: 1), locked ? null : () => _setDuration(const Duration(hours: 1))),
        _chip(t, l.evdDur2h, dur == const Duration(hours: 2), locked ? null : () => _setDuration(const Duration(hours: 2))),
        _chip(t, l.evdDurHalfDay, dur == const Duration(hours: 4), locked ? null : () => _setDuration(const Duration(hours: 4))),
        _chip(
            t,
            l.evdChipCustomEnd,
            (dur != const Duration(hours: 1) && dur != const Duration(hours: 2) && dur != const Duration(hours: 4)) || _day(_end) != sd,
            locked ? null : _pickEnd),
      ]),
      const SizedBox(height: 12),
      Semantics(
        label: _summary,
        child: Container(
          key: const ValueKey('evd-summary'),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: t.soft,
            borderRadius: BorderRadius.circular(16),
            border: err == null ? null : Border.all(color: t.danger),
          ),
          child: Row(children: [
            Icon(LucideIcons.calendarDays, size: 20, color: t.pr),
            const SizedBox(width: 10),
            Expanded(child: Text(_summary, style: BuType.label.copyWith(fontWeight: FontWeight.w700, color: t.ink))),
          ]),
        ),
      ),
      if (_endAdjusted && err == null)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, top: 6),
          child: Text(l.evdEndAdjusted, key: const ValueKey('evd-adjusted'), style: BuType.caption.copyWith(color: t.mut)),
        ),
      if (err != null)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, top: 6),
          child: Text(err, key: const ValueKey('evd-error'), style: BuType.label.copyWith(color: t.danger)),
        ),
    ]);
  }

  // ---- kaydet ----

  Future<void> _save() async {
    if (_busy) return;
    final title = _title.text.trim();
    if (title.length < 3) {
      setState(() => _error = context.l10n.eventFormTitleTooShort);
      return;
    }
    if (_desc.text.trim().length > _descMax) {
      setState(() => _error = context.l10n.evdErrDescTooLong('$_descMax'));
      return;
    }
    final dateErr = _dateError;
    if (dateErr != null) {
      setState(() => _error = dateErr);
      return;
    }
    if (!_editing && _clubId == null) {
      setState(() {
        _clubErr = true;
        _error = context.l10n.evcClubRequiredHint;
      });
      return;
    }
    final capText = _cap.text.trim();
    final cap = capText.isEmpty ? null : int.tryParse(capText);
    if (capText.isNotEmpty && (cap == null || cap < 1)) {
      setState(() => _error = context.l10n.eventFormCapInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final api = widget.session.api;
    try {
      var id = _id;
      var coverOk = true;
      String? status;
      if (_editing) {
        await api.patch('/events/$id', {
          'title': title,
          'description': _desc.text.trim(),
          'startsAt': _start.toUtc().toIso8601String(),
          'endsAt': _end.toUtc().toIso8601String(),
          'location': _place.text.trim(),
          'capacity': cap ?? 0,
          'joinPolicy': _policy,
        });
      } else {
        final r = await api.post('/events', {
          'title': title,
          if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
          'startsAt': _start.toUtc().toIso8601String(),
          'endsAt': _end.toUtc().toIso8601String(),
          if (_place.text.trim().isNotEmpty) 'location': _place.text.trim(),
          if (cap != null) 'capacity': cap,
          'communityId': _clubId,
          'joinPolicy': _policy,
        });
        id = r is Map ? (r['id'] as num?)?.toInt() : null;
        status = r is Map ? r['status'] as String? : null;
      }
      // Etkinlik kaydedildi; kapak hatası etkinliği geri almaz, ayrıca bildirilir.
      if (id != null) {
        if (_picked != null) {
          coverOk = await uploadEventCover(
            messenger: messenger,
            session: widget.session,
            eventId: id,
            image: _picked!,
            eventAlreadyCreated: !_editing,
            uploader: widget.uploadCover,
          );
        } else if (_removeCover && _editing) {
          try {
            await api.delete('/events/$id/cover');
          } catch (e) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(l10n.eventFormCoverRemoveFail(errorText(e)))));
          }
        }
      }
      if (!mounted) return;
      if (!_editing && status == 'PENDING_REVIEW') {
        // Onaya düştü: kullanıcıya açık bilgi, sonra liste (Oluşturduklarım'da rozetli).
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(c.l10n.evcSubmittedTitle, style: BuType.heading.copyWith(color: c.bu.ink)),
            content: Text(c.l10n.evcSubmittedBody, style: BuType.body.copyWith(color: c.bu.mut)),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(c.l10n.evcOk))],
          ),
        );
        if (!mounted) return;
        nav.pop(true);
        return;
      }
      // Kapak hatası bildirimi varsa üstüne yazılmaması için yalnızca başarılıysa gösterilir.
      if (!_editing && coverOk) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.eventFormCreated)));
      }
      if (!_editing && status == 'ACTIVE' && id != null) {
        final newId = id;
        nav.pushReplacement(
          MaterialPageRoute<bool>(builder: (_) => EventDetailPage(session: widget.session, eventId: newId)),
          result: true,
        );
        return;
      }
      nav.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = eventSaveErrorText(context, e);
      });
    }
  }

  // ---- kulüp (zorunlu) ----

  Future<void> _loadClubs() async {
    setState(() {
      _clubs = null;
      _clubsError = null;
    });
    try {
      final r = await widget.session.api.get('/me/communities?size=50');
      final items = (r is Map ? r['items'] : null) as List? ?? const [];
      final out = <Map<String, dynamic>>[
        for (final c in items.whereType<Map>())
          if (eventClubPublishMode(Map<String, dynamic>.from(c)) != null) Map<String, dynamic>.from(c),
      ];
      if (!mounted) return;
      setState(() {
        _clubs = out;
        // Tek kulüp ya da dışarıdan verilen kulüp otomatik seçilir; çoklu kulüpte seçim zorunlu.
        Map<String, dynamic>? pre;
        if (widget.communityId != null) {
          for (final c in out) {
            if ((c['id'] as num?)?.toInt() == widget.communityId) pre = c;
          }
        }
        pre ??= out.length == 1 ? out.first : null;
        if (pre != null) _selectClub(pre);
      });
    } catch (e) {
      if (mounted) setState(() => _clubsError = e);
    }
  }

  void _selectClub(Map<String, dynamic> c) {
    _clubId = (c['id'] as num?)?.toInt();
    _clubName = c['name'] as String?;
    _clubInstant = eventClubPublishMode(c) == true;
    _clubErr = false;
    _error = null;
  }

  Future<void> _chooseClub() async {
    final clubs = _clubs ?? const <Map<String, dynamic>>[];
    if (clubs.length < 2) return;
    final t = context.bu;
    final l = context.l10n;
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: t.sf,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * .7),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 12), children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(l.etkinlik2ClubSheetTitle, style: BuType.heading.copyWith(color: t.ink)),
            ),
            for (final club in clubs)
              BuMenuRow(
                  icon: LucideIcons.users,
                  label: '${club['name'] ?? ''}',
                  showChevron: false,
                  onTap: () => Navigator.pop(c, club)),
          ]),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectClub(picked));
  }

  void _browseClubs() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => Scaffold(body: ClubsTab(session: widget.session))),
      );

  Widget _noClubView(BuTokens t, BuildContext context) {
    final l = context.l10n;
    return Column(children: [
      BuHeader(title: l.eventFormNewTitle, onBack: () => Navigator.pop(context)),
      Expanded(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.users, size: 44, color: t.mut),
              const SizedBox(height: 14),
              Text(l.evcEmptyTitle, textAlign: TextAlign.center, style: BuType.heading.copyWith(color: t.ink)),
              const SizedBox(height: 8),
              Text(l.evcEmptyBody, textAlign: TextAlign.center, style: BuType.body.copyWith(color: t.mut)),
              const SizedBox(height: 20),
              BuButton(label: l.evcBrowseClubs, onPressed: _browseClubs),
            ]),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final narrow = MediaQuery.of(context).size.width < 340;
    if (!_editing) {
      if (_clubsError != null) {
        return Scaffold(
          backgroundColor: t.bg,
          body: Column(children: [
            BuHeader(title: l.eventFormNewTitle, onBack: () => Navigator.pop(context)),
            Expanded(child: ErrorView(error: _clubsError!, onRetry: _loadClubs)),
          ]),
        );
      }
      if (_clubs == null) {
        return Scaffold(
          backgroundColor: t.bg,
          body: Column(children: [
            BuHeader(title: l.eventFormNewTitle, onBack: () => Navigator.pop(context)),
            const Expanded(child: LoadingView()),
          ]),
        );
      }
      if (_clubs!.isEmpty) return Scaffold(backgroundColor: t.bg, body: _noClubView(t, context));
    }
    final multiClub = !_editing && (_clubs?.length ?? 0) > 1;
    final clubField = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(t, l.evcLabelClub),
      Semantics(
        button: true,
        label: '${l.evcLabelClub}: ${_clubName ?? l.etkinlik2ClubSheetTitle}',
        excludeSemantics: true,
        onTap: _busy || !multiClub ? null : _chooseClub,
        child: BuCard(
          key: const ValueKey('et2-club-field'),
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          onTap: _busy || !multiClub ? null : _chooseClub,
          child: SizedBox(
            height: 53,
            child: Row(children: [
              Expanded(
                child: Text(_clubName ?? l.etkinlik2ClubSheetTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BuType.label.copyWith(
                        fontWeight: FontWeight.w600, color: _clubErr ? t.danger : (_clubName == null ? t.mut : t.ink))),
              ),
              if (multiClub) Icon(LucideIcons.chevronDown, size: 18, color: t.mut),
            ]),
          ),
        ),
      ),
      if (!_editing && _clubId != null)
        Padding(
          key: const ValueKey('evc-club-info'),
          padding: const EdgeInsetsDirectional.only(start: 2, top: 6),
          child: Text(_clubInstant ? l.evcInfoInstant : l.evcInfoReview,
              style: BuType.caption.copyWith(color: t.mut)),
        ),
    ]);
    final capField = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(t, l.etkinlik2CapacityOptional),
      TextField(
        controller: _cap,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: BuType.body.copyWith(color: t.ink),
        decoration: InputDecoration(hintText: l.etkinlik2Unlimited),
      ),
    ]);
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(
            title: _editing ? l.eventFormEditTitle : l.eventFormNewTitle,
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              children: [
                _coverBox(t),
                const SizedBox(height: 14),
                _label(t, l.eventFormFieldTitle),
                TextField(
                  controller: _title,
                  maxLength: _titleMax,
                  textCapitalization: TextCapitalization.sentences,
                  style: BuType.body.copyWith(color: t.ink),
                  decoration: InputDecoration(hintText: l.eventFormTitleHint, counterText: ''),
                ),
                const SizedBox(height: 12),
                _label(t, l.eventFormFieldDesc),
                TextField(
                  controller: _desc,
                  maxLength: _descMax + 200, // aşımda yazılabilir; sayaç kızarır, gönderme kapanır
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  minLines: 3,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  style: BuType.body.copyWith(color: t.ink),
                  decoration: InputDecoration(
                    hintText: l.eventFormDescHint,
                    counterText: '',
                    errorText: _desc.text.length > _descMax ? l.evdErrDescTooLong('$_descMax') : null,
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, right: 2, left: 2),
                    child: Text(l.evdDescCounter('${_desc.text.length}', '$_descMax'),
                        key: const ValueKey('evd-desc-counter'),
                        style: BuType.caption.copyWith(color: _desc.text.length > _descMax ? t.danger : t.mut)),
                  ),
                ),
                const SizedBox(height: 12),
                _dateSection(t, l),
                const SizedBox(height: 12),
                _label(t, l.eventFormPlace),
                TextField(
                  controller: _place,
                  maxLength: 200,
                  style: BuType.body.copyWith(color: t.ink),
                  decoration: InputDecoration(hintText: l.eventFormPlaceHint, counterText: ''),
                ),
                const SizedBox(height: 12),
                _label(t, l.etkinlik2JoinPolicyLabel),
                Et2Segment<String>(
                  value: _policy,
                  enabled: !_busy,
                  options: [('OPEN', l.etkinlik2PolicyOpen), ('APPROVAL', l.etkinlik2PolicyApproval)],
                  onChanged: (v) => setState(() => _policy = v),
                ),
                if (_policy == 'APPROVAL')
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 2, top: 6),
                    child: Text(l.etkinlik2PolicyApprovalHint, style: BuType.caption.copyWith(color: t.mut)),
                  ),
                const SizedBox(height: 12),
                narrow
                    ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        capField,
                        const SizedBox(height: 12),
                        clubField,
                      ])
                    : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 10, child: capField),
                        const SizedBox(width: 12),
                        Expanded(flex: 13, child: clubField),
                      ]),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  constraints: const BoxConstraints(minHeight: 56),
                  decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(12)),
                      child: Icon(LucideIcons.messageCircle, size: 20, color: t.pr),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.etkinlik2ChatAutoTitle, style: BuType.label.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                        Text(l.etkinlik2ChatAutoBody, style: BuType.caption.copyWith(height: 1.4, color: t.mut)),
                      ]),
                    ),
                  ]),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: BuType.label.copyWith(color: t.danger)),
                ],
              ],
            ),
          ),
          Et2BottomBar(
            child: BuButton(
              label: _editing ? l.eventFormSave : l.eventFormCreate,
              busy: _busy,
              onPressed: (_desc.text.length > _descMax || _dateError != null) ? null : _save,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(BuTokens t, String s) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 2, bottom: 6),
        child: Text(s, style: BuType.label.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
      );

  /// 16:9 minimal kapak kutusu: boşken "Kapak fotoğrafı ekle", doluyken önizleme + değiştir/kaldır.
  Widget _coverBox(BuTokens t) {
    final Uint8List? bytes = _picked?.bytes;
    final existing = _removeCover ? null : _existingCover;
    final has = bytes != null || existing != null;
    final radius = BorderRadius.circular(18);
    if (!has) {
      return Semantics(
        button: true,
        label: context.l10n.eventFormAddCover,
        excludeSemantics: true,
        onTap: _busy ? null : _chooseCover,
        child: Material(
          color: t.sf,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _busy ? null : _chooseCover,
            child: Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.bd, width: 1.5),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Et2IconBox(LucideIcons.image),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(context.l10n.eventFormAddCover,
                      textAlign: TextAlign.center,
                      style: BuType.label.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                ),
              ]),
            ),
          ),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(bytes,
                  fit: BoxFit.cover,
                  cacheWidth: 800,
                  errorBuilder: (_, __, ___) => ColoredBox(color: t.soft))
            else
              EventCoverImage(url: existing!),
            if (has)
              PositionedDirectional(
                top: 8,
                end: 8,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _glass(LucideIcons.pencil, context.l10n.eventFormChangeCover, _busy ? null : _chooseCover),
                  const SizedBox(width: 8),
                  _glass(LucideIcons.trash2, context.l10n.eventFormRemoveCover, _busy ? null : _clearCover),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _glass(IconData icon, String tip, VoidCallback? onTap) => Tooltip(
        message: tip,
        child: Material(
          color: Colors.black.withValues(alpha: .45),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 18, color: Colors.white)),
          ),
        ),
      );
}

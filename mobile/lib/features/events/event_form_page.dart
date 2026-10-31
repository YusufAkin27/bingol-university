import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../l10n/app_localizations.dart';
import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../clubs/clubs_tab.dart';
import '../media_crop/media_crop.dart';
import 'etkinlik2_widgets.dart';
import '../clubs/clubs_widgets.dart' show ClubPageHeader, ClubsLogo, DashedRRectPainter;
import 'event_cover.dart';
import 'event_detail_page.dart';
import 'event_parts.dart';

/// Görsel seçici: kaynak verilir, hazırlanmış görsel (ya da iptalde null) döner. Testte değiştirilebilir.
typedef CoverPicker = Future<PreparedImage?> Function(ImageSource source);

/// Kapak kırpıcı: seçilen görseli 16:9 kırpma sayfasında açar (varsayılan [cropImage]). Testte değiştirilebilir.
typedef CoverCropper = Future<CropOutcome?> Function(BuildContext context, Uint8List bytes, CropSpec spec);

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
  BuildContext? toastContext,
}) async {
  final up = uploader ??
      (path, img) => MultipartUploader(session).upload(path, img, method: 'PUT');
  final l10n = messenger.context.l10n; // await'ten önce al: sayfa kapanmış olabilir
  try {
    await up('/events/$eventId/cover', image);
    return true;
  } catch (e) {
    final reason = e is ApiError && !e.isNetwork && e.message.isNotEmpty ? ' ${e.message}' : '';
    final text = eventAlreadyCreated ? l10n.eventFormCoverCreatedFail(reason) : l10n.eventFormCoverFail(reason);
    void retry() => uploadEventCover(
          messenger: messenger,
          session: session,
          eventId: eventId,
          image: image,
          eventAlreadyCreated: eventAlreadyCreated,
          uploader: uploader,
          toastContext: toastContext,
        );
    final ctx = toastContext;
    if (ctx != null && ctx.mounted) {
      BuToast.show(ctx, text,
          kind: BuToastKind.error, duration: const Duration(seconds: 8), actionLabel: l10n.eventFormRetry, onAction: retry);
    } else {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(text),
          action: SnackBarAction(label: l10n.eventFormRetry, onPressed: retry),
        ));
    }
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
    this.cropCover,
    this.now,
  });

  final Session session;
  final Map<String, dynamic>? event;
  final int? communityId;
  final CoverPicker? pickCover;
  final CoverUploader? uploadCover;
  final CoverCropper? cropCover;

  /// Yalnız test amaçlı: "şimdi" kaynağı (varsayılan DateTime.now); zamana bağlı varsayılanları sabitler.
  final DateTime Function()? now;

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<EventFormPage> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _place = TextEditingController();
  final _placeFocus = FocusNode();
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
  String? _clubLogo;
  bool _submitted = false; // kaydet denendi: alan hataları görünür
  String? _errCode; // sunucu hata kodu (şerit başlığı için)

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
      _clubLogo = e['communityLogoUrl'] as String?;
    } else {
      _loadClubs();
    }
    final base = _nextRoundHour();
    _start = DateTime.tryParse('${e?['startsAt']}')?.toLocal() ?? base;
    _end = DateTime.tryParse('${e?['endsAt']}')?.toLocal() ?? _start.add(const Duration(hours: 2));
    _origStart = e == null ? null : _start;
    _desc.addListener(() => setState(() {})); // canlı sayaç
    // Odak bırakılınca uzun mekân metni başa sarılır (ilk harf kesik görünmesin).
    _placeFocus.addListener(() {
      if (!_placeFocus.hasFocus) _place.selection = const TextSelection.collapsed(offset: 0);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _place.dispose();
    _placeFocus.dispose();
    _cap.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    BuToast.show(context, m, kind: BuToastKind.error);
  }

  // ---- kapak ----

  Future<PreparedImage?> _pick(ImageSource s) =>
      widget.pickCover != null ? widget.pickCover!(s) : _images.pickPrepared(s);

  Future<void> _chooseCover() async {
    final has = _picked != null || (!_removeCover && _existingCover != null);
    final choice = await BuSheet.show<Object>(
      context,
      scrollable: false,
      padding: EdgeInsets.zero,
      builder: (c) => _CoverSheet(canRemove: has),
    );
    if (choice == null || !mounted) return;
    if (choice == _removeToken) {
      _clearCover();
      return;
    }
    var source = choice as ImageSource;
    try {
      while (true) {
        final img = await _pick(source);
        if (img == null || !mounted) return;
        // 16:9 kırpma: "Fotoğrafı değiştir" yeni seçim açar, "Kapağı kaldır" kapağı siler, vazgeçmek hiçbir şey değiştirmez.
        final crop = widget.cropCover ?? cropImage;
        final title = _title.text.trim();
        final out = await crop(
          context,
          img.bytes,
          CropSpec.cover(previewTitle: title.isEmpty ? null : title, previewSubtitle: _clubName, allowRemove: has),
        );
        if (out == null || !mounted) return;
        if (out.removed) {
          _clearCover();
          return;
        }
        if (out.changeRequested) {
          source = ImageSource.gallery;
          continue;
        }
        final bytes = out.bytes;
        if (bytes == null) return;
        setState(() {
          _picked = PreparedImage(bytes, 'image/jpeg'); // kırpma çıktısı her zaman JPEG
          _removeCover = false;
        });
        return;
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

  /// '14 May 2025' (dile göre kısa tarih).
  String _shortDate(DateTime d) {
    final loc = Localizations.localeOf(context).toString();
    try {
      return DateFormat('d MMM y', loc).format(d);
    } catch (_) {
      return DateFormat('d MMM y').format(d);
    }
  }

  /// Özel bitiş çip etiketi: aynı gün ise saat, değilse 'tarih saat'.
  String get _endLabel => _day(_end) == _day(_start) ? _hm(_end) : '${_shortDate(_end)} ${_hm(_end)}';

  /// 'Cum, 31 Ekim · 14:00 – 16:00' (çok günlüde iki tarih).
  String get _summary => _day(_start) == _day(_end)
      ? '${_dayText(_start)} · ${_hm(_start)} – ${_hm(_end)}'
      : '${_dayText(_start)} ${_hm(_start)} – ${_dayText(_end)} ${_hm(_end)}';

  // ---- doğrulama ----

  String? get _titleErr => _title.text.trim().length < 3 ? context.l10n.eventFormTitleTooShort : null;

  String? get _descErr =>
      _desc.text.trim().length > _descMax ? context.l10n.evdErrDescTooLong('$_descMax') : null;

  String? get _clubFieldErr => (!_editing && _clubId == null) ? context.l10n.evcClubRequiredHint : null;

  String? get _capErr {
    final txt = _cap.text.trim();
    if (txt.isEmpty) return null;
    final v = int.tryParse(txt);
    return (v == null || v < 1) ? context.l10n.eventFormCapInvalid : null;
  }

  /// Ekranda görünen doğrulama hataları: açıklama/tarih her zaman (canlı), diğerleri kaydet denendikten sonra.
  List<String> get _visibleErrors {
    final out = <String>[];
    void add(String? e) {
      if (e != null) out.add(e);
    }

    if (_submitted) add(_clubFieldErr);
    if (_submitted) add(_titleErr);
    add(_descErr);
    add(_dateError);
    if (_submitted) add(_capErr);
    return out;
  }

  // ---- kaydet ----

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _submitted = true);
    final title = _title.text.trim();
    if (_visibleErrors.isNotEmpty) return;
    final capText = _cap.text.trim();
    final cap = capText.isEmpty ? null : int.tryParse(capText);
    setState(() {
      _busy = true;
      _error = null;
      _errCode = null;
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
            // ignore: use_build_context_synchronously
            toastContext: context,
          );
        } else if (_removeCover && _editing) {
          try {
            await api.delete('/events/$id/cover');
          } catch (e) {
            if (mounted) BuToast.show(context, l10n.eventFormCoverRemoveFail(errorText(e)), kind: BuToastKind.error);
          }
        }
      }
      if (!mounted) return;
      if (!_editing && status == 'PENDING_REVIEW') {
        // Onaya düştü: kullanıcıya açık bilgi, sonra liste (Oluşturduklarım'da rozetli).
        await BuDialog.show<void>(context, builder: (c) => const _SubmittedDialog());
        if (!mounted) return;
        nav.pop(true);
        return;
      }
      // Kapak hatası bildirimi varsa üstüne yazılmaması için yalnızca başarılıysa gösterilir.
      if (!_editing && coverOk) BuToast.show(context, l10n.eventFormCreated, kind: BuToastKind.success);
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
        _errCode = e is ApiError && !e.isNetwork ? (e.status == 403 ? 'FORBIDDEN' : e.code) : null;
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
    _clubLogo = c['logoUrl'] as String?;
    _error = null;
    _errCode = null;
  }

  Future<void> _chooseClub() async {
    final clubs = _clubs ?? const <Map<String, dynamic>>[];
    if (clubs.isEmpty) return;
    final picked = await BuSheet.show<Map<String, dynamic>>(
      context,
      scrollable: false,
      padding: EdgeInsets.zero,
      builder: (c) => _ClubPickerSheet(clubs: clubs, selectedId: _clubId, onBrowse: () {
        Navigator.pop(c);
        _browseClubs();
      }),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectClub(picked));
  }

  void _browseClubs() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => Scaffold(body: ClubsTab(session: widget.session))),
      );

  // ---- bölümler ----

  Widget _noClubView(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    // Stitch v3 06: yalnız geri oku; ortada kalın başlık, muted açıklama, tek marka düğmesi. İllüstrasyon/kart yok.
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        const ClubPageHeader(title: ''),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(56, 0, 56, 40),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(l.evcEmptyTitle, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink, height: 1.3)),
                const SizedBox(height: 10),
                Text(l.p51EvClubOnly, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(height: 1.5, color: t.mut)),
                const SizedBox(height: 28),
                BuButton(label: l.evcBrowseClubs, onPressed: _browseClubs),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48)),
                  onPressed: _loadClubs,
                  child: Text(l.p15RefreshPerms, style: tx.bodyMedium!.copyWith(color: t.pr, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  /// Alan etiketi: 13 sp muted/600 (Stitch v3); zorunlu alanlar yıldız yerine hata metniyle anlatılır.
  Widget _label(String s, {String? trailing}) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 20, bottom: 8),
      child: Row(children: [
        Expanded(child: Text(s, style: tx.labelLarge!.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: t.mut))),
        if (trailing != null) Text(trailing, style: tx.labelMedium!.copyWith(color: t.mut)),
      ]),
    );
  }

  /// Alanın altındaki doğrulama satırı: simgesiz, `danger` 12.5 sp.
  Widget _fieldError(String text, {Key? key, IconData icon = LucideIcons.info}) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      key: key,
      padding: const EdgeInsetsDirectional.only(top: 6),
      child: Semantics(liveRegion: true, child: Text(text, style: tx.bodySmall!.copyWith(fontWeight: FontWeight.w500, color: t.danger))),
    );
  }

  /// Metin alanı kutusu: beyaz, 1 dp `bdStrong`, 16 dp köşe; hatada 1.5 dp `danger` çerçeve (dolgu beyaz kalır).
  Widget _box({required Widget child, bool error = false, EdgeInsetsGeometry? padding}) {
    final t = context.bu;
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: error ? t.danger : t.bdStrong, width: error ? 1.5 : 1),
      ),
      child: child,
    );
  }

  InputDecoration _bare(String hint, {Widget? icon}) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return InputDecoration(
      hintText: hint,
      hintStyle: tx.bodyLarge!.copyWith(color: t.mut),
      counterText: '',
      filled: false,
      isDense: true,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      icon: icon,
    );
  }

  /// Sunucu hatası şeridi (kapatılabilir): yetki / kulüp pasif / diğer. Simgesiz, düz renkli not.
  Widget _serverBanner() {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final forbidden = _errCode == 'FORBIDDEN';
    final inactive = _errCode == 'COMMUNITY_NOT_ACTIVE';
    final title = forbidden ? l.p15ErrForbiddenTitle : (inactive ? l.p15ErrInactiveTitle : null);
    final danger = !inactive;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        key: const ValueKey('evc-server-error'),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 8),
        decoration: BoxDecoration(color: danger ? t.danger.withValues(alpha: .1) : t.warnSoft, borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (title != null) Text(title, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: danger ? t.danger : t.onWarnSoft)),
                Text(_error!, style: tx.bodySmall!.copyWith(height: 1.4, color: danger ? t.danger : t.onWarnSoft)),
              ]),
            ),
          ),
          Semantics(
            button: true,
            label: l.commonClose,
            excludeSemantics: true,
            onTap: () => setState(() => _error = null),
            child: BuPressable(
              onTap: () => setState(() => _error = null),
              child: SizedBox(width: 44, height: 44, child: Icon(LucideIcons.x, size: 18, color: t.mut)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _errorSummary(int n) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        key: const ValueKey('evc-error-summary'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: t.danger.withValues(alpha: .1), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.p15ErrBannerTitle('$n'), style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: t.danger)),
          const SizedBox(height: 2),
          Text(l.p15ErrBannerBody, style: tx.bodySmall!.copyWith(height: 1.4, color: t.danger)),
        ]),
      ),
    );
  }

  /// "Kulüp" seçici (Stitch v3): beyaz alan, baş harf dairesi + ad + chevron; altında amber/soft not (ikonsuz).
  Widget _clubSection() {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final canPick = !_editing && (_clubs?.isNotEmpty ?? false);
    final err = _submitted ? _clubFieldErr : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _label(l.evcLabelClub),
      Semantics(
        button: canPick,
        label: '${l.evcLabelClub}: ${_clubName ?? l.etkinlik2ClubSheetTitle}',
        excludeSemantics: true,
        onTap: _busy || !canPick ? null : _chooseClub,
        child: BuPressable(
          scale: .99,
          enabled: canPick && !_busy,
          child: Material(
            key: const ValueKey('et2-club-field'),
            color: t.sf,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: err != null ? t.danger : t.bdStrong, width: err != null ? 1.5 : 1)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _busy || !canPick ? null : _chooseClub,
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 16, 8),
                child: Row(children: [
                  ClubsLogo(name: _clubName ?? '?', id: _clubId ?? 0, url: _clubLogo, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_clubName ?? l.etkinlik2ClubSheetTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w600, color: _clubName == null ? t.mut : t.ink)),
                  ),
                  if (canPick) Icon(buDirIcon(context, LucideIcons.chevronRight), size: 20, color: t.mut),
                ]),
              ),
            ),
          ),
        ),
      ),
      if (err != null) _fieldError(err),
      if (!_editing && _clubId != null)
        Container(
          key: const ValueKey('evc-club-info'),
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: _clubInstant ? t.soft : t.warnSoft, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Flexible(child: Text(_clubInstant ? l.evcInfoInstant : l.evcInfoReview, style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w500, color: _clubInstant ? t.onSoft : t.onWarnSoft))),
            if (_clubInstant) Flexible(flex: 0, child: Text(' • ${l.p15PublishRoleActive}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.onSoft.withValues(alpha: .8)))),
          ]),
        ),
    ]);
  }

  /// Bölüm: etiket + içerik (kartsız).
  Widget _section(IconData icon, String title, Widget child) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(header: true, child: _label(title)),
      child,
    ]);
  }

  Widget _dateSection(AppLocalizations l) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
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
    // Hızlı tarih tek seçimlidir: aynı güne denk gelen ilk çip (Bugün > Yarın > Hafta sonu > Gelecek hafta).
    final dayIdx = dayChips.indexWhere((c) => c.$2 == sd);
    final customEnd = (dur != const Duration(hours: 1) && dur != const Duration(hours: 2) && dur != const Duration(hours: 4)) || _day(_end) != sd;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Seçili tarih/saat özeti ekran okuyucu içindir (görsel karşılığı çipler).
      Semantics(key: const ValueKey('evd-summary'), label: _summary, child: const SizedBox.shrink()),
      _section(
        LucideIcons.calendarDays,
        l.evdLabelDate,
        Wrap(spacing: 8, children: [
          for (var i = 0; i < dayChips.length; i++)
            _Chip(label: dayChips[i].$1, selected: i == dayIdx, onTap: locked ? null : () => _setStartDate(dayChips[i].$2)),
          _Chip(
            label: presetDate ? l.evdChipPickDate : _shortDate(_start),
            tone: _ChipTone.soft,
            selected: !presetDate,
            icon: LucideIcons.calendarPlus,
            onTap: locked ? null : _pickStartDate,
          ),
        ]),
      ),
      _section(
        LucideIcons.clock,
        l.evdLabelTime,
        Wrap(spacing: 8, children: [
          for (final h in hours)
            _Chip(
              label: '${h.$1.toString().padLeft(2, '0')}:${h.$2.toString().padLeft(2, '0')}',
              tone: _ChipTone.brand,
              selected: _start.hour == h.$1 && _start.minute == h.$2,
              // Bugünse geçmiş saat seçilemez.
              onTap: (locked || DateTime(sd.year, sd.month, sd.day, h.$1, h.$2).isBefore(_now())) ? null : () => _setStartTime(h.$1, h.$2),
            ),
          _Chip(label: presetTime ? l.evdChipCustomTime : _hm(_start), tone: _ChipTone.brand, selected: !presetTime, icon: LucideIcons.alarmClock, onTap: locked ? null : _pickCustomTime),
        ]),
      ),
      _section(
        LucideIcons.chartPie,
        l.evdLabelDuration,
        Wrap(spacing: 8, children: [
          _Chip(label: l.evdDur1h, selected: dur == const Duration(hours: 1), onTap: locked ? null : () => _setDuration(const Duration(hours: 1))),
          _Chip(label: l.evdDur2h, selected: dur == const Duration(hours: 2), onTap: locked ? null : () => _setDuration(const Duration(hours: 2))),
          _Chip(label: l.evdDurHalfDay, selected: dur == const Duration(hours: 4), onTap: locked ? null : () => _setDuration(const Duration(hours: 4))),
          _Chip(label: customEnd ? _endLabel : l.evdChipCustomEnd, selected: customEnd, icon: LucideIcons.calendarDays, onTap: locked ? null : _pickEnd),
        ]),
      ),
      if (_endAdjusted && err == null)
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: t.warnSoft, borderRadius: BorderRadius.circular(BuRadius.md)),
          child: Row(children: [
            ExcludeSemantics(child: Icon(LucideIcons.wandSparkles, size: 18, color: t.onWarnSoft)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(l.evdEndAdjusted,
                  key: const ValueKey('evd-adjusted'), style: tx.bodySmall!.copyWith(fontWeight: FontWeight.w500, color: t.onWarnSoft)),
            ),
          ]),
        ),
      if (err != null) _fieldError(err, key: const ValueKey('evd-error'), icon: LucideIcons.calendarX),
    ]);
  }

  /// "Katılım Türü": Herkes katılabilir | İstek ile (segment); altında muted ipucu.
  Widget _policySection(AppLocalizations l) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final approval = _policy == 'APPROVAL';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _label(l.etkinlik2SettingsPolicy),
      Et2Segment<String>(
        value: _policy,
        enabled: !_busy,
        options: [('OPEN', l.etkinlik2PolicyOpen), ('APPROVAL', l.etkinlik2PolicyApproval)],
        onChanged: (v) => setState(() => _policy = v),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(approval ? l.etkinlik2PolicyApprovalHint : l.p16PolicyOpenHint, style: tx.bodySmall!.copyWith(height: 1.4, color: t.mut)),
      ),
    ]);
  }

  /// Kapak: kesik çizgili (1 dp `bdStrong`) 140 dp beyaz alan + "Kapak fotoğrafı ekle"; doluyken 16:9 önizleme.
  Widget _coverSection() {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final Uint8List? bytes = _picked?.bytes;
    final existing = _removeCover ? null : _existingCover;
    final has = bytes != null || existing != null;
    final radius = BorderRadius.circular(16);
    if (!has) {
      return Semantics(
        button: true,
        label: l.eventFormAddCover,
        excludeSemantics: true,
        onTap: _busy ? null : _chooseCover,
        child: BuPressable(
          onTap: _busy ? null : _chooseCover,
          haptic: BuHaptic.selection,
          scale: .985,
          child: CustomPaint(
            foregroundPainter: DashedRRectPainter(color: t.bdStrong, radius: 16),
            child: Container(
              width: double.infinity,
              height: 140,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.sf, borderRadius: radius),
              child: Text(l.eventFormAddCover, textAlign: TextAlign.center, style: tx.bodyLarge!.copyWith(color: t.mut)),
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
              Image.memory(bytes, fit: BoxFit.cover, cacheWidth: 800, errorBuilder: (_, __, ___) => ColoredBox(color: t.soft))
            else
              EventCoverImage(url: existing!),
            PositionedDirectional(
              top: 10,
              end: 10,
              child: Tooltip(
                message: l.eventFormChangeCover,
                child: Semantics(
                  button: true,
                  label: l.eventFormChangeCover,
                  excludeSemantics: true,
                  onTap: _busy ? null : _chooseCover,
                  child: BuPressable(
                    onTap: _busy ? null : _chooseCover,
                    haptic: BuHaptic.selection,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: t.sf.withValues(alpha: .95), borderRadius: BorderRadius.circular(BuRadius.pill)),
                        child: Text(l.p15CoverChange, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    if (!_editing) {
      if (_clubsError != null) {
        return BuPageScaffold(
          title: l.eventFormNewTitle,
          large: false,
          state: BuViewState.error,
          error: _clubsError,
          onRetry: _loadClubs,
        );
      }
      if (_clubs == null) {
        return BuPageScaffold(
          title: l.eventFormNewTitle,
          large: false,
          state: BuViewState.loading,
          loading: const _FormSkeleton(),
        );
      }
      if (_clubs!.isEmpty) return _noClubView(context);
    }
    final errors = _visibleErrors;
    // Kaydet denendikten sonra hatalar sürerken düğme kilitli; düzeltilince kendiliğinden açılır.
    final locked = _submitted && errors.isNotEmpty;
    final titleErr = _submitted ? _titleErr : null;
    final descErr = _descErr;
    final capErr = _submitted ? _capErr : null;
    final descLen = _desc.text.length;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        ClubPageHeader(title: _editing ? l.eventFormEditTitle : l.eventFormNewTitle),
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_error != null) ...[const SizedBox(height: 8), _serverBanner()],
              if (_submitted && errors.isNotEmpty) ...[const SizedBox(height: 8), _errorSummary(errors.length)],
              _clubSection(),
              _label(l.p15CoverSheetTitle),
              _coverSection(),
              _label(l.eventFormFieldTitle),
              _box(
                error: titleErr != null,
                child: TextField(
                  key: const ValueKey('evc-title'),
                  controller: _title,
                  maxLength: _titleMax,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.sentences,
                  style: tx.bodyLarge!.copyWith(color: t.ink),
                  onChanged: (_) => setState(() {}),
                  decoration: _bare(l.eventFormTitleHint),
                ),
              ),
              if (titleErr != null) _fieldError(titleErr),
              _label(l.eventFormFieldDesc),
              _box(
                error: descErr != null,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: TextField(
                  key: const ValueKey('evc-desc'),
                  controller: _desc,
                  maxLength: _descMax + 200, // aşımda yazılabilir; sayaç kızarır, gönderme kapanır
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  enabled: !_busy,
                  minLines: 4,
                  maxLines: 8,
                  textCapitalization: TextCapitalization.sentences,
                  style: tx.bodyLarge!.copyWith(color: t.ink),
                  decoration: _bare(l.eventFormDescHint),
                ),
              ),
              if (descErr != null) _fieldError(descErr),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(l.evdDescCounter('$descLen', '$_descMax'),
                      key: const ValueKey('evd-desc-counter'),
                      style: tx.bodySmall!.copyWith(fontWeight: descErr != null ? FontWeight.w700 : FontWeight.w400, color: descErr != null ? t.danger : t.mut)),
                ),
              ),
              _dateSection(l),
              _label(l.eventFormPlace),
              _box(
                child: TextField(
                  key: const ValueKey('evc-place'),
                  controller: _place,
                  focusNode: _placeFocus,
                  maxLines: 1,
                  maxLength: 200,
                  enabled: !_busy,
                  style: tx.bodyLarge!.copyWith(color: t.ink),
                  decoration: _bare(l.eventFormPlaceHint),
                ),
              ),
              _label(l.eventFormCapacityLabel),
              _box(
                error: capErr != null,
                child: TextField(
                  key: const ValueKey('evc-cap'),
                  controller: _cap,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: tx.bodyLarge!.copyWith(color: t.ink),
                  onChanged: (_) => setState(() {}),
                  decoration: _bare(l.eventFormCapHint),
                ),
              ),
              if (capErr != null) _fieldError(capErr),
              _policySection(l),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text('${l.etkinlik2ChatAutoTitle} · ${l.etkinlik2ChatAutoBody}', style: tx.bodySmall!.copyWith(height: 1.4, color: t.mut)),
              ),
              if (locked)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(l.p15ErrHint, style: tx.bodySmall!.copyWith(height: 1.4, color: t.mut)),
                ),
              const SizedBox(height: 24),
              BuButton(
                key: const ValueKey('evc-submit'),
                label: _editing ? l.eventFormSave : l.eventFormCreate,
                busy: _busy,
                onPressed: (_busy || locked) ? null : _save,
              ),
              if (locked)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(l.p15ErrLocked('${errors.length}'), textAlign: TextAlign.center, style: tx.bodySmall!.copyWith(color: t.mut)),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}

enum _ChipTone { neutral, brand, soft }

/// Hızlı seçim çipi: ortak [BuChip] (34 dp görünür, 48 dp dokunma; seçili = yumuşak zemin + marka). [tone] eski çağrılar içindir.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap, this.icon, this.tone = _ChipTone.neutral});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : .5,
      child: IgnorePointer(ignoring: !enabled, child: BuChip(label: label, selected: selected, onTap: onTap ?? () {}, icon: tone == _ChipTone.soft ? icon : null)),
    );
  }
}

/// Kulüp seçici alt sayfa: başlık + kapat, arama, rol etiketli liste, bilgi notu.
class _ClubPickerSheet extends StatefulWidget {
  const _ClubPickerSheet({required this.clubs, required this.selectedId, required this.onBrowse});

  final List<Map<String, dynamic>> clubs;
  final int? selectedId;
  final VoidCallback onBrowse;

  @override
  State<_ClubPickerSheet> createState() => _ClubPickerSheetState();
}

class _ClubPickerSheetState extends State<_ClubPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final q = _q.trim().toLowerCase();
    final list = [
      for (final c in widget.clubs)
        if (q.isEmpty || '${c['name'] ?? ''}'.toLowerCase().contains(q)) c,
    ];
    return BuBottomSheet(
      scrollable: false,
      padding: EdgeInsets.zero,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 12, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Semantics(header: true, child: Text(l.etkinlik2ClubSheetTitle, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
                const SizedBox(height: 2),
                Text(l.p15PickerSubtitle, style: tx.bodySmall!.copyWith(color: t.mut)),
              ]),
            ),
            Semantics(
              button: true,
              label: l.commonClose,
              excludeSemantics: true,
              onTap: () => Navigator.pop(context),
              child: BuPressable(
                onTap: () => Navigator.pop(context),
                haptic: BuHaptic.selection,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
                      child: Icon(LucideIcons.x, size: 18, color: t.ink),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.md)),
            child: TextField(
              key: const ValueKey('evc-club-search'),
              onChanged: (v) => setState(() => _q = v),
              style: tx.bodyLarge!.copyWith(color: t.ink),
              decoration: InputDecoration(
                hintText: l.p15PickerSearch,
                hintStyle: tx.bodyLarge!.copyWith(color: t.mut),
                icon: Icon(LucideIcons.search, size: 20, color: t.mut),
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            children: [
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(l.p15PickerNoMatch, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut)),
                ),
              for (final c in list) _row(context, c),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.md)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: ExcludeSemantics(child: Icon(LucideIcons.info, size: 16, color: t.mut)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.p15PickerInfoTitle, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                      const SizedBox(height: 2),
                      Text(l.p15PickerInfoBody, style: tx.bodySmall!.copyWith(height: 1.4, color: t.mut)),
                    ]),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> c) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final id = (c['id'] as num?)?.toInt() ?? 0;
    final sel = id == widget.selectedId;
    final role = c['myRole'] as String?;
    final manager = role == 'OWNER' || role == 'ADMIN';
    final roleLabel = switch (role) {
      'OWNER' || 'ADMIN' => l.clubRoleOwner,
      'MODERATOR' => l.clubRoleModerator,
      _ => l.profilyardRoleMember,
    };
    final members = (c['memberCount'] as num?)?.toInt();
    final logo = fileUrl(c['logoUrl'] as String?);
    final tint = t.tint(id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        button: true,
        selected: sel,
        label: '${c['name'] ?? ''}, $roleLabel',
        excludeSemantics: true,
        onTap: () => Navigator.pop(context, c),
        child: BuPressable(
          onTap: () => Navigator.pop(context, c),
          haptic: BuHaptic.selection,
          scale: .985,
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 14, 8),
            decoration: BoxDecoration(color: sel ? t.soft : Colors.transparent, borderRadius: BorderRadius.circular(BuRadius.md)),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(BuRadius.md),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: logo != null
                      ? BuImage(logo, width: 52, height: 52, placeholderIcon: LucideIcons.users)
                      : ColoredBox(color: tint.bg, child: Icon(LucideIcons.users, size: 24, color: tint.fg)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('${c['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: manager ? t.ink : t.sf2, borderRadius: BorderRadius.circular(BuRadius.pill)),
                      child: Text(roleLabel, style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: manager ? t.bg : t.mut)),
                    ),
                    if (members != null) ...[
                      const SizedBox(width: 8),
                      Flexible(child: Text(l.p15PickerMembers('$members'), maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(color: t.mut))),
                    ],
                  ]),
                ]),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: BuMotion.of(context, BuMotion.short),
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: sel ? t.pr : t.sf2, shape: BoxShape.circle),
                child: sel ? Icon(LucideIcons.check, size: 16, color: t.onPr) : null,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Kapak kaynağı alt sayfası: Galeriden seç / Fotoğraf çek / (kapak varsa) Kapağı kaldır.
class _CoverSheet extends StatelessWidget {
  const _CoverSheet({required this.canRemove});

  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    Widget row(IconData icon, String title, String sub, VoidCallback onTap, {bool danger = false, Key? key}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Semantics(
          button: true,
          label: '$title, $sub',
          excludeSemantics: true,
          onTap: onTap,
          child: BuPressable(
            key: key,
            onTap: onTap,
            haptic: BuHaptic.selection,
            scale: .985,
            child: Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 16, 10),
              decoration: BoxDecoration(color: danger ? t.danger.withValues(alpha: .1) : Colors.transparent, borderRadius: BorderRadius.circular(BuRadius.md)),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: danger ? t.danger.withValues(alpha: .14) : t.sf2, borderRadius: BorderRadius.circular(BuRadius.sm + 2)),
                  child: Icon(icon, size: 22, color: danger ? t.danger : t.ink),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(title, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: danger ? t.danger : t.ink)),
                    Text(sub, style: tx.bodySmall!.copyWith(color: danger ? t.danger.withValues(alpha: .85) : t.mut)),
                  ]),
                ),
                const SizedBox(width: 8),
                Icon(danger ? LucideIcons.trash2 : buDirIcon(context, LucideIcons.chevronRight), size: 18, color: danger ? t.danger : t.mut),
              ]),
            ),
          ),
        ),
      );
    }

    return BuBottomSheet(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 4, 8),
          child: Row(children: [
            Expanded(child: Semantics(header: true, child: Text(l.p15CoverSheetTitle, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink)))),
            Semantics(
              button: true,
              label: l.commonClose,
              excludeSemantics: true,
              onTap: () => Navigator.pop(context),
              child: BuPressable(
                onTap: () => Navigator.pop(context),
                child: SizedBox(width: 48, height: 48, child: Icon(LucideIcons.x, size: 20, color: t.mut)),
              ),
            ),
          ]),
        ),
        row(LucideIcons.images, l.eventFormPickGallery, l.p15CoverGallerySub, () => Navigator.pop(context, ImageSource.gallery)),
        row(LucideIcons.camera, l.eventFormTakePhoto, l.p15CoverCameraSub, () => Navigator.pop(context, ImageSource.camera)),
        if (canRemove)
          row(LucideIcons.trash2, l.eventFormRemoveCover, l.p15CoverRemoveSub, () => Navigator.pop(context, _removeToken),
              danger: true, key: const ValueKey('evc-cover-remove')),
      ]),
    );
  }
}

/// Kapak sayfasından "kaldır" seçimini ImageSource'tan ayırt etmek için işaret.
const Object _removeToken = 'remove';

/// Form iskeleti (kulüpler yüklenirken).
class _FormSkeleton extends StatelessWidget {
  const _FormSkeleton();

  @override
  Widget build(BuildContext context) {
    return const BuSkeletonScope(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BuSkeleton.line(width: 60),
          SizedBox(height: 10),
          BuSkeleton(height: 80, radius: 20),
          SizedBox(height: 10),
          BuSkeleton(height: 44, radius: 16),
          SizedBox(height: 22),
          BuSkeleton(height: 170, radius: 20),
          SizedBox(height: 22),
          BuSkeleton.line(width: 80),
          SizedBox(height: 10),
          BuSkeleton(height: 52, radius: 16),
          SizedBox(height: 22),
          BuSkeleton(height: 120, radius: 16),
        ]),
      ),
    );
  }
}

/// "Onaya gönderildi": koyu daire içinde onay + köşede kırmızı saat rozeti, başlık, gövde, koyu "Tamam" düğmesi.
class _SubmittedDialog extends StatelessWidget {
  const _SubmittedDialog();

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ExcludeSemantics(
            child: SizedBox(
              width: 84,
              height: 84,
              child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: t.ink, shape: BoxShape.circle, boxShadow: [BoxShadow(color: t.pr.withValues(alpha: .18), blurRadius: 0, spreadRadius: 6)]),
                  child: Icon(LucideIcons.check, size: 34, color: t.bg),
                ),
                PositionedDirectional(
                  end: 2,
                  bottom: 2,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle, border: Border.all(color: t.sf3, width: 3)),
                    child: Icon(LucideIcons.clock, size: 15, color: t.onPr),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(header: true, child: Text(l.evcSubmittedTitle, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
          const SizedBox(height: 8),
          Text(l.evcSubmittedBody, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(height: 1.5, color: t.mut)),
          const SizedBox(height: 20),
          Semantics(
            button: true,
            label: l.evcOk,
            excludeSemantics: true,
            onTap: () => Navigator.pop(context),
            child: BuPressable(
              onTap: () => Navigator.pop(context),
              haptic: BuHaptic.light,
              child: Container(
                constraints: const BoxConstraints(minHeight: BuSize.button),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: t.ink, borderRadius: BorderRadius.circular(BuRadius.md)),
                child: Text(l.evcOk, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: t.bg)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

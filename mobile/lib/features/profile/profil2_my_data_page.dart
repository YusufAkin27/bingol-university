import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'legal_pages.dart';
import 'profil2_delete_account_page.dart';
import 'profil2_widgets.dart';

/// Paylaşılan KVKK dosyasının yedek silme süresi. Asıl temizlik yaşam döngüsüyle yapılır (kullanıcı paylaşım
/// sayfasından uygulamaya dönünce / sayfa kapanınca / sonraki açılışta); süre, hiçbiri olmazsa devreye giren sigortadır.
Duration kExportFileTtl = const Duration(minutes: 10);

/// KVKK dışa aktarma dosyasının tesliminin tek kapısı. Kişisel veri PANOYA KONMAZ (A4-08: pano diğer uygulamalarca
/// okunabilir ve zamanlayıcıyla silme arka planda güvenilmezdir); veri önbellek altındaki `export/` dizinine yazılıp
/// sistem paylaşım sayfasıyla (Android FileProvider, iOS UIActivityViewController) verilir.
class ExportShare {
  ExportShare._();

  static const MethodChannel channel = MethodChannel('bu_kampus/share');
  static const String dirName = 'export';

  /// Test kancası: geçici dizin.
  @visibleForTesting
  static Future<Directory> Function() baseDir = getTemporaryDirectory;

  /// Test kancası: JSON'u teslim eder; true = paylaşım sayfası açıldı.
  static Future<bool> Function(String json, String title) deliver = _deliver;

  /// Test kancası: `export/` dizinindeki dosyaları siler.
  static Future<void> Function() purge = _purge;

  static Future<Directory> _dir() async => Directory('${(await baseDir()).path}${Platform.pathSeparator}$dirName');

  static Future<bool> _deliver(String json, String title) async {
    try {
      final dir = await _dir();
      await _purge();
      await dir.create(recursive: true);
      final stamp = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final file = File('${dir.path}${Platform.pathSeparator}bu-kampus-verilerim-$stamp.json');
      await file.writeAsString(json, flush: true);
      final ok = await channel.invokeMethod<bool>('shareFile', {'path': file.path, 'title': title});
      if (ok != true) await _purge();
      return ok == true;
    } catch (_) {
      await _purge(); // paylaşım açılamadıysa (eklenti yok / hata) dosya kalmasın
      return false;
    }
  }

  static Future<void> _purge() async {
    try {
      final dir = await _dir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Silinemezse sessizce geçilir; sonraki açılış/sayfa tekrar dener.
    }
  }
}

/// Verilerim (Stitch 08-1/2): KVKK veri indirme (`GET /users/me/export`, günde 3), aydınlatma metni, hesap silme girişi.
class MyDataPage extends StatefulWidget {
  const MyDataPage({super.key, required this.session});

  final Session session;

  @override
  State<MyDataPage> createState() => _MyDataPageState();
}

class _MyDataPageState extends State<MyDataPage> with WidgetsBindingObserver {
  bool _exporting = false;

  /// Günlük sınır aşıldı (429): düğme pasif, kırmızı kart gösterilir.
  String? _limitMessage;

  /// Paylaşım sayfası açıldı, dosya henüz silinmedi.
  bool _fileOut = false;

  /// Paylaşım sayfası açıkken uygulama arka plana/inactive'e geçti; dönüşte (resumed) dosya silinir.
  bool _leftApp = false;
  Timer? _ttl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Önceki oturumdan (süreç öldürüldü vb.) kalmış dışa aktarma dosyası varsa temizle.
    unawaited(ExportShare.purge());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ttl?.cancel();
    unawaited(ExportShare.purge());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_fileOut) return;
    if (state == AppLifecycleState.resumed) {
      // Kullanıcı paylaşımı bitirip (ya da iptal edip) uygulamaya döndü: kişisel veri dosyası silinir.
      if (_leftApp) _discardFile();
    } else {
      _leftApp = true;
    }
  }

  void _discardFile() {
    _ttl?.cancel();
    _fileOut = false;
    _leftApp = false;
    unawaited(ExportShare.purge());
  }

  void _push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Future<void> _export() async {
    if (_exporting || _limitMessage != null) return;
    setState(() => _exporting = true);
    final title = context.l10n.profilePrefsDownloadData;
    try {
      final data = await widget.session.api.get('/users/me/export');
      if (!mounted) return; // sayfa kapandı: dosya oluşturulmaz
      const enc = JsonEncoder.withIndent('  ');
      final text = enc.convert(data);
      final ok = await ExportShare.deliver(text, title);
      if (ok) {
        _fileOut = true;
        _leftApp = false;
        _ttl?.cancel();
        _ttl = Timer(kExportFileTtl, _discardFile);
      } else if (mounted) {
        BuToast.show(context, context.l10n.p32ExportShareFailed, kind: BuToastKind.error);
      }
    } catch (e) {
      if (!mounted) return;
      if (e is ApiError && e.status == 429) {
        setState(() => _limitMessage = e.message.isNotEmpty ? e.message : context.l10n.profilePrefsExportLimit);
      } else {
        BuToast.show(context, errorText(e), kind: BuToastKind.error);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final items = [
      l.profil2DataItemProfile,
      l.profil2DataItemPrefs,
      l.profil2DataItemClubs,
      l.profil2DataItemSaved,
      l.profil2DataItemSupport,
    ];
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: l.profil2DataTitle, onBack: () => Navigator.pop(context)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(l.profil2DataIntro, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
                ),
                const SizedBox(height: 4),
                // Biçim bilgisi tek soluk satır (kutu + simge karosu kalktı).
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(l.profil2DataFileSub, style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                ),
                P2Heading(l.profil2DataContents, top: 20),
                BuCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(children: [
                    for (final s in items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
                            child: Icon(LucideIcons.check, size: 15, color: _limitMessage == null ? t.ink : t.mut),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(s, style: tx.bodyLarge!.copyWith(fontWeight: FontWeight.w600, color: t.ink))),
                        ]),
                      ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 14, 4, 14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (_limitMessage != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: ExcludeSemantics(child: Icon(LucideIcons.info, size: 15, color: t.mut)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(child: Text(l.profil2DataLimit, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.4))),
                  ]),
                ),
                BuButton(
                  key: const ValueKey('my-data-download'),
                  label: l.profilePrefsDownloadData,
                  icon: LucideIcons.download,
                  busy: _exporting,
                  onPressed: (_exporting || _limitMessage != null) ? null : _export,
                ),
                if (_limitMessage != null) ...[
                  const SizedBox(height: 14),
                  Semantics(
                    liveRegion: true,
                    container: true,
                    child: Container(
                      key: const ValueKey('my-data-limit'),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BuRadius.bMd),
                      child: Row(children: [
                        const P2IconTile(icon: LucideIcons.circleAlert, danger: true, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(_limitMessage!,
                              style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onErrorContainer)),
                        ),
                      ]),
                    ),
                  ),
                ],
                P2Heading(l.profil2DataOther, top: 20),
                BuGroup(dividerIndent: 66, children: [
                  BuSettingsTile(
                    icon: LucideIcons.shieldUser,
                    title: l.profil2DataKvkk,
                    tint: profilNeutralTint(context),
                    onTap: () => _push(LegalListPage(session: widget.session)),
                  ),
                  BuSettingsTile(
                    key: const ValueKey('my-data-delete-row'),
                    icon: LucideIcons.trash2,
                    title: l.profilePrefsDeleteMyAccount,
                    danger: true,
                    trailing: ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.danger)),
                    onTap: () => _push(DeleteAccountPage(session: widget.session)),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

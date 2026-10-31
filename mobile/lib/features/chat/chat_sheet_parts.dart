import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import '../media_crop/media_crop.dart' show PhotoSource;
import 'chat_info_parts.dart';
import 'chatlist_widgets.dart';

/// Sohbet alt sayfaları ve pencereleri (Stitch 21-6 İlet, 22 sessize al / üye ekle / grup adı): ortak parçalar.

/// Seçim dairesi (İlet, Üye ekle): seçiliyken dolu kırmızı daire, değilken çizgili boş daire.
class ChatSheetCheck extends StatelessWidget {
  const ChatSheetCheck({super.key, required this.on, this.filledOff = false});

  final bool on;

  /// Seçili değilken gri dolu daire (Üye ekle, referans 22-4).
  final bool filledOff;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: BuMotion.of(context, BuMotion.short),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? t.pr : (filledOff ? t.sf2 : Colors.transparent),
          border: on || filledOff ? null : Border.all(color: t.bdStrong, width: 2),
        ),
        child: on ? Icon(Icons.check_rounded, size: 16, color: t.onPr) : null,
      ),
    );
  }
}

/// Seçenek düğmesi (sessize alma süresi): seçiliyken kırmızı halka + beyaz nokta.
class ChatSheetRadio extends StatelessWidget {
  const ChatSheetRadio({super.key, required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: BuMotion.of(context, BuMotion.short),
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: on ? t.danger : t.bd.withValues(alpha: .7)),
        child: on ? Container(width: 8, height: 8, decoration: BoxDecoration(color: t.onPr, shape: BoxShape.circle)) : null,
      ),
    );
  }
}

/// Alt sayfa başlığı: 18/600 ad + sağda yuvarlak kapat düğmesi.
class ChatSheetHeader extends StatelessWidget {
  const ChatSheetHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Row(children: [
      Expanded(
        child: Semantics(
          header: true,
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
        ),
      ),
      const SizedBox(width: 8),
      Semantics(
        button: true,
        label: context.l10n.chatMiscClose,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.maybePop(context),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
                child: Icon(LucideIcons.x, size: 20, color: t.ink),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Alt sayfa arama kutusu: ikincil zeminli, 16 köşe, 52 dp.
class ChatSheetSearch extends StatelessWidget {
  const ChatSheetSearch({super.key, required this.hint, required this.controller, required this.onChanged, this.autofocus = false});

  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bMd),
      child: Row(children: [
        ExcludeSemantics(child: Icon(LucideIcons.search, size: 20, color: t.mut)),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            cursorColor: t.pr,
            style: tx.bodyLarge!.copyWith(color: t.ink),
            decoration: InputDecoration(
              isCollapsed: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              hintText: hint,
              hintStyle: tx.bodyLarge!.copyWith(color: t.mut),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Arama altı bilgi satırı ("En fazla 5 sohbet seçilebilir."): küçük bilgi simgesi + 12 dp yazı; [warn] kırmızı.
class ChatSheetHint extends StatelessWidget {
  const ChatSheetHint(this.text, {super.key, this.warn = false});

  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final c = warn ? t.danger : t.mut;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 2), child: Icon(LucideIcons.info, size: 14, color: c)),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: chatInfoBody12(context, color: c))),
    ]);
  }
}

/// Sessize alma süresi alt sayfası (22-1): başlık + sohbet adı, üç seçenek, "Sessize al" ve "Vazgeç".
/// Dönüş: `480` | `10080` | `forever`; vazgeçilirse null.
Future<String?> showChatMuteSheet(BuildContext context, {required String chatName}) {
  final l = context.l10n;
  return BuSheet.show<String>(
    context,
    padding: const EdgeInsets.symmetric(horizontal: kChatInfoMargin),
    builder: (c) {
      final t = c.bu;
      var pick = '480';
      return StatefulBuilder(
        builder: (c, set) {
          Widget row(String id, IconData icon, String label) {
            final on = pick == id;
            return Semantics(
              inMutuallyExclusiveGroup: true,
              checked: on,
              button: true,
              child: Material(
                color: on ? t.soft : Colors.transparent,
                borderRadius: BuRadius.bMd,
                child: InkWell(
                  borderRadius: BuRadius.bMd,
                  onTap: () {
                    buHaptic(BuHaptic.selection);
                    set(() => pick = id);
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 64),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(children: [
                        ChatInfoIconDot(icon: icon, soft: on, size: 36),
                        const SizedBox(width: 12),
                        Expanded(child: Text(label, style: chatInfoTitle16(c, color: on ? t.onSoft : t.ink))),
                        const SizedBox(width: 8),
                        ChatSheetRadio(on: on),
                      ]),
                    ),
                  ),
                ),
              ),
            );
          }

          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(LucideIcons.bellOff, size: 20, color: t.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l.chatInfoMuteNotifications,
                      style: Theme.of(c).textTheme.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Text(chatName, maxLines: 1, overflow: TextOverflow.ellipsis, style: chatInfoBody14(c)),
            const SizedBox(height: 16),
            row('480', LucideIcons.clock, l.chatInfoMute8h),
            row('10080', LucideIcons.calendarDays, l.chatInfoMute1w),
            row('forever', LucideIcons.bellOff, l.chatInfoMuteForever),
            const SizedBox(height: 20),
            BuButton(label: l.chatInfoMute, icon: LucideIcons.bellRing, onPressed: () => Navigator.pop(c, pick)),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(c),
              style: TextButton.styleFrom(foregroundColor: t.ink, minimumSize: const Size(0, 48)),
              child: Text(l.chatInfoCancel, style: chatInfoTitle16(c)),
            ),
          ]);
        },
      );
    },
  );
}

/// Grup adı penceresi (22-5): altta açılan kart; soluk simge + başlık + kapat, alan (temizle, sayaç), hata satırı,
/// sağda Vazgeç / Kaydet. Dönüş: yeni ad; vazgeçilirse null.
Future<String?> showChatRenameDialog(BuildContext context, {required String initial, int maxLength = 60}) {
  final t = context.bu;
  return showDialog<String>(
    context: context,
    barrierColor: t.ink.withValues(alpha: .4),
    builder: (_) => _RenameDialog(initial: initial, maxLength: maxLength),
  );
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial, required this.maxLength});

  final String initial;
  final int maxLength;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _ctl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      alignment: Alignment.bottomCenter,
      backgroundColor: dark ? t.sf3 : t.sf,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(kChatInfoMargin),
      shape: const RoundedRectangleBorder(borderRadius: BuRadius.bLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ListenableBuilder(
            listenable: _ctl,
            builder: (context, _) {
              final v = _ctl.text.trim();
              return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                    child: Icon(LucideIcons.pencil, size: 16, color: t.onSoft),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(l.chatInfoGroupName, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      tooltip: l.commonClose,
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
                        child: Icon(LucideIcons.x, size: 18, color: t.ink),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 8, 8),
                  decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bSm),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _ctl,
                          autofocus: true,
                          maxLength: widget.maxLength,
                          cursorColor: t.pr,
                          style: chatInfoTitle16(context),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            counterText: '',
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            hintText: l.chatInfoGroupName,
                          ),
                        ),
                      ),
                      if (_ctl.text.isNotEmpty)
                        IconButton(
                          tooltip: l.commonClose,
                          onPressed: _ctl.clear,
                          icon: Icon(LucideIcons.circleX, size: 20, color: t.mut),
                        ),
                    ]),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: Text('${_ctl.text.characters.length}/${widget.maxLength}',
                          textAlign: TextAlign.end, style: chatInfoBody12(context)),
                    ),
                  ]),
                ),
                if (v.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      Icon(LucideIcons.circleAlert, size: 14, color: t.danger),
                      const SizedBox(width: 6),
                      Expanded(child: Text(l.chatMiscGroupNameRequired, style: chatInfoLabel12(context, color: t.danger).copyWith(fontWeight: FontWeight.w400))),
                    ]),
                  ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Flexible(child: ChatDialogButton(label: l.chatInfoCancel, onTap: () => Navigator.pop(context), minHeight: 48)),
                  const SizedBox(width: 8),
                  Flexible(
                      child: ChatDialogButton(
                          label: l.chatInfoSave,
                          icon: LucideIcons.check,
                          destructive: true,
                          minHeight: 48,
                          onTap: v.isEmpty ? null : () => Navigator.pop(context, v))),
                ]),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

/// Grup fotoğrafı kaynak sayfası (22-6): Galeriden seç / Fotoğraf çek / (varsa) Fotoğrafı kaldır; [error] verilirse
/// altta uyarı kartı. İptalde null.
Future<PhotoSource?> showChatPhotoSheet(
  BuildContext context, {
  required String name,
  String? avatarUrl,
  Map<String, String>? headers,
  bool removable = false,
  String? error,
}) {
  final l = context.l10n;
  return BuSheet.show<PhotoSource>(
    context,
    padding: const EdgeInsets.symmetric(horizontal: kChatInfoMargin),
    builder: (c) {
      final t = c.bu;
      Widget row(Key key, IconData icon, String label, PhotoSource v, {bool danger = false}) {
        return Semantics(
          button: true,
          child: Material(
            color: danger ? t.soft.withValues(alpha: .6) : Colors.transparent,
            borderRadius: BuRadius.bMd,
            child: InkWell(
              key: key,
              borderRadius: BuRadius.bMd,
              onTap: () => Navigator.pop(c, v),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: danger ? t.danger.withValues(alpha: .15) : t.sf2, borderRadius: BuRadius.bSm),
                        child: Icon(icon, size: 20, color: danger ? t.danger : t.ink),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Text(label, style: chatInfoTitle16(c, color: danger ? t.danger : t.ink).copyWith(fontWeight: FontWeight.w500))),
                    Icon(buDirIcon(c, LucideIcons.chevronRight), size: 20, color: danger ? t.danger : t.mut),
                  ]),
                ),
              ),
            ),
          ),
        );
      }

      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(alignment: Alignment.center, children: [
              ChatlistAvatar(name: name, url: avatarUrl, group: true, circle: true, size: 48, headers: headers),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: t.scrim.withValues(alpha: .35), shape: BoxShape.circle),
                child: Icon(LucideIcons.camera, size: 20, color: t.onMedia),
              ),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(l.chatInfoChangePhoto,
                  style: Theme.of(c).textTheme.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        row(const ValueKey('photoSrcGallery'), LucideIcons.images, l.chatInfoPickGallery, PhotoSource.gallery),
        row(const ValueKey('photoSrcCamera'), LucideIcons.camera, l.p04SrcCamera, PhotoSource.camera),
        if (removable) row(const ValueKey('photoSrcRemove'), LucideIcons.trash2, l.chatInfoRemovePhoto, PhotoSource.remove, danger: true),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              key: const ValueKey('photoSrcError'),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bMd),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 2), child: Icon(LucideIcons.circleAlert, size: 16, color: t.danger)),
                const SizedBox(width: 12),
                Expanded(child: Text(error, style: chatInfoBody14(c, color: t.ink))),
              ]),
            ),
          ),
        const SizedBox(height: 16),
        ChatDialogButton(label: l.chatInfoCancel, minHeight: BuSize.button, onTap: () => Navigator.pop(c)),
      ]);
    },
  );
}

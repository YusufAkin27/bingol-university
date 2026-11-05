import 'package:flutter/material.dart';

import '../../core/push/push_router.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/profile_photo_viewer.dart' show AvatarLongPress;

/// Sohbet listesi bileşenleri (referans 18).

/// "Yeni sohbet" kırmızı yuvarlak düğme (44 dp görünür / 48 dp dokunma alanı, yumuşak kırmızı gölge).
class ChatlistNewButton extends StatelessWidget {
  const ChatlistNewButton({super.key, required this.tooltip, required this.onTap, this.quiet = false});

  final String tooltip;
  final VoidCallback onTap;

  /// Eski yumuşak-zemin seçeneği; Stitch v3'te düğme her durumda düz ikondur (parametre uyumluluk için durur).
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: BuPressable(
          onTap: onTap,
          haptic: BuHaptic.light,
          // 48 dp dokunma alanı, 40 dp görünür daire (+ eylemi); tek birincil eylem, gölgesiz.
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              // Stitch v3 liste: daire/çerçeve yok, 24 dp çizgi ikon (tek birincil eylem sayfadaki boş durum düğmesidir).
              child: Icon(BuIcons.plus, size: 24, color: t.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sakin yuvarlak simge düğmesi (Arşiv): 48 dp dokunma alanı, nötr zemin, çerçevesiz.
class ChatlistRoundButton extends StatelessWidget {
  const ChatlistRoundButton({super.key, required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: BuPressable(
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Icon(icon, size: 24, color: t.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// Arama kutusu: 52 dp, 18 dp köşe, yüzey rengi + ince çizgi; yazı varken temizle düğmesi.
class ChatlistSearch extends StatelessWidget {
  const ChatlistSearch({super.key, required this.hint, required this.onChanged, this.controller});

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Container(
      height: BuSize.field,
      padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
      decoration: BoxDecoration(
        borderRadius: BuRadius.bMd,
        border: Border.all(color: t.bdStrong),
      ),
      child: Row(
        children: [
          Icon(BuIcons.search, size: 18, color: t.mut),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: tx.bodyLarge!.copyWith(color: t.ink),
              cursorColor: t.pr,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: hint,
                hintStyle: tx.bodyLarge!.copyWith(color: t.mut),
              ),
            ),
          ),
          if (controller != null)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller!,
              builder: (c, v, _) => v.text.isEmpty
                  ? const SizedBox(width: 8)
                  : IconButton(
                      tooltip: MaterialLocalizations.of(c).deleteButtonTooltip,
                      onPressed: () {
                        controller!.clear();
                        onChanged('');
                      },
                      icon: Icon(BuIcons.x, size: 16, color: t.mut),
                    ),
            ),
        ],
      ),
    );
  }
}

/// Segment: sf2 zemin, 16 px köşe, seçili öğe yüzey rengi + gölge. (Eski görünüm; liste artık [BuChipRow] kullanır.)
class ChatlistSegment extends StatelessWidget {
  const ChatlistSegment({super.key, required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return BuSegmented(items: labels, index: selected, onChanged: onSelect);
  }
}

/// Satır avatarı: 52 dp yuvarlatılmış kare; fotoğraf varsa foto, yoksa varsayılan profil görseli ([BuDefaultAvatar]).
/// [badge] kulüp/etkinlik odası için köşe işareti, [online] çevrimiçi noktası.
class ChatlistAvatar extends StatelessWidget {
  const ChatlistAvatar({
    super.key,
    required this.name,
    this.url,
    this.group = false,
    this.size = 52,
    this.online = false,
    this.badge,
    this.badgeAtTop = false,
    this.circle = false,
    this.headers,
    this.heroTag,
    this.cornerRadius,
    this.preview = false,
  });

  /// true: UZUN BASMA büyük fotoğraf önizlemesini açar ([AvatarLongPress], diğer avatarlarla tutarlı); fotoğraf yoksa
  /// (ya da gizliyse) hiçbir şey açılmaz ve dokunuş/uzun basma üstteki satıra düşer.
  final bool preview;

  /// Köşe yarıçapını sabitler (varsayılan: boyutun %34'ü; büyük avatarda 20 dp).
  final double? cornerRadius;

  /// Liste -> konuşma geçişinde paylaşılan avatar uçuşu etiketi (`chat-avatar-<id>`); null: Hero yok.
  final Object? heroTag;

  /// Yetkili (`/api/...`) avatar adresleri için istek başlıkları. Verilmezse `/api/` adreslerinde oturumun
  /// Bearer başlığı kendiliğinden eklenir ([authHeadersFor]); `/files/...` herkese açık adreslerde başlık gitmez.
  final Map<String, String>? headers;

  /// Testlerde oturum yerine kullanılacak başlık kaynağı.
  @visibleForTesting
  static Map<String, String>? Function()? authProvider;

  static Session? _bound;

  /// Sohbet sekmesi oturumu bağlar (push yolu henüz kurulmamış olsa da avatarlar yetkili istenir).
  static void bindSession(Session s) => _bound = s;

  /// [url] için varsayılan başlıklar: yalnız `/api/` ile başlayan göreli adreslerde Bearer.
  static Map<String, String>? authHeadersFor(String? url) {
    if (url == null || !url.startsWith('/api/')) return null;
    final custom = authProvider;
    if (custom != null) return custom();
    final tok = (_bound ?? PushRouter.session)?.api.tokens?.access;
    return tok == null ? null : {'Authorization': 'Bearer $tok'};
  }

  /// true: yuvarlak (sohbet içi 28 dp gönderen avatarı); false: yuvarlatılmış kare (liste).
  final bool circle;

  final String name;
  final String? url;
  final bool group;
  final double size;
  final bool online;

  /// Köşe işareti simgesi (kulüp: megafon, etkinlik: takvim).
  final IconData? badge;

  /// true: işaret üst başta (kulüp), false: alt sonda (etkinlik).
  final bool badgeAtTop;

  @override
  Widget build(BuildContext context) {
    final avatar = _avatar(context);
    if (!preview) return avatar;
    return AvatarLongPress(imageUrl: url, headers: headers ?? authHeadersFor(url), title: name, child: avatar);
  }

  Widget _avatar(BuildContext context) {
    final t = context.bu;
    final radius = circle ? size / 2 : (cornerRadius ?? size * .34);
    // Tek kişi avatarı yolu [BuAvatar]: fotoğraf varsa o; yoksa/yüklenirken/hata verince varsayılan profil görseli.
    final base = ExcludeSemantics(
      child: BuAvatar(
        name: name,
        url: url,
        size: size,
        radius: radius,
        group: group,
        headers: headers ?? authHeadersFor(url),
      ),
    );
    final Widget shown = heroTag == null ? base : BuHero(tag: heroTag!, radius: radius, child: base);
    if (!online && badge == null) return shown;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        shown,
        if (badge != null)
          PositionedDirectional(
            start: badgeAtTop ? -4 : null,
            end: badgeAtTop ? null : -4,
            top: badgeAtTop ? -4 : null,
            bottom: badgeAtTop ? null : -4,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: t.sf2, // tür işareti nötr (renk vurgusu yok)
                shape: BoxShape.circle,
                border: Border.all(color: t.bg, width: 2),
              ),
              child: Icon(badge, size: 11, color: t.ink),
            ),
          ),
        if (online)
          PositionedDirectional(
            end: -3,
            bottom: -3,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(color: t.ok, shape: BoxShape.circle, border: Border.all(color: t.bg, width: 2.5)),
            ),
          ),
      ]),
    );
  }
}

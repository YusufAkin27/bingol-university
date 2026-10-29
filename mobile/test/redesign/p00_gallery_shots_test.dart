@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';

import '../support/fake_app.dart';

/// P0 tasarim sistemi galerisi: tema + tum ortak bilesenler (acik/koyu, tr/ar, yazi olcegi 1.3).
///
/// Varsayilan `flutter test` ile CALISMAZ (ortam degiskeni yoksa atlanir). Uretim (C:\bu_mobile icinde, Git Bash):
///   STORE_SHOTS_OUT='C:/Users/.../redesign/p00/sonraki' flutter test test/redesign/p00_gallery_shots_test.dart
/// Istege bagli: `P00_LANG=tr|ar` (varsayilan tr), `P00_ONLY=01,05`, `P00_MODES=light,dark,x13` (varsayilan hepsi).
/// Arapca: Windows'ta Arial yuklenir (testte sistem yedek yazi tipi yok); yalniz yerlesimi gormek icindir.
const _dpr = 2.5;

String _lang = 'tr';
String s(String tr, String en, String ar) => switch (_lang) {
      'ar' => ar,
      'en' => en,
      _ => tr,
    };

class _Board {
  const _Board(this.file, this.build, {this.height = 1400, this.after});
  final String file;
  final Widget Function() build;
  final double height;
  final Future<void> Function(WidgetTester t)? after;
}

class _Variant {
  const _Variant(this.suffix, this.dark, this.scale);
  final String suffix;
  final bool dark;
  final double scale;
}

Widget _app(Widget home, bool dark, GlobalKey key, double scale) {
  final lang = _lang;
  return RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.forLocale(Brightness.light, lang),
      darkTheme: BuTheme.forLocale(Brightness.dark, lang),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home,
    ),
  );
}

Future<void> _loadFonts(bool arabic) async {
  if (!arabic) return loadTestFonts();
  final f = FontLoader('Inter');
  for (final n in ['arial.ttf', 'arialbd.ttf']) {
    final file = File('C:/Windows/Fonts/$n');
    if (file.existsSync()) f.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await f.load();
  await loadIconFonts();
}

// ---------------------------------------------------------------------------------------------------------------
// Pano yardimcilari

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _Sec extends StatelessWidget {
  const _Sec(this.title, this.child);
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelSmall!.copyWith(color: context.bu.mut, letterSpacing: _lang == 'ar' ? 0 : .8)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}

// ---------------------------------------------------------------------------------------------------------------
// Panolar

Widget _boardColors() => Builder(builder: (context) {
      final t = context.bu;
      final tx = Theme.of(context).textTheme;
      Widget sw(String name, Color c, Color on) => Container(
            width: 104,
            height: 56,
            padding: const EdgeInsets.all(8),
            alignment: AlignmentDirectional.bottomStart,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.bd)),
            child: Text(name, style: tx.labelSmall!.copyWith(color: on, fontWeight: FontWeight.w700)),
          );
      return _Page(title: s('Renk ve yazı', 'Color & type', 'اللون والخط'), children: [
        _Sec(
          s('Yüzeyler', 'Surfaces', 'الأسطح'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            sw('bg', t.bg, t.ink),
            sw('sf', t.sf, t.ink),
            sw('sf2', t.sf2, t.ink),
            sw('sf3', t.sf3, t.ink),
            sw('nav', t.nav, t.onNav),
            sw('bd', t.bd, t.ink),
          ]),
        ),
        _Sec(
          s('Marka ve anlam', 'Brand & semantic', 'العلامة والدلالة'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            sw('pr', t.pr, t.onPr),
            sw('soft', t.soft, t.onSoft),
            sw('ok', t.ok, t.onPr),
            sw('okSoft', t.okSoft, t.ok),
            sw('warn', t.warnSoft, t.onWarnSoft),
            sw('danger', t.danger, Theme.of(context).colorScheme.onError),
            sw('ink', t.ink, t.bg),
            sw('mut', t.mut, t.bg),
          ]),
        ),
        _Sec(
          s('Kategori renkleri', 'Category tints', 'ألوان الفئات'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < t.tints.length; i++) sw('tint $i', t.tints[i].bg, t.tints[i].fg),
          ]),
        ),
        _Sec(
          s('Yazı ölçeği', 'Type scale', 'سلم الخط'),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s('Display 40', 'Display 40', 'عرض ٤٠'), style: tx.displayLarge),
            Text(s('Headline L 28', 'Headline L 28', 'عنوان ٢٨'), style: tx.headlineLarge),
            Text(s('Headline M 24', 'Headline M 24', 'عنوان ٢٤'), style: tx.headlineMedium),
            Text(s('Headline S 20', 'Headline S 20', 'عنوان ٢٠'), style: tx.headlineSmall),
            Text(s('Title L 18 Bingöl Üniversitesi', 'Title L 18 Bingol University', 'عنوان ١٨ جامعة بينغول'), style: tx.titleLarge),
            Text(s('Title M 15.3 Kampüs haberleri', 'Title M 15.3 Campus news', 'عنوان ١٥ أخبار الحرم'), style: tx.titleMedium),
            Text(s('Title S 13.5 Etkinlik takvimi', 'Title S 13.5 Event calendar', 'عنوان ١٣ تقويم الفعاليات'), style: tx.titleSmall),
            Text(s('Body L 15 Yemek listesi ve duyurular burada.', 'Body L 15 Menus and announcements live here.', 'نص ١٥ قوائم الطعام والإعلانات هنا.'), style: tx.bodyLarge),
            Text(s('Body M 13.5 Yemek listesi ve duyurular burada.', 'Body M 13.5 Menus and announcements live here.', 'نص ١٣ قوائم الطعام والإعلانات هنا.'), style: tx.bodyMedium),
            Text(s('Body S 12 Yardımcı açıklama metni', 'Body S 12 Helper caption text', 'نص ١٢ شرح مساعد'), style: tx.bodySmall),
            Text(s('Label L 13.5 Düğme', 'Label L 13.5 Button', 'زر ١٣'), style: tx.labelLarge),
            Text(s('Label M 12 Çip', 'Label M 12 Chip', 'شريحة ١٢'), style: tx.labelMedium),
            Text(s('Label S 11 Zaman 14:30', 'Label S 11 Time 14:30', 'وقت ١١ ١٤:٣٠'), style: tx.labelSmall),
          ]),
        ),
      ]);
    });

Widget _boardButtons() => Builder(builder: (context) {
      return _Page(title: s('Düğmeler ve çipler', 'Buttons & chips', 'الأزرار والشرائح'), children: [
        _Sec(
          'BuButton',
          Column(children: [
            BuButton(label: s('Devam et', 'Continue', 'متابعة'), icon: LucideIcons.arrowRight, onPressed: () {}),
            const SizedBox(height: 8),
            BuButton(label: s('Tonal', 'Tonal', 'تونال'), kind: BuButtonKind.soft, onPressed: () {}),
            const SizedBox(height: 8),
            BuButton(label: s('Çerçeveli', 'Outlined', 'محدد'), kind: BuButtonKind.outline, onPressed: () {}),
            const SizedBox(height: 8),
            BuButton(label: s('Hesabı sil', 'Delete account', 'حذف الحساب'), kind: BuButtonKind.danger, icon: LucideIcons.trash2, onPressed: () {}),
            const SizedBox(height: 8),
            BuButton(label: s('Gönderiliyor', 'Sending', 'جارٍ الإرسال'), busy: true, onPressed: () {}),
            const SizedBox(height: 8),
            BuButton(label: s('Devre dışı', 'Disabled', 'معطل')),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              BuButton(label: s('Katıl', 'Join', 'انضم'), compact: true, onPressed: () {}),
              BuButton(label: s('Takip', 'Follow', 'متابعة'), compact: true, kind: BuButtonKind.soft, onPressed: () {}),
              BuButton(label: s('Ayrıl', 'Leave', 'مغادرة'), compact: true, kind: BuButtonKind.outline, onPressed: () {}),
              BuButton(label: s('Tümü', 'All', 'الكل'), compact: true, kind: BuButtonKind.text, onPressed: () {}),
            ]),
          ]),
        ),
        _Sec(
          'Material 3',
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () {}, child: const Text('Filled')),
            FilledButton.tonal(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () {}, child: const Text('Tonal')),
            OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () {}, child: const Text('Outlined')),
            TextButton(onPressed: () {}, child: const Text('Text')),
            IconButton(onPressed: () {}, icon: const Icon(LucideIcons.heart)),
            IconButton.filledTonal(onPressed: () {}, icon: const Icon(LucideIcons.share2)),
            FloatingActionButton.small(onPressed: () {}, child: const Icon(LucideIcons.plus)),
            FloatingActionButton.extended(onPressed: () {}, icon: const Icon(LucideIcons.plus), label: Text(s('Yeni', 'New', 'جديد'))),
          ]),
        ),
        _Sec(
          s('Segment', 'Segmented', 'مقاطع'),
          Column(children: [
            BuSegmented(items: [s('Keşfet', 'Explore', 'استكشاف'), s('Kulüplerim', 'My clubs', 'نواديّ'), s('Etkinlik', 'Events', 'فعاليات')], index: 1, onChanged: (_) {}),
            const SizedBox(height: 10),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(s('Gün', 'Day', 'يوم'))),
                ButtonSegment(value: 1, label: Text(s('Hafta', 'Week', 'أسبوع'))),
                ButtonSegment(value: 2, label: Text(s('Ay', 'Month', 'شهر'))),
              ],
              selected: const {1},
              onSelectionChanged: (_) {},
            ),
          ]),
        ),
        _Sec(
          s('Çipler', 'Chips', 'شرائح'),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            BuChipRow(
              labels: [s('Hepsi', 'All', 'الكل'), s('Haber', 'News', 'أخبار'), s('Duyuru', 'Notices', 'إعلانات'), s('Etkinlik', 'Events', 'فعاليات'), s('Yemek', 'Food', 'طعام')],
              selected: 1,
              onSelected: (_) {},
              padding: EdgeInsets.zero,
            ),
            Wrap(spacing: 8, runSpacing: 4, children: [
              FilterChip(label: Text(s('Filtre', 'Filter', 'تصفية')), selected: true, onSelected: (_) {}),
              FilterChip(label: Text(s('Filtre', 'Filter', 'تصفية')), selected: false, onSelected: (_) {}),
              ChoiceChip(label: Text(s('Seçim', 'Choice', 'خيار')), selected: true, onSelected: (_) {}),
              InputChip(label: Text(s('Etiket', 'Tag', 'وسم')), onDeleted: () {}),
              ActionChip(avatar: const Icon(LucideIcons.calendar, size: 16), label: Text(s('Takvime ekle', 'Add to calendar', 'أضف للتقويم')), onPressed: () {}),
            ]),
          ]),
        ),
      ]);
    });

Widget _boardInputs() => Builder(builder: (context) {
      final t = context.bu;
      return _Page(title: s('Girdiler ve kontroller', 'Inputs & controls', 'الإدخال والعناصر'), children: [
        _Sec(
          s('Metin alanları', 'Text fields', 'حقول النص'),
          Column(children: [
            TextField(decoration: InputDecoration(labelText: s('E-posta', 'Email', 'البريد'), prefixIcon: const Icon(LucideIcons.mail))),
            const SizedBox(height: 10),
            TextField(
              controller: TextEditingController(text: 'ayse@bingol.edu.tr'),
              autofocus: true,
              decoration: InputDecoration(labelText: s('Odakta', 'Focused', 'نشط'), helperText: s('Kurumsal adres', 'Institutional address', 'عنوان مؤسسي')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: TextEditingController(text: 'abc'),
              decoration: InputDecoration(labelText: s('Şifre', 'Password', 'كلمة المرور'), errorText: s('En az 8 karakter olmalı', 'At least 8 characters', 'ثمانية أحرف على الأقل'), suffixIcon: const Icon(LucideIcons.eye)),
            ),
            const SizedBox(height: 10),
            BuSearchField(hint: s('Haber, kulüp, kişi ara', 'Search news, clubs, people', 'ابحث عن أخبار ونوادٍ وأشخاص'), controller: TextEditingController(text: s('kampüs', 'campus', 'الحرم'))),
            const SizedBox(height: 10),
            SearchBar(hintText: s('M3 SearchBar', 'M3 SearchBar', 'شريط بحث M3'), leading: const Icon(LucideIcons.search)),
          ]),
        ),
        _Sec(
          s('Seçim kontrolleri', 'Selection controls', 'عناصر الاختيار'),
          Column(children: [
            Row(children: [
              Switch(value: true, onChanged: (_) {}),
              Switch(value: false, onChanged: (_) {}),
              Checkbox(value: true, onChanged: (_) {}),
              Checkbox(value: false, onChanged: (_) {}),
              Radio<int>(value: 1, groupValue: 1, onChanged: (_) {}),
              Radio<int>(value: 2, groupValue: 1, onChanged: (_) {}),
            ]),
            Slider(value: .4, onChanged: (_) {}),
          ]),
        ),
        _Sec(
          s('İlerleme', 'Progress', 'التقدم'),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const LinearProgressIndicator(value: .6),
            const SizedBox(height: 14),
            Row(children: [
              const CircularProgressIndicator(value: .7),
              const SizedBox(width: 16),
              Badge(label: const Text('3'), child: Icon(LucideIcons.bell, color: t.ink)),
              const SizedBox(width: 16),
              const Badge(),
            ]),
            const SizedBox(height: 14),
            BuProgressSteps(count: 3, current: 1, labels: [s('Bilgi', 'Info', 'معلومات'), s('Kişisel', 'Personal', 'شخصي'), s('Şifre', 'Password', 'كلمة المرور')]),
          ]),
        ),
        _Sec(
          s('Sekmeler', 'Tabs', 'علامات التبويب'),
          SizedBox(
            height: 52,
            child: DefaultTabController(
              length: 3,
              initialIndex: 1,
              child: TabBar(tabs: [Tab(text: s('Gönderiler', 'Posts', 'منشورات')), Tab(text: s('Etkinlikler', 'Events', 'فعاليات')), Tab(text: s('Üyeler', 'Members', 'الأعضاء'))]),
            ),
          ),
        ),
        _Sec(
          s('Alt gezinme', 'Navigation bar', 'شريط التنقل'),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: NavigationBar(
              selectedIndex: 2,
              onDestinationSelected: (_) {},
              destinations: [
                NavigationDestination(icon: const Icon(LucideIcons.house), label: s('Ana Sayfa', 'Home', 'الرئيسية')),
                NavigationDestination(icon: const Icon(LucideIcons.compass), label: s('Keşfet', 'Explore', 'استكشاف')),
                NavigationDestination(icon: Badge(label: const Text('2'), child: const Icon(LucideIcons.messageCircle)), label: s('Sohbet', 'Chat', 'محادثة')),
                NavigationDestination(icon: const Icon(LucideIcons.users), label: s('Kulüpler', 'Clubs', 'النوادي')),
                NavigationDestination(icon: const Icon(LucideIcons.user), label: s('Profil', 'Profile', 'الملف')),
              ],
            ),
          ),
        ),
      ]);
    });

Widget _boardCards() => Builder(builder: (context) {
      final t = context.bu;
      Widget cardBody(String name) => Row(children: [
            const BuAvatar(name: 'Ayşe Kaya', size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: Theme.of(context).textTheme.titleSmall),
                Text(s('Bugün 14:30', 'Today 14:30', 'اليوم ١٤:٣٠'), style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.mut)),
              ]),
            ),
          ]);
      return _Page(title: s('Kartlar ve listeler', 'Cards & lists', 'البطاقات والقوائم'), children: [
        _Sec(
          'BuCard',
          Column(children: [
            BuCard(onTap: () {}, child: cardBody('outlined')),
            const SizedBox(height: 10),
            BuCard(style: BuCardStyle.filled, child: cardBody('filled')),
            const SizedBox(height: 10),
            BuCard(style: BuCardStyle.elevated, child: cardBody('elevated')),
            const SizedBox(height: 10),
            BuCard(style: BuCardStyle.tonal, child: cardBody('tonal')),
          ]),
        ),
        _Sec(
          s('Ayar listesi', 'Settings list', 'قائمة الإعدادات'),
          BuGroup(dividerIndent: 66, children: [
            BuSettingsTile(icon: LucideIcons.user, title: s('Profili düzenle', 'Edit profile', 'تعديل الملف'), onTap: () {}),
            BuSettingsTile(icon: LucideIcons.globe, title: s('Dil', 'Language', 'اللغة'), value: s('Türkçe', 'English', 'العربية'), tint: t.tint(1), onTap: () {}),
            BuSettingsTile.toggle(icon: LucideIcons.bell, title: s('Bildirimler', 'Notifications', 'الإشعارات'), subtitle: s('Yeni mesaj ve duyurular', 'New messages and notices', 'رسائل وإعلانات جديدة'), value: true, onChanged: (_) {}, tint: t.tint(3)),
            BuSettingsTile(icon: LucideIcons.logOut, title: s('Çıkış yap', 'Sign out', 'تسجيل الخروج'), danger: true, onTap: () {}),
          ]),
        ),
        _Sec(
          s('Liste satırları', 'List tiles', 'عناصر القائمة'),
          BuGroup(children: [
            BuListTile(
              leading: const BuAvatar(name: 'Mehmet Demir', size: 44, online: true),
              title: 'Mehmet Demir',
              subtitle: s('Yarınki sınav saat kaçta?', 'What time is the exam?', 'متى الامتحان غدًا؟'),
              trailing: const Column(mainAxisSize: MainAxisSize.min, children: [BuCountBadge(3)]),
              onTap: () {},
            ),
            BuListTile(
              leading: const BuAvatar(name: 'Bilgisayar Kulübü', size: 44, square: true, group: true),
              title: s('Bilgisayar Mühendisliği Kulübü', 'Computer Engineering Club', 'نادي هندسة الحاسوب'),
              subtitle: s('128 üye', '128 members', '١٢٨ عضوًا'),
              showChevron: true,
              selected: true,
              onTap: () {},
            ),
            BuMenuRow(icon: LucideIcons.bookmark, label: s('Kaydedilenler', 'Saved', 'المحفوظات'), onTap: () {}),
          ]),
        ),
        _Sec(
          s('Başlık, rozet, avatar', 'Header, badges, avatars', 'عنوان وشارات وصور'),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            BuSectionHeader(s('Yaklaşan etkinlikler', 'Upcoming events', 'الفعاليات القادمة'), action: s('Tümü', 'All', 'الكل'), onAction: () {}, padding: EdgeInsets.zero),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              BuBadge(s('Yeni', 'New', 'جديد'), soft: true),
              BuBadge(s('Etkinlik', 'Event', 'فعالية')),
              const BuCountBadge(7),
              const BuCountBadge(120),
              const BuCountBadge(2, muted: true),
              const BuAvatar(name: 'Ayşe Kaya', size: 36),
              const BuAvatar(name: 'Ali', size: 48, online: true),
              const BuAvatar(name: 'Grup', size: 48, square: true, group: true),
            ]),
          ]),
        ),
      ]);
    });

Widget _boardStates() => Builder(builder: (context) {
      return _Page(title: s('Boş, hata, iskelet', 'Empty, error, skeleton', 'فارغ وخطأ وهيكل'), children: [
        _Sec(
          s('İllüstrasyonlar', 'Illustrations', 'الرسوم'),
          Wrap(spacing: 4, runSpacing: 4, children: [for (final k in BuIllustration.values) BuIllustrationView(k, size: 84)]),
        ),
        _Sec(
          'BuEmptyState',
          SizedBox(
            height: 330,
            child: BuEmptyState(
              illustration: BuIllustration.message,
              title: s('Henüz sohbet yok', 'No chats yet', 'لا توجد محادثات بعد'),
              message: s('Arkadaşlarınla konuşmaya başla.', 'Start talking with your friends.', 'ابدأ الحديث مع أصدقائك.'),
              actionLabel: s('Yeni sohbet', 'New chat', 'محادثة جديدة'),
              onAction: () {},
            ),
          ),
        ),
        _Sec(
          'BuErrorState',
          SizedBox(
            height: 340,
            child: BuErrorState(error: ApiError(0, 'NETWORK', 'x'), onRetry: () {}),
          ),
        ),
        _Sec('BuOfflineBanner', BuOfflineBanner(onRetry: () {}, margin: EdgeInsets.zero)),
        _Sec(
          'BuSkeleton',
          SizedBox(height: 230, child: BuSkeletonList(variant: BuSkeletonVariant.row, itemCount: 3, padding: EdgeInsets.zero, shrinkWrap: true)),
        ),
      ]);
    });

Widget _boardStates2() => Builder(builder: (context) {
      return _Page(title: s('İskelet düzenleri', 'Skeleton layouts', 'تخطيطات الهيكل'), children: [
        const _Sec('card', SizedBox(height: 250, child: BuSkeletonList(variant: BuSkeletonVariant.card, itemCount: 1, padding: EdgeInsets.zero, shrinkWrap: true))),
        const _Sec('grid', SizedBox(height: 410, child: BuSkeletonList(variant: BuSkeletonVariant.grid, itemCount: 4, padding: EdgeInsets.zero, shrinkWrap: true))),
        _Sec(
          s('Boş durumlar (küçük)', 'Empty states (compact)', 'حالات فارغة'),
          Row(children: [
            Expanded(child: SizedBox(height: 250, child: BuEmptyState(compact: true, illustration: BuIllustration.calendar, title: s('Etkinlik yok', 'No events', 'لا فعاليات'), message: s('Yakında burada olacak', 'Coming soon', 'قريبًا')))),
            Expanded(child: SizedBox(height: 250, child: BuEmptyState(compact: true, illustration: BuIllustration.search, title: s('Sonuç yok', 'No results', 'لا نتائج'), message: s('Başka bir şey dene', 'Try something else', 'جرّب شيئًا آخر')))),
          ]),
        ),
      ]);
    });

Widget _boardHero() => Builder(builder: (context) {
      final tx = Theme.of(context).textTheme;
      Widget hero(BuHeroPattern p, String name) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: BuGradientHero(
              pattern: p,
              minHeight: 130,
              onTap: () {},
              semanticLabel: name,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: tx.labelMedium!.copyWith(color: Colors.white70)),
                const SizedBox(height: 6),
                Text(s('Bahar Şenliği', 'Spring Festival', 'مهرجان الربيع'), style: tx.headlineSmall!.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text(s('12 Mayıs • Merkez Kampüs', 'May 12 • Main Campus', '١٢ مايو • الحرم الرئيسي'), style: tx.bodyMedium!.copyWith(color: Colors.white)),
              ]),
            ),
          );
      return _Page(title: s('Vitrin ve adımlar', 'Hero & steps', 'العرض والخطوات'), children: [
        hero(BuHeroPattern.orbs, 'orbs'),
        hero(BuHeroPattern.rings, 'rings'),
        hero(BuHeroPattern.waves, 'waves'),
        const SizedBox(height: 8),
        BuProgressSteps(count: 4, current: 0),
        const SizedBox(height: 18),
        BuProgressSteps(count: 4, current: 2),
        const SizedBox(height: 18),
        BuProgressSteps(count: 4, current: 3),
      ]);
    });

Widget _scaffoldReady({bool scrolled = false}) => Builder(builder: (context) {
      final t = context.bu;
      return BuPageScaffold(
        title: s('Haberler', 'News', 'الأخبار'),
        onRefresh: () async {},
        actions: [IconButton(onPressed: () {}, icon: const Icon(LucideIcons.search))],
        banner: const BuOfflineBanner(),
        controller: scrolled ? ScrollController(initialScrollOffset: 220) : null,
        bottomInset: 24,
        slivers: [
          SliverToBoxAdapter(
            child: BuChipRow(labels: [s('Hepsi', 'All', 'الكل'), s('Haber', 'News', 'أخبار'), s('Duyuru', 'Notices', 'إعلانات'), s('Etkinlik', 'Events', 'فعاليات')], selected: 0, onSelected: (_) {}),
          ),
          SliverList.builder(
            itemCount: 12,
            itemBuilder: (c, i) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
              child: BuCard(
                onTap: () {},
                child: Row(children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: t.tint(i).bg, borderRadius: BorderRadius.circular(14)),
                    child: Icon(LucideIcons.newspaper, color: t.tint(i).fg),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s('Güz dönemi ders ekleme-bırakma tarihleri açıklandı', 'Add/drop dates for the fall term announced', 'تم الإعلان عن مواعيد الإضافة والحذف'), maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(c).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(s('2 gün önce', '2 days ago', 'قبل يومين'), style: Theme.of(c).textTheme.bodySmall!.copyWith(color: t.mut)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ],
      );
    });

Widget _scaffoldState(BuViewState st) => Builder(builder: (context) {
      return BuPageScaffold(
        title: s('Bildirimler', 'Notifications', 'الإشعارات'),
        state: st,
        error: ApiError(500, 'SERVER_ERROR', 'x'),
        onRetry: () {},
        onRefresh: () async {},
        empty: BuEmptyState(
          illustration: BuIllustration.bell,
          title: s('Bildirimin yok', 'No notifications', 'لا إشعارات'),
          message: s('Yeni gelişmeler burada görünür.', 'New updates will show up here.', 'ستظهر التحديثات الجديدة هنا.'),
        ),
        slivers: const [],
      );
    });

Widget _overlayHost() => Builder(builder: (context) {
      final t = context.bu;
      return Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(title: Text(s('Ayarlar', 'Settings', 'الإعدادات'))),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          for (var i = 0; i < 5; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: BuCard(child: Text(s('Örnek içerik kartı', 'Sample content card', 'بطاقة محتوى')))),
        ]),
        bottomNavigationBar: NavigationBar(selectedIndex: 4, destinations: [
          NavigationDestination(icon: const Icon(LucideIcons.house), label: s('Ana Sayfa', 'Home', 'الرئيسية')),
          NavigationDestination(icon: const Icon(LucideIcons.compass), label: s('Keşfet', 'Explore', 'استكشاف')),
          NavigationDestination(icon: const Icon(LucideIcons.messageCircle), label: s('Sohbet', 'Chat', 'محادثة')),
          NavigationDestination(icon: const Icon(LucideIcons.users), label: s('Kulüpler', 'Clubs', 'النوادي')),
          NavigationDestination(icon: const Icon(LucideIcons.user), label: s('Profil', 'Profile', 'الملف')),
        ]),
      );
    });

BuildContext _ctx(WidgetTester t) => t.element(find.byType(Scaffold).first);

final _boards = <_Board>[
  _Board('01_renk_yazi', _boardColors, height: 1500),
  _Board('02_dugmeler_cipler', _boardButtons, height: 1500),
  _Board('03_girdiler', _boardInputs, height: 1650),
  _Board('04_kartlar_listeler', _boardCards, height: 1800),
  _Board('05_durumlar', _boardStates, height: 1700),
  _Board('06_iskelet_bos', _boardStates2, height: 1100),
  _Board('07_vitrin_adimlar', _boardHero, height: 880),
  _Board('08_sayfa_hazir', () => _scaffoldReady(), height: 844),
  _Board('09_sayfa_kaydirilmis', () => _scaffoldReady(scrolled: true), height: 844),
  _Board('10_sayfa_yukleniyor', () => _scaffoldState(BuViewState.loading), height: 844),
  _Board('11_sayfa_bos', () => _scaffoldState(BuViewState.empty), height: 844),
  _Board('12_sayfa_hata', () => _scaffoldState(BuViewState.error), height: 844),
  _Board('13_diyalog', _overlayHost, height: 844, after: (t) async {
    BuDialog.confirm(_ctx(t),
        title: s('Çıkış yapılsın mı?', 'Sign out?', 'تسجيل الخروج؟'),
        message: s('Bu cihazdaki oturumun kapanacak.', 'Your session on this device will end.', 'ستنتهي جلستك على هذا الجهاز.'),
        confirmLabel: s('Çıkış yap', 'Sign out', 'خروج'),
        destructive: true,
        icon: LucideIcons.logOut);
  }),
  _Board('14_onay_sayfasi', _overlayHost, height: 844, after: (t) async {
    BuConfirmSheet.show(_ctx(t),
        title: s('Gönderi silinsin mi?', 'Delete post?', 'حذف المنشور؟'),
        message: s('Bu işlem geri alınamaz.', 'This cannot be undone.', 'لا يمكن التراجع عن هذا.'),
        confirmLabel: s('Sil', 'Delete', 'حذف'),
        destructive: true);
  }),
  _Board('15_alt_sayfa', _overlayHost, height: 844, after: (t) async {
    BuSheet.show<void>(_ctx(t),
        title: s('Sıralama', 'Sort by', 'الترتيب'),
        subtitle: s('Listeyi nasıl sıralayalım?', 'How should we sort the list?', 'كيف نرتب القائمة؟'),
        actions: [BuButton(label: s('Uygula', 'Apply', 'تطبيق'), onPressed: () {})],
        builder: (c) => Column(children: [
              BuListTile(leading: const Icon(LucideIcons.clock), title: s('En yeni', 'Newest', 'الأحدث'), selected: true, onTap: () {}),
              BuListTile(leading: const Icon(LucideIcons.flame), title: s('En popüler', 'Most popular', 'الأكثر شعبية'), onTap: () {}),
              BuListTile(leading: const Icon(LucideIcons.calendar), title: s('Tarihe göre', 'By date', 'حسب التاريخ'), onTap: () {}),
            ]));
  }),
  _Board('16_toast', _overlayHost, height: 844, after: (t) async {
    BuToast.show(_ctx(t), s('Profil güncellendi', 'Profile updated', 'تم تحديث الملف'), kind: BuToastKind.success, actionLabel: s('Geri al', 'Undo', 'تراجع'), onAction: () {});
  }),
  _Board('17_tarih_secici', _overlayHost, height: 844, after: (t) async {
    showDatePicker(context: _ctx(t), initialDate: DateTime(2026, 10, 29), firstDate: DateTime(2026), lastDate: DateTime(2027));
  }),
  _Board('18_saat_secici', _overlayHost, height: 844, after: (t) async {
    showTimePicker(context: _ctx(t), initialTime: const TimeOfDay(hour: 14, minute: 30));
  }),
];

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  _lang = (Platform.environment['P00_LANG'] ?? 'tr');
  final only = (Platform.environment['P00_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['P00_MODES'] ?? 'light,dark,x13').split(',');
  final variants = <_Variant>[
    if (modes.contains('light')) const _Variant('', false, 1),
    if (modes.contains('dark')) const _Variant('_koyu', true, 1),
    if (modes.contains('x13')) const _Variant('_x1.3', false, 1.3),
  ];

  setUpAll(() => _loadFonts(_lang == 'ar'));

  for (final v in variants) {
    for (final b in _boards) {
      if (only.isNotEmpty && !only.any((o) => b.file.startsWith(o))) continue;
      final name = '${b.file}${v.suffix}_$_lang';
      testWidgets('galeri $name', skip: skip != null, (tester) async {
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(390 * _dpr, b.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);

        final key = GlobalKey();
        await tester.pumpWidget(_app(b.build(), v.dark, key, v.scale));
        // Varsayilan avatar gorselleri testte esenkron cozulur: onceden yukle.
        await tester.runAsync(() async {
          final ctx = tester.element(find.byType(Scaffold).first);
          await precacheImage(const AssetImage('assets/branding/default_avatar.png'), ctx);
          await precacheImage(const AssetImage('assets/branding/default_group.png'), ctx);
        });
        await settle(tester, const Duration(milliseconds: 900));
        if (b.after != null) {
          await b.after!(tester);
          await settle(tester, const Duration(milliseconds: 900));
        }
        final err = tester.takeException();
        if (err != null) fail('Istisna: $err');
        await tester.runAsync(() async {
          final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await ro.toImage(pixelRatio: _dpr);
          final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final dir = Directory(out!)..createSync(recursive: true);
          final f = File('${dir.path}/$name.png')..writeAsBytesSync(data.buffer.asUint8List());
          // ignore: avoid_print
          print('YAZILDI ${f.path} ${image.width}x${image.height}');
        });
        await unmount(tester);
      });
    }
  }
}

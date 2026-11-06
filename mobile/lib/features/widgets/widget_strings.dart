/// Ana ekran widget'larının metinleri (tr/en/ar). Widget tarafında ÇEVİRİ TABLOSU yoktur: uygulama alıcının
/// dilindeki hazır metni snapshot'a yazar (sözleşme: design/widget-previews/DATA_CONTRACT.md). `{n}`, `{time}`,
/// `{date}`, `{day}`, `{kcal}` yer tutucuları yalnız `now`'a bağlı (zamanla değişen) metinlerde widget'a bırakılır.
///
/// Büyük harf başlıklar (caption) Türkçe `i`/`ı` sorunu yüzünden hazır büyük harfle yazılır (Dart toUpperCase
/// yerel ayar duyarsızdır). Rakamlar her dilde Batı rakamıdır (0-9); binlik ayırıcı: tr `.`, en/ar `,`.
library;

const kWidgetLangs = ['tr', 'en', 'ar'];

/// Desteklenmeyen kod Türkçe'ye düşmez, İngilizce'ye düşer (uygulama dil çözümüyle aynı).
String normalizeWidgetLang(String? code) => kWidgetLangs.contains(code) ? code! : 'en';

class WidgetStrings {
  const WidgetStrings._(this.lang, this._m);

  final String lang;
  final Map<String, String> _m;

  static WidgetStrings of(String? lang) {
    final l = normalizeWidgetLang(lang);
    return WidgetStrings._(l, _tables[l]!);
  }

  bool get rtl => lang == 'ar';

  /// Anahtar yoksa ASSERT (testler yakalar), üretimde boş metin (widget çökmez).
  String operator [](String key) {
    final v = _m[key];
    assert(v != null, 'widget metni yok: $key ($lang)');
    return v ?? '';
  }

  /// Yer tutucuları doldurur: `fill('m.totalLine', {'kcal': '1.570'})`.
  String fill(String key, Map<String, String> args) {
    var s = this[key];
    args.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  /// Tüm anahtarlar (testler: üç dil aynı anahtar kümesini taşımalı).
  Iterable<String> get keys => _m.keys;

  /// Binlik ayırıcılı tamsayı: tr `1.570`, en/ar `1,570`.
  String num(int n) {
    final sep = lang == 'tr' ? '.' : ',';
    final neg = n < 0;
    final s = n.abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(sep);
      b.write(s[i]);
    }
    return '${neg ? '-' : ''}$b';
  }

  /// Sayaç: 99'dan büyük `99+`.
  String count(int n) => n > 99 ? '99+' : '$n';

  /// Ay kısaltması BÜYÜK (rozet): OCA ŞUB ... / JAN FEB ... / يناير...
  String monthCaps(int month) => _monthsCaps[lang]![month - 1];

  /// Ay kısaltması (duyuru tarihi `05 Kas`).
  String monthShort(int month) => _monthsShort[lang]![month - 1];

  /// Ay adı (başlık `Cuma, 6 Kasım`).
  String monthName(int month) => _monthsFull[lang]![month - 1];

  /// Gün adı (1 = Pazartesi .. 7 = Pazar).
  String dayName(int weekday) => _daysFull[lang]![weekday - 1];

  /// Kısa gün adı (`Pzt`).
  String dayShort(int weekday) => _daysShort[lang]![weekday - 1];

  static const _monthsCaps = {
    'tr': ['OCA', 'ŞUB', 'MAR', 'NİS', 'MAY', 'HAZ', 'TEM', 'AĞU', 'EYL', 'EKİ', 'KAS', 'ARA'],
    'en': ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'],
    'ar': ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'],
  };
  static const _monthsShort = {
    'tr': ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'],
    'en': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
    'ar': ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'],
  };
  static const _monthsFull = {
    'tr': ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'],
    'en': ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
    'ar': ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'],
  };
  static const _daysFull = {
    'tr': ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'],
    'en': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
    'ar': ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'],
  };
  static const _daysShort = {
    'tr': ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'],
    'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    'ar': ['اث', 'ثل', 'أر', 'خم', 'جم', 'سب', 'أح'],
  };

  static const _tables = <String, Map<String, String>>{'tr': _tr, 'en': _en, 'ar': _ar};
}

const _tr = <String, String>{
  // Ortak
  'signedOutTitle': 'Giriş yap',
  'signedOutSub': "BÜ Kampüs'ü aç",
  'appName': 'BÜ Kampüs',
  // Menü
  'm.caption': 'ÖĞLE',
  'm.captionAny': 'YEMEK',
  'm.captionFull': 'YEMEK MENÜSÜ',
  'm.emptyTitle': 'Bugün menü yok',
  'm.emptySmallSub': 'Yemekhane tatilde olabilir',
  'm.emptySub': 'Menü yayımlanınca burada görünür',
  'm.totalLine': 'Toplam {kcal} kcal',
  'm.kcalToday': '{kcal} kcal bugün',
  'm.dailyTotal': 'Günlük toplam',
  'm.kcalUnit': 'kcal',
  'm.more': '+{n} yemek',
  'm.a11y': 'Bugünün yemek menüsü: {items}',
  // Ders programı
  't.captionNext': 'SIRADAKİ',
  't.captionNone': 'DERS',
  't.captionFull': 'DERS PROGRAMI',
  't.headerNext': '{date} · Sıradaki',
  't.nowBadge': 'Şu an',
  't.inMin': '{n} dk sonra',
  't.inHour': '{n} sa sonra',
  't.endsAt': '{time} biter',
  't.todayCount': 'Bugün {n} ders',
  't.lastEnds': 'Son ders {time} biter',
  't.more': '+{n} ders daha',
  't.emptyTitle': 'Bugün ders yok',
  't.nextSmall': 'Sıradaki: {day}',
  't.nextFull': 'Sıradaki ders: {day}',
  't.a11y': 'Ders programı: {summary}',
  // Etkinlikler
  'e.captionSmall': 'Yaklaşan',
  'e.captionEmpty': 'Etkinlik',
  'e.title': 'Yaklaşan Etkinlikler',
  'e.countLabel': '{n} etkinlik',
  'e.emptyTitle': 'Yaklaşan etkinlik yok',
  'e.emptySub': 'Kulüpler yeni etkinlik eklediğinde burada görünür',
  'e.a11y': 'Yaklaşan etkinlik: {summary}',
  // Duyurular
  'a.titleSmall': 'Duyurular',
  'a.title': 'Kampüs Duyuruları',
  'a.last': 'Son {n}',
  'a.urgent': 'Acil',
  'a.emptyTitle': 'Yeni duyuru yok',
  'a.emptySub': 'Yeni duyurular burada görünür',
  'a.a11y': 'Kampüs duyurusu: {summary}',
  // Anket
  'p.caption': 'ANKET',
  'p.captionFull': 'GÜNÜN ANKETİ',
  'p.vote': 'Oy ver',
  'p.voted': 'Oy verildi',
  'p.voteMicro': '{votes} · gizli',
  'p.voteCount': '{n} oy',
  'p.secretLine': 'Oylar gizlidir · {votes}',
  'p.detail': 'Ayrıntı',
  'p.emptyTitle': 'Bugün anket yok',
  'p.emptySmallSub': 'Yenisi yayımlanınca',
  'p.emptySub': 'Yeni anket yayımlanınca burada görünür',
  'p.a11y': 'Günün anketi: {summary}',
  // Hızlı erişim
  'q.caption': 'HIZLI ERİŞİM',
  'q.heading': 'Neye bakmak istersin?',
  'q.sub': 'Dokun, uygulamada doğrudan aç',
  'q.menu': 'Yemek',
  'q.timetable': 'Ders',
  'q.timetableFull': 'Ders Programı',
  'q.events': 'Etkinlik',
  'q.clubs': 'Kulüpler',
  'q.chat': 'Sohbet',
  'q.qr': 'QR Kodum',
  'q.news': 'Haberler',
  'q.search': 'Ara',
  'q.a11y': 'Hızlı erişim kısayolları',
  // Sosyal özet
  's.captionSmall': 'MESAJ',
  's.captionFull': 'SOSYAL ÖZET',
  's.captionEmpty': 'SOSYAL',
  's.unreadSmall': 'okunmamış mesaj',
  's.labelMessages': 'Mesaj',
  's.labelNotifications': 'Bildirim',
  's.labelLikes': 'Beğeni',
  's.heading': 'Bugün yeni olanlar',
  's.privacyNote': 'Yalnızca sayılar gösterilir',
  's.rowMessages': 'Okunmamış mesaj',
  's.rowNotifications': 'Yeni bildirim',
  's.rowLikes': 'Yeni beğeni ve takipçi',
  's.subMessages': 'Sohbetler',
  's.subNotifications': 'Bildirim kutusu',
  's.subLikes': 'Keşfet',
  's.emptyTitle': 'Her şey güncel',
  's.emptySub': 'Yeni mesaj, bildirim ya da beğeni yok',
  's.a11y': 'Sosyal özet: {summary}',
};

const _en = <String, String>{
  'signedOutTitle': 'Sign in',
  'signedOutSub': 'Open BU Campus',
  'appName': 'BU Campus',
  'm.caption': 'LUNCH',
  'm.captionAny': 'MEAL',
  'm.captionFull': 'MEAL MENU',
  'm.emptyTitle': 'No menu today',
  'm.emptySmallSub': 'The cafeteria may be closed',
  'm.emptySub': 'Appears here once the menu is published',
  'm.totalLine': 'Total {kcal} kcal',
  'm.kcalToday': '{kcal} kcal today',
  'm.dailyTotal': 'Daily total',
  'm.kcalUnit': 'kcal',
  'm.more': '+{n} more',
  'm.a11y': "Today's meal menu: {items}",
  't.captionNext': 'NEXT UP',
  't.captionNone': 'CLASSES',
  't.captionFull': 'TIMETABLE',
  't.headerNext': '{date} · Next up',
  't.nowBadge': 'Now',
  't.inMin': 'in {n} min',
  't.inHour': 'in {n} h',
  't.endsAt': 'ends {time}',
  't.todayCount': '{n} classes today',
  't.lastEnds': 'Last class ends {time}',
  't.more': '+{n} more classes',
  't.emptyTitle': 'No classes today',
  't.nextSmall': 'Next: {day}',
  't.nextFull': 'Next class: {day}',
  't.a11y': 'Timetable: {summary}',
  'e.captionSmall': 'Upcoming',
  'e.captionEmpty': 'Events',
  'e.title': 'Upcoming Events',
  'e.countLabel': '{n} events',
  'e.emptyTitle': 'No upcoming events',
  'e.emptySub': 'New club events will appear here',
  'e.a11y': 'Upcoming event: {summary}',
  'a.titleSmall': 'Announcements',
  'a.title': 'Campus Announcements',
  'a.last': 'Last {n}',
  'a.urgent': 'Urgent',
  'a.emptyTitle': 'No new announcements',
  'a.emptySub': 'New announcements appear here',
  'a.a11y': 'Campus announcement: {summary}',
  'p.caption': 'POLL',
  'p.captionFull': "TODAY'S POLL",
  'p.vote': 'Vote',
  'p.voted': 'Voted',
  'p.voteMicro': '{votes} · private',
  'p.voteCount': '{n} votes',
  'p.secretLine': 'Votes are private · {votes}',
  'p.detail': 'Details',
  'p.emptyTitle': 'No poll today',
  'p.emptySmallSub': 'When a new one is out',
  'p.emptySub': 'A new poll will appear here',
  'p.a11y': "Today's poll: {summary}",
  'q.caption': 'QUICK ACCESS',
  'q.heading': 'What do you want to open?',
  'q.sub': 'Tap to open directly in the app',
  'q.menu': 'Meals',
  'q.timetable': 'Classes',
  'q.timetableFull': 'Timetable',
  'q.events': 'Events',
  'q.clubs': 'Clubs',
  'q.chat': 'Chat',
  'q.qr': 'My QR',
  'q.news': 'News',
  'q.search': 'Search',
  'q.a11y': 'Quick access shortcuts',
  's.captionSmall': 'MESSAGES',
  's.captionFull': 'SOCIAL SUMMARY',
  's.captionEmpty': 'SOCIAL',
  's.unreadSmall': 'unread messages',
  's.labelMessages': 'Messages',
  's.labelNotifications': 'Alerts',
  's.labelLikes': 'Likes',
  's.heading': "What's new today",
  's.privacyNote': 'Only counts are shown',
  's.rowMessages': 'Unread messages',
  's.rowNotifications': 'New notifications',
  's.rowLikes': 'New likes and followers',
  's.subMessages': 'Chats',
  's.subNotifications': 'Notification inbox',
  's.subLikes': 'Discover',
  's.emptyTitle': 'All caught up',
  's.emptySub': 'No new messages, notifications or likes',
  's.a11y': 'Social summary: {summary}',
};

const _ar = <String, String>{
  'signedOutTitle': 'تسجيل الدخول',
  'signedOutSub': 'افتح BÜ Kampüs',
  'appName': 'BÜ Kampüs',
  'm.caption': 'الغداء',
  'm.captionAny': 'الوجبة',
  'm.captionFull': 'قائمة الطعام',
  'm.emptyTitle': 'لا توجد قائمة اليوم',
  'm.emptySmallSub': 'قد تكون الكافتيريا مغلقة',
  'm.emptySub': 'ستظهر هنا عند نشر القائمة',
  'm.totalLine': 'الإجمالي {kcal} سعرة',
  'm.kcalToday': '{kcal} سعرة اليوم',
  'm.dailyTotal': 'الإجمالي اليومي',
  'm.kcalUnit': 'سعرة',
  'm.more': '+{n} أطباق',
  'm.a11y': 'قائمة طعام اليوم: {items}',
  't.captionNext': 'التالية',
  't.captionNone': 'المحاضرات',
  't.captionFull': 'الجدول الدراسي',
  't.headerNext': '{date} · التالية',
  't.nowBadge': 'الآن',
  't.inMin': 'بعد {n} د',
  't.inHour': 'بعد {n} س',
  't.endsAt': 'تنتهي {time}',
  't.todayCount': '{n} محاضرات اليوم',
  't.lastEnds': 'آخر محاضرة تنتهي {time}',
  't.more': '+{n} محاضرات أخرى',
  't.emptyTitle': 'لا محاضرات اليوم',
  't.nextSmall': 'التالية: {day}',
  't.nextFull': 'المحاضرة التالية: {day}',
  't.a11y': 'الجدول الدراسي: {summary}',
  'e.captionSmall': 'القادمة',
  'e.captionEmpty': 'الفعاليات',
  'e.title': 'الفعاليات القادمة',
  'e.countLabel': '{n} فعاليات',
  'e.emptyTitle': 'لا فعاليات قادمة',
  'e.emptySub': 'ستظهر هنا فعاليات الأندية الجديدة',
  'e.a11y': 'فعالية قادمة: {summary}',
  'a.titleSmall': 'الإعلانات',
  'a.title': 'إعلانات الحرم الجامعي',
  'a.last': 'آخر {n}',
  'a.urgent': 'عاجل',
  'a.emptyTitle': 'لا إعلانات جديدة',
  'a.emptySub': 'ستظهر الإعلانات الجديدة هنا',
  'a.a11y': 'إعلان الحرم الجامعي: {summary}',
  'p.caption': 'استطلاع',
  'p.captionFull': 'استطلاع اليوم',
  'p.vote': 'صوّت',
  'p.voted': 'تم التصويت',
  'p.voteMicro': '{votes} · سري',
  'p.voteCount': '{n} صوت',
  'p.secretLine': 'الأصوات سرية · {votes}',
  'p.detail': 'التفاصيل',
  'p.emptyTitle': 'لا استطلاع اليوم',
  'p.emptySmallSub': 'عند نشر استطلاع جديد',
  'p.emptySub': 'سيظهر هنا استطلاع جديد',
  'p.a11y': 'استطلاع اليوم: {summary}',
  'q.caption': 'وصول سريع',
  'q.heading': 'ماذا تريد أن تفتح؟',
  'q.sub': 'اضغط للفتح مباشرة في التطبيق',
  'q.menu': 'الطعام',
  'q.timetable': 'الجدول',
  'q.timetableFull': 'الجدول الدراسي',
  'q.events': 'الفعاليات',
  'q.clubs': 'الأندية',
  'q.chat': 'المحادثات',
  'q.qr': 'رمز QR',
  'q.news': 'الأخبار',
  'q.search': 'بحث',
  'q.a11y': 'اختصارات الوصول السريع',
  's.captionSmall': 'الرسائل',
  's.captionFull': 'ملخص اجتماعي',
  's.captionEmpty': 'اجتماعي',
  's.unreadSmall': 'رسائل غير مقروءة',
  's.labelMessages': 'الرسائل',
  's.labelNotifications': 'الإشعارات',
  's.labelLikes': 'الإعجابات',
  's.heading': 'الجديد اليوم',
  's.privacyNote': 'تُعرض الأعداد فقط',
  's.rowMessages': 'رسائل غير مقروءة',
  's.rowNotifications': 'إشعارات جديدة',
  's.rowLikes': 'إعجابات ومتابعون جدد',
  's.subMessages': 'المحادثات',
  's.subNotifications': 'صندوق الإشعارات',
  's.subLikes': 'استكشاف',
  's.emptyTitle': 'كل شيء محدّث',
  's.emptySub': 'لا رسائل أو إشعارات أو إعجابات جديدة',
  's.a11y': 'الملخص الاجتماعي: {summary}',
};

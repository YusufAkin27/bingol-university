// Telefon çizimlerindeki örnek uygulama metinleri (tr/en/ar). Yalnızca dekoratif çizim içindir:
// kişi adı, fotoğraf ya da gerçek kayıt içermez; kurgusal kulüp/etkinlik adları kullanılır.
// Tarih ve saatler Intl ile üretilir (24-30 Ekim 2026), böylece dile göre biçim kendiliğinden uyar.
import { useMemo } from 'react';
import { useI18n } from '../../../../i18n/I18nProvider';
import type { Lang } from '../../../../i18n/lang';

interface Strings {
  nav: { home: string; discover: string; chat: string; clubs: string; profile: string };
  chips: { news: string; announcements: string; events: string; saved: string };
  chatChips: { all: string; people: string; clubs: string; events: string };
  hello: string;
  who: string;
  searchAll: string;
  nextEvent: string;
  career: string;
  hall: string;
  joinBtn: string;
  quick: { chat: string; clubs: string; events: string; menu: string; support: string };
  mealToday: string;
  mealShort: string;
  newMessages: string;
  clubMemberships: string;
  myClubs: string;
  all: string;
  photoClub: string;
  softwareClub: string;
  chessClub: string;
  theatre: string;
  mountaineering: string;
  music: string;
  news: string;
  announcement: string;
  headline: string;
  announce1: string;
  news2: string;
  chatTitle: string;
  chatSearch: string;
  clubTag: string;
  eventTag: string;
  msg1: string;
  msg2: string;
  msg3: string;
  msg4: string;
  libraryGroup: string;
  msg5: string;
  yesterday: string;
  eventsTitle: string;
  attendance: string;
  going: string;
  attendCode: string;
  photoWalk: string;
  chessTournament: string;
  campusGate: string;
  studentCenter: string;
  interested: string;
  menuTitle: string;
  today: string;
  soup1: string;
  main1: string;
  rice1: string;
  side1: string;
  soup2: string;
  main2: string;
  side2: string;
  soup3: string;
  main3: string;
  rice3: string;
  clubsTitle: string;
  cats: { all: string; arts: string; tech: string; sport: string };
  join: string;
  supportTitle: string;
  ticket1: string;
  ticket2: string;
  ticket3: string;
  open: string;
  waiting: string;
  done: string;
  newTicket: string;
  notifTitle: string;
  notif: [string, string, string, string, string];
  langTitle: string;
  privacyTitle: string;
  showEmail: string;
  showOnline: string;
  downloadData: string;
  deleteAccount: string;
  members: (n: string) => string;
  goingCount: (n: string) => string;
  goingShort: (n: string) => string;
  newPosts: (n: string) => string;
}

const TR: Strings = {
  nav: { home: 'Ana Sayfa', discover: 'Keşfet', chat: 'Sohbet', clubs: 'Kulüpler', profile: 'Profil' },
  chips: { news: 'Haberler', announcements: 'Duyurular', events: 'Etkinlikler', saved: 'Kaydedilenler' },
  chatChips: { all: 'Tümü', people: 'Kişiler', clubs: 'Kulüpler', events: 'Etkinlikler' },
  hello: 'Günaydın',
  who: 'Bingöl Üniversitesi',
  searchAll: 'Haber, kulüp, etkinlik ara',
  nextEvent: 'Sıradaki etkinlik',
  career: 'Kariyer Günleri',
  hall: 'Konferans Salonu',
  joinBtn: 'Katılıyorum',
  quick: { chat: 'Sohbet', clubs: 'Kulüpler', events: 'Etkinlik', menu: 'Yemek', support: 'Destek' },
  mealToday: 'Bugünün yemeği',
  mealShort: 'Mercimek çorbası\nTavuk sote\nPilav · Cacık',
  newMessages: 'yeni mesaj',
  clubMemberships: 'kulüp üyeliği',
  myClubs: 'Kulüplerimden',
  all: 'Tümü',
  photoClub: 'Fotoğraf Kulübü',
  softwareClub: 'Yazılım Kulübü',
  chessClub: 'Satranç Kulübü',
  theatre: 'Tiyatro Topluluğu',
  mountaineering: 'Dağcılık Kulübü',
  music: 'Müzik Topluluğu',
  news: 'Haber',
  announcement: 'Duyuru',
  headline: 'Üniversitemiz yeni akademik yıla hazır',
  announce1: 'Güz dönemi ara sınav programı yayımlandı',
  news2: 'Kütüphane çalışma saatleri güncellendi',
  chatTitle: 'Sohbet',
  chatSearch: 'Kişi veya grup ara',
  clubTag: 'Kulüp',
  eventTag: 'Etkinlik',
  msg1: 'Toplantı saati değişti',
  msg2: 'Salon değişti mi?',
  msg3: 'Hafta sonu yürüyüşü için kayıtlar açıldı',
  msg4: 'Turnuva eşleşmeleri paylaşıldı',
  libraryGroup: 'Kütüphane Çalışma Grubu',
  msg5: 'Sınav haftası için masa ayırdım',
  yesterday: 'Dün',
  eventsTitle: 'Etkinlikler',
  attendance: 'Yoklama',
  going: 'Katılıyorsun',
  attendCode: 'Yoklama kodu',
  photoWalk: 'Fotoğraf Yürüyüşü',
  chessTournament: 'Satranç Turnuvası',
  campusGate: 'Kampüs girişi',
  studentCenter: 'Öğrenci Merkezi',
  interested: 'İlgileniyorum',
  menuTitle: 'Yemek listesi',
  today: 'BUGÜN',
  soup1: 'Mercimek çorbası',
  main1: 'Tavuk sote',
  rice1: 'Pirinç pilavı',
  side1: 'Cacık',
  soup2: 'Domates çorbası',
  main2: 'Kıymalı makarna',
  side2: 'Ayran',
  soup3: 'Ezogelin çorbası',
  main3: 'Etli nohut',
  rice3: 'Bulgur pilavı',
  clubsTitle: 'Kulüpler',
  cats: { all: 'Tümü', arts: 'Sanat', tech: 'Teknoloji', sport: 'Spor' },
  join: 'Katıl',
  supportTitle: 'Destek',
  ticket1: 'Giriş yapamıyorum',
  ticket2: 'Yemek listesi güncel değil',
  ticket3: 'Profil fotoğrafı hatası',
  open: 'Açık',
  waiting: 'Yanıt bekliyor',
  done: 'Çözüldü',
  newTicket: 'Yeni talep',
  notifTitle: 'Bildirimler',
  notif: ['Haber ve duyurular', 'Etkinlik hatırlatmaları', 'Sohbet mesajları', 'Kulüp gönderileri', 'Yemek listesi'],
  langTitle: 'Dil',
  privacyTitle: 'Gizlilik',
  showEmail: 'E-posta adresimi göster',
  showOnline: 'Çevrimiçi durumumu göster',
  downloadData: 'Verilerimi indir',
  deleteAccount: 'Hesabımı sil',
  members: (n) => `${n} üye`,
  goingCount: (n) => `${n} kişi katılıyor`,
  goingShort: (n) => `${n} katılıyor`,
  newPosts: (n) => `${n} yeni gönderi`,
};

const EN: Strings = {
  nav: { home: 'Home', discover: 'Discover', chat: 'Chat', clubs: 'Clubs', profile: 'Profile' },
  chips: { news: 'News', announcements: 'Announcements', events: 'Events', saved: 'Saved' },
  chatChips: { all: 'All', people: 'People', clubs: 'Clubs', events: 'Events' },
  hello: 'Good morning',
  who: 'Bingöl University',
  searchAll: 'Search news, clubs, events',
  nextEvent: 'Next event',
  career: 'Career Days',
  hall: 'Conference Hall',
  joinBtn: 'I’m going',
  quick: { chat: 'Chat', clubs: 'Clubs', events: 'Events', menu: 'Menu', support: 'Support' },
  mealToday: 'Today’s menu',
  mealShort: 'Lentil soup\nChicken sauté\nRice · Tzatziki',
  newMessages: 'new messages',
  clubMemberships: 'club memberships',
  myClubs: 'From my clubs',
  all: 'All',
  photoClub: 'Photography Club',
  softwareClub: 'Software Club',
  chessClub: 'Chess Club',
  theatre: 'Theatre Society',
  mountaineering: 'Mountaineering Club',
  music: 'Music Society',
  news: 'News',
  announcement: 'Notice',
  headline: 'Our university is ready for the new academic year',
  announce1: 'Fall midterm exam schedule published',
  news2: 'Library opening hours updated',
  chatTitle: 'Chat',
  chatSearch: 'Search people or groups',
  clubTag: 'Club',
  eventTag: 'Event',
  msg1: 'The meeting time has changed',
  msg2: 'Has the hall changed?',
  msg3: 'Sign-ups for the weekend walk are open',
  msg4: 'Tournament pairings are posted',
  libraryGroup: 'Library Study Group',
  msg5: 'I saved a table for exam week',
  yesterday: 'Yesterday',
  eventsTitle: 'Events',
  attendance: 'Check-in',
  going: 'You’re going',
  attendCode: 'Check-in code',
  photoWalk: 'Photo Walk',
  chessTournament: 'Chess Tournament',
  campusGate: 'Campus entrance',
  studentCenter: 'Student Center',
  interested: 'Interested',
  menuTitle: 'Dining menu',
  today: 'TODAY',
  soup1: 'Lentil soup',
  main1: 'Chicken sauté',
  rice1: 'Rice pilaf',
  side1: 'Tzatziki',
  soup2: 'Tomato soup',
  main2: 'Pasta with minced meat',
  side2: 'Ayran',
  soup3: 'Ezogelin soup',
  main3: 'Chickpeas with beef',
  rice3: 'Bulgur pilaf',
  clubsTitle: 'Clubs',
  cats: { all: 'All', arts: 'Arts', tech: 'Technology', sport: 'Sports' },
  join: 'Join',
  supportTitle: 'Support',
  ticket1: 'I can’t sign in',
  ticket2: 'Dining menu is out of date',
  ticket3: 'Profile photo error',
  open: 'Open',
  waiting: 'Awaiting reply',
  done: 'Resolved',
  newTicket: 'New request',
  notifTitle: 'Notifications',
  notif: ['News and announcements', 'Event reminders', 'Chat messages', 'Club posts', 'Dining menu'],
  langTitle: 'Language',
  privacyTitle: 'Privacy',
  showEmail: 'Show my email address',
  showOnline: 'Show my online status',
  downloadData: 'Download my data',
  deleteAccount: 'Delete my account',
  members: (n) => `${n} members`,
  goingCount: (n) => `${n} people going`,
  goingShort: (n) => `${n} going`,
  newPosts: (n) => `${n} new posts`,
};

const AR: Strings = {
  nav: { home: 'الرئيسية', discover: 'استكشاف', chat: 'الدردشة', clubs: 'النوادي', profile: 'الملف' },
  chips: { news: 'الأخبار', announcements: 'الإعلانات', events: 'الفعاليات', saved: 'المحفوظات' },
  chatChips: { all: 'الكل', people: 'الأشخاص', clubs: 'النوادي', events: 'الفعاليات' },
  hello: 'صباح الخير',
  who: 'جامعة بينغول',
  searchAll: 'ابحث عن خبر أو نادٍ أو فعالية',
  nextEvent: 'الفعالية القادمة',
  career: 'أيام المهنة',
  hall: 'قاعة المؤتمرات',
  joinBtn: 'سأحضر',
  quick: { chat: 'الدردشة', clubs: 'النوادي', events: 'الفعاليات', menu: 'الطعام', support: 'الدعم' },
  mealToday: 'وجبة اليوم',
  mealShort: 'شوربة العدس\nدجاج سوتيه\nأرز · جاجيك',
  newMessages: 'رسائل جديدة',
  clubMemberships: 'عضويات في النوادي',
  myClubs: 'من نواديّ',
  all: 'الكل',
  photoClub: 'نادي التصوير',
  softwareClub: 'نادي البرمجيات',
  chessClub: 'نادي الشطرنج',
  theatre: 'جماعة المسرح',
  mountaineering: 'نادي تسلق الجبال',
  music: 'جماعة الموسيقى',
  news: 'خبر',
  announcement: 'إعلان',
  headline: 'جامعتنا جاهزة للعام الدراسي الجديد',
  announce1: 'نُشر جدول امتحانات منتصف الفصل الخريفي',
  news2: 'تحديث ساعات عمل المكتبة',
  chatTitle: 'الدردشة',
  chatSearch: 'ابحث عن شخص أو مجموعة',
  clubTag: 'نادٍ',
  eventTag: 'فعالية',
  msg1: 'تغيّر موعد الاجتماع',
  msg2: 'هل تغيّرت القاعة؟',
  msg3: 'فُتح التسجيل في نزهة نهاية الأسبوع',
  msg4: 'نُشرت مواجهات البطولة',
  libraryGroup: 'مجموعة الدراسة في المكتبة',
  msg5: 'حجزتُ طاولة لأسبوع الامتحانات',
  yesterday: 'أمس',
  eventsTitle: 'الفعاليات',
  attendance: 'تسجيل الحضور',
  going: 'ستحضر',
  attendCode: 'رمز الحضور',
  photoWalk: 'جولة تصوير',
  chessTournament: 'بطولة الشطرنج',
  campusGate: 'مدخل الحرم الجامعي',
  studentCenter: 'مركز الطلاب',
  interested: 'مهتم',
  menuTitle: 'قائمة الطعام',
  today: 'اليوم',
  soup1: 'شوربة العدس',
  main1: 'دجاج سوتيه',
  rice1: 'أرز بيلاف',
  side1: 'جاجيك',
  soup2: 'شوربة الطماطم',
  main2: 'معكرونة باللحم المفروم',
  side2: 'عيران',
  soup3: 'شوربة إزوغلين',
  main3: 'حمّص باللحم',
  rice3: 'برغل',
  clubsTitle: 'النوادي',
  cats: { all: 'الكل', arts: 'الفنون', tech: 'التقنية', sport: 'الرياضة' },
  join: 'انضم',
  supportTitle: 'الدعم',
  ticket1: 'لا أستطيع تسجيل الدخول',
  ticket2: 'قائمة الطعام غير محدّثة',
  ticket3: 'خطأ في صورة الملف الشخصي',
  open: 'مفتوح',
  waiting: 'بانتظار الرد',
  done: 'تم الحل',
  newTicket: 'طلب جديد',
  notifTitle: 'الإشعارات',
  notif: ['الأخبار والإعلانات', 'تذكيرات الفعاليات', 'رسائل الدردشة', 'منشورات النوادي', 'قائمة الطعام'],
  langTitle: 'اللغة',
  privacyTitle: 'الخصوصية',
  showEmail: 'إظهار بريدي الإلكتروني',
  showOnline: 'إظهار حالة اتصالي',
  downloadData: 'تنزيل بياناتي',
  deleteAccount: 'حذف حسابي',
  members: (n) => `${n} عضوًا`,
  goingCount: (n) => `${n} أشخاص سيحضرون`,
  goingShort: (n) => `${n} سيحضرون`,
  newPosts: (n) => `${n} منشورات جديدة`,
};

const DICT: Record<Lang, Strings> = { tr: TR, en: EN, ar: AR };

export interface ScreenKit {
  s: Strings;
  lang: Lang;
  num: (n: number) => string;
  upper: (s: string) => string;
  /** Ekim 2026 içindeki gün için biçimli tarih. */
  date: (day: number, opts: Intl.DateTimeFormatOptions) => string;
  /** 24 saat biçimli saat (örn. 14:00). */
  time: (h: number, m?: number) => string;
}

/** Çizimler için dile göre metin ve tarih/sayı biçimleyicileri. */
export function useScreenKit(): ScreenKit {
  const { lang, locale } = useI18n();
  return useMemo(() => {
    const numFmt = new Intl.NumberFormat(locale);
    return {
      s: DICT[lang],
      lang,
      num: (n) => numFmt.format(n),
      upper: (v) => (lang === 'ar' ? v : v.toLocaleUpperCase(locale)),
      date: (day, opts) => new Intl.DateTimeFormat(locale, opts).format(new Date(2026, 9, day)),
      time: (h, m = 0) =>
        new Intl.DateTimeFormat(locale, { hour: '2-digit', minute: '2-digit', hour12: false }).format(
          new Date(2026, 9, 28, h, m),
        ),
    };
  }, [lang, locale]);
}

/**
 * COMM: Topluluk / Akademik / İçerik grubu için backendsiz /api taklidi (görsel doğrulama).
 * Senaryo: full | empty | error. mockPanel.stubPanel ÖNCE kurulur; bu yönlendirici sonradan eklenir
 * (Playwright son eklenen yönlendiriciyi önce dener). Tanımadığı yol `unmatched` listesine yazılır ve 404 döner.
 */
import type { Page, Route } from '@playwright/test';

export type Scenario = 'full' | 'empty' | 'error';

const json = (r: Route, body: unknown, status = 200) =>
  r.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });
const DAY = 86_400_000;
const iso = (backDays: number) => new Date(Date.now() - backDays * DAY).toISOString();
const ymd = (offsetDays: number) => new Date(Date.now() + offsetDays * DAY).toISOString().slice(0, 10);
const pageOf = <T>(items: T[]) => ({ items, page: 0, size: 20, total: items.length, totalPages: 1, totalItems: items.length });
const cursorOf = <T>(items: T[]) => ({ items, nextCursor: null });
const LONG_MAIL = 'mehmet.kaya.cok.uzun.bir.eposta.adresi.ogrenci@onlisans.bingol.edu.tr';
const LONG_NAME = 'Mehmet Kaya Çok Uzun Bir Soyisim Taşıyan Öğrenci';
const LONG_CLUB = 'Bingöl Üniversitesi Yapay Zekâ ve Veri Bilimi Öğrenci Topluluğu Çok Uzun Ad';

const CATS = [
  { key: 'academic', nameTr: 'Akademik' },
  { key: 'sports', nameTr: 'Spor' },
  { key: 'arts', nameTr: 'Sanat' },
  { key: 'tech', nameTr: 'Teknoloji' },
];

const category = (id: number) => ({
  id,
  key: CATS[(id - 1) % 4].key,
  nameTr: CATS[(id - 1) % 4].nameTr + (id > 4 ? ` ${id}` : ''),
  nameEn: 'Category ' + id,
  nameAr: id % 2 ? 'فئة' : '',
  icon: ['school', 'sports_soccer', 'palette', 'memory'][(id - 1) % 4],
  sortOrder: id * 10,
  active: id !== 5,
  usageCount: id === 5 ? 0 : 10 - id,
  createdAt: iso(60),
  updatedAt: iso(id),
});

const club = (id: number) => ({
  id,
  name: id === 2 ? LONG_CLUB : ['Satranç Kulübü', 'Fotoğraf Kulübü', 'Girişimcilik Topluluğu', 'Tiyatro Kulübü', 'Dağcılık Kulübü', 'Yazılım Kulübü', 'Müzik Kulübü', 'Sinema Kulübü'][id % 8],
  slug: `kulup-${id}`,
  category: CATS[id % 4].key,
  status: (['ACTIVE', 'ACTIVE', 'PENDING_REVIEW', 'HIDDEN', 'REJECTED', 'ACTIVE'] as const)[id % 6],
  visibility: id % 5 === 0 ? 'PRIVATE' : 'PUBLIC',
  joinPolicy: id % 2 ? 'APPROVAL' : 'OPEN',
  ownerId: 40 + id,
  ownerName: id === 2 ? LONG_NAME : `Kulüp Başkanı ${id}`,
  ownerEmail: id === 2 ? LONG_MAIL : `baskan${id}@bingol.edu.tr`,
  coverUrl: null,
  logoUrl: null,
  memberCount: 5 + id * 13,
  pendingCount: id % 3 === 0 ? 4 : 0,
  openReportCount: id % 4 === 0 ? 2 : 0,
  eventCount: id % 5,
  createdAt: iso(id * 9),
  updatedAt: iso(id),
});

const member = (id: number, over: Record<string, unknown> = {}) => ({
  userId: 100 + id,
  displayName: id === 2 ? LONG_NAME : `Üye Kişi ${id}`,
  email: id === 2 ? LONG_MAIL : `uye${id}@bingol.edu.tr`,
  avatarUrl: null,
  role: id === 1 ? 'OWNER' : id === 2 ? 'ADMIN' : id === 3 ? 'MODERATOR' : 'MEMBER',
  status: id === 7 ? 'BANNED' : 'ACTIVE',
  accountStatus: 'ACTIVE',
  joinedAt: iso(id * 3),
  customPermissions: id === 3,
  ...over,
});

const audit = (id: number) => ({
  id,
  action: ['MEMBER_JOINED', 'MEMBER_REMOVED', 'PERMISSIONS_CHANGED', 'OWNERSHIP_TRANSFERRED', 'INVITE_CREATED', 'MEMBER_BANNED'][id % 6],
  actorId: 1,
  actorName: id === 2 ? LONG_NAME : 'Yönetici Kişi',
  targetUserId: 100 + id,
  targetName: `Üye Kişi ${id}`,
  detail: id === 3 ? 'Etkinlik oluşturma izni verildi: bu açıklama biraz uzun tutuldu ki satır sığmazsa taşma görünsün' : null,
  at: iso(id / 2),
  createdAt: iso(id / 2),
});

const content = (id: number) => ({
  id,
  communityId: 1 + (id % 3),
  communityName: id === 2 ? LONG_CLUB : ['Satranç Kulübü', 'Fotoğraf Kulübü', 'Girişimcilik Topluluğu'][id % 3],
  kind: id % 3 === 0 ? 'ANNOUNCEMENT' : 'POST',
  state: id === 4 ? 'HIDDEN' : id === 6 ? 'DELETED' : 'VISIBLE',
  author: { id: 50 + id, displayName: id === 2 ? LONG_NAME : `Yazar ${id}`, email: id === 2 ? LONG_MAIL : `yazar${id}@bingol.edu.tr`, avatarUrl: null },
  text: id === 2 ? 'Bu çok uzun bir gönderi metnidir '.repeat(8) : `Bu hafta cuma günü toplantımız var, herkesi bekleriz (${id}).`,
  imageUrl: null,
  pinned: id === 1,
  openReportCount: id === 2 ? 3 : 0,
  hiddenReason: id === 4 ? 'Reklam içeriyor' : null,
  hiddenBy: id === 4 ? 1 : null,
  hiddenAt: id === 4 ? iso(1) : null,
  editedAt: null,
  createdAt: iso(id),
});

const event = (id: number) => ({
  id,
  title: id === 2 ? 'Yapay Zekâ ve Gelecek Çalıştayı: Çok Uzun Bir Etkinlik Başlığı Taşma Denemesi İçin' : `Bahar Şenliği ${id}`,
  description: 'Etkinlik açıklaması',
  startsAt: new Date(Date.now() + (id - 3) * DAY).toISOString(),
  endsAt: new Date(Date.now() + (id - 3) * DAY + 7_200_000).toISOString(),
  location: id === 2 ? 'Mühendislik Fakültesi Konferans Salonu Zemin Kat' : 'Merkez Kampüs',
  coverUrl: null,
  capacity: id % 2 ? 100 : null,
  goingCount: 12 * id,
  interestedCount: 3 * id,
  communityId: id % 3 === 0 ? null : 1 + (id % 3),
  communityName: id % 3 === 0 ? null : ['Satranç Kulübü', 'Fotoğraf Kulübü', 'Girişimcilik Topluluğu'][id % 3],
  createdBy: 40 + id,
  organizerName: `Düzenleyen ${id}`,
  status: (['ACTIVE', 'PENDING_REVIEW', 'CANCELLED', 'HIDDEN', 'ACTIVE', 'REJECTED'] as const)[id % 6],
  createdAt: iso(id),
  joinPolicy: id % 2 ? 'APPROVAL' : 'OPEN',
  pendingCount: id % 2 ? id : 0,
  organizer: null,
});

const calEvent = (id: number) => ({
  id,
  kind: ['DONEM_BASLANGIC', 'DERS_KAYIT', 'VIZE', 'FINAL', 'BUT', 'TATIL', 'RESMI_TATIL', 'DIGER'][id % 8],
  title: id === 2 ? 'Güz Dönemi Ara Sınav Haftası ve Ders Kayıt Yenileme Süreci Başlangıcı Çok Uzun' : `Akademik olay ${id}`,
  startsAt: ymd(id * 2 - 8) + 'T00:00:00',
  endsAt: id % 2 ? ymd(id * 2 - 6) + 'T00:00:00' : null,
  allDay: true,
  scopeDepartment: id % 4 === 0 ? 'Bilgisayar Programcılığı' : null,
  note: id % 3 === 0 ? 'Not' : null,
  published: id % 3 !== 0,
});

const exam = (id: number) => ({
  id,
  title: id === 2 ? 'Olasılık ve İstatistik Ara Sınavı: Mühendislik Fakültesi Tüm Bölümler Çok Uzun' : `Matematik ${id} Ara Sınavı`,
  type: ['VIZE', 'FINAL', 'BUT', 'QUIZ', 'ODEV', 'DIGER'][id % 6],
  term: '2026-2027 Güz',
  courseCode: `MAT${100 + id}`,
  faculty: 'Mühendislik Fakültesi',
  department: id % 2 ? 'Bilgisayar Mühendisliği' : null,
  grade: (['1', '2', '3', '4', 'PREP'] as const)[id % 5],
  startsAt: new Date(Date.now() + (id - 3) * DAY).toISOString(),
  endsAt: new Date(Date.now() + (id - 3) * DAY + 5_400_000).toISOString(),
  room: id === 2 ? 'Amfi-A Blok Zemin Kat Büyük Salon' : `D-${100 + id}`,
  note: null,
  published: id % 3 !== 0,
});

const announcement = (id: number) => ({
  id,
  title: id === 2 ? 'Burs Başvuruları Başladı: Tüm Öğrencilerimizin Dikkatine Sunulur Çok Uzun Başlık' : `Duyuru ${id}`,
  body: 'Duyuru metni burada yer alır.',
  department: id % 2 ? 'Bilgisayar Programcılığı' : null,
  faculty: null,
  grade: id % 3 === 0 ? '2' : null,
  pinned: id === 1,
  publishAt: id === 3 ? new Date(Date.now() + 2 * DAY).toISOString() : null,
  expiresAt: id === 4 ? iso(1) : null,
  attachmentUrl: null,
  published: id !== 5,
  notify: id % 2 === 0,
  notifiedAt: id % 2 === 0 ? iso(1) : null,
  createdBy: 1,
  readCount: 40 * id,
  createdAt: iso(id),
});

const news = (id: number) => ({
  id,
  type: (['HABER', 'DUYURU', 'ETKINLIK'] as const)[id % 3],
  title: id === 2 ? 'Üniversitemizde Düzenlenen Uluslararası Bilimsel Araştırmalar Sempozyumu Büyük İlgi Gördü ve Çok Uzun' : `Haber başlığı ${id}`,
  summary: 'Haber özeti',
  imageUrl: null,
  publishedDate: ymd(-id),
  url: `https://www.bingol.edu.tr/haber/${id}`,
  hidden: id === 4,
});

const faq = (id: number) => ({
  id,
  lang: 'tr',
  category: ['Hesap', 'Mesajlaşma', 'Etkinlikler'][id % 3],
  question: id === 2 ? 'Şifremi unuttum ve doğrulama e-postası da gelmiyor, ne yapmalıyım? Çok uzun bir soru örneği' : `Soru ${id}?`,
  answer: 'Cevap metni.',
  sortOrder: id,
  published: id !== 3,
});

const LEGAL = ['TERMS', 'PRIVACY', 'KVKK', 'COMMUNITY_RULES', 'EXPLICIT_CONSENT', 'COOKIES', 'CONTENT_REMOVAL', 'RETENTION'];

const menuDay = (i: number) => ({
  date: ymd(i),
  items: ['Mercimek çorbası', 'Etli nohut', 'Pirinç pilavı', 'Cacık', i === 1 ? 'Çok uzun adlı bir yemek: fırında sebzeli tavuk but' : 'Kemalpaşa tatlısı'],
  imageUrl: null,
  dishes: [
    { name: 'Mercimek çorbası', kcal: 180 },
    { name: 'Etli nohut', kcal: 420 },
    { name: 'Pirinç pilavı', kcal: i === 2 ? null : 300 },
    { name: 'Cacık', kcal: 90 },
    { name: i === 1 ? 'Çok uzun adlı bir yemek: fırında sebzeli tavuk but' : 'Kemalpaşa tatlısı', kcal: 250 },
  ],
  totalKcal: i === 2 ? 940 : 1240,
  kcalComplete: i !== 2,
});

const range = (n: number, f: (i: number) => unknown) => Array.from({ length: n }, (_, i) => f(i + 1));

export async function stubCommunity(page: Page, scenario: Scenario = 'full', unmatched: string[] = []) {
  const empty = scenario === 'empty';
  const error = scenario === 'error';
  await page.route(
    (u) => u.pathname.startsWith('/api/'),
    (r) => {
      const u = new URL(r.request().url());
      const m = r.request().method();
      const p = u.pathname.replace(/^\/api/, '');
      const some = <T>(n: number, f: (i: number) => T): T[] => (empty ? [] : (range(n, f) as T[]));
      const dataPaths = /^\/(admin\/(news|communities|community-categories|community-posts|events|academic|announcements|legal|faq|menu)|events\/\d+\/applications|communities\/\d+\/audit|legal|status)/;
      if (error && dataPaths.test(p)) return json(r, { code: 'INTERNAL', message: 'Sunucu hatası' }, 500);
      if (m !== 'GET') return json(r, {}, 200);
      if (/^\/admin\/(me$|rbac\/)/.test(p)) return r.fallback();

      // kabuk (üst bant): bakım yok, depolama sağlıklı
      if (p === '/app/info') return json(r, { maintenance: { enabled: false, message: null }, banner: null });
      if (p === '/admin/system/storage') return json(r, { status: 'OK', worstPercent: 40, warnPercent: 80, critPercent: 90, items: [] });

      // Haberler
      if (p === '/admin/news') return json(r, pageOf(some(14, news)));
      if (p === '/status')
        return json(r, { NEWS: { maintenance: false, lastSuccessAt: iso(0.4), lastAttemptAt: iso(0.4) }, MENU: { maintenance: true, lastSuccessAt: iso(5), lastAttemptAt: iso(0.1), message: 'Kaynak site yanıt vermiyor' } });

      // Kulüpler
      if (p === '/admin/community-categories') {
        const items = some(6, category);
        return json(r, { items, activeCount: items.filter((c) => c.active).length, maxActive: 12 });
      }
      let mt = p.match(/^\/admin\/communities\/(\d+)$/);
      if (mt) {
        const c = club(Number(mt[1]));
        return json(r, {
          club: c,
          description: 'Kulüp açıklaması: öğrencilerin bir araya geldiği topluluk.',
          reviewNote: null,
          staff: [
            { userId: 101, displayName: 'Üye Kişi 1', email: 'uye1@bingol.edu.tr', role: 'OWNER' },
            { userId: 102, displayName: LONG_NAME, email: LONG_MAIL, role: 'ADMIN' },
          ],
          bannedCount: 1,
          statusHistory: range(2, audit),
          openReports: c.openReportCount ? [{ id: 1, reason: 'SPAM', note: 'Reklam yapılıyor', status: 'OPEN', createdAt: iso(1) }] : [],
          recentAudit: range(3, audit),
          capabilities: { canEdit: true, canClose: true, canReopen: true, canDelete: true, canTransfer: true, canApprove: true },
        });
      }
      mt = p.match(/^\/admin\/communities\/(\d+)\/(members|join-requests)$/);
      if (mt) return json(r, pageOf(some(8, (i) => member(i, mt![2] === 'join-requests' ? { status: 'PENDING', role: 'MEMBER' } : {}))));
      if (/^\/admin\/communities\/\d+\/invites$/.test(p))
        return json(r, some(2, (i) => ({ id: i, codeHint: 'AB' + i + '***', createdBy: 1, maxUses: 10, usedCount: i, expiresAt: ymd(7), revoked: i === 2, state: i === 2 ? 'REVOKED' : 'ACTIVE' })));
      if (/^\/admin\/communities\/\d+\/club-audit$/.test(p)) return json(r, cursorOf(some(6, audit)));
      if (p === '/admin/communities') return json(r, pageOf(some(12, club)));
      if (/^\/communities\/\d+\/audit$/.test(p)) return json(r, cursorOf(some(10, audit)));
      mt = p.match(/^\/admin\/community-posts\/(\d+)$/);
      if (mt) return json(r, { post: content(Number(mt[1])), reports: [] });
      if (p === '/admin/community-posts') return json(r, pageOf(some(8, content)));

      // Etkinlikler
      mt = p.match(/^\/admin\/events\/(\d+)$/);
      if (mt)
        return json(r, {
          event: event(Number(mt[1])),
          organizerEmail: LONG_MAIL,
          requests: { pending: 3, waitlisted: 1, accepted: 12, rejected: 2, cancelled: 1 },
          attendedCount: 9,
          reviewNote: null,
          moderationReason: null,
          moderatedBy: null,
          moderatedAt: null,
          history: [],
          allowedActions: ['approve', 'reject', 'edit', 'hide', 'cancel', 'delete'],
        });
      mt = p.match(/^\/admin\/events\/(\d+)\/(applications|attendance|certificates|feedback|announcements|organizers)$/);
      if (mt) {
        const kind = mt[2];
        const summary = { mode: 'APPROVAL', capacity: 40, goingCount: 12, seatsLeft: 28, pending: 3, accepted: 12, waitlisted: 1, rejected: 2, cancelled: 1 };
        if (kind === 'applications')
          return json(r, { items: some(6, (i) => ({ id: i, userId: 100 + i, displayName: i === 2 ? LONG_NAME : `Başvuran ${i}`, emailMasked: 'a***@bingol.edu.tr', department: 'Bilgisayar Programcılığı', status: ['PENDING', 'ACCEPTED', 'WAITLISTED', 'REJECTED', 'CANCELLED', 'PENDING'][i - 1], note: null, answers: [], queuedAt: null, decidedBy: null, decidedAt: null, decisionNote: null, createdAt: iso(i), updatedAt: iso(i) })), nextCursor: null, summary });
        if (kind === 'attendance')
          return json(r, { rows: some(5, (i) => ({ userId: 100 + i, displayName: `Katılımcı ${i}`, emailMasked: 'k***@bingol.edu.tr', department: null, rsvp: i === 5 ? 'WALK_IN' : 'GOING', present: i % 3 === 0 ? null : i % 2 === 0, method: i % 2 ? 'QR' : 'MANUAL', markedBy: 1, markedByName: 'Yönetici', markedAt: iso(0.1), hasCertificate: i === 1, certificateRevoked: false })), summary: { going: 5, present: 2, absent: 1, unmarked: 2, walkIns: 1 }, truncated: false });
        if (kind === 'feedback')
          return json(r, { items: some(3, (i) => ({ id: i, rating: 6 - i, comment: 'Güzel bir etkinlikti', createdAt: iso(i) })), nextCursor: null, summary: { total: 3, average: 4, distribution: [0, 0, 1, 1, 1] } });
        return json(r, cursorOf([]));
      }
      if (p === '/admin/events') return json(r, cursorOf(some(10, event)));
      mt = p.match(/^\/events\/(\d+)\/applications\/summary$/);
      if (mt) return json(r, { eventId: Number(mt[1]), mode: 'APPROVAL', capacity: 40, goingCount: 12, pending: 3, accepted: 12, waitlisted: 1, rejected: 2, cancelled: 1 });

      // Akademik
      if (p === '/admin/academic/events') return json(r, pageOf(some(12, calEvent)));
      if (p === '/admin/academic/exams') return json(r, pageOf(some(9, exam)));
      if (p === '/admin/announcements/audience-count') return json(r, { count: 1234 });
      if (p === '/admin/announcements') return json(r, pageOf(some(7, announcement)));

      // Sözleşmeler / SSS / Menü
      if (p === '/legal') return json(r, empty ? [] : LEGAL.map((type, i) => ({ type, version: 2 + (i % 3), title: type, lang: 'tr', publishedAt: iso(10 + i) })));
      if (p === '/admin/legal/acceptance-stats') return json(r, LEGAL.map((type, i) => ({ type, version: 2 + (i % 3), accepted: empty ? 0 : 800 - i * 90, totalActiveUsers: 1000 })));
      mt = p.match(/^\/admin\/legal\/([A-Z_]+)\/versions$/);
      if (mt) return json(r, empty ? [] : [3, 2, 1].flatMap((v) => ['tr', 'en'].map((lang) => ({ version: v, lang, title: 'Kullanım Koşulları', content: '# Başlık\n\nMetin ' + v, requireReaccept: v === 3, active: v === 3, publishedAt: iso(v * 30) }))));
      if (p === '/admin/faq') return json(r, some(8, faq));
      if (p === '/admin/menu') return json(r, empty ? [] : range(10, (i) => menuDay(i - 3)));

      // mockPanel'in (me/rbac/...) tanıdığı yollar ona devredilir; gerçekten tanınmayanlar kayda geçer.
      if (!/^\/admin\/(me$|rbac\/)/.test(p)) unmatched.push(`${m} ${p}`);
      return r.fallback();
    },
  );
}

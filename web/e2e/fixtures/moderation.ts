/**
 * MOD: Moderasyon + Destek grubu için backendsiz /api taklidi (görsel doğrulama). Senaryo: full | empty | error.
 * mockPanel.stubPanel (rbac/me vb.) ÖNCE kurulur; bu yönlendirici sonradan eklenir ve tanımadığı yolu `fallback()` ile devreder.
 */
import type { Page, Route } from '@playwright/test';

export type Scenario = 'full' | 'empty' | 'error';

const json = (r: Route, body: unknown, status = 200) =>
  r.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });
const iso = (backDays: number) => new Date(Date.now() - backDays * 86_400_000).toISOString();
const pageOf = <T>(items: T[]) => ({ items, page: 0, size: 20, total: items.length, totalPages: 1 });
const LONG_MAIL = 'mehmet.kaya.cok.uzun.bir.eposta.adresi.ogrenci@onlisans.bingol.edu.tr';
const LONG_NAME = 'Mehmet Kaya Çok Uzun Bir Soyisim Taşıyan Öğrenci';

const person = (id: number, name: string, email = `ogr${id}@bingol.edu.tr`) => ({ id, displayName: name, email, avatarUrl: null });

const post = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  author: id === 3 ? person(7, LONG_NAME, LONG_MAIL) : person(5, 'Ayşe Yılmaz'),
  text: id === 3 ? 'Kampüste bugün hava çok güzel' : `Bahar şenliği fotoğrafı ${id}`,
  media: [],
  likeCount: 120 + id,
  mediaCount: 0,
  hidden: id === 2,
  deleted: false,
  hiddenReason: id === 2 ? 'Reklam içeriyor' : null,
  createdAt: iso(id),
  editedAt: id === 4 ? iso(0.5) : null,
  hiddenAt: id === 2 ? iso(0.2) : null,
  deletedAt: null,
  deletedBy: null,
  openReportCount: id === 3 ? 2 : 0,
  ...over,
});

const strike = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  userId: 40 + id,
  userName: id === 2 ? LONG_NAME : `Ayşe Yılmaz ${id}`,
  userEmail: id === 2 ? LONG_MAIL : `a${id}@bingol.edu.tr`,
  reportId: 100 + id,
  targetType: 'POST',
  targetId: 200 + id,
  resolution: id === 1 ? 'SUSPEND_USER' : 'HIDE',
  createdAt: iso(id),
  revokedAt: null,
  active: true,
  forgiven: false,
  forgivenBy: null,
  forgivenReason: null,
  ...over,
});

const hiddenRow = (type: string, id: number, over: Record<string, unknown> = {}) => ({
  targetType: type,
  targetId: id,
  hiddenBy: id % 2 ? 'AUTO' : 'ADMIN',
  hiddenAt: iso(id),
  reversible: true,
  exists: true,
  ownerId: 5,
  ownerName: 'Sahip Kişi',
  preview: { kind: 'TEXT', url: null, thumbnailUrl: null, mime: null, text: `Hemen tıkla kazan: bu bağlantıya tıklayan herkes ödül kazanır ${id}` },
  ...over,
});

const tpl = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  kind: 'DECISION',
  code: ['SPAM_ADS', 'TACIZ', 'UYGUNSUZ'][id % 3],
  textTr: `İçeriğiniz topluluk kurallarına uymadığı için kaldırıldı (${id}). Lütfen kuralları yeniden okuyun ve tekrarlamayın.`,
  textEn: id === 1 ? 'Your content was removed.' : null,
  textAr: null,
  active: id !== 3,
  sortOrder: id * 10,
  updatedAt: iso(id),
  ...over,
});

const ticket = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  subject: id === 2 ? 'Uygulamaya giriş yapamıyorum, şifre sıfırlama e-postası da gelmiyor' : `Yardım talebi ${id}`,
  category: ['ACCOUNT', 'TECHNICAL', 'CONTENT', 'OTHER'][id % 4],
  status: ['OPEN', 'ANSWERED', 'CLOSED'][id % 3],
  userId: 40 + id,
  userEmail: id === 2 ? LONG_MAIL : `ogr${id}@bingol.edu.tr`,
  publicTicket: id === 4,
  priority: id === 1 ? 'URGENT' : 'NORMAL',
  assigneeId: id === 1 ? 1 : null,
  createdAt: iso(id + 1),
  updatedAt: iso(id),
  ...over,
});

const feedback = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  category: ['BUG', 'SUGGESTION', 'COMPLAINT', 'PRAISE'][id % 4],
  subject: `Öneri başlığı ${id}`,
  message: 'Yemek listesinde kalori bilgisi de görünürse çok iyi olur, ayrıca bildirimler çok geç geliyor.',
  status: ['NEW', 'IN_REVIEW', 'PLANNED', 'DONE'][id % 4],
  voteCount: 42 - id * 5,
  publicVisible: id % 2 === 0,
  adminResponse: id === 1 ? 'Teşekkürler, ekibimize ilettik.' : null,
  userId: 40 + id,
  userEmail: id === 2 ? LONG_MAIL : `ogr${id}@bingol.edu.tr`,
  createdAt: iso(id),
  platform: 'android',
  appVersion: '2.0.5',
  ...over,
});

const pollRow = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  title: id === 1 ? 'Yemekhane menüsünü nasıl buluyorsunuz?' : `Kulüp seçimi anketi ${id}`,
  type: 'SINGLE',
  scope: id === 1 ? 'MENU' : 'GLOBAL',
  communityId: null,
  status: 'OPEN',
  state: ['OPEN', 'CLOSED', 'DRAFT', 'CANCELLED', 'OPEN'][id % 5],
  anonymous: id % 2 === 1,
  totalVotes: 120 * id,
  opensAt: iso(10),
  closesAt: iso(-3),
  createdAt: iso(10),
  createdBy: 7,
  ...over,
});

const report = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  reporterId: 5,
  targetType: ['FEED_POST', 'MESSAGE', 'USER', 'COMMUNITY'][id % 4],
  targetId: 300 + id,
  reason: ['SPAM', 'HARASSMENT', 'INAPPROPRIATE', 'OTHER'][id % 4],
  note: id === 1 ? 'Sürekli aynı reklamı gönderiyor ve herkese rahatsızlık veriyor.' : null,
  status: 'OPEN',
  resolution: null,
  createdAt: iso(id),
  priority: [130, 30, 10, 0, 50][id % 5],
  reasonCode: null,
  preview: { kind: 'TEXT', url: null, thumbnailUrl: null, mime: null, text: `Şikâyet edilen metin örneği ${id}` },
  hidden: id % 5 === 0,
  hiddenBy: id % 5 === 0 ? 'AUTO' : null,
  openReporters: [3, 1, 2, 1, 5][id % 5],
  reporter: { id: 5, displayName: 'Ayşe Yılmaz' },
  reportedUser: { id: 9, displayName: LONG_NAME },
  ...over,
});

const chatMsg = (id: number) => ({
  conversation: { id: 30, type: 'GROUP', title: 'Bilgisayar Mühendisliği 3. sınıf proje grubu sohbeti', memberCount: 3 },
  message: {
    id,
    conversationId: 30,
    senderId: 7,
    senderName: LONG_NAME,
    sender: person(7, LONG_NAME, LONG_MAIL),
    mine: false,
    createdAt: iso(id / 10),
    text: `Akış mesajı ${id}`,
    error: null,
    edited: false,
    editedAt: null,
    revisions: [],
    deleted: false,
    deletedAt: null,
    deletedBy: null,
    deletedByName: null,
    hidden: false,
    suppressed: id === 2,
    status: 'SENT',
    replyTo: null,
    reactions: [],
    attachments: [],
  },
});

export async function stubModeration(page: Page, scenario: Scenario = 'full') {
  const empty = scenario === 'empty';
  const fail = scenario === 'error';
  await page.route(
    (u) => u.pathname.startsWith('/api/'),
    (r) => {
      const u = new URL(r.request().url());
      const m = r.request().method();
      const p = u.pathname.replace(/^\/api/, '');
      const err = () => json(r, { code: 'INTERNAL', message: 'Sunucu hatası' }, 500);
      const data = <T>(items: T[]) => (fail ? err() : json(r, pageOf(empty ? [] : items)));
      const cursor = <T>(items: T[]) => (fail ? err() : json(r, { items: empty ? [] : items, nextCursor: null }));
      if (m !== 'GET') return r.fallback();

      // gönderiler
      if (p === '/admin/posts/stats')
        return fail
          ? err()
          : json(r, {
              postCount: empty ? 0 : 98234, likeCount: empty ? 0 : 412000, mediaCount: empty ? 0 : 91000, hiddenCount: empty ? 0 : 41, deletedCount: 7,
              openReportedCount: empty ? 0 : 7,
              last24h: { postCount: empty ? 0 : 64, likeCount: 900, mediaCount: 60, hiddenCount: 1, deletedCount: 0 },
            });
      if (/^\/admin\/posts\/\d+$/.test(p)) return json(r, { post: post(3), reports: [{ id: 9, reason: 'INAPPROPRIATE', note: 'uygunsuz', status: 'OPEN', createdAt: iso(1) }, { id: 10, reason: 'SPAM', note: null, status: 'OPEN', createdAt: iso(1) }] });
      if (p === '/admin/posts') return cursor([post(1), post(2), post(3), post(4)]);

      // sohbet akışı
      if (p === '/admin/chat-media/stats')
        return fail
          ? err()
          : json(r, { imageCount: 18300, videoCount: 1023, viewOnceCount: 412, deletedMessageMediaCount: 880, hiddenCount: 0, suppressedCount: 0, purgedCount: 3100, totalBytes: 8127000000, last24h: { imageCount: 200, videoCount: 24 } });
      if (p === '/admin/chat-messages') return cursor([chatMsg(1), chatMsg(2), chatMsg(3)]);
      if (p === '/admin/chat-media') return cursor([]);

      // ihlaller / gizlenen / şablonlar / yasaklı görseller
      if (p === '/admin/moderation/strikes') return data([strike(1), strike(2), strike(3, { active: false, forgiven: true, forgivenReason: 'Yanlış karar', revokedAt: iso(1) })]);
      if (p === '/admin/moderation/hidden') return data([hiddenRow('POST', 7), hiddenRow('MESSAGE', 8, { reversible: false, preview: null }), hiddenRow('POST', 9)]);
      if (p === '/admin/moderation/reason-templates') return fail ? err() : json(r, { items: empty ? [] : [tpl(1), tpl(2), tpl(3)], max: 50 });
      if (p === '/admin/moderation/blocklist')
        return cursor([
          { sha256: 'a'.repeat(32) + 'b1'.repeat(16), note: 'Şiddet içerikli görsel', createdBy: 1, createdAt: iso(3) },
          { sha256: 'c0'.repeat(32), note: null, createdBy: 1, createdAt: iso(9) },
        ]);

      // anketler
      if (p === '/admin/polls/stats')
        return fail ? err() : json(r, { total: empty ? 0 : 38, open: empty ? 0 : 5, closed: 29, draft: 2, cancelled: 2, totalVotes: 24310, avgTurnoutPercent: 27.4 });
      if (p === '/admin/polls') return data([pollRow(1), pollRow(2), pollRow(3), pollRow(4)]);

      // uygunsuz ifade
      if (p === '/admin/profanity/info')
        return fail ? err() : json(r, { builtIn: { tr: 412, en: 288, ar: 130, allow: 30, source: 'profanity-words.txt' }, adminBlock: 3, adminAllow: 1, settings: { enabled: true, mode: 'BLOCK' } });
      if (p === '/admin/profanity/stats')
        return fail ? err() : json(r, { last24h: { total: 14, byField: [] }, last7d: { total: 96, byField: [{ entity: 'FeedPost', field: 'text', count: 40 }, { entity: 'AppUser', field: 'displayName', count: 31 }, { entity: 'Community', field: 'description', count: 25 }] } });
      if (p === '/admin/profanity') return cursor([{ id: 1, term: 'ornekkelime', kind: 'BLOCK', lang: 'TR', note: 'deneme', createdBy: 1, createdAt: iso(4) }, { id: 2, term: '=tamkelime', kind: 'BLOCK', lang: 'ALL', note: null, createdBy: 1, createdAt: iso(6) }]);

      // raporlar
      if (p === '/admin/reports/reason-templates') return json(r, [{ code: 'SPAM', text: 'Spam içerik', texts: { tr: 'Spam içerik', en: 'Spam', ar: 'x' } }]);
      if (/^\/admin\/reports\/\d+$/.test(p)) return fail ? err() : json(r, { report: report(1), context: [], related: [] });
      if (p === '/admin/reports') return cursor([report(1), report(2), report(3), report(4), report(5)]);
      if (/^\/admin\/users\/\d+$/.test(p)) return json(r, { id: 9, displayName: LONG_NAME, email: LONG_MAIL, status: 'ACTIVE', counts: { reportsAgainst: 4 } });

      // destek
      if (/^\/admin\/support\/tickets\/\d+$/.test(p))
        return fail
          ? err()
          : json(r, {
              ticket: ticket(2, { status: 'OPEN' }),
              messages: [
                { id: 1, fromStaff: false, internal: false, text: 'Merhaba, şifremi unuttum ama sıfırlama kodu gelmiyor.', createdAt: iso(2), authorId: null },
                { id: 2, fromStaff: true, internal: false, text: 'Merhaba, e-posta adresinizi kontrol edebilir misiniz?', createdAt: iso(1.9), authorId: 1 },
              ],
              userId: 42,
              userEmail: LONG_MAIL,
              priority: 'URGENT',
              assigneeId: null,
              assigneeName: null,
            });
      if (p === '/admin/support/tickets') return cursor([ticket(1), ticket(2), ticket(3), ticket(4), ticket(5)]);
      if (p === '/admin/feedback') return cursor([feedback(1), feedback(2), feedback(3), feedback(4)]);
      return r.fallback();
    },
  );
}

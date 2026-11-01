/**
 * MOD2: İçerik denetimi görsel doğrulaması (backendsiz). Ekran görüntüleri repoya girmez:
 * SHOTS_DIR (varsayılan <depo>/.playwright-mcp/mod2). Çalıştırma:
 *   cd web && E2E_PORT=5312 npx playwright test mod2-visual.spec.ts
 * Önce/sonra için aynı betik eski kaynağa (E2E_BASE_URL) çalıştırılıp SHOTS_DIR farklı verilir.
 */
import { expect, test, type Page } from '@playwright/test';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { json, pageOverflow, stubPanel } from './mockPanel';
import { stubModeration } from './fixtures/moderation';

const DIR = process.env.SHOTS_DIR || join(process.cwd(), '..', '.playwright-mcp', 'mod2');
mkdirSync(DIR, { recursive: true });

const iso = (backDays: number) => new Date(Date.now() - backDays * 86_400_000).toISOString();
const person = (id: number, name: string) => ({ id, displayName: name, email: `ogr${id}@bingol.edu.tr`, avatarUrl: null });
const SVG = (c: string) =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="160" height="160"><rect width="160" height="160" fill="${c}"/><circle cx="80" cy="70" r="34" fill="#fff" opacity=".7"/></svg>`;
const COLORS = ['#2a4f8c', '#d53e35', '#1f8a8a', '#c68a10', '#7a5aa6', '#5f7f3a'];

const post = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  author: person(5 + (id % 3), ['Ayşe Yılmaz', 'Mehmet Kaya', 'Zeynep Demir'][id % 3]),
  text: `Bahar şenliği fotoğrafı ${id}`,
  media: id % 4 === 0 ? [] : [{ id: id * 10, kind: 'IMAGE', url: `/api/admin/posts/media/${id}/full`, thumbUrl: `/api/admin/posts/media/${id}/thumb`, width: 160, height: 160, durationMs: null, hidden: false }],
  likeCount: 40 + id * 7,
  mediaCount: 1,
  hidden: id === 2,
  deleted: false,
  hiddenReason: null,
  createdAt: iso(id),
  editedAt: null,
  hiddenAt: null,
  deletedAt: null,
  deletedBy: null,
  openReportCount: id === 3 ? 2 : 0,
  ...over,
});

const attach = (id: number, over: Record<string, unknown> = {}) => ({
  attachmentId: id,
  messageId: 900 + id,
  conversationId: 30,
  conversationTitle: 'Bilgisayar Mühendisliği 3. sınıf grubu',
  conversationType: 'GROUP',
  sender: person(7, 'Ayşe Yılmaz'),
  kind: 'IMAGE',
  viewOnce: id === 2,
  viewedBy: [],
  purged: false,
  messageDeleted: id === 3,
  hidden: false,
  suppressed: false,
  createdAt: iso(id / 3),
  width: 160,
  height: 160,
  durationMs: null,
  bytes: 15000,
  previewUrl: `/api/admin/media/attachments/${id}/preview`,
  thumbUrl: `/api/admin/media/attachments/${id}/preview?thumb=true`,
  ...over,
});

const accessRow = (id: number) => ({
  id,
  adminId: 1 + (id % 2),
  adminEmail: ['yonetici@bingol.edu.tr', 'destek.uzmani@bingol.edu.tr', 'moderator@bingol.edu.tr'][id % 3],
  conversationId: 30 + id,
  targetUserId: 40 + id,
  kind: ['CONVERSATION', 'MESSAGES', 'MEDIA'][id % 3],
  messageCount: 10 + id,
  fromMessageId: 1,
  toMessageId: 20,
  reason: id % 4 === 0 ? null : 'Şikâyet incelemesi için gerekli',
  ip: '10.0.0.1',
  at: iso(id / 4),
});

const pollDetail = (id: number, type: 'SINGLE' | 'RATING') => ({
  id,
  title: type === 'SINGLE' ? 'Hangi kulüp etkinliği olsun?' : 'Yemekhane menüsünü nasıl buluyorsunuz?',
  description: null,
  type,
  scope: 'GLOBAL',
  communityId: null,
  communityName: null,
  menuDate: null,
  menuItems: null,
  options:
    type === 'SINGLE'
      ? [
          { id: 1, text: 'Bahar şenliği', position: 1 },
          { id: 2, text: 'Kariyer günleri', position: 2 },
          { id: 3, text: 'Konser', position: 3 },
        ]
      : [1, 2, 3, 4, 5].map((n) => ({ id: n, text: String(n), position: n })),
  maxChoices: 1,
  anonymous: true,
  allowChangeVote: true,
  showResults: 'ALWAYS',
  notify: false,
  opensAt: iso(5),
  closesAt: null,
  audience: null,
  status: 'OPEN',
  state: 'OPEN',
  createdAt: iso(5),
  closedAt: null,
  createdBy: { id: 1, displayName: 'Yönetici' },
  canManage: true,
  resultsVisible: true,
  results:
    type === 'SINGLE'
      ? [
          { optionId: 1, count: 210, percent: 52.5, score: null },
          { optionId: 2, count: 120, percent: 30, score: null },
          { optionId: 3, count: 70, percent: 17.5, score: null },
        ]
      : [
          { optionId: 1, count: 6, percent: 3, score: null },
          { optionId: 2, count: 14, percent: 7, score: null },
          { optionId: 3, count: 40, percent: 20, score: null },
          { optionId: 4, count: 90, percent: 45, score: null },
          { optionId: 5, count: 50, percent: 25, score: null },
        ],
  totalVotes: type === 'SINGLE' ? 400 : 200,
  turnout: { voted: type === 'SINGLE' ? 400 : 200, eligible: 1500, percent: type === 'SINGLE' ? 26.7 : 13.3 },
  average: type === 'RATING' ? 3.9 : null,
  ratingCount: type === 'RATING' ? 200 : null,
});

async function setup(page: Page, theme: 'light' | 'dark', w: number, h: number) {
  await page.emulateMedia({ colorScheme: theme });
  await page.setViewportSize({ width: w, height: h });
  await stubPanel(page, 'FULL');
  await stubModeration(page, 'full');
  await page.addInitScript((t) => localStorage.setItem('bu.theme', t), theme);
  // Fixture'ı zenginleştiren ek yanıtlar (son kayıt öncelikli; tanımadığını fixture'a devreder)
  await page.route(
    (u) => u.pathname.startsWith('/api/'),
    (r) => {
      const u = new URL(r.request().url());
      const p = u.pathname.replace(/^\/api/, '');
      if (r.request().method() !== 'GET') return r.fallback();
      if (p.startsWith('/admin/posts/media/')) return r.fulfill({ status: 200, contentType: 'image/svg+xml', body: SVG(COLORS[Number(p.split('/')[4]) % 6]) });
      if (p.startsWith('/admin/media/attachments/')) return r.fulfill({ status: 200, contentType: 'image/svg+xml', body: SVG(COLORS[Number(p.split('/')[4]) % 6]) });
      if (p === '/admin/posts') return json(r, { items: [1, 2, 3, 4, 5, 6, 7, 8].map((i) => post(i)), nextCursor: null });
      if (p === '/admin/chat-media') return json(r, { items: [1, 2, 3, 4, 5, 6].map((i) => attach(i)), nextCursor: null });
      if (p === '/admin/polls/1') return json(r, pollDetail(1, 'SINGLE'));
      if (p === '/admin/polls/2') return json(r, pollDetail(2, 'RATING'));
      if (p === '/admin/audit/message-access') {
        const items = Array.from({ length: 12 }, (_, i) => accessRow(i + 1));
        return json(r, { items, page: 0, size: 20, totalItems: items.length, totalPages: 1 });
      }
      if (p === '/admin/users') return json(r, { items: [], page: 0, size: 100, totalItems: 0, totalPages: 1 });
      return r.fallback();
    },
  );
}

const shot = (page: Page, name: string, w: number, theme = 'light') =>
  page.screenshot({ path: join(DIR, `${process.env.SHOT_TAG || 'sonra'}-${name}-${w}-${theme}.png`), fullPage: true });

for (const [w, h] of [
  [1280, 900],
  [390, 844],
] as const) {
  test(`raporlar @${w}`, async ({ page }) => {
    await setup(page, 'light', w, h);
    await page.goto('/admin/reports');
    await page.waitForSelector('[data-search-anchor="reports-summary"]');
    await page.waitForLoadState('networkidle');
    await shot(page, 'raporlar', w);
    if (w === 390) {
      const o = await pageOverflow(page);
      expect(o.sw, `taşma: ${o.offenders.join(' | ')}`).toBeLessThanOrEqual(o.cw);
    }
  });

  test(`gönderiler liste ve ızgara @${w}`, async ({ page }) => {
    await setup(page, 'light', w, h);
    await page.goto('/admin/posts');
    await page.waitForSelector('[data-testid="post-list"]');
    await page.waitForLoadState('networkidle');
    await shot(page, 'gonderiler-liste', w);
    await page.getByRole('button', { name: 'Izgara' }).click();
    await page.waitForSelector('[data-testid="post-grid"]');
    await page.waitForLoadState('networkidle');
    expect(page.url()).toContain('view=grid');
    await shot(page, 'gonderiler-izgara', w);
    if (w === 390) {
      const o = await pageOverflow(page);
      expect(o.sw, `taşma: ${o.offenders.join(' | ')}`).toBeLessThanOrEqual(o.cw);
    }
  });

  test(`anketler ve sonuç grafiği @${w}`, async ({ page }) => {
    await setup(page, 'light', w, h);
    await page.goto('/admin/polls');
    await page.waitForSelector('[data-testid="poll-stats"]');
    await page.waitForLoadState('networkidle');
    await shot(page, 'anketler', w);
    for (const [name, tag] of [
      ['Yemekhane menüsünü nasıl buluyorsunuz?', 'halka'],
      ['Kulüp seçimi anketi 2', 'puan'],
    ] as const) {
      await page.goto('/admin/polls');
      await page.getByRole('button', { name }).first().click();
      await page.waitForSelector('[data-testid="poll-results"]');
      if (process.env.SHOT_TAG !== 'once') {
        await page.locator('[data-testid="poll-viz"]').waitFor();
        await page.waitForTimeout(1500);
      }
      await page.screenshot({ path: join(DIR, `${process.env.SHOT_TAG || 'sonra'}-anket-sonuc-${tag}-${w}-light.png`) });
    }
  });

  test(`mesaj erişim kayıtları @${w}`, async ({ page }) => {
    await setup(page, 'light', w, h);
    await page.goto('/admin/audit/message-access');
    await page.waitForSelector('main h1');
    await page.waitForLoadState('networkidle');
    await shot(page, 'mesaj-erisim', w);
    if (w === 390) {
      const o = await pageOverflow(page);
      expect(o.sw, `taşma: ${o.offenders.join(' | ')}`).toBeLessThanOrEqual(o.cw);
    }
  });

  test(`sohbet medyası @${w}`, async ({ page }) => {
    await setup(page, 'light', w, h);
    await page.goto('/admin/chat-feed');
    await page.waitForSelector('main h1');
    await page.getByRole('textbox').first().fill('Rapor incelemesi 1234 numaralı şikâyet için bakılıyor');
    await page.getByRole('button', { name: /Devam|Onayla|Tamam|Görüntüle/ }).first().click();
    await page.getByLabel('Sohbet no').fill('30');
    await page.waitForSelector('[data-testid="media-grid"]');
    await page.waitForLoadState('networkidle');
    await shot(page, 'sohbet-medya', w);
    if (w === 390) {
      const o = await pageOverflow(page);
      expect(o.sw, `taşma: ${o.offenders.join(' | ')}`).toBeLessThanOrEqual(o.cw);
    }
  });
}

test('sohbet akışı: sekme adreste, J/K gezinme, bulanıklık kapatılabilir', async ({ page }) => {
  await setup(page, 'light', 1280, 900);
  await page.goto('/admin/chat-feed');
  await page.getByRole('textbox').first().fill('Rapor incelemesi 1234 numaralı şikâyet için bakılıyor');
  await page.getByRole('button', { name: /Devam|Onayla|Tamam|Görüntüle/ }).first().click();
  await page.getByRole('tab', { name: 'Mesajlar' }).click();
  await expect(page).toHaveURL(/tab=messages/);
  await page.getByLabel('Sohbet no').fill('30');
  await page.waitForSelector('[data-testid="feed-row"]');
  await page.locator('body').click({ position: { x: 5, y: 5 } });
  await page.keyboard.press('j');
  await page.keyboard.press('j');
  const idx = await page.evaluate(() => Array.from(document.querySelectorAll('[data-testid="feed-row"]')).findIndex((r) => r.contains(document.activeElement)));
  expect(idx).toBe(1);
  await page.keyboard.press('k');
  const idx2 = await page.evaluate(() => Array.from(document.querySelectorAll('[data-testid="feed-row"]')).findIndex((r) => r.contains(document.activeElement)));
  expect(idx2).toBe(0);
  const box = page.getByRole('checkbox', { name: 'Görselleri bulanık göster' });
  await expect(box).toBeChecked();
  await box.uncheck();
  await page.reload();
  await page.getByRole('textbox').first().fill('Rapor incelemesi 1234 numaralı şikâyet için bakılıyor');
  await page.getByRole('button', { name: /Devam|Onayla|Tamam|Görüntüle/ }).first().click();
  await expect(page.getByRole('checkbox', { name: 'Görselleri bulanık göster' })).not.toBeChecked();
});

test('arama: "mesaj" ve yazım hatası "meaj" sohbet sayfasını getirir', async ({ page }) => {
  await setup(page, 'light', 1280, 900);
  await page.goto('/admin');
  await page.waitForSelector('main');
  for (const q of ['mesaj', 'meaj']) {
    await page.keyboard.press('Control+k');
    await page.getByRole('combobox').first().fill(q);
    await expect(page.getByRole('option', { name: /Sohbet medyası/ }).first()).toBeVisible();
    if (q === 'mesaj') await page.screenshot({ path: join(DIR, 'sonra-arama-mesaj-1280-light.png') });
    await page.keyboard.press('Escape');
  }
});

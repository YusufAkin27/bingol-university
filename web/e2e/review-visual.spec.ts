/**
 * REVIEW-VISUAL: bağımsız görsel doğrulama (backendsiz). Ekran görüntüleri repoya girmez:
 * SHOTS_DIR (varsayılan C:\bu_qa\shots\adminvisual\after\REVIEW). Ölçümler RESULTS.jsonl dosyasına eklenir.
 *   cd web && E2E_PORT=5306 npx playwright test review-visual.spec.ts
 */
import { test, type Page } from '@playwright/test';
import { appendFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { pageOverflow, stubPanel } from './mockPanel';
import { stubCommunity, type Scenario } from './fixtures/community';
import { stubModeration } from './fixtures/moderation';
import { stubPeople } from './fixtures/people';
import { stubNotifsys } from './fixtures/notifsys';

const DIR = process.env.SHOTS_DIR || 'C:\\bu_qa\\shots\\adminvisual\\after\\REVIEW';
mkdirSync(DIR, { recursive: true });
const RESULTS = join(DIR, `${process.env.RUN || 'RESULTS'}.jsonl`);

/** Sayfa içi ölçüm: küçük hedef, kontrast, kesilen metin, üst üste binen etkileşimli öğeler. */
async function measure(page: Page) {
  return page.evaluate(() => {
    const vis = (el: HTMLElement) => {
      const r = el.getBoundingClientRect();
      if (r.width === 0 || r.height === 0) return false;
      const cs = getComputedStyle(el);
      return cs.visibility !== 'hidden' && cs.display !== 'none' && !el.closest('[hidden]') && !el.closest('.sr-only') && !el.classList.contains('sr-only');
    };
    const label = (el: HTMLElement) => `${el.tagName.toLowerCase()}[${(el.getAttribute('aria-label') || el.textContent || '').trim().slice(0, 24)}]`;

    // 1) dokunma hedefi
    const small: string[] = [];
    const sel = 'button, a[href], input:not([type=hidden]), select, textarea, [role=tab], [role=button]';
    for (const el of Array.from(document.querySelectorAll<HTMLElement>(sel))) {
      if (!vis(el)) continue;
      if (el.tagName === 'A' && getComputedStyle(el).display === 'inline') continue;
      const r = el.getBoundingClientRect();
      const lb = el.closest('label');
      const box = lb ? lb.getBoundingClientRect() : r;
      if (Math.max(r.height, box.height) < 43.5 || Math.max(r.width, box.width) < 43.5) small.push(`${label(el)} ${Math.round(r.width)}x${Math.round(r.height)}`);
    }

    // 2) kontrast
    const cv = document.createElement('canvas');
    cv.width = cv.height = 1;
    const ctx = cv.getContext('2d', { willReadFrequently: true })!;
    const rgba = (c: string): [number, number, number, number] => {
      ctx.clearRect(0, 0, 1, 1);
      ctx.fillStyle = '#000';
      ctx.fillStyle = c;
      ctx.fillRect(0, 0, 1, 1);
      const d = ctx.getImageData(0, 0, 1, 1).data;
      return [d[0], d[1], d[2], d[3] / 255];
    };
    const over = (f: number[], b: number[], a: number) => [0, 1, 2].map((i) => f[i] * a + b[i] * (1 - a));
    const lum = (c: number[]) => {
      const f = c.map((v) => {
        const s = v / 255;
        return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
      });
      return 0.2126 * f[0] + 0.7152 * f[1] + 0.0722 * f[2];
    };
    const bgOf = (el: HTMLElement): number[] | null => {
      const layers: [number, number, number, number][] = [];
      let p: HTMLElement | null = el;
      while (p) {
        const cs = getComputedStyle(p);
        if (cs.backgroundImage && cs.backgroundImage !== 'none') return null; // gradyan/resim: bilinmiyor
        const c = rgba(cs.backgroundColor);
        if (c[3] > 0) layers.push(c);
        if (c[3] >= 1) break;
        p = p.parentElement;
      }
      let base: number[] = [255, 255, 255];
      const last = layers[layers.length - 1];
      if (last && last[3] >= 1) {
        base = [last[0], last[1], last[2]];
        layers.pop();
      } else {
        const b = rgba(getComputedStyle(document.body).backgroundColor);
        base = b[3] > 0 ? [b[0], b[1], b[2]] : [255, 255, 255];
      }
      for (let i = layers.length - 1; i >= 0; i--) base = over(layers[i], base, layers[i][3]);
      return base;
    };
    const low: { t: string; r: number; fs: number }[] = [];
    const seen = new Set<string>();
    let checked = 0;
    for (const el of Array.from(document.body.querySelectorAll<HTMLElement>('*'))) {
      if (!vis(el)) continue;
      let txt = '';
      for (const n of Array.from(el.childNodes)) if (n.nodeType === 3) txt += n.textContent || '';
      txt = txt.trim();
      if (!txt) continue;
      if (el.closest('[disabled],[aria-disabled=true]')) continue;
      if (el.closest('svg')) continue;
      const bg = bgOf(el);
      if (!bg) continue;
      const cs = getComputedStyle(el);
      const fg = rgba(cs.color);
      let op = 1;
      for (let p: HTMLElement | null = el; p; p = p.parentElement) op *= Number(getComputedStyle(p).opacity);
      const fgc = over(fg, bg, fg[3] * op);
      const L1 = lum(fgc);
      const L2 = lum(bg);
      const ratio = (Math.max(L1, L2) + 0.05) / (Math.min(L1, L2) + 0.05);
      const fs = parseFloat(cs.fontSize);
      const large = fs >= 24 || (fs >= 18.66 && Number(cs.fontWeight) >= 700);
      checked++;
      if (ratio < (large ? 3 : 4.5)) {
        const key = txt.slice(0, 30) + '|' + ratio.toFixed(2);
        if (!seen.has(key)) {
          seen.add(key);
          low.push({ t: txt.slice(0, 30), r: Math.round(ratio * 100) / 100, fs });
        }
      }
    }

    // 3) kesilen metin (üç nokta ile kısaltma bilinçli sayılır, ayrıca sayılır)
    const clipped: string[] = [];
    let ellipsis = 0;
    for (const el of Array.from(document.body.querySelectorAll<HTMLElement>('*'))) {
      if (!vis(el)) continue;
      let hasText = false;
      for (const n of Array.from(el.childNodes)) if (n.nodeType === 3 && (n.textContent || '').trim()) hasText = true;
      if (!hasText) continue;
      const cs = getComputedStyle(el);
      if (el.scrollWidth > el.clientWidth + 1 && (cs.overflowX === 'hidden' || cs.overflowX === 'clip')) {
        if (cs.textOverflow === 'ellipsis') ellipsis++;
        else clipped.push(`${label(el)} sw${el.scrollWidth}>cw${el.clientWidth}`);
      }
    }

    // 4) üst üste binen etkileşimli öğeler (sabit/yapışkan atalar hariç)
    const items = Array.from(document.querySelectorAll<HTMLElement>(sel)).filter((el) => {
      if (!vis(el)) return false;
      for (let p: HTMLElement | null = el; p; p = p.parentElement) {
        const pos = getComputedStyle(p).position;
        if (pos === 'fixed' || pos === 'sticky') return false;
      }
      return true;
    });
    const overlap: string[] = [];
    for (let i = 0; i < items.length && overlap.length < 8; i++) {
      const a = items[i].getBoundingClientRect();
      for (let j = i + 1; j < items.length; j++) {
        if (items[i].contains(items[j]) || items[j].contains(items[i])) continue;
        const b = items[j].getBoundingClientRect();
        const w = Math.min(a.right, b.right) - Math.max(a.left, b.left);
        const h = Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top);
        if (w > 4 && h > 4 && w * h > 30) {
          overlap.push(`${label(items[i])} x ${label(items[j])} ${Math.round(w)}x${Math.round(h)}`);
          break;
        }
      }
    }
    return { small, low, clipped, ellipsis, overlap, checked };
  });
}

type Group = 'COMM' | 'PEOPLE' | 'MOD' | 'NOTIF';
interface Pg {
  name: string;
  route: string;
  group: Group;
  after?: (p: Page) => Promise<void>;
}

const tab = (name: RegExp | string) => async (p: Page) => {
  await p.getByRole('tab', { name }).first().click();
  await p.waitForTimeout(500);
};

const COMM: Pg[] = [
  { name: 'news', route: '/admin/content/news', group: 'COMM' },
  { name: 'clubs', route: '/admin/communities', group: 'COMM' },
  { name: 'clubs-drawer', route: '/admin/communities?club=3', group: 'COMM' },
  { name: 'clubs-members', route: '/admin/communities?club=3', group: 'COMM', after: tab(/Üyeler/) },
  { name: 'clubs-queue', route: '/admin/communities?tab=queue', group: 'COMM' },
  { name: 'categories', route: '/admin/community-categories', group: 'COMM' },
  { name: 'club-audit', route: '/admin/communities/audit?communityId=1', group: 'COMM' },
  { name: 'content-review', route: '/admin/content-review', group: 'COMM' },
  { name: 'events', route: '/admin/events', group: 'COMM' },
  { name: 'events-drawer', route: '/admin/events?open=2', group: 'COMM' },
  { name: 'event-apps', route: '/admin/events/applications?eventId=2&name=Bahar%20%C5%9Eenli%C4%9Fi', group: 'COMM' },
  { name: 'acd-calendar', route: '/admin/academic/calendar', group: 'COMM' },
  { name: 'acd-calendar-list', route: '/admin/academic/calendar?view=list', group: 'COMM' },
  { name: 'acd-exams', route: '/admin/academic/exams', group: 'COMM' },
  { name: 'acd-announcements', route: '/admin/academic/announcements', group: 'COMM' },
  { name: 'legal', route: '/admin/content/legal', group: 'COMM' },
  { name: 'faq', route: '/admin/content/faq', group: 'COMM' },
  { name: 'menu', route: '/admin/content/menu', group: 'COMM' },
];

const MOD: Pg[] = [
  ['reports', '/admin/reports'], ['posts', '/admin/posts'], ['polls', '/admin/polls'], ['blocklist', '/admin/moderation/blocklist'],
  ['strikes', '/admin/moderation/strikes'], ['hidden', '/admin/moderation/hidden'], ['reason-templates', '/admin/moderation/reason-templates'],
  ['profanity', '/admin/profanity'], ['tickets', '/admin/support/tickets'], ['ticket-detail', '/admin/support/tickets/2'],
  ['feedback', '/admin/support/feedback'], ['chat-feed', '/admin/chat-feed'],
].map(([name, route]) => ({ name, route, group: 'MOD' as Group }));

const PEOPLE: Pg[] = [
  ['dashboard', '/admin'], ['an-overview', '/admin/analytics'], ['an-growth', '/admin/analytics/growth'], ['an-engagement', '/admin/analytics/engagement'],
  ['an-retention', '/admin/analytics/retention'], ['an-demographics', '/admin/analytics/demographics'], ['users', '/admin/users'], ['user-detail', '/admin/users/12'],
  ['pending', '/admin/pending-users'], ['suspensions', '/admin/moderation/suspensions'], ['appeals', '/admin/moderation/appeals'], ['accessbans', '/admin/security/access-bans'],
].map(([name, route]) => ({ name, route, group: 'PEOPLE' as Group }));

const NOTIF: Pg[] = [
  ['system', '/admin/system'], ['ops', '/admin/ops'], ['mailqueue', '/admin/mail/queue'], ['audit', '/admin/audit'], ['settings', '/admin/settings'],
  ['retention', '/admin/data-retention'], ['crypto', '/admin/crypto'],
].map(([name, route]) => ({ name, route, group: 'NOTIF' as Group }));

async function setup(page: Page, g: Group, theme: 'light' | 'dark', w: number, h: number, scenario: Scenario, unmatched: string[]) {
  await page.emulateMedia({ colorScheme: theme, reducedMotion: 'reduce' });
  await page.setViewportSize({ width: w, height: h });
  if (g === 'PEOPLE') await stubPeople(page, scenario, theme === 'dark');
  else if (g === 'NOTIF') await stubNotifsys(page, scenario);
  else {
    await stubPanel(page, 'FULL');
    if (g === 'MOD') await stubModeration(page, scenario);
    else await stubCommunity(page, scenario, unmatched);
  }
  await page.addInitScript((t) => localStorage.setItem('bu.theme', t), theme);
}

async function run(page: Page, pg: Pg, theme: 'light' | 'dark', w: number, h: number, scenario: Scenario) {
  const unmatched: string[] = [];
  await setup(page, pg.group, theme, w, h, scenario, unmatched);
  await page.goto(pg.route);
  await page.waitForSelector('main h1', { timeout: 20000 });
  await page.waitForLoadState('networkidle');
  if (pg.after) await pg.after(page);
  await page.waitForTimeout(scenario === 'error' ? 6500 : 500);
  const tag = `${pg.name}${scenario === 'full' ? '' : '-' + scenario}-${w}-${theme}`;
  await page.screenshot({ path: join(DIR, `${tag}.png`), fullPage: true });
  const o = await pageOverflow(page);
  const m = await measure(page);
  appendFileSync(
    RESULTS,
    JSON.stringify({ group: pg.group, page: pg.name, scenario, w, theme, sw: o.sw, cw: o.cw, off: o.offenders, small: m.small, low: m.low, clipped: m.clipped, ellipsis: m.ellipsis, overlap: m.overlap, checked: m.checked, unmatched: Array.from(new Set(unmatched)) }) + '\n',
  );
}

const only = process.env.ONLY ? new RegExp(process.env.ONLY) : null;
const ALL = [...COMM, ...PEOPLE, ...MOD, ...NOTIF].filter((p) => !only || only.test(`${p.group}:${p.name}`));

// COMM: üç genişlik, açık + koyu. Diğer gruplar: 390 açık + koyu.
for (const pg of ALL) {
  for (const theme of ['light', 'dark'] as const) {
    const sizes = pg.group === 'COMM' ? ([[390, 844], [768, 1024], [1280, 800]] as const) : ([[390, 844]] as const);
    for (const [w, h] of sizes) {
      test(`${pg.group} ${pg.name} @${w} ${theme}`, async ({ page }) => {
        test.setTimeout(60000);
        await run(page, pg, theme, w, h, 'full');
      });
    }
  }
}

// COMM: boş / hata (390 açık)
for (const pg of ALL.filter((p) => p.group === 'COMM' && !p.after && !/drawer|queue/.test(p.name))) {
  for (const sc of ['empty', 'error'] as const) {
    test(`COMM ${pg.name} ${sc} @390 light`, async ({ page }) => {
      test.setTimeout(60000);
      await run(page, pg, 'light', 390, 844, sc);
    });
  }
}

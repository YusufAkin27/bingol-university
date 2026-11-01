/**
 * REVIEW-VISUAL: arama derin bağlantısı (path#anchor) 15+ sayfada doğru öğeye gidiyor mu. Plan: review-search.spec.ts
 * "S7 plan" testi SHOTS_DIR/s7-plan.json yazar. Her girdi ayrı test (temiz sayfa, baseURL'li).
 *   cd web && E2E_PORT=5306 npx playwright test review-search.spec.ts -g "S7 plan" && E2E_PORT=5306 npx playwright test review-deeplink.spec.ts
 */
import { test, type Page } from '@playwright/test';
import { appendFileSync, existsSync, mkdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { stubPanel } from './mockPanel';
import { stubCommunity } from './fixtures/community';
import { stubModeration } from './fixtures/moderation';
import { stubPeople } from './fixtures/people';
import { stubNotifsys } from './fixtures/notifsys';

const DIR = process.env.SHOTS_DIR || 'C:/bu_qa/shots/adminvisual/after/REVIEW';
mkdirSync(DIR, { recursive: true });
const LOG = join(DIR, `${process.env.RUN || 'deeplink'}.jsonl`);
const PLAN = join(DIR, 's7-plan.json');
interface Pick {
  id: string;
  pageId: string;
  groupId: string;
  to: string;
  anchor: string;
  title: string;
}
const plan: Pick[] = existsSync(PLAN) ? JSON.parse(readFileSync(PLAN, 'utf-8')) : [];

async function stubFor(page: Page, group: string) {
  if (group === 'overview' || group === 'people') return stubPeople(page, 'full');
  if (group === 'notifications' || group === 'system') return stubNotifsys(page, 'full');
  await stubPanel(page, 'FULL');
  if (group === 'moderation' || group === 'support') return stubModeration(page, 'full');
  return stubCommunity(page, 'full');
}

for (const e of plan.slice(0, 26)) {
  test(`derin bağlantı ${e.id}`, async ({ page }) => {
    test.setTimeout(90000);
    await page.setViewportSize({ width: 1280, height: 800 });
    await page.addInitScript(() => {
      localStorage.setItem('bu.cookies', 'ack:v1');
      const hits: Record<string, unknown> = {};
      (window as unknown as { __hits: Record<string, unknown> }).__hits = hits;
      new MutationObserver((ms) => {
        for (const m of ms) {
          const el = m.target as HTMLElement;
          if (el.getAttribute('data-search-hit') === 'true') {
            const a = el.getAttribute('data-search-anchor')!;
            const r = el.getBoundingClientRect();
            if (!hits[a]) hits[a] = { top: r.top, w: r.width, h: r.height, vh: innerHeight };
          }
        }
      }).observe(document, { attributes: true, subtree: true, attributeFilter: ['data-search-hit'] });
    });
    await stubFor(page, e.groupId);
    await page.goto(e.to, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('main h1', { timeout: 60000 });
    let state = 'missing';
    for (let i = 0; i < 70; i++) {
      const info = await page.evaluate((a) => {
        const el = document.querySelector(`[data-search-anchor="${a}"]`);
        const h = (window as unknown as { __hits: Record<string, { top: number; w: number; h: number; vh: number }> }).__hits[a];
        return { present: !!el, h: h ?? null };
      }, e.anchor);
      if (info.h) {
        state = info.h.w > 0 && info.h.h > 0 && info.h.top >= -2 && info.h.top <= info.h.vh - 20 ? 'ok' : 'hit-not-in-view';
        break;
      }
      if (info.present) state = 'present-no-hit';
      await page.waitForTimeout(150);
    }
    const alerts = (await page.locator('[role=alert]').allInnerTexts()).slice(0, 2).map((s) => s.replace(/\s+/g, ' ').slice(0, 90));
    appendFileSync(LOG, JSON.stringify({ id: e.id, page: e.pageId, to: e.to, state, alerts }) + '\n');
    if (state !== 'ok') await page.screenshot({ path: join(DIR, `DL-${e.id.replace(/\W+/g, '_')}.png`) });
  });
}
